# Naap — Business & Architecture Blueprint

*Reconciled 2026-09-01. This supersedes chat-drafted versions; the privacy
contradiction in earlier drafts (cloud vision + "photos never leave the
device") is resolved in §AI Architecture below.*

## Vision

A two-phase geo-arbitrage tailoring platform: bridge overseas demand for
perfectly fitting garments with Pakistan's textile and master-tailor
infrastructure — measurement friction removed by privacy-first, on-device
computer vision.

## Phasing (agreed sequencing)

| Phase | What | Status |
| --- | --- | --- |
| **1 — Measurement utility** | The trust wedge: scan → bilingual Digital Parchi → WhatsApp to your tailor. Free; later a small export micro-fee. | **Built (MVP)** — this repo |
| **1.5 — Fabric marketplace** | Unstitched fabric e-commerce for the diaspora (US/UK/CA/UAE): branded (affiliate/partnership feeds preferred over scraping) + Faisalabad/Lahore wholesale. Tri-modal checkout: One-Click Stitch (vetted tailor network), DIY fabric export (fabric + parchi shipped), or measurement-only. | After scan trust is earned |
| **2 — Luxury su misura** | EU size/drop translation (affiliate), MTM suiting stitched in Lahore/Karachi with pattern deltas → `.DXF` for CAD cutting, white-label iPad clienteling SaaS for luxury stores. | After Phase 1.5 network is battle-tested |

Rationale for sequencing: the measurement utility earns the trust and the
tape-verified accuracy data that everything downstream depends on. Marketplace
before trust inverts the wedge.

### Phase 2 design notes (2026-09-02 — NOT built; demo primitives ≠ product)

**Full strategy, scaling gates, unit economics and the atelier decision:
[PHASE2-PLAN.md](PHASE2-PLAN.md).** The fit-library data flywheel
(fit_library.py + /fit-reports) collects from day one.

The current EU size/drop mapping + drafting deltas + DXF export are
generic-block placeholders. Real luxury size translation requires a
**per-brand, per-line fit library**, because every house cuts its own
block: an EU 50 ZEGNA (classic Italian shoulder) ≠ EU 50 Saint Laurent
(slim French, high armhole) ≠ Brioni (Roman shoulder, generous drop), and
within a house the lines differ again. The library is deterministic data
(brand, line, garment, size → measured garment dimensions + ease
philosophy), built like ease.dart — declarative and reviewable — and
populated from evidence: published size charts, garments measured on a
table (the BOSS 40R method), and partner data feeds. Accumulated garment
by garment, it is the Phase 2 moat; it is acquisition work, not an
algorithm. The clienteling SaaS carries the measured BODY into stores'
own MTM programs — their blocks stay theirs.

Target roster (founder's list):

| Origin | Houses |
| --- | --- |
| France | Hermès, Chanel, Dior, Louis Vuitton, Saint Laurent, Schiaparelli |
| Italy | Loro Piana, Brunello Cucinelli, Brioni, Kiton, ZEGNA, Giorgio Armani, Valentino, Prada, Gucci, Bottega Veneta |
| UK | Burberry, Alexander McQueen |
| Spain | Loewe |

## AI architecture (agreed rules — do not violate)

1. **Measurement is on-device, always.** No cloud vision API ever receives a
   user's body photos. This is the product's differentiator and its legal
   shield (biometric data: GDPR special-category, BIPA-style laws). VLMs also
   cannot do ±2 cm metrology.
2. **No model training now.** Accuracy roadmap:
   - v1 (shipped): pretrained on-device models (pose landmarks + silhouette)
     + deterministic geometry, height-calibrated.
   - v1.5: per-measurement **calibration regressors** trained on
     (estimate, tape-measured truth, user-edit) triples from early users.
     Small, cheap, on-device. Highest-ROI ML work.
   - v2: SMPL-X body-model fitting on-device via existing pretrained research
     models converted to TFLite/Core ML. Unlocks the 3D avatar, EU size
     translation, and pattern deltas. Never train a vision foundation model.
3. **No LLM in the numeric path.** Ease, fabric-stretch adjustments, and size
   translation are deterministic tables/code (see `lib/core/ease.dart`),
   authored and reviewed with a master tailor. LLMs may *propose* table
   entries and write Urdu instructions — the runtime math stays testable code.
4. **Agent layer: no identity in prompts; DeepSeek for all prose.**
   (Revised 2026-09-02, founder decision on cost.) All agent prose runs on
   DeepSeek. The privacy line moved from provider choice to prompt
   content: **no LLM prompt may ever contain customer identity** — names,
   contacts, addresses stay out (the darzi agent receives garment, fit,
   fabric, and measurement numbers only; sourcing sees public supplier
   text). Claude remains a per-deployment opt-in for customer-adjacent
   prose (`NAAP_PREFER_CLAUDE=1` + key) if the DPA posture is wanted
   later — revisit before scale or any B2B/clienteling data enters the
   system, where identity-adjacent context becomes unavoidable.
5. **Branded catalogs via partnership/affiliate feeds, not scraping.**
   Scraping is reserved for genuinely unstructured wholesale sources.

## Product laws (privacy contract)

- Capture photos are analyzed on-device and deleted immediately
  (`shredCaptures` in the engine). Never uploaded, persisted, or logged.
- The parchi carries numbers + a generic sketch — never user imagery.
- No account required for the measurement utility; data stays in local app
  storage.
- Every AI measurement is user-editable; manual edits win.

## What is built today (Phase 1 MVP)

Flutter app (Android + iOS): guided front/side capture with ghost overlay →
ML Kit pose + segmentation engine (height-calibrated, elliptical
circumference model) → Pakistani ease tables (asan/teera/chaak,
fitted/regular/loose) → bilingual EN/Urdu PDF Digital Parchi → WhatsApp
share. Unit-tested engine; CI builds both platforms; AWS Device Farm smoke
gate on rented phones (`scripts/devicefarm_smoke.py`).

## Near-term roadmap

1. **Calibration sprint** — tape-measure validation on real bodies (family
   phones via APK/TestFlight); tune engine constants; start collecting the
   v1.5 regression dataset.
2. **Capture UX — BUILT 2026-09-02 (device validation pending)** —
   intelligent auto-capture: `live_coach.dart` runs the pose detector on
   the live camera stream (base model, throttled), judges framing
   deterministically (head/feet in frame, body span 45–94%, side-view
   hands-in-front check — prevention for the waist-inflation failure),
   requires 1.2 s of stillness, then fires the shutter itself. Live
   bilingual banner + on-device TTS voice coaching (Urdu voice when the
   device has one, English otherwise), speaks on status change only.
   Auto mode is default; the 7-second timer remains as fallback. SOTA review notes: 360° video +
   SMPL-X/WHAM under-cloth reconstruction stays v2 (must run on-device per
   privacy law — server-class today, and budget Android can't); ARCore
   ground-plane scale rejected for v1 (patchy on Pakistan's budget
   Androids; height is a parchi measurement anyway). Mesh→measurement
   extraction ref for v2: SMPL-Anthropometry.
3. **Fabric-aware ease** — stretch-coefficient table feeding the ease engine
   (deterministic; blueprint's "fit & fabric reasoning" done right).
   Measurement vocabulary (designer-tailoring review, 2026-09-02): ALL
   built — armhole/baghal + bicep on the kameez parchi; trouser waist
   (Belt) on trouser garments; belly/pait MEASURED at its own row with the
   contamination guards; jacket length, front chest, back width as drafting
   regressions; a bilingual Style section (neckline bann/collar/round/V,
   neck depth+width, sleeve cuff/plain/half, daman, pockets) persisted in
   app state and printed on the parchi; server su misura accepts the
   extended bespoke set with per-field deltas and a corpulent-balance note,
   flowing into the alteration DXF.
4. **Distribution** — app icon/branding, Play Store internal track, Codemagic
   → TestFlight for iOS testers.
5. **Phase 1.5 groundwork** — supplier conversations (affiliate feeds),
   tailor-network vetting criteria, diaspora payment rails (Stripe).
6. **Catalog IA (built 2026-09-02 from the official-catalog review)** —
   `server/app/taxonomy.py` holds the bilingual browse tree: women/men
   main+sub categories, 11 occasions (Eid→walima→bridal/groom), buying
   options (unstitched/semi/ready/custom), seasons, design types,
   availability incl. made-to-measure, fabric shopping groups, and the
   30-brand retail directory (+ Ahmad Jamal in a separate SUPPLIERS list
   pending retail verification). Key rules encoded: garment/fabric/season/
   occasion/stitching are separate product axes; the shopping fabric LABEL
   (Boski, Wash & Wear) is stored apart from disclosed composition — Boski
   does not establish silk content; piece count must state explicit
   contents (shirt+trouser vs shirt+dupatta). Served at GET /taxonomy;
   /catalog takes filter params; app shop has audience/season/occasion
   filters. Ops idea: monthly catalog review flagging changed categories
   and dead brand links.
