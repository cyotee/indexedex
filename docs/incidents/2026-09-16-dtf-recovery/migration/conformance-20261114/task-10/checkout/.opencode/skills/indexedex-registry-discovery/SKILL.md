---
name: indexedex-registry-discovery
description: >
  Discover IndexedEx vaults via Vault Registry cast calls (vaults, isVault,
  vaultsOfToken). Use before acting on any vault address.
---

# IndexedEx registry discovery (cast)

## Goal
Discover and validate vault addresses from the registry.

## Prerequisites
`REGISTRY` from `indexedex-networks-addresses`; `foundry-agent`.

## Safety
Never hardcode vaults from chat without registry or deployment verification.

## Inspect
```bash
export REGISTRY=0x6fe7Ea8a4901F9b29342Bdee13eDA204DB5104D0

cast call $REGISTRY "vaults()(address[])" --rpc-url $ETH_RPC_URL
cast call $REGISTRY "isVault(address)(bool)" $VAULT --rpc-url $ETH_RPC_URL
cast call $REGISTRY "vaultsOfToken(address)(address[])" $TOKEN --rpc-url $ETH_RPC_URL
cast call $REGISTRY "isContainedToken(address)(bool)" $TOKEN --rpc-url $ETH_RPC_URL
cast call $REGISTRY "vaultTokens()(address[])" --rpc-url $ETH_RPC_URL
```

## Dry-run
All of the above are read-only.

## Verify
If `isVault` is false, do not call vault exchange functions on that address.

## Common failures
- Wrong chain / wrong registry
- Empty arrays on fresh deployments
- eth_call gas limits on huge `vaults()` lists — prefer filtered queries
