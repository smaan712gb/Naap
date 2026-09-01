"""Seed the catalog with starter fabrics (verified) for demos/testing.
Run from server/:  python seed.py
"""

from app import db
from app.models import Fabric, FabricComposition, FabricSource

STARTERS = [
    Fabric(id="lawn-classic-white", name="Classic White Lawn — 5m suit",
           composition=FabricComposition.lawn, price_usd=24.0, meters=5.0,
           description="Airy summer lawn, unstitched. Ideal for everyday "
                       "shalwar kameez.", source=FabricSource.manual,
           verified=True),
    Fabric(id="khaddar-winter-brown", name="Winter Khaddar — Earthy Brown",
           composition=FabricComposition.khaddar, price_usd=32.0, meters=5.0,
           description="Handloom-style khaddar with a warm hand feel.",
           source=FabricSource.manual, verified=True),
    Fabric(id="washwear-slate", name="Wash & Wear — Slate Grey",
           composition=FabricComposition.wash_and_wear, price_usd=38.0,
           meters=5.0,
           description="Crease-resistant blend, the daily-wear workhorse.",
           source=FabricSource.manual, verified=True),
    Fabric(id="rawsilk-ivory", name="Raw Silk — Ivory (occasion)",
           composition=FabricComposition.raw_silk, price_usd=95.0, meters=5.0,
           description="Structured raw silk for weddings and events. Rigid "
                       "weave — Naap adds extra ease automatically.",
           source=FabricSource.manual, verified=True),
]

if __name__ == "__main__":
    for f in STARTERS:
        db.upsert_fabric(f)
    print(f"seeded {len(STARTERS)} fabrics into the catalog")
