"""Go-live catalog validator — every filter, every image, every claim.

Three sweeps against the LIVE API:
1. FILTER INTEGRITY — for each audience/season/occasion/color/tier value,
   fetch /catalog with that filter and assert every returned item actually
   carries the value (audience additionally allows untagged/unisex; season
   allows all-season). Also: every item is reachable through at least one
   tier or the untiered bucket, prices are positive, meters positive.
2. IMAGE HEALTH — every image_url returns HTTP 200; for made-to-measure
   items the -flat/-fitted/-regular/-loose variants are probed too
   (missing variants are WARN, not FAIL — the UI falls back).
3. VISION AUDIT (DeepSeek) — for every audience-tagged item, the vision
   model looks at the LISTING image and answers whether it reads as
   menswear, womenswear, or neutral fabric. A men's listing with an image
   that reads womenswear (or vice versa) is a FAIL — this is the check
   that catches a feminine-reading ghost-mannequin on a men's SKU.

Usage:  python scripts/validate_catalog.py            (all sweeps)
        python scripts/validate_catalog.py --no-vision (skip sweep 3)
Exit code 0 = go, 1 = findings need attention.
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys
import urllib.request

API = "https://naap-api.m9vte9fmk66k4.us-west-2.cs.amazonlightsail.com"
ROOT = pathlib.Path(__file__).resolve().parent.parent

COLORS = {"white", "cream", "ivory", "beige", "brown", "grey", "black",
          "blue", "teal", "green", "pink", "red", "gold", "multi"}
TIERS = {"everyday", "occasion", "ceremonial"}
SEASONS = {"summer", "winter", "all-season"}

FAIL: list[str] = []
WARN: list[str] = []


def get(path: str):
    with urllib.request.urlopen(API + path, timeout=30) as r:
        return json.load(r)


def head_ok(url: str) -> bool:
    try:
        req = urllib.request.Request(url, method="GET",
                                     headers={"Range": "bytes=0-0"})
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.status in (200, 206)
    except Exception:
        return False


def sweep_filters(items):
    ids = {i["id"] for i in items}
    print(f"catalog: {len(items)} items")
    for i in items:
        if not i.get("price_usd") or i["price_usd"] <= 0:
            FAIL.append(f"{i['id']}: non-positive price")
        if not i.get("meters") or i["meters"] <= 0:
            FAIL.append(f"{i['id']}: non-positive meters")
        if i.get("color") not in COLORS:
            FAIL.append(f"{i['id']}: color {i.get('color')!r} not canonical")
        if i.get("tier") not in TIERS and i.get("tier") is not None:
            FAIL.append(f"{i['id']}: unknown tier {i.get('tier')!r}")

    for aud in ("men", "women"):
        got = get(f"/catalog?audience={aud}")
        for i in got:
            if i.get("audience") not in (aud, None):
                FAIL.append(
                    f"audience={aud} leaked {i['id']} (audience={i.get('audience')})")
        print(f"  audience={aud}: {len(got)} items")

    for season in SEASONS:
        got = get(f"/catalog?season={season}")
        for i in got:
            if i.get("season") not in (season, "all-season", None):
                FAIL.append(f"season={season} leaked {i['id']} ({i.get('season')})")
        print(f"  season={season}: {len(got)}")

    occasions = sorted({o for i in items for o in i.get("occasions", [])})
    for occ in occasions:
        got = get(f"/catalog?occasion={occ}")
        if not got:
            WARN.append(f"occasion={occ}: zero items (dead filter value)")
        for i in got:
            if occ not in i.get("occasions", []):
                FAIL.append(f"occasion={occ} leaked {i['id']}")
    print(f"  occasions swept: {len(occasions)}")

    for color in sorted({i.get("color") for i in items if i.get("color")}):
        got = get(f"/catalog?color={color}")
        for i in got:
            if i.get("color") != color:
                FAIL.append(f"color={color} leaked {i['id']} ({i.get('color')})")
    print("  colors swept")

    tiered = set()
    for tier in TIERS:
        got = get(f"/catalog?tier={tier}")
        for i in got:
            tiered.add(i["id"])
            if i.get("tier") != tier:
                FAIL.append(f"tier={tier} leaked {i['id']}")
        print(f"  tier={tier}: {len(got)}")
    untiered = ids - tiered
    for uid in untiered:
        item = next(i for i in items if i["id"] == uid)
        if item.get("tier") is not None:
            FAIL.append(f"{uid}: tier set but not returned by tier filter")
    print(f"  untiered (All-only): {sorted(untiered)}")


def sweep_images(items):
    for i in items:
        url = i.get("image_url")
        if not url:
            FAIL.append(f"{i['id']}: no image_url")
            continue
        if not head_ok(url):
            FAIL.append(f"{i['id']}: image_url dead {url}")
        if i.get("availability") == "made-to-measure":
            for var in ("flat", "fitted", "regular", "loose"):
                vu = url.replace(".jpg", f"-{var}.jpg")
                if not head_ok(vu):
                    WARN.append(f"{i['id']}: missing -{var} variant")
    print("  image health swept")


def sweep_vision(items):
    key = os.environ.get("DEEPSEEK_API_KEY")
    if not key:
        for line in (ROOT / "server" / ".env").read_text().splitlines():
            if line.startswith("DEEPSEEK_API_KEY="):
                key = line.split("=", 1)[1].strip()
    if not key:
        WARN.append("vision sweep skipped: no DEEPSEEK_API_KEY")
        return

    def ask(url: str) -> str:
        body = json.dumps({
            "model": "deepseek-v4-flash-vision-exp",
            "messages": [{"role": "user", "content": [
                {"type": "text", "text":
                 "Look at this clothing-catalog image. Answer with exactly "
                 "one word: MENSWEAR if it shows or suggests a men's "
                 "garment, WOMENSWEAR if a women's garment, NEUTRAL if it "
                 "is plain fabric/still-life with no gender signal."},
                {"type": "image_url", "image_url": {"url": url}},
            ]}],
            # Reasoning model: reasoning_content consumes tokens before the
            # answer — leave generous headroom or content comes back empty.
            "max_tokens": 1500,
        }).encode()
        req = urllib.request.Request(
            "https://api.deepseek.com/chat/completions", data=body,
            headers={"Content-Type": "application/json",
                     "Authorization": f"Bearer {key}"})
        with urllib.request.urlopen(req, timeout=90) as r:
            out = json.load(r)
        msg = out["choices"][0]["message"]
        verdict = (msg.get("content") or "").strip().upper()
        if verdict not in ("MENSWEAR", "WOMENSWEAR", "NEUTRAL"):
            # Truncated answer: take the LAST verdict word the reasoning
            # trace reached (WOMENSWEAR checked first — it contains
            # MENSWEAR as a substring).
            trace = (msg.get("reasoning_content") or "").upper()
            best = (-1, verdict)
            for word in ("WOMENSWEAR", "NEUTRAL"):
                pos = trace.rfind(word)
                if pos > best[0]:
                    best = (pos, word)
            pos = trace.replace("WOMENSWEAR", " " * 10).rfind("MENSWEAR")
            if pos > best[0]:
                best = (pos, "MENSWEAR")
            verdict = best[1]
        return verdict

    for i in items:
        aud = i.get("audience")
        if aud not in ("men", "women"):
            continue
        urls = [i["image_url"]]
        if i.get("availability") == "made-to-measure":
            urls.append(i["image_url"].replace(".jpg", "-flat.jpg"))
        for url in urls:
            try:
                verdict = ask(url)
            except Exception as e:  # noqa: BLE001
                WARN.append(f"{i['id']}: vision check errored ({type(e).__name__})")
                continue
            expected = "MENSWEAR" if aud == "men" else "WOMENSWEAR"
            tag = url.rsplit('/', 1)[-1]
            if verdict == expected or verdict == "NEUTRAL":
                print(f"  vision OK  {tag}: {verdict}")
            else:
                FAIL.append(
                    f"{i['id']}: {tag} reads {verdict} but listing is {aud}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-vision", action="store_true")
    args = ap.parse_args()

    items = get("/catalog")
    print("== 1. filter integrity ==")
    sweep_filters(items)
    print("== 2. image health ==")
    sweep_images(items)
    if not args.no_vision:
        print("== 3. vision audit (DeepSeek) ==")
        sweep_vision(items)

    print("\n== RESULT ==")
    for w in WARN:
        print(f"  WARN {w}")
    for f in FAIL:
        print(f"  FAIL {f}")
    print(f"{len(FAIL)} failures, {len(WARN)} warnings")
    return 1 if FAIL else 0


if __name__ == "__main__":
    raise SystemExit(main())
