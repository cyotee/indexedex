# MiniMax M3 — leveraged wsNET / Morpho cross-review

Read all three originals this turn; no peer cross-review files. Source/math adjudication over voting.

## 1. Math corrections

**My §9 APR error (decisive).** I wrote: "At `P = 1.04` this is `0.0045 × (0.04/0.75) × 1095 = ~0.26%` annual." That is off by 100×. The product is `0.0045 × 0.0533 × 1095 = 0.2628`, i.e., **26.28% APR**, not 0.26%. The economic conclusion in my §9 ("far below Morpho borrow APY in any normal regime") and the threshold ("Only at `P > 1.4` does rebase APY exceed 12% annualized") both **flip**: at 1.04× premium, rebase APY is comparable to or above typical Morpho borrow rates (utilization-driven 2–10% in normal conditions). Source: `Distributor.sol:86–99`; `Constants.sol:18–20`; 1095 = 365 × 3 epochs/day. The user-callout is correct. **My "value-extracting trap" claim is wrong at low/moderate premiums.** The loop is profitable whenever `0.0045 × (P−1)/0.75 × 1095 > borrow_APY(P,u)`, which for u<0.7 and P>1.01 is typically satisfied.

**W at zero-debt (correction to my §4).** I wrote "W = ∞" at D=0. This is **wrong**: at D=0, the target constraint `D ≤ τV` is trivially satisfied for any τ∈(0,1), so W is bounded by posted collateral C (the entire position can be withdrawn). W=C, H=τ·V. The user is right; the clean continuous model writes `W = max(C − D/(τp), 0)`, and at D=0 this equals C. Grok: "W is essentially all collateral." Astra: "If debt is zero, all c is withdrawable; t=0 requires a separate zero-debt-only policy." All three peers correct; my §4.3 over-stated.

**Joint constraint `τpx + y ≤ slack` (Astra originals.md:48).** Verified continuous: `H_credit = τV − D`, `W = (D/(τp) − C)` reflected, so at the boundary `H_credit = τp·W` and any combined (withdraw x wsNET, borrow y USDG) satisfies `τp·x + y ≤ H_credit`. This is the same continuous identity Kimi originals.md:29 and Grok originals.md:60–61 derive. My §4 §W,H separately said they are not additive; the joint constraint is the precise non-additivity rule.

**Phantom burn (user-callout).** I did not address this. A repayer paying USDG to the vault to retire vault debt must not have vault *equity shares* burned in the process — the vault's repay burns Morpho `borrowShares` (line 286–288 of `lib/crane/contracts/external/morpho/blue/Morpho.sol`), not the diamond's equity. Adding repay-driven share burn would create a new claim class for the residual equity. Correct route semantics: USDG-in either (a) **repays the vault's Morpho debt** (no equity share movement) or (b) **mints equity shares** in exchange for deposited USDG (a separate lending leg) — never both.

**Positive-equity above-target vs insolvency (user-callout).** Above-target is a *low-LTV* state (τ < LTV ≤ LLTV), not insolvency. Insolvency is `E = V − D ≤ 0` regardless of LTV band. These are independent: a position can be above target and solvent, between target and LLTV and solvent, or below LLTV and either solvent (oracle tight) or insolvent (oracle loose). My §6 conflated "above target" with "healthy" only; the user is right that the three conditions are separate.

**Returns metrics per funded participation, not new donations (user-callout).** A wsNET donation supplied `onBehalf=vault` (line 313) increases `V` for *all* existing holders pro-rata; it is not share-accretive to a new depositor. The A0/K1 rule from `MorphoBlueStandardExchange_PRD.md:71` extends. A K1 anti-dilution test must check that a fresh wsNET donation does not mint free shares to the next equity depositor. My §5 mentioned K1 only for first-depositor, not for ongoing donations; the user's callout is correct.

**Provider empty-supply behavior (verified at `StandardExchangeRateProviderFacet.sol:91,111`).** Line 91 comment: "D60 (2026-09-22): an empty Standard Exchange still has a well-defined initial mint rate." Line 111: `return 0;`. Kimi and Grok are right: empty supply returns **0**, not infinity or a placeholder. A zero rate is *not* a safe "ignore this leg" signal in a Weighted join (Grok originals.md:64). My §11 said "hook zero rate" but I had not read the actual code; the verified behavior is 0 at empty NAV.

## 2. Source verifications

