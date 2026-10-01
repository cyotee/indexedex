# Kimi K3 — ORIGINAL: NN-05 weights/fees source verification (PRD v0.28 context)

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only |
| Date | 2026-09-27 |
| Scope | Source verification of the selected synthetic-price/fee mechanics against the actual Universal V4 Weighted implementation. Local analysis only; no external claims arose; no execution. No missing/failed reads this round; no identity/guard issues. |

## 1. Selected inputs (human-fixed; not re-asked)

Weights: NET-DETF self-leg 50%, NET 20%, sNET 10%, USDG 20% (sum 1e18; all ≥ `MIN_WEIGHT = 1e16`, 4 legs within `MIN_N/MAX_N = 2/8`, `UniswapV4StandardExchangeWeightedBufferHookMath.sol:30–35`). Peg target 1 NET/DETF vs opening 1000 NET/DETF. NET leg priced from PLP/YT zap-out, funded from shared SY. Fees: hook HLP mint = usual vault usage fee; NET-DETF mint = usual seigniorage share — both from the existing oracle.

## 2. The actual `previewSynthetic` (ExitQueryTarget.sol:89–140) — what the mark really is

```
guards: ownedLp==0 || detfTotalSupply==0 || creationPairPerDetfWad==0 → 0; !_isLive() → 0   (:94–97)
numeraire classification; SE numeraire → pairOfStandardExchange; out == detfToken → 0       (:99–112)
j = tokenIndex(out); rated = _ratedWadAll(); wOut = weights[j]                               (:113–115)
marked = rated[j] + Σ_{i∉{j, detf}, rated[i]>0, weights[i]>0} mulDiv(rated[j], weights[i], wOut)  (:120–130)
lpSupply = _previewSupplyAfterProtocolMint()                                                 (:132)
pairWad  = mulDiv(marked, ctx.ownedLp, lpSupply)                                             (:134)
mid_     = pairWad * 1e18 / (ctx.detfTotalSupply + ctx.pendingExpansion)                     (:136–138)
return   (mid_ * 1e18) / ctx.creationPairPerDetfWad                                          (:139)
```

Verified properties, each contradicting a "simple NET-only" formula:

