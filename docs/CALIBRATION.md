# Calibration protocol — tuning the engine to ±2–4 cm

The engine's tunable constants live at the top of
[engine.dart](../lib/core/measure/engine.dart): three circumference *shape
factors* (chest/waist/seat) and four torso *row positions*. They ship with
anthropometric starting points; real tape data from family testers tunes
them. Everything here is deterministic — no LLM touches the numeric path.

## Session protocol (per subject, ~15 minutes)

1. **Capture first.** Run the full Naap flow: profile (exact height — measure
   it against a wall, don't trust memory), front + side photos per the
   guided capture. Fitted clothing; empty pockets; hair off the shoulders.
2. **Record the AI numbers immediately**, before any manual edits — once a
   value is edited it becomes `source=manual` and is useless for
   calibration. Copy each value off the results screen into the CSV
   (`app_cm` column).
3. **Tape-measure the same body**, same session (bodies change through the
   day). Snug tape, not tight; over the same clothing. Record as `tape_cm`.

| Measurement | Tailor term | Tape technique |
|---|---|---|
| neck | Gala | around the base of the neck, one finger inside the tape |
| shoulder | Teera | bone tip to bone tip across the back |
| chest | Chaati | fullest point, tape level, natural breath out |
| waist | Kamar | natural waist (bend sideways — the crease), relaxed belly |
| hip | Hip | fullest point of the seat, feet together |
| sleeveLength | Baazu | shoulder bone tip to wrist bone, arm slightly bent |
| bicep | Dola | fullest point of the upper arm, arm relaxed |
| wrist | Kalai | around the wrist bone |
| kameezLength | Qameez Lambai | shoulder-neck point down to the wanted hem |
| shalwarLength | Shalwar Lambai | waist to ankle bone, standing straight |
| inseam | — | crotch to ankle bone along the inner leg |
| thigh | Raan | fullest point of the thigh |
| ankleOpening | Paincha | around the ankle where the paincha sits |
| hem | Ghera | this is a style value — skip unless comparing sweep |

4. **Fill the CSV** — copy
   [calibration_template.csv](../scripts/calibration_template.csv) to
   `calibration_<subject>_<date>.csv` (keep these out of git if the subject
   wants; they contain body measurements + a name — use initials).

## Analysis

```powershell
python scripts\calibrate.py calibration_*.csv
```

Per measurement it reports bias (app − tape; positive = app reads big), MAE,
and a verdict against the ±4 cm v1 ceiling. With ≥3 samples of
chest/waist/hip it prints ready-to-paste replacement shape factors (current
value × mean tape/app ratio). Length errors point at the row-position
constants instead — move those while eyeballing the capture overlay.

After applying constants: `flutter analyze && flutter test`, bump nothing
else, re-capture one subject to confirm the direction of change, commit with
the calibration CSVs' stats (not the CSVs) in the message.

Pool data across subjects and phones — the constants are population-level,
not per-user (per-user learning is the v1.5 roadmap item).
