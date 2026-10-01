# MiniMax M3 — Weights & Fees Source Verification (Bounded Round)

> **Scope:** NN05 source verification — user's selected weights (NET-DETF 50%, NET 20%, sNET 10%, USDG 20%); synthetic reuses Universal DETF pattern with NET pricing leg; hook HLP mint = existing vault usage fee; NET-DETF mint = existing seigniorage share. Read `UniswapV4DetfCommon.sol:90–339`, `DETFMintSplitLib.sol`, `UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol:89–186`, `UniswapV4StandardExchangeWeightedBufferHookTarget.sol:387–463`, `UniswapV4StandardExchangeWeightedBufferHookMath.sol:160–180`. Research-only; routing metadata `minimax/MiniMax-M3` only. Date 2026-09-27.

---

## 1. Confirmed formula — `previewSynthetic` per NET pricing leg

`UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.previewSynthetic` (`:89–140`). Inputs: `ctx.detfTotalSupply` (WAD-native, from `_quoteCtx`), `ctx.ownedLp`, `ctx.creationPairPerDetfWad`, `numeraire`.

```
k = classify(legs, out_)             // SE-pair → pair; Unknown → revert(0)
if (k == SE) out_ = legs.pairOfStandardExchange[out_]
if (out_ == detf_ || out_ == 0) return 0
j = tokenIndex(out_)
rated[] = _ratedWadAll()             // wad-rate units per token
wOut = weights[j]
marked = 0
for i in [0..numTokens):
    if (tokens[i] == detf_) continue                    // ← self-leg EXCLUDED
    if (i == j) marked += rated[i]                      // ← numeraire leg INCLUDED at full value
    else if (rated[i] != 0 && wIn != 0):
        marked += mulDiv(rated[j], weights[i], wOut)    // ← OTHER non-self legs MARKED INTO numeraire
if (marked == 0) return 0
lpSupply = _previewSupplyAfterProtocolMint()            // includes pending protocol LP at current oracle
pairWad = mulDiv(marked, ctx.ownedLp, lpSupply)
den = ctx.detfTotalSupply + ctx.pendingExpansion
mid = (pairWad * 1e18) / den
return (mid * 1e18) / ctx.creationPairPerDetfWad
```

**Self-leg exclusion confirmed** (`:122`). **Numeraire leg included at full value** (`:124`). **Other non-self legs marked into numeraire via weight ratio** (`:129`). Per-NET pricing leg, marked = `rated[NET] + Σ over i≠NET, i≠DETF of rated[NET]·weights[i]/weights[NET]`.

**Owned LP fraction / dilution:** `ownedLp / lpSupply` (line 134). `_protocolLp` (`:97–102`) returns self-held + bond-NFT-held. `lpSupply` from `_previewSupplyAfterProtocolMint` (`:416`) includes pending protocol LP from `_maybeMintProtocolFee` (`:429`). Protocol mints LP to `feeTo()` on `rootK` growth; mints dilutes `ownedLp / lpSupply`.

