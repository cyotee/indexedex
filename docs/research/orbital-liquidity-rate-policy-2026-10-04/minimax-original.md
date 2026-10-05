# Orbital liquidity rate policy — MiniMax M3 original first-pass findings

- **Author / model:** MiniMax M3 (independent first pass; no peer artifact read)
- **Date:** 2026-10-04
- **Scope:** Should rates be quoted for every operation, only zap-in / zap-out types, or never (raw balances only) for `UniswapV4StandardExchangeOrbitalBufferHook`?
- **Out of scope (this pass):** executing any change, reading peer researchers' files (any tool), reading prior-council reports (any tool). Source: only product/PRDs, code under `contracts/hooks/uniswap/v4/standardExchange/orbital/`, repo agent law.

## TL;DR

Per APEX **D59 (locked 2026-09-21)** and **D60 (locked 2026-09-22)**, as recorded in `docs/audits/apex-2026-09-17-open-item-10-cp-hook-rate-providers-PRD.md` and reiterated verbatim in the Orbital PRD addendum (`UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md` § Addendum, lines 828–834) and `docs/agent/INDEXEDEX_AGENT_LAW.md` § "Uniswap V4 SE buffer hooks: held-reserve valuation (APEX D60, LOCKED 2026-09-22)" (lines 233–243):

> **Liquidity operations, LP issuance and proportional exits use raw balances of the concrete reserve. The virtual swap invariant uses the rated reserves.**

Answer to the question: **rates must be quoted for swap operations only, never for liquidity operations.** Liquidity = raw balances; swap invariant = rated (raw × rate). This is exactly the user's stated intended law ("liquidity uses raw balances to avoid price manipulation").

## 1. Normative authority

| Source | Lines | What it locks |
|---|---|---|
| `docs/audits/apex-2026-09-17-open-item-10-cp-hook-rate-providers-PRD.md` (APEX D60, owner-signed 2026-09-21) | 1–13 (rule 1–5) | Hook values a held reserve as **raw held balance** unless a rate provider is configured for that leg, in which case value = `held × rate`. Hook never derives a rate from the SE's own quotes. A buffered leg must carry a rate provider (`RateProviderRequired`); a raw leg may optionally carry one. **D59: Liquidity operations, LP issuance and proportional exits use raw balances of the concrete reserve. The virtual swap invariant uses the rated reserves.** |
| `docs/agent/INDEXEDEX_AGENT_LAW.md` § "Uniswap V4 SE buffer hooks: held-reserve valuation (APEX D60, LOCKED 2026-09-22)" | 233–243 | Same rule, project-wide. Applies to every reserve-holding buffer hook under `contracts/hooks/uniswap/v4/standardExchange/**` (weighted, curve-quad, Balancer-quad, **orbital**, single-CP, dual-CP). The non-CP single buffer hook under `standardExchange/single/` is the only exception (holds no reserve). |
| Orbital PRD addendum, `contracts/hooks/uniswap/v4/standardExchange/orbital/UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md` § "Addendum: APEX D60 held-reserve valuation (2026-09-22)" | 828–834 | Same rule, **explicitly supersedes** any statement in the Orbital PRD that values a held SE leg through the SE's own quote. Reiterates: "Liquidity operations use raw balances (D59): LP issuance for a buffered leg follows the share ratio, exits are pro rata in raw shares and raw tokens." |
| B6 remediation PRD, `contracts/hooks/uniswap/v4/standardExchange/orbital/UNISWAP_V4_SE_ORBITAL_BUFFER_MIN_SE_AND_B6_REMEDIATION_PRD.md` | 1–46 | Independent of D59/D60 but consistent: D6 "Accounting stays effective-reserve / claim / rate as product defines; SE-share in converts via claim or RP (anti-skew vs pair-then-buffer within dust)." |

**Read:** the answer is decided. Liquidity uses raw balances; the swap invariant uses the rated reserves. The question is what to do operationally and where the current implementation deviates.

## 2. What each operation type is (observed vs. inferred)

Observed from `UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md` §1, §4.5, §3.3, §3.4:

