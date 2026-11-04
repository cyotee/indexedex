# fz-balancer-router-dead-routes — RESULT

Status: CONFIRMED, liveness/DoS only (low). No user funds get stuck: every failure reverts atomically, and the tests assert balances are unchanged.
Duplicate check: distinct. P4 new_breaks only listed the symptoms. `balancer-router-permit-overpull` (p2/p3) covers stranded permit over-pull and pass-through exact-out, which is a different code path and a different root cause.
Deployment: P2/census say no Balancer SE router or buffer pool is in the Robinhood 4663 manifests, so this is latent/forward-looking.

Suite: `FzDeadRoutes.t.sol`. forge test gave 8 passed, 0 failed. (`FzRouterTrace.t.sol` is the original P4 repro and fails by design.)
The handler copy is instrumented: `r2OutFails`, `lastR2Err`, `lastR2Out`.

## Route 2 exact-in (USDC -> SE deposit -> buffer swap -> DAI): always BalanceNotSettled
Code: `BalancerV3StandardExchangeRouterExactInSwapTarget.sol:509-578`.

The router mints the SE shares straight into the Balancer vault (recipient=_balVault) **before** `vault.swap`. It only calls `settle(tokenInVault, actualVaultShares)` **after** the swap.

During the swap the buffer hook (`StandardExchangeBufferHookTarget._preSeatShares` step 5, and `_returnExcessPreSeatTta`) calls `vault.settle(shareTok, smallHint)`. Balancer `settle` sets `reservesOf = balanceOf(vault)`, but it only credits `min(hint, diff)`. So the hook's settle sweeps the router's pre-sent shares into reserves without crediting anyone. The router's later settle then gets credit 0, and the shares debt is left open.

- Evidence (`test_r2in_rootCause_hookSettleAbsorbsPreSentShares`): 24.94 shares were pre-sent. After the swap, reserves = balance = 2003.50e18. Router settle credit = 0 and the shares delta is +24.94e18, which gives BalanceNotSettled.
- `test_r2in_router_alwaysReverts_noFundsStuck`: amounts from 0.01 to 500 USDC all revert with 0x20f1d86d, and nothing is stranded.
- Fix (`test_r2in_fixedOrdering_succeeds`): mint the shares to the router, swap, then transfer the shares and settle. This returns 42.67 DAI for 50 USDC.

## Route 3 exact-out (DAI -> buffer swap -> shares -> SE withdraw -> exact USDC): always FailedCall
Code: `ExactOutSwapTarget.sol:796-920` calls `_exchangeOutFromVault` (`BalancerV3StandardExchangeRouterCommon.sol:216-240`).

That helper is hard-coded to `params.tokenInVault.exchangeOut(params.tokenIn, ..., params.tokenInVault, ...)`, which is the deposit direction. On route 3, tokenInVault == address(0), so the call goes to a codeless address. It reverts with empty data, and the diamond fallback wraps that as FailedCall (0xd6bda275).

There are two more problems on this route, even if the helper were fixed:
- The shares are `sendTo`'d to the router, not to the SE vault, yet the helper uses pretransferred=true.
- `params.limit` is in DAI units but would be used as the shares max-in.

Evidence: `test_r3out_router_alwaysReverts_noFundsStuck` (5 sizes, all FailedCall, balances unchanged) and `test_r3out_rootCause_callToTokenInVaultZero`.

## Route 2 exact-out (USDC -> SE exact-out mint -> buffer swap -> DAI): intermittent
Code: `ExactOutSwapTarget.sol:492-586`. There are two failure classes (`test_r2out_randomStates`: 58 attempts, 24 ok, 34 fail).

1. **BalanceNotSettled (a real bug).** The router calls `settle(tokenInVault, actualAmountIn)`. The hint is the **USDC** amount the SE vault consumed, not `swapAmountIn` shares.
   - The Aerodrome SE exact-out mint rounds `sharesOut = convertToSharesDown(lpReceived)` and is allowed to be >= amountOut. It often over-mints by 1 wei.
   - Because the USDC hint is large, the vault credits all of the minted shares. That leaves a **negative** shares delta (-1, an unclaimed credit), which Balancer also rejects as BalanceNotSettled.
   - `test_r2out_diagFailingStates`, 3 states: minted = swapAmountIn + 1, credit = minted, shDelta = -1. Route 1 (direct shares->DAI exact-out) succeeds for the same `out` in the same state. The real router's route 2 reverts BNS even with a 50k limit.
   - Fix: `settle(tokenInVault, swapAmountIn)`, i.e. the hint equals the exact debt.
2. **SwapLimit(0xe2ea151b).** This is correct slippage protection, not a bug. In fuzz-moved states the buffer pool prices shares far below the SE mint price, so the shares needed exceed `previewExchangeIn(limit)`. This reflects the pool-state mispricing (TTA-domain B1/B2), not the router.

In the clean deployment state, route 2 exact-out works for 0.01 to 300 DAI with both loose and tight limits (`test_r2out_sweep`). It costs about 1.15 USDC per DAI, which is pool pricing.

## Funds-at-risk conclusion
All three failures revert the whole `vault.unlock` frame. Permit2 pulls, SE deposits and hook mutations all roll back. User, router and BV3-vault balances are asserted unchanged after every failure. There is no attacker profit and no victim loss; the impact is broken functionality and DoS of these router paths.
