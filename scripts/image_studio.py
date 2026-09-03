"""Naap image studio — AI catalog photography via Gemini image generation.

Generates luxury product imagery for every catalog item, art-directed from
the item's own metadata (composition, design, audience, occasion). Output
goes to a local preview folder for founder approval FIRST; nothing touches
the live site until --upload.

Rules baked in (docs/BLUEPRINT.md §AI architecture):
- Synthetic imagery only: prompts forbid logos, brand marks, and any real
  person's likeness. Models in shots are AI-synthesized people.
- This is CATALOG imagery. User body photos never touch any cloud model.

Usage:
  set GEMINI_API_KEY=...              (or put it in server/.env)
  python scripts/image_studio.py                  # generate all -> preview/
  python scripts/image_studio.py --only id1,id2   # regenerate a few
  python scripts/image_studio.py --upload         # s3 -> getnaap.com/img/,
                                                  # rewrite seed image_url
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import pathlib
import subprocess
import sys
import time
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
SEEDS = [ROOT / "scripts" / "seed_fabrics.json",
         ROOT / "server" / "seed_fabrics.json"]
PREVIEW = ROOT / "scripts" / "image_preview"
MODEL = "gemini-2.5-flash-image"
CDN_BASE = "https://getnaap.com/img"
S3_BUCKET = "s3://naap-landing/img"
CLOUDFRONT_ID = "E39ZIUR5GTI9G7"

STYLE = ("Ultra-premium fashion e-commerce photography, soft diffused "
         "studio lighting, elegant warm neutral backdrop, shallow depth of "
         "field, 4:5 portrait composition, rich fabric detail, editorial "
         "luxury-brand quality. No text, no watermarks, no logos, no brand "
         "marks anywhere.")

PEOPLE = ("The person is a fully AI-synthesized fashion model who does not "
          "resemble any real individual or celebrity.")


def _key() -> str:
    k = os.environ.get("GEMINI_API_KEY")
    if not k:  # fall back to server/.env
        env = ROOT / "server" / ".env"
        if env.exists():
            for line in env.read_text().splitlines():
                if line.startswith("GEMINI_API_KEY="):
                    k = line.split("=", 1)[1].strip()
    if not k:
        sys.exit("GEMINI_API_KEY not set — get one at "
                 "https://aistudio.google.com/apikey and either `set "
                 "GEMINI_API_KEY=...` or add it to server/.env")
    return k


def prompt_for(item: dict) -> str:
    """Art direction from the item's own metadata."""
    comp = item.get("composition", "")
    name = item["name"]
    design = item.get("design", "plain")
    audience = item.get("audience")
    occasions = ", ".join(item.get("occasions", []))
    mtm = item.get("availability") == "made-to-measure"

    if mtm:
        # Garments: a synthesized model wearing the finished piece.
        wearer = ("an elegant South Asian woman" if audience == "women"
                  else "a distinguished South Asian man")
        garment = {
            "atelier-kurta-boski": "a perfectly tailored cream boski silk "
                "kurta with shalwar, standing in a softly lit heritage "
                "courtyard",
            "atelier-blazer-wool": "a soft unstructured Italian-style wool "
                "blazer in deep charcoal over an open-collar shirt, city "
                "evening light",
            "atelier-occasion-sk": "a luxurious raw-silk occasion shalwar "
                "kameez in warm ivory with a fine shawl, wedding-venue "
                "ambience",
            "atelier-formal-ladies": "a breathtaking embroidered raw-silk "
                "formal kameez with flowing organza dupatta, deep jewel "
                "tones with gold threadwork, palace-interior ambience",
        }.get(item["id"], f"a beautifully tailored {name}")
        return (f"Full-length editorial fashion photograph of {wearer} "
                f"wearing {garment}. {PEOPLE} {STYLE}")

    # Fabrics: sumptuous draped-textile still life.
    texture = {
        "lawn": "crisp airy white cotton lawn, gently billowing",
        "embroidered_lawn": "teal lawn with intricate raised threadwork "
            "and cutwork border, silk dupatta beside it",
        "khaddar": "earthy brown handloom khaddar with visible artisan "
            "weave",
        "dhanak": "soft dusty-rose dhanak with a subtle printed border",
        "wash_and_wear": "smooth slate-grey blended suiting, crisply "
            "folded",
        "cotton_latha": "pure white tightly-woven latha with a crisp "
            "sheen",
        "boski": "lustrous cream boski silk with liquid drape",
        "raw_silk": "structured ivory raw silk with characteristic slubs, "
            "catching golden light",
        "velvet": "deep emerald velvet with a rich directional pile",
        "organza": "sheer blush organza holding sculptural volume",
    }.get(comp, f"{design} {comp} fabric")
    return (f"Luxurious still-life photograph of {texture}, draped and "
            f"artfully arranged on a marble surface with a single soft "
            f"side light. Suggests {occasions or 'celebration'}. {STYLE}")


def generate(item: dict, key: str) -> bytes | None:
    body = json.dumps({
        "contents": [{"parts": [{"text": prompt_for(item)}]}],
        "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]},
    }).encode()
    req = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}"
        f":generateContent",
        data=body, method="POST",
        headers={"Content-Type": "application/json", "x-goog-api-key": key})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                out = json.load(r)
            for part in out["candidates"][0]["content"]["parts"]:
                if "inlineData" in part:
                    return base64.b64decode(part["inlineData"]["data"])
            return None
        except Exception as e:  # noqa: BLE001
            print(f"    retry {attempt + 1}: {type(e).__name__}: {e}")
            time.sleep(8 * (attempt + 1))
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="comma-separated item ids")
    ap.add_argument("--upload", action="store_true",
                    help="push approved previews to S3 + rewrite seeds")
    args = ap.parse_args()

    items = json.loads(SEEDS[0].read_text(encoding="utf-8"))
    if args.only:
        keep = set(args.only.split(","))
        items = [i for i in items if i["id"] in keep]

    if args.upload:
        changed = []
        for it in items:
            f = PREVIEW / f"{it['id']}.png"
            if not f.exists():
                continue
            subprocess.run(["aws", "s3", "cp", str(f),
                            f"{S3_BUCKET}/{it['id']}.png",
                            "--content-type", "image/png",
                            "--cache-control", "max-age=86400"], check=True)
            changed.append(it["id"])
        for seed in SEEDS:
            data = json.loads(seed.read_text(encoding="utf-8"))
            for it in data:
                if it["id"] in changed:
                    it["image_url"] = f"{CDN_BASE}/{it['id']}.png"
            seed.write_text(json.dumps(data, indent=1, ensure_ascii=False),
                            encoding="utf-8")
        subprocess.run(["aws", "cloudfront", "create-invalidation",
                        "--distribution-id", CLOUDFRONT_ID,
                        "--invalidation-batch",
                        'Paths={Quantity=1,Items=["/img/*"]},'
                        f"CallerReference=img-{int(time.time())}"],
                       check=True)
        print(f"uploaded {len(changed)}: {changed}")
        print("Now rebuild+push the server image and redeploy to serve "
              "the new image_urls from the API.")
        return 0

    key = _key()
    PREVIEW.mkdir(exist_ok=True)
    for it in items:
        print(f"  {it['id']} …")
        img = generate(it, key)
        if img:
            (PREVIEW / f"{it['id']}.png").write_bytes(img)
            print(f"    -> {PREVIEW / (it['id'] + '.png')}")
        else:
            print("    FAILED — no image returned")
    print("\nReview the preview folder, then run with --upload to publish.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
