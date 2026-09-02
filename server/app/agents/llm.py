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


def llm_configured() -> dict:
    return {
        "deepseek": bool(os.environ.get("DEEPSEEK_API_KEY")),
        "anthropic": bool(os.environ.get("ANTHROPIC_API_KEY")),
        "stripe": bool(os.environ.get("STRIPE_SECRET_KEY")),
    }
