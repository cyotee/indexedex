---
name: uniswap-cca
description: Configure and deploy Continuous Clearing Auction (CCA) smart contracts — guided parameter setup, convex supply schedule generation, Q96 price calculations, and multi-chain CREATE2 deployment.
metadata:
  expanded_from: Uniswap/uniswap-ai
  plugin: uniswap-cca
---

# uniswap-cca

Full Uniswap AI plugin content (from `Uniswap/uniswap-ai`). Sub-skills live under `skills/`.

Load the relevant sub-skill `skills/<name>/SKILL.md` (and its references) for the task.

## Sub-skills

| Directory | Name | Description |
|-----------|------|-------------|
| [`skills/configurator/`](skills/configurator/SKILL.md) | configurator | Configure CCA (Continuous Clearing Auction) smart contract parameters through an interactive bulk form flow. Use when user says "configure auction", "cca auction", "setup token auction", "auction configuration", "continuous auction", or men |
| [`skills/deployer/`](skills/deployer/SKILL.md) | deployer | Deploy CCA (Continuous Clearing Auction) smart contracts using the Factory pattern. Use when user says "deploy auction", "deploy cca", "factory deployment", or wants to deploy a configured auction. |

## How to use

1. Identify which sub-skill matches the user request.
2. Read that sub-skill's `SKILL.md` fully before acting.
3. Follow its steps, scripts, and security notes.

Upstream: https://github.com/Uniswap/uniswap-ai