| Operation | PRD identifier | Type for D59/D60 law |
|---|---|---|
| `addLiquidity(a0Max, a1Max, a2Max, …)` (multipath) | D41, §4.5.1 | **Liquidity** — raw balances per D59 |
| `removeLiquidity(shares, …)` (multipath, pro-rata) | D45, §4.5.2 | **Liquidity** — raw balances per D59 |
| `depositSingle(tokenIn, amountIn, …)` (zap-in only; no `withdrawSingle`) | D41a, §4.5.3 | **Liquidity (zap-in)** — raw balances per D59; the planning math operates on pre-buffer effective, but the issued LP is on the share ratio |
| `depositFlexible(...)` / `withdrawFlexible(...)` (B6 SE-share LP) | B6 PRD §3 | **Liquidity** — raw balances; SE-share is the *unit*, not a *rate* |
| `joinProportional` / `joinUnbalanced` (Balancer-style routes) | Common.sol `_entryJoinProportional` / `_entryJoinUnbalanced` lines 158–203 | **Liquidity** — raw balances per D59 |
| `joinSingleAssetExactIn(tokenIn, amountIn)` (with `kind_ == StandardExchange` branches handling SE-share → pair-token → `_depositSingleFromBalance`) | Common.sol `_entryJoinSingleAssetExactIn` lines 218–240 | **Liquidity** — raw balances per D59; the SE-share branch unwraps to pair first and then runs the standard single-asset join path. |
| `_proRataOut` / `_burnAndPay` (remove internals) | Common.sol lines 1287–1368 | **Liquidity** — explicit "Pro-rata on raw reserves and/or SE share balances" comment (line 1294); SE-share branch uses `ClaimLib.previewUnwrapShares(l.seX, l.tokenX, seOut)` (a *buffering* quote, not a *valuation*). |
| V4 swap (any of three pair doors) | D49a, §4.4 | **Swap** — rated reserves per D60 |
| `exchangeIn(tokenIn, tokenOut, …)` / `exchangeOut(...)` (SE In/Out) | D49a–D49c, §4.5.4 | **Swap** — rated reserves per D60 |
| Zap-internal sequential swaps (`ZapSwap` events) | D41c, §4.5.3 step 5 | **Swap** — rated reserves per D60 |
| `beforeSwap` hook callback | D58 mine flags, O11 | **Swap** — rated reserves per D60 |

**Confidence: high (fact)** — mapping is direct from the PRD, which is the source of truth for product law.

## 3. Where the Orbital code reads rates (today, observed)

All rate reads observed in `contracts/hooks/uniswap/v4/standardExchange/orbital/`:

- `UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol` — the rate-aware helpers used by swaps and by `_planDeposit`:
  - `_refresh` (lines 73–83): reads `LegLib.rateAfterExchange(q, asset, rp)` (line 81); used by `preview`, `_swap`, `_receiveOutput`, `_bondAtExternalState`.
  - `_projectedInputValue` (`Common.sol` lines 677–685): reads `LegLib.rateAfterExchange(q, pair, provider)` (line 682). Used by `_previewSwapAfterExchange` (transition-quote swap path).
  - `bufferClaimQuote` (`ClaimLib.sol` lines 288–298): `if (rp != address(0)) quote.rate = getRateFailClosed(rp);` — used by `previewBufferClaimIn` (lines 300–312) and `_invertBufferForEffective` (line 246).
  - `effectiveNative` (lines 376–390): when `se != address(0)` it returns `ratedNative(seBal, getRateFailClosed(rp), se, token)` — the **swap invariant** legal valuation.
  - `previewInputWithContext`, `previewOutputWithContext`, `effectiveNativeWithContext` (lines 340–366): rate-aware, used by PM-end-of-swap (`ContextQuote.rate(...)`).
  - `getRateFailClosed` (lines 332–338): single chokepoint, fail-closed on revert / short return / zero.
- `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol` — `_effectiveNativeAt` (lines 336–343), `_effectiveNativeOf` (346–348), `_effectiveWad` (350–356), `_syncVaultReserves` (459–469) — these are the canonical swap-side reserve views; rate-aware via `ClaimLib.effectiveNative` (raw leg returns raw balance or `raw × rate`; buffered leg returns `shares × rate`). They back `_loadSphereLegs` (swap path) and `_syncVaultReserves` (multi-asset vault discovery / `reserveOfToken`).

