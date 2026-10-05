# Orbital raw-liquidity remediation — Kimi K3 proposal (research only)

**Author:** Kimi K3. **Date:** 2026-10-04. Bounded round; prior-round context retained. No code/test/config executed. This is a requirements/plan proposal for the moderator's PRD; it authorizes nothing.

**Approved direction (user):** raw inventory for LP ownership; rated swap pricing. Basis: `docs/agent/INDEXEDEX_AGENT_LAW.md:233-242`; `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md:149-153` (D59/D60/D63); Orbital addendum `contracts/hooks/uniswap/v4/standardExchange/orbital/UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md:828-835`; Weighted peer addendum `…/weighted/UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_PRD.md:920-927`.

Path shorthand: `O/` = `contracts/hooks/uniswap/v4/standardExchange/orbital/`; files `Common`, `ExitQuoteLib`, `ClaimLib`, `Math` = the full `UniswapV4StandardExchangeOrbitalBufferHook*.sol` names.

## Requirements (R1–R7)

- **R1 Full-book joins → raw share ratios.** Rewrite `_fullBookSharesUsed` (`O/Common:1066-1090`): per leg, numerator = shares a buffering would mint from the offered face (`IStandardExchangeIn.previewExchangeIn(token, offer, se)` — a buffering quote, no rate); denominator = live `IERC20(se).balanceOf(hook)`; raw legs keep face/`reserves`. `shares = min_i(dShares_i/held_i) × supply`. Used face per leg = inverse of the buffering quote for the pro-rata share delta, reusing the existing inversion pattern (`O/Common:1106-1113`, `:879-880`; bounded search as in `_invertBufferForEffective`, `O/ClaimLib:250-276`). **No `getRate` on the join LP path.**
- **R2 Zap terminal mint → raw shares; swap split stays rated.** In `O/ExitQuoteLib:_planDeposit` (`:272-295`) keep `_depositSales`/`zapSplitWad` rated (the swap invariant, unchanged) but compute `q.shares` and `q.used` from raw share ratios at the simulated post-swap state (offered shares minted per leg over held shares), replacing rated `fullBookShares` over `_claimIn` outputs. Keep `_depositSupply` (`:384-399`) rated — D63 protocol-fee exception. Remove reliance on the face fallback (`_claimIn` `:379-381`; `ClaimLib:309`) for the mint computation: a zero SE mint/claim preview must revert on the mint path, not silently substitute face units into a share ratio.
- **R3 Partial/single-sided joins → unit-consistent raw.** `_partialMinShares` (`O/Common:1162-1184`) currently divides raw face by rated effective; `_partialUsed` (`:1147-1158`) then pulls the rated-native `used` as face with no inversion. Convert both to raw share ratios with the same inverse-quote helper as R1. Also fix the quote twin `_partialDepositAtState` (`O/ExitQuoteLib:401-425`, rated pro-rata at `:410`). Deliberate keep: `_capFaceUnderRadius` (`O/Common:1017-1040`) stays rated — the radius is a rated-domain safety bound set at first mint (D63); flag for owner confirmation (U4).
- **R4 Preserve SE buffer/unwrap execution.** No change to buffer-last execution or minOut patterns (`O/Common:518-536, 581-598, 620-625`); SE is asked only shares-minted / pair-paid.
- **R5 Proportional payouts unchanged.** `_proRataOut`/`_burnAndPay`/`_previewRemoveLiquidity` (`O/Common:1287-1316, 1319-1368, 1789-1817`) already conform; byte-identical outputs required.
- **R6 Rate-failure liveness — bounded default, deferred branch.** Default (no approval assumed): keep fail-closed semantics and **document** that exits revert on provider failure because post-payout bookkeeping reads rates unconditionally — `_recomputeL2` (`O/Common:1362` → `:472-480`) and `_syncVaultReserves` (`:1366` → `:459-469`) are ungated, unlike the fee reads (`:899-903, 918-929`). Pin this with a revert assertion test. **Deferred owner-decision branch (U1):** a raw in-kind recovery route or failure-tolerant bookkeeping on exits — this changes written state under failure and is **not** in the default scope.
- **R7 First mint and fees unchanged.** `_computeFirstMint`/`_sumFaceEffectiveWad` (`O/Common:971-985, 1054-1063`) and `_maybeMintProtocolFee`/`_snapshotKLastIfFeeOn` stay rated per D63. No fee waiver, no rated-bootstrap redesign.