1. **Self-leg excluded, other legs included and marked into the numeraire.** The loop skips the DETF leg (:122) and adds every other non-empty leg via the marginal weighted identity (leg i's value in j-units = b_j·w_i/w_j — the equal-value-share property of weighted pools). This is a **multi-leg** mark: the USDG-SE and sNET-SY legs enter `rated` through their rate providers (`_ratedWadAll` :342–348 → `_ratedPairUnits` → leg rate providers, fail-closed :330–332) and are marked into the NET leg. A "NET leg balance ÷ DETF supply" formula is **false**.
2. **ownedLp fraction with fee-dilution:** numerator scales by `ctx.ownedLp / lpSupply` where lpSupply is the supply **after the pending protocol-fee mint** (:132 → Target :416–427), not raw totalSupply.
3. **native9→WAD normalization happens caller-side:** `_quoteCtx` sets `detfTotalSupply: supply_ * 1e9` (`UniswapV4DetfCommon.sol:184–186`) and `pendingExpansion: 0` (pending expansion enters via `previewSettlement_` supply adjustment, :181–183). The nine-decimal DETF supply is WAD-scaled before the division at :138.
4. **Creation-vs-opening normalization — the decisive finding for the peg mapping:** the synthetic result is a **ratio to `creationOfPair`** (:139 divides by `ctx.creationPairPerDetfWad`), while the first-bond quote uses `openingOfPair` with creation fallback (`_openingBondQuote`, DetfCommon :259–264). The reference therefore already separates the two knobs. The custom family's gate is an **absolute** 1 NET/DETF threshold — "opening 1,000 NET is not the ongoing threshold's normalization denominator" (PRD). Minimal-change mapping: set the NET leg's `creationOfPair` = **1 NET per DETF** (WAD) so the :139 division is identity and the reference formula yields absolute NET-per-DETF directly, while `openingOfPair` = **1000 NET per DETF** carries the first-bond bootstrap quote. This preserves the reused formula exactly; the alternative (dropping the creation division) would be an unneeded formula change.
5. **Zero/liveness behavior is fail-closed:** non-live hook (not full book, :371–373), empty legs (skipped, not zeroed-out whole mark), zero marks/supply/denominator all return 0 (:94–135). Partial-book legs are skipped, not renormalized — the custom family's four-leg book with a possibly-empty SY leg at bootstrap inherits this behavior; NN-08's zero-interest bootstrap must note it.

## 3. Fee usage — actual reference behavior vs the selected fees

**Hook side (`Target._feeOnAndShare` :387–398):** `feeTo = oracle.feeTo()`; `usageFeeWad = oracle.usageFeeOfVault(address(this))` — hook proxy key, exactly R36's selected identity. `ownerFeeShare = usageFeeWad * FEE_DENOMINATOR / WAD`; `feeOn` requires feeTo≠0, 0<usageFee<WAD, ownerFeeShare≠0. **The charge is not a flat per-mint deposit percentage:** `_maybeMintProtocolFee` (:429–441) mints `Math.protocolLpShares(supply, rootK, kLast, ownerFeeShare)` (WeightedBufferHookMath :167–180 — Balancer-style fee on invariant **growth**: `supply·(k−kLast)/(k·FEE_DENOM/ownerFeeShare + k−kLast)`) to `feeTo`, only when k grew in the same k-mode; `_snapshotKLastIfFeeOn` (:443–453) resets the baseline. Zero/growth-absent/mode-change all mint nothing (:173–175, :434). So "usual vault usage fee on HLP minting" is realized in the reference as a growth-share protocol-LP fee sourced from the usage-fee oracle key — **no invented flat deposit fee is needed, and no double fee exists**: the DETF side's mint split (`DETFMintSplitLib._splitLiveGross/_splitBond` :19–53 — user (1−p), pot floor(p·U)+floor(p·G)) is a separate issuance-time seigniorage share resolved under the DETF's own instance key (`_seigniorageIncentiveWad`, DetfCommon :112–116).

**Oracle fallback source:** `IVaultFeeOracleQuery.sol:16–24` — WAD, three-tier vault→type→global, stored 0 = unset/trigger fallback; explicit 0% not expressible. Verified directly.

**Order/floor constraints:** fee computed only on growth after state settlement; integer floors throughout; `protocolLpShares` returns 0 rather than reverting on zero/negative growth; mode change skips the fee rather than mis-computing.

## 4. User's selected fees vs reference capability

| Selection | Reference capability | Gap |
| --- | --- | --- |
| Hook HLP mint usage fee, hook proxy key, existing oracle | Supported exactly — but as growth-share protocol-LP mint, not per-mint deduction | **None — but the PRD text should stop implying a per-mint charge if it does**; "hook LP-mint usage fees" (R36) is satisfied by the growth mechanism and its rate source |
| NET-DETF mint seigniorage share, instance key | Supported exactly (`_splitMintedGross`/`_splitBond`, oracle `seigniorageIncentivePercentageOfVault`) | None |
| Weights 50/20/10/20 | Compatible with Weighted domain checks | None; record as PkgInit/config values with WAD sum 1e18 |

## 5. Amendment recommendation (docs only, UNAPPROVED wording to consolidator)

1. NN-05 row / §7.1: record the verified synthetic construction — multi-leg marginal mark excluding the self-leg, owned-LP fraction over post-protocol-fee supply, WAD-scaled 9-decimal supply, creation-rate normalization — and select **creation = 1 NET/DETF, opening = 1000 NET/DETF** so the reused formula needs no change.
2. Clarify fee wording: hook usage fee is charged as protocol-LP on invariant growth from the hook's oracle key; NET-DETF seigniorage is an issuance-time split from the DETF's key. One fee each, distinct mechanisms, distinct identities.
3. No numeric fee defaults are set by this; live oracle configuration remains unverified (NN-01 pending class).

## 6. Limits

All citations from direct reads this session (`ExitQueryTarget.sol:89–149`, `Target.sol:330–459`, `UniswapV4DetfCommon.sol:100–341`, `DETFMintSplitLib.sol`, `IVaultFeeOracleQuery.sol`, `WeightedBufferHookMath.sol:28–43,167–180`). No executed tests; preview/execution parity, actual configured rates, and rate-provider behavior of the custom SY/SE legs remain NN-10/NN-01 evidence work. No live-config claims made.
