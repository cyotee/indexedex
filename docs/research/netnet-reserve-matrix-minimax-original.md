# NetNet–Pendle PRD v0.20 — Independent Readiness Review (MiniMax M3)

**Reviewer identity and observed metadata.** Prompt identifies me as `minimax/MiniMax-M3`. PRD §17:859–863 records prior-session model metadata (Astra `openai/gpt-6-astra`, Grok `xai/grok-4.6`, MiniMax `minimax/MiniMax-M3`). Routing metadata, not provider attestation. No secrets transmitted.

**Scope.** First of four independent passes in new reserve-matrix round. Owner context read: `docs/research/netnet-reserve-matrix-owner-input.md` (49 lines, moderator-provided, not a peer artifact). PRD read in full: `NETNET_PENDLE_DETF_PRD.md` v0.20 (978 lines). PRD §18:972–977 confirms v0.20 reconciliation against v0.18, including absent-as-above-1 policy, participation timing, recipient weights, and non-blocking forwarding. Earlier reports preserved unchanged. No peer artifact opened. No Context7 MCP available in this session; primary public sources via webfetch.

**Tool-availability deviation (flagged).** Prompt asked for apply_patch; only `write`/`edit`/`read`/`glob`/`grep` available. Used `write` after reading the target directory listing. No shell, tests, deployment, signing, instruction edit, file deletion/move, browser, MCP, subagent delegation.

---

## 1. Owner pre/post-expiry stateful quote method — verification

**Status vs current PRD.** The owner specifies a precise Pendle helper sequence (owner input lines 22–41). The current PRD §7.1 (lines 335–356) records only a generic "Weighted invariant-based calculation, actual HLP debit, fees, rate scaling and net delivery" (line 348) and references `KEEP_YT_ROLLOVER_RESEARCH.md` for Keep-YT entry (`ActionAddRemoveLiqV3.sol:236–303,410–432`). The pre-expiry and post-expiry stateful quote procedure from owner input is **not integrated into the PRD body** for non-proportional HLP exits.

