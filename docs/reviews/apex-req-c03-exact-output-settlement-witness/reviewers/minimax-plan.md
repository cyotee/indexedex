# Blocking question — REQ-C03 witness cannot reach `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:531-536`

## Question
Can a production-proxy test reach the post-swap settlement check at `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:531-536` with `outputPaid != amountOut` without mocking the pool or `pool.swap`?

## Why this blocks the plan
The PRD's Repair 1 requires the witness to "pass `_quoteSwapOut` and then reach `:531-536`" with the post-swap payment not equal to the requested amount. The PRD's "What is already true" section states the production call order is quote, then pull, then `_swapExactOut`. The PRD's Repair 4 prohibits "constructing the short payment by skipping the quote, by replacing `pool.swap`, or by calling `_swapExactOut` on a bare implementation that is not the production proxy." Repair 5 allows "a non-SUT token or pool observer" to change pool state during the production pull.

The PRD never resolves the following question: in a real Uniswap V3 pool, an exact-output `pool.swap` either fully fills (`outputPaid == amountOut`) or reverts (`pool.swap` does not return). The check at `:531-536` is `if (outputPaid != amountOut) revert UniswapV3Exchange_ExactOutputNotFilled(amountOut, outputPaid);`. There is no standard-pool state in which `pool.swap` returns successfully with `outputPaid != amountOut` for an exact-output swap. Reaching `:531-536` with a non-matching `outputPaid` therefore requires either a non-standard pool that returns synthetic amounts (mocking) or a wrapper that intercepts `pool.swap` (replacing the call).

The PRD's wording is permissive on the surface ("non-SUT pool observer may be used"), but on the production sequence, a real Uniswap V3 pool cannot produce the required state through a non-SUT observer that does not replace `pool.swap`. The PRD does not name any non-standard pool deployment path that would reach `:531-536` with `outputPaid != amountOut`. The "fix a derivative of a standard pool" path is not authorized.

The PRD does acknowledge in its Gap section that the witness may find "the check is wrong or unreachable" and that this discovery is "in scope to report." But it does not specify what to write if the check is unreachable without mocking — only that the implementation report should say so and not claim REQ-C03 closed. The implementer cannot write a single test that satisfies Repair 1 bullets 1-6 simultaneously without choosing between two paths that the PRD treats as incompatible (mocking versus reaching the check on the production sequence).

## The PRD sentence that does not settle it
`docs/reviews/apex-req-c03-exact-output-settlement-witness/REMEDIATION_PRD.md` Repair 4:

> Do not construct the short payment by skipping the quote, by replacing `pool.swap`, or by calling `_swapExactOut` on a bare implementation that is not the production proxy. A non-SUT token or pool observer may be used only to let the production sequence quote successfully and then observe a different payment. It must not replace the vault.

The phrase "observe a different payment" is undefined. On the production sequence with a real Uniswap V3 pool, `pool.swap` for exact-output either fully fills or reverts. "A different payment" cannot be produced without replacing `pool.swap` (mocking the call result) or replacing the pool itself (mocking the contract). The PRD does not authorize either.

## The two incompatible implementations

**Implementation A — real Uniswap V3 pool, production sequence, non-SUT observer that swaps between the quote and the swap.**
- Quote passes (pool can fill at quote time).
- Observer's swap changes pool price during the pull window.
- Vault's `pool.swap` runs against the new pool state.
- In a real Uniswap V3 pool, the swap either fully fills at the new state (`outputPaid == amountOut`, check at `:531-536` passes) or reverts with `InsufficientOutput` when the price limit is hit (check at `:531-536` never reached).
- Result: the post-swap check is never triggered with `outputPaid != amountOut`. The witness cannot be built.

**Implementation B — non-standard pool, or a wrapper around the production proxy that intercepts `pool.swap`.**
- Either the pool is not a real Uniswap V3 pool but a stub that returns synthetic `amount0Delta` / `amount1Delta`, or a wrapper contract sits between the vault and the pool, intercepting `pool.swap` and returning fake amounts.
- The vault's `_swapExactOut` receives the synthetic deltas.
- `outputPaid != amountOut`, and the check at `:531-536` reverts with `UniswapV3Exchange_ExactOutputNotFilled`.
- This is mocking the pool or replacing `pool.swap`. The PRD forbids both.

## Why the wrong choice fails
- Choosing A and the clear-A-no-mocking path means the witness can never actually exercise `:531-536` with a non-matching payment. The implementer cannot produce a passing witness. The post-swap check remains unwitnessed; the test gap is not closed. If `:534-535` is removed or broken in a future edit, the failure is silent because the check is never reached on this path.
- Choosing B and the mock-the-pool path exercises the check but is forbidden by the PRD. If the production sequence is later changed (e.g., a future fix to `pool.swap` callback ordering), the mock's synthetic deltas may pass when the real check would catch the bug. The witness is not a binding proof on the production proxy.

The PRD itself anticipates this when it says (Verification): "A failing witness is reported, not hidden." But the PRD's Repair 1-6 do not specify which path the implementer should choose if the witness cannot reach the check without mocking. The implementer needs an owner ruling on one of three choices:

1. **Build the witness anyway**, using a non-standard pool or a wrapper, accepting that the resulting test is not a binding production-proxy proof. The PRD would need a one-sentence scope amendment to Repair 4 to authorize this.
2. **Skip the witness**, and accept that REQ-C03 is not closed. The current quote-stage tests stay as quote-stage tests; the PRD's Repair 6 becomes inapplicable to a settlement bullet. The PRD's Gap section ("It is in scope to report") covers this branch.
3. **Add a production-path hook or wrapper** that genuinely allows `pool.swap` to return with `outputPaid != amountOut` after an accepted quote (e.g., a pool-level reentrancy callback that withdraws output between the swap's price-step updates). This is a new design, not a test addition. The PRD does not authorize this.

## Owner decision required
The owner must choose one of the three branches above before the implementer can write a single test that satisfies Repair 1 bullets 1-6 simultaneously. No plan draft can be written until that choice is on the record.

STOP. No plan draft written.