---
name: uniswap-trading-tools
description: Uniswap trading tools — DCA bots, copy trade, and index bot skills.
metadata:
  expanded_from: Uniswap/uniswap-ai
  plugin: uniswap-trading-tools
---

# uniswap-trading-tools

Full Uniswap AI plugin content (from `Uniswap/uniswap-ai`). Sub-skills live under `skills/`.

Load the relevant sub-skill `skills/<name>/SKILL.md` (and its references) for the task.

## Sub-skills

| Directory | Name | Description |
|-----------|------|-------------|
| [`skills/copy-trade/`](skills/copy-trade/SKILL.md) | copy-trade | This skill should be used when the user asks to "copy trades from" a wallet, "mirror a wallet", "follow this address", set up "copy trading", "track and replicate a trader", or mirror another account's swaps bounded by guardrails. Watches a |
| [`skills/dca-bot/`](skills/dca-bot/SKILL.md) | dca-bot | This skill should be used when the user wants to "dca into" a token, "buy X every day", set up a "recurring buy", "dollar cost average" into an asset, "schedule a buy", or "auto-buy on a dip". Buys a fixed amount into a token on a schedule, |
| [`skills/index-bot/`](skills/index-bot/SKILL.md) | index-bot | This skill should be used when the user asks to "create an index", "build a basket of top assets", "buy a weighted basket", "make a portfolio of assets", "equal-weight basket", "rebalance my portfolio", "track the top N tokens", or wants an |

## How to use

1. Identify which sub-skill matches the user request.
2. Read that sub-skill's `SKILL.md` fully before acting.
3. Follow its steps, scripts, and security notes.

Upstream: https://github.com/Uniswap/uniswap-ai
