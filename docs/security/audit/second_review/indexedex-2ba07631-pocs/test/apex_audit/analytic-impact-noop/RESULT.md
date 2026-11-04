# analytic-impact-noop (hunt-analytic-certify-alias-impact-noop)

Status: the mechanism is CONFIRMED by execution. It causes the preview and execution to disagree (quote integrity). It is NOT exploitable for profit. Severity: low/info.

Run: `forge test test/apex_audit/analytic-impact-noop/AnalyticImpactNoop.t.sol -vv`. Result: 9/9 pass.

## Bug
In `AnalyticComposition._certify`, line 333 does `Types.Snapshot memory original = walk_.state;`. That copies a pointer, not the struct. `_afterSwap(original, …)` at :343 then writes the post-swap sqrtPrice into `walk_.state`. The check `_priceWithin(walk_.state…, original…, 50)` at :348 therefore compares a value with itself, so the 50 bps gate never rejects anything. Fix: cache `uint160 before = walk_.state.position.sqrtPriceX96` before `_afterSwap`, or deep-copy the struct the way `_zeroSwap` does.

## Evidence (project's own Acceptance fixture: real v4 PoolManager, fee 0.30%, external full-range L = 1e6 units, vault bootstrapped with 1000/1000)
`test_impactCheckNoop_previewValid_executionReverts` deposits 20,000 token1 into the vault:
- `Planner._composition` returns plan.valid = true, shares 9935.5e18, swapIn 9981.9e18
- Planned sqrtP moves from 79228162514264337593543950336 to 80015982406100339109357649329, about 199 bps of price. That breaks the 50 bps bound.
- `previewExchangeIn` returns 9935.5e18 shares, identical to the plan.
- `exchangeIn` with the same inputs reverts with `PriceImpactExceeded` (the Common.sol:1114 re-check against the live slot0). No tokens move, supply is unchanged, the pool price is unchanged, and the books stay balanced.

The `test_scan_*` tests count certified plans whose price move is over 50 bps:
- 14 at the default fixture, with a maximum of 954 bps
- 42 with external L = 1000
- 11 with a 1e6 vault

All of these are in the token1→vault (zeroForOne=false) direction.

Control test: a 100-unit deposit has preview == execution.

## Why there is no profit
- Execution re-checks the bound against the real slot0 and requires afterPrice == plan.sqrtPriceAfterX96. A deposit over 50 bps can never settle, and the revert is atomic.
- The only effect is a nonzero preview for a deposit that will revert. A consumer that trusts the preview (a router or DETF planner) reverts or must re-route. An attacker gains nothing; at most they impose gas griefing, which ordinary frontrunning already allows.
- This is not a strict DoS. With a correct check these deposits would preview 0 and still be refused.

## Side observation (not in scope)
In the token0→vault direction (zeroForOne=true), the analytic solver's plan fails the 1 bp `_aligned` check from about 700 units on (the analytic result is `Failure.Rejected`, see `test_diag`). With a 1e6-unit vault, even 1000-unit token0 deposits are refused (AlignmentNotAchievable), while the same sizes in the token1 direction work. The solver is asymmetric or inaccurate for zeroForOne compositions. That limits usability (single-sided token0 zaps above a few hundred units revert) but is not a security issue. It is worth a separate look.
