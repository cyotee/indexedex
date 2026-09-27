# MiniMax M3 — combined cross-review (preserves original)

Three peer originals read in full: Astra (85 lines), Grok (102), Kimi (65). My original (`…-minimax-original.md`) preserved. Owner-input moderator context already shared. All peer reports are attributed evidence, not authority.

## A. Direct-source verification of disputed claims

I re-checked the local Pendle snapshot under `lib/crane/contracts/protocols/perps/pendle/`. Results in the table supersede unverified claims.

| Disputed claim | Verified | Evidence |
|---|---|---|
| `exitPreExpToSy` / `exitPostExpToSy` existence | **DO exist** (Kimi and Astra correct; Grok's "not present" is wrong) | `router/ActionMiscV3.sol:129` `exitPreExpToSy`; `:208` `exitPostExpToSy(receiver, market, netPtIn, netLpIn, minSyOut)`; `:111` `exitPreExpToToken`; `:218` `_exitPostExpToSy(bool, address, address, uint256, uint256)`. All are state-changing execution helpers. |
| `exitPreExpToSy`/`exitPostExpToSy` usable for view quotation | **No** (all three peers agree) | Owner input line 24 explicit; helper bodies call into AMM and burn LP. |
| Caller-specific fee override matters | **Yes** | `router/base/ActionBase.sol:135` `IPMarket(market).readState(address(this))`; `offchain-helpers/router-static/base/ActionMarketAuxStatic.sol:307–308` `_readState(market)` reads with `address(this)` (RouterStatic itself). Different fee configs by caller. Use execution router identity. |
| `pyIndexCurrentViewYt` name and reuse | Confirmed | `offchain-helpers/router-static/base/ActionMintRedeemStatic.sol:103`; one index, then `assetToSy` (`PYIndex.sol:23–25`) floors; `syToAssetUp` (`PYIndex.sol:31–34`). |
| `MarketMathCore.removeLiquidity` mutates memory state | Confirmed | `core/Market/MarketMathCore.sol:69–78`; pure mutator returning `(netSyToAccount, netPtToAccount)`. |
| Static helpers re-read fresh state between calls | Confirmed | `offchain-helpers/router-static/base/ActionMarketCoreStatic.sol:75,103` `state = _readState(market); // re-read`. Composing static swaps after static burns invalidates the math. |
| `SY.exchangeRate()` units | Confirmed (Grok + Kimi) | `IStandardizedYield.sol:101` returns asset-per-SY WAD, **not** requested-tokenOut. `previewRedeem(tokenOut, shares)` is token-specific (`:153`). |
| Official preview warning | Confirmed (Astra) | Pendle docs (fetched 2026-09-26) explicitly mark SY preview functions best-effort, unaudited, not safe for on-chain reliance. Treat as feasibility gate, not certified infrastructure. |
| Rate scalar extrapolation | Confirmed pattern | `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchangeRateProvider/StandardExchangeRateProviderFacet.sol:55–139` (Kimi line 33). Sample-and-extrapolate with `mulDiv(..., Ceil)` ceiling branch; dec binding; empty-vault initial-rate handling. |

## B. Agreements across all four originals (incl. mine)

1. **v0.20 captures v0.18's owner selections** (1h arithmetic TWAPs; absent-as-above-1; `floor(S0*n/200)`; pre-expansion participation; fee/creator internal shares; interest-token retention + others to dynamic feeTo with retries; minimal-input factory-validated atomic rollover; family approval). Do not reopen. **All four.** Kimi §1, Grok §"Preserve", Astra §"Preserve", mine §"Latest unrelated decisions".
2. **Pre/post-expiry quote procedure is verified** for the helper shape (Kimi §2, Astra §2, Grok table, mine §1). All three peers confirm `MarketMathCore` on a single mutable `MarketState` is the correct view-quote method; composing `swapExactPtForSyStatic`/`swapSyForExactPtStatic` after a separate static burn re-reads state.
3. **`exchangeRate()` ≠ desired tokenOut rate** (all four). `previewRedeem(tokenOut, shares)` is the token-specific path; `exchangeRate()` only directly answers if `assetInfo().assetAddress` is the desired output and decimals match.
4. **`exitPreExpToSy`/`exitPostExpToSy` are state-changing execution helpers** (all four for non-quote use). Owner quote uses MarketMathCore on memory copy, NOT these router functions.
5. **No live SY/sNET address or deployed equivalence verified** (all four). Pin before executable closure.
6. **NET output is no longer interest-only** (all four). PRD §6/R40/R49 conflict with owner input line 20.
7. **USDG SE: HLP pays shares, public swap redeems** (all four). Owner input line 10 explicit.
8. **PLP/YT two-token sub-reserve with V2-style proportional allocation** (all four). Owner input line 12; PRD §7.1:337–344 four-component formula needs replacement.
9. **Companions stale** (all four). Matrix header v0.15; REQUIREMENTS_QUESTIONS v0.12; Universal v0.5 says NetNet compounds.
10. **sNET input settlement is OPEN** (all four). Owner input line 19 explicitly incomplete.

## C. Corrections / dissent

- **C1 (Grok):** Line 13/41 — "Names `exitPreExpToSy` / `exitPostExpToSy` are **not** in this snapshot" — **wrong**. Both exist in `router/ActionMiscV3.sol` at lines 129 and 208. Use for execution only; quotations use the in-memory `MarketMathCore` method (all four peers agree on the latter half).
- **C2 (Kimi):** Line 28 — "did not locate the fee-override mechanism in the inspected static helpers; verify against the deployed router version." This is **partly wrong**: `ActionBase.sol:135` reads `IPMarket(market).readState(address(this))` from the execution router; `ActionMarketAuxStatic.sol:307–308` reads `address(this)` (RouterStatic itself). Different fee configs by caller identity are established. **Engineering gap remains** for the full Pendle market fee-config surface; pin in planning.
- **C3 (mine):** My original said "Whether the live NetNet-deployed SY actually exposes `exchangeRate()`" — confirmed present in the local `IStandardizedYield.sol:101` interface. Verify the deployed bytecode matches; not a re-architect.
- **C4 (Astra line 24):** "the `LimitOrderData` in `ActionMiscV3:129–151,179–185` can change excess execution" — not re-verified by me, but flagged as engineering risk if the executable path is used. Quote path does not touch this; execution path with limit orders needs explicit handling.
- **C5 (Grok line 41):** "Names … are **not** in this snapshot. Do not treat as ABI. Specify `MarketMathCore` quote + `burn`/`swap`/`redeemPY` execution" — the second sentence is correct; the first sentence is wrong (verified above).

## D. Concrete safe PRD wording (for moderator's edit pass)

### D1. Replace P:337–344 (§7.1 four-component proportional formula)

> **Hook-LP book components (Weighted pool process):** HLP backing consists of (1) raw NET-DETF self-leg, (2) raw custom V2 SE **share-token** balance, (3) Pendle SY = held claimed market interest + unclaimed market interest claimable as SY, (4) Pendle LP + held NET-YT as a two-token sub-reserve with internal shares. Proportional HLP exit allocates each leg by `floor(h * X / H)` where X is each leg's attributable balance. Sub-reserve exit uses V2-style proportional allocation between PLP and YT. **Direct HLP withdrawal of leg 2 pays SE shares, not underlying. Direct HLP withdrawal of leg 3 pays SY. PLP/YT leg withdrawal yields SY via the verified pre/post-expiry procedure (§D3).** Liquidity-provisioning legs are distinct from swap-currency legs.

### D2. Replace R03 / §5 with explicit NET vs sNET asymmetry

> **R03:** NET paid in (swap or bond) uses Keep YT into the PLP/YT sub-reserve. USDG paid in (swap or bond) is deposited into the configured custom V2 SE. **sNET input settlement is OPEN** (O:19); do not silently inherit Keep-YT or any other route.

### D3. Add §7.1.x pre/post-expiry stateful quote method

> **Pre-expiry quote (in-memory, single `MarketState`):** call `IPMarket.readTokens()` and validate output against `SY.getTokensOut()`. Read `IPMarket.readState(router)` using the **execution router identity** (not RouterStatic's `address(this)`). Read `IPRouterStatic.pyIndexCurrentViewYt(YT)` once, reuse as `PYIndex`; `assetToSy(index, py) = floor(py*1e18/index)`. Call `MarketMathCore.removeLiquidity(state, lpIn)` to mutate the memory state. Match `min(ptFromLp, ytIn)`, redeem matched PT/YT to SY at the one index. Process overage on post-burn state: PT excess → `swapExactPtForSy`; YT excess → `swapSyForExactPt`, compute `pyRepay = PYIndexLib.syToAssetUp(index, syOwed)`, retain `assetToSy(index, ytOverage − pyRepay)`. Aggregate `syFromLp + syFromRedeem + syFromSwap`; call `redeemSyToTokenStatic(SY, tokenOut, totalSy)` once (or `SY.previewRedeem` for view). SY-output HLP exits skip the final conversion. **Do not use `swapExactPtForSyStatic` / `swapSyForExactPtStatic` after a separate static burn** — they re-read state (`ActionMarketCoreStatic.sol:75,103`) and ignore prior math.
>
> **Post-expiry quote:** remove LP via `removeLiquidityDualSyAndPtStatic(market, lpIn)` or `MarketMathCore.removeLiquidity` on a state copy. `redeemPY` consumes PT (not user YT); use **current** index for `syFromPt = assetToSy(currentIndex, ptFromLp)`. The frozen first-expiry index gives gross SY; the excess over current-index user payout is Pendle treasury interest, not hook backing. If the frozen index is not yet initialized, `redeemPY` initializes it at the then-current index. No expired PT/YT swap (those revert at `MarketMathCore:187,210`).

### D4. Add §4.x SY rate provider shape

> **Reusable SY rate provider:** the existing `StandardExchangeRateProviderFacet.sol:55–139` is the reference pattern (one-whole-subject sample, halve on failure, dec binding, ceiling extrapolation, empty-vault initial rate). For Pendle SY, `SY.exchangeRate()` (`IStandardizedYield.sol:101`) returns the SY's `assetInfo()` asset per SY in WAD — usable directly only if the desired output token equals `assetInfo().assetAddress` and decimals match. For token-specific outputs (e.g., SY → sNET), use `SY.previewRedeem(tokenOut, sample)` with `isValidTokenOut(tokenOut)` validation. **Official SY preview functions are best-effort, unaudited, and not certified for on-chain reliance**; treat the provider as a feasibility gate and verify the deployed SY implementation. Sample is a **valuation convention**, not the whole-position executable payout (PRD §7.1 caveat at line 333). Unclaimed YT `userInterest` is **not** counted by `exchangeRate` or `previewRedeem`; the sNET virtual balance = held SY + claimable SY from a separate YT-interest view.

### D5. Update §6/R40/R49 NET output language

> **R40:** the hook's **sNET** trading leg is unclaimed interest only. Public sNET swaps must never fully drain that interest leg. **R49 (revised):** ordinary public **sNET-out** draws from unclaimed-interest inventory. **NET-out** uses the amount-specific PLP/YT virtual zap-out value per the §7.1.x pre-expiry quote; it is not the SY-interest leg. Distinct interest-leg restrictions apply only to the **sNET** leg. **§6 (revised):** keep sNET non-drainage and no-principal-substitution; remove the same-inventory constraint for NET.

### D6. Preserve HLP ownership separation

> DETF-owned HLP remains only its actual fraction of the shared pool; **liquid DETF acquires no proportional reserve claim** (R42, PRD:354). All HLP transfer-and-redemption accounting must continue to distinguish DETF-as-LP-holder from DETF-as-proxy-coordinator so that burn-side ownership fractions are correctly attributed to the DETF's actual share, not a privileged equity. The DETF may redeem its own hook LP to fund authorized operations under §7.1 but cannot debit other LP holders' component claims. **This is an owner override, not a math proof**; math at the proportional layer cannot reinstate proportional liquid-DETF reserve redemption.

## E. Narrow owner questions (only what cannot be defaulted)

1. **sNET input settlement** (owner input line 19; Grok §Narrow, Kimi §5 Q1, Astra §5, mine O-Incomplete-1). Only the sNET input leg remains; NET and USDG are settled. Candidate destinations (SY interest deposit, Keep-YT, separate route, unsupported) must be owner-chosen.
2. **Unbalanced / subset / single-token HLP exits** under the four-leg structure (Grok §"Genuinely incomplete" 2; Kimi §5 Q4; Astra §5 2; mine O-Incomplete-4). R28/R32 retain Weighted unbalanced modes; PLP/YT sub-reserve proportional was not affirmed for those modes by owner. Either confirm or restrict to proportional-only for the new legs.
3. **NET-DETF confirmation as raw Weighted self-leg** (Grok §"Narrow" 3; mine). Owner input line 20 default, but explicit confirmation prevents drift.

**Confirmatory (do not ask):** v0.20 owner approvals; 1h arithmetic windows; absent-as-above-1; `floor(S0*n/200)`; pre-expansion participation; fee/creator internal shares; interest-token retention + other-reward forwarding with retries; minimal-input atomic rollover; O10 sub-reserve shape (settled); D61/R32 encapsulation via `ownerOnlyLiquidity = false`.

No council consensus claimed. Originals preserved unchanged. Stopping here for the human moderator.
