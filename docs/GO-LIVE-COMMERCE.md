# Commerce go-live runbook

Everything below the line is BUILT and deployed. What remains is three
founder inputs; each line says exactly what to do and what it unlocks.

## 1. Payments — ~20 minutes, $0

1. dashboard.stripe.com → create account (or sign in) → Developers →
   API keys → copy the **Secret key** (starts `sk_test_` in test mode).
2. Developers → Webhooks → Add endpoint:
   - URL: `https://naap-api.m9vte9fmk66k4.us-west-2.cs.amazonlightsail.com/stripe/webhook`
   - Event: `checkout.session.completed`
   - Copy the **Signing secret** (`whsec_...`).
3. In `server/deploy.json` (and `server/.env`), add:
   ```
   STRIPE_SECRET_KEY=sk_test_...
   STRIPE_WEBHOOK_SECRET=whsec_...
   ```
4. Tell Claude "stripe keys are in" → server redeploy → checkout links
   appear on every order, and paid orders flip to **PAID** in the admin
   console automatically. Test with card 4242 4242 4242 4242.
5. Real money later = switch to the `sk_live_` pair, nothing else changes.

## 2. Durable orders — ~10 minutes, $0 (Neon) or ~$15/mo (Lightsail)

SQLite in the container is wiped on every redeploy. The db layer already
speaks Postgres — one env var flips it:

- **Free path:** neon.tech → sign up → create project `naap` →
  copy the connection string (`postgresql://...`).
- **AWS path:** Lightsail → Databases → PostgreSQL, smallest ($15/mo).

Add to deploy.json/.env: `NAAP_DATABASE_URL=postgresql://...` → redeploy.
Tables self-create; orders, waitlist, fit reports and calibration pairs
survive every redeploy from then on.

## 3. The two phone calls

- **Supplier**: send docs/partners/SUPPLIER-BRIEF.md (what we buy, what
  we need from them, how the swatch box works).
- **Tailor (Imran)**: send docs/partners/TAILOR-AGREEMENT.md (rates
  table to fill in, turnaround, remake guarantee, payout).

## Ops loop (already live)

Order placed → admin console (getnaap.com/admin) shows it with payment
flag → advance through the state machine with one-click buttons
(placed → fabric_sourced → stitching → qa → shipped → delivered);
every transition is validated server-side and logged to order history.