**Morpho repay callback order (lines 281–295, Morpho.sol).** Both Grok originals.md:79 and Astra originals.md:81 claim "debt decreases before onMorphoRepay, then loan tokens are pulled afterward." Source-verified: `_accrueInterest` (281) → `position.borrowShares -= shares` (286) → callback (293) → `safeTransferFrom(msg.sender, …)` (295). **Debt is reduced at line 286, callback at 293, pull at 295.** Both peers correct. This is the source of the "full repay allows full collateral withdrawal even when oracle fails" claim: at D=0, the LTV check at line 337 (`_isHealthy`) passes vacuously (`0 ≤ collateral × price × lltv / 1e36`), and the oracle's `price()` revert is *only* triggered by `borrow`/`withdrawCollateral` health checks, not by the position reaching D=0.

**Morpho authorization model (verified).** Per `IMorpho.sol:146–239` and `Morpho.sol`:
- `supplyCollateral(marketParams, assets, onBehalf, data)`: **no** authorization check (line 303–320, no `_isSenderAuthorized`); anyone can credit collateral to any `onBehalf`. But tokens are pulled from `msg.sender` (line 319), so a third party cannot use someone else's tokens without allowance.
- `repay(marketParams, assets, shares, onBehalf, data)`: **no** authorization check (line 268–298); anyone can repay on behalf of any borrower.
- `borrow(...)`: requires `msg.sender == onBehalf || _isSenderAuthorized(onBehalf)` (line ~250).
- `withdraw(...)` and `withdrawCollateral(...)`: same authorization requirement (line 331).

**Implication for vault-owned vs user-owned positions:**
- **User-owned (TurboRouter pattern):** each user runs `setAuthorization(router, true)`, then the router borrows/withdraws on the user's behalf. The router is stateless. Liquidation seizes *user's* collateral.
- **Vault-owned (pooled):** the diamond is `onBehalf`. The diamond borrows/withdraws against *its own* collateral. Equity shares represent a pro-rata claim on `collateral − debt + idle cash`. Liquidation seizes *vault's* collateral and burns *all* equity equally. The user is **right** that the v0.36 D6 supply-only restriction is a *product* boundary, not a technical impossibility. My §2 over-stated the constraint.

**`SharesMathLib.sol:20–43`.** VIRTUAL_SHARES = 1e6, VIRTUAL_ASSETS = 1. Astra originals.md:19 `D = ceil(b*(A+1)/(T+1e6))` is the correct integer-floor form of `b.toAssetsUp(totalBorrowAssets, totalBorrowShares) = ceil(b × (T_a + 1) / (T_s + 1e6))`. Astra correct. Kimi originals.md:20 `D = ceil(b_s × B_a / B_s)` is the no-virtual-shares form, which is a continuous approximation; for production the virtual form is mandatory.

**Borrow direction rounding (line ~252, Morpho.sol).** Newly minted borrow shares round **up** via `assets.toSharesUp` (verified in `_borrow` path). Confirms Astra originals.md:21.

**Repay direction rounding (line 283–284, Morpho.sol).** Repaying by assets: `shares = assets.toSharesDown(...)` (line 283). Repaying by shares: `assets = shares.toAssetsUp(...)` (line 284). Confirms Astra originals.md:21.

**Oracle fail-closed scope (line 56–64, `LoopbackOracle.sol`).** Verified: `price()` reverts on `spot < TWAP × (1 − DIVERGENCE_BPS/10000)`. The "borrows and liquidations alike" claim (Kimi originals.md:10) is correct: the oracle is read by Morpho's `_isHealthy` during both `borrow` and `withdrawCollateral`. **`repay` and `supplyCollateral` do not read the oracle**, so a vault in fail-closed state can still repay debt and add collateral (insulating it from liquidation during the pause). This is the falsifiable design condition the user requested.

## 3. Disagreements with peers (source-checked)

**Astra originals.md:23 `creditedNET = clamp(0.90×TWAP, treasuryNAV, 5×treasuryNAV)`.** Compare `LoopbackOracle.sol:67–71`: `credited = twapWad × (BPS − HAIRCUT_BPS) / BPS` = `twapWad × 9000/10000` = `twapWad × 0.90`, clamped to `[floor, 5 × floor]`. Astra correct in structure but the "twap" in `LoopbackOracle` is `pairOracle.twapNetUsdg()` not a generic TWAP — confirms my §8.

**Astra originals.md:48 `H_credit = max(floor(V×t/1e18) − D, 0)`.** Source-correct given the WAD-convention that `t` is fractional WAD and `V` is raw. In raw terms: `H_credit = (V × t / 1e18) − D` clamped at 0. The continuous form `H_credit = τpW` holds when `t × p × W = t × p × (C − D/(tp)) = t × p × C − D = τV − D = H_credit`. Verified.

