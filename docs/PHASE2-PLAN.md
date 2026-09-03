# Phase 2 — Luxury Su Misura: strategy, scaling, monetization

> **FOUNDER DIRECTIVE (2026-09-03): monetization is DEFERRED.** The
> product runs free-first until it is feature-complete, habit-forming,
> and demonstrably viral across every user type. The measurement tool is
> free FOREVER for individuals AND tailors — revenue only ever enters
> through commerce (fabric, stitch-and-ship, atelier garments, and much
> later data/SaaS), never through the measuring itself. Signals that
> reopen the monetization conversation: repeat scans per user, parchis
> shared per week, active tailor nodes, and QR-driven installs (the
> viral coefficient). Growth features in service of this: scan history,
> tailor shop branding on parchis, parchi QR install loop, women's
> garment coverage.

Decision memo, 2026-09-02. Founder asked: fit-library/translation play, or
enter the business directly with custom-made garments in the styles people
covet, at a fraction of the price. **Recommendation: both, sequenced — the
MTM atelier is the revenue engine, size translation is the free customer
funnel, and the fit library is the moat that both of them feed.**

## The three paths, honestly compared

| Path | What it is | Revenue | Risk | Verdict |
| --- | --- | --- | --- | --- |
| **A. Size translation (affiliate)** | "You're a 50 in ZEGNA, 52 in Prada" → affiliate link | 5–12% affiliate fees; thin | Low; but zero moat without B | Keep as FREE funnel feature |
| **B. Fit library (data/SaaS)** | Per-brand/line measured fit data; license to stores/platforms; clienteling SaaS | SaaS $/seat later; slow to sell | Data acquisition is years | Build passively from day one; monetize LAST |
| **C. Inspired-by MTM atelier** | Made-to-measure garments in coveted style archetypes, cut to the customer's Naap scan, stitched in Lahore/Karachi | $299–$549 per garment at 45–60% gross margin | Execution: MTM-grade tailoring, QC, returns | **The business.** Gate behind Phase 1.5 network proof |

Why C wins as the engine: it uses everything already built (measurement
engine, parchi, fabric sourcing, Pakistani stitching arbitrage, order
machine) and every garment shipped generates fit-library data for free.
A and B alone leave the margin with the brands.

## The legal line for path C (non-negotiable)

Selling garments *in the style of* luxury houses is legal — garment
designs are largely unprotected. What is FORBIDDEN, ever:

- No logos, monograms, branded hardware, or labels (LV toile, Gucci
  webbing, Burberry check are trademarks — never reproduce).
