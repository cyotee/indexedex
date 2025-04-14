# 2026-01-10 — Area Review (Parallel): DEX Vaults

- **Date:** 2026-01-10
- **Branch/Worktree:** `review/2026-01-10-dex-vaults`
- **Reviewer:** Copilot (GPT-5.2)

This file is now an **index**. Per-DEX findings are split into separate files so they can be reviewed/iterated independently.

## Per-DEX finding files

- [Uniswap V2](./2026-01-10_dex-uniswap-v2.md)
- [Aerodrome V1](./2026-01-10_dex-aerodrome-v1.md)
- [Slipstream](./2026-01-10_dex-slipstream.md)
- [Camelot V2](./2026-01-10_dex-camelot-v2.md)
- [Uniswap V3](./2026-01-10_dex-uniswap-v3.md)
- [Uniswap V4](./2026-01-10_dex-uniswap-v4.md)
- [Protocol DETF recovery](./2026-01-10_protocol-detf-recovery.md)

## Hard conventions (enforced)

- Never enable IR compilation (`via_ir`). Fix `stack too deep` via structs + local scoping.
- Never deploy with `new`; deployments must use the repo’s CREATE3 factory/deploy helpers.

## Top findings

- Aerodrome V1: confirmed `previewExchangeOut` bug (vault-deposit branch uses the wrong variable) — see Aerodrome note.
- Camelot V2: verified `previewDeployVault` can revert (underflow/overflow) — see Camelot note.
- Slipstream / Uniswap V3 / Uniswap V4: vault implementations appear planned but not present on `main` in this worktree.

## What “subagents” look like

Subagents run as one-shot workers: you give them a scoped prompt; they return a report. There’s no live “parallel chat UI” inside this VS Code chat view — you only see the final report when it finishes.
