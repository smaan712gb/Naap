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
    garment_cm: dict[str, float] = {}
    # BODY chart semantics ("size X fits body chest Y") — how European
    # houses publish. Range midpoints in cm; garment_cm stays for flat
    # garment specs (how Pakistani houses publish). An entry uses one.
    body_cm: dict[str, float] = {}
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


# ---------------------------------------------------------------------------
# European / international houses — harvested 2026-09-03 (research agent).
# Official sites block automation; numbers come from retailer size guides
# (Nordstrom PDFs, UK retailers) and chart aggregators — every value read
# from a fetched page, ranges stored as midpoints. These are BODY charts
# ("size fits chest X"), unlike the Pakistani flat-garment specs above.
# Cross-brand law observed in the data: IT size ~= body chest cm / 2
# (Zegna, Prada, Gucci, Massimo Dutti); Saint Laurent runs a full size
# tighter at the same label.
# ---------------------------------------------------------------------------

def _body_rows(brand: str, garment: str, fit: str | None, evidence: str,
               cols: list[str], table: dict[str, list[float]],
               ) -> list[GarmentEntry]:
    return [
        GarmentEntry(
            brand=brand, garment=garment, size_label=size,
            body_cm=dict(zip(cols, vals)),
            fit_philosophy=fit, evidence=evidence, verified=True)
        for size, vals in table.items()
    ]


_CWH = ["chest", "waist", "hip"]

SEED_ENTRIES += _body_rows(
    "Zegna", "suit/jacket", "classic Italian",
    "looksize.com/brand-size-chart/ermenegildo-zegna (body cm, midpoints)",
    _CWH, {
        "IT44": [87.5, 75.5, 91.5], "IT46": [91.5, 79.5, 95.5],
        "IT48": [95.5, 83.5, 99.5], "IT50": [99.5, 87.5, 103.5],
        "IT52": [103.5, 91.5, 107.5], "IT54": [107.5, 95.5, 111.5],
        "IT56": [111.5, 99.5, 115.5], "IT58": [115.5, 103.5, 119.5],
        "IT60": [119.5, 107.5, 123.5], "IT62": [123.5, 111.5, 127.5],
    })

SEED_ENTRIES += _body_rows(
    "Prada", "suit/jacket", "slim Italian",
    "looksize.com/brand-size-chart/prada (body cm)",
    _CWH, {
        "IT44": [88, 76, 90], "IT46": [92, 80, 94], "IT48": [96, 84, 98],
        "IT50": [100, 88, 102], "IT52": [104, 92, 106],
        "IT54": [108, 96, 110], "IT56": [112, 100, 114],
        "IT58": [116, 104, 118], "IT60": [120, 108, 122],
    })

SEED_ENTRIES += _body_rows(
    "Prada", "women RTW", None,
    "looksize.com/brand-size-chart/prada (body cm)",
    _CWH, {
        "IT36": [80.4, 59, 86], "IT38": [84.4, 62.8, 89.8],
        "IT40": [88, 66, 93], "IT42": [92, 70, 97], "IT44": [96, 74, 101],
        "IT46": [100, 78, 105], "IT48": [104, 82, 109],
        "IT50": [108, 86, 113],
    })

SEED_ENTRIES += _body_rows(
    "Gucci", "suit/jacket", None,
    "looksize.com/brand-size-chart/gucci (body cm; rare shoulder data)",
    ["chest", "shoulder"], {
        "IT42": [86, 44], "IT44": [90, 45], "IT46": [94, 46],
        "IT48": [98, 47], "IT50": [102, 48], "IT52": [106, 49],
        "IT54": [110, 50], "IT56": [114, 51],
    })

SEED_ENTRIES += _body_rows(
    "Gucci", "women jacket", None,
    "looksize.com/brand-size-chart/gucci (body cm)",
    ["chest", "waist", "shoulder"], {
        "XS": [83, 65, 39], "S": [86, 68, 40], "M": [89, 71, 41],
        "L": [93, 75, 42.5], "XL": [97, 79, 44], "2XL": [101, 83, 45.5],
    })

SEED_ENTRIES += _body_rows(
    "Hugo Boss", "menswear", None,
    "hurleys.co.uk/pages/boss-size-guide (cm; arm=sleeve-from-shoulder)",
    ["chest", "waist", "hip", "sleeve"], {
        "EU44/XS": [92, 80, 95, 81.1], "EU46/S": [95, 83, 98, 83],
        "EU48/M": [98, 86, 101, 85], "EU50/L": [102, 90, 105, 87],
        "EU52/XL": [106, 94, 109, 88.9], "EU54/XXL": [110, 98, 113, 90.3],
        "EU56/3XL": [114, 102, 117, 91.8],
    })

SEED_ENTRIES += _body_rows(
    "Massimo Dutti", "menswear", "runs slightly small",
    "looksize.com/brand-size-chart/massimo-dutti (body cm)",
    ["chest"], {
        "EU44": [90], "EU46": [94], "EU48": [98], "EU50": [102],
        "EU52": [106], "EU54": [110], "EU56": [114], "EU58": [118],
    })

