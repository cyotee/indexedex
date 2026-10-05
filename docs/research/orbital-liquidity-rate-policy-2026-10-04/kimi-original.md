# Orbital hook liquidity rate policy — Kimi K3 original first pass

**Author:** Kimi K3 (independent first pass; no peer artifacts read)
**Date:** 2026-10-04
**Question:** Should Orbital SE buffer hook liquidity operations quote rates for every operation, only zap-in/zap-out types, or never (raw balances only)?
**Code observed:** Solidity 0.8.35 repo state at root `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex`, accessed 2026-10-04.

## Verdict (inference from law + code)

Neither "every operation" nor "never": **raw share ratios for LP issuance/proportional exits; rates only where a swap is priced** (standalone swaps and the internal swaps inside zap-in and single-asset exits). This is the locked law:

- `docs/agent/INDEXEDEX_AGENT_LAW.md:233-242` (APEX D60, LOCKED 2026-09-22): "The virtual swap invariant uses the rated reserves. **Liquidity issuance and proportional exits use raw balances** of the concrete reserve (D59)… `kLast` and the protocol-fee LP are computed on the rated book, as before."
- `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md:149` (D59 two invariants) and `:153` (**D63**: "later joins and exits follow raw balances; the first mint's scale and `kLast` … stay on the rated book").
- Orbital PRD addendum, `UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md:828-835`: "Liquidity operations use raw balances (D59): LP issuance for a buffered leg follows the share ratio, exits are pro rata in raw shares and raw tokens"; supersedes only SE-own-quote valuation, and `ratedNative`/`sharesForNativeUp` + "the rated `ExitQuoteLib` paths are the only valuation" (for the swap side).
- Weighted SE peer law is stricter: `standardExchange/weighted/UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_PRD.md:61,318` (D23/Q26) — **all** liquidity ops incl. first-mint and `kLast` use inventory only, "No `getRate()`"; Weighted code comments confirm inventory-domain LP algebra (`UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:216,269-270`). Note a documentary tension with AGENT_LAW's "kLast on the rated book" (family-scoped difference; unresolved).

Single-asset joins/exits *are* zaps (they contain swaps), so they legitimately need rates **for the swap legs**; their LP mint/burn ratio should still be raw.

## Observed code facts (Orbital)

