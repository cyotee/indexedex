# Research: Morpho looping DETF configuration

**Date:** 2026-08-26  
**Status:** Research for a **later** DETF package. Not Uni V4 v1. Not implementation.  
**Resume here** when designing the Morpho + Uni V4 loop product.

**Related (do not conflate):**

| Artifact | Role |
|----------|------|
| [`DETF_INSTANCE_IO_ROUTING_PRD.md`](../../contracts/vaults/detf/DETF_INSTANCE_IO_ROUTING_PRD.md) | I/O tables, donate R12a, Uni V4 v1 hook ABI + **one** Uni V4 DETF DFPkg. Explicitly: Morpho-illiquid close is **out of v1**. |
| `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchange_PRD.md` | Morpho Blue SE: **supply only**. One market. `loanToken` = `rateAsset`. Never `createMarket`. No borrow on the vault. |
| `contracts/oracles/uniswap/v4/twap/UNISWAP_V4_MULTI_POOL_TWAP_ORACLE_PRD.md` | Morpho `IOracle` adapters (TWAP). Not DETF mint/burn gates. |
| This file | Design discussion of using Morpho **borrow against `detfToken`** plus a Uni V4 TT/ETH SE in one DETF. |

**Role names:** `rateAsset`, `pairToken`, `underlyingVault`, `vaultShare`, `detfToken`, `reservePool`. Not product tickers. Use `WETH` only where the market loan token is actually WETH.

---

## 1. Why this file exists

A session on 2026-08-26 designed Uni V4 hook-quoted DETFs and instance I/O tables. The **Morpho leverage loop** was the original product idea that motivated those tables (mint TT only, bond WETH into Morpho, donate must not open Morpho). v1 of the I/O PRD then **scoped Morpho close / illiquid unwind to a later DETF package**.

This document stores the loop discussion so that later package can start from decisions and rejected shapes, not from a blank page.

---

## 2. Original configuration (user proposal)

### 2.1 Pieces

1. Uniswap V4 pool `$TT` / ETH (WETH). Wrap in a **Uniswap V4 Standard Exchange** vault.
2. Morpho Blue **market**: `loanToken = WETH`, `collateralToken = detfToken`. Wrap **supply** in a **Morpho Blue Standard Exchange** (one market per vault).
3. DETF reserve pairs:
   - Uni V4 SE vault share with `$TT` (`rateAsset` of that vault / pair face).
   - Morpho SE vault share with WETH (`loanToken`).

First sketch used **Multi-vault weighted DETF** (Balancer host): two SE legs + DETF self-leg. Later the same session collapsed Uni V4 DETF *families* to one hook-based DFPkg. The **loop product** is not that v1 Uni V4 DETF. It needs Morpho shares **in the reserve**, which the hook book (DETF + pairs) does not provide unless Morpho shares are a pair token (they are not).

**Likely later host:** Balancer **Multi-vault weighted** DETF with I/O tables (follow-on in the I/O PRD), **or** a new DETF package whose close can unwind Morpho. Do not bolt Morpho cash-out onto the Uni V4 hook DETF v1.

### 2.2 Intended user loop (first version)

1. Deposit WETH into Morpho SE → vault shares.
2. Mint `detfToken` with those shares (or, as later refined, mint only with TT).
3. `supplyCollateral(detfToken)` on Morpho, `borrow(WETH)`.
4. Repeat, or (refined) sell WETH for TT on the TT/ETH book and mint more DETF from TT.

Premise: WETH from mint-via-Morpho sits in Morpho as supply and is the same cash borrowers draw. The DETF does not borrow; **users** (or a later protocol-owned loop vault) borrow on Blue.

---

## 3. What already exists in-tree

