"""Naap backend — catalog, tri-modal checkout, order orchestration, agents.

Run:  uvicorn app.main:app --reload   (from server/, with .env populated)

Privacy stance (docs/BLUEPRINT.md): this backend never receives user photos.
Measurements arrive only as numbers, only with explicit in-app consent, and
only for orders that need them (stitch & ship).
"""

from __future__ import annotations

import logging
import os
from typing import Optional

import httpx
from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException, Response
from pydantic import BaseModel

from . import db
from .agents.darzi import tailor_note
from .agents.llm import llm_configured
from .agents.sourcing import extract_fabrics, to_catalog_entries
from .models import (CheckoutMode, Fabric, Order, OrderCreate, OrderStatus,
                     ORDER_TRANSITIONS, utcnow)
from .dxf_export import alteration_dxf
from .taxonomy import full_taxonomy
from .sizing import SuMisura, map_su_misura

load_dotenv()
log = logging.getLogger("naap")
app = FastAPI(title="Naap API", version="0.2.0")

# The landing page (different origin) posts waitlist signups from the
# browser. Public endpoints only carry public data; admin endpoints are
# token-gated regardless of origin.
from fastapi.middleware.cors import CORSMiddleware  # noqa: E402

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    # Authorization: the admin review page sends the bearer token from the
    # browser; the token check itself stays server-side.
    allow_headers=["Content-Type", "Authorization"],
)


@app.on_event("startup")
def start_agent_team() -> None:
    """Scheduled agents (trend scout, link auditor, season planner) — see
    agents/monitor.py. Opt-in via NAAP_AGENTS_ENABLED=1 so tests and dev
    servers stay quiet; every output is a report, never a live change."""
    if os.environ.get("NAAP_AGENTS_ENABLED") != "1":
        return
    from apscheduler.schedulers.background import BackgroundScheduler
    from .agents.monitor import run_agent
    sched = BackgroundScheduler(daemon=True)
    # Staggered weekly cadence; trend scan rotates 3 brands per run to keep
    # LLM spend at pennies.
    sched.add_job(lambda: run_agent("seasonal"), "cron",
                  day_of_week="mon", hour=6)
    sched.add_job(lambda: run_agent("link-health"), "cron",
                  day_of_week="tue", hour=6)
    sched.add_job(lambda: run_agent("trends"), "cron",
                  day_of_week="wed", hour=6)
    sched.start()
    log.info("agent team scheduled (seasonal/link-health/trends)")


@app.on_event("startup")
def seed_if_empty() -> None:
    """Self-healing catalog: the container's SQLite is ephemeral, so every
    redeploy starts empty. If a bundled seed file exists and the catalog has
    no rows, load it — demo inventory survives redeploys without manual
    reseeding. Real durability (orders!) still needs external storage."""
    import json
    from pathlib import Path
    seed = Path(__file__).resolve().parent.parent / "seed_fabrics.json"
    if not seed.exists() or db.list_fabrics(verified_only=False):
        return
    n = 0
    for row in json.loads(seed.read_text(encoding="utf-8")):
        db.upsert_fabric(Fabric(**row))
        n += 1
    log.info("seeded %d fabrics from bundled seed file", n)

STITCHING_FEE_USD = {  # margin-bearing service fees per checkout mode
    CheckoutMode.stitch_and_ship: 35.0,
    CheckoutMode.diy_fabric: 0.0,
    CheckoutMode.measurement_only: 1.99,  # parchi export micro-fee
}
SHIPPING_USD = {
    CheckoutMode.stitch_and_ship: 25.0,
    CheckoutMode.diy_fabric: 20.0,
    CheckoutMode.measurement_only: 0.0,
}


def admin_only(authorization: Optional[str] = Header(None)) -> None:
    token = os.environ.get("NAAP_ADMIN_TOKEN")
    if token and authorization != f"Bearer {token}":
        raise HTTPException(401, "admin token required")
    if not token and os.environ.get("NAAP_ENV", "dev") != "dev":
        raise HTTPException(500, "NAAP_ADMIN_TOKEN must be set outside dev")


