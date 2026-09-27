# Astra — reserve-matrix bounded cross-review

Read complete Grok, MiniMax M3 and Kimi K3 originals together. No cross-review artifacts read; originals unchanged. Research only; this report is the sole write. No shell, tests, delegation or code/config changes. No independent runtime/provider attestation exposed.

References: O = `docs/research/netnet-reserve-matrix-owner-input.md`; P = `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.20. G/M/K = `docs/research/netnet-reserve-matrix-{grok,minimax,kimi}-original.md`. D = `lib/crane/contracts/protocols/perps/pendle/`. Local sources remain unpinned.

## Agreements and outcome

The originals agree on full PRD reconciliation, separate HLP delivery and swap conversions, the new PLP/YT sub-reserve, incomplete sNET input, and preservation of unrelated owner decisions. I retain Astra's original distinction: **owner selection establishes intended rights, not mathematical conservation, executable quotes or on-chain oracle reliability**. No consensus/security certification follows.

## Verified corrections

**1. Grok's missing-selector claim is false.** G:13,29,41 says these exits do not exist. Direct re-read confirms `exitPreExpToSy` at D`router/ActionMiscV3.sol:129–141`, `exitPostExpToSy` at `:208–215`; `exitPreExpToToken` was directly inspected at `:111`. K:24 is correct. They are state-changing execution methods, not quote functions. M:33–34's uncertainty about vendored MarketMathCore is also resolved by the inspected D`core/Market/MarketMathCore.sol:69–104,153–202`.

**2. Router-specific fees are source fact, not just interface inference.** D`core/Market/v3/PendleMarketV3.sol:276–286` passes the supplied router to `getMarketConfig` and selects an overridden fee. RouterStatic uses its own address in D`offchain-helpers/router-static/base/ActionMarketCoreStatic.sol:573–578`. This closes K:28's local-source gap, but not deployed-version equivalence. Quote for the identity actually calling the market; use one post-burn memory state. Keep my original AMM-only/limit-order-path and zero-LP qualifications.

**3. Post-expiry current-index payout is confirmed.** D`core/YieldContracts/PendleYieldToken.sol:317–355` burns PT, omits YT burning after expiry and pays current-index SY; the first-expiry-index excess is treasury interest. `:373–404` establishes the frozen snapshot and current-index behavior. G:40/K:22's verification gaps therefore do not remain unresolved locally. Historical interest is separate from expired YT principal. The YT-excess ceiling repayment is additionally confirmed by D`router/ActionCallbackV3.sol:104–116`, not merely the owner's proposed arithmetic.

**4. Do not equate accounting exchange rate with deliverable sNET.** K:35 calls `exchangeRate()` an “exact linear rate” when the asset matches; that is at most accounting conversion, not proof of fee-free, unconstrained redemption. D`interfaces/IStandardizedYield.sol:94–101,153–156` distinguishes asset balance conversion from token-specific preview. Normalize raw-unit exchange rates to the project's whole-token WAD convention; matching addresses alone is insufficient. M:48's NET rebasing/scaled-supply prescription is unsupported: inspected `lib/crane/contracts/protocols/pol/net/src/interfaces/INET.sol:6–17` describes NET, while sNET is the rebasing face; this interface supplies no proposed `scaledTotalSupply()` conversion.

**5. Preview reliability is a material omitted qualification.** After Context7-first research, Astra fetched official https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield and https://docs.pendle.finance/pendle-v2-dev/Contracts/UnitAndDecimals on **2026-09-26**. Official SY documentation warns previews are best-effort, unaudited and should not be relied upon on-chain. G/K's sampled-preview proposals need that explicit gate. Owner selection does not remove it; verify the actual SY conversion implementation before using previews to price on-chain issuance/swaps.

**6. A rate scalar is not whole-book realization.** Existing `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:77–124` changes sample size and uses ceiling extrapolation. Neither copying this nor frequent re-reading proves linearity. A reusable SY provider should return a unit conversion; the hook accounts for held plus net-claimable SY. G:56 need not force hook-specific accrued-interest aggregation inside the reusable provider. Keep rate calculation and inventory measurement separate.

M:116's compounded-expansion preservation is stale: O:47 and P:63–77 select linear batch catch-up. M:87,124,141 must not predetermine a “rate-provider-driven” sNET-input settlement while describing it as incomplete. G:96's self-leg confirmation is unnecessary: O:9,20 already selects raw DETF absent a concrete conflict.

## Safe operative PRD wording

> HLP liquidity accounting uses four legs: raw hook-held DETF, raw custom-SE shares, the defined SY balance/claim book, and internal shares representing the joint PLP/YT sub-reserve. HLP exit of the SE leg delivers SE shares without redeeming that SE. Exit of the SY leg delivers SY. Exit of allocated sub-reserve shares realizes their proportional PLP/YT into SY through the appropriate Pendle expiry path. Public USDG swaps separately deposit/redeem the SE; sNET-output swaps redeem eligible SY; NET-output swaps realize the PLP/YT leg. These delivery rules do not themselves define selected-leg HLP pricing or share debit.

> Quote an allocated PLP/YT amount using one coherent market/index snapshot and post-burn memory state; use actual execution fee identity, preserve native rounding/domain failures and convert aggregate SY once if a token output is required. After expiry, ignore YT for principal payout, pay current-index PT redemption and retain historical-interest attribution. This is quote methodology, not permission to spend another HLP holder's allocation.

**Important ambiguity:** “proportional withdrawal including this leg” does not establish whether burning h/H extinguishes all four entitlements, whether omitted legs remain claimable, or whether selected-leg exits use invariant pricing. Do not silently forfeit omitted components, leave duplicate claims, or replace selected Weighted share debit with h/H caps. M:96–97 incorrectly treats Pendle realization as a replacement for Weighted HLP pricing; the two are different layers. Proportional PLP/YT allocation within leg four does not resolve allocation among all four legs.

## Narrow human checkpoint

1. Complete sNET-input settlement and its operation scope. No default to Keep-YT, SY deposit, rejection or another route.
2. Resolve selected-leg/subset HLP debit and treatment of omitted entitlements where the latest proportional language leaves ambiguity; preserve prior modes unless explicitly changed.
3. Approve concrete economic choices after engineering proposes sub-reserve mint/init/imbalance rules and finite-output debit against nonlinear NET valuation. Raw source verification, token binding and existing ownership rights need no vote.
4. Clarify spendability of directly contributed SY and retained same-token incentives if the interest-only rule does not determine it.

Preserve HLP ownership and DETF-owned burn scope; accepted YT-expiry risk is not guaranteed arbitrage liquidation. Preserve all O:47 decisions. No evidence changes my original conservation, preview-reliability or dependency-verification gates. High confidence on local corrections; no executed parity, live deployment or economic proof. Return to moderator and stop.
