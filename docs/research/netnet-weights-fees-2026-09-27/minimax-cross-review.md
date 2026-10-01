# MiniMax M3 — NN-05 Weights/Fees Cross-Review (Bounded Round)

> Cross-review of three peer originals. Read together; no peer cross-review consulted. My `minimax-original.md` is baseline. Routing metadata `minimax/MiniMax-M3` only. Date 2026-09-27.

---

## 1. Convergence (all four agree)

1. **Multi-leg marginal mark, self-leg excluded, numeraire included.** `ExitQueryTarget.sol:120–130` confirms: skip DETF self-leg (`tokens[i] == detf_` continue, `:122`); include numeraire at full value (`:124`); include every other non-empty non-self leg marked into numeraire via weight ratio (`mulDiv(rated[j], weights[i], wOut)`, `:129`).
2. **Owned LP / post-protocol-fee supply.** `lpSupply = _previewSupplyAfterProtocolMint()` (`:132`) includes pending protocol-LP mint. Numerator scales by `ownedLp / lpSupply`.
3. **9-dec → WAD once at `_quoteCtx`.** `detfTotalSupply: supply_ * 1e9` (`UniswapV4DetfCommon.sol:185`). No double-scale.
4. **Pending expansion enters via supply adjustment, not as additive on top.** `_quoteCtx:181–183` adds `_pendingExpansionDetf()` to `supply_` when `previewSettlement_`; `pendingExpansion` field is `0` in live mark.
5. **Creation vs opening distinct.** Synthetic uses `creationPairPerDetfWad` only (`:139`); opening is for first-bond pricing and falls back to creation (`_openingBondQuote` `:259–264`).
6. **NetNet expansion uses hook TWAP, not Universal `_highestSyntheticPrice`.** Confirmed: `_highestSyntheticPrice` (`:322–340`) is Universal expansion helper; PRD §9 expansion uses hook TWAP.
7. **Oracle fallback is stored-0 = unset/fallback, not 0%.** `IVaultFeeOracleQuery.sol:16–24`: vault → type → global; stored 0 triggers fallback. Missing TWAP, rate failure, and `!_isLive()` are distinct categories.
8. **Fees reuse existing oracle — no invented model.** Hook HLP mint = growth-share protocol-LP via `Math.protocolLpShares` (`:167–180`); NET-DETF mint = `_splitMintedDetf` via `DETFMintSplitLib._splitLiveGross` (`:19–26`).

---

## 2. Attributed corrections to my original

### 2.1 MAJOR ERROR: peg mapping

I wrote: "At deployment with opening 1,000 NET per DETF: `creationPairPerDetfWad = 1e21`." **This is wrong.** If `creationPairPerDetfWad = 1e21` (= 1000e18), the synthetic divides by 1000 (`ExitQueryTarget:139`), normalizing away the absolute peg — synthetic value becomes `marked·.../(supply·1000)`, not `marked·.../supply`. **Correct (Kimi):** set `creationOfPair[NET] = 1e18` (= 1 NET per DETF WAD); keep `openingOfPair[NET] = 1000e18` separately. The synthetic's `:139` division is then identity, yielding absolute NET-per-DETF directly. Opening remains 1000e18 for first-bond bootstrap per PRD §10.4. **Reject my normalization-by-1000 formulation.**

### 2.2 DETFDecimalScaleLib comment contradiction (Grok)

I missed: `DETFDecimalScaleLib` comment states DETF "stays 18" decimals. DETF is **9-decimal** per `Constants.sol:14 NET_UNIT = 1e9`. The synthetic scales `* 1e9` at `_quoteCtx:185`, not `* 1e18`. **Use `Common`'s `* 1e9`; do not trust the 18-decimal comment.**

### 2.3 K is invariant V, not sqrt(rootK) (Astra)

`Math.protocolLpShares` operates on **literal invariant V** (full book, `mode == 0`) or **interim K** (partial book, `mode == 1`) — **NOT** a square root despite `rootK` naming. The naming is misleading. `K = computeV(weights, inv)` full; `K = computeInterimK(weights, inv)` partial. Per `Math.sol:8–14`: "rootK = V (full WeightedMath invariant) — LITERAL, no cbrt."