Rate **not** read for:
- `_proRataOut` (Common.sol lines 1287–1316): `if (l.seX == address(0)) { aX = (shares * l.reserves[l.tokenX]) / supply; } else { seOut = (shares * seBal) / supply; aX = ClaimLib.previewUnwrapShares(l.seX, l.tokenX, seOut); }` — *no* rate; unwrap is a buffering quote (D60 allows).
- `_burnAndPay` (lines 1319–1368): mirror of `_proRataOut`, again no rate.
- `_computeFirstMint` (lines 971–985): `Math.firstMintShares(_sumFaceEffectiveWad(used0, used1, used2))` — `sumFaceEffectiveWad` (lines 1054–1063) calls `_previewClaimInAt` which on a buffered leg returns the **rated** effective via `ClaimLib.previewBufferClaimIn` (so it does call `getRate`). For first mint this is a *buffering quote composition* (D60: rated of the buffer), not a swap-invariant valuation. **Inference (medium confidence):** first mint sum-WAD could legitimately stay raw (sum of native shares × 1e18 + native raw × 1e18 + …) without losing equality, since R is scaled by `R_SAFETY_MULTIPLIER` and LP supply follows raw shares post-mint. But this is a separate question; see §6.

## 4. The moderator's "bug" claim — untrusted assertion, examined

**Claim:** "ExitQuoteLib._planDeposit uses rated effective and fullBookShares; therefore [a bug solely because of this]." Treat as untrusted per the prompt.

**Observations on `_planDeposit` (`UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol` lines 272–295):**

```text
1. _depositSales → q.offered[i] = raw native input amount in binding order
2. _depositOutputs → legs[q.input] executed on pre-zap snapshot via _swap;
                    legs[q.j], legs[q.k] updated (rated) effective reserves
3. _claimIn(legs[i], q.offered[i]) → for buffered leg returns
       ClaimLib.ratedNative(mintedShares, rate, se, asset)  // RATED
       for raw leg returns q.offered[i]                       // RAW
4. Math.fullBookShares(fb) with fb.e*Wad = toWad(legs[*].effective, ...)
                                  // legs[*].effective is RATED for buffered
                                  // and RAW for raw leg
```

For a buffered leg, `legs[i].effective = shares_i × rate_i / 1e18` (linear in shares for a fixed rate read at quote time). So `effective_i / shares_i = rate_i` is the same constant on both sides of `fullBookShares` (numerator and denominator), and the share mint = `dShares_i / shares_i` (raw-share ratio), **identically** to a raw-share fullBookShares. For a raw leg, both numerator and denominator are raw (no rate is read for a raw leg with `rp == address(0)`).

**Therefore the rate read inside `_planDeposit` is functionally redundant for buffered legs** at one rate-read snapshot — the result is the same as a raw-share computation. The differences are:

1. **Rate read happens** (extra `getRate()` external call per leg in `_refresh`, `_claimIn`, `_planDeposit`). This is gas, not correctness — and `LegLib.rateAfterExchange` + `ContextQuote` is exactly the family rate path the swap invariant must use, so the read is reusable.
2. **Quote/execution rate drift.** `_planDeposit` is a view; execution reads the rate fresh. If the rate moves between quote and execution, the share mint **could** differ from the preview. This is the manipulation risk the user flags. **Critical:** the rate read happens in `_depositOutputs` → `_swap` → `_receiveOutput` → `_refresh` at *quote time*, and the same rate is needed at execution. A drift between quote rate and execution rate is real but is also the same risk the swap path already accepts (rated reserves change mid-block, the swap prices them anyway).
3. **Read cost on the SE leg that is *not* the input.** `_planDeposit` refreshes all three legs (lines 36–37) even though the math only needs the input leg's effective. Optimization, not correctness.

**Moderator's "bug" claim: not established.** It is consistent with D59 in principle (liquidity should not read rates), but the result is identical to a raw-share read for buffered legs and is a no-op for raw-without-RP legs. **Inference (medium confidence):** if the implementation were rewritten to read raw shares for buffered legs, the share mint would be bit-identical, the gas cost would drop by the redundant `getRate()` calls, and the manipulation surface between quote and execution would narrow (because the share mint would no longer depend on the rate at quote time at all — only on `dShares/shares`, a pure share-count ratio). **Speculation:** this is the reason the PRD addendum (line 834) says "LP issuance for a buffered leg follows the share ratio" — that is a statement that the law wants the implementation to be re-expressed in terms of shares, not in terms of rated effective, even if currently equivalent.