| Piece | Status |
|-------|--------|
| Uni V4 SE vault | Production package. `tokens()` = pool currencies. |
| Morpho Blue SE | Supply-only. `vaultTokens()` = `[loanToken]`. NAV = idle + `expectedSupplyAssets`. Withdraw reverts when Blue has no cash. **No sleeve in v1.** Vault never `createMarket`. |
| Multi-vault weighted DETF | Mint/burn **vault shares only** today. Bond: BPT + shares. Donate join: DETF or shares, not rate assets. |
| Euler SE | **None.** Drop Euler for this experiment unless a second lending SE is in scope. |
| Morpho listing of `detfToken` | Configuration: `createMarket` with predicted DETF address (CREATE3). Oracle adapter required. |

Weighted live mint cannot take WETH or TT as `tokenIn` until I/O tables (follow-on) add `{WETH, morphoSe}` / `{TT, uniV4Se}` zaps: `SE.exchangeIn` then join **shares**.

---

## 4. Loop shapes discussed

### 4.1 Remint through Morpho (WETH → Morpho shares → DETF → borrow WETH)

Works as a two-step, not as DETF `exchangeIn(WETH)`. Bounded by Policy mint gate (synthetic > 1.05 unless Open), Morpho LLTV, and Morpho **cash**. Full utilization: Morpho SE `maxWithdraw` → 0. Weighted burn of Morpho shares reverts. User accepted illiquid Morpho unwrap as a product stance for the *credit rail*, not as honest NAV.

### 4.2 Borrow WETH, buy TT, mint DETF (the refined loop)

Borrowed WETH is sold on the TT/ETH book. TT (via Uni V4 SE shares) mints DETF. Buy pressure on TT. Morpho stays 100% utilized on purpose.

**You still do not mint DETF with TT on Weighted today.** Path: TT → Uni V4 SE → shares → DETF. If the SE zaps TT by selling some TT for WETH to LP, it sells into the book just bought.

If the Uni V4 SE **is** the TT/ETH book (likely for a test token):

1. User borrows WETH (Morpho cash that is mostly DETF Morpho-leg supply).
2. Swap WETH → TT against the vault’s pool: vault **gives TT, receives WETH**.
3. User deposits TT back into the Uni V4 SE, mints shares, mints DETF.

One WETH is then marked as:

- Morpho SE NAV: `expectedSupplyAssets` still includes the borrow (receivable).
- Uni V4 SE reserves: the WETH that actually arrived in the pool, plus TT deposited back.

Weighted synthetic sums `ownedShares * rate` across legs. Both rates can rise from the same ETH. If Morpho’s collateral oracle uses that synthetic / full NAV, borrow capacity is inflated. That is the **double-count**.

If the Uni V4 vault is a small LP and WETH goes to outside LPs, the DETF does not double-count that WETH inside both legs. You still have a leveraged TT long plus extra DETF from TT deposits.

### 4.3 “Keep Morpho insolvent until bond matures”

Wrong word: the Morpho leg is **illiquid and reflexive**, not insolvent, while borrowers are current. Unwrap is a cash constraint. Share price vs WETH still uses full `expectedSupplyAssets`.

Bond mature **cannot repay other users’ Morpho loans**. D25 proportional withdraw of Morpho **shares** still needs Blue cash (or a vault that delevers).

Two borrower identities (do not mix on one market):

| Who borrows | Bond close can |
|-------------|----------------|
| **Users** against `detfToken` | Not repay Alice because Bob’s bond matured. Morpho SE withdraw still needs cash. |
| **Protocol / nested loop vault** | Delever on redeem: un-LP, repay WETH, pay TT. DETF calls `IStandardExchange` only. |

The session conclusion: **put the loop in an SE vault**, not in DETF production code (opacity; unowned diamond; Morpho types stay out of DETF). Aave cross-version loop vault is the in-tree pattern (leverage in `exchangeIn` / `exchangeOut`). Morpho Blue SE v1 is **not** that vault (D6 supply only).

Later package options:

