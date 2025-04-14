````skill
---
name: permit2-router-witness
description: This skill should be used when the user asks about Permit2 witness signatures for Balancer V3 router swaps, typed-data construction, nonce/deadline handling, or needs the router’s canonical witness type string/typehash.
license: MIT
---

# Permit2 Router Witness (Balancer V3)

Use this skill for signed swap flows that call:
- `swapSingleTokenExactInWithPermit(...)`
- `swapSingleTokenExactOutWithPermit(...)`

Both routes use Permit2 `permitWitnessTransferFrom` and must use the router’s exact witness schema.

## Canonical Router Witness Values

Source of truth is the router itself (via `BalancerV3StandardExchangeRouterPermit2WitnessFacet`):

- `WITNESS_TYPE_STRING()`
- `WITNESS_TYPEHASH()`

Current canonical witness type string:

```text
Witness witness)TokenPermissions(address token,uint256 amount)Witness(address owner,address pool,address tokenIn,address tokenInVault,address tokenOut,address tokenOutVault,uint256 amountIn,uint256 limit,uint256 deadline,bool wethIsEth,bytes32 userData)
```

Current canonical witness struct hash preimage:

```text
Witness(address owner,address pool,address tokenIn,address tokenInVault,address tokenOut,address tokenOutVault,uint256 amountIn,uint256 limit,uint256 deadline,bool wethIsEth,bytes32 userData)
```

## Critical Rules

1. **Always read witness constants from router**
   - Do not hardcode app-only strings when the router can return the canonical values.

2. **Typed data must use EIP-712 signing**
   - Use `signTypedData`.
   - Do **not** fall back to `personal_sign` / `signMessage` for Permit2 typed-data payloads.

3. **Nonce and deadline are single-use/strict**
   - Build a fresh nonce from Permit2 nonce bitmap if stored permit is missing/expired.
   - Re-sign on swap click when quote-time signature is absent or stale.

4. **Token -> Permit2 allowance still required**
   - SignatureTransfer still pulls via Permit2 and requires ERC20 allowance to Permit2.

5. **Signed mode should not silently downgrade**
   - If signed mode is selected, execute the `*WithPermit` method path.
   - If permit prep fails, surface actionable error instead of unsigned fallback.

## Known Failure Patterns

- `InvalidSigner`:
  - Usually typed-data mismatch (domain/witness fields/order/spender/chain).

- `AllowanceExpired(uint256)` from Permit2:
  - Flow hit non-signature transfer path or used stale allowance deadline.
  - Ensure signed mode invokes `*WithPermit` and regenerates signature if expired.

- Unknown selector custom errors from router:
  - Inline ABI drift in frontend (tuple shape mismatch) causes wrong selector.

## Validation Checklist

- Confirm router has required function selector via `facetAddress(bytes4)`.
- Confirm router witness getters return expected constants.
- Confirm frontend ABI tuple shapes match deployed contract exactly.
- Confirm signed swap path includes fresh or valid stored permit.
- Confirm token balance and token->Permit2 allowance before submission.

## Useful Files

- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterCommon.sol`
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterPermit2WitnessTarget.sol`
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterPermit2WitnessFacet.sol`
- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterDFPkg.sol`
- `frontend/app/swap/page.tsx`

````