## 5. Answers to the sub-questions

| Sub-question | Answer | Evidence |
|---|---|---|
| Should rates be quoted for **every** operation? | **No.** Per D59, liquidity uses raw balances; per D60, swaps use rated. Rates are quoted for swap-side valuation only. | PRD addendum line 834; agent law lines 233–243. |
| Should rates be quoted for **only zap-in/zap-out types**? | **No.** Zap-out is **not in v1** (D41b, PRD line 220, line 305). Zap-in is liquidity per D59 — raw balances. The split is by operation *type* (liquidity vs swap), not by *single-asset vs multi-asset*. | D41a–D41c; PRD non-goal #3 line 226. |
| Should rates **never** be quoted (raw balances only)? | **Yes for liquidity operations; no for swap operations.** The right answer is "rates are quoted for swaps, never for liquidity." Swaps need `held × rate` to price pair-token output against share inventory. Liquidity needs `dShares/shares`. | PRD addendum; agent law lines 233–243; `effectiveNative` (`ClaimLib.sol` lines 376–390) confirms raw-without-RP branch on raw legs. |

| Sub-question | Where current code is | Conformity |
|---|---|---|
| Proportional joins (`addLiquidity`) | `_computeFullBook` (`Common.sol` lines 988–999) → `_fullBookSharesUsed` (lines 1066–1090) reads `_effectiveWad()` (rated). For buffered legs equivalent to raw-share ratio; for raw legs without RP, equivalent to raw. | **Meets law in result**; does **not** read rates on raw-without-RP legs but **does** read rates on buffered legs (functionally redundant). |
| Proportional exits (`removeLiquidity`) | `_proRataOut` (`Common.sol` lines 1287–1316) + `_burnAndPay` (1319–1368): explicit raw-reserves or raw-se-balance × shares / supply. **No rate read** anywhere in the remove path. | **Conforms to D59 verbatim.** |
| Zap-in (`depositSingle`) | `_planDeposit` (`ExitQuoteLib.sol` lines 272–295) reads effective (rated) for buffered legs via `_claimIn` and `fullBookShares`. `_swap` (line 85) and `_receiveOutput` (line 110) also rate-refresh. | **Conforms to D59 in result** (rated is linear in shares); does **not** conform in *expression* — reads rates on liquidity path. |
| Single-asset joins (`joinSingleAssetExactIn`, `_entryJoinSingleAssetExactIn` lines 218–240) | SE-share branch unwraps to pair, then runs `_depositSingleFromBalance` (raw). Pool-token branch `_depositSingleFromBalance` is raw. | **Conforms to D59 verbatim** (no rate read for LP math). |
| Swaps within zaps (the two `ZapSwap` internal swaps) | `_swap` (`ExitQuoteLib.sol` lines 85–108) — sphere on rated effective reserves; `_receiveOutput` (110–127) — rated via `ClaimLib.sharesForNativeUp`. | **Conforms to D60 verbatim.** Swaps are the rated domain. |
| Raw share ratios vs rated coordinates | For a buffered leg, `effective_i = shares_i × rate_i / 1e18` is linear; `effective_i / shares_i = rate_i` is a constant. Therefore `dEffective_i / effective_i = dShares_i / shares_i` (raw-share ratio). **In raw-share coordinate, share mint is independent of rate.** | **Fact** for any rate read at a single instant. |
| Identical-rate cancellation | Two `getRate()` reads at the same instant with the same provider must agree; if not, `RateProviderFailed` (fail-closed, `ClaimLib.sol` lines 332–338). No cancellation needed in the math — the ratio cancels. | **Fact** (ClaimLib lines 332–338; D60 rule 1 in `INDEXEDEX_AGENT_LAW.md` line 237). |
| Integer rounding | `Math.fullBookShares` (`Math.sol` lines 366–374): `sX = (aXWad * supply) / eXWad; shares = min(s0, s1, s2)`. **Floor division** per leg; min picks the binding leg's floor. `_faceForClaim` (`ExitQuoteLib.sol` lines 347–374) inverts via bounded binary search (≤ 8 probes + log₂ iterations). | **Fact.** Floor is the conservative direction (under-mints). |
| Rate reads vs expensive SE transition simulation | `LegLib.rateAfterExchange` (used at `ClaimLib.sol` line 81) is a single `staticcall(getRate)`. The expensive SE simulation is `quoteTransition` (used at `ExitQuoteLib.sol` lines 43, 65, 92, 119, 177, 195, 196, 209, 215, 378), which is a full SE state-machine quote. The two are independent: rate is one `staticcall`; transition is multiple state transitions. The plan's Q9 algorithm requirement (closed-form sphere + SE invert) is unaffected by rate reads. | **Fact** (file imports + call sites). |
| Fee accounting and rate failure liveness | `_feeOnAndShare` (`Common.sol` lines 374–385): `feeTo != 0 && usageFeeWad != 0 && usageFeeWad < 1e18 && ownerFeeShare != 0`. Rate failure (`getRateFailClosed` reverts `RateProviderFailed`) fails the *quote*, not the fee; if a swap or LP path needs a rate and it fails, the whole tx reverts. Liveness: a temporary rate revert reverts pending operations; no partial fills, no silent zero rates (`rate == 0 → RateProviderFailed`). | **Fact** (lines 332–338, 374–385). |

