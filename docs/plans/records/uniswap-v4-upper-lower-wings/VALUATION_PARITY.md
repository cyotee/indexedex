# Valuation and parity status

Implemented references cover geometry, removable/addition principal and modular fee growth only. Full-width principal vectors use Python arbitrary-precision rational formulas at protocol price extremes and maximum uint128 liquidity. Geometry reference uses binary search over usable boundaries, independently of production inverse TickMath and signed-floor logic. Both references use protocol endpoint/forward sqrt values as inputs, not the production Wings helper's outputs.

The full-range principal reference is not the canonical liquidation simulator: no owned-liquidity pool overlay, initialized-tick traversal, external depth exhaustion or real PoolManager clone/remove/swap parity has been implemented. No V quote is exposed.

Future phase 3 must compare canonical V against real own-position removal and permitted conversion, including shared boundaries, empty active regions, all-owned liquidity, partial sells, protocol fees and computational exhaustion. The open total-work budget must be selected from measured useful domains; no partial computation may be reported as market-limited value.

Pure-reference validation passed: both geometry fuzz properties, rational principal fuzz, full-width rounding-gap fuzz, fee fuzz/checkpoint tests and all 24 Python principal vectors. No full liquidation parity result is implied.

## Real PoolManager reference added

RecoveryValue tests now execute actual target-only wing funding, conversion, total own-position removal and market-limited opposing sale for both targets. The actual sale produces zero target and preserves all unsold inventory; external liquidity plus a restoring trade recovers sellability. These cases supply reference evidence for A1 and an O2 counterexample. They are not simulator parity because the canonical LiquidationQuote library is still pending.

## Canonical simulator implementation and first parity result

`LiquidationQuote.sol` now removes all three owned positions from active liquidity and
from a merged six-boundary gross/net overlay. The bitmap clears only boundaries with
zero remaining external gross liquidity, including shared boundaries whose original net
was zero. Fee growth is collected once using the real position checkpoint. The sale
uses protocol swap math, directional protocol fees, exact tick crossing and protocol
price limits. Empty bitmap words/gaps are traversed; reaching the protocol price limit
with input remaining reports market limitation. Exhausting the explicit step budget
reverts `QuoteWorkExceeded`, never returns an invented zero value.

`package-liquidation-tests.log`: all 13 liquidation suite tests passed, including 256
fuzz cases across target orientation, three overlapping positions, variable liquidity
and fee-generating trades. Exact sold/unsold/proceeds/V, final sqrt price, directional
tick and active liquidity match actual remove-all-then-swap execution. Deterministic
cases cover all-own/no-external, separated external depth, partial fills, shared zero-net
boundary, exact leftward boundary tick, both directional protocol fees and rejection
of duplicate positions, unexecutable signed deltas and unfinished work.

The library subsequently gained a no-swap projected-inventory entrypoint and an input
immutability fix; these changes are in the next validation run. This projected entrypoint
is valid for harvest/placement without price or external-liquidity changes. It is not a
claim of complete multi-transition quote support after projected swaps. The current
512-step cap needs full outer-transaction gas acceptance; it is an engineering bound,
not evidence that every tick-spacing/external-book configuration is admitted.

## Projected pool traversal checkpoint

`projection-pool-tests-retry.log`: production and tests compiled without viaIR;
14 suites finished with 109 passing tests and one failing withdrawal fuzz test.
The projected pool suite passed successive opposite-direction swaps against the
real PoolManager, including full Q128 fee-growth accumulation, protocol fees,
owned-liquidity removal/replacement and newly initialized bitmap boundaries.
These are pool-engine checks, not yet consumer compatibility evidence.

The failing withdrawal witness is preserved as
`test_regression_partialExitAfterMarketMove`: seed `(5661228, 14214, false)`.
The quoted payout was funded, but the remaining-value assertion required
503876736717 target units and observed 503876736716. The strict no-cost assertion
has not yet been relaxed; the funding sequence and execution rounding require
analysis against owner ruling O4. No haircut or extra share burn is permitted.

Sequential transition code and tests are now in progress. The first compiled
projection library measured 25176 runtime bytes (over EIP-170); it must be split
before any deployment or passing-package claim. This failed size gate is not
waived by the larger test harness limit.
