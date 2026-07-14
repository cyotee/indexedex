---
name: uniswap-driver
description: Plan Uniswap swaps and liquidity positions then execute via deep links — verify tokens on-chain, research market conditions, and generate pre-filled Uniswap interface URLs across 12 chains.
metadata:
  expanded_from: Uniswap/uniswap-ai
  plugin: uniswap-driver
---

# uniswap-driver

Full Uniswap AI plugin content (from `Uniswap/uniswap-ai`). Sub-skills live under `skills/`.

Load the relevant sub-skill `skills/<name>/SKILL.md` (and its references) for the task.

## Sub-skills

| Directory | Name | Description |
|-----------|------|-------------|
| [`skills/liquidity-planner/`](skills/liquidity-planner/SKILL.md) | liquidity-planner | This skill should be used when the user asks to "provide liquidity", "create LP position", "add liquidity to pool", "become a liquidity provider", "create v3 position", "create v4 position", "concentrated liquidity", "set price range", or m |
| [`skills/swap-planner/`](skills/swap-planner/SKILL.md) | swap-planner | This skill should be used when the user asks to "swap tokens", "trade ETH for USDC", "exchange tokens on Uniswap", "buy tokens", "sell tokens", "convert ETH to stablecoins", "find memecoins", "discover tokens", "research tokens", "tokens to |

## How to use

1. Identify which sub-skill matches the user request.
2. Read that sub-skill's `SKILL.md` fully before acting.
3. Follow its steps, scripts, and security notes.

Upstream: https://github.com/Uniswap/uniswap-ai
