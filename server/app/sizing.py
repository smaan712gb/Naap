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
    # Extended bespoke deltas — present only when the corresponding
    # measurement was supplied (None = block default, cutter decides).
    belly_delta_cm: float | None = None
    jacket_length_delta_cm: float | None = None
    front_chest_delta_cm: float | None = None
    back_width_delta_cm: float | None = None
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
        # Extended bespoke references, classic drafting proportions.
        "belly": chest - 8.0,       # block stomach for a drop-6 figure
        "jacket_length": 72.0 + (size - 44) * 0.5,
        "front_chest": chest * 0.36,
        "back_width": chest * 0.43,
    }


def map_su_misura(chest_cm: float, waist_cm: float, hip_cm: float,
                  shoulder_cm: float, sleeve_cm: float,
                  belly_cm: float | None = None,
                  jacket_length_cm: float | None = None,
                  front_chest_cm: float | None = None,
                  back_width_cm: float | None = None) -> SuMisura:
    if not (60 <= chest_cm <= 160):
        raise ValueError(f"chest {chest_cm} cm outside supported range")
    size = min(EU_SIZES, key=lambda s: abs(s * 2.0 - chest_cm))
    drop = round((chest_cm - waist_cm) / 2.0)
    nom = _nominal(size)
    notes = []
    # European drop taxonomy: 8 slim/athletic, 7 modern/trim, 6 classic,
    # 4 portly/executive.
    if drop >= 8:
        notes.append("Drop 8 (slim/athletic) — take in back waist suppression")
    elif drop == 7:
        notes.append("Drop 7 (modern/trim) block")
    elif drop == 6:
        notes.append("Drop 6 (classic/regular) block")
    elif drop == 5:
        notes.append("Between classic and comfort — fit garment advised")
    elif drop <= 4:
        notes.append("Drop 4 (portly/executive) — ease side seams, "
                     "consider half-lining")
    if abs(chest_cm - nom["chest"]) > 4:
        notes.append("Between sizes — verify with a fitting garment")
    if belly_cm is not None and belly_cm >= chest_cm:
        # Corpulent figure: the jacket must button over the stomach, so the
        # front balance changes, not just the side seams.
        notes.append("Belly exceeds chest — cut a corpulent front balance")
    return SuMisura(
        eu_size=size,
        drop=drop,
        chest_delta_cm=round(chest_cm - nom["chest"], 1),
        waist_delta_cm=round(waist_cm - nom["waist"], 1),
        hip_delta_cm=round(hip_cm - nom["hip"], 1),
        shoulder_delta_cm=round(shoulder_cm - nom["shoulder"], 1),
        sleeve_delta_cm=round(sleeve_cm - nom["sleeve"], 1),
        belly_delta_cm=None if belly_cm is None
        else round(belly_cm - nom["belly"], 1),
        jacket_length_delta_cm=None if jacket_length_cm is None
        else round(jacket_length_cm - nom["jacket_length"], 1),
        front_chest_delta_cm=None if front_chest_cm is None
        else round(front_chest_cm - nom["front_chest"], 1),
        back_width_delta_cm=None if back_width_cm is None
        else round(back_width_cm - nom["back_width"], 1),
        notes=notes,
    )
