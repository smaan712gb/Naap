"""SQLite persistence — deliberately boring. Documents are stored as JSON
columns; swap for Postgres by reimplementing this module only."""

from __future__ import annotations

import json
import os
import sqlite3
import threading
import uuid
from typing import Optional

from .models import Fabric, Order, OrderCreate, OrderStatus, utcnow

_lock = threading.Lock()
_conn: sqlite3.Connection | None = None


def _db() -> sqlite3.Connection:
    global _conn
    if _conn is None:
        path = os.environ.get("NAAP_DB_PATH", "naap.db")
        _conn = sqlite3.connect(path, check_same_thread=False)
        _conn.execute(
            "CREATE TABLE IF NOT EXISTS fabrics (id TEXT PRIMARY KEY, doc TEXT)")
        _conn.execute(
            "CREATE TABLE IF NOT EXISTS orders (id TEXT PRIMARY KEY, doc TEXT)")
        _conn.commit()
    return _conn


def reset_for_tests(path: str) -> None:
    global _conn
    if _conn is not None:
        _conn.close()
    _conn = None
    os.environ["NAAP_DB_PATH"] = path


# ---------------------------------------------------------------- fabrics

def upsert_fabric(f: Fabric) -> Fabric:
    with _lock:
        _db().execute(
            "INSERT INTO fabrics (id, doc) VALUES (?, ?) "
            "ON CONFLICT(id) DO UPDATE SET doc=excluded.doc",
            (f.id, f.model_dump_json()))
        _db().commit()
    return f


def list_fabrics(verified_only: bool = True) -> list[Fabric]:
    rows = _db().execute("SELECT doc FROM fabrics").fetchall()
    fabrics = [Fabric.model_validate(json.loads(r[0])) for r in rows]
    if verified_only:
        fabrics = [f for f in fabrics if f.verified]
    return sorted(fabrics, key=lambda f: f.name)


def get_fabric(fabric_id: str) -> Optional[Fabric]:
    row = _db().execute(
        "SELECT doc FROM fabrics WHERE id=?", (fabric_id,)).fetchone()
    return Fabric.model_validate(json.loads(row[0])) if row else None


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
    with _lock:
        _db().execute("INSERT INTO orders (id, doc) VALUES (?, ?)",
                      (order.id, order.model_dump_json()))
        _db().commit()
    return order


def save_order(order: Order) -> Order:
    with _lock:
        _db().execute("UPDATE orders SET doc=? WHERE id=?",
                      (order.model_dump_json(), order.id))
        _db().commit()
    return order


def get_order(order_id: str) -> Optional[Order]:
    row = _db().execute(
        "SELECT doc FROM orders WHERE id=?", (order_id,)).fetchone()
    return Order.model_validate(json.loads(row[0])) if row else None


def list_orders() -> list[Order]:
    rows = _db().execute("SELECT doc FROM orders").fetchall()
    return sorted((Order.model_validate(json.loads(r[0])) for r in rows),
                  key=lambda o: o.created_at, reverse=True)
