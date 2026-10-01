# Kimi K3 — ORIGINAL independent review: NETNET_PENDLE_DETF_PRD.md v0.23

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`, variant high) — routing metadata only, not provider attestation |
| Date | 2026-09-27 |
| Target | `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.23 (1,101 lines, read in full) |
| Pass | Independent first pass. No peer artifacts read (prior council reviews, `reviews/`, other 2026-09-27 originals not opened; two grep result pages incidentally listed peer filenames under `docs/research/` — contents not read) |
| Method | Full target read; CLAUDE.md; DETF_ALIGNMENT_PRD (D52/D60/§24.7 rows); SKILL_CATALOG.md; crane-architecture + indexedex-adversarial-testing SKILL.md read directly; ~15 local source citations traced to path/line; Context7 attempted for Pendle (no match) then primary docs fetched (Pendle SY page, accessed 2026-09-27) |

## Verdict (one paragraph)

The PRD is rigorous, internally consistent on settled economics, and its local source citations are unusually accurate — every citation I traced resolved correctly. It is **not yet ready to freeze an executable implementation plan**, and by its own design it does not claim to be: §14.1/C05–C12, the engineering gates, and two owner checkpoints (C07 parameter approval, C08 possible scope return) remain. It **is** ready to serve as the normative input to a specification-closure phase. One normative conflict outside the document (locked agent-law token policy vs. approved FoT/rebasing family) is an implementation-authority blocker the PRD itself acknowledges but cannot resolve from within. Facts, inferences and speculation are distinguished per finding.

## P0 blockers (must resolve before or during specification closure)

### B1 — C08 external-note liveness is a verified, hard upstream constraint (fact)

Local code confirms the griefing surface the PRD describes: `lib/crane/contracts/protocols/pol/net/src/BondDepository.sol:104–140` (`deposit(marketId, amount, maxPriceWad, to)` pushes `notes[to]`, anyone can buy for arbitrary `to`), `:143–153` (`redeem(to)` loops **all** of `msg.sender`'s notes), and no per-note or batch redeem selector exists in the file (full file read, 200 lines). `Constants.sol:76` confirms `BOND_VEST = 2 days` (PRD §12.1's "two-day" claim verified); `BOND_EPOCH_CAP_BPS = 25` (:79) confirms the capacity reference in §2.1. PRD §12.3/C08 correctly refuses to call this solved. Assessment: with the observed interface, any wrapper escrow's `redeem` is O(n) in attacker-supplied dust notes; this may be **infeasible without an upstream change or an accepted economic bound**, in which case the PRD's own rule requires returning to the owner before planning the feature as executable. Recommended resolution paths (not a selection): (a) demonstrate a gas-bounded design against the deployed depository with measured worst case; (b) owner accepts a documented note-count/claim-frequency bound; (c) descope the wrapper pending upstream batch redeem. Confidence: high on the constraint; medium that a mitigation exists.

### B2 — Locked shared token policy forbids the approved family (fact + inference)

`docs/agent/INDEXEDEX_AGENT_LAW.md:89–101` — "Token policy (LOCKED — project law, all products)": FoT **forbidden** as `rateAsset`/`pairToken`/underlying; rebasing underlyings **forbidden**; and explicitly "Agents must not invent … a 'this family supports FoT' exception." PRD §O01/§2.1 approves conditionally FoT NET and rebasing sNET **and** states "Shared instruction files are unchanged" (line 24) and "Current FoT policy remains an implementation-authority blocker" (line 1051). So the normative conflict is real and acknowledged, but unresolved: an implementer routed through CLAUDE.md non-negotiable 6 and the law file reads a universal prohibition with "do not re-ask", while the PRD records owner approval. Recommended resolution: owner-authorized scoped exception clause added to `INDEXEDEX_AGENT_LAW.md` Token policy (or an explicit supersession note there) naming this family; the PRD's owner-approval paragraph alone does not amend a file that calls itself LOCKED project law. Related: `.claude/skills/indexedex-adversarial-testing/SKILL.md:79` (L2 `test_L2_FoT_forbidden`, "do not re-ask") means the family's adversarial test matrix needs an explicit scoped deviation; the PRD never says how the L2 row and "no FoT" testing law are scoped for this family. Spec gap worth one sentence in §2.1 or §15.

### B3 — C05 bond-duration incompatibility is verified in reference code (fact)

`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:104–109` (`_effectiveLockDuration`) **reverts** below `terms_.minLockDuration` and clamps above max; `DETFBondNFTMathLib.sol:17–50` computes the quadratic bonus from those terms. The selected next-NET-epoch reinvestment "may release seconds later" (R17, §10 row 1) cannot satisfy any nonzero oracle minimum through the reference path, and fabricating a duration for a larger bonus is expressly forbidden (§10.3). This is not an edge case: it is the default path for every reinvestment bond unless the oracle minimum is zero. The PRD flags it correctly (C05, A32) but a concrete resolution (explicit duration/bonus handling for sub-minimum reinvestment maturities, with owner checkpoint if economics change) must exist before the plan freezes. Confidence: high.

