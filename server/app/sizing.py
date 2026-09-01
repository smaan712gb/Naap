"""Phase 2 su misura engine — deterministic EU size/drop mapping and block
pattern deltas. No LLM anywhere in here (BLUEPRINT rule 3).

European jacket sizing convention:
  size  = half chest circumference in cm, rounded to the nearest even size
          (EU 44-64 covers roughly 88-128 cm chests)
  drop  = (chest - waist) / 2, rounded to nearest integer; Drop 8 = athletic,
          Drop 6 = regular, Drop 4 = comfort.

Pattern deltas are the millimeter adjustments a cutter applies to the base
block of the mapped size. Kept intentionally simple in v1: the block's
reference girths equal the size's nominal girths; deltas = actual - nominal.
"""

from __future__ import annotations

from pydantic import BaseModel

EU_SIZES = list(range(44, 66, 2))


class SuMisura(BaseModel):
    eu_size: int
    drop: int
    chest_delta_cm: float
    waist_delta_cm: float
    hip_delta_cm: float
    shoulder_delta_cm: float
    sleeve_delta_cm: float
    notes: list[str]


# Nominal reference values per EU size for a regular-drop block.
def _nominal(size: int) -> dict[str, float]:
    chest = size * 2.0
    return {
        "chest": chest,
        "waist": chest - 12.0,      # drop-6 block
        "hip": chest + 2.0,
        "shoulder": 39.0 + (size - 44) * 0.5,
        "sleeve": 59.0 + (size - 44) * 0.5,
    }


def map_su_misura(chest_cm: float, waist_cm: float, hip_cm: float,
                  shoulder_cm: float, sleeve_cm: float) -> SuMisura:
    if not (60 <= chest_cm <= 160):
        raise ValueError(f"chest {chest_cm} cm outside supported range")
    size = min(EU_SIZES, key=lambda s: abs(s * 2.0 - chest_cm))
    drop = round((chest_cm - waist_cm) / 2.0)
    nom = _nominal(size)
    notes = []
    if drop >= 8:
        notes.append("Athletic drop — take in back waist suppression")
    elif drop <= 4:
        notes.append("Comfort drop — ease side seams, consider half-lining")
    if abs(chest_cm - nom["chest"]) > 4:
        notes.append("Between sizes — verify with a fitting garment")
    return SuMisura(
        eu_size=size,
        drop=drop,
        chest_delta_cm=round(chest_cm - nom["chest"], 1),
        waist_delta_cm=round(waist_cm - nom["waist"], 1),
        hip_delta_cm=round(hip_cm - nom["hip"], 1),
        shoulder_delta_cm=round(shoulder_cm - nom["shoulder"], 1),
        sleeve_delta_cm=round(sleeve_cm - nom["sleeve"], 1),
        notes=notes,
    )
