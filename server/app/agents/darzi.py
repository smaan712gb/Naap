"""Darzi-translator agent — writes the Urdu stitching note that accompanies
an order's parchi to the tailor network.

BLUEPRINT rule 3 enforcement: the LLM writes PROSE ONLY. Every measurement
number is injected verbatim into the prompt and the output is validated by
`numbers_intact` — if the model altered, dropped, or invented a stitching
number, we discard its text and fall back to a deterministic template.
"""

from __future__ import annotations

import re

from ..models import ParchiLine
from .llm import customer_llm

_SYSTEM = """You write a short note (Urdu, then an English line) from a
tailoring platform to a Pakistani master tailor accompanying a customer's
measurement parchi. Mention the garment, fit, and fabric, remind them to cut
to the Stitch column, and be respectful ("ustaad ji" register). Include every
measurement EXACTLY as given — never change, round, or omit a number. Keep it
under 150 words."""


def _fmt_lines(lines: list[ParchiLine]) -> str:
    return "\n".join(
        f"- {l.english} ({l.tailor_term} / {l.urdu}): "
        f"stitch {l.stitch_cm:.1f} cm (body {l.body_cm:.1f} cm)"
        for l in lines)


def _numbers_in(text: str) -> set[str]:
    return set(re.findall(r"\d+\.?\d*", text))


def numbers_intact(note: str, lines: list[ParchiLine]) -> bool:
    """Every stitch measurement must appear verbatim; no unknown numbers
    that look like measurements (>= 10) may be introduced."""
    wanted = {f"{l.stitch_cm:.1f}" for l in lines}
    found = _numbers_in(note)
    if not wanted.issubset(found):
        return False
    known = wanted | {f"{l.body_cm:.1f}" for l in lines}
    known |= {w[:-2] for w in known if w.endswith(".0")}  # "96.0" as "96"
    for n in found:
        try:
            val = float(n)
        except ValueError:
            continue
        if val >= 10 and n not in known and f"{val:.1f}" not in known:
            return False
    return True


def fallback_note(garment: str, fit: str, fabric: str,
                  lines: list[ParchiLine]) -> str:
    return (
        f"استاد جی، آداب۔ {garment} ({fit} fit, {fabric}) کے لیے ناپ حاضر ہے۔ "
        "براہِ کرم Stitch والے خانے کے مطابق کاٹیں۔\n"
        f"Please cut to the Stitch column. Garment: {garment}, fit: {fit}, "
        f"fabric: {fabric}.\n\n" + _fmt_lines(lines))


def tailor_note(garment: str, fit: str, fabric: str,
                lines: list[ParchiLine]) -> str:
    prompt = (f"Garment: {garment}\nFit: {fit}\nFabric: {fabric}\n"
              f"Parchi:\n{_fmt_lines(lines)}")
    try:
        note = customer_llm().invoke(
            [("system", _SYSTEM), ("human", prompt)]).text()
    except Exception:
        return fallback_note(garment, fit, fabric, lines)
    if not numbers_intact(note, lines):
        return fallback_note(garment, fit, fabric, lines)
    return note
