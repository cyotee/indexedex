---
name: balancer-v3-vault-read
description: "Read Balancer V3 pool balances, supply and deployed Vault state before swaps, joins or exits."
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

# Balancer V3 vault / pool read (cast)

## Goal

Inspect pool-related state needed before a swap or liquidity action.

## Address sources

- Pool / BPT token: from pool list or IndexedEx vault config
- Base Sepolia sample router (not vault): see `indexedex-networks-addresses`

```bash
export POOL=0x...   # BPT / pool contract — from registry, never invent
export WALLET_ADDRESS=0x...
```

## Inspect

```bash
cast call $POOL "totalSupply()(uint256)" --rpc-url $ETH_RPC_URL
cast call $POOL "balanceOf(address)(uint256)" $USER --rpc-url $ETH_RPC_URL
cast call $POOL "symbol()(string)" --rpc-url $ETH_RPC_URL
cast call $POOL "decimals()(uint8)" --rpc-url $ETH_RPC_URL
cast call $POOL "name()(string)" --rpc-url $ETH_RPC_URL
```

For Vault-centric queries, use the official Vault ABI from Balancer deployments (function names differ by V3 release). Example pattern:

```bash
# Only if VAULT address is from a trusted address table
 # Set QUERY_SIGNATURE from the complete deployed Vault ABI, including return types.
cast call "$VAULT" "$QUERY_SIGNATURE" "$POOL" --rpc-url "$ETH_RPC_URL"
```

If the selector is unknown, fetch ABI from the block explorer for that deployment — do not invent.

## Dry-run

Reads only; no state change.

## Verify

After any write (swap/join/exit), re-run inspect calls and compare BPT + underlying balances.

## Related

- `balancer-v3-router-swap`, `balancer-v3-add-remove-liquidity`, `balancer-v3-addresses`