- No brand names in product marketing ("Fendi-style", "Zegna replica" =
  trademark use; instead: "the unstructured Italian blazer", "the
  minimalist French trouser").
- Brand names MAY appear in the private fit-translation feature ("your
  size in ZEGNA") — nominative use for size reference is standard.
- Positioning is "made for YOUR body, in fabric you chose" — the honest
  superiority (fit + fabric agency) is the pitch, not imitation.

## Product: the Naap Atelier

Style **archetypes**, not brand copies — each an internal block we own:

| Archetype | Reference world | Fabric (our catalog) | Target price | Landed cost est. |
| --- | --- | --- | --- | --- |
| Unstructured Italian blazer | Boglioli/Cucinelli world | wool suiting, linen | $349 | ~$140 |
| Classic 2-pc suit | ZEGNA/Brioni world | wool suiting | $549 | ~$230 |
| Minimalist trouser | The Row/SLP world | wool, cotton latha | $149 | ~$55 |
| Luxe kurta capsule | festive menswear | boski, jamawar | $199 | ~$70 |
| Occasion shalwar kameez | premium ethnic | raw silk, velvet | $249 | ~$90 |

Landed cost = fabric + MTM stitching (Lahore master rate 3–5× the
TAILOR-NETWORK.md daily-wear card) + QC + DHL. Gross margins 55–60%.

## Scaling gates (each gate is evidence, not a date)

1. **Gate 0 (now):** Phase 1 accuracy proven on tape; parchi cuttable
   without phone calls. Fit-library passive collection STARTS NOW (below).
2. **Gate 1:** Phase 1.5 network proof — 10 shalwar-kameez orders through
   vetted tailors, ≥8 first-pass QC. Proves logistics + QC + payments.
3. **Gate 2 — Atelier pilot:** ONE archetype (luxe kurta — closest to
   existing tailor skill), 10 garments to friendly diaspora customers at
   cost. Requires: one suit-grade master (sample-tested per
   TAILOR-NETWORK.md at MTM tolerance ±1 cm), our own block for the
   archetype, fit-guarantee policy (free remake — budget 15% remake rate
   at pilot).
4. **Gate 3 — Capsule launch:** 3 archetypes, waitlist-first drop,
   $299–549. Remake rate must be <8% to scale ads.
5. **Gate 4 — Suiting + clienteling:** 2-pc suits (hardest), then the
   iPad SaaS for boutiques once OUR OWN fit data proves the value.

## The data flywheel (starts today, costs nothing)

Every touchpoint feeds the fit library:

- **Brand-size self-reports:** at checkout and (optional) after a scan —
  "What size do you wear in [brand]? How does it fit?" One measured body
  + one brand size + a fit verdict = one calibration row for that brand's
  block. A thousand users = a fit library no one can buy.
- **Garment measuring (the BOSS 40R method):** every physical garment we
  or friends own gets measured into `server/app/fit_library.py` — brand,
  line, size, garment dimensions. Row one exists (BOSS 40R).
- **Atelier remakes:** every remake tells us exactly where our block was
  wrong for a body type. Painful data is the best data.

## Monetization summary

1. Phase 1: free (trust wedge) → parchi export micro-fee later.
2. Phase 1.5: fabric margin + $35 stitch-and-ship fee.
3. Phase 2C: Atelier garments, 55–60% gross margin — the P&L driver.
4. Phase 2A: affiliate fees on "shop your size" links — funnel that pays
   for itself.
5. Phase 2B: fit-data licensing / clienteling SaaS — sold only after the
   Atelier proves the data works. Last, largest, most defensible.

## Built today (code)

- `server/app/fit_library.py` — the per-brand/line/size measured-garment
  schema + first entries; served read-only at `/fit-library` (admin) so
  entries are reviewable like the ease tables.
- `POST /fit-reports` — anonymous brand-size self-reports (brand, size,
  fit verdict, optional chest/waist of the reporter in cm — numbers only,
  no identity), stored for the flywheel; admin export.
- Blueprint updated to point here.

Next in code (needs app UI round): the optional brand-size question in
checkout + post-scan prompt feeding /fit-reports.

## European MTM spec review (2026-09-03) — silhouettes & associate mode

Audit against the detailed EU/MTM requirements confirmed the
architecture: body truth (naap) is already decoupled from style layers
(ease/fit/fabric/silhouette), the parchi's Body vs Stitch IS the
dual-layer (biometric truth / production spec) export, the drop system
ships (4/6/7/8 taxonomy in sizing.py), and the calf→paicha floor is the
anatomical feasibility enforcer. Built as regressions today: over-arm
(chest +10 cm) and knee. Banked for the Atelier trouser pilot — the
declarative silhouette table (all values are style-layer offsets over
the immutable body):

| Profile | Knee ease | Opening | Break/length |
| --- | --- | --- | --- |
| Wide/flared | +7.5–13 cm | 46–61 cm | full break, +2.5 cm |
| Relaxed/straight | +5–9 cm | 41–46 cm | medium break |
| Slim/tapered | +2.5–4 cm | 35.5–39 cm | slight break |
| Skinny | +1.3 cm | max(calf, instep diagonal)+1.3 cm | no break/cropped |

Gated v2 (needs the mesh): shoulder-slope angle → pad thickness,
posture profiling → front/back balance, 3D digital twin preview. Gated
on business: associate iPad AR/LiDAR capture, interactive trend sliders,
Gerber/Lectra/AAMA-DXF integration (our DXF is an annotation sheet, not
an AAMA pattern payload — the real integration is built WITH the first
cutting house, not speculatively).
