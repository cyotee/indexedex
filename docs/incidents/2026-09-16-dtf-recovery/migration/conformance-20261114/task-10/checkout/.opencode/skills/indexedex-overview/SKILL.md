---
name: indexedex-overview
description: >
  High-level IndexedEx product model for agents: Standard Exchange, DETF,
  vault registry, manager. Use first when an agent must interact with IndexedEx.
  Testnet-first (Base Sepolia).
---

# IndexedEx overview (agents)

## Goal

Map user intent to the correct IndexedEx surface before crafting cast calls.

## Network (default)

| Field | Value |
|-------|--------|
| Chain | Base Sepolia |
| Chain id | **84532** |
| Addresses | `indexedex-networks-addresses` → `references/public_sepolia_base.md` |

```bash
cast chain-id --rpc-url $ETH_RPC_URL   # expect 84532 for public test deployments
```

Mainnet: **fail closed** until published address artifacts exist.

## Components

| Surface | Purpose | Agent use |
|---------|---------|-----------|
| Manager / Vault Registry | Discover vaults & packages | Always discover before hardcoding vaults |
| Standard Exchange (SE) | Vault exchange in/out | Swaps / share exchange — `indexedex-standard-exchange` |
| Balancer V3 SE Router | SE-aware router + Permit2 | Multi-hop / SE path — `indexedex-balancer-se-router` |
| DETF | Diamond-as-share ERC20 | Mint/burn/bond when live — `indexedex-detf-user-flows` |

### Base Sepolia anchors (re-verify on-chain)

| Key | Address |
|-----|---------|
| manager / vaultRegistry | `0x6fe7Ea8a4901F9b29342Bdee13eDA204DB5104D0` |
| balancerV3StandardExchangeRouter | `0x0FEF2ebbD2Dd7B677F750740BA12623D4cC77344` |
| balancerV3Router | `0xbd4855c98fb0B2BBcE2D5421fefbDD18C37A1cf2` |
| create3Factory | `0xae187b18B5d5a3fdd5f4b5B172aB76972698d0ac` |
| sample abVault | `0x2dC4ad5F15057f4fbA46452489B43097ca006C5C` |

```bash
export MANAGER=0x6fe7Ea8a4901F9b29342Bdee13eDA204DB5104D0
cast call $MANAGER "owner()(address)" --rpc-url $ETH_RPC_URL  # probe liveness; adjust to real getter
cast codesize $MANAGER --rpc-url $ETH_RPC_URL
```

## User route defaults

- Prefer vault shares ↔ DETF on DETF surface when live
- RateAsset mint usually: deposit into SE first, then use shares
- Do not invent approximate solvers / unsupported routes

## Backend

Default execution: **Foundry cast** (`foundry-agent` + `foundry-agent-safety`). Optional: `bankr-ops`.

## Safety

Prefer read-only first; require user confirmation for any write. Re-check state after writes.

## Not in this plugin

Architecture dumps, forge tests, Crane style, deploy orchestration — use [cyotee-claude-plugins](https://github.com/cyotee/cyotee-claude-plugins) / Crane repo.

## Related checklist

See `indexedex-agent-checklist` before first write.
