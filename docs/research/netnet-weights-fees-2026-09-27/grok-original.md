# Grok original — NN-05 weights, synthetic, fees

| Field | Value |
| --- | --- |
| Routing | Process identity **`grok-4.6` / `xai/grok-4.6`**. `docs/agent/RESEARCH_COUNCIL.md:35–36` now pins **`xai/grok-4.7`** and says 4.6 sessions fail continuation. **Not relabeled 4.7.** Human asked same-session continuity. |
| Date | 2026-09-27 |
| PRD | v0.28. Tracker NN-05 OPEN (C07). |

**Missing once:** `lib/crane/.claude/skills/crane-architecture/SKILL.md` = `RC_UNAVAILABLE`. Glob of `docs/strategies/ohm-style/netnet-pendle/*` hit broken Crane links. `contracts/interfaces/IDetfReserveQuote.sol` missing; actual interface `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol`. Exhaustive `DETFMintSplitLib` caller search not run (same glob/grep tree errors). `ClaimLib.ratedPairUnits` not fully read. **No live oracle/config.** Crane adversarial skill read; IndexedEx adversarial + V4 hook-package + testing skills read.

---

## Human selections (do not re-ask)

Weights (WAD, sum `1e18`; hook `MIN_WEIGHT=1e16`):

| Leg | Weight |
| --- | --- |
| NET-DETF self | `50e16` |
| NET (PLP/YT virtual) | `20e16` |
| sNET (SY book) | `10e16` |
| USDG (SE shares) | `20e16` |

**Peg vs opening (already selected):** ongoing target **1 NET/DETF**; launch **1,000 NET/DETF** (PRD §§1,10; O05). Synthetic **reuses Universal DETF** `previewSynthetic` with **NET as numeraire**, **total DETF supply**, **owned LP fraction**. Hook HLP mint = **usual usage fee** (`usageFeeOfVault(hook)`). NET-DETF mint = **usual seigniorage** (`seigniorageIncentivePercentageOfVault(detf)`). **No invented p, usage %, or extra deposit haircut.**

---

## Synthetic (not NET-only)

**Caller** (`UniswapV4DetfCommon.sol:175–211`):

```text
ctx.detfTotalSupply = totalSupply * 1e9     // native 9 → human WAD
ctx.pendingExpansion = 0 for live mark
ctx.ownedLp = DETF.balanceOf(this) [+ bondNft if holder ≠ this]
ctx.creationPairPerDetfWad = creationOfPair[NET]   // NOT openingOfPair
wad = hook.previewSynthetic(ctx, NET)
```

**Hook** (`ExitQueryTarget.sol:89–140`):

1. Zero if `ownedLp`, `detfTotalSupply`, or `creationPairPerDetfWad` is 0; numeraire **must not be DETF**.
2. SE numeraire maps to pair. **Skip self-leg.**
3. `rated = _ratedWadAll()` (`Target.sol:342–347`): native/SE inventory → pair units → WAD via `ratedScales`.
4. For NET index `j`, **exclude DETF**, **include every other non-self leg**:

```text
marked = rated[NET]
+ Σ_{i ≠ NET, i ≠ DETF, rated[i]>0, w_i>0}  mulDiv(rated[NET], w_i, w_NET)
```

At equilibrium this is `rated[NET] * (1 - w_DETF) / w_NET`, not “NET virtual only.” **False formula:** `NET_virtual / supply` (drops sNET+USDG, skips `/creation`).

5. Dilution: `lpSupply = _previewSupplyAfterProtocolMint()` (includes **pending protocol-LP**). `pairWad = mulDiv(marked, ownedLp, lpSupply)`.
6. `mid = pairWad * 1e18 / (detfTotalSupply + pendingExpansion)`; `synthetic = mid * 1e18 / creationPairPerDetfWad`.

