---
name: indexedex-networks-addresses
description: >
  Load IndexedEx deployment addresses by network. Fail closed if a chain table
  is missing. Use before any IndexedEx cast call.
---

# IndexedEx networks and addresses

## Goal
Resolve manager/registry/router addresses for the active chain.

## Fail closed
If the network is not listed below and no deployment JSON is provided by the user, **refuse** and ask for addresses. Never invent mainnet addresses.

## Public Base Sepolia (IndexedEx `public_sepolia/base` snapshot)

| Name | Address |
|------|---------|
| Chain ID | `84532` |
| IndexedEx Manager / Vault Registry | `0x6fe7Ea8a4901F9b29342Bdee13eDA204DB5104D0` |
| Balancer V3 SE Router | `0x0FEF2ebbD2Dd7B677F750740BA12623D4cC77344` |
| Balancer V3 Router (core) | `0xbd4855c98fb0B2BBcE2D5421fefbDD18C37A1cf2` |
| Create3Factory | `0xae187b18B5d5a3fdd5f4b5B172aB76972698d0ac` |
| Permit2 (canonical) | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |

Source note: copied from IndexedEx deployment artifacts; re-verify with `cast codesize` before writes.

Example SE vaults (Base Sepolia public snapshot — verify live):
- `abVault`: `0x2dC4ad5F15057f4fbA46452489B43097ca006C5C`
- Prefer registry queries over hardcoding when possible.

## Ethereum / Base mainnet
**Not listed here until production deployment artifacts exist.** Fail closed.

## Verify
```bash
export REGISTRY=0x6fe7Ea8a4901F9b29342Bdee13eDA204DB5104D0
cast chain-id --rpc-url $ETH_RPC_URL   # expect 84532 for Base Sepolia
cast codesize $REGISTRY --rpc-url $ETH_RPC_URL
```

See also [references/public_sepolia_base.md](references/public_sepolia_base.md).
