# Naap backend — catalog, checkout, agents, su misura

FastAPI service for Phase 1.5 (fabric marketplace, tri-modal checkout,
order orchestration) and Phase 2 (EU su misura mapping + DXF alteration
sheets). The agent layer runs on LangChain: **DeepSeek V4** for public
supplier-data extraction, **Claude** for customer-facing text (falls back
to DeepSeek with a warning if unset). Numbers never pass through a model —
the darzi agent's output is validated by a number guardrail and replaced
with a deterministic template if any measurement was altered.

## Run locally

```powershell
cd server
python -m venv .venv; .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env   # then fill in keys
uvicorn app.main:app --reload
```

Tests (no keys needed): `pytest tests -q`

## Deploy

`docker build -t naap-api . && docker run -p 8000:8000 --env-file .env -v naap-data:/data naap-api`

Any container host works (Fly.io, Railway, ECS). Set `NAAP_ADMIN_TOKEN`
(required outside dev) and front it with HTTPS.

## Environment / API keys

See `.env.example`. Summary: `DEEPSEEK_API_KEY` (sourcing agent),
`ANTHROPIC_API_KEY` (customer-facing text — recommended for prod),
`STRIPE_SECRET_KEY` (checkout; without it orders are created unpaid and a
warning is logged), `NAAP_ADMIN_TOKEN` (protects catalog/orchestration
admin endpoints).

## Endpoints

| Route | Purpose |
| --- | --- |
| `GET /health` | liveness + which keys are configured |
| `GET /catalog` | verified fabrics (public) |
| `POST /catalog`, `GET /catalog/review`, `POST /catalog/{id}/verify` | admin catalog management; agent extractions require human verification before sale |
| `POST /agents/source` | sourcing agent: raw supplier text → unverified catalog entries |
| `POST /orders` | tri-modal checkout (stitch & ship / DIY fabric / measurement-only); returns Stripe payment URL and the darzi note |
| `POST /orders/{id}/advance` | deterministic order state machine (placed → fabric_sourced → stitching → qa → shipped → delivered) |
| `POST /sizing/su-misura` | Phase 2: EU size/drop + pattern deltas (deterministic) |
| `POST /sizing/su-misura/alteration.dxf` | CAD-readable alteration sheet |
