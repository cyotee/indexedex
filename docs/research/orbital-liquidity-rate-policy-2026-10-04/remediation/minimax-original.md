# Orbital liquidity rate policy — bounded remediation PRD + plan proposal (MiniMax M3)

- **Date:** 2026-10-04
- **Author:** MiniMax M3 (research-only)
- **Scope:** research-only PRD/plan draft to hand to an implementor. **No code, tests, shell, or config touched.**
- **Law inputs:** APEX D59/D60/D63 (`docs/audits/apex-2026-09-17-open-item-10-cp-hook-rate-providers-PRD.md` lines 1–13, `…-remediation-and-regression-tests.plan.md:149,153`); Orbital PRD addendum `UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md:828–834`; agent law `INDEXEDEX_AGENT_LAW.md:233–243`.
- **Preserved by design:** swap invariant (rated), SE buffer/unwrap execution quotes, first-mint scale and `kLast` on the rated book (D63), Weighted inventory policy, existing `gas_limit = 30_000_000_000` (`foundry.toml`), `R_SAFETY_MULTIPLIER = 10` (D21), hook flags min / pool-init UX (Orbital D59/D60).
- **NOT approved by this PRD:** new public ABI/storage, fee waiver, in-kind recovery route, rated bootstrap/fee redesign, override of Weighted or Hookless files.

## 1. Goal

Restore raw inventory LP ownership math (D59) at the four rated sites that drive share counts and proportional exit reads, while preserving the rated sphere invariant for pricing, preserving first-mint scale and `kLast` per D63, and making every post-state-change read (including unconditional `_recomputeL2` and `_syncVaultReserves`) rate-failure tolerant.

## 2. Bounded default (the only change set)

### R1. Replace rated effective with raw inventory in LP share/used math

| File | Site | Fix (in-place, no new storage) |
|---|---|---|
| `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol` | `_computeFullBook` lines 988–999; `_fullBookSharesUsed` lines 1066–1090 | Replace `_effectiveWad()` denominator (rated) with a raw-inventory twin: raw face `_toWad(token, l.reserves[token])` for raw legs; `_toWad(token, IERC20(se).balanceOf(address(this)))` for buffered legs. Replace `_previewClaimInAt` numerator (rated) with a buffering quote (see R2). Drop `_effectiveUsedWadToFace` rated step for buffered legs; share-count inversion is now direct on raw se-share count (no `invertBufferForEffective` round-trip). |
| same | `_computePartial` lines 1002–1014; `_partialSharesUsed` lines 1093–1103; `_partialUsed` lines 1116–1159; `_partialMinShares` lines 1162–1184 | Make raw inventory only: numerator = raw face (or raw se-share count when B6 flag); denominator = raw face (raw leg) or se-share count (buffered leg). Replace `_partialNavShares` `r*Wad = _toWad(token, _effectiveNativeAt(i))` (lines 1649–1651) with raw inventory; drop `_partialUsed` mixed-unit branch at 1147–1148 (`used0 = fromWadFloor(l.token0, fullBookUsedWad(minShares, _toWad(l.token0, r0), supply))`) and use `used0 = minShares * rawShares[i] / supply` (floor). |
| `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol` | `_planDeposit` lines 272–295; `_claimIn` lines 376–382 | Replace `_claimIn` (rated, with face-amount fallback at line 380–381) with raw se-share count: `shares = previewExchangeIn(token, amount, se)`; for raw legs `shares = amount` (raw face). `fullBookShares(fb)` then takes raw numerators over raw denominators. Drop the `rated == 0 ? amount : rated` fallback. |
| same | `_swap` lines 85–108; `_receiveOutput` lines 110–127; `_saleBudget` lines 135–145 | **No change.** Sphere stays rated (D60 swap invariant). Only the *terminal* `_planDeposit` mint moves to raw. |

### R2. Keep actual conversions as real SE calls

