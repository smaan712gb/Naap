"""DXF bridge v0 — emits a CAD-readable alteration sheet for a su misura
order: the mapped block size and every pattern delta as dimensioned text on
standard layers, importable by Lectra/Gerber/CLO3D operators.

This is deliberately an ALTERATION SHEET, not generated pattern geometry —
cutting files for production come from the manufacturer's own graded blocks;
v0 hands their operator exact deltas in the format their CAD reads.
"""

from __future__ import annotations

import io

import ezdxf

from .sizing import SuMisura


def alteration_dxf(s: SuMisura, order_id: str) -> bytes:
    doc = ezdxf.new("R2010")
    msp = doc.modelspace()
    doc.layers.add("NAAP_META", color=3)
    doc.layers.add("NAAP_DELTAS", color=1)

    msp.add_text(
        f"NAAP SU MISURA ALTERATION SHEET — ORDER {order_id}",
        dxfattribs={"layer": "NAAP_META", "height": 8},
    ).set_placement((0, 100))
    msp.add_text(
        f"BASE BLOCK: EU {s.eu_size}  DROP {s.drop}",
        dxfattribs={"layer": "NAAP_META", "height": 6},
    ).set_placement((0, 88))

    deltas = [
        ("CHEST", s.chest_delta_cm),
        ("WAIST", s.waist_delta_cm),
        ("HIP", s.hip_delta_cm),
        ("SHOULDER", s.shoulder_delta_cm),
        ("SLEEVE", s.sleeve_delta_cm),
        # Extended bespoke deltas appear only when supplied.
        *([("BELLY", s.belly_delta_cm)]
          if s.belly_delta_cm is not None else []),
        *([("JACKET LEN", s.jacket_length_delta_cm)]
          if s.jacket_length_delta_cm is not None else []),
        *([("FRONT CHEST", s.front_chest_delta_cm)]
          if s.front_chest_delta_cm is not None else []),
        *([("BACK WIDTH", s.back_width_delta_cm)]
          if s.back_width_delta_cm is not None else []),
    ]
    y = 74.0
    for name, cm in deltas:
        sign = "+" if cm >= 0 else ""
        msp.add_text(
            f"{name}: {sign}{cm:.1f} CM",
            dxfattribs={"layer": "NAAP_DELTAS", "height": 5},
        ).set_placement((0, y))
        y -= 10
    for i, note in enumerate(s.notes):
        msp.add_text(
            f"NOTE: {note.upper()}",
            dxfattribs={"layer": "NAAP_META", "height": 4},
        ).set_placement((0, y - i * 8))

    buf = io.StringIO()
    doc.write(buf)
    return buf.getvalue().encode("utf-8")
