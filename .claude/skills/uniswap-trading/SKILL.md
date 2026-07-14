---
name: uniswap-trading
description: Integrate Uniswap swaps into frontends, backends, and smart contracts — V2/V3/V4 support via Trading API, Universal Router, or direct contract calls.
metadata:
  expanded_from: Uniswap/uniswap-ai
  plugin: uniswap-trading
---

# uniswap-trading

Full Uniswap AI plugin content (from `Uniswap/uniswap-ai`). Sub-skills live under `skills/`.

Load the relevant sub-skill `skills/<name>/SKILL.md` (and its references) for the task.

## Sub-skills

| Directory | Name | Description |
|-----------|------|-------------|
| [`skills/lp-integration/`](skills/lp-integration/SKILL.md) | lp-integration | Integrate Uniswap liquidity provisioning (LP) into applications via the LP REST API. Use when the user says "LP API", "liquidity provisioning API", "provide liquidity programmatically", "create LP position via API", "add liquidity via API", |
| [`skills/pay-with-any-token/`](skills/pay-with-any-token/SKILL.md) | pay-with-any-token | > |
| [`skills/pay-with-app/`](skills/pay-with-app/SKILL.md) | pay-with-app | > |
| [`skills/swap-integration/`](skills/swap-integration/SKILL.md) | swap-integration | Integrate Uniswap swaps into applications. Use when user says "integrate swaps", "uniswap", "trading api", "add swap functionality", "build a swap frontend", "create a swap script", "smart contract swap integration", "use Universal Router", |
| [`skills/v4-sdk-integration/`](skills/v4-sdk-integration/SKILL.md) | v4-sdk-integration | > |

## How to use

1. Identify which sub-skill matches the user request.
2. Read that sub-skill's `SKILL.md` fully before acting.
3. Follow its steps, scripts, and security notes.

Upstream: https://github.com/Uniswap/uniswap-ai
