"""Backend tests — everything that runs without API keys.

Agent LLM calls are exercised only via their guardrails/fallbacks here;
live-model integration is a separate (key-requiring) concern.
"""

import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from fastapi.testclient import TestClient

from app import db
from app.agents.darzi import fallback_note, numbers_intact
from app.dxf_export import alteration_dxf
from app.models import CheckoutMode, Fabric, ParchiLine
from app.sizing import map_su_misura


@pytest.fixture()
def client(tmp_path, monkeypatch):
    db.reset_for_tests(str(tmp_path / "test.db"))
    # Import FIRST: app.main runs load_dotenv() at import time, which would
    # re-inject a developer's server/.env secrets after any earlier scrub.
    from app.main import app
    monkeypatch.setenv("NAAP_ENV", "dev")
    monkeypatch.delenv("NAAP_ADMIN_TOKEN", raising=False)
    monkeypatch.delenv("STRIPE_SECRET_KEY", raising=False)
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    monkeypatch.delenv("DEEPSEEK_API_KEY", raising=False)
    return TestClient(app)


def sample_lines():
    return [
        ParchiLine(key="chest", english="Chest", urdu="چھاتی",
                   tailor_term="Chaati", body_cm=96.0, stitch_cm=106.0),
        ParchiLine(key="waist", english="Waist", urdu="کمر",
                   tailor_term="Kamar", body_cm=84.0, stitch_cm=94.0),
    ]


# ------------------------------------------------------------- darzi guard

def test_numbers_intact_accepts_verbatim():
    note = fallback_note("Shalwar Kameez", "regular", "Lawn", sample_lines())
    assert numbers_intact(note, sample_lines())


def test_numbers_intact_rejects_altered_measurement():
    note = fallback_note("Shalwar Kameez", "regular", "Lawn", sample_lines())
    assert not numbers_intact(note.replace("106.0", "160.0"), sample_lines())


def test_numbers_intact_rejects_missing_measurement():
    note = fallback_note("Shalwar Kameez", "regular", "Lawn", sample_lines())
    assert not numbers_intact(note.replace("94.0", ""), sample_lines())


# ---------------------------------------------------------------- sizing

def test_su_misura_maps_regular_body():
    s = map_su_misura(chest_cm=100, waist_cm=88, hip_cm=102,
                      shoulder_cm=41, sleeve_cm=61)
    assert s.eu_size == 50
    assert s.drop == 6
    assert s.chest_delta_cm == 0.0


def test_su_misura_athletic_drop_note():
    s = map_su_misura(chest_cm=104, waist_cm=86, hip_cm=100,
                      shoulder_cm=43, sleeve_cm=62)
    assert s.drop >= 8
    assert any("Athletic" in n for n in s.notes)


def test_su_misura_rejects_out_of_range():
    with pytest.raises(ValueError):
        map_su_misura(30, 30, 30, 30, 30)


def test_su_misura_extended_fields_default_to_none():
    s = map_su_misura(chest_cm=100, waist_cm=88, hip_cm=102,
                      shoulder_cm=41, sleeve_cm=61)
    assert s.belly_delta_cm is None
    assert s.jacket_length_delta_cm is None


def test_su_misura_extended_bespoke_deltas():
    s = map_su_misura(chest_cm=100, waist_cm=88, hip_cm=102,
                      shoulder_cm=41, sleeve_cm=61,
                      belly_cm=95, jacket_length_cm=76,
                      front_chest_cm=38, back_width_cm=45)
    # Nominals for EU 50: belly 92, jacket 75, front 36, back 43.
    assert s.belly_delta_cm == 3.0
    assert s.jacket_length_delta_cm == 1.0
    assert s.front_chest_delta_cm == 2.0
    assert s.back_width_delta_cm == 2.0


def test_order_quote_breakdown(client):
    _seed_fabric(client)
    q = client.post("/orders/quote", json={
        "mode": "stitch_and_ship", "fabric_id": "lawn1"}).json()
    assert q["fabric_usd"] == 28.0
    assert q["service_usd"] == 35.0
    assert q["shipping_usd"] == 25.0
    assert q["total_usd"] == 88.0
    q2 = client.post("/orders/quote",
                     json={"mode": "measurement_only"}).json()
    assert q2["total_usd"] == 1.99


def test_fit_report_flywheel(client):
    r = client.post("/fit-reports", json={
        "brand": "ZEGNA", "garment": "jacket", "size_label": "EU 50",
        "fit_verdict": "true-to-size", "body_chest_cm": 102.0})
    assert r.status_code == 200
    rows = client.get("/fit-reports").json()
    assert rows[0]["brand"] == "ZEGNA"
    # No identity fields exist on the model at all.
    assert "email" not in rows[0] and "name" not in rows[0]
    # Garbage body numbers rejected.
    assert client.post("/fit-reports", json={
        "brand": "X", "size_label": "M",
        "body_chest_cm": 999}).status_code == 422


def test_fit_library_seed_entries(client):
    rows = client.get("/fit-library").json()
    assert any(e["brand"] == "BOSS" and e["size_label"] == "40R"
               for e in rows)


def test_seasonal_agent_is_deterministic(client):
    import datetime
    from app.agents.monitor import season_for_month, seasonal_focus
    assert season_for_month(12) == "winter"
    assert season_for_month(6) == "summer"
    assert season_for_month(3) == "mid-season"
    _seed_fabric(client)  # a lawn (summer implied untagged -> all-season)
    winter = Fabric(id="v1", name="Velvet Test", composition="velvet",
                    price_usd=99, meters=5, verified=True, season="winter")
    client.post("/catalog", json=winter.model_dump())
    doc = seasonal_focus(datetime.date(2026, 12, 15))
    assert doc["current_season"] == "winter"
    assert "Velvet Test" in doc["live_for_current"]


