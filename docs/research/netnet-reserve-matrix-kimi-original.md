# Kimi K3 — Independent original: NetNet reserve-matrix round (PRD v0.20 vs owner reserve/swap matrices)

- **Date:** 2026-09-25 (environment). **Author:** Kimi K3 (reported metadata `kimi-code-plan-global/k3`, variant high; routing metadata, not provider attestation). No peer originals/cross-reviews read via any tool. Research only: no delegation, shell, tests, code/config/instruction edits. Older reports retained unchanged.
- **Sources read directly:** owner context `docs/research/netnet-reserve-matrix-owner-input.md` (49 lines, treated as owner input, not peer findings); full current `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` **v0.20** (978 lines); CLAUDE.md; agent law; ALIGN D61; local Pendle sources (paths/lines below); existing rate provider `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:55–139`. Context7 `/websites/pendle_finance` queried 2026-09-25 for SY `exchangeRate`/rate-provider semantics — returned only generic SY descriptions (docs.pendle.finance/pendle-v2/ProtocolMechanics/YieldTokenization/SY); local code is the precise evidence. No proprietary source or secrets transmitted.
- **Abbreviations:** P = PRD v0.20; O = owner input file; PC = `lib/crane/contracts/protocols/perps/pendle/`.

## 1. PRD v0.20 state (fact)

The v0.18-era economics contradictions are **already reconciled in the body**: R13/R30 generalized rewards (P:156,173), R52 linear catch-up (P:195), R53 two 3,600 s arithmetic series (P:196), R54 absent-as-above-1 (P:197), R38 synthetic-TWAP branch (P:181), §9.1 linear formula (P:446–467), §13 interest-token retention + non-blocking retries (P:706–718), §14.1 closure register C01–C08 (P:741–758), A40 updated to `1,000→1,015` and batched-10-vs-sequential-5+5.025 (P:803). O:47's "latest unrelated decisions" (1h TWAPs; absent-above-1; `floor(S0*n/200)`; pre-expansion participation; fee/creator internal shares; interest-token retention + others to dynamic feeTo with retries; minimal-input rollover; family approval) are all present in P and must be **preserved**. Companions remain stale: M header still v0.15; Q tracker v0.12; U v0.5 still says NetNet compounds (U:11/19) — sync separately; P:489 already warns Universal policies do not bind NetNet.

## 2. Owner quote procedures — verification against local Pendle source

**Pre-expiry (O:26–35).** All shapes verified:
- `IPMarket.readTokens()` / `readState(router)`: `PC/interfaces/IPMarket.sol:51,57` ✓. `SY.getTokensOut()`: `IStandardizedYield.sol:142` ✓.
- `pyIndexCurrentViewYt(yt)`: `PC/offchain-helpers/router-static/base/ActionMintRedeemStatic.sol:103` ✓.
- `assetToSy(index, py)` floors: `PYIndex.sol:23–25` → `SYUtils.assetToSy` (mulDiv-down) ✓; `syToAssetUp`: `PYIndex.sol:31–34` ✓.
- `MarketMathCore.removeLiquidity(state, lpIn)` — `PC/core/Market/MarketMathCore.sol:69–78`: pure, returns `(netSyToAccount, netPtToAccount)` and mutates the **memory** state copy ✓ (owner step 4).
- `swapExactPtForSy(state, index, exactPtToMarket, blockTime)` returns `netSyToAccount` (:80–91); `swapSyForExactPt(...)` returns `netSyToMarket` (:93–104) ✓ (owner step 6).
- `redeemSyToTokenStatic(SY, tokenOut, netSyIn)`: `ActionMintRedeemStatic.sol:47`; `SY.previewRedeem`: `IStandardizedYield.sol:153` ✓ (owner step 7).
- Owner's warning is correct: `swapExactPtForSyStatic`/`swapSyForExactPtStatic` (`ActionMarketCoreStatic.sol:269,280`) re-read fresh state, so composing them after a separately quoted burn would ignore the burn; the single-mutable-`MarketState`-copy method is the coherent alternative.

