# Darzi heuristics — observed technique, encoded rules

Source: video sessions of the founder's master tailor measuring
(2026-09-03), analysis reviewed and encoded. This file is the growing
record of HOW professional darzis measure and decide — every rule that
enters the numeric path lands here first, with its evidence, and then
becomes a deterministic constant (never an LLM call).

## Technique observations → engine consequences

| Observation | Engine consequence |
| --- | --- |
| **One-finger ease**: an index finger stays under the tape on every girth (neck, chest, waist, hip, wrist) | Professional tape ≈ skin + 1.5–2 cm. Our shape factors calibrate to darzi-tape convention, not skin-tight — that IS what a parchi number means |
| **Teera is a curved path**: the tape arcs over the upper back/neck base, seam edge to seam edge | Shoulder factor 1.25 over ML Kit joint-center span (geodesic > chord) — matches darzi 19.25" vs landmark 16.0" |
| **Chest technique**: arms lifted to seat the tape high under the armpits, then lowered before reading | Confirms our chest row just below the armpit line |
| **Pet (stomach)** at the fullest protrusion, not the trouser line | Our belly row targets the widest abdominal slice (0.92 shoulder→hip); v2 mesh slicing finds the true z-max |
| **Suran (seat)**: feet together, widest gluteal protrusion | Matches seat row definition |
| **Bicep at muscle peak; forearm just below the elbow** | forearm key added (≈0.82 × bicep, editable) |
| **Trouser thigh: pockets emptied first** | Capture instructions now say to empty pockets |
| **Calf dictates minimum paicha**: a 14.5" calf needs ≥13–13.5" opening | HARD RULE in ease.dart: trouser-family paicha stitch ≥ calf − 2.5 cm. Shalwar exempt (style number) |
| **Waistcoat length**: ends ~1.5" below the trouser waistband | Banked — applies when a waistcoat garment type ships |
| **Posture balance**: sloping vs square shoulders and spine posture change back/front length balance | v2 (needs 3D); recorded so the mesh pipeline includes front/back balance outputs |

## Cross measurements

Cross front / cross back are taped flat between the armscye creases —
our frontChest/backWidth regressions (0.36 / 0.43 × chest) use this
definition; darzi pairs will calibrate them.

## v2 bank (from the same review — NOT v1 work)

Architecture direction consistent with BLUEPRINT Phase 2 notes: SMPL-X
mesh regression (SHAPY/HMR2.0 for stills, WHAM for rotation video),
geodesic surface paths instead of chords, plane-slice circumferences at
anatomically found rows (z-max belly, z-min seat), gyroscope plumb-lock
+ A-pose validation at capture (partially shipped already via the live
coach), ARKit/ARCore floor-plane metric scale as a *supplement* to
height, cloth-displacement correction trained on Cloth3D/BUFF, and
regressors from SMPL betas to tape values trained on CAESAR/ANSUR II.
All of it stays behind the product law: on-device only, deterministic
outputs, tailor-reviewable corrections.