### 2.4 2.5× derivation is conditional (Astra)

I had the formula correct but didn't derive the special case. With **all three externals positive** and selected weights (NET 20%, sNET 10%, USDG 20%): `marked = rated[NET]·(1 + 0.10/0.20 + 0.20/0.20) = rated[NET]·(1 + 0.5 + 1) ≈ 2.5·rated[NET]`. **This requires all externals positive AND exact floors**; not a simple multiplier. Empty SY leg or zero USDG leg degrades the sum. NN-08 zero-interest bootstrap must note this degradation.

### 2.5 Hook usage fee is growth-share, not per-mint deduction (Kimi/Astra)

I said "fees reuse existing oracle; no flat deposit percentage" but should sharpen: the hook HLP mint fee is a **growth-share protocol-LP mint** to `feeTo()` via `Math.protocolLpShares` on `rootK` growth. It is **not** `join · usage%`. Per `Math.sol:165–180`: `protocolLp = supply·(k−kLast)/(k·FEE_DENOM/ownerFeeShare + k−kLast)`. Single/unbalanced joins separately use `dexSwapFeeOfVault` for imbalance (not a duplicate usage fee).

### 2.6 Oracle fallback semantic (user correction)

I said "silent zero return" generally. Should distinguish per user correction:
- **Stored zero** in oracle = unset → fallback to type default → fallback to global default. Not 0%.
- **Rate failure** (rate provider returned unusable value or reverted) = different from stored zero; `IVaultFeeOracleQuery` typically reverts on this.
- **Missing TWAP** = different category (PRD §9 absent-TWAP = above-1 branch). Not a fee oracle concern.
- **`!_isLive()`** = hook not yet activated; previewSynthetic returns 0.
- **Returned no-live zero** is not "measured hour below peg"; it is `!_isLive()`.

### 2.7 NET numeraire pinning (Grok, sharper than mine)

`_syntheticPrice` uses `pairs_[0]` (`UniswapV4DetfCommon.sol:207–211`). **Do not rely on token-array order.** PkgInit or wrapper initialization must **explicitly pin NET as the synthetic numeraire** so `pairs_[0]` is NET, not sNET/USDG. `_highestSyntheticPrice` (`:322–340`) maxes across all numeraires — that is for Universal expansion only, not the NetNet DETF synthetic.

### 2.8 No DETFDecimalScaleLib path (Grok)

The user's correction: "no DETFDecimalScaleLib comment says 18 decimals; use Common's `* 1e9`." My §2 §3 already said this correctly, but didn't explicitly call out the comment contradiction.

---

## 3. Genuine differences

- **Kimi** sharpest on peg mapping — `creation = 1e18`, `opening = 1000e18`, formula unchanged.
- **Astra** sharpest on K = invariant V (not sqrt) and the 2.5× conditional.
- **Grok** sharpest on oracle fallback and on the `DETFDecimalScaleLib` 18-decimal comment contradiction.
- **Me** correctly identified self-leg exclusion, numeraire inclusion, native→WAD scaling, creation-vs-opening distinction, fee reuse — but **erred on peg mapping** (creation = 1000e18 normalization). Rejected by Kimi/user.

---

## 4. Accepted (do not reopen)

1. Weights `[5e17, 2e17, 1e17, 2e17]` (DETF/NET/sNET/USDG); sum `1e18`; ≥ `MIN_WEIGHT = 1e16`; legs within `MIN_N..MAX_N = 2..8`.
2. Multi-leg marginal mark; self-leg excluded; numeraire included; other non-self legs marked via weight ratio.
3. `creationOfPair[NET] = 1e18` (absolute peg), `openingOfPair[NET] = 1000e18` (bootstrap).
4. Native 9-dec → WAD via `* 1e9` at `_quoteCtx:185` (not `* 1e18`, contradicting the 18-decimal comment in `DETFDecimalScaleLib`).
5. `pendingExpansion = 0` in live preview; pending expansion enters via supply adjustment only.
6. Hook HLP mint = growth-share via `Math.protocolLpShares` on `rootK` growth; oracle-driven.
7. NET-DETF mint = `_splitMintedDetf` via `DETFMintSplitLib._splitLiveGross`; oracle-driven.
8. Bond split = `_splitBond` (three independent floors; user + pot ≤ U + G).
9. Single/unbalanced joins use `dexSwapFeeOfVault` for imbalance; **no duplicate usage fee** on top.
10. `_syntheticPrice` selects `pairs_[0]`; **NET must be pinned as numeraire** at PkgInit/init time.
11. `_highestSyntheticPrice` is Universal expansion helper; **NetNet §9 expansion uses hook TWAP**, not this.
12. Oracle fallback: stored 0 = unset → fallback tier; rate failure distinct; missing TWAP distinct; `!_isLive()` distinct.

