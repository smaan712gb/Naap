"""Pricing engine — every commercial number in ONE reviewable file.

Values marked TO-FILL are placeholders awaiting real inputs (Imran's
rate table, a courier account, supplier price list). The engine and the
quote breakdown are final; go-live is editing this file, nothing else.

Rule: deterministic tables only — same law as the ease engine.
"""

from __future__ import annotations

from .models import CheckoutMode

# --------------------------------------------------------------- stitching
# Per-garment service fee (tailor rate + Naap margin), USD.
# TO-FILL: derive from Imran's signed rate table
# (docs/partners/TAILOR-AGREEMENT.md) as  rate_pkr / fx * (1 + margin).
# Current numbers are launch placeholders on the old flat-$35 scale.
STITCH_FEE_USD: dict[str, float] = {
    "shalwarKameez": 35.0,
    "kurtaPajama": 30.0,
    "ladiesSuit": 45.0,
    "trousersShirt": 60.0,
    "suitTwoPiece": 120.0,
}
DEFAULT_STITCH_FEE_USD = 35.0
MEASUREMENT_EXPORT_FEE_USD = 1.99  # parchi export micro-fee (mode 3)

# ---------------------------------------------------------------- shipping
# Zone x weight-bracket, USD. TO-FILL with real courier quotes
# (DHL/FedEx Pakistan export or a consolidator). Brackets in grams.
# Weight estimate: fabric meters x ~250 g/m unless the item carries gsm.
SHIP_ZONES: dict[str, str] = {  # ISO-ish country hints -> zone
    "US": "americas", "CA": "americas",
    "GB": "europe", "UK": "europe", "DE": "europe", "FR": "europe",
    "IT": "europe", "ES": "europe", "NL": "europe", "IE": "europe",
    "AE": "gulf", "SA": "gulf", "QA": "gulf", "KW": "gulf", "OM": "gulf",
    "BH": "gulf",
    "PK": "pakistan",
    "AU": "apac", "NZ": "apac", "SG": "apac", "MY": "apac",
}
DEFAULT_ZONE = "americas"
SHIP_RATE_USD: dict[str, list[tuple[int, float]]] = {
    # zone: [(max_grams, usd), ...] first bracket that fits wins.
    "americas": [(500, 22.0), (1000, 28.0), (2000, 38.0), (4000, 55.0)],
    "europe": [(500, 20.0), (1000, 26.0), (2000, 35.0), (4000, 50.0)],
    "gulf": [(500, 14.0), (1000, 18.0), (2000, 25.0), (4000, 38.0)],
    "apac": [(500, 24.0), (1000, 30.0), (2000, 42.0), (4000, 60.0)],
    "pakistan": [(500, 3.0), (1000, 4.0), (2000, 6.0), (4000, 9.0)],
}
GRAMS_PER_METER_DEFAULT = 250

# ------------------------------------------------------------------ duties
# Estimated import duties/taxes shown to the customer (DDP-style
# honesty). TO-FILL after the broker/courier decision: the US ended
# de-minimis for postal imports in Aug 2025, so US-bound textile parcels
# now attract duty — founder must confirm the effective rate for the HS
# codes we ship (woven cotton/silk fabric, made-up garments) and whether
# we ship DDP (we collect here) or DAP (courier collects from customer).
# 0.0 keeps the line hidden until decided.
DUTIES_PCT: dict[str, float] = {
    "americas": 0.0,  # TO-FILL — likely material post-de-minimis
    "europe": 0.0,    # TO-FILL (UK/EU VAT + duty over thresholds)
    "gulf": 0.0,
    "apac": 0.0,
    "pakistan": 0.0,
}

# ------------------------------------------------------------- processing
# Card processing (Stripe ~2.9% + $0.30) surfaced as its own honest line.
PROCESSING_PCT = 0.029
PROCESSING_FIXED_USD = 0.30


def zone_for(country_hint: str | None) -> str:
    if not country_hint:
        return DEFAULT_ZONE
    return SHIP_ZONES.get(country_hint.strip().upper()[:2], DEFAULT_ZONE)


def shipping_usd(zone: str, grams: int) -> float:
    for max_g, usd in SHIP_RATE_USD[zone]:
        if grams <= max_g:
            return usd
    return SHIP_RATE_USD[zone][-1][1]


def quote(mode: CheckoutMode, *, fabric_usd: float = 0.0,
          fabric_meters: float = 0.0, fabric_gsm: int | None = None,
          garment: str = "shalwarKameez",
          country_hint: str | None = None) -> dict:
    """Full honest breakdown. Keys are stable API surface for the app."""
    if mode == CheckoutMode.measurement_only:
        service = MEASUREMENT_EXPORT_FEE_USD
        ship = 0.0
        duties = 0.0
    else:
        service = (STITCH_FEE_USD.get(garment, DEFAULT_STITCH_FEE_USD)
                   if mode == CheckoutMode.stitch_and_ship else 0.0)
        z = zone_for(country_hint)
        gpm = (fabric_gsm or 0) and max(120, int((fabric_gsm or 0) * 1.4)) \
            or GRAMS_PER_METER_DEFAULT
        grams = max(300, int(fabric_meters * gpm))
        ship = shipping_usd(z, grams)
        duties = round((fabric_usd + service) * DUTIES_PCT[zone_for(
            country_hint)], 2)
    subtotal = fabric_usd + service + ship + duties
    processing = round(subtotal * PROCESSING_PCT + PROCESSING_FIXED_USD, 2) \
        if subtotal > 0 else 0.0
    return {
        "fabric_usd": round(fabric_usd, 2),
        "service_usd": round(service, 2),
        "shipping_usd": round(ship, 2),
        "duties_usd": duties,
        "processing_usd": processing,
        "total_usd": round(subtotal + processing, 2),
    }