SEED_ENTRIES += _body_rows(
    "Saint Laurent", "men jacket", "runs one full size tight",
    "sizedepo.com yves-saint-laurent-men-jackets-pants (cm as published)",
    ["chest", "waist"], {
        "44": [80, 64], "46": [84, 68], "48": [88, 72], "50": [92, 76],
        "52": [96, 80], "54": [100, 84], "56": [102, 88], "58": [108, 92],
        "60": [112, 96],
    })

SEED_ENTRIES += _body_rows(
    "Brunello Cucinelli", "menswear", "classic",
    "nordstrom.com/sizeguides/3309_sizeguide.pdf (states body measurements)",
    ["chest", "waist"], {
        "XS/EU44": [86.4, 72.5], "S/EU46": [91.4, 77.5],
        "M/EU48": [96.5, 82.5], "L/EU50": [101.6, 87.5],
        "XL/EU52": [106.7, 92.5], "XXL/EU54": [111.8, 97.5],
        "XXXL/EU56": [116.8, 102.5],
    })

SEED_ENTRIES += _body_rows(
    "Ralph Lauren", "men tops", None,
    "mcelhinneys.com/pages/ralph-lauren-size-guide (body, midpoints)",
    ["chest", "sleeve"], {
        "S": [88.5, 82.5], "M": [99.5, 85], "L": [109.5, 87.5],
        "XL": [119.5, 90], "XXL": [129.5, 92.5],
    })

SEED_ENTRIES += _body_rows(
    "Kiton", "jacket/shirt", "wide shoulder, light construction",
    "axelsltd.com/pages/kiton-size-chart (inches conv, midpoints)",
    ["chest", "sleeve"], {
        "S/EU46-48": [94, 82.5], "M/EU48-50": [99.5, 85],
        "L/EU50-52": [109.5, 87.5], "XL/EU52-54": [114.5, 90],
        "XXL/EU54-56": [119.5, 92.5],
    })

SEED_ENTRIES += _body_rows(
    "Zara", "men tops", "runs small and slim — size up between sizes",
    "size.ly/size-chart/zara (body, midpoints)",
    ["chest"], {
        "S/EU46": [91], "M/EU48": [96], "L/EU50": [101],
        "XL/EU52": [106], "XXL/EU54": [111.5],
    })

SEED_ENTRIES += _body_rows(
    "Zara", "women tops", "runs small",
    "size.ly/size-chart/zara (body cm)",
    ["chest", "waist"], {
        "XXS/EU32": [80, 58], "XS/EU34": [82, 62], "S/EU36": [86, 66],
        "M/EU38": [90, 70], "L/EU40": [96, 76], "XL/EU42": [102, 82],
    })

SEED_ENTRIES += _body_rows(
    "Armani Collezioni", "womenswear", None,
    "nordstrom.com/sizeguides/1111_sizeguide.pdf (states body measurements)",
    _CWH, {
        "US2/IT38": [81.3, 59.7, 86.4], "US4/IT40": [83.8, 62.2, 88.9],
        "US6/IT42": [86.4, 64.8, 91.4], "US8/IT44": [88.9, 67.3, 94.0],
        "US10/IT46": [91.4, 69.9, 96.5], "US12/IT48": [95.3, 73.7, 100.3],
        "US14/IT50": [99.1, 77.5, 104.1], "US16": [102.9, 81.3, 108.0],
    })

SEED_ENTRIES += _body_rows(
    "Fendi", "women RTW (x SKIMS chart)", None,
    "us.fendiskims.com/pages/clothing-size-guide (inches conv)",
    _CWH, {
        "IT36/US0": [82.6, 63.5, 86.4], "IT38/US2": [87.6, 67.3, 92.7],
        "IT40/US4": [88.9, 68.6, 94.0], "IT42/US6": [94.0, 73.7, 100.3],
        "IT44/US8": [95.3, 74.9, 101.6], "IT46/US10": [100.3, 80.0, 106.7],
        "IT48/US12": [101.6, 81.3, 108.0], "IT50/US14": [108.0, 88.9, 113.0],
        "IT52/US16": [111.8, 96.5, 118.1],
    })

# Maria B — official per-product spec charts (GARMENT, flat, inches conv).
SEED_ENTRIES += _rows(
    "Maria B", "women kameez (pret)", "regular",
    "mariab.pk/pages/size-guide (size-chart app JSON; flat garment specs)",
    ["chest_flat", "waist_flat", "hip_flat", "shoulder", "sleeve", "length"], {
        "XS": [47.0, 41.9, 55.9, 34.3, 55.9, 132.1],
        "S": [49.5, 44.5, 58.4, 35.6, 55.9, 132.1],
        "M": [52.1, 47.0, 61.0, 36.8, 57.2, 134.6],
        "L": [57.2, 52.1, 66.0, 38.1, 58.4, 137.2],
    })

# Gaps recorded so nobody re-searches blind: Brioni, Loro Piana, Canali
# (conversion-only charts), Burberry (ranges only), Fendi menswear —
# no public measurement charts; fill via garments-on-the-table or
# partner data. Khaadi men: no chart exists at all.