**Pre-expiry procedure (owner input lines 24–35) — verification needs:**
- `IPMarket.readTokens()` discovery and `SY.getTokensOut()` validation.
- `IPMarket.readState(pendleRouter)` with execution-router identity (not RouterStatic's identity, since caller-specific fee overrides differ).
- `IPRouterStatic.pyIndexCurrentViewYt(YT)` once, reused as `PYIndex`. `assetToSy(index, py)` floors `py*1e18/index`.
- `MarketMathCore.removeLiquidity(state, lpIn)` mutating `totalSy/totalPt/totalLp` to post-burn.
- Matched `min(ptFromLp, ytIn)` redeem at one index without market touch.
- Overage: `MarketMathCore.swapExactPtForSy` (PT excess) or `swapSyForExactPt` (YT excess) using the post-burn state, `block.timestamp`, accounting for `pyRepay = PYIndexLib.syToAssetUp(index, syOwed)` and retained SY.
- Aggregate `syFromLp + syFromRedeem + syFromSwap` → single `redeemSyToTokenStatic(SY, tokenOut, totalSy)` or `SY.previewRedeem` once. **SY-output HLP exit does not need the final token conversion.**

This sequence is the source-mapping work the PRD §11.4 implicitly defers (line 659). It is not yet in the PRD body.

**Post-expiry procedure (owner input lines 38–41) — verification needs:**
- `removeLiquidityDualSyAndPtStatic(market, lpIn)` or local `MarketMathCore.removeLiquidity` on state copy.
- Ignore `ytIn` in payout; `redeemPY` consumes PT but does not burn user's YT.
- `syFromPt = assetToSy(currentIndex, ptFromLp)`; gross SY from frozen first-expiry index; excess over current-index is Pendle treasury interest, not hook backing.
- No expired PT/YT swap (those revert).

**Inferred gaps (not silently invented):**
- Exact Pendle helper address exposure (`MarketMathCore`, `IPRouterStatic`, `IPMarket`, `PYIndexLib`) needs pin to a verified local snapshot.
- Whether the existing Crane-vendored Pendle source at `lib/crane/contracts/protocols/perps/pendle/router/ActionAddRemoveLiqV3.sol:236–303,410–432` is sufficient or whether `MarketMathCore` helpers are also vendored.

## 2. SY rate provider research

**Owner requirement (line 19):** "Research/specify a reusable Pendle SY-token Rate Provider."

**Findings.** I fetched https://docs.pendle.finance/pendle-academy/yield-trading-deep-dives/chapter-7-providing-liquidity-while-trading-yield (2026-09-25) confirming: a Pendle pool consists of PT and SY; YT is held outside the pool; the SY token is the yield-bearing wrapper of the underlying. The Pendle SY contract family exposes an `exchangeRate()` view returning the underlying per share.

For the **reusable SY rate provider pattern**, the existing Crane/IndexedEx `StandardExchangeRateProviderFacet.sol:60–139` (cited in PRD E07) samples share-conversion previews and scales the result. Adaptation:
- Take a configured SY address (read from validated market via `IPMarket.readTokens()` / SY `getTokensOut()`).
- Call SY `exchangeRate()` to get the underlying-per-SY rate.
- For rebasing underlying (sNET), the rate changes on each rebase; the provider must read at quote time, not cache.
- Apply the existing three-tier sample / extrapolate semantics, but verify that extrapolation is meaningful for a rate that changes on external rebase events, not just per-block.
- Output should fit the `IRateProvider.getRate() → WAD whole pair tokens per whole share` shape (per `INDEXEDEX_AGENT_LAW.md` §"Uniswap V4 SE buffer hooks" APEX D60 line 237).
- For sNET specifically: `getRate()` returns sNET per SY. To express in NET (rebasing), an additional `INET.totalSupply()` / `INET.scaledTotalSupply()` view is needed; rebasing-vs-static distinction matters.

**Genuine gaps (not silently filled):**
- Whether the live NetNet-deployed SY actually exposes `exchangeRate()` in the version used. PRD E17 cites YT v6/market V7 with `^0.8.17`. The specific SY contract version's surface for `exchangeRate()` versus `previewRedeem` is not verified.
- Whether rebasing underlying requires a `previewRedeem` (for actual redemption tax/fee) vs `exchangeRate` (clean rate) and whether the rate provider should reflect redemption cost or pure rate.
- Whether the same rate provider works for an SY whose underlying is non-rebasing (future hook re-use); the rebasing-normalization is NetNet-specific.

**Recommendation.** Spec author should pin the SY contract address and version, confirm `exchangeRate()` surface from the actual deployed bytecode or verified source, and decide whether rebasing normalization is a separate adapter step or part of the same provider.

## 3. Conflicts to remove from PRD

Per owner input: "full PRD reconciliation, not precedence-only banner; moderator edits it." The v0.20 body still has stale or contradictory text. Each item below is a documented conflict the moderator should reconcile.

**C1 — NET output uses accrued-interest inventory.**
- PRD §6 line 309: "Ordinary public NET-out and sNET-out trades must use the same accrued-interest inventory."
- PRD §6 line 311: "Selected sNET leg: its trading inventory is the hook's unclaimed interest, not the Pendle principal book."
- PRD R40 line 183: "The hook's sNET trading leg is unclaimed interest only."
- PRD R49 line 192: "Ordinary public NET-out and sNET-out trades both draw from unclaimed-interest trading inventory."
- Owner input line 20: "NET output is no longer necessarily the SY-interest leg."
- **Action:** remove the NET-output-from-interest claim. sNET remains interest-only (owner input explicitly says sNET via SY rate provider). NET output is a separate swap path.

**C2 — USDG SE direct share withdrawal rule.**
- Owner input line 10: "Do not withdraw underlying from the SE on behalf of the HLP withdrawing user."
- Current PRD §7.1 line 348: "use the copied Weighted invariant-based calculation, actual HLP debit, fees, rate scaling and net delivery for requested NET/sNET/USDG/NET-DETF outputs" — does not specify direct share withdrawal vs underlying withdrawal for USDG.
- **Action:** add explicit rule that USDG-SE-share HLP exits pay shares, not underlying, except via the public USDG swap route.

**C3 — Pendle LP+YT two-token sub-reserve.**
- Owner input line 12: "`(PLP, YT) -> internal sub-reserve shares -> HLP allocation`."
- Current PRD §7.1 lines 337–344 enumerates four proportional-mode components (Pendle LP, retained YT, accrued interest, USDG SE) but does not specify internal sub-reserve shares for the PLP+YT leg.
- **Action:** add PLP/YT sub-reserve share accounting with Uniswap-V2-style proportional allocation between PLP and YT, distinct from USDG SE share and from raw DETF.

**C4 — Pre/post-expiry quote procedure.**
- Owner input lines 22–41 specify a precise Pendle helper sequence.
- Current PRD §7.1 (lines 335–356) and §11.4 (lines 649–659) do not include this procedure for non-proportional HLP exits.
- **Action:** add a §7.1 sub-section documenting pre-expiry (stateful MarketMathCore over the post-burn state with overage swap and single final SY→output) and post-expiry (no overage swap, current index, frozen first-expiry gross, treasury-interest distinction).

**C5 — sNET input route is incomplete.**
- Owner input line 19: "The owner's sentence literally ends **'sNET in'**; input settlement is incomplete. Do not silently finish it or preserve an older conflicting route as a selection."
- Current PRD §5 line 280: "NET/sNET swap input or bond payment" listed as one combined row; §6/§7 do not detail sNET→reserve-pool swap execution.
- **Action:** flag sNET-input settlement as OPEN, with the owner-required deliverable being an SY-rate-provider-driven sNET virtual-balance input path. Do not invent a route.

**C6 — Pendle SY output semantics.**
- Owner input line 12: SY "held claimed market interest in SY plus unclaimed market interest claimable as SY. Direct SY deposits for HLP are selected. Withdrawals including this leg receive proportional SY."
- Current PRD §4 line 207: "Accrued SY interest / harvested income" — present, but not split into "held" vs "claimable" and not specifying SY output for HLP withdrawal.
- **Action:** add SY-as-output-for-HLP-withdrawal in §7.1 alongside the sub-reserve share accounting.

**C7 — Unbalanced/subset/single-token withdrawal modes vs PLP+YT sub-reserve.**
- Owner input specifies PLP+YT as a two-token sub-reserve with proportional allocation. PRD R28/R32 select unbalanced/subset/single-token modes, and PRD §7.1 line 348 specifies "Weighted invariant-based calculation" for them.
- **Conflict:** the owner's two-token proportional sub-reserve does not directly map to Weighted invariant-based swap; it requires the pre-expiry Pendle helper sequence from C4. Owner input implies the helper sequence is the source of the proportional pricing within the PLP+YT leg.
- **Action:** clarify in §7.1 that PLP+YT exit pricing uses the pre-expiry/post-expiry stateful quote (C4), while other leg combinations use the copied Weighted invariant math.

**C8 — Standard exchange and ERC-4626/SY surfaces.**
- Current PRD §7.4 line 397 maps ERC-4626 / SY / SE surfaces. The owner does not change the surface mapping but adds a new SY-rate-provider step inside sNET routes.
- **Action:** add a clarifying note in §7.4 that sNET-output routes from a SY-rate-provider-priced virtual balance, not from the sNET leg of the hook's inventory.

## 4. Latest unrelated decisions to preserve (per owner line 47)

These must not be reopened. They are reconciled in v0.20 and tracked here for the moderator's edit pass:

- 1-hour arithmetic spot and synthetic TWAPs (PRD §9.2, R52–R54, A44).
- Absent TWAP treated as above-1 (PRD line 41, §9.1 absent branch, A42).
- Linear `floor(S0*n/200)` catch-up with later-supply-bases (PRD §9.1 lines 446–467, R52, A40).
- Pre-expansion participation: funded stake present before expansion participates regardless of age (PRD line 43, §9.3, A41/A42).
- Fee/creator internal-share allocations honoring distribution weights with established zero-share handling (PRD line 43, §10.2 lines 519–533, A41).
- Interest-token retention; other rewards to dynamic `feeTo()` (PRD §13 lines 706–718, A11).
- Non-blocking forwarding retries: failed fee-reward transfers retain token/payable, continue the operation, allow later retry (PRD §13 line 716, A11).
- Minimal-input factory-validated atomic rollover (PRD §11 lines 597–607, C06 line 754, A37/A38).
- Custom-family approval (V18-1 line 22, O01 line 726).
- 1,000 NET opening; 0.5% compounded per eligible processed NET epoch (PRD §1, R52).
- Standard-interface contraction with input-side `p` (PRD §7.2, R27).
- Roving `CLI`/`pgrep` not used; no shell.

## 5. Genuinely incomplete / flag (not silently invent)

Per task: "flag genuinely incomplete sNET input and other necessary economics without silently inventing them."

**O-Incomplete-1 — sNET input settlement.** Owner input line 19. Flagged in C5 above. Open deliverable: sNET→SY rate-provider-driven virtual-balance path. Requires actual NetNet SY contract surface verification (§2 gaps).

**O-Incomplete-2 — PLP/YT sub-reserve share mint/init/rebalance.** Owner input line 12 specifies the shape but not initial supply, rebalance trigger, or accounting for partial YT realization before maturity.

**O-Incomplete-3 — Whole-position virtual valuation vs finite-output realization.** Owner input line 45 lists this as a remaining decision. Current PRD §7 conflates them in places (e.g., §7.1 lines 354–356 explicitly distinguish; §7.2 line 360 implies finite-size quotes). The question is whether the weighted "inventory mark" used for views/quotes equals finite-size execution output, or whether the owner wants a separate virtual valuation layer for some surfaces. Not silently chosen.

**O-Incomplete-4 — Subset/single-leg allocation vs proportional language for PLP+YT.** Owner input line 45 calls this out. Proportional within PLP+YT sub-reserve is set; but how single-token exits from PLP+YT (e.g., "give me NET only") interact with the pre-expiry quote procedure is not specified by owner. Owner selected pre-expiry `redeemSyToTokenStatic` for aggregate SY; single-token direct selection from within PLP+YT is not separately specified.

**O-Incomplete-5 — Independently owned HLP/burn accounting.** Owner input line 45. Current PRD keeps HLP holders and the NET-DETF proxy as distinct accounts; how burn realized funding interacts with public HLP holders' shares is not specified beyond "DETF may redeem its own hook LP to fund an authorized operation" (PRD §7.1 line 354).

**O-Incomplete-6 — Token identity/provenance for incentive receipts that match the retained interest-token.** Owner input line 45; PRD §13 line 712 says "Spendability of those retained incentive receipts by an interest-only swap route requires explicit classification under §14 if that case occurs." Owner confirms the OPEN status.

## 6. Recommendations to moderator (research-only, no execution)

1. Edit the PRD body to remove or replace C1–C8 in §3 above; do not preserve as precedence-banned contradictions.
2. Add a §7.1.x sub-section for the pre/post-expiry stateful quote procedure (owner input lines 22–41), with explicit Pendle helper list, fee identity (execution-router-specific), rounding, and expiry handling. Pin to a verified local source snapshot.
3. Add a §7.5 or §10.x for the SY rate provider (owner input line 19), distinguishing `exchangeRate()` (pure rate) from `previewRedeem` (with redemption cost). Decide whether rebasing normalization is an adapter step.
4. Add explicit sNET-input deliverable to §14.1 register as a specification obligation, not an OPEN owner question.
5. Update the §14.1 closure register to add C09 (SY rate provider), C10 (pre/post-expiry stateful quote), C11 (sNET-input settlement), C12 (PLP/YT sub-reserve shares), C13 (subset/single-leg PLP+YT exit), C14 (independent HLP/burn accounting), C15 (incentive-receipt provenance when addresses coincide).
6. Confirm owner §6.3 acceptance tests expand to cover: rebasing-underlying rate provider, rebasing vs static SY distinction, owner pre/post-expiry quote correctness including fee override identity, pre-expansion participation, absent-as-above-1, non-blocking fee forwarding, minimal-input rollover.

## 7. Confidence and limits

**High confidence:** v0.20 reconciliation captured owner selections on TWAPs, catch-up, participation, rewards, rollover. Body text has internal contradictions with owner input on NET/sNET routing and on the missing pre/post-expiry quote procedure.

**Medium confidence:** the existing Crane-vendored Pendle source covers the helper calls named by the owner; not all were re-opened in this pass. `MarketMathCore` and `IPRouterStatic` need a pin.

**Low confidence:** NetNet-deployed SY contract surface for `exchangeRate()` versus `previewRedeem`; rebasing-normalization interaction with the rate provider; live `BOND_VEST` (2-day) vs interface prose (5-day).

**Not asserted:** solvency, peg effectiveness, gas, deployed equivalence, security, economic soundness.

Stop after this single original; no council consensus claimed. Originals preserved unchanged.