@app.get("/health")
def health() -> dict:
    return {"ok": True, "configured": llm_configured()}


# ---------------------------------------------------------------- catalog

@app.get("/taxonomy")
def taxonomy() -> dict:
    """The full browse/filter tree (categories, occasions, brands, ...)."""
    return full_taxonomy()


# ---------------------------------------------------------------- waitlist

class WaitlistRequest(BaseModel):
    email: str


_EMAIL_RE = r"^[^@\s]{1,64}@[^@\s]{1,255}\.[A-Za-z]{2,}$"


@app.post("/waitlist")
def join_waitlist(req: WaitlistRequest) -> dict:
    import re
    email = req.email.strip().lower()
    if not re.match(_EMAIL_RE, email):
        raise HTTPException(422, "invalid email")
    db.add_waitlist(email)
    return {"ok": True}


@app.get("/waitlist", dependencies=[Depends(admin_only)])
def waitlist_export() -> list[dict]:
    return db.list_waitlist()


# ------------------------------------------------------------- agent team

@app.get("/reports", dependencies=[Depends(admin_only)])
def reports(limit: int = 20) -> list[dict]:
    return db.list_reports(limit=limit)


@app.post("/agents/run/{kind}", dependencies=[Depends(admin_only)])
def run_agent_now(kind: str) -> dict:
    from .agents.monitor import run_agent
    try:
        return run_agent(kind)
    except ValueError as e:
        raise HTTPException(404, str(e)) from e


@app.get("/catalog")
def catalog(audience: Optional[str] = None,
            category_id: Optional[str] = None,
            season: Optional[str] = None,
            occasion: Optional[str] = None,
            buying_option: Optional[str] = None,
            brand_id: Optional[str] = None) -> list[Fabric]:
    items = db.list_fabrics(verified_only=True)
    if audience:
        items = [f for f in items if f.audience in (audience, None)]
    if category_id:
        items = [f for f in items if f.category_id == category_id]
    if season:
        items = [f for f in items if f.season in (season, "all-season", None)]
    if occasion:
        items = [f for f in items if not f.occasions or occasion in f.occasions]
    if buying_option:
        items = [f for f in items
                 if not f.buying_options or buying_option in f.buying_options]
    if brand_id:
        items = [f for f in items if f.brand_id == brand_id]
    return items


@app.get("/catalog/review", dependencies=[Depends(admin_only)])
def review_queue() -> list[Fabric]:
    return [f for f in db.list_fabrics(verified_only=False) if not f.verified]


@app.post("/catalog", dependencies=[Depends(admin_only)])
def add_fabric(f: Fabric) -> Fabric:
    return db.upsert_fabric(f)


@app.post("/catalog/{fabric_id}/verify", dependencies=[Depends(admin_only)])
def verify_fabric(fabric_id: str) -> Fabric:
    f = db.get_fabric(fabric_id)
    if not f:
        raise HTTPException(404, "fabric not found")
    f.verified = True
    return db.upsert_fabric(f)


class SourceRequest(BaseModel):
    supplier: str
    raw_text: str


@app.post("/agents/source", dependencies=[Depends(admin_only)])
def run_sourcing(req: SourceRequest) -> list[Fabric]:
    """Sourcing agent (DeepSeek): raw supplier text -> unverified entries."""
    extracted = extract_fabrics(req.raw_text)
    entries = to_catalog_entries(extracted, req.supplier)
    for e in entries:
        db.upsert_fabric(e)
    return entries


# ----------------------------------------------------------------- orders

class OrderResponse(BaseModel):
    order: Order
    payment_url: Optional[str] = None
    tailor_note: Optional[str] = None