1. **Proportional exit is raw (conforms).** `_proRataOut` (`UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:1287-1316`), `_burnAndPay` (`:1319-1368`), `_previewRemoveLiquidity` (`:1789-1817`): `shares * reserves[token] / supply` for raw legs, `shares * seBal / supply` for buffered legs; `ClaimLib.previewUnwrapShares` (SE buffering quote, not a rate) converts shares to pair payout. Rate-free payout.
2. **Full-book proportional join uses rated coordinates.** `_fullBookSharesUsed` (`Common.sol:1066-1090`): numerators `_previewClaimInAt` (rated claim of face offer, `:1043-1051`), denominators `_effectiveWad()` (rated, `:351-356`).
3. **Partial join mixes units.** `_partialMinShares` (`Common.sol:1162-1184`): numerator raw face `_toWad(token, a_iMax)`, denominator rated `_toWad(token, r_i)` with `r_i = _effectiveNativeAt(i)`. On a buffered leg the joiner is credited `F / (held×rate)` while the book gains only `claim(F)/(held×rate)` — SE deposit fee dilutes existing LPs (inference; magnitude = SE deposit fee).
4. **Zap planner is rated and is the execution path, not just a quote.** `_planZap` → `ExitQuoteLib.planDeposit` (`Common.sol:2000`); `_planDeposit` (`ExitQuoteLib.sol:272-295`) feeds rated `legs[i].effective` and rated `_claimIn` (`:376-382`) into `Math.fullBookShares` (`Math.sol:146-162`). `_depositSupply` (`ExitQuoteLib.sol:384-399`) adds protocol-fee LP from the rated book (sanctioned by D63).
5. **Identical-rate cancellation.** `ClaimLib.ratedNative` (`ClaimLib.sol:317-322`) is linear in shares (`mulDiv(shares, rate, scale)`, floor). Per leg, `ratedNative(minted,r) / ratedNative(held,r)` equals `minted/held` in exact arithmetic; the rate cancels. Rated-vs-raw LP issuance therefore diverges only by integer rounding (≤1 unit per term) and the rated protocol-fee supply addend. So the moderator's assertion that `_planDeposit` is a bug **solely** for using rated `effective` + `fullBookShares` is **not established**: economically equivalent modulo rounding; formally divergent from the raw-balance wording. The substantive raw-law deviations I found are (3) and (8), not the zap planner's full-book step.
6. **Swaps use the rated book** (`_loadSphereLegs`, `Common.sol:789-803`; zap `_saleBudget`, `ExitQuoteLib.sol:135-145`) — correct per the two-invariant law.
7. **Single-asset exit exists despite PRD "No zap-out in v1"** (PRD line 73 vs `WithdrawTarget.sol:136-173` `exitSingleAssetExactBptIn`: proportional raw removal then residual internal swaps `_swapExitResidual`→`_internalSwapExactIn`; preview via `ExitQuoteLib.preview`, `:29-47`). PRD/code drift (fact), or the PRD line is stale (inference).
8. **Rate-failure liveness is only partial.** Rates fail closed (`getRateFailClosed`, `ClaimLib.sol:332-338`; `RateProviderRequired` at `:388,405,418`). The exit *payout* is rate-free, but `_removeLiquidityAndSettle` calls `_maybeMintProtocolFee()` (`Common.sol:1276`) and `_burnAndPay` calls `_snapshotKLastIfFeeOn()` (`:1364`); both read `_effectiveWad()` (rated) whenever fees are on and `kLast != 0` (`:899-929`). So a reverting/zero rate provider bricks **all joins and exits while protocol fees are active**, even though the raw payout math needs no rate. Swaps always need rates (by design). This is the real liveness surface, independent of the rounding debate.
9. **Rate reads vs transition simulation.** Rates are cheap fail-closed staticcalls; the expensive part of zap/exit quotes is the `IStandardExchangeTransitionQuote` state simulation (`ExitQuoteLib.sol:61-69, 92-98, 119-127`) modeling withdraw/swap sequences against evolving SE states. That simulation is required for zap quote fidelity (D49 bit-exact previews) regardless of rate policy — a "raw only" policy would not remove it; it would only change the final share-ratio step.
10. **Fee accounting:** trading fee `dexSwapFeeOfVault` nets swap inputs (`ExitQuoteLib.sol:140-143`); growth fee `usageFeeOfVault` mints protocol LP on rated `cbrt`/sum roots (`Common.sol:388-409`, `_maybeMintProtocolFee` `:899-915`) — rated book, per law.

## Prior-claim verification (independent)

- **`WeightedFundedBindingTest` exists** as a contract at `test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol:171` (behavior `:21-167`: bond debits, selectors, principal funding). The file contains **zero `FullSpread` occurrences** (grep; observed). Its TestBase (`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol:38-55`) binds `SimpleYieldERC4626` stub SEs + `RateProviderFixtureLib` to the Weighted SE buffer hook. → The claim it "proves FullSpread compatibility" is **unsupported** by these fixtures. FullSpread is a separate family (`docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md`; `TestBase_UniswapV4FullSpread*`).
- Gas-budget tests in that file (`:262`, `:275`) belong to `OrbitalV4PositionFundedBindingTest` (`:209`), not the Weighted binding → "old planner fits gas" is also not proven there. I ran no tests (forbidden); gas adequacy of `planDeposit`/`_faceForClaim`/`_invertBufferForEffective` bounded loops remains **unverified**.
- D-number collision caution: Orbital-local D59/D60 = hook flags / pool-init UX (Orbital PRD `:336-337`); APEX D59/D60/D63 = rate-provider/held-reserve rulings. The addendum cites the APEX rulings.

## External reference (Context7, accessed 2026-10-04)

Balancer docs (`/balancer/docs`, rate-providers.md): `IRateProvider.getRate()` returns 18-decimal rates; pools scale raw balances by rates for pricing; rate-scaling is the swap-side pattern. Consistent with the two-invariant design (rated swap book, raw liquidity ratios).

## Confidence / missing evidence

- High: raw proportional exit path; rated zap planner on execution path; cancellation linearity; liveness coupling via fee accounting.
- Medium: `_partialMinShares` mixed-unit dilution impact (needs numeric tests to quantify; inference from unit analysis).
- Not done (no shell/tests permitted): compiling, gas measurement, executing `WeightedFundedBindingTest`; internals of `LegLib.rateAfterExchange`, `_executeDepositSinglePlan` (`Common.sol:1849+`, unread), `StandardExchangeRateProvider` source of truth.