**Opening vs creation:** `_openingBondQuote` (`Common.sol:258–263`) uses `openingOfPair` else `creationOfPair`: `G = mulDiv(nativeToWad(pairEq), 1e9, opening_)`. Example: `opening_=1000e18`, `pairEq=1000e18` NET → `G=1e9` (1 DETF, 9 dec). **Synthetic must use creation**, not opening. Set **`creationOfPair[NET] = 1000e18`** so marked 1,000 NET-wad per human DETF-wad ⇒ synthetic **`1e18` = peg 1**.

`_syntheticPrice` uses `pairs_[0]` (`:207–211`); **pin NET as the synthetic numeraire**, do not rely on token-array order. `_highestSyntheticPrice` (`:322–340`) maxes all numeraires — **Universal expansion helper; NetNet expansion uses hook TWAP, not this.** Burn **branch** is synthetic **TWAP**; finite quote is owned-book `F`.

**Pricing ≠ funding:** NET coordinate = PLP/YT zap-out (§7.1.2). Ordinary NET/sNET **cash** = shared SY (§6.2). Rated NET in `previewSynthetic` is the **weighted mark**, not a zap-out of the whole book.

---

## Fees (oracle, two keys, no double charge)

Interface (`IVaultFeeOracleQuery.sol:16–24,58,113`): WAD; **vault → type → global**; **stored 0 = unset**, not 0%. **No live values claimed.**

**Hook HLP** (`Target.sol:387–452`; `Math.sol:165–179`):

```text
usageFeeWad = feeOracle.usageFeeOfVault(address(this))  // hook proxy
ownerFeeShare = usageFeeWad * 100_000 / 1e18
feeOn = feeTo≠0 && usageFeeWad≠0 && usageFeeWad<1e18 && ownerFeeShare≠0
protocolLp = supply * (rootK-kLast) / (rootK*100000/ownerFeeShare + rootK - kLast)
```

Uniswap-V2-style **K-growth mint to `feeTo`**, not `join * usage%`. `feeOn` false or `kLast==0` ⇒ no mint. Swap fee is **separate** `dexSwapFeeOfVault`. Do **not** also haircut HLP deposits by usage%.

**NET-DETF mint** (`Common.sol:112–136`; `DETFMintSplitLib.sol:18–52`):

```text
p = feeOracle.seigniorageIncentivePercentageOfVault(address(this))  // DETF proxy; 0 if oracle unset
live:  user = mulDiv(G, 1e18-p, 1e18);  pot = mulDiv(G, p, 1e18)
bond:  join G unboosted; user = (1-p)*U; pot = p*U + p*G
```

Observed callers: `_splitBondDetf` from `UniswapV4DetfTarget.sol:569,590`. `_splitMintedDetf` wraps live split; **full caller set not exhaustively listed.** Liquid NetNet **buys existing DETF** — no live liquid mint. Bond still splits. Expansion **does not take p** (alignment D4; PRD §9 mints full then fee/creator **internal shares**). Contraction `qQuote = q*(1e18+p)/1e18` (§7.2) is **quote-only**, not a second mint.

`DETFDecimalScaleLib` comment that DETF “stays 18” **contradicts** 9-decimal product law and Common `* 1e9`. Use Common.

---

## Amendment (C07 / NN-05)

Write as **selected**, not examples:

1. Weights `50/20/10/20` e16 as above; Balancer Weighted + `MIN_WEIGHT`.
2. Synthetic = `previewSynthetic(ctx, NET)` with `creation[NET]=1000e18`, 9→WAD `*1e9`, **self excluded**, **other legs marked into NET**, **ownedLp / post-protocol-fee supply**.
3. Fees = existing oracle lookups only (hook usage / DETF seigniorage); protocol-LP formula as sourced; **no flat join %**, **no double usage**.
4. Remaining **engineering** (not owner numbers): rated NET from §7.1.2 zap-out; sNET SY provider (NN-10); USDG SE rate; first-bond G/U vs these weights (A35).

**Do not ask** p, usage fee, or a new synthetic model.

Confidence: **high** on cited formulas and the false NET-only mark; **none** on deployed oracle percentages.
