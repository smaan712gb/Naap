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
