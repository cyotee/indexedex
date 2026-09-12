---
name: indexedex-agent-checklist
description: >
  Pre-flight checklist before any IndexedEx write. Use every time before cast
  send or forge script broadcast against IndexedEx contracts.
---

# IndexedEx agent checklist

## Goal
Run pre-flight checks before any IndexedEx write.

## Inspect
Confirm chain, addresses, and prerequisites before acting.


## Pre-flight (mandatory)

1. **Plugins:** `foundry-agent` installed; `indexedex-ops` loaded
2. **Network:** `cast chain-id` matches address table (e.g. 84532 Base Sepolia)
3. **Addresses:** from `indexedex-networks-addresses` or user-provided deployment JSON — not invented
4. **Registry:** `isVault(vault)` true when acting on a vault
5. **Token meta:** decimals + balances for user
6. **Allowance path:** ERC20 approve and/or Permit2 configured
7. **Preview:** preview/query or fork dry-run when available
8. **User confirmation:** print chain, contracts, amounts, minOut; wait for OK
9. **Broadcast:** `cast send` or forge script
10. **Verify:** receipt status + re-read balances / shares
11. **Report:** tx hash + explorer link

## Stop conditions
- Missing address table for network
- `isVault` false
- Preview reverts without understood reason
- User did not confirm write
