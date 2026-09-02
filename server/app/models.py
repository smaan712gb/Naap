"""Pydantic models shared across the Naap backend.

The measurement vocabulary mirrors lib/core/models/measurements.dart in the
Flutter app — keep the key names in sync (they travel in order payloads).
"""

from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


# ---------------------------------------------------------------- fabrics

class FabricComposition(str, Enum):
    # Summer
    lawn = "lawn"
    embroidered_lawn = "embroidered_lawn"
    cotton = "cotton"
    chiffon = "chiffon"
    # Transitional
    viscose = "viscose"
    wash_and_wear = "wash_and_wear"
    # Winter
    khaddar = "khaddar"
    linen = "linen"
    marina = "marina"
    dhanak = "dhanak"
    pashmina = "pashmina"
    wool_suiting = "wool_suiting"
    velvet = "velvet"
    # Weddings / bridal
    raw_silk = "raw_silk"
    karandi = "karandi"
    jamawar = "jamawar"
    organza = "organza"
    net_tissue = "net_tissue"
    # Eid / festive
    jacquard = "jacquard"
    cotton_net = "cotton_net"
    # Modern
    stretch_knit = "stretch_knit"
    other = "other"


class FabricSource(str, Enum):
    branded_feed = "branded_feed"      # affiliate/partner feed (preferred)
    wholesale_sourced = "wholesale_sourced"  # sourcing-agent extraction
    manual = "manual"


class Fabric(BaseModel):
    id: str
    name: str
    brand: Optional[str] = None
    composition: FabricComposition = FabricComposition.other
    description: str = ""
    price_usd: float = Field(ge=0)
    meters: float = Field(gt=0, description="cut length sold, in meters")
    image_url: Optional[str] = None
    source: FabricSource = FabricSource.manual
    verified: bool = Field(
        default=False,
        description="sourcing-agent extractions stay unverified until a "
                    "human reviews them; only verified fabrics are sold")
    supplier_ref: Optional[str] = None


# ---------------------------------------------------------------- orders

class CheckoutMode(str, Enum):
    stitch_and_ship = "stitch_and_ship"  # fabric + vetted tailor + delivery
    diy_fabric = "diy_fabric"            # fabric + parchi PDF, own tailor
    measurement_only = "measurement_only"  # parchi export only


class OrderStatus(str, Enum):
    placed = "placed"
    fabric_sourced = "fabric_sourced"
    stitching = "stitching"
    qa = "qa"
    shipped = "shipped"
    delivered = "delivered"
    cancelled = "cancelled"


# Deterministic state machine — the ONLY legal transitions. The orchestrator
# refuses anything else; no LLM is involved in state changes.
ORDER_TRANSITIONS: dict[OrderStatus, list[OrderStatus]] = {
    OrderStatus.placed: [OrderStatus.fabric_sourced, OrderStatus.cancelled],
    OrderStatus.fabric_sourced: [OrderStatus.stitching, OrderStatus.shipped,
                                 OrderStatus.cancelled],
    OrderStatus.stitching: [OrderStatus.qa, OrderStatus.cancelled],
    OrderStatus.qa: [OrderStatus.stitching, OrderStatus.shipped],
    OrderStatus.shipped: [OrderStatus.delivered],
    OrderStatus.delivered: [],
    OrderStatus.cancelled: [],
}


class ParchiLine(BaseModel):
    key: str            # measurement key name, e.g. "chest"
    english: str
    urdu: str
    tailor_term: str
    body_cm: float
    stitch_cm: float


class OrderCreate(BaseModel):
    fabric_id: Optional[str] = None   # None for measurement_only
    mode: CheckoutMode
    garment: str = "shalwarKameez"
    fit: str = "regular"
    fabric_note: Optional[str] = None
    customer_name: str
    customer_email: str
    ship_to: Optional[str] = None
    # Measurements are sent ONLY with explicit in-app consent, and only for
    # modes that need them (stitch_and_ship). Never images.
    parchi: list[ParchiLine] = []


class Order(BaseModel):
    id: str
    created_at: datetime
    status: OrderStatus = OrderStatus.placed
    detail: OrderCreate
    history: list[str] = []
    total_usd: float = 0.0


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


# ---------------------------------------------------------- sourcing agent

class ExtractedFabric(BaseModel):
    """Structured output schema the sourcing agent must produce."""
    name: str
    brand: Optional[str] = None
    composition: FabricComposition = FabricComposition.other
    description: str = ""
    price_usd: Optional[float] = None
    meters: Optional[float] = None
    supplier_ref: Optional[str] = None


class SourcingResult(BaseModel):
    fabrics: list[ExtractedFabric]
