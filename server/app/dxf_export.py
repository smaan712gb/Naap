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
    # Drawn delta bars (audit 2026-09-04: text-only sheets open "empty" in
    # a CAD viewport — operators expect geometry). Each delta renders as a
    # horizontal bar from a zero axis, scaled 10 units/cm, with its label:
    # readable at a glance in any viewer, still plain data on layers.
    doc.layers.add("NAAP_DIAGRAM", color=5)
    y = 70.0
    x0 = 90.0  # zero axis
    scale = 10.0
    msp.add_line((x0, y + 6), (x0, y - len(deltas) * 12), dxfattribs={
        "layer": "NAAP_DIAGRAM"})
    for name, cm in deltas:
        sign = "+" if cm >= 0 else ""
        msp.add_text(
            f"{name}: {sign}{cm:.1f} CM",
            dxfattribs={"layer": "NAAP_DELTAS", "height": 5},
        ).set_placement((0, y))
        if abs(cm) > 0.05:
            x1 = x0 + cm * scale
            msp.add_lwpolyline(
                [(x0, y + 1), (x1, y + 1), (x1, y + 4), (x0, y + 4),
                 (x0, y + 1)],
                dxfattribs={"layer": "NAAP_DIAGRAM"})
        y -= 12
    msp.add_text("SCALE: 10 UNITS = 1 CM DELTA",
                 dxfattribs={"layer": "NAAP_DIAGRAM", "height": 3}
                 ).set_placement((x0, y + 4))
    for i, note in enumerate(s.notes):
        msp.add_text(
            f"NOTE: {note.upper()}",
            dxfattribs={"layer": "NAAP_META", "height": 4},
        ).set_placement((0, y - 8 - i * 8))

    buf = io.StringIO()
    doc.write(buf)
    return buf.getvalue().encode("utf-8")