- `_previewBufferClaimIn` (`ClaimLib.sol:393–408`) stays as a *buffering quote* (D60 allows the SE preview for shares minted / pair paid out). It must not be used as a *reserve valuation*.
- `_previewUnwrapShares`, `_previewUnwrapForEffectiveOut`, `_bufferToken`/`_unwrapSeShares`/`_unwrapExactTokenOut` (Common.sol lines 514–617) stay unchanged.
- `_invertBufferForEffective` (ClaimLib.sol:242–276) is no longer used in LP math after R1; retain for `_faceInToEffectiveNative`/`_effectiveInToFaceIn` swap-side composition only (Common.sol lines 824–896).

### R3. Unconditional L2/sync + fee-mint rate-failure liveness

| File | Site | Fix (minimal) |
|---|---|---|
| Common.sol | `_recomputeL2` lines 472–480; called at lines 1251, 1362, 1744 | Wrap the `_effectiveWad()` read in `try { … } catch { /* keep l.L_SQUARED as-is */ }`. On provider revert / zero / short return, leave `L_SQUARED` unchanged. **Do not** rewrite to raw inventory — `L_SQUARED` is sphere-rated by D60. Cache, do not zero. |
| Common.sol | `_syncVaultReserves` lines 459–469; called at 1253, 1366, 1748 | Wrap `_updateReserve` calls in try/catch; on failure leave `MultiAssetBasicVaultRepo` snapshot as-is. Document that the multi-asset vault discovery surface may lag the rated book when the rate fails (acceptable; the surfaced value is informational). |
| Common.sol | `_maybeMintProtocolFee` lines 899–915 (called at 1200, 1276, 1394, 1443, 1835, 1863) | Early-return when `getRateFailClosed` would revert: pre-fetch the rate once in a single `try { rate = getRateFailClosed(rp); } catch { return 0; }`. On failure, **skip protocol mint for this op** (do not waive fees in general — kLast remains for the next alive read). Document owner-approved degradation. |
| Common.sol | `_snapshotKLastIfFeeOn` lines 918–929 (called at 1252, 1364, 1746) | Same try/catch pattern. On failure, leave `kLast` unchanged (preserves D63 rated measure when alive; safe when dead). |

**No fee waiver** — protocol mint is skipped only when the rate is dead, not unilaterally removed. No L_SQUARED zero on failure (preserves swap invariant for next alive read).

### R4. Surface / hook signature compatibility

- **No new selectors, no new events, no new storage slots.** Existing getters remain; `rateProviders()` / `rateProvider(address)` getters stay where they already are.
- `_bufferLastUsed` (Common.sol:620–625), `_applyAdd` (1216–1254), `_removeLiquidityAndSettle` (1268+), `_addLiquidity` (1187–1213), `WithdrawTarget.exitSingleAssetExactBptIn` (136–177), `_depositFlexible` (1371+) — internal call shapes unchanged.

## 3. Exact file/test scope

### Files to edit (production)

1. `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol` — R1 (`_computeFullBook`/`_fullBookSharesUsed`, `_computePartial`/`_partialSharesUsed`/`_partialUsed`/`_partialMinShares`/`_partialNavShares`), R3 (`_recomputeL2`, `_syncVaultReserves`, `_maybeMintProtocolFee`, `_snapshotKLastIfFeeOn`). No ABI change.
2. `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol` — R1 (`_planDeposit`, `_claimIn` and dependents inside `planDeposit`/`previewShareDeposit`/`previewJoinAfterDeposit`/`previewBondAfterDeposit`/`_depositAtState` that consume `_claimIn`).
3. `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookMath.sol` — **only if** R1 introduces a new pure helper `inventoryMinShares` or `inventoryFullBookShares`. Otherwise unchanged. Math stays pure sphere / WAD / NAV.

### Files NOT edited

