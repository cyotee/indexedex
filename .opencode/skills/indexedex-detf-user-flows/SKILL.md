---
name: indexedex-detf-user-flows
description: >
  IndexedEx DETF user flows for agents: inspect live/thresholds, bond, mint/burn
  gates, claim notes. Cast-oriented; fail closed when inert or addresses missing.
---

# IndexedEx DETF user flows (cast)

## Goal
Operate DETF user routes safely when the instance is live.

## Concepts
- **Inert vs live:** mint/burn of user DETF against vault shares blocked until live (first successful bond / reserve live).
- **Thresholds:** mint only above mintThreshold; burn only below burnThreshold (defaults often ±5%).
- Prefer **vault shares <-> DETF** closed-form routes.

## Inspect
```bash
export DETF=0x...  # from deployment / registry — never invent
cast call $DETF "mintThreshold()(uint256)" --rpc-url $ETH_RPC_URL
cast call $DETF "burnThreshold()(uint256)" --rpc-url $ETH_RPC_URL
# bond NFT vault, accepted tokens — use interface methods present on the diamond
cast call $DETF "bondNftVault()(address)" --rpc-url $ETH_RPC_URL
```

## Bond (pattern)
From bonding interfaces (`bond(tokenIn, amountIn, lockDuration, recipient, deadline)`):

```bash
cast send $TOKEN_IN "approve(address,uint256)" $DETF $AMOUNT \
  --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY

DEADLINE=$(( $(date +%s) + 600 ))
cast send $DETF \
  "bond(address,uint256,uint256,address,uint256)" \
  $TOKEN_IN $AMOUNT $LOCK_DURATION $USER $DEADLINE \
  --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY
```

Confirm exact signature against the live DETF family ABI before broadcast.

## Mint / burn
Only when live and thresholds allow. Preview first if query methods exist. Fail closed if inert.

## Claim / redeem
Requires claim token configuration; burn claim shares on redeem paths. Do not treat raw claim amounts as free BPT authority.

## Safety
- Small size first
- User confirmation
- Prefer testnet snapshot addresses

## Common failures
- Operating while inert
- Threshold gates
- Wrong accepted bond token
