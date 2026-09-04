"""Persistence — deliberately boring. Documents are stored as JSON columns.

Two backends behind one four-method interface (execute/commit):
- SQLite (default): zero-config dev/demo. EPHEMERAL in the container —
  every redeploy starts empty (catalog self-seeds; orders do NOT survive).
- Postgres: set NAAP_DATABASE_URL (e.g. a free Neon instance or Lightsail
  managed DB) and orders/waitlist/reports become durable. Same SQL — the
  wrapper only translates placeholders.
"""

from __future__ import annotations

import json
import os
import sqlite3
import threading
import uuid
from typing import Optional

from .models import Fabric, Order, OrderCreate, OrderStatus, utcnow

_lock = threading.Lock()
_conn = None


class _Postgres:
    """Minimal adapter exposing the sqlite3-ish surface db.py uses."""

    def __init__(self, url: str):
        import psycopg
        self._c = psycopg.connect(url, autocommit=False)

    def execute(self, sql: str, params: tuple = ()):  # noqa: ANN001
        cur = self._c.cursor()
        cur.execute(sql.replace("?", "%s"), params)
        return cur

    def commit(self) -> None:
        self._c.commit()

    def close(self) -> None:
        self._c.close()


def _db():
    global _conn
    if _conn is None:
        url = os.environ.get("NAAP_DATABASE_URL")
        if url:
            _conn = _Postgres(url)
        else:
            path = os.environ.get("NAAP_DB_PATH", "naap.db")
            _conn = sqlite3.connect(path, check_same_thread=False)
        _conn.execute(
            "CREATE TABLE IF NOT EXISTS fabrics (id TEXT PRIMARY KEY, doc TEXT)")
        _conn.execute(
            "CREATE TABLE IF NOT EXISTS orders (id TEXT PRIMARY KEY, doc TEXT)")
        _conn.execute(
            "CREATE TABLE IF NOT EXISTS waitlist "
            "(email TEXT PRIMARY KEY, created TEXT)")
        _conn.execute(
            "CREATE TABLE IF NOT EXISTS reports "
            "(id TEXT PRIMARY KEY, kind TEXT, created TEXT, doc TEXT)")
        _conn.execute(
            "CREATE TABLE IF NOT EXISTS fit_reports "
            "(id TEXT PRIMARY KEY, created TEXT, doc TEXT)")
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


# ---------------------------------------------------------------- waitlist

def add_waitlist(email: str) -> None:
    with _lock:
        _db().execute(
            "INSERT INTO waitlist (email, created) VALUES (?, ?) "
            "ON CONFLICT(email) DO NOTHING",
            (email, utcnow().isoformat()))
        _db().commit()


def list_waitlist() -> list[dict]:
    rows = _db().execute(
        "SELECT email, created FROM waitlist ORDER BY created").fetchall()
    return [{"email": r[0], "created": r[1]} for r in rows]


# ---------------------------------------------------------------- reports

def add_report(kind: str, doc: dict) -> str:
    rid = uuid.uuid4().hex[:12]
    with _lock:
        _db().execute(
            "INSERT INTO reports (id, kind, created, doc) VALUES (?,?,?,?)",
            (rid, kind, utcnow().isoformat(), json.dumps(doc)))
        _db().commit()
    return rid


def add_fit_report(doc: dict) -> str:
    rid = uuid.uuid4().hex[:12]
    with _lock:
        _db().execute(
            "INSERT INTO fit_reports (id, created, doc) VALUES (?,?,?)",
            (rid, utcnow().isoformat(), json.dumps(doc)))
        _db().commit()
    return rid


def list_fit_reports(limit: int = 500) -> list[dict]:
    rows = _db().execute(
        "SELECT id, created, doc FROM fit_reports "
        "ORDER BY created DESC LIMIT ?", (limit,)).fetchall()
    return [{"id": r[0], "created": r[1], **json.loads(r[2])} for r in rows]


def list_reports(limit: int = 20) -> list[dict]:
    rows = _db().execute(
        "SELECT id, kind, created, doc FROM reports "
        "ORDER BY created DESC LIMIT ?", (limit,)).fetchall()
    return [{"id": r[0], "kind": r[1], "created": r[2],
             "doc": json.loads(r[3])} for r in rows]
