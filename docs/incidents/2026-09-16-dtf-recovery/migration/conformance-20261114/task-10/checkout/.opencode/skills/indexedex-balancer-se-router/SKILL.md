---
name: indexedex-balancer-se-router
description: >
  Use IndexedEx Balancer V3 Standard Exchange Router for exact-in swaps with
  optional SE vault intermediation and Permit2. Cast runbooks with safety.
---

# IndexedEx Balancer SE Router (cast)

## Goal
Swap via `balancerV3StandardExchangeRouter` with optional SE vault legs.

## Addresses (Base Sepolia public snapshot)
```bash
export ROUTER=0x0FEF2ebbD2Dd7B677F750740BA12623D4cC77344
export PERMIT2=0x000000000022D473030F116dDEE9F6B43aC78BA3
```

## Signature (exact-in)
From `IBalancerV3StandardExchangeRouterExactInSwap`:

```text
swapSingleTokenExactIn(
  address pool,
  address tokenIn,
  address tokenInVault,   # IStandardExchangeProxy; address(0) if none
  address tokenOut,
  address tokenOutVault,
  uint256 exactAmountIn,
  uint256 minAmountOut,
  uint256 deadline,
  bool wethIsEth,
  bytes userData
) payable returns (uint256)
```

## Safety
- User confirmation required
- Set conservative minAmountOut
- Prefer Permit2 allowance or ERC20 approve to ROUTER

## Inspect
```bash
cast codesize $ROUTER --rpc-url $ETH_RPC_URL
cast call $TOKEN_IN "balanceOf(address)(uint256)" $USER --rpc-url $ETH_RPC_URL
```

## Approve path
```bash
# ERC20 approve router
cast send $TOKEN_IN "approve(address,uint256)" $ROUTER $AMOUNT \
  --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY
# or use permit2-ops against ROUTER as spender
```

## Execute
```bash
DEADLINE=$(( $(date +%s) + 600 ))
cast send $ROUTER \
  "swapSingleTokenExactIn(address,address,address,address,address,uint256,uint256,uint256,bool,bytes)" \
  $POOL $TOKEN_IN $TOKEN_IN_VAULT $TOKEN_OUT $TOKEN_OUT_VAULT \
  $AMOUNT $MIN_OUT $DEADLINE false 0x \
  --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY
```

Use `address(0)` for unused vault params: `0x0000000000000000000000000000000000000000`.

## Verify
```bash
cast call $TOKEN_OUT "balanceOf(address)(uint256)" $USER --rpc-url $ETH_RPC_URL
cast receipt $TX --rpc-url $ETH_RPC_URL
```

## Common failures
- pool/tokenInVault mismatch
- deadline expired
- allowance missing (ERC20 or Permit2)
