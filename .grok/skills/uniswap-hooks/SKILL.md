---
name: uniswap-hooks
description: Security-first assistance for building Uniswap v4 hooks — threat modeling, permission flags analysis, NoOp attack prevention, delta accounting, and pre-deployment audit checklists.
metadata:
  expanded_from: Uniswap/uniswap-ai
  plugin: uniswap-hooks
---

# uniswap-hooks

Full Uniswap AI plugin content (from `Uniswap/uniswap-ai`). Sub-skills live under `skills/`.

Load the relevant sub-skill `skills/<name>/SKILL.md` (and its references) for the task.

## Sub-skills

| Directory | Name | Description |
|-----------|------|-------------|
| [`skills/v4-hook-generator/`](skills/v4-hook-generator/SKILL.md) | v4-hook-generator | Generate Uniswap v4 hook contracts via OpenZeppelin MCP. Use when building custom swap logic, async swaps, hook-owned liquidity, custom curves, dynamic fees, MEV protection, limit orders, or oracle hooks. |
| [`skills/v4-security-foundations/`](skills/v4-security-foundations/SKILL.md) | v4-security-foundations | Security-first Uniswap v4 hook development. Use when user mentions "v4 hooks", "hook security", "PoolManager", "beforeSwap", "afterSwap", or asks about V4 hook best practices, vulnerabilities, or audit requirements. |

## How to use

1. Identify which sub-skill matches the user request.
2. Read that sub-skill's `SKILL.md` fully before acting.
3. Follow its steps, scripts, and security notes.

Upstream: https://github.com/Uniswap/uniswap-ai