- **A.** Weighted DETF + I/O tables + **user** Morpho looping. Accept utilization freeze on Morpho-share burn. Close Default = D25 basket (Morpho shares in the bag). If cash is 0, close reverts unless Custom `closeRoutes` omits Morpho (rejoin id 0) or a dedicated loop SE can delever.
- **B.** Nested **loop SE** (Uni V4 inventory + Morpho supply **and borrow**). DETF holds one vault share. `exchangeOut(shares → TT)` repays WETH then pays TT. Close/burn never see a raw Morpho share. This is the package reserved when I/O PRD said Morpho-illiquid close is later.

**Do not** have DETF `supplyCollateral(detfToken)` of **itself**. Unowned diamond + Morpho liquidation of `detfToken` is a protocol dump. If the protocol loops, Morpho collateral should be **Uni V4 LP / TT / loop-vault shares**, not `detfToken`. User-listed `detfToken` collateral is a **different** Morpho market (external looping). Combining A and B on one Blue market makes bond close unable to free cash from user debt.

---

## 5. Valuation and oracle

### 5.1 Synthetic vs Morpho `IOracle`

DETF mint/burn gates use **synthetic** (owned reserve / `totalSupply`, Policy 1.05 / 0.95). Morpho needs `collateral` in **loan token** (WETH), argument-free `price()`, typically 1e36 scale.

Do **not** feed Balancer spot or DETF synthetic into Morpho as-is (manipulable; circular with Morpho NAV).

Safer marks (discussion, not locked):

| Oracle marks DETF as | Loop power | Honesty |
|----------------------|------------|---------|
| Full synthetic / NAV (includes Morpho WETH claims) | Strong | Counts lent WETH as collateral for borrowing that WETH |
| Uni V4 / TT/ETH backing in WETH only | Weaker | Exogenous book only |
| Uni V4 + Morpho **cash** (not borrowed assets) | In between | Harder feed |

Uni V4 multi-pool TWAP + Morpho adapter is the intended slow feed **if** a DETF/WETH (or TT/WETH) pool is thick. The DETF reserve is DETF + vault shares, not DETF/WETH. A third pool for the oracle is extra inventory. Thin launch pool is already a TWAP PRD non-goal.

### 5.2 Weights and LLTV

If Morpho LLTV is set like wstETH (~77%) on **full** NAV while the Uni V4 leg is a fraction of the basket, credit is marked as equity. Size LLTV off **exogenous** weight (Uni V4 / TT), not off Morpho share NAV.

Policy vs Open: Policy mint gate is a loop brake. Open removes it; then only LLTV and cash remain.

### 5.3 Mixed units

Weighted synthetic adds DETF self-leg (raw) + Uni V4 shares × rate (TT) + Morpho shares × rate (WETH). Distinct valuations in one 1e18 peg. For a `$TT` that is not ~1 WETH, the number is a weighted mix, not a WETH NAV. Morpho still needs a WETH price. Do not assume synthetic 1.05 means 1.05 WETH per DETF.

---

## 6. I/O tables (why they were invented)

Without tables, Weighted mint/burn is shares only; donate N6 can seat any SE `tokens()` (including Morpho WETH). That fights “public seigniorage is TT; Morpho only via bond.”

Desired instance (later, on Weighted + I/O follow-on or package B):

| Table | Example |
|-------|---------|
| mint | `{TT, uniV4Se}` only |
| burn | `{TT, uniV4Se}` only |
| bond | `{TT, uniV4Se}`, `{WETH, morphoSe}` |
| donate | Custom `{TT, uniV4Se}` only (Default would be mint ∪ bond and would allow WETH donate into Morpho) |
| close | Later package: Morpho unwind **or** omit Morpho (rejoin id 0). v1 Uni V4 DETF close is D25 hook basket only. Empty Custom close is **illegal**. |

Seating (locked for Uni V4 v1, reuse later): **SE `exchangeIn` then join shares** on the reserve host. Custom `{WETH, morphoSe}` is not forced to the Uni V4 pair map. R6: WETH still appears **once** per table.

Donate **booking** (R12a, locked in I/O PRD): when `totalOriginalShares > 0`, do **not** mint originalShares to id 0. NAV of id 0 and user bonds (id ≥ 3) rises. Ids 1 and 2 never get originalShares. `O == 0`: credit id 0 at 1:1 (N14). Compound / `buyClaim` / D25 DETF rejoin stay id-0 mints.