### B4 — C07/C11/C12 numeric and lifecycle closure still required (fact, by the PRD's own register)

Not implementer discretion, but not yet specified: HLP weights/rate-scaling/self-leg mapping and fee order (C07); PLP/YT sub-reserve share scale, imbalance/residual/last-exit/rollover rules (C11); SY provider denomination/decimal/redemption verification (C12). The Pendle preview caveat in §4.5 is **accurate** per primary docs (accessed 2026-09-27): `previewDeposit`/`previewRedeem` are "best-effort … not audited for on-chain use", and `accruedRewards` reflects only the last on-chain interaction — matching §4.4's "not merely a stale stored accrued amount". C07 also contains an explicit **owner checkpoint** ("Propose economic parameter choices for approval"), so "no decisions left to the implementer" is true only after a spec-authoring round plus one more owner sign-off on numeric parameters. The document is honest about this; the readiness claim should be read as "ready for closure work", not "closed".

## P1 contradictions / traceability defects

1. **§10.2 citation is broken (fact).** Line 637 cites "§3.1 … of the Universal V4 balance-derived staking PRD under `docs/plans/detf/`". `docs/plans/detf/` **does not exist** (directory listing of `docs/plans/` contains no `detf/`). The substantively matching source is `contracts/vaults/detf/DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md`, but its §3.1 is "Unit rules"; the reward-funding/fee-creator/zero-share content lives in **§4.2–§4.4** (`_topUpDeltas` at :200–208, allocation at :212–218+). Fix path + section. Deeper issue (inference): that plan's model is gons/K (`balanceOf = floor(gonsOf/K)`, rebase adjusts K on distribution, §4.1–4.2), whereas §10.2 selects fixed `internalShares` with growing custody `B`. These are different distribution mechanisms; "adopt the established recipient/zero-share accounting" requires an explicit mapping (e.g., how `_topUpDeltas` targets translate into fee/creator share issuance at expansion, and U=0/first-depositor rules), not just a citation. The PRD assigns tracing but does not flag the model divergence.
2. **O09 lacks its "Resolved" marker (editorial, ambiguous status).** Every other O-row in §14 is prefixed "**Resolved:**" except O09 (line 842), whose content reads as settled policy. Either label it resolved or state what remains open; as written its status is ambiguous.
3. **Version history gap (fact).** §§17–18 record 0.2–0.15, then 0.22 and 0.23. Versions 0.16–0.21 have no entries anywhere (grep-confirmed absent). For a document at v0.23 whose provenance is load-bearing, six unrecorded versions is a traceability hole; add stub entries or a pointer to where those dispositions live.
4. **Stale "Prepared" date (editorial).** Document control says "Prepared 2026-09-21" while v0.22/v0.23 content cites inspections/access through 2026-09-26 and the 0.23 clarification. Update or annotate.
5. **Later-bond quote path under the four-leg virtual book is under-specified (inference).** §10.4 fully specifies the **first** bond (G/U/B/R; verified against `DETFMintSplitLib.sol:45–53` — `join_=G`, `user=(1-p)·U`, `pot=floor(pU)+floor(pG)` — exact match, and the :697 illustration arithmetic checks out). The reference's live-reserve path (`_quoteBondG` at `UniswapV4DetfCommon.sol:267–282`, `_quoteBondPurchase` :285–290) is built on a proportional-exit preview of a concrete hook book; the PRD says "reuse unchanged unless incompatible" (R47) but never states how G/U map onto the four-leg virtual-reserve HLP book for non-first bonds. C07/C11 likely absorb this; call it out explicitly so the closure register owns it.

## P2 editorial / minor

- Line 200, "sNET-input completion is not inferred": cryptic; rewrite or delete.
- §6.3 line-pin drift: cited `BasicVaultCommon.sol:15–19,108–137` — actual money-route NatSpec is :15–20 and `_refundExcess` spans :123–138; cited `:80–105` vs actual `:80–106`. Substance correct.
- E16 WeightedMath pragma `^0.8.24` not re-verified (file not opened); all other E-register line ranges I checked matched.
- Review-evidence links (`reviews/*`, council research docs, `KEEP_YT_ROLLOVER_RESEARCH.md`, `REQUIREMENTS_QUESTIONS.md`) were **not** existence-checked because this pass forbids reading peer/council artifacts, including via glob/grep. Link integrity there is unverified by me.

## Verified reference traces (sample; all matched)