**Kimi originals.md:46 `V = c × p / 1e36`.** Verified: `LoopbackOracle.price()` is 1e36-scaled, so `collateral × price / 1e36` is the loan-units value. This is the standard Morpho valuation. Kimi correct.

**Kimi originals.md:45 "Borrow/withdraw revert when market cash is insufficient."** **Half-correct, half-wrong.** Borrow does not require market cash (it is LTV-gated, line ~250). Withdraw (of supply) does require market cash (`totalSupplyAssets − totalBorrowAssets` ≥ requested, line 167). Kimi's blanket statement is loose; the precision is: **borrow is LTV-gated; supply-withdraw is cash-gated**. WithdrawCollateral is LTV-gated (line 337), not cash-gated.

**Grok originals.md:33 "TWAP is WAD USDG per whole NET. Spot is only a divergence guard."** Confirmed (line 81–86 of `LoopbackOracle.sol`). The "crediting WAD via index" claim is consistent with `LendingConstants.sol:36–39`.

**Astra originals.md:92 "Borrow to buy to post increases collateral and debt, consuming fees; it is not share yield at execution."** Verified. `TurboRouter.sol:163–222` explicitly settles pending rebase and pays 5% NET tax on the buy leg. The accumulated wsNET is *new* collateral; the new equity-NAV impact is `(new_V − new_D) − (old_V − old_D)`, which is generally negative due to tax + 0.3% pool fee. Confirms.

## 4. Constructive options for the user goal

All three peers (and the user) identify the core goal: a pooled, wsNET-collateralized, USDG-debt vault where token routes are management directives. The architectural dispute is the share-accounting model.

**Option A — Equity share + capacity views (Kimi §6, my Option A).** One share class. NAV = `V − D + K − liabilities`, measured at oracle-haircut value. Mint on actual-received equity at pre-credit NAV. Two views (`maxWithdraw = W_exec`, `maxBorrow = H_exec`) are *observability*, not value. Hook is unchanged. PRD v0.36 R55 only requires the SE-class to be `standardExchangeVault`; a new leverage DFPkg is a *separate* family package, not a re-opening of D6.

**Option B — Custom dual-coordinate hook (Astra §5).** Two bound rate providers (one for `W/S`, one for `H/S`) feed a custom Weighted hook whose host math explicitly handles the non-additivity. This is *feasible* but requires a custom Weight/quote implementation; the existing `StandardExchangeRateProvider` returns 0 on empty NAV (`StandardExchangeRateProviderFacet.sol:111`) and the existing `Weighted` join/exit enforces ratio/domain guards (per Astra originals.md:92). The proposal must prove conservation under all combinations. **Engineering gate, not a product decision.**

**Option C — Separate leverage DETF (my §3.1, Grok §1).** A new Standard Exchange Diamond with the existing four-leg family + a fifth leg = wsNET-collateralized Morpho borrow. Re-opens HLP and the v0.36 PRD's "supply-only" clause. This is the *largest* change.

**Recommended bounded initial:** Option A with the architectural restriction that the diamond is *itself* the Morpho borrower (vault-owned position, not user-owned). This requires (a) re-opening v0.36 PRD §2.3:172 *only* for the new family, not the existing one; (b) writing a new PRD for the borrow vault (not a Round-3 amendment); (c) accepting the concentration risk the user explicitly accepts. Owner must decide whether the *family* DETF or a *new* DETF holds the borrow position. The two are functionally distinct risk profiles.

## 5. Unresolved dissent (3-of-4)

- **Vault-owned vs user-owned positions.** I previously argued vault-owned was incoherent (§2 of my original); the user and Grok correctly note that Morpho allows `supplyShares + borrowShares + collateral` at the same address, so vault-owned is technically feasible. **My original was wrong on this point.** A vault-owned pooled position is a *product* choice, not a *technical* impossibility. The user is right.
- **Astra's 0.26% APR vs my 26.28%** — the corrected figure is **26.28%**. My original was off by 100×; the user is right. Astra originals.md does not give a specific APR; Kimi originals.md:49 stays qualitative.
- **Reusing v0.36 DETF as borrow vault vs new package.** Grok §1 says "Do not add as a leg of the current family" (recommended). My Option A says new package, not a re-opening. Kimi §6 says new package. **3-of-3 peers recommend a new package; my original's §3.2 Option B (re-open D6) was not adopted.** Resolution: the borrow vault is a new package; v0.36 D6 is not re-opened.

## 6. Strongest falsifiable design conditions

For the user's proposal to be coherent, the following must hold simultaneously (each is independently falsifiable):

