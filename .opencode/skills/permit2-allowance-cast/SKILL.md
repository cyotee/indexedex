---
name: permit2-allowance-cast
description: "Inspect ERC20 and Permit2 allowances and prepare authorized bounded Permit2 approvals with Cast."
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

# Permit2 allowance (cast)

## Goal
Enable a spender to pull tokens via Permit2 AllowanceTransfer without EIP-712 signatures.

## Prerequisites
- `PERMIT2=0x000000000022D473030F116dDEE9F6B43aC78BA3` (if codesize > 0)
- `TOKEN`, `SPENDER`, `AMOUNT`, `EXPIRATION` (unix ts)

## Safety
Confirm spender is the intended router. Prefer finite amount + expiration.

## Inspect
```bash
cast call $TOKEN "allowance(address,address)(uint256)" $USER $PERMIT2 --rpc-url $ETH_RPC_URL
cast call $PERMIT2 \
  "allowance(address,address,address)(uint160,uint48,uint48)" \
  $USER $TOKEN $SPENDER --rpc-url $ETH_RPC_URL
```

## Execute
```bash
cast send $TOKEN "approve(address,uint256)" $PERMIT2 $AMOUNT \
  --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY

cast send $PERMIT2 \
  "approve(address,address,uint160,uint48)" \
  $TOKEN $SPENDER $AMOUNT $EXPIRATION \
  --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY
```

## Verify
```bash
cast call $PERMIT2 \
  "allowance(address,address,address)(uint160,uint48,uint48)" \
  $USER $TOKEN $SPENDER --rpc-url $ETH_RPC_URL
```

## Common failures
- Forgot ERC20 approve to Permit2 first
- Expiration in the past
- Amount does not fit uint160
