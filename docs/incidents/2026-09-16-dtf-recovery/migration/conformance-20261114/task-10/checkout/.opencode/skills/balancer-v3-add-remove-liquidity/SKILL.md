---
name: balancer-v3-add-remove-liquidity
description: "Prepare Balancer V3 router joins and exits with verified deployed ABIs, amounts and slippage bounds."
---

## IndexedEx integration (2026-10-19)

Read the repository `CLAUDE.md` and the relevant Crane/IndexedEx skill before
using this topic. Current product law, registry/CREATE3 deployment, production-first
tests, build-before-test ordering and configured Foundry profiles override generic
examples. This archive-derived guide does not authorize broadcasts, dependency
installs, new product integrations or restoration of retired protocol families.
Use current deployment artifacts and the pinned frontend/tool versions; archived
addresses and API samples are not live verification. Resolve topic names through
`scripts/codex-skill-catalog.json` when they are grouped behind routers.

# Balancer V3 add/remove liquidity (cast)

## Goal
Join or exit a Balancer V3 pool proportionally via Router.

## Safety
Confirm pool tokens, amounts, and minBptOut / minAmountsOut. User OK required.

## Sequence
1. Inspect pool BPT + underlying balances
2. Approve each underlying token to Router (or Permit2)
3. Call Router join/exit with ABI from deployment docs
4. Verify BPT and token balances