**Self-leg is excluded; numeraire is included — the formula is NOT a simple "NET-balance-only"**. The simple `marked = NET_balance / DETF_supply` would be wrong because:
1. Self-leg DETF inventory is excluded (no double-count between hook LP and DETF self-leg).
2. Other non-self legs (USDG, sNET) contribute their weighted value expressed in NET terms.
3. The result is scaled by `ownedLp / lpSupply` (protocol's share), not the entire hook LP.
4. The result is divided by `creationPairPerDetfWad` (creation price at deploy).

**Native 9-dec → wad normalization:** `_quoteCtx:185` does `detfTotalSupply: supply_ * 1e9`. DETF has 9 decimals (`Constants.sol:14 NET_UNIT = 1e9`); multiplying by 1e9 converts native → wad-native. `marked` from `_ratedWadAll` is wad-rate units per token. Dimensional consistency: `wad-rate · 1e18 / wad-native / wad-rate/wad-native` = dimensionless.

**Creation vs opening normalization:** `previewSynthetic` uses **creationPairPerDetfWad only** (`:139`). Opening price is used only for `_openingBondQuote` (`:259–264`); opening falls back to creation when zero. The synthetic itself does **not** substitute opening for creation.

**Oracle fallback (silent zeros, not reverts):**
- `Math.protocolLpShares:173`: zero if `supply == 0 || rootKLast == 0 || rootK <= rootKLast || ownerFeeShare == 0`.
- `_maybeMintProtocolFee:432–434`: zero if `!feeOn || kLast == 0` or `mode != kLastMode`.
- `previewSynthetic:94,97`: zero if `ctx.ownedLp == 0 || ctx.detfTotalSupply == 0 || ctx.creationPairPerDetfWad == 0 || !isLive()`.

---

## 2. Confirmed fees — no invented model

**Hook HLP mint (existing vault usage fee):** `UniswapV4StandardExchangeWeightedBufferHookTarget._feeOnAndShare` (`:387–398`):
```
feeTo_ = feeOracle.feeTo()
usageFeeWad = feeOracle.usageFeeOfVault(address(this))
ownerFeeShare = (usageFeeWad * FEE_DENOMINATOR) / WAD
feeOn = feeTo_ != 0 && usageFeeWad != 0 && usageFeeWad < WAD && ownerFeeShare != 0
```
`_maybeMintProtocolFee` (`:429–441`): if `feeOn && kLast != 0 && mode == kLastMode`, mints `Math.protocolLpShares(totalSupply, rootK, kLast, ownerFeeShare)` to `feeTo_`, updates `kLast`. **No invented flat deposit percentage; reuses existing oracle.**

**NET-DETF mint seigniorage share:** `UniswapV4DetfCommon._splitMintedDetf` (`:118–124`):
```
split.grossDetf = gross_
if gross_ == 0: return split
(user_, pot_) = DETFMintSplitLib._splitLiveGross(gross_, seigniorageIncentiveWad)
split.userDetf = user_; split.inventoryDetf = pot_
```
`_seigniorageIncentiveWad` (`:112–116`): `feeOracle.seigniorageIncentivePercentageOfVault(address(this))`. **No invented fee model; reuses existing oracle.**

**`DETFMintSplitLib._splitLiveGross` (`:19–26`):**
```
userDetf_ = mulDiv(gross_, ONE_WAD - p_, ONE_WAD)      // floor
potDetf_  = mulDiv(gross_, p_, ONE_WAD)               // floor
```
**Two independent floors** — `user + pot ≤ gross` (rounding may lose up to 2 wei).

**`DETFMintSplitLib._splitBond(purchasedGross_, joinDetf_, p_)` (`:45–53`):**
```
join_ = joinDetf_
userDetf_ = mulDiv(purchasedGross_, ONE_WAD - p_, ONE_WAD)
potDetf_ = mulDiv(purchasedGross_, p_, ONE_WAD) + mulDiv(joinDetf_, p_, ONE_WAD)
```
**Three independent floors** — `user + pot ≤ purchasedGross + join` (rounding may lose up to 3 wei). `join_` is separately minted for liquidity self-leg (not boosted).

**Source order / floor denom constraints:**
- `_quoteBondG` (`:267–282`): live-book quote uses `mulDiv(reserveDetf_, pairEq_, reservePair_)` — uses native DETF self-leg reserve and pair reserve from `previewExitProportional(supply_)`. If `reserveDetf_ == 0 || reservePair_ == 0`, falls back to `_openingBondQuote`.
- `_quoteBondPurchase` (`:285–290`): boosted payment × duration multiplier via `_quoteBondG` for opening or `_hook().previewSwapExactIn` for live.
- `_quoteReserveLpBond` (`:295–306`): per-leg sum across non-self legs only (line 302 `if (tokens_[i_] != address(this))`).
- `_quoteMintGross` (`:252–256`): `boosted = mulDiv(pairEq, ONE_WAD + p, ONE_WAD); gross = _hook().previewSwapExactIn(...)` — boost then swap-quote.

**No double fee:** `_quoteBondG` and `_quoteMintGross` operate on **different** functions; `_quoteBondG` is for bond opening, `_quoteMintGross` is for live mint. The hook's `_maybeMintProtocolFee` is the HLP mint (oracle-driven); the bond quote does not double-charge it. The DETF `_splitMintedDetf` deducts only `p` (seigniorage share), not additionally the hook LP fee.

---

## 3. Amendment recommendation — UNAPPROVED

```markdown
### §4.X NN05 weights & synthetic for v0.28 selected1

Weights (user-selected 2026-09-27; PRD-validated against UniswapV4StandardExchangeWeightedBufferHook):
- NET-DETF self-leg: 50% (excluded from `previewSynthetic` mark per line 122)
- NET: 20%
- sNET: 10%
- USDG: 20%

Synthetic per numeraire (NET pricing leg example):
  rated[NET] is the hook's NET inventory in wad-rate units (9-dec native via `_ratedWadAll`).
  marked = rated[NET] + Σ(over i ≠ NET, i ≠ DETF) rated[NET]·weights[i]/weights[NET]
  pairWad = marked · ownedLp / lpSupply
  den = detfTotalSupply + pendingExpansion       (detfTotalSupply = totalSupply · 1e9)
  synthetic(NET) = (pairWad · 1e18 / den) · 1e18 / creationPairPerDetfWad[NET]

Synthetic uses **creationPairPerDetfWad only**, not opening. Opening is used for first-bond pricing and falls back to creation when zero (`_openingBondQuote` line 262). The DETF synthetic does not silently substitute opening for creation.

Oracle fallback is **silent zero return**, not revert. Failure modes: `supply == 0`, `rootKLast == 0`, `rootK <= rootKLast`, `ownerFeeShare == 0`, `!feeOn`, `kLast == 0`, `mode != kLastMode`, `!isLive()`. Each returns zero.

Fee usage (no invented model):
- Hook HLP mint: existing `_maybeMintProtocolFee` per existing oracle (`usageFeeWad`, `feeTo()`, `ownerFeeShare = usageFeeWad * FEE_DENOMINATOR / WAD`).
- NET-DETF mint: existing `_splitMintedDetf` with `seigniorageIncentiveWad = oracle.seigniorageIncentivePercentageOfVault(address(this))`.
- Bond split: `_splitLiveGross` (two-floored) or `_splitBond` (three-floored, plus join liquidity self-leg). Each mulDiv floors independently; rounding may lose up to 2-3 wei.
- **No double fee** — HLP mint and DETF seigniorage share are distinct paths; the bond quote operates on reserves without duplicating either.
```

---

## 4. False simple-NET-only formula — explicitly rejected

A naive `synthetic = NET_balance / DETF_total_supply` would be wrong:
1. **Excludes self-leg** (`:122`) but **includes numeraire at full value** (`:124`) — does not subtract numeraire leg.
2. **Includes OTHER non-self legs** (`:129`) — USDG, sNET weighted into NET.
3. **Scales by `ownedLp / lpSupply`** (`:134`) — not whole inventory.
4. **Divides by `creationPairPerDetfWad`** (`:139`) — not the ongoing TWAP.

The simple formula is rejected by source. Per the user: "false simpleNETonly formula" — confirmed.

---

## 5. Confidence and evidence limits

- **High** all six source ranges verified directly: `UniswapV4DetfCommon.sol:90–211, 252–339`; `DETFMintSplitLib.sol` (full 54 lines); `UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol:89–186`; `UniswapV4StandardExchangeWeightedBufferHookTarget.sol:387–463`; `UniswapV4StandardExchangeWeightedBufferHookMath.sol:160–180`.
- **High** that the user's "excludes self, includes other nonself legs marked into NET" framing matches the source exactly.
- **High** that the simple NET-only formula is wrong.
- **High** that fee usage reuses existing oracle; no invented model.
- **Medium** that `_ratedWadAll` returns consistent wad-rate units across tokens — its internal source was not directly read this round (function reference only); the rate-provider interface is verified (`rateProvider(address)` at `:179`).
- **Low** on exact live config values (PkgsArgs immutables) — not asserted, not verified.
- **Not claiming** the user's weights are deployed; PRD §4 must record them with PkgArgs immutables; no live config claim.
- **Not reopening** any settled owner decision.

**Saved:** `docs/research/netnet-weights-fees-2026-09-27/minimax-original.md`. Originals untouched.