---

## 5. Deferred / engineering

- **NN-08** zero-interest bootstrap leg population; SY leg may be empty at deploy → marked degrades.
- **NN-10** SY rate-provider verification (sNET/PLP/YT mapping into `_ratedWadAll`).
- **NN-05/01** live oracle values not read; no live-config claims.
- **A35** first-bond G/U under selected weights.
- preview/execution parity, rate-provider behavior remain engineering evidence.

---

## 6. Concrete PRD amendment (UNAPPROVED)

```markdown
### §4.X NN-05 weights & synthetic — selected

Weights (WAD): NET-DETF self 5e17 / NET 2e17 / sNET 1e17 / USDG 2e17. Sum 1e18; ≥ MIN_WEIGHT 1e16.

**Peg mapping:** `creationOfPair[NET] = 1e18` (= 1 NET per DETF WAD — absolute peg); `openingOfPair[NET] = 1000e18` (first-bond bootstrap). Synthetic divides by `creationPairPerDetfWad` (1e18), yielding absolute NET-per-DETF directly. **Do not set `creationOfPair[NET] = 1e21`** (normalizes the peg away).

Synthetic per numeraire (NET pricing leg):
  marked = rated[NET] + Σ over (i ≠ NET, i ≠ DETF) mulDiv(rated[NET], weights[i], weights[NET])
  pairWad = mulDiv(marked, ownedLp, lpSupply)
  lpSupply = _previewSupplyAfterProtocolMint() (includes pending protocol-LP)
  mid = pairWad · 1e18 / (detfTotalSupply + pendingExpansion)
  synthetic = mid · 1e18 / creationPairPerDetfWad[NET]

Native 9-dec → WAD at `_quoteCtx:185` (`* 1e9`); pendingExpansion = 0 in live mark (pending expansion enters via supply adjustment). K is literal invariant V or partial-book interim K (NOT sqrt(rootK)).

`_syntheticPrice` selects `pairs_[0]`; **NET must be explicitly pinned as the synthetic numeraire** at PkgInit/init. `_highestSyntheticPrice` is Universal expansion only; PRD §9 expansion uses hook TWAP.

**Hook HLP mint fee:** growth-share protocol-LP via `Math.protocolLpShares(supply, rootK, kLast, ownerFeeShare)` to `feeTo()` from existing oracle — NOT a flat deposit deduction. **NET-DETF mint fee:** issuance-time split via `_splitMintedDetf` → `_splitLiveGross` from existing oracle. Two distinct fee mechanisms; no double charge.

**Oracle fallback:** stored 0 = unset/fallback (not 0%); rate failure distinct from missing TWAP; `!_isLive()` returns 0 from previewSynthetic.
```

---

## 7. Confidence and evidence limits

- **High** formula structure, fee mechanisms, source-order floor constraints.
- **High** my original had a major peg-mapping error (creation = 1000e18). Corrected here per Kimi.
- **High** DETFDecimalScaleLib 18-decimal comment contradicts Common's `* 1e9`. Use Common.
- **Medium** `_ratedWadAll` internal consistency (function reference, not directly read).
- **Low** on live oracle config; not asserted.
- **Not claiming** deployed weights, rates, or rate-provider behavior.
- **Not reopening** settled owner decisions.

**Saved:** `docs/research/netnet-weights-fees-2026-09-27/minimax-cross-review.md`. Originals untouched.
