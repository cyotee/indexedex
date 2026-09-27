# Astra — reserve-matrix independent original

Access date: 2026-09-26 (provided environment date). Research only; no peer reports, shell, tests, delegation, implementation or configuration edits. Only this file written. No independently exposed runtime model/provider identifier; Astra is the assigned label, not provider attestation.

**Sources:** O = `docs/research/netnet-reserve-matrix-owner-input.md`; P = `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md`, **v0.20**, all 978 lines read. Read CLAUDE, skill catalog, canonical Crane architecture/adversarial guidance, local hook-package guidance and current held-reserve law. Local Pendle paths below are relative to `lib/crane/contracts/protocols/perps/pendle/` (D). Sources are unpinned; router/YT files use Solidity `^0.8.17`, MarketMathCore/SYUtils `^0.8.0`. Upstream YT identifies VERSION=6. No deployed Robinhood equivalence is established.

## 1. Verdict and selected accounting

The owner's matrix is coherent as a **custody/entitlement decomposition**, but not yet a complete issuance/pricing specification. Reconcile the entire PRD, not another precedence banner.

O:9–20 selects distinct books:

- HLP: raw DETF; raw custom SE shares; accounted held plus net-claimable SY; internal shares in a PLP/YT sub-reserve.
- Swap pricing: rated SE shares in USDG; rated eligible SY in sNET; amount-specific PLP/YT zap-out in NET; raw DETF.

Direct HLP SE-share withdrawal is not USDG redemption. Direct HLP SY withdrawal is not an sNET swap. PLP/YT component liquidation yields SY and must not also credit the interest leg. DETF-owned HLP remains only its actual fraction of the shared pool; liquid DETF acquires no proportional reserve claim.

## 2. Pendle exit method — verified with qualifications

**Pre-expiry:** owner's stateful-in-memory procedure matches the AMM-only execution path:

- Exact names are `exitPreExpToSy` and `exitPostExpToSy` (lowercase `y`). D`router/ActionMiscV3.sol:129–188` burns LP, matches PT/YT, then swaps only excess PT or YT; `:188` aggregates SY. These functions execute transactions, not view quotations.
- D`core/Market/MarketMathCore.sol:153–176` proportionally floors SY/PT and mutates totalLp/totalPt/totalSy in the passed memory state. Subsequent swap must use that state, not freshly read market reserves.
- `swapExactPtForSy` returns net account SY plus separately reported fees (`:80–104`); do not subtract its fee twice. Excess-YT logic is `swapSyForExactPt`, ceiling PY repayment, then floor remaining PY→SY: D`offchain-helpers/router-static/base/ActionMarketCoreStatic.sol:402–427`; execution callback D`router/ActionCallbackV3.sol:104–116` confirms the two redemption recipients and ceiling repayment.
- One current PY index respects same-block caching and `max(exchangeRate, stored)` (D`offchain-helpers/router-static/base/ActionMintRedeemStatic.sol:103–114`). SYUtils `:7–20` confirms floor conversions and ceiling repayment.
- Caller identity matters: D`core/Market/v3/PendleMarketV3.sol:276–286` fetches router-specific fee configuration. RouterStatic instead reads `readState(address(this))` (D`.../ActionMarketCoreStatic.sol:573–578`). Use the actual market-calling router for execution parity, not an arbitrary address.

**Qualifications:** pin execution to the quoted AMM path; `LimitOrderData` in `ActionMiscV3:129–151,179–185` can change excess execution. A generic router path with limit orders is not automatically covered by this calculation. Skip zero LP removal as execution does: `removeLiquidityCore` rejects zero (`:161`), while exits conditionally burn (`ActionMiscV3:159,228`). Preserve market-domain failures and excess-YT repayment underflow; do not clamp them into a payout. One-index quotation presumes execution does not change the effective index between steps; verify the actual SY/callback behavior. Aggregate only this exit's SY before one token-specific redemption preview; HLP's SY-output exit needs no external token conversion.

**Post-expiry:** verified. D`router/ActionMiscV3.sol:208–240` removes LP and redeems PT, with no YT argument or swap. D`core/YieldContracts/PendleYieldToken.sol:317–355` burns PT, burns YT only before expiry, pays `assetToSy(currentIndex, PT)` and allocates the frozen-index excess to treasury. `:373–404` initializes the first-expiry snapshot and maintains the current index. D`MarketMathCore:187,210` rejects expired trading. Therefore neither frozen-index gross SY nor expired YT face quantity is user payout. Historical interest remains separate.

**Confidence:** high on local mathematical/call correspondence; not an executed parity proof. Retrieved upstream router has additional functions compared with the vendored snapshot—pin revisions rather than citing `main` as an immutable match.

## 3. Reusable SY rate provider

**Recommended design, not an existing verified implementation:** an immutable/configured SY subject, output token, native sample amount, and decimal metadata exposing the project's `IRateProvider.getRate()` whole-output-token-per-whole-SY WAD convention. Validate directional redemption support and token identity; rebinding after rollover must preserve historical-series accounting.

For raw sample `q`, raw preview output `a`, SY decimals `ds`, output decimals `do`:

`rateWad = floor(a * 10^ds * 1e18 / (q * 10^do))`.

Use overflow-safe factorization/mulDiv. Choose and document sample size and rounding; no invented one-token universal minimum. Test zero supply, tiny outputs, caps and nonlinear redemption. A scalar sample extrapolated over holdings is a **valuation convention**, not the whole-position executable payout.