- `weighted/…` — out of scope; family policy is different and unchanged.
- `…/standardExchange/dual/`, `…/constantProduct/`, `…/single/`, `…/stable/quad/`, `…/orbital/` raw monomorph — siblings only; per-family.
- `hooks/uniswap/v4/orbital/` (raw monomorph), `standardExchange/single/` (no reserve), `factory/` — out of scope.
- `lib/crane/`, `lib/DeFiHackLabs/`, `lib/balancer-docs/`, `lib/balancer-v3/`, frontend, Anvil scripts.
- Pre-staged Init amendment files (PRD `/…/STAGED_INIT_PRD.md`) — amend does not touch R1/R3 sites.
- B6 remediation PRD (`…/UNISWAP_V4_SE_ORBITAL_BUFFER_MIN_SE_AND_B6_REMEDIATION_PRD.md`) — surface unchanged.
- Aperture PRD/plan (`docs/plans/UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD*.md`) and `Hookless analytic/*` — explicitly out of scope (PRD line 62).

### Tests to add or extend (hermetic default profile; no fork DoD change)

Under `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/`, extend:

| Test | Asserts |
|---|---|
| `UniswapV4StandardExchangeOrbitalBufferHook_Liquidity_RawOwnership.t.sol` | `addLiquidity` (full book), `removeLiquidity` (raw proportional), `depositFlexible` raw-only flags: LP minted on raw share count; rate provider reverts mid-call do **not** change ownership or revert the call. |
| `UniswapV4StandardExchangeOrbitalBufferHook_ZapIn_TerminalMint.t.sol` | `depositSingle` terminal mint matches `previewDepositSingle` to the unit when rate is alive, identity-rate, and non-identity-rate (≤ 1 wei rounding). Raw share-count path is rate-invariant; rated path (today) shows the documented floor drift. |
| `UniswapV4StandardExchangeOrbitalBufferHook_PartialJoin_UnitConversion.t.sol` | Partial join with all `*IsSeShare == false`: LP matches raw share-ratio floor; `used*` equals raw face pull. SE-share B6 partial path: matches raw se-share ratio. No SE deposit-fee dilution of existing LPs beyond what the buffering quote already prices in. |
| `UniswapV4StandardExchangeOrbitalBufferHook_RateFailureLiveness.t.sol` | After R3: revert-rate provider during `addLiquidity` ⇒ op succeeds, protocol fee skipped, `kLast` cached. Revert during `removeLiquidity` ⇒ payout succeeds, post-payout `_recomputeL2`/`_syncVaultReserves` no-op, `kLast` cached. Revert during `_partialNavShares` sphere-NAV step ⇒ op succeeds (raw-inventory NAV, no rated read). |
| `UniswapV4StandardExchangeOrbitalBufferHook_SwapRatedUnchanged.t.sol` | All swap paths (V4 doors, `exchangeIn`/`exchangeOut`, internal zap swaps) still read rate; sphere stays rated; `quoteAssets`/`previewExchangeIn(se, heldShares, token)` still forbidden as reserve valuation. |

Differential suite: replay current rated-LP tests; assert behavior change is bounded to ≤ `MINIMUM_LIQUIDITY` wei at any mint and zero at all exits and zero-fee-on cases.

### Regression matrix

Hermetic matrix `0/1/2/3 SE × RP on/off × fee on/off × kLast 0/>0` plus adversarial (reentrancy, donation, SE revert mid-buffer, distinct-SE binding, full drain attempts). Existing TestBase `_ensureProductDoorsAndFinalize` (per staged init plan §5 F7) keeps prod-only lifecycle helpers green.

## 4. Acceptance criteria

- **A1.** After R1, a `getRate` revert (or short return or zero) on any leg does **not** revert `_addLiquidity`, `_removeLiquidity`, `_depositFlexible` (raw flags), `_withdrawFlexible` (raw flags), or any proportional exit path; the call settles on raw inventory.
- **A2.** `_planDeposit` terminal mint equals raw-share-ratio floor; `previewDepositSingle` matches execution bit-exactly at same `R`, same oracle fees, same SE state, with raw-share arithmetic.
- **A3.** `_computePartial` uses raw face (raw leg) or raw se-share count (buffered leg) on both sides of the ratio; no `_effectiveWad()` read in this path.
- **A4.** Sphere pricing unchanged: `_swapExactInWithFee`, `_swapExactOutWithFee`, zap internal `_swap`/`_saleBudget`, `_loadSphereLegs` still read `_effectiveWad()`.
- **A5.** `_maybeMintProtocolFee` skips when rate fails; `kLast` cached; next alive read resumes. **No fee waiver** — fee-on/kLast-alive/alive-rate ⇒ same rated mint as today.
- **A6.** `_recomputeL2` and `_syncVaultReserves` cache on rate failure (no zero); swap invariant usable next block.
- **A7.** `WeightedFundedBindingTest` claim retired: no new FullSpread suite change required; existing Orbital SeMatrix COMPATIBLE/REJECTED rows continue to apply. No new historical-claim assertion.
- **A8.** Pre-existing forge compile (`forge build`) green; no `via_ir`; no `new` SUT.
- **A9.** Gas: no measured gas reduction *or* regression claim. `gas_limit = 30_000_000_000` ceiling unchanged; the `Common.sol:1929–1931` 31M OOG comment is a comment, not a measurement.

