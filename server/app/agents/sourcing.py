"""Sourcing agent — turns unstructured wholesale supplier text into
structured catalog entries (LangChain + DeepSeek V4, structured output).

Scope, per docs/BLUEPRINT.md: PUBLIC supplier data only. Extractions land
in the catalog as `verified=False` and are not sellable until a human
reviews them (POST /catalog/{id}/verify). Branded catalogs should arrive
via affiliate/partner feeds, not this agent.
"""

from __future__ import annotations

import uuid

from ..models import ExtractedFabric, Fabric, FabricSource, SourcingResult
from .llm import sourcing_llm

_SYSTEM = """You extract fabric listings from raw Pakistani textile supplier
text (WhatsApp broadcast messages, price lists, marketplace pages — Urdu,
English, or Roman Urdu). Extract every distinct sellable fabric you can see.

Rules:
- price_usd: convert PKR to USD at roughly 280 PKR/USD when a PKR price is
  given; leave null when there is no price. Do not invent prices.
- meters: the cut length being sold (a "suit" of unstitched lawn is usually
  ~ 5 meters; use the text's own numbers when present, else null).
- composition: map local names — lawn→lawn, khaddar→khaddar, karandi→karandi,
  "wash n wear"→wash_and_wear, "khaam reshm"/raw silk→raw_silk,
  boski/silk→raw_silk, "pattu"/wool→wool_suiting — else other.
- supplier_ref: any item/article code in the text.
Never fabricate items that are not in the text."""


def extract_fabrics(raw_text: str) -> list[ExtractedFabric]:
    llm = sourcing_llm().with_structured_output(SourcingResult)
    result: SourcingResult = llm.invoke(
        [("system", _SYSTEM), ("human", raw_text)])
    return result.fabrics


def to_catalog_entries(extracted: list[ExtractedFabric],
                       supplier: str) -> list[Fabric]:
    out = []
    for e in extracted:
        if e.price_usd is None or e.meters is None:
            # Not sellable without a price and a cut length; still record it
            # for the review queue with zeroed commercials.
            pass
        out.append(Fabric(
            id=uuid.uuid4().hex[:10],
            name=e.name,
            brand=e.brand,
            composition=e.composition,
            description=e.description,
            price_usd=e.price_usd or 0.0,
            meters=e.meters or 5.0,
            source=FabricSource.wholesale_sourced,
            verified=False,  # human review gate — always
            supplier_ref=e.supplier_ref or supplier,
        ))
    return out
