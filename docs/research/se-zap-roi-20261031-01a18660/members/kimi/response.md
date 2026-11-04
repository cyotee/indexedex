# Kimi response

## Identity

- Member: Kimi.
- Requested model route: `kimi-coding/k3.1-pro:high`, global route.
- Actual Native identity: not exposed.
- Run: `se-zap-roi-20261031-01a18660`.

## Question and targets

For `previewZapCredit`, `maxZapBps`, and `maxZapTickMove`, does the utility of the public function justify its incremental implementation cost beyond the entry route the family already has to build?

The targets are the three public functions only. Internal zap limits and their enforcement are separate decisions. This response does not reopen the locked drops of `previewWithdrawalMode` or the family `wrappedNative()` getter.

## Evidence

1. The zap review section says that `previewZapCredit(tokenIn, amountIn)` returns shares, per-currency credited amounts, and per-currency uncredited amounts. It defines `maxZapBps()` and `maxZapTickMove()` as getters for configured limits and explicitly warns that dropping a getter does not drop its cap (`PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`, lines 22-29).
2. The prior remaining-functions report establishes that `previewExchangeIn.amountRefunded` is only unkept input in the token supplied by the caller. It is not the `credit0`, `credit1`, `uncredited0`, and `uncredited1` split. The same report leaves all three public functions unsettled while recording no proposal to remove the internal caps.
3. The current `previewZapCredit` body is a thin adapter: it calls `_plan(_zapOperation(token_, amount_))` and returns `plan_.shares`, the two `plan_.credit` fields, and the two `plan_.uncredited` fields (`UniswapV4PairTokenStandardExchangeVaultQuoteTarget.sol`, lines 139-153). It contains no second economic planner.
4. The planner used by that adapter is also on the execution path. Current `exchangeIn` constructs a `DepositZap` operation and routes it through `_exchange` (`UniswapV4PairTokenStandardExchangeVaultExecution.sol`, lines 149-183); `_exchange` calls the common `prepare` routine (lines 268-269), and `prepare` calls `Planner.plan` before settlement (lines 292-310). Thus the current shape supports reusing the entry plan rather than implementing a parallel quote algorithm.
5. Both current cap getters are direct storage reads: `maxZapBps()` returns `Repo._layoutStruct().config.maxZapBps`, and `maxZapTickMove()` returns `Repo._layoutStruct().config.maxZapTickMove` (`UniswapV4PairTokenStandardExchangeVaultQueryTarget.sol`, lines 112-130). Their interface return types are respectively `uint16` and `int24` (`IUniswapV4PairTokenStandardExchangeVault.sol`, lines 312-324).
6. The stage-one PRD is evidence only for what the baseline caps enforce. It places `maxZapBps` in instance configuration, applies it to entry size, and applies `maxZapTickMove` to the caller's entry swap (lines 171-185 and 533-547). Its compound quarter-cap is baseline policy, not a requirement for this family (lines 599-624).

## Assumptions

- The family will implement single-token entry with one authoritative planner whose result includes the share and residual accounting needed by execution. `previewZapCredit` must consume that same plan; a second planner is not an acceptable implementation strategy.
- The entry plan retains a meaningful distinction between credited and uncredited currency amounts. If the family later eliminates that distinction, the preview's utility must be reassessed rather than preserved as an empty shell.
- The internal size and tick-movement limits remain stored and enforced where the selected family policy requires them, regardless of whether their public getters are exposed.
- The current PairToken bodies demonstrate implementation shape only. They do not lock stage-one residual accounting, formulas, or compound-cap policy for the full-spread family.
- Implementation-cost estimates include interface and target plumbing, documentation, and focused conformance testing, not merely the few lines in the current function bodies.

## Coverage

### `previewZapCredit`

**Utility:** This provides information that `previewExchangeIn` plus a revert does not. A caller can explain how a single-token deposit becomes shares, how much of each pool currency earns those shares, and what remains uncredited before committing funds. That is materially different from knowing only the share amount and a single-input-token refund. It is useful for integrator displays, accounting reconciliation, and user review of residual treatment.

The value depends on exposing the authoritative entry result. A separate simulation could drift from execution and would have negative utility even if its initial implementation appeared straightforward.

**Incremental difficulty:** Low to moderate when implemented as the observed adapter over the common planner. The economic planning and cap enforcement already belong to `exchangeIn`; the additional work is the public ABI, extraction of five existing plan fields, documentation, and tests that the preview agrees with execution and `previewExchangeIn` on shares and revert behavior. It would be high and unjustified if it required a second planner or independently recreated residual accounting.

### `maxZapBps()`

**Utility:** An integrator can combine the configured basis-point limit with the relevant reserve to choose or validate an input size before submission. A revert reveals that a particular attempt failed; it does not reveal the configured limit, and repeated probing is not an adequate substitute. Operators also get a direct way to inspect the policy governing entry size.

**Incremental difficulty:** Low. If the cap is already stored for enforcement, the getter is a typed configuration read plus interface, documentation, and a small getter/consistency test. No planner or new economic formula is needed.

### `maxZapTickMove()`

**Utility:** This is less directly actionable than the size cap because a caller still needs pool state and swap simulation to translate a tick bound into a maximum input. It nevertheless lets integrators reproduce the entry guard and explain a rejected quote or execution, and lets operators inspect the configured bound without inferring it from failures. Its utility is real but narrower than `maxZapBps()`.

**Incremental difficulty:** Low for the public getter. It is another typed read of configuration already needed by entry enforcement. The getter does not implement tick measurement, swap simulation, or the guard itself; those belong to the entry route.

## Conclusions

| Public function | Recommendation | ROI rationale | Separation from internal policy |
| --- | --- | --- | --- |
| `previewZapCredit` | **Implement** | The per-currency credit and uncredited split is useful information unavailable from `previewExchangeIn` and a revert. Reusing the planner already required by `exchangeIn` keeps the incremental cost proportionate. | This recommendation covers only the read-only public preview over the authoritative entry plan. It neither adds nor removes an internal cap and does not adopt stage-one residual or compound formulas. If sharing the entry planner were impossible, this recommendation would not justify a second planner. |
| `maxZapBps()` | **Implement** | The getter provides directly actionable sizing and operational configuration visibility for very little incremental work. | Keep the internal size cap and its required enforcement independently of the getter. This decision does not require copying the stage-one compound quarter-cap. |
| `maxZapTickMove()` | **Implement** | Its diagnostic and integration value is narrower than the size getter's, but the very low cost of exposing stored configuration still produces sufficient ROI. | Keep the internal entry tick-movement cap and its required enforcement independently of the getter. This decision does not extend that cap to compound or enact stage-one formulas. |

All three public functions are worth implementing under the shared-planner and stored-cap assumptions above.

## Limits

This is a research recommendation, not implementation authority and not a PRD lock. No code, tests, builds, or deployments were run. No peer responses were read. The recommendation does not decide residual ownership, exact cap formulas, compound policy, selector placement, or deployment packaging. If the full-spread design removes uncredited residual accounting or cannot expose the authoritative entry plan, `previewZapCredit` needs a fresh ROI decision rather than a parallel planner.
