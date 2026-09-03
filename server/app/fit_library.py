"""The fit library — Phase 2's data moat, collected from day one.

Per-brand, per-line, per-size MEASURED garment dimensions, built the same
way the ease tables were built: declarative rows a human can review, each
carrying its evidence. Two sources feed it:

1. Garments measured on a table (the "BOSS 40R method").
2. Anonymous brand-size self-reports from users (see /fit-reports): a
   measured body + a brand size + a fit verdict triangulates that brand's
   block without touching the garment.

Rules: measurements are of GARMENTS, never people; brand names here are
nominative size references (legal), and never appear in Atelier product
marketing (docs/PHASE2-PLAN.md legal line).
"""

from __future__ import annotations

from pydantic import BaseModel, Field


class GarmentEntry(BaseModel):
    brand: str
    line: str | None = None          # e.g. "BOSS" vs "BOSS Orange"
    garment: str                     # jacket / trouser / shirt / kurta
    size_label: str                  # "40R", "EU 50", "M"
    # Measured flat-garment dimensions in cm, keyed by a small stable
    # vocabulary: chest, waist, hip, shoulder, sleeve, length, thigh...
    garment_cm: dict[str, float]
    fit_philosophy: str | None = None  # "classic", "slim", "unstructured"
    evidence: str                    # how we know: "measured 2026-09-02", chart URL
    verified: bool = False           # human-reviewed before it drives advice


# Row one — the founder's jacket, the method's proof of concept.
# (Owner-fit corroboration: wearer's body chest ~102-107 cm per collar/
# drop inference; garment measured values to be filled at next session
# with the jacket on the table — placeholders carry the chart values.)
SEED_ENTRIES: list[GarmentEntry] = [
    GarmentEntry(
        brand="BOSS",
        garment="jacket",
        size_label="40R",
        garment_cm={"chest_flat_x2": 110.0, "shoulder": 45.5,
                    "sleeve": 64.0, "back_length": 74.0},
        fit_philosophy="slim",
        evidence="US 40R nominal block (chart); to re-measure on the table",
        verified=False,
    ),
]

# ---------------------------------------------------------------------------
# Pakistani premium brands — official published charts, harvested
# 2026-09-03 from the brands' own pages/APIs/CDN images (research agent;
# every number chart-verified, inches → cm ×2.54). ALL are GARMENT
# measurements; "chest_flat" is the flat width — double it for the
# garment's circumference. Values per size follow the column order given
# in COLS for each table.
# ---------------------------------------------------------------------------

def _rows(brand: str, garment: str, fit: str, evidence: str,
          cols: list[str], table: dict[str, list[float]],
          ) -> list[GarmentEntry]:
    return [
        GarmentEntry(
            brand=brand, garment=garment, size_label=size,
            garment_cm=dict(zip(cols, vals)),
            fit_philosophy=fit, evidence=evidence, verified=True)
        for size, vals in table.items()
    ]


_KURTA_COLS = ["chest_flat", "shoulder", "sleeve", "length", "collar"]

SEED_ENTRIES += _rows(
    "Junaid Jamshed", "kurta/kameez", "regular",
    "brand CDN chart image MEN_KURTA_REGULAR_FIT_ID133 (junaidjamshed.com)",
    _KURTA_COLS, {
        "XS": [55.9, 43.2, 58.4, 100.3, 36.8],
        "S": [58.4, 44.5, 59.7, 103.5, 38.1],
        "M": [61.0, 47.0, 61.6, 107.3, 40.6],
        "L": [63.5, 49.5, 63.5, 111.8, 43.2],
        "XL": [68.6, 52.1, 64.8, 114.9, 45.7],
        "XXL": [72.4, 54.6, 66.0, 118.1, 47.0],
    })

