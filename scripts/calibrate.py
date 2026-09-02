#!/usr/bin/env python3
"""Compare Naap AI measurements against tape measurements and suggest
engine-constant updates.

Usage:
    python scripts/calibrate.py calibration_*.csv

Input CSVs follow scripts/calibration_template.csv. Lines starting with '#'
are ignored. All math is deterministic (product law: no LLM in the numeric
path). The script reads the CURRENT shape factors out of
lib/core/measure/engine.dart and prints suggested replacements for the
circumference constants; lengths get a bias report only, because length
errors usually mean a row-position constant (_k*RowT) needs moving, which a
human should do while looking at capture overlays.
"""

from __future__ import annotations

import csv
import re
import statistics
import sys
from collections import defaultdict
from pathlib import Path

ENGINE = Path(__file__).resolve().parent.parent / "lib" / "core" / "measure" / "engine.dart"

VALID = {
    "neck", "shoulder", "chest", "waist", "trouserWaist", "belly", "hip",
    "sleeveLength", "bicep", "armhole", "wrist", "kameezLength",
    "shalwarLength", "inseam", "thigh", "ankleOpening", "hem",
    "jacketLength", "frontChest", "backWidth",
}

# measurement -> engine.dart shape-factor constant it calibrates
SHAPE_CONSTANTS = {
    "chest": "_kChestShape",
    "waist": "_kWaistShape",
    "hip": "_kSeatShape",
}

V1_TARGET_CM = 4.0  # v1 accuracy goal: within ±2–4 cm


def read_engine_constant(name: str) -> float | None:
    text = ENGINE.read_text(encoding="utf-8")
    m = re.search(rf"const double {re.escape(name)} = ([0-9.]+);", text)
    return float(m.group(1)) if m else None


def main(paths: list[str]) -> int:
    rows: dict[str, list[tuple[float, float]]] = defaultdict(list)
    n_bad = 0
    for p in paths:
        with open(p, newline="", encoding="utf-8") as fh:
            for rec in csv.DictReader(
                    r for r in fh if not r.lstrip().startswith("#")):
                key = (rec.get("measurement") or "").strip()
                try:
                    app_cm = float(rec["app_cm"])
                    tape_cm = float(rec["tape_cm"])
                except (KeyError, TypeError, ValueError):
                    n_bad += 1
                    continue
                if key not in VALID or app_cm <= 0 or tape_cm <= 0:
                    n_bad += 1
                    continue
                rows[key].append((app_cm, tape_cm))

    if not rows:
        print("no usable rows found — see scripts/calibration_template.csv")
        return 1
    if n_bad:
        print(f"(skipped {n_bad} malformed/unknown rows)\n")

    print(f"{'measurement':<16}{'n':>3}{'bias cm':>9}{'MAE cm':>8}"
          f"{'tape/app':>10}  verdict")
    print("-" * 60)
    suggestions = []
    for key in sorted(rows, key=lambda k: -len(rows[k])):
        pairs = rows[key]
        biases = [app - tape for app, tape in pairs]
        maes = [abs(b) for b in biases]
        ratios = [tape / app for app, tape in pairs]
        bias, mae = statistics.mean(biases), statistics.mean(maes)
        ratio = statistics.mean(ratios)
        verdict = "OK" if mae <= V1_TARGET_CM else "TUNE"
        print(f"{key:<16}{len(pairs):>3}{bias:>+9.1f}{mae:>8.1f}"
              f"{ratio:>10.3f}  {verdict}")

        const = SHAPE_CONSTANTS.get(key)
        if const and len(pairs) >= 3:
            current = read_engine_constant(const)
            if current is not None:
                suggestions.append((const, current, round(current * ratio, 3)))

    if suggestions:
        print("\nSuggested lib/core/measure/engine.dart updates "
              "(needs >=3 samples per line):")
        for const, old, new in suggestions:
            marker = "  (unchanged)" if abs(new - old) < 0.005 else ""
            print(f"  const double {const} = {new};  // was {old}{marker}")
        print("\nApply, run `flutter test`, then re-capture to confirm.")
    else:
        print("\nNo shape-factor suggestions yet — need >=3 samples of "
              "chest/waist/hip.")

    lengths = [k for k in rows
               if k not in SHAPE_CONSTANTS
               and statistics.mean(abs(a - t) for a, t in rows[k]) > V1_TARGET_CM]
    if lengths:
        print(f"\nLength-type measurements out of tolerance: "
              f"{', '.join(sorted(lengths))}.\n"
              "These calibrate via row-position constants (_kChestRowT, "
              "_kWaistRowT, _kSeatRowT, _kCrotchRowT) — adjust while "
              "comparing the capture overlay against the subject.")
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1:]))
