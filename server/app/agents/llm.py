"""Model routing for the agent layer — implements docs/BLUEPRINT.md rule 4.

- PUBLIC-data work (fabric sourcing/extraction): DeepSeek V4 (cheap, fine).
- CUSTOMER-adjacent text (darzi instructions, order updates): Claude when
  ANTHROPIC_API_KEY is set; falls back to DeepSeek with a logged warning.
- NOTHING numeric ever goes through a model (rule 3) — see darzi.py's
  number guardrail.
"""

from __future__ import annotations

import logging
import os

log = logging.getLogger("naap.agents")


def sourcing_llm():
    """DeepSeek chat model for public-data extraction."""
    from langchain_deepseek import ChatDeepSeek
    if not os.environ.get("DEEPSEEK_API_KEY"):
        raise RuntimeError(
            "DEEPSEEK_API_KEY is not set — the sourcing agent needs it "
            "(see server/.env.example)")
    return ChatDeepSeek(model="deepseek-chat", temperature=0)


def customer_llm():
    """Claude for customer-adjacent generation; DeepSeek fallback."""
    if os.environ.get("ANTHROPIC_API_KEY"):
        from langchain_anthropic import ChatAnthropic
        return ChatAnthropic(model="claude-opus-5", max_tokens=2048)
    log.warning(
        "ANTHROPIC_API_KEY unset — customer-facing text is falling back to "
        "DeepSeek. Set the key before production (BLUEPRINT rule 4).")
    return sourcing_llm()


def llm_configured() -> dict:
    return {
        "deepseek": bool(os.environ.get("DEEPSEEK_API_KEY")),
        "anthropic": bool(os.environ.get("ANTHROPIC_API_KEY")),
        "stripe": bool(os.environ.get("STRIPE_SECRET_KEY")),
    }
