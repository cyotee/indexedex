---
name: permit2-signature-notes
description: "Choose Permit2 AllowanceTransfer or SignatureTransfer to match the actual IndexedEx contract and authorization flow."
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

# Permit2 signatures (agent notes)

## Safety
Prefer read-only first; require user confirmation for any write.

## Verify
Re-check state after any write; confirm receipts when broadcasting.


## Goal
Choose the right Permit2 path for agents.

## Default: AllowanceTransfer via cast
Use `permit2-allowance-cast` — no EIP-712 assembly required.

## SignatureTransfer
Requires EIP-712 typed data + wallet sign. Use only when the protocol requires signature params and you have a tested signing path.

## Agent rule
If both paths work, prefer AllowanceTransfer for CLI agents.
