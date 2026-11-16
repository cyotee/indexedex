---
name: indexedex-standard-exchange
description: >
  Interact with IndexedEx Standard Exchange vaults via cast: inspect, preview
  exchangeIn, approve, execute, verify balances.
---

# IndexedEx Standard Exchange (cast)

## Goal
Exchange tokens through an SE vault (`previewExchangeIn` / `exchangeIn`).

## Prerequisites
- Vault address validated via registry
- Token addresses in vault
- `defi-primitives` approve patterns
- User confirmation for writes

## Inspect
```bash
export VAULT=0x...   # from registry
cast call $VAULT "vaultConfig()((bytes32,bytes32,bytes4[],address[]))" --rpc-url $ETH_RPC_URL
# or per-interface helpers if available on proxy
cast call $TOKEN_IN "balanceOf(address)(uint256)" $USER --rpc-url $ETH_RPC_URL
cast call $TOKEN_OUT "balanceOf(address)(uint256)" $USER --rpc-url $ETH_RPC_URL
```

## Dry-run / preview
```bash
# IStandardExchangeIn
cast call $VAULT \
  "previewExchangeIn(address,uint256,address)(uint256)" \
  $TOKEN_IN $AMOUNT_IN $TOKEN_OUT --rpc-url $ETH_RPC_URL
```
If selector mismatches the live ABI, decode with project interfaces — do not invent args.

## Execute
```bash
cast send $TOKEN_IN "approve(address,uint256)" $VAULT $AMOUNT_IN \
  --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY

# exchangeIn(tokenIn, amountIn, tokenOut, minAmountOut, recipient, deadline) — confirm exact signature on live ABI
cast send $VAULT \
  "exchangeIn(address,uint256,address,uint256,address,uint256)" \
  $TOKEN_IN $AMOUNT_IN $TOKEN_OUT $MIN_OUT $USER $DEADLINE \
  --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY
```

If the live diamond uses a different signature, read the interface from deployment and adjust — fail rather than guess.

## Verify
```bash
cast call $TOKEN_IN "balanceOf(address)(uint256)" $USER --rpc-url $ETH_RPC_URL
cast call $TOKEN_OUT "balanceOf(address)(uint256)" $USER --rpc-url $ETH_RPC_URL
cast receipt $TX --rpc-url $ETH_RPC_URL
```

## Common failures
- Missing approval
- minAmountOut slippage
- Unsupported token pair on vault
- Calling non-vault address
