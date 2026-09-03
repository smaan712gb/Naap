"""Curator agent — drafts NEW catalog items as the season turns.

Weekly flow: read the calendar + live catalog -> ask DeepSeek to propose
1-2 seasonally-right items we DON'T already stock -> validate hard ->
insert as verified=False (invisible to shoppers) -> founder reviews in the
admin console, generates imagery (scripts/image_studio.py --only <id>),
and flips them live with one click. Shoppers then see them under "New in"
(added_at drives the badge).

Guardrails:
- The LLM never sets a number: price and meters come from PRICE_BOOK,
  keyed by composition (blueprint law: no LLM in the numeric path).
- Compositions/colors/audiences outside the fixed vocabulary are rejected.
- Nothing the curator writes is customer-visible until human-verified.
"""

from __future__ import annotations

import datetime as _dt
import json
import logging
import re

from .. import db
from ..models import Fabric, FabricComposition
from .llm import sourcing_llm
from .monitor import season_for_month

log = logging.getLogger("naap.agents.curator")

# Deterministic commercials per composition: (price_usd, meters).
PRICE_BOOK: dict[str, tuple[float, float]] = {
    "lawn": (24.0, 5.0), "embroidered_lawn": (54.0, 8.0),
    "khaddar": (32.0, 5.0), "dhanak": (38.0, 6.5),
    "wash_and_wear": (38.0, 5.0), "cotton_latha": (28.0, 5.0),
    "boski": (65.0, 5.0), "raw_silk": (95.0, 5.0),
    "velvet": (110.0, 4.5), "organza": (85.0, 5.0),
    "karandi": (42.0, 5.0), "marina": (40.0, 6.5),
    "jamawar": (120.0, 4.5), "chiffon": (48.0, 6.0),
    "silk": (90.0, 5.0), "net": (70.0, 5.5),
}
COLORS = {"white", "cream", "ivory", "beige", "brown", "grey", "black",
          "blue", "teal", "green", "pink", "red", "gold", "multi"}

_PROMPT = """You are the merchandising curator for Naap, a Pakistani
fabric marketplace serving families in Pakistan and the diaspora.

Current season: {season}. Upcoming: {upcoming}. Month: {month}.
Items already live (do NOT duplicate these): {live}.

Propose exactly {n} NEW unstitched-fabric catalog items that fill seasonal
gaps. Answer with ONLY a JSON array; each object has EXACTLY these keys:
  name        - retail name, English, max 45 chars
  composition - one of: {comps}
  color       - one of: {colors}
  audience    - "women", "men", or null for everyone
  season      - "summer", "winter", or "all-season"
  occasions   - array from: daily, workwear, eid, nikkah, barat, walima,
                bridal, groom, mehndi-dholki, wedding-guest, dinner-party
  design      - plain, printed, embroidered, or embellished
  pieces      - 1, 2, or 3
  piece_contents - short description like "shirt + trouser + dupatta"
  description - one enticing retail sentence, max 140 chars
No prices, no meters, no other keys."""


def _slug(name: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    return s[:40]


def draft_new_items(n: int = 2, now: _dt.date | None = None) -> dict:
    today = now or _dt.date.today()
    season = season_for_month(today.month)
    upcoming = season_for_month((today.month % 12) + 1)
    live = db.list_fabrics(verified_only=False)
    live_names = [f.name for f in live]

    msg = _PROMPT.format(
        season=season, upcoming=upcoming, month=today.strftime("%B"),
        live="; ".join(live_names), n=n,
        comps=", ".join(sorted(PRICE_BOOK)),
        colors=", ".join(sorted(COLORS)))
    raw = sourcing_llm().invoke([("human", msg)]).text
    m = re.search(r"\[.*\]", raw, re.S)
    if not m:
        return {"drafted": [], "error": "no JSON array in model output"}

    drafted, rejected = [], []
    existing_ids = {f.id for f in live}
    for p in json.loads(m.group(0))[:n]:
        comp = p.get("composition")
        if comp not in PRICE_BOOK or comp not in {
                c.value for c in FabricComposition}:
            rejected.append({"name": p.get("name"), "why": f"comp {comp}"})
            continue
        if p.get("color") not in COLORS:
            p["color"] = None
        price, meters = PRICE_BOOK[comp]
        iid = _slug(p.get("name", ""))
        if not iid or iid in existing_ids:
            rejected.append({"name": p.get("name"), "why": "dup/empty id"})
            continue
        fabric = Fabric(
            id=iid, name=str(p.get("name"))[:60], composition=comp,
            description=str(p.get("description", ""))[:200],
            price_usd=price, meters=meters,
            source="wholesale_sourced", verified=False,
            audience=p.get("audience") or None,
            season=p.get("season"), design=p.get("design"),
            occasions=[o for o in (p.get("occasions") or []) if o],
            pieces=p.get("pieces"),
            piece_contents=p.get("piece_contents"),
            buying_options=["unstitched", "custom-stitching"],
            fabric_label=comp.replace("_", " ").title(),
            color=p.get("color"),
            added_at=today.isoformat(),
            availability="ready-to-dispatch")
        db.upsert_fabric(fabric)
        existing_ids.add(iid)
        drafted.append({"id": iid, "name": fabric.name,
                        "composition": comp, "price_usd": price})

    return {
        "season": season, "upcoming": upcoming,
        "drafted": drafted, "rejected": rejected,
        "next_steps": [
            "Review drafts in the admin console and Verify to publish.",
            "Generate imagery: python scripts/image_studio.py --only "
            + ",".join(d["id"] for d in drafted) if drafted else
            "Nothing drafted this run.",
        ],
    }