`exchangeRate()` converts SY raw units into its **assetInfo accounting asset**, not necessarily the requested sNET yield/output token. It is usable directly only after proving denomination/conversion equivalence and adjusting native decimals. A token-specific `previewRedeem(sNET,q)` answers the desired direction; RouterStatic's `redeemSyToTokenStatic` merely delegates to it (D`.../ActionMintRedeemStatic.sol:47–52`). RouterStatic adds no accuracy guarantee.

**Material upstream warning:** current official SY documentation explicitly calls previews best-effort, unaudited and unsuitable for reliance on-chain. Thus a generic preview-backed on-chain rate provider is a **feasibility/security gate**, not certified infrastructure. Verify the actual deployed SY implementation and its native conversion source; report incompatibility if it cannot provide reliable on-chain valuation. Do not silently replace selected economics with another oracle.

Existing `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:61–124,148–161` samples SE previews, adjusts sample size and extrapolates with ceiling in one branch. It is a deployment/interface reference, not a drop-in SY adapter; blindly copying its rounding or zero-supply inversion is unwarranted. A filename search found no SY-named rate provider under `contracts/`; this is not an exhaustive absence proof.

Net claimable interest must include pending accrual and subtract native interest fees, not simply copy stored `userInterest.accrued`: D`core/YieldContracts/InterestManagerYT.sol:43–57,63–79`. Reconcile third-party claims and preexisting SY once.

## 4. Complete PRD reconciliation targets

Moderator should rewrite, with O controlling these conflicts:

1. **Architecture/matrices:** P:91–103,146–148,171–175,183,192,200,204–240: replace flat independent PLP/YT legs with the sub-reserve, make raw DETF explicit, distinguish LP and swap currencies, remove unresolved self-leg representation now answered.
2. **Routes:** P:280–295,309–311,496,603,766: remove blanket “all NET/sNET in → Keep YT”; NET remains selected, sNET input is incomplete. Qualify USDG withdrawal as swap settlement, not HLP withdrawal. Explicitly add direct SY and SE-share HLP admission/delivery.
3. **NET outputs:** P:51,91,103,192,309,790 must stop requiring NET-out to use interest only. Preserve independently applicable sNET non-drainage constraints; do not extend them to the principal-backed NET leg.
4. **HLP/accounting:** P:317–352 must replace four independent component formulas with DETF/SE/SY/internal-subshare allocation and nested PLP/YT floors. P:348,802's NET/sNET/USDG-only HLP output model conflicts with direct shares/SY. P:337,781 needs explicit proportional versus subset/single-leg treatment, not silent feature deletion.
5. **Pricing/burn:** P:264–274,325–333,360–390: specify rate versus amount-dependent zap valuation, router identity, pre/post-expiry quotation and actual owned-subshare funding. Never scale a full-pool nonlinear exit quote by an ownership fraction.
6. **Bootstrap/rollover:** P:581–591,603–659: map four-leg initialization, direct SY capital, internal-share retirement/recreation, expired worthless YT and historical claims. Preserve accepted YT-expiry risk; public arbitrage is intended, not guaranteed liquidation.
7. **Closure/tests:** update O04/O06/O09/O10 and C07 (P:729–755), A01–03/A13/A18–20/A26–27/A33–39. Add zero/equal/PT-excess/YT-excess exits, router overrides, current versus frozen expiry index, direct-share delivery, net interest, sample nonlinearity and independent LP ownership. Mark contradictory historical passages explicitly historical; do not retain them as operative requirements.

Clarify that the old “virtual USDG design” exclusion (P:138) forbids unbacked exposure, not the newly selected rate-derived balance. Current held-reserve law (`docs/agent/INDEXEDEX_AGENT_LAW.md:233–241`) separates raw liquidity and rated swaps; document the custom amount-dependent PLP/YT valuation boundary rather than changing generic hooks.

## 5. Necessary unresolved economics and preservation

- Complete **sNET input settlement**, including which operation classes it covers; no inherited Keep-YT default.
- Define subset/single-leg HLP selection versus proportional debit. Within the PLP/YT leg preserve joint allocation; do not infer independent YT withdrawal.
- Specify internal-subshare bootstrap/minting, imbalance handling, rounding, depleted/expired YT and rollover reset. V2-style proportional withdrawal alone does not choose issuance for changing PLP/YT contribution ratios.
- Specify full-position virtual valuation versus finite-size output realization: how much sub-reserve is debited for a quoted NET amount, and who bears nonlinear impact. Whole-book zap failure must have defined effects on unrelated routes.
- Resolve direct SY deposits versus “interest-only” spendability; keep contributed SY, principal-exit SY and interest provenance distinct. Retained same-token incentive spendability remains conditional.

Preserve P:26–79,186,195–198,519–533,597–607,708–718: current TWAPs/absence policy, linear catch-up, pre-expansion participation, recipient shares, retryable forwarding and minimal-input atomic rollover. No approval/window/formula reopening.

## Primary evidence and limits

Context7 first: `/websites/pendle_finance` SY query; returned general SY material, insufficient for exit proof. Primary sources fetched **2026-09-26**:

- https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield
- https://docs.pendle.finance/pendle-v2-dev/Contracts/UnitAndDecimals
- https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/main/contracts/core/YieldContracts/PendleYieldToken.sol
- https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/main/contracts/router/ActionMiscV3.sol

Public documentation has imprecise natural/raw-unit prose; source arithmetic and actual deployed metadata must control normalization. No secrets/source transmitted externally. No live market, deployment hash, gas or economic safety verified. Reconciliation can proceed; executable closure still requires the listed specification/proof obligations. No consensus claim.
