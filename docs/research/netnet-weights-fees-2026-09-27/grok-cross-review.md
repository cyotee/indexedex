# Grok NN-05 cross-review

| Field | Value |
| --- | --- |
| Routing | `xai/grok-4.6` (not relabeled 4.7). Inputs: own original (untouched) + full Astra, MiniMax, Kimi. No peer cross-reviews. |
| Date | 2026-09-27 |

---

## Agreement (keep)

Human weights **50/20/10/20** e16 by **leg identity**. Fees **not reopened**: hook `usageFeeOfVault(hook)` + DETF `seigniorageIncentivePercentageOfVault(detf)`. No invented p/usage/defaults. No Universal `_highestSyntheticPrice` expansion import.

`previewSynthetic` (`ExitQueryTarget.sol:89–140`): skip DETF; include NET at `rated[NET]`; other **positive** non-self legs add `floor(rated[NET]*w_i/w_NET)` (weight-ratio mark, **not** each leg’s own rated amount). Then `ownedLp / lpSupply` with `lpSupply=_previewSupplyAfterProtocolMint()`. Native 9→WAD **once** (`supply*1e9`); `_quoteCtx` sets `pendingExpansion=0` and, if previewing settlement, already folds pending mint into that supply — **do not add twice**. Divide by **`creationPairPerDetfWad`**, not opening.

False: `NET_virtual / supply`.

Hook fee = **K-growth protocol-LP mint**, not a join haircut. Swap/imbalance uses **`dexSwapFeeOfVault`**. SE/tax are **SE-boundary**. Distinct from DETF seigniorage split.

---

## Correction: peg vs opening (Grok original wrong)

**Selected peg is 1 NET/DETF, not 1,000.** Opening `1000e18` is **first-bond only** (`Common.sol:258–263`).

Keep source division:

```text
C = creationOfPair[NET] = 1e18     // 1 NET per DETF
openingOfPair[NET] = 1000e18       // bootstrap G only
synthetic = floor(floor(V * 1e18 / S) * 1e18 / C)
```

At 1 NET-wad per DETF-wad and `C=1e18`, synthetic **`1e18`**. At launch ~1000 NET/DETF, synthetic **`1000e18` (above peg)** — intended.

**Grok original’s `creation=1000e18` is rejected:** it would make a 1-NET book print `1e15`, **erasing the absolute peg**. Astra/Kimi were right. MiniMax correctly said “creation not opening” but did **not** pin `C=1e18`.

---

## 2.5× only if all three external legs live

With selected weights, if NET+sNET+USDG all have `rated>0` and `w>0`:

`M = R_NET + floor(R_NET/2) + R_NET` ≈ **2.5 R_NET** (exact floors).

If a non-self leg is empty, that addend is **skipped, not renormalized** (Kimi). Do not bake 2.5 into the PRD as an identity.

---

## Oracle / zeros / TWAP (MiniMax over-merged)

| Event | Meaning |
| --- | --- |
| Stored oracle **0** | **vault → type → global** (`IVaultFeeOracleQuery.sol:16–24`). **Not** silent 0% and **not** “oracle returns 0.” |
| `usageFee` after fallback still 0 / `≥WAD` / `feeTo=0` | `feeOn=false`; **no** protocol-LP mint |
| `previewSynthetic` 0 (`!live`, zero ctx, unknown numeraire) | **Not a measured 1h TWAP.** Absent TWAP = **above-1 branch**, not below-peg burn |
| Rate-provider fail-closed | **Not** missing-TWAP policy |
| `protocolLpShares` 0 | no K growth / mode mismatch / zero share — **not** a price |

MiniMax “Unknown → revert(0)” is **`return 0`**. MiniMax “`_quoteBondPurchase` via `_quoteBondG`” is **false** (boost then opening or `previewSwapExactIn`).

---

## Fee math (rounding)

`Target.sol:395`: `a = (u * 100_000) / 1e18` (floor).  
`Math.sol:176–179`: `num = supply*(K-Klast)`; `den = (K*100000)/a + (K-Klast)`; **`num/den` floor**. `K` is Weighted **V** (or interim), **not √K**, from **`_invWadAll` native inventory**, not rated swap vector (Astra). Do not invent a second usage % on deposits. Astra’s JoinCore mint-before-join was **not re-read here**.

Live split: two independent `mulDiv` floors; `user+pot ≤ U`. Bond: `user=(1-p)U`; pot `pU+pG`; **G unboosted**. Do not use `_splitHalfSeigniorage`. Expansion **does not take p**.

---

## Custom custody ≠ Universal rated book yet

Rated NET must be **PLP/YT zap-out**, sNET **SY provider**, USDG **SE rate** — still NN-10/C12 mapping. `_protocolLp` may add a bond-NFT holder; **this family is direct DETF HLP** — use **actually owned** L, not whole-hook inventory. Burn quote remains **ownership-limited nonlinear F**, not this marginal mark.

No oracle-free / live-config / preview-parity guarantee.

---

## Handoff

Record: weights; **C=1e18 / opening=1000e18**; source-ordered floors; two oracle keys; growth-LP vs seigniorage. **Retire fee/formula questions.** Remaining: custom rated inputs + pin NET as numeraire (do not use `pairs_[0]`).
