---
name: balancer-v3-router-swap
description: "Inspect, simulate and prepare authorized Balancer V3 router swaps; use current IndexedEx registry paths for managed vault flows."
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

# Balancer V3 router swap (cast)

## Goal

Swap a single token pair via the user-facing Balancer V3 **Router** (`swapSingleTokenExactIn`-style), with inspect → dry-run → execute → verify.

## Address sources

| Network | Key | Source |
|---------|-----|--------|
| Base Sepolia (84532) | `balancerV3Router` | Current IndexedEx deployment artifacts via `indexedex-networks-addresses` |
| Canonical | Vault / Router | Protocol deployment docs — never invent |

```bash
# Set CHAIN_ID and ROUTER from the current task-selected deployment artifact.
# TOKEN_IN / TOKEN_OUT / POOL from registry or known pool list
export WALLET_ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY)
```

For IndexedEx-managed SE flows prefer `indexedex-balancer-se-router` / `indexedex-standard-exchange` instead of the raw Balancer router.

## Prerequisites

- `foundry-tools` + `foundry-agent-safety`
- ERC20 approve (`approval-ops`) or Permit2 (`permit2-allowance-cast`)
- User confirmation for writes

## Safety

- Set `minAmountOut` / deadline; confirm `cast chain-id` == intended network
- Prefer Anvil fork first
- Do not hardcode mainnet addresses from memory

## Inspect

```bash
cast chain-id --rpc-url $ETH_RPC_URL
cast call $TOKEN_IN "balanceOf(address)(uint256)" $USER --rpc-url $ETH_RPC_URL
cast call $TOKEN_OUT "balanceOf(address)(uint256)" $USER --rpc-url $ETH_RPC_URL
cast call $TOKEN_IN "allowance(address,address)(uint256)" $USER $ROUTER --rpc-url $ETH_RPC_URL
cast call $TOKEN_IN "decimals()(uint8)" --rpc-url $ETH_RPC_URL
```

## Dry-run

Estimate gas / call as static where ABI supports query; otherwise re-check balances and minOut math off-chain:

```bash
cast estimate $ROUTER \
  "swapSingleTokenExactIn(address,address,address,uint256,uint256,uint256,bool,bytes)" \
  $POOL $TOKEN_IN $TOKEN_OUT $AMOUNT_IN $MIN_AMOUNT_OUT $DEADLINE false 0x \
  --from $USER --rpc-url $ETH_RPC_URL
```

If the live Router ABI differs (version skew), read the deployment ABI and adjust the signature — **fail rather than invent**.

## Execute

```bash
# 1) Approve TOKEN_IN -> Router (or use permit2-allowance-cast for Permit2 path)
cast send $TOKEN_IN "approve(address,uint256)" $ROUTER $AMOUNT_IN \
  --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY

# 2) Exact-in swap (Balancer V3 Router-style)
# signature must match the deployed Router — confirm with cast sig / ABI
export DEADLINE=$(($(date +%s) + 600))
cast send $ROUTER \
  "swapSingleTokenExactIn(address,address,address,uint256,uint256,uint256,bool,bytes)" \
  $POOL $TOKEN_IN $TOKEN_OUT $AMOUNT_IN $MIN_AMOUNT_OUT $DEADLINE false 0x \
  --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY
```

Common alternate (if deployment uses different naming): decode Router interface from explorer and substitute.

## Verify

```bash
cast receipt $TX --rpc-url $ETH_RPC_URL
cast call $TOKEN_IN "balanceOf(address)(uint256)" $USER --rpc-url $ETH_RPC_URL
cast call $TOKEN_OUT "balanceOf(address)(uint256)" $USER --rpc-url $ETH_RPC_URL
```

## Common failures

- Missing approval / wrong spender (Router vs Vault vs Permit2)
- Slippage: `minAmountOut` too high
- Wrong pool / token order
- Deadline expired
- Wrong chain id

## Related

- `balancer-v3-vault-read`, `balancer-v3-addresses`
- IndexedEx: `indexedex-balancer-se-router`, `indexedex-standard-exchange`