def test_agent_run_endpoint_writes_report(client):
    r = client.post("/agents/run/seasonal")
    assert r.status_code == 200
    reps = client.get("/reports").json()
    assert reps and reps[0]["kind"] == "seasonal"
    assert client.post("/agents/run/nonsense").status_code == 404


def test_waitlist_signup_and_admin_export(client):
    assert client.post("/waitlist",
                       json={"email": "Tester@Example.com"}).status_code == 200
    # Duplicate is idempotent, invalid rejected.
    assert client.post("/waitlist",
                       json={"email": "tester@example.com"}).status_code == 200
    assert client.post("/waitlist",
                       json={"email": "not-an-email"}).status_code == 422
    rows = client.get("/waitlist").json()  # dev mode: no token required
    assert [r["email"] for r in rows] == ["tester@example.com"]


def test_taxonomy_serves_full_tree(client):
    t = client.get("/taxonomy").json()
    cat_ids = {c["id"] for c in t["categories"]}
    assert "w-bridal" in cat_ids and "m-wedding" in cat_ids
    assert len(t["brands"]) == 30
    assert any(o["id"] == "walima" for o in t["occasions"])
    # Bilingual: every category carries Urdu.
    assert all(c["ur"] for c in t["categories"])


def test_catalog_filters_by_taxonomy(client):
    _seed_fabric(client)
    winter = Fabric(id="kh1", name="Winter Khaddar", composition="khaddar",
                    price_usd=30, meters=5, verified=True,
                    audience="women", season="winter",
                    occasions=["daily"], buying_options=["unstitched"])
    client.post("/catalog", json=winter.model_dump())
    names = [f["name"]
             for f in client.get("/catalog?season=winter").json()]
    assert "Winter Khaddar" in names
    # The untagged seed fabric survives filters (untagged = shown).
    assert "Premium Lawn 5m" in names
    names = [f["name"]
             for f in client.get("/catalog?occasion=bridal").json()]
    assert "Winter Khaddar" not in names  # tagged daily-only


def test_su_misura_corpulent_front_balance_note():
    s = map_su_misura(chest_cm=100, waist_cm=98, hip_cm=104,
                      shoulder_cm=41, sleeve_cm=61, belly_cm=104)
    assert any("corpulent" in n for n in s.notes)


def test_alteration_dxf_contains_deltas():
    s = map_su_misura(101.3, 88.2, 103.0, 41.5, 60.8)
    data = alteration_dxf(s, "abc123").decode("utf-8", "replace")
    assert "EU 50" in data
    assert "CHEST" in data


# ----------------------------------------------------------------- API

def _seed_fabric(client):
    f = Fabric(id="lawn1", name="Premium Lawn 5m", composition="lawn",
               price_usd=28.0, meters=5.0, verified=True)
    r = client.post("/catalog", json=f.model_dump())
    assert r.status_code == 200
    return f


def test_catalog_hides_unverified(client):
    _seed_fabric(client)
    unv = Fabric(id="x1", name="Mystery cloth", price_usd=5, meters=5,
                 verified=False)
    client.post("/catalog", json=unv.model_dump())
    names = [f["name"] for f in client.get("/catalog").json()]
    assert "Premium Lawn 5m" in names
    assert "Mystery cloth" not in names


def test_order_measurement_only_needs_no_fabric(client):
    r = client.post("/orders", json={
        "mode": "measurement_only",
        "customer_name": "Test", "customer_email": "t@example.com",
    })
    assert r.status_code == 200
    body = r.json()
    assert body["order"]["total_usd"] == pytest.approx(1.99)
    assert body["payment_url"] is None  # no stripe key in dev


def test_order_stitch_and_ship_requires_parchi(client):
    _seed_fabric(client)
    r = client.post("/orders", json={
        "mode": "stitch_and_ship", "fabric_id": "lawn1",
        "customer_name": "Test", "customer_email": "t@example.com",
    })
    assert r.status_code == 422


def test_order_stitch_and_ship_full_flow(client):
    _seed_fabric(client)
    r = client.post("/orders", json={
        "mode": "stitch_and_ship", "fabric_id": "lawn1",
        "garment": "Shalwar Kameez", "fit": "regular",
        "customer_name": "Test", "customer_email": "t@example.com",
        "ship_to": "London",
        "parchi": [l.model_dump() for l in sample_lines()],
    })
    assert r.status_code == 200
    body = r.json()
    # fabric 28 + stitching 35 + shipping 25
    assert body["order"]["total_usd"] == pytest.approx(88.0)
    # no keys in test env -> deterministic fallback note, numbers verbatim
    assert "106.0" in body["tailor_note"]

    oid = body["order"]["id"]
    ok = client.post(f"/orders/{oid}/advance", json={"to": "fabric_sourced"})
    assert ok.status_code == 200
    bad = client.post(f"/orders/{oid}/advance", json={"to": "delivered"})
    assert bad.status_code == 409  # illegal jump refused


def test_su_misura_endpoint(client):
    r = client.post("/sizing/su-misura", json={
        "chest_cm": 100, "waist_cm": 88, "hip_cm": 102,
        "shoulder_cm": 41, "sleeve_cm": 61})
    assert r.status_code == 200
    assert r.json()["eu_size"] == 50