1. **Pooled vault position model:** the diamond is the Morpho `onBehalf`. Equity shares fractionalize `V − D + K`. Falsifier: cannot have a single diamond address hold a Morpho position with both `collateral > 0` and `borrowShares > 0` without `setAuthorization` round-trips.
2. **Two-capacity single-NAV:** providers report W and H; totalAssets is single-valued; double-counting requires explicit partition or tranching. Falsifier: a Weighted host that sums two rate providers for totalAssets double-counts and inflates the share NAV.
3. **Closed-form underwater deposit:** an underwater position (`E ≤ 0`) cannot mint equity shares at any price; the operation must revert or trigger a separate recapitalization. Falsifier: a deposit that mints shares while `E ≤ 0` is dilution.
4. **Full unwind without external flash:** `repay(allBorrowShares, 0, vault, data)` → callback → `withdrawCollateral(all, vault, vault)`, with conversion in callback funded by withdrawing. Falsifier: if `oracle.price()` reverts on divergence during unwind, `withdrawCollateral` reverts; a full close fails. **Mitigation:** `E = 0` makes `_isHealthy` pass without reading the oracle (vacuous check), so a *full* repay-then-withdraw-all-collateral sequence works even under oracle fail-closed. **Partial unwind may still fail.**
5. **APY comparison threshold:** rebase APY > borrow APY at the relevant premium. With R_MAX = 0.45%/8h-epoch, the threshold `P*` solving `0.0045 × (P*−1)/0.75 × 1095 = borrow_APY(P*, u)` is `P* ≈ 1 + 0.75 × borrow_APY / 4.9275`. At 5% borrow APY, P* ≈ 1.0076. **The loop is profitable at any premium above ~1.01× if borrow APY is below 5%.**
6. **Encumbered supply ≠ price floor:** concentration in one borrow position is systemic risk; a single bad oracle revert or interest shock can liquidate. Falsifier: the user-stated goal "prevent market NET below buyback NAV" requires a *mechanism* that buys NET on dips; encumbrance alone is not that mechanism.

## 7. Saved path

Written to `docs/research/netnet-leveraged-wsnet-2026-10-03/minimax-cross-review.md`. Originals frozen. No PRD/plan/source/shell/RPC edits. Cross-review complete; bounded round closes here.

## Sources cited (path:line, version)

- PRD v0.36: `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md:22,127,172,289–340`
- Plan v0.10: `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md:7–13,20`
- Morpho Blue source: `lib/crane/contracts/external/morpho/blue/Morpho.sol:268–298,303–320,322–342` (repay, supplyCollateral, withdrawCollateral)
- Morpho Blue interface: `lib/crane/contracts/external/morpho/blue/interfaces/IMorpho.sol:6–353`
- SharesMathLib: `lib/crane/contracts/external/morpho/blue/libraries/SharesMathLib.sol:20–43` (VIRTUAL_SHARES, VIRTUAL_ASSETS, toAssetsUp)
- LoopbackOracle: `lib/crane/contracts/protocols/pol/net/src/lending/LoopbackOracle.sol:11–88`
- TurboRouter: `lib/crane/contracts/protocols/pol/net/src/lending/TurboRouter.sol:1–330`
- LendingConstants: `lib/crane/contracts/protocols/pol/net/src/lending/LendingConstants.sol:9–40`
- Distributor: `lib/crane/contracts/protocols/pol/net/src/Distributor.sol:43–99`
- Staking: `lib/crane/contracts/protocols/pol/net/src/Staking.sol:129–151`
- WrappedStakedNET: `lib/crane/contracts/protocols/pol/net/src/perp/WrappedStakedNET.sol:79–86`
- Zap: `lib/crane/contracts/protocols/pol/net/src/perp/Zap.sol:41–48`
- StandardExchangeRateProviderFacet: `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:91,111`
- MorphoBlueStandardExchange PRD: `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchange_PRD.md:42–71,367`
- `docs/detf/NET_MORPHO_USDG_LENDING_STRATEGY_PRD.md:1–80`
- Peers (untrusted model evidence): originals.md astra/grok/kimi originals
- Context7 Morpho docs, 2026-10-03
- `https://docs.netnet.capital/lending`, 2026-10-03
- Morpho Blue v1.0.0 vendored, pin `55d2d99304fb3fb930c688462ae2ccabb1d533ad` (per `lib/crane/contracts/external/morpho/blue/VENDOR.md`)
- NetNet 2026-08-28 verified-source dump, `lib/crane/contracts/protocols/pol/net/VENDOR.md`