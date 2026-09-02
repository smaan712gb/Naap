"""The catalog-freshness agent team. Three agents, three trust levels:

- trend_scan   (LLM, DeepSeek): reads PUBLIC brand collection pages from the
               taxonomy's brand directory and summarizes what's launching —
               fabrics, themes, seasons. Informs the merchandiser; it never
               copies products into the catalog (blueprint rule 5: branded
               inventory comes via partnership, not scraping).
- link_health  (no LLM): checks every brand URL in the directory still
               answers — the "monthly catalog review" as a robot.
- seasonal_focus (no LLM, pure calendar): reports which live fabrics match
               the CURRENT and UPCOMING season and where the shelf is thin,
               so the shop always leads with the right cloth.

Every agent's output is a REPORT in the reports table, surfaced on the
admin page. Nothing here writes to the live catalog — the human
verification gate stays absolute.
"""

from __future__ import annotations

import datetime as _dt
import logging
import re

import httpx

from .. import db
from ..taxonomy import BRANDS
from .llm import sourcing_llm

log = logging.getLogger("naap.agents.monitor")

_UA = {"User-Agent": "NaapCatalogMonitor/1.0 (+catalog freshness check)"}


# ---------------------------------------------------------------- seasonal

def season_for_month(month: int) -> str:
    """Deterministic shopping season (subcontinent + diaspora calendar)."""
    if month in (11, 12, 1, 2):
        return "winter"
    if month in (4, 5, 6, 7, 8, 9):
        return "summer"
    return "mid-season"  # March, October


def seasonal_focus(now: _dt.date | None = None) -> dict:
    today = now or _dt.date.today()
    current = season_for_month(today.month)
    upcoming = season_for_month((today.month % 12) + 1)
    fabrics = db.list_fabrics(verified_only=True)

    def bucket(season: str) -> list[str]:
        return [f.name for f in fabrics
                if (f.season or "all-season") in (season, "all-season")]

    doc = {
        "current_season": current,
        "upcoming_season": upcoming,
        "live_for_current": bucket(current),
        "live_for_upcoming": bucket(upcoming),
        "total_live": len(fabrics),
        "advice": [],
    }
    if upcoming != current and len(doc["live_for_upcoming"]) < 5:
        doc["advice"].append(
            f"Only {len(doc['live_for_upcoming'])} fabrics ready for "
            f"{upcoming} — source more before the season turns.")
    if len(fabrics) and len(doc["live_for_current"]) < len(fabrics) * 0.4:
        doc["advice"].append(
            f"Under 40% of the live catalog suits {current} — front page "
            "may feel out of season.")
    return doc


# ---------------------------------------------------------------- links

def link_health(timeout: float = 8.0) -> dict:
    results = []
    with httpx.Client(follow_redirects=True, timeout=timeout,
                      headers=_UA) as client:
        for b in BRANDS:
            try:
                r = client.head(b["url"])
                if r.status_code >= 400:  # some shops reject HEAD
                    r = client.get(b["url"])
                ok = r.status_code < 400
                results.append({"brand": b["name"], "url": b["url"],
                                "status": r.status_code, "ok": ok})
            except Exception as e:  # noqa: BLE001 — record, don't crash
                results.append({"brand": b["name"], "url": b["url"],
                                "status": None, "ok": False,
                                "error": type(e).__name__})
    dead = [r for r in results if not r["ok"]]
    return {"checked": len(results), "dead": dead,
            "summary": f"{len(results) - len(dead)}/{len(results)} brand "
                       "links healthy"}


# ---------------------------------------------------------------- trends

_TREND_PROMPT = """You are a merchandising analyst for a Pakistani fashion
marketplace. Below is text extracted from a brand's public catalog page.
Summarize ONLY what is observable: collections being promoted, fabric names
mentioned, seasonal themes, and notable garment types. Output 3-6 short
bullet lines of plain text. Do not invent prices or products not present."""


def _page_text(client: httpx.Client, url: str, cap: int = 6000) -> str:
    r = client.get(url)
    text = re.sub(r"<script.*?</script>|<style.*?</style>", " ",
                  r.text, flags=re.S | re.I)
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"\s+", " ", text)
    return text[:cap]


def trend_scan(max_brands: int = 3, offset: int = 0) -> dict:
    """LLM trend summaries for a small rotating slice of the directory —
    the slice is capped to keep every run cheap and predictable."""
    llm = sourcing_llm()
    picks = (BRANDS * 2)[offset:offset + max_brands]
    findings = []
    with httpx.Client(follow_redirects=True, timeout=12.0,
                      headers=_UA) as client:
        for b in picks:
            try:
                text = _page_text(client, b["url"])
                note = llm.invoke(
                    [("system", _TREND_PROMPT),
                     ("human", f"Brand: {b['name']}\nPage text:\n{text}")]
                ).text
                findings.append({"brand": b["name"], "url": b["url"],
                                 "notes": note})
            except Exception as e:  # noqa: BLE001
                findings.append({"brand": b["name"], "url": b["url"],
                                 "error": type(e).__name__})
    return {"scanned": [f["brand"] for f in findings], "findings": findings}


# ---------------------------------------------------------------- runner

RUNNERS = {
    "seasonal": lambda: seasonal_focus(),
    "link-health": lambda: link_health(),
    "trends": lambda: trend_scan(),
}


def run_agent(kind: str) -> dict:
    if kind not in RUNNERS:
        raise ValueError(f"unknown agent kind: {kind}")
    doc = RUNNERS[kind]()
    rid = db.add_report(kind, doc)
    log.info("agent %s ran -> report %s", kind, rid)
    return {"id": rid, "kind": kind, "doc": doc}
