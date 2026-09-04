"""DynamoDB backend — same public surface as db.py, zero monthly cost.

Single-table design on the always-free tier (25 GB + 25 provisioned
RCU/WCU): every record is {pk, sk, doc, created} where pk partitions by
record type ("fabric", "order", "waitlist", "report", "fitreport") and
sk is the record id. Documents stay JSON, exactly as in the SQL backends.

Activated when NAAP_DYNAMO_TABLE is set (db.py re-exports this module).
The container needs AWS credentials with access to that one table
(AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY env, scoped IAM user).
Provision once with scripts/provision_dynamo.py.
"""

from __future__ import annotations

import json
import os
import uuid
from typing import Optional

import boto3
from boto3.dynamodb.conditions import Key

from .models import Fabric, Order, OrderCreate, OrderStatus, utcnow

_table = None


def _t():
    global _table
    if _table is None:
        _table = boto3.resource(
            "dynamodb",
            region_name=os.environ.get("AWS_REGION", "us-west-2"),
        ).Table(os.environ["NAAP_DYNAMO_TABLE"])
    return _table


def _put(pk: str, sk: str, doc: str) -> None:
    _t().put_item(Item={"pk": pk, "sk": sk, "doc": doc,
                        "created": utcnow().isoformat()})


def _get(pk: str, sk: str) -> Optional[str]:
    item = _t().get_item(Key={"pk": pk, "sk": sk}).get("Item")
    return item["doc"] if item else None


def _query(pk: str) -> list[dict]:
    items: list[dict] = []
    kwargs = {"KeyConditionExpression": Key("pk").eq(pk)}
    while True:
        page = _t().query(**kwargs)
        items.extend(page.get("Items", []))
        lek = page.get("LastEvaluatedKey")
        if not lek:
            return items
        kwargs["ExclusiveStartKey"] = lek


def reset_for_tests(path: str) -> None:  # signature parity; tests use SQLite
    raise RuntimeError("tests must run on the SQLite backend")


# ---------------------------------------------------------------- fabrics

def upsert_fabric(f: Fabric) -> Fabric:
    _put("fabric", f.id, f.model_dump_json())
    return f


def list_fabrics(verified_only: bool = True) -> list[Fabric]:
    fabrics = [Fabric.model_validate(json.loads(i["doc"]))
               for i in _query("fabric")]
    if verified_only:
        fabrics = [f for f in fabrics if f.verified]
    return sorted(fabrics, key=lambda f: f.name)


def get_fabric(fabric_id: str) -> Optional[Fabric]:
    doc = _get("fabric", fabric_id)
    return Fabric.model_validate(json.loads(doc)) if doc else None


# ---------------------------------------------------------------- orders

def create_order(detail: OrderCreate, total_usd: float) -> Order:
    order = Order(
        id=uuid.uuid4().hex[:12],
        created_at=utcnow(),
        status=OrderStatus.placed,
        detail=detail,
        history=[f"{utcnow().isoformat()} placed"],
        total_usd=total_usd,
    )
    _put("order", order.id, order.model_dump_json())
    return order


def save_order(order: Order) -> Order:
    _put("order", order.id, order.model_dump_json())
    return order


def get_order(order_id: str) -> Optional[Order]:
    doc = _get("order", order_id)
    return Order.model_validate(json.loads(doc)) if doc else None


def list_orders() -> list[Order]:
    orders = [Order.model_validate(json.loads(i["doc"]))
              for i in _query("order")]
    return sorted(orders, key=lambda o: o.created_at, reverse=True)


# ---------------------------------------------------------------- waitlist

def add_waitlist(email: str) -> None:
    if _get("waitlist", email) is None:
        _put("waitlist", email, "{}")


def list_waitlist() -> list[dict]:
    return sorted(
        ({"email": i["sk"], "created": i["created"]}
         for i in _query("waitlist")),
        key=lambda r: r["created"])


# ---------------------------------------------------------------- reports

def add_report(kind: str, doc: dict) -> str:
    rid = uuid.uuid4().hex[:12]
    _put("report", rid, json.dumps({"kind": kind, "doc": doc}))
    return rid


def list_reports(limit: int = 20) -> list[dict]:
    rows = sorted(_query("report"), key=lambda i: i["created"], reverse=True)
    out = []
    for i in rows[:limit]:
        rec = json.loads(i["doc"])
        out.append({"id": i["sk"], "kind": rec.get("kind"),
                    "created": i["created"], "doc": rec.get("doc")})
    return out


def add_fit_report(doc: dict) -> str:
    rid = uuid.uuid4().hex[:12]
    _put("fitreport", rid, json.dumps(doc))
    return rid


def list_fit_reports(limit: int = 500) -> list[dict]:
    rows = sorted(_query("fitreport"), key=lambda i: i["created"],
                  reverse=True)
    return [{"id": i["sk"], "created": i["created"],
             **json.loads(i["doc"])} for i in rows[:limit]]