## 6. Where current code *could* be tightened (no action recommended; observation only)

1. `_planDeposit` (`ExitQuoteLib.sol` lines 272–295) reads effective (rated) on the input-leg quote but `fullBookShares` is rate-cancelling on buffered legs. A raw-share rewrite would:
   - Remove `getRate()` reads from the zap-in quote path (gas).
   - Remove quote/execution rate-drift sensitivity on the LP mint.
   - Not change the LP amount for buffered legs at a single rate read.
   - **Inference (medium confidence):** this is what the PRD addendum (line 834) signals with "LP issuance for a buffered leg follows the share ratio, exits are pro rata in raw shares and raw tokens" — a recipe, not a description of the current code.
2. `_computeFullBook` / `_fullBookSharesUsed` (`Common.sol` lines 988–1090) has the same redundancy. It uses `_effectiveWad()` (rated); for buffered legs the result equals the raw-share computation; for raw legs without RP it equals raw. **Same observation.**
3. `_computeFirstMint` / `_sumFaceEffectiveWad` (lines 971–1063): `firstMintShares(sumWad)` with `sumWad` from `_previewClaimInAt` (rated). Per first-mint law (D42, PRD line 306), `R = max(effective) × R_SAFETY_MULTIPLIER`, and the LP is `sumWad - MINIMUM_LIQUIDITY`. A raw-share formulation would set `R` from raw max instead of rated max — *the radius would shift*, and the sphere would be slightly different post-mint. **Inference (medium confidence):** first-mint uses rated max intentionally to leave headroom for the rate to drift upward before any first trade; this is consistent with D26/Q2 ("native × rate then `toWad`") and with the `R_SAFETY_MULTIPLIER = 10` (D21). Do not change without owner ruling.
4. `_syncVaultReserves` (`Common.sol` lines 459–469) writes rated effective into `MultiAssetBasicVaultRepo._updateReserve` for `IBasicVault.reserveOfToken`. Per D62 (PRD line 341) "reserveOfToken(token_i) = effective reserve (shares×rate, claim, or raw face)". This is the **swap invariant** view (rated); it's the right thing for the vault discovery surface used by other consumers. **Conforms.** No change.
5. The Aperture PRD (`docs/plans/UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.md`, dated 2026-10-03/04) targets `UniswapV4FullSpreadHooklessStandardExchangeVault` only. Out of scope for this question. The PRD's §3 non-goal line 62 explicitly says: "Removing or redesigning Orbital's `_faceForClaim`, `_invertBufferForEffective` or `zapSplitWad` algorithms. They remain measured consumer dependencies, not problems this library automatically solves." This confirms the aperture refactor is **not** an entry point to change Orbital's liquidity/rate policy. **Fact.**

## 7. Counterarguments to the user's stated law