## Non-goals / constraints

No new ABI selectors, no storage-layout changes (rewrites reuse existing structs and internal helpers); no Weighted changes (already inventory-domain: `WeightedBufferHookTarget.sol:310-314`, `WeightedBufferHookMath.sol:261-274`); no touch of hookless/FullSpread analytic work or other dirty files; swap invariant, zap split, fee semantics, `MINIMUM_LIQUIDITY`, `R_SAFETY_MULTIPLIER`, and loop bounds (`_faceForClaim` ≤8 probes, `O/ExitQuoteLib:347-374`; `_invertBufferForEffective` ≤64, `O/ClaimLib:250-276`) preserved. Historical "old planner fits gas" is a comment (`O/Common:1929-1931`), not evidence — gas acceptance must be **measured on this change**, never asserted from history.

## File scope

- `O/Common`: `_fullBookSharesUsed` (1066-1090), `_partialSharesUsed`/`_partialUsed`/`_partialMinShares` (1093-1184); join-path use of `_previewClaimInAt` (1043-1051) restricted to first mint.
- `O/ExitQuoteLib`: `_planDeposit` (272-295), `_faceForClaim` raw-target variant (347-374), `_claimIn` mint-path fallback removal (376-382), `_partialDepositAtState` (401-425).
- `O/ClaimLib`: add a raw shares-minted preview helper (or call `previewExchangeIn` directly at sites); do not alter `ratedNative`/`sharesForNativeUp` (swap path depends on them, `:317-330`).
- Interfaces/PRD: no selector changes; PRD addendum note that liquidity math is expressed in raw shares (editorial).

## Test scope (hermetic, production-first; existing TestBases `O/TestBase_…_B_*` decimal matrix)

1. **Rate-independence differential:** for rates {0.5e18, 1e18, 1.5e18, 2e18} × decimals rows, identical join/zap inputs must mint identical shares; a provider rate move between two identical joins changes swap quotes but not minted LP per unit inventory. Needs a mutable-rate fixture — extend `contracts/test/libs/RateProviderFixtureLib.sol` usage (test-infra only).
2. **Conservation:** partial/full/zap joins must not dilute existing LPs beyond the SE's own deposit fee; floor rounding favors existing LPs (under-mint).
3. **Exit byte-identity** vs pre-change outputs; **swap quote byte-identity** (untouched path).
4. **Preview fidelity:** `preview* == execution` (D49) for every changed route.
5. **Liveness pin:** reverting provider ⇒ documented revert set (default) on join/exit/swap.
6. **Gas:** measured before/after on this branch under `foundry.toml:38` limit and a stated chain cap; regression threshold defined against the measured baseline only. Pre-existing unrelated failures (e.g., FullSpread hookless analytic compile errors) are out of scope, must not be attributed to this change, and must not be "fixed" here.

## Acceptance

All tests above green on a fresh baseline; zero rate reads on proportional join/exit LP paths (grep-auditable); zap mint rate-independent; gas report attached; PRD/plan updated.

## Unresolved owner decisions (deferred; default = preserve current semantics)

- **U1** Rate-failure recovery route / failure-tolerant exit bookkeeping (default: fail-closed revert, documented).
- **U2** Orbital PRD D27 (`:282`, rated LP NAV/`kLast`) vs addendum raw wording — confirm addendum supersedes for liquidity.
- **U3** Weighted `kLast` inventory-only (`…WEIGHTED…PRD.md:318`) vs AGENT_LAW "kLast rated, as before" (`:240`) — family divergence.
- **U4** D63 first-mint/`kLast` rated exception is CP-context; confirm its application to Orbital and to the rated `_capFaceUnderRadius` radius bound.