**Post-expiry (O:39–41).** `removeLiquidityDualSyAndPtStatic(market, netLpToRemove)`: `ActionMarketCoreStatic.sol:166` ✓. Expired `redeemPY` consuming PT only and the post-expiry index snapshot are consistent with the previously cited YT behavior (`PendleYieldToken.sol:373–394`, recorded P:853); not re-verified line-by-line this pass.

**Leg-4 exit calls (O:12).** `exitPreExpToSy` — `PC/router/ActionMiscV3.sol:129`; `exitPostExpToSy(receiver, market, netPtIn, netLpIn, minSyOut)` — `:208`. Capitalization exactly as the owner wrote; note `exitPostExpToSy` takes **no** `ytIn` ✓ consistent with "ignore ytIn in payout." These are state-changing router functions for execution; quotation uses the in-memory method above.

**YT-excess arithmetic (inference, internally consistent):** `exactPtToAccount = ytOverage`; SY owed = `netSyToMarket`; `pyRepay = syToAssetUp(index, syOwed)` (rounds up = conservative); retained SY = `assetToSy(index, ytOverage − pyRepay)` — matches redeem-PY economics for the matched portion. Needs numeric/fuzz validation in planning, not an owner question.

**Verification residue (fact):** the owner says `readState` should use "the actual execution router identity" because "caller-specific fee overrides may differ from RouterStatic's identity." Local `readState(address router)` exists, but I did not locate the fee-override mechanism in the inspected static helpers; verify against the deployed router version before freezing the quote spec.

## 3. Reusable Pendle SY rate provider — research findings

Local SY surface (`IStandardizedYield.sol`): `exchangeRate()` (:101, asset-per-SY WAD), `previewRedeem(tokenOut, shares)` (:153), `getTokensOut()` (:142). Existing reusable pattern: `StandardExchangeRateProviderFacet.sol:61–139` samples one whole subject token (capped by supply) via a preview, halves on failure, rescues dust by scaling up, extrapolates with `mulDiv(..., Ceil)` (:111–113), normalizes decimals to 18 (:115–124), and publishes an initial rate for empty vaults instead of 0 (:70–75,129–139).

**Findings (facts → inference):**
- If the desired output token is the SY's `assetInfo()` asset (owner's sNET case if SY asset is sNET-denominated): `exchangeRate()` is the exact linear rate; a provider can return it directly with decimal binding. **Preferred** over sampling.
- For token-specific outputs: reuse the existing sampled-preview pattern with `previewRedeem`; standard SY redemption is rate-based and linear in shares, but that is an implementation property, not a standard guarantee — retain the PRD's existing caveat (P:264,333) that sampled rates are not whole-position liquidation values.
- The **NET leg is not rate-provider shaped**: the owner's zap-out quote is amount-specific and stateful (§2). Mapping it into a Weighted per-leg rate is an engineering gate (see §5); do not force it through a linear rate provider silently.
- Native decimals: SY/SY-asset decimals must be verified per market (P:132); the existing provider's decimal-normalization pattern (:79,115–124) is the reusable reference.

## 4. Conflicts to remove from the PRD (reconciliation list for the moderator's edit)

Owner reserve matrix (O:9–14) and swap-pricing matrix (O:18–20) vs current P text:

1. **P:337–344 (§7.1 formula) — replace the L/Y/C/V component set.** New legs: (1) raw NET-DETF self-leg (explicit; currently absent from the formula); (2) raw SE **share-token** leg; (3) SY interest leg (held claimed SY + unclaimed interest claimable as SY); (4) **PLP+YT two-token sub-reserve** with V2-style proportional allocation `(PLP, YT) → sub-reserve shares → HLP allocation`. Separate `L` and `Y` per-component floors are superseded by sub-reserve shares; `C` becomes the SY leg.
2. **P:171 (R28) / P:781 (A18) — proportional component language** must name the new legs (including proportional DETF payout on withdrawals, O:9) and the sub-reserve-share allocation instead of raw PLP/YT payouts.
3. **P:175 (R32) / P:802 (A39) — HLP join asset list.** Add direct **SY deposits** (O:11) and direct **SE-share deposits** (O:10) as HLP join assets; mark **sNET input OPEN** (§5 Q1) rather than listing it as a settled join token.
4. **P:146 (R03) / P:280–281 (§5) — sNET-in via Keep YT is no longer selected** (O:19: sentence ends "sNET in"; "do not … preserve an older conflicting route as a selection"). NET-in → Keep YT remains (O:12). Remove sNET from the settled routing; record it as unresolved.
5. **P:183 (R40) / P:192 (R49) / P:309–311 (§6) / P:790 (A27) — NET-out from interest inventory is superseded.** O:20: "NET output is no longer necessarily the SY-interest leg"; NET virtual balance = zap-out value of the PLP/YT leg via the amount-specific quote. The interest-only/no-principal-substitution restriction now scopes to the **sNET** leg (O:19: claimable SY interest + held SY expressed as sNET); revise R49/§6/A27 accordingly.
6. **P:285 (§5 "USDG withdrawal" row) — conflation to split.** O:10 forbids withdrawing SE underlying on behalf of an HLP withdrawer (proportional direct share payout), while O:18 has public USDG output redeem from the SE under the USDG-targeted rate provider. P must distinguish HLP-exit SE-share payout from public USDG swap redemption.
7. **P:317 (§7 common assets) / P:272 (§4.3 mapping list) / P:348 ("same-economic-leg NET/sNET normalization") — update** to the four-leg structure; the NET/sNET normalization sentence is obsolete.
8. **Quotation procedure (P §§7/11):** add the owner's verified stateful pre/post-expiry quote method (§2) as the specified zap-out quotation, replacing any implication of composing fresh-state static helpers; execution uses `exitPreExpToSy`/`exitPostExpToSy`.
9. **P:399 (§7.4 "Pendle SY deposit" row)** concerns the DETF SY surface (DETF-as-shares) — distinct from new HLP SY deposits (leg 3); reconcile wording so the two SY concepts are not conflated. R22 (P:165) unaffected: SY remains a non-output on standard DETF-out routes.

## 5. Genuinely incomplete economics — necessary questions (no invention)

1. **Q1 — sNET input settlement (owner decision required).** O:19 explicitly leaves it incomplete. Candidate destinations (SY interest leg deposit, Keep-YT, or another) must not be chosen by the council; P's current Keep-YT routing for sNET must be marked OPEN until answered. **This is the only strictly-required owner question.**
2. **Sub-reserve mint/init/rebalance (specification; owner confirmation if economics change).** How sub-reserve shares are minted on PLP/YT deposit, initialized at first deposit, and rebalanced as LP composition/YT coverage change (O:45); how HLP allocation maps to sub-reserve shares. Engineering proposes; owner confirms any valuation-affecting choice.
3. **Whole-position virtual valuation vs finite output realization (engineering gate).** USDG (rate provider), sNET (SY expression) and NET (amount-specific zap-out) virtual balances feed Weighted pricing, but realization is finite-size and state-dependent; reconciling an amount-specific quote with per-leg Weighted rates needs a concrete design with manipulation analysis — escalate only if the chosen design changes pricing economics.
4. **Subset/single-leg allocation vs proportional language (specification).** How unbalanced/subset and single-token HLP exits debit sub-reserve shares versus other legs without unpriced capture (extends existing R28/A18 semantics).
5. **DETF-owned HLP/burn accounting under the new legs (specification).** Owned-book construction for contraction/reinvestment must be restated over legs 1–4 including the sub-reserve (existing R39/§7.2 domain rule unchanged in principle).
6. **Token identity/provenance (engineering verification).** Bind actual SY address vs sNET vs interest vs reward-SY; P:51,710 already require this.

## 6. Facts vs inference; confidence; limits

**Facts:** §1 reconciliation state; §2 call shapes/math at the cited lines; §3 interface lines; §4 text-vs-owner-input diffs; companion staleness. **Inference:** YT-excess arithmetic consistency; rate-provider preference ordering; that §5 items 2–6 are specification rather than owner questions (based on O:45's framing and P:743's no-delegation rule). **Not verified:** deployed router fee-override semantics; frozen first-expiry index behavior line-by-line; live 4663 market/SY identity; any execution, gas or economic-safety property. No consensus claimed; this is one independent pass.