| Counterargument | Where it exists | Why it fails |
|---|---|---|
| "Rated is needed on first mint so `R` has headroom against upward rate drift." | D21 (`R_SAFETY_MULTIPLIER = 10`) + D26/Q2 rated before `toWad`; `_computeFirstMint` uses rated. | Confirmed by code. **First mint** uses rated by design; this is a separate question from proportional exits and proportional joins. The user's law applies to **proportional** and **single-asset** LP, not first-mint headroom. |
| "Rated is needed on `_syncVaultReserves` for `IBasicVault.reserveOfToken`." | D62 (PRD line 341). | Confirmed: the swap invariant view backs the vault discovery surface. Same scope: rated is the swap-side valuation; the user's "raw balances for liquidity" does not apply. |
| "Removing rated from `_planDeposit` would change preview/execution parity." | `previewDepositSingle` (via `_planDeposit`) must be bit-exact with execution per D49 (PRD line 313). | Only bit-exactness that matters is on share count. Bit-exact on share count is preserved by a raw-share rewrite for buffered legs (rated is linear in shares). Raw legs produce different p → different preview if raw vs rated, but raw-without-RP is the only branch that touches rated today (`effectiveNative` line 385: `rp == address(0) → rawReserve`). So a raw-share rewrite is consistent. |
| "The `_claimIn` line is needed for the inverse: native → effective for sphere exact-out." | `_faceOutToEffectiveNative` and `_faceInToEffectiveNative` (Common.sol lines 824–835, 854–868) bridge native input to effective for the sphere. Used by `_previewSwapExactOut` and `_previewSwapExactIn`. | **Confirmed**: these are swap-side, not liquidity-side. Out of scope of the user's "liquidity uses raw balances" law. |

## 8. Confidence and missing evidence

- **High confidence:** the law itself (D59/D60 verbatim, locked 2026-09-21/22, restated in the Orbital PRD addendum on 2026-09-22, restated in agent law). The mapping of each public hook operation to liquidity-or-swap. The current conformance of `_proRataOut`, `_burnAndPay`, `_entryJoinSingleAssetExactIn`, all `_swap`/`_receiveOutput` swap paths, and `_syncVaultReserves`.
- **Medium confidence:** the equivalence claim that a raw-share rewrite of `_planDeposit` and `_fullBookSharesUsed` would not change the share mint for buffered legs at a single rate read. This follows from linearity of `effective = shares × rate / 1e18` (`ClaimLib.ratedNative`, lines 317–322) but I have not executed a gas measurement or a fuzz comparison.
- **Low confidence / missing evidence:** I did not run any test or measurement (forbidden). I did not read prior researcher sessions (forbidden). I did not read the Weighted PRD's full text or the Weighted hook's liquidity path beyond grep (lines confirm dual-scale `ratedScales`/ `invScales` math, which is a different design — the Weighted hook uses `ratedPairUnits` with separate `invScale` / `ratedScale`, not the orbital "native × rate / 1e18 × decimals` method; treat as a peer reference, not a direct parallel). I did not locate a `WeightedFundedBindingTest` file (no such test in the repo); the closest matches are `test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol` and `DETFFundedStakingSuite.t.sol` — both DETF, not weighted hook — so the moderator's prior claim "WeightedFundedBindingTest proves FullSpread compatibility" was **not verifiable** from the file tree alone.
- **The moderator's "bug solely because ExitQuoteLib._planDeposit uses rated effective and fullBookShares" is not established as a bug.** It is consistent with D59 in principle (liquidity should not read rates) and may warrant a future refactor for gas and quote/execution drift narrowing, but it is not currently a correctness defect. The shares minted at a single rate read are identical.

## 9. Conclusion (single sentence, for cross-review)

**Rates must be quoted for swap operations only, never for liquidity operations** (per APEX D59/D60, LOCKED 2026-09-21/22). In the current Orbital code, `_proRataOut`, `_burnAndPay`, and `_entryJoinSingleAssetExactIn` already conform (raw-only). `_planDeposit` (zap-in quote) and `_computeFullBook` (full-book multipath quote) read rates but the results are rate-cancelling for buffered legs and no-op for raw-without-RP legs — conformance is by accident of linearity, not by intent; a raw-share rewrite would tighten quote/execution drift and gas, but is not a current correctness defect. The moderator's "bug" assertion is unestablished. The Aperture refactor PRD is out of scope and does not change this policy.

---

*End of original first pass. Saved to `docs/research/orbital-liquidity-rate-policy-2026-10-04/minimax-original.md`. No peer artifact was read; no tests were run; no shell, config, or code change was made.*