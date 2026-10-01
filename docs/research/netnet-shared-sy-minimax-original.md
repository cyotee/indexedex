# NetNet–Pendle PRD v0.21 → reserve-matrix override — Independent Original (MiniMax M3)

**Reviewer identity and observed metadata.** Prompt identifies me as `minimax/MiniMax-M3`. PRD §17 records prior-session metadata (Astra `openai/gpt-6-astra`, Grok `xai/grok-4.6`, MiniMax `minimax/MiniMax-M3`). Routing metadata, not provider attestation. No secrets transmitted.

**Sources actually read (full current PRD v0.21, 1067 lines, plus supporting code).**
- PRD `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.21.
- `contracts/vaults/basic/BasicVaultRepo.sol` (136 lines) — verified.
- `contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol` (139 lines) — verified.
- `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol` lines 343–810 — verified unbalanced/single-asset helpers exist.
- `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitTarget.sol` lines 8–67 — verified exits.
- `lib/crane/contracts/protocols/perps/pendle/router/ActionMiscV3.sol:111–240` (carry-over), `core/Market/MarketMathCore.sol:69–104` (carry-over).
- CLAUDE, `INDEXEDEX_AGENT_LAW.md` token policy, `DETF_ALIGNMENT_PRD.md` D32–D66 / §24, `DETF_INSTANCE_IO_ROUTING_PRD.md` §16 (prior context only).

**Tool-availability deviation.** Prompt asked for apply_patch; only write/edit/read/glob/grep available. I used `write` after reading the directory listing. No shell, tests, deployment, signing, instruction edit, file deletion/move, browser, MCP, subagent delegation. No peer artifact, prior cross-review, or earlier-round original opened.

---

## 1. Owner clarifications — settled verifications

**C09 answered:** sNET input enters underlying Pendle liquidity via Keep-YT, same as NET input. PRD §5:310 and §7.4:479 still record sNET-input as "unfinished (C09)". **Stale; replace.**

**C10 answered:** HLP unbalanced operations = existing Balancer V3 Weighted unbalanced liquidity logic. **Verified.** `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:343,384,389,414,537,552,571,785,797,810` defines `_joinUnbalancedPairAmounts`, `_joinUnbalancedFlexible`, `_joinSingleAssetExactIn` and `_joinSingleAssetExactInFlexible`. `ExitTarget.sol:8–67` defines `exitProportional`, `exitSingleAssetExactBptIn`, `exitSingleAssetExactTokenOut`, and `Flexible` variants. `IStandardExchangeMultiAssetLiquidity.sol:33–94` is the canonical external surface. **Do not re-derive.** The PRD §7.1:393 reference to "selected-leg/subset share debit and omitted-leg entitlement" should be replaced with a note that these modes reuse the existing Weighted unbalanced logic.

**Raw DETF swap input/output from held balance — explicit.** PRD §6.1:346 already records "actual raw hook-held NET-DETF balance". No PRD change needed for the leg itself, but the new shared-SY output rule interacts with this (see §3 below).

**USDG swap still deposits/redeems SE.** PRD §6.1:347 records this. No change.

## 2. Critical new override — verbatim facts

Owner input explicitly states: NET remains PRICED by PLP/YT joint zap-out valuation (§7.1.2 method), but ordinary NET output comes from SAME held SY reserve as sNET output, NOT liquidation of PLP/YT. The flow is: use held eligible SY first; if insufficient, claim pending interest/rewards, retain SY, forward other tokens to current feeTo (preserve non-blocking forwarding retries), then redeem needed SY to requested token. The hook MUST update held SY reserves using `contracts/vaults/basic/BasicVaultRepo.sol`. The purpose is sell earned interest to grow Pendle principal — nonstandard shared ingress/egress with different pricing coordinates.

**BasicVaultRepo verification (fact, source-verified).** `BasicVaultRepo.sol` exposes:
- `_vaultTokens` (AddressSet) at line 24 — tracked token set.
- `reserveOfToken[token]` mapping at line 27 — locally held balance per token.
- `_reserveOfToken(token)` reader (line 87), `_reserves()` array reader (line 132).
- `_updateReserve(IERC20 token, uint256 newReserve)` writer (line 108).

**Critical limitation (fact, contract comment lines 26–27, 92–97, 102–107):** "This is only to be used for **locally held token reserves**, not for external accounting. For example, if a vault integrates with a DEX, this mapping would be used to store the locally held LP token balance, NOT the owned shares of deployed liquidity reserves in the DEX."

**Implication (inference, not silently invented):** BasicVaultRepo fits the hook's directly held SY balance and USDG SE shares held by the hook. It does NOT fit the PLP/YT sub-reserve: Pendle PLP/YT are external positions held by the hook at the Pendle market, not "locally held" by the hook itself. The sub-reserve internal shares remain separate internal accounting. Using BasicVaultRepo for the sub-reserve would misrepresent the contract's stated scope.

**Reusable SY rate provider (carry-over from prior round).** PRD §4.5 is consistent with the new override; no change. The provider converts SY units; the hook separately aggregates its held/claimable SY inventory through BasicVaultRepo.

## 3. Stale PRD statements requiring replacement

Each row is operative text (not history), verified against current PRD v0.21, and conflicts with the owner's new override.

| Location | Stale text | Replacement (not silently invented) |
|---|---|---|
| §1:91 "NET output realizes the PLP/YT leg; sNET output realizes the separate SY leg; USDG output redeems the SE-share leg" | "NET output uses held SY reserve priced by PLP/YT joint zap-out valuation (§7.1.2); sNET output uses held SY reserve at SY rate; USDG output redeems SE shares. PLP/YT leg is not liquidated for ordinary NET output." |
| §5:310 "sNET input \| **Unfinished owner matrix** … C09" | "sNET input enters underlying Pendle liquidity via Keep-YT, same as NET input. Bond issuance is funded/locked; public HLP entry does not mint user DETF." |
| §6.1:349 "**NET** \| Amount-specific joint zap-out value of the PLP/YT sub-reserve, using §7.1.2 \| NET in uses Keep-YT. NET out realizes an allocated PLP/YT position to SY then NET; not the separate SY-interest leg" | "**NET** \| Amount-specific joint zap-out value of the PLP/YT sub-reserve, using §7.1.2 \| NET in uses Keep-YT. **NET out uses held SY reserve, redeemable via SY preview to the requested token; PLP/YT is not liquidated. The PLP/YT joint zap-out valuation is the pricing coordinate, not the delivery source.**" |
| §6.1:353 "NET output is expressly allowed to realize the PLP/YT leg under its own accounting; the former common NET/sNET interest-only restriction is removed" | "NET output draws from held SY reserve; PLP/YT is not realized. The shared SY output leg backs both sNET and NET public outputs and must prevent double-spend." |
| §7:367 "HLP position-leg exits pay SY; NET swaps additionally redeem aggregate SY to NET. None of this gives liquid DETF holders a proportional HLP claim" | "HLP position-leg exits pay SY. NET swaps use held SY reserve redeemed to NET via SY preview. PLP/YT sub-reserve shares remain the holder's proportional claim, not liquidated by public swap output." |
| §7.3:462 "Income claiming, SE unbuffering, owned HLP redemption and conversions are candidate realization steps; specify the exact sequence before implementation, not an implementer-selected waterfall" | "For NET/sNET public outputs: (1) use held eligible SY first via BasicVaultRepo `_reserveOfToken`; (2) if insufficient, claim pending interest/rewards (move receivable to held SY, not new profit); (3) forward non-SY rewards (PENDLE, USDG) to current `feeTo()` with non-blocking retries; (4) redeem needed SY to requested token via the validated SY preview. Insufficient funded delivery reverts atomically. No PLP/YT liquidation. No invented off-pool treasury." |
| §3 R49:192 "NET pricing/output uses the PLP/YT leg's amount-specific zap-out value and realization (§7.1.2), not the sNET interest leg" | "**R49 (revised):** NET pricing uses the PLP/YT joint zap-out valuation (§7.1.2). NET output draws from the held SY reserve (priced by that valuation, redeemed to the requested token). sNET output uses the same held SY reserve at the SY rate. PLP/YT is not realized for ordinary public output. sNET swap may not consume the other position leg or fully drain the eligible SY reserve." |
| §15 A27:874 "Public NET output realizes the PLP/YT leg; sNET output realizes eligible held/claimable SY" | "**A27 (revised):** Public NET and sNET outputs both draw from the eligible held/claimable SY reserve. Pricing uses the PLP/YT joint zap-out valuation for NET and the SY rate for sNET. No PLP/YT liquidation. No cross-leg misclassification. No double credit of position-exit SY. No principal substitution." |
| §15 A39:886 "Verify direct HLP DETF/SE-share/SY deposits and NET Keep-YT entry into the PLP/YT sub-reserve under selected Weighted processing" | "**A39 (add):** Also verify the shared-SY output debit path — both NET and sNET public outputs debit the same held SY reserve, with claim-to-cash transitions reconciled once and non-SY rewards forwarded to dynamic `feeTo()`." |
| §4.4:289 "The sub-reserve is proportional allocation/accounting, not an additional PLP/YT trading AMM" | Keep this paragraph; add: "BasicVaultRepo updates apply only to the hook's directly held SY (and USDG SE-share) inventory, not to the PLP/YT sub-reserve's external Pendle positions." |
| §14 O09:814 "Owned-book construction … SY/sNET inventory restrictions do not prohibit selected NET position liquidation" | "**O09 (revised):** Owned-book construction for contraction/reinvestment unchanged in principle. SY/sNET inventory restrictions now apply to the **shared** NET/sNET output path: PLP/YT position liquidation is removed from ordinary NET output. Insufficient SY funding path reverts atomically. No separate contraction API." |

**Preserve (do not reopen per owner instruction).** 1h arithmetic hook spot and DETF synthetic TWAPs; absent-as-above-1 policy; `floor(S0*n/200)` catch-up with later-supply bases; pre-expansion participation regardless of deposit age; fee/creator internal-share allocations with established zero-share handling (§10.2); interest-token retention with non-blocking forwarding retries for non-interest reward tokens; minimal-input factory-validated atomic rollover; custom-family approval; 1,000 NET opening; standard-interface contraction with input-side `p`; D61/R32 encapsulation via `ownerOnlyLiquidity = false`; the new four-leg HLP book; the new PLP/YT sub-reserve internal accounting; the existing pre/post-expiry §7.1.2 valuation method (unchanged).

## 4. Engineering gates / real blockers (not owner questions)

**EG1 — Finite liquidity vs virtual price mismatch.** USDG virtual = rate × held SE shares. NET virtual = PLP/YT joint zap-out valuation. Both are *pricing coordinates*, not delivery sources. Real output = held SY redeemed to requested token. The preview/execution pair must demonstrate that the joint PLP/YT valuation does not promise more SY than the held reserve can fund; insufficient delivery reverts atomically. **No double credit** of position-exit SY into the SY leg (PRD §4.4:287 explicit). **Proof obligation.**

**EG2 — Cross-leg swap effect on all books.** A public NET or sNET output debits the held SY reserve. The PLP/YT sub-reserve internal shares and the joint PLP/YT valuation price are not debited by this output (PLP/YT is not liquidated). But a public HLP join with NET inputs through Keep-YT does change the sub-reserve. The two flows must not double-count: PLP/YT valuation price uses §7.1.2; SY output debit uses BasicVaultRepo. **Conservation proof obligation.**

**EG3 — Claim-to-cash transitions / force claims / fee liabilities.** A third-party force-claim of YT interest converts receivable to held SY (move, not new profit); must reconcile once. The output path uses claimed SY before claiming new — the order must be specified. Fee-owned rewards (PENDLE, USDG) forwarded to `feeTo()`; retained interest-token (SY) is not forwarded. Forwarding failure retains the payable for retry, non-blocking. PRD §13 carries this; no double credit of force-claimed amounts. **Engineering gate.**

**EG4 — BasicVaultRepo wiring.** SY token address added to `_vaultTokens` via `_addVaultToken`. After every claim/swap that changes held SY, call `_updateReserve(sy, newBalance)` reflecting actual `balanceOf`. PLP/YT external positions are NOT recorded in BasicVaultRepo (out-of-scope comment). Internal sub-reserve shares are a separate accounting layer. **Engineering gate.**

**EG5 — Sub-reserve mint/init/rebalance / C11.** PLP/YT sub-reserve shares on first mint, unequal contribution ratios, final residual retirement, rollover reinitialization — remain specification work. The new shared-SY output does not affect C11 directly (output does not touch PLP/YT), but conservation across four legs plus the shared-SY output must be demonstrated.

**EG6 — External-note liveness (§12.3).** Unchanged. Engineering gate.

**EG7 — Pendle pin and live deployment equivalence.** Router, YT, market, SY addresses and pragmas unpinned; no deployed Robinhood equivalence verified. Owner override assumes the verified Pendle helper shape (ActionMiscV3, MarketMathCore, pyIndexCurrentViewYt, exchangeRate). Engineering pin required.

**EG8 — Token identity.** SY address vs sNET vs interest vs reward-SY vs NET (rebasing underlying). PRD §2.2/§13 require actual address binding; the new shared-SY output path makes this binding mandatory, not optional.

## 5. Genuine narrow questions vs engineering specification work

**Not owner questions (engineering proposals, owner approves only on entitlement change):**
- Specific BasicVaultRepo wiring sequence (when to add SY token, when to update reserve, ordering with feeTo forward).
- Internal-subshare rounding on shared-SY output (BasicVaultRepo balance delta + PLP/YT valuation delta must reconcile).
- Force-claim reconciliation ordering relative to output debit.
- Specific retry policy on non-blocking forwarding when both NET and sNET outputs are pending.
- TWAP interface selectors, observation storage layout, callback safety — unchanged from prior rounds.

**No genuine remaining owner question is identified.** The user's prompt explicitly resolves C09, C10, raw DETF leg, USDG leg, and the new shared-SY override. All remaining items are engineering specification or feasibility proof. **No new owner approval is required to proceed to planning.**

## 6. Confidence and limits

**High confidence (source-verified):** BasicVaultRepo API and scope limitation; Weighted unbalanced liquidity logic exists; C09 and C10 resolved as stated; PRD v0.21 has the operative text replacements listed in §3.

**Medium confidence:** Conservation across the four-leg HLP book plus shared-SY output is a proof obligation, not a fact. The exact ordering of claim → retain → forward → redeem needs engineering specification.

**Low confidence:** Live NetNet-deployed SY address identity; deployed Pendle router version equivalence; rebasing sNET rate provider behavior; atomic feasibility of the claim-retain-forward-redeem sequence under hostile callbacks.

**Not asserted:** solvency, peg effectiveness, gas, deployed equivalence, security, economic soundness. The shared ingress/egress with different pricing coordinates is an intentionally nonstandard design; it is approved, not validated.

Stop after this single original. Originals preserved unchanged. No council consensus claimed.