SEED_ENTRIES += _rows(
    "Sapphire", "kurta", "regular",
    "pk.sapphireonline.pk Product-SizeChart?cid=kurta-shalwar",
    _KURTA_COLS[:4], {
        "XS": [54.6, 41.3, 61.0, 101.6],
        "S": [57.2, 43.8, 62.2, 104.1],
        "M": [59.7, 46.4, 63.5, 106.7],
        "L": [62.2, 48.9, 64.8, 109.2],
        "XL": [64.8, 51.4, 66.0, 111.8],
    })

# Sapphire is the only PK house publishing an explicit slim-fit delta:
# −2.5" chest, −0.5" sleeve, same shoulder/length.
SEED_ENTRIES += _rows(
    "Sapphire", "kurta", "slim",
    "pk.sapphireonline.pk Product-SizeChart?cid=kurtas",
    _KURTA_COLS[:4], {
        "XS": [48.3, 41.3, 59.7, 101.6],
        "S": [50.8, 43.8, 61.0, 104.1],
        "M": [53.3, 46.4, 62.2, 106.7],
        "L": [55.9, 48.9, 63.5, 109.2],
        "XL": [58.4, 51.4, 64.8, 111.8],
    })

SEED_ENTRIES += _rows(
    "Gul Ahmed", "kurta/kameez", "regular",
    "gulahmedshop.com product Fit & Sizing (regular-fit kurta/suits pages)",
    _KURTA_COLS[:4], {
        "S": [54.6, 44.5, 61.0, 104.1],
        "M": [57.2, 47.0, 62.2, 108.0],
        "L": [59.7, 49.5, 63.5, 111.8],
        "XL": [62.2, 52.1, 64.8, 114.3],
    })

SEED_ENTRIES += _rows(
    "Alkaram", "kameez", "regular",
    "alkaramstudio.com size-chart API (Kameez & Shalwar Regular Fit)",
    _KURTA_COLS, {
        "XS": [55.9, 41.9, 57.2, 99.1, 40.6],
        "S": [58.4, 44.5, 58.4, 103.5, 40.6],
        "M": [61.0, 47.0, 62.2, 108.0, 43.2],
        "L": [63.5, 49.5, 63.5, 111.8, 45.7],
        "XL": [68.6, 52.1, 64.8, 114.9, 48.3],
        "XXL": [71.1, 53.3, 66.0, 116.8, 50.8],
    })

SEED_ENTRIES += _rows(
    "Khaadi", "women kurta", "regular",
    "us.khaadi.com per-product size guide (long cambric kurta)",
    ["chest_flat", "shoulder", "sleeve", "length"], {
        "XS (8)": [45.7, 34.3, 53.3, 106.7],
        "S (10)": [48.3, 35.6, 55.9, 111.8],
        "M (12)": [50.8, 36.8, 55.9, 111.8],
        "L (14)": [55.9, 38.1, 58.4, 111.8],
        "XL (16)": [61.0, 40.6, 58.4, 111.8],
    })

SEED_ENTRIES += _rows(
    "Khaadi", "women pants", "regular",
    "us.khaadi.com per-product size guide (cambric pants)",
    ["waist", "hip_flat", "length", "thigh"], {
        "XS (8)": [67.3, 50.8, 86.4, 31.8],
        "S (10)": [71.1, 53.3, 88.9, 33.0],
        "M (12)": [74.9, 55.9, 91.4, 34.3],
        "L (14)": [78.7, 59.7, 94.0, 36.2],
        "XL (16)": [83.8, 63.5, 96.5, 38.1],
    })


class FitReport(BaseModel):
    """Anonymous brand-size self-report — one flywheel row. Numbers only,
    never identity (product law: no PII beside measurements)."""
    brand: str = Field(min_length=1, max_length=60)
    line: str | None = Field(default=None, max_length=60)
    garment: str = Field(default="jacket", max_length=30)
    size_label: str = Field(min_length=1, max_length=20)
    fit_verdict: str = Field(default="true-to-size", max_length=30)
    # Optional reporter body numbers (cm) to triangulate the block.
    body_chest_cm: float | None = Field(default=None, ge=40, le=200)
    body_waist_cm: float | None = Field(default=None, ge=40, le=200)