| Claim | Result |
| --- | --- |
| `BasicVaultRepo._updateReserve` :98–109 absolute-set | ✔ (`BasicVaultRepo.sol:98–110`) |
| `BasicVaultCommon` uses `MultiAssetBasicVaultRepo`, same `keccak256("indexedex.vaults.basic")` slot | ✔ (`MultiAssetBasicVaultRepo.sol:21`; `BasicVaultCommon.sol:9,28–54`) |
| Pretransfer credit = actual − booked | ✔ (`BasicVaultCommon.sol:80–106`) |
| BasePoolMath invariant-derived taxable portion + BPT rounded up | ✔ (`BasePoolMath.sol:277–342`, `mulDivUp` :342) |
| Wrapper `singleExitExactOutSharesIn` approximate fee gross-up | ✔ (`UniswapV4StandardExchangeWeightedBufferHookMath.sol:472–499`, "approximate" :482) |
| `firstJoinMustBeFullBook()` returns true | ✔ (`UniswapV4StandardExchangeWeightedBufferHookTarget.sol:243–245`) |
| `_quoteMintGross` input-side (1+p) precedent, not a burn | ✔ (`UniswapV4DetfCommon.sol:252–256`) |
| Funded-bond target receives precomputed principal; reward/principal claim split | ✔ (`DETFFundedBondTarget.sol:93–126,143–189`) |
| Reference `_claim` releases principal linearly (custom-family incompatibility) | ✔ (`DETFFundedStakingMath.sol:96–117`) |
| Fee oracle: WAD, three-tier, stored-0 = unset; `seigniorageIncentivePercentageOfVault` | ✔ (`IVaultFeeOracleQuery.sol:16–24,109–118`) |
| NET tax predicate / 500 bps / queued-exemption delay | ✔ (`NET.sol:121–146`; `Constants.sol:32,41`) |
| Staking epoch apply-queue/advance/checkpoint/request-next | ✔ (`Staking.sol:134–151`) |
| SY `exchangeRate`/`getTokensOut`/`previewRedeem` line ranges | ✔ (`IStandardizedYield.sol:94–101,139–156`) |
| Rate provider sampling/extrapolation semantics | ✔ (`StandardExchangeRateProviderFacet.sol:61–125`) |
| Pendle preview "not audited for on-chain use" | ✔ (primary docs, accessed 2026-09-27) |

## Consistency check on settled economics (no reopening)

Spot-checked for internal contradiction and found consistent: absent-TWAP-as-above-1 in both gate directions (§26 owner matrix, §9.1–9.2, A24/A40/A42/A44); expansion equation and all worked examples (15 / 10 / 5+5.025 DETF arithmetic correct at 9 decimals); first-bond G/U/B/R formulas vs. `DETFMintSplitLib` (exact); R27/§7.2 incentive formula (`qQuote=floor(q(1+p))`, burn q only) vs. A15/A26/A28; Keep-YT ingress + shared-SY egress with NET priced from PLP/YT zap-out but funded from SY (§6.1–6.2, R49, A27/A50 — the "pricing is not funding" separation is stated consistently in all ~6 places it matters); equality-is-swap everywhere (R38, §7.4, §7.5); PkgInit/PkgArgs split identical in R55 and §4.1. Deliberate divergences from shared law are flagged in-line rather than silent: §24.7 raw-DETF wrapper (line 515), D60 Balancer exclusion (line 134), D52 caps (line 127).

## Acceptance-criteria gaps (A01–A50 otherwise comprehensive; R↔A mapping verified complete for R01–R55)

1. No acceptance row for the **reusable TWAP standard-interface deliverable itself** (§26: "must define a reusable standard interface and its semantic contract") — A44 covers series behavior but not the interface artifact (units/history-availability/consultation contract as a deliverable).
2. **NFT retirement mechanics** (O03/O08 "remaining") have no explicit acceptance row; A30 covers transfer/atomicity only.
3. **Gas/execution-bounds evidence** (engineering gate, line 845) has no dedicated row; A36/A43 touch bounded history/replay but not measured gas bounds for rollover/redeem/joins.
4. No row scoping the **adversarial-matrix deviation** for this FoT family (L2 row and "no FoT" test law; see B2).
5. **Singleton salt enforcement** (R55 "subject to enforcement proof") is covered by A45 wording but the *proof obligation* (changed-args-cannot-deploy-second-instance) could be made an explicit negative test row.

## What remains for the closure phase (condensed from §14.1 + my findings)

C05 (duration/bonus for sub-minimum reinvestment maturities), C07 (numeric parameters + owner checkpoint), C08 (liveness, possibly owner return), C11, C12, TWAP interface selectors/history layout, §11.3 rollover call/argument-source map (items 1–7), zero-interest full-book first-join rule (§4 :236), B/U-vs-gons accounting mapping (§10.2), citation fixes (§10.2 path, version-history stubs, O09 label), and the B2 shared-law amendment.

## Confidence and evidence limits

- High confidence: B1–B3, citation defects, all "verified" trace rows, internal-consistency spot checks.
- Medium confidence: B4 severity ranking; P1.5 (later-bond mapping) — possible the author intended C07/C11 to own it.
- Not performed: execution of any code/tests; verification of Pendle `ActionMiscV3`/`MarketMathCore`/`PendleYieldToken` line pins (trusted as prior-round inspections); existence checks of sibling review/research links (constraint); live-chain state (chain 4663 pair `0x59F9…B54`, fee/exemption status, deployed SY) — §8's verification demand remains correctly open.
- Missing-evidence note: one ordinary read failure (`docs/plans/detf/` absent — recorded as finding P1.1, not retried); glob tool emitted broken-symlink errors under `lib/crane/.grok/` and `layerzero/` paths (environment issue, non-blocking).