def _stripe_checkout(order: Order) -> Optional[str]:
    key = os.environ.get("STRIPE_SECRET_KEY")
    if not key:
        return None  # dev mode: order proceeds unpaid, clearly logged
    resp = httpx.post(
        "https://api.stripe.com/v1/checkout/sessions",
        auth=(key, ""),
        data={
            "mode": "payment",
            "success_url": "https://naap.app/order/success",
            "cancel_url": "https://naap.app/order/cancel",
            "line_items[0][price_data][currency]": "usd",
            "line_items[0][price_data][product_data][name]":
                f"Naap order {order.id} ({order.detail.mode.value})",
            "line_items[0][price_data][unit_amount]":
                str(int(round(order.total_usd * 100))),
            "line_items[0][quantity]": "1",
            "metadata[order_id]": order.id,
        },
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()["url"]


@app.post("/orders")
def place_order(detail: OrderCreate) -> OrderResponse:
    total = STITCHING_FEE_USD[detail.mode] + SHIPPING_USD[detail.mode]
    fabric = None
    if detail.mode != CheckoutMode.measurement_only:
        if not detail.fabric_id:
            raise HTTPException(422, "fabric_id required for this mode")
        fabric = db.get_fabric(detail.fabric_id)
        if not fabric or not fabric.verified:
            raise HTTPException(404, "fabric not available")
        total += fabric.price_usd
    if detail.mode == CheckoutMode.stitch_and_ship and not detail.parchi:
        raise HTTPException(422, "stitch & ship needs the measurement parchi "
                                 "(sent only with in-app consent)")

    order = db.create_order(detail, round(total, 2))

    note = None
    if detail.mode == CheckoutMode.stitch_and_ship:
        note = tailor_note(
            detail.garment, detail.fit,
            fabric.name if fabric else (detail.fabric_note or "customer fabric"),
            detail.parchi)
        order.history.append(f"{utcnow().isoformat()} darzi note generated")
        db.save_order(order)

    try:
        payment_url = _stripe_checkout(order)
    except httpx.HTTPError as e:
        raise HTTPException(502, f"payment provider error: {e}") from e
    if payment_url is None:
        log.warning("order %s created WITHOUT payment (no STRIPE_SECRET_KEY)",
                    order.id)
    return OrderResponse(order=order, payment_url=payment_url,
                         tailor_note=note)


@app.get("/orders/{order_id}")
def get_order(order_id: str) -> Order:
    order = db.get_order(order_id)
    if not order:
        raise HTTPException(404, "order not found")
    return order


class AdvanceRequest(BaseModel):
    to: OrderStatus
    note: str = ""


@app.post("/orders/{order_id}/advance", dependencies=[Depends(admin_only)])
def advance_order(order_id: str, req: AdvanceRequest) -> Order:
    """Deterministic orchestration: only legal transitions are accepted."""
    order = db.get_order(order_id)
    if not order:
        raise HTTPException(404, "order not found")
    if req.to not in ORDER_TRANSITIONS[order.status]:
        raise HTTPException(
            409, f"illegal transition {order.status.value} -> {req.to.value}")
    order.status = req.to
    order.history.append(
        f"{utcnow().isoformat()} {req.to.value}"
        + (f" — {req.note}" if req.note else ""))
    return db.save_order(order)


# ---------------------------------------------------------------- phase 2

class SuMisuraRequest(BaseModel):
    chest_cm: float
    waist_cm: float
    hip_cm: float
    shoulder_cm: float
    sleeve_cm: float
    # Extended bespoke vocabulary — optional; None means "block default".
    belly_cm: float | None = None
    jacket_length_cm: float | None = None
    front_chest_cm: float | None = None
    back_width_cm: float | None = None


@app.post("/sizing/su-misura")
def su_misura(req: SuMisuraRequest) -> SuMisura:
    try:
        return map_su_misura(req.chest_cm, req.waist_cm, req.hip_cm,
                             req.shoulder_cm, req.sleeve_cm,
                             belly_cm=req.belly_cm,
                             jacket_length_cm=req.jacket_length_cm,
                             front_chest_cm=req.front_chest_cm,
                             back_width_cm=req.back_width_cm)
    except ValueError as e:
        raise HTTPException(422, str(e)) from e


@app.post("/sizing/su-misura/alteration.dxf")
def su_misura_dxf(req: SuMisuraRequest) -> Response:
    s = su_misura(req)
    data = alteration_dxf(s, order_id="quote")
    return Response(content=data, media_type="application/dxf",
                    headers={"Content-Disposition":
                             'attachment; filename="naap-alteration.dxf"'})
