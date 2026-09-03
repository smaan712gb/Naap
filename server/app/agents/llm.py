"""Model routing for the agent layer — docs/BLUEPRINT.md §AI architecture.

ALL agent prose runs on DeepSeek (founder decision, 2026-09-02: cost).
This is acceptable privacy-wise because no agent ever receives customer
IDENTITY: the sourcing agent sees public supplier text only, and the darzi
agent gets garment/fit/fabric plus measurement numbers — never a name,
contact, or address (see darzi.py). Claude can be re-enabled for
customer-adjacent prose on any deployment by setting NAAP_PREFER_CLAUDE=1
alongside ANTHROPIC_API_KEY.

NOTHING numeric ever goes through a model (rule 3) — darzi.py's
`numbers_intact` guardrail discards any output that touches a number.
"""

from __future__ import annotations

import logging
import os

log = logging.getLogger("naap.agents")


def sourcing_llm():
    """DeepSeek chat model — the workhorse for all agent prose."""
    from langchain_deepseek import ChatDeepSeek
    if not os.environ.get("DEEPSEEK_API_KEY"):
        raise RuntimeError(
            "DEEPSEEK_API_KEY is not set — the agent layer needs it "
            "(see server/.env.example)")
    return ChatDeepSeek(model="deepseek-chat", temperature=0)


def customer_llm():
    """Customer-adjacent prose. DeepSeek by default (identity never enters
    prompts); opt into Claude with NAAP_PREFER_CLAUDE=1 + ANTHROPIC_API_KEY."""
    if (os.environ.get("NAAP_PREFER_CLAUDE") == "1"
            and os.environ.get("ANTHROPIC_API_KEY")):
        from langchain_anthropic import ChatAnthropic
        return ChatAnthropic(model="claude-opus-5", max_tokens=2048)
    return sourcing_llm()


def vision_llm():
    """DeepSeek's vision model (V4 Flash Vision Exp) — the agents' cheap
    eyes. Understanding only: it reads public catalog imagery; it cannot
    generate images (that needs the separate image-gen key). User body
    photos never reach it or any cloud model (product laws 1 & 4)."""
    from langchain_deepseek import ChatDeepSeek
    if not os.environ.get("DEEPSEEK_API_KEY"):
        raise RuntimeError("DEEPSEEK_API_KEY is not set")
    return ChatDeepSeek(model="deepseek-v4-flash-vision-exp", temperature=0)


def screen_image(url: str, expect: str) -> bool:
    """True if the image plausibly shows `expect` (a clean garment/fabric
    shot, not a logo/banner/sprite). Fail-open: the model is experimental,
    so on any error we keep the image rather than silently dropping it."""
    try:
        out = vision_llm().invoke([("human", [
            {"type": "text", "text":
                f"Does this image clearly show: {expect}? It must be a "
                "product, garment, or fabric photograph — not a logo, "
                "banner, icon, or sprite. Answer YES or NO only."},
            {"type": "image_url", "image_url": {"url": url}},
        ])]).text
        return "YES" in out.upper()
    except Exception:  # noqa: BLE001
        log.warning("vision screen failed for %s — keeping image", url)
        return True


def llm_configured() -> dict:
    return {
        "deepseek": bool(os.environ.get("DEEPSEEK_API_KEY")),
        "anthropic": bool(os.environ.get("ANTHROPIC_API_KEY")),
        "stripe": bool(os.environ.get("STRIPE_SECRET_KEY")),
    }