First bond still funds **every** reserve leg (D16): both vault shares + DETF self-leg. Tables apply **after** live.

Claim stays DETF-only.

---

## 7. Deploy order (chicken and egg)

Morpho SE binds an **existing** market only.

1. Predict DETF address (CREATE3 / `calcSalt(pkgArgs)`).
2. Deploy Uni V4 SE on the live TT/WETH pool.
3. Deploy Morpho oracle adapter (price may be 0 until poked).
4. `createMarket({ loan: WETH, collateral: predicted DETF, oracle, irm, lltv })`.
5. Deploy Morpho Blue SE on that market.
6. Deploy DETF at the predicted address with both vaults (Weighted + I/O) **or** deploy loop SE then DETF (package B).
7. First bond: all non-DETF legs + DETF self-leg.

Do not borrow against DETF until live + oracle + real reserve.

---

## 8. What not to do

- Treat Morpho SE unwrap failure as “NAV is cash.”
- Mark Morpho `expectedSupplyAssets` and Uni V4 inventory as independent ETH after borrow-and-buy against the vault’s own book.
- `createMarket` from Morpho SE.
- Import Morpho types into DETF.
- Protocol-owned Morpho borrow using `detfToken` as collateral on the unowned diamond.
- Put Morpho utilization unwind on Uni V4 hook DETF v1 close.
- Euler in v1 of this idea.
- FoT / rebasing underlyings (token policy).
- Open threshold mode if the mint gate is meant to cap the loop.

---

## 9. Open questions for the later package

Resume design by locking these (not decided):

1. **Host:** Weighted DETF + two SEs + I/O tables, vs one nested loop SE + Single SE / Uni V4 DETF.
2. **Who borrows:** users on Blue vs loop vault vs both (reject both on one market).
3. **Morpho collateral:** `detfToken` (user loop) vs LP/TT (protocol loop).
4. **Oracle:** exogenous-only vs cash-adjusted vs full NAV (not recommended).
5. **Weights** of Uni V4 vs Morpho legs vs DETF self-leg.
6. **LLTV** as a function of exogenous weight.
7. **ThresholdMode:** Policy vs Open.
8. **Close:** D25 Morpho shares (revert if no cash) vs Custom omit Morpho vs loop-SE `exchangeOut` that repays.
9. **Sleeve** on Morpho SE (cash band) vs accept burn/close revert at 100% utilization.
10. **Numeric sketch:** 100 WETH mint, 80 WETH borrow-and-buy against a vault that **is** the TT/ETH book, two NAVs after the trade (double-count).

---

## 10. Suggested resume order

1. Pick A vs B in §4.3 (user loop + Weighted I/O vs nested loop SE).
2. Lock oracle + LLTV + weights (§5, §9).
3. If A: wait for Balancer I/O table follow-on, then Custom tables in §6.
4. If B: PRD for a Morpho+UniV4 **loop Standard Exchange** (borrow in the vault; TT in, TT out after repay). DETF stays opaque. Close is hook/vault share redeem, not Morpho cash.
5. CREATE3 predict + market + oracle before DETF (§7).
6. Production-first tests: utilization freeze, oracle mark, TT dump cascade, R6 single WETH row, donate cannot open Morpho.

---

## 11. Session map (short)

| Turn | Outcome |
|------|---------|
| Loop with Weighted + Uni V4 SE + Morpho SE | Feasible as config; circular credit is the issue |
| Borrow WETH to buy TT to mint DETF | Levered TT flywheel; double-count if vault is the book |
| I/O allowlists + donate subset | Motivated `DETF_INSTANCE_IO_ROUTING_PRD.md` |
| Donate to all originalShares | R12a; ids 1–2 never originalShares |
| Uni V4 hook quote + one DETF DFPkg | **v1**; Morpho close deferred |
| “Morpho no cash on close” | **Later DETF package** (this research) |