## 5. Unresolved owner-decision branch (explicit deferred)

**OD-1. In-kind recovery when rated kLast is unreachable.** If the user wants a fee-off raw-payout path that *also* skips the rated `_recomputeL2` and protocol-fee paths entirely (not just caches on failure), an owner ruling is required to add a new fee-oracle-disables-protocol-mint flag or accept the rated-cached state. **This PRD does not authorize it.** Place a single explicit `// OWNER-DECISION: in-kind recovery — pending OD-1` comment in `_maybeMintProtocolFee` and `_recomputeL2`.

**OD-2. Authorize R3 try/catch as a non-owner change.** Default behavior change: rate failure ⇒ protocol fee skipped for that block. Owner ruling needed if any policy says "must revert on dead rate." Recommend: accept, document, and link to OD-1 for richer recovery if policy later disagrees.

**OD-3. Per-family rated first-mint / kLast divergence.** Orbital keeps rated first-mint scale + `kLast` (D63); Weighted uses inventory for everything (D23/Q7). Owner ruling: confirm no cross-family harmonization is required.

**OD-4. Unrelated historical failures.** Pre-existing LSP/forge build errors in `TestBase_UniswapV4FullSpreadStandardExchangeVault_Adversarial.sol`, `SeMatrix_FullSpreadPonsV2Fixture.sol`, `UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticSwapMath.sol`, `…/AnalyticSwapMath.t.sol`, and `ReleaseRegression.t.sol` are **not** in scope of this PRD and must not be touched or attributed as regressions introduced by this change. Any pre-existing dirty file outside `orbital/` is unchanged.

**OD-5. Historical "fits gas" / "passes tests" claims.** Not adopted. PRD/plan/implementor must not assert current test passes or current gas fit; only assert A1–A9 above are achieved by a measured test run after the edit lands.

## 6. Anti-patterns (do not introduce)

- New public ABI / new event / new storage slot.
- `via_ir`.
- `new` SUT, `MockStandardExchange`, mocked rate provider, mocked hook.
- Modifying Weighted, Dual, Single-CP, stable/quad, raw monomorph orbital, or factory files.
- Touching Aperture PRD/plan or `Hookless analytic/*`.
- Silently zeroing `L_SQUARED` or `kLast` on failure.
- Treating `_claimIn` rated path as a substitute for raw share count after R1.

## 7. Implementation order

1. Land a measurement baseline (current forge test output for the matrix) **before** edits. Do not assert the baseline value in the PRD.
2. R1 Common.sol edits, then ExitQuoteLib edits, then `forge build` + hermetic tests.
3. R3 try/catch around `_recomputeL2`, `_syncVaultReserves`, `_maybeMintProtocolFee`, `_snapshotKLastIfFeeOn`. Tests for A1, A5, A6.
4. Differential suite: replay old rated-LP tests, document drift ≤ 1 wei on mints, zero on exits.
5. Adversarial + lifecycle regression. **No fork DoD change.**
6. Leave `WeightedFundedBindingTest`, "fits gas", "passes tests" claims out of the final report.

---

*End of bounded proposal. Saved to `docs/research/orbital-liquidity-rate-policy-2026-10-04/remediation/minimax-original.md`. Originals preserved. No code/test/config/shell executed.*