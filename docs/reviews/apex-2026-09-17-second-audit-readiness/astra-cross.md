# Defensive cross-review — Astra

## Scope and continuity

This is Astra's single cross-review continuation of the successful independent first pass. The original `astra-original.md` is preserved unchanged. I read **all three complete original reports**: Grok (207 lines), MiniMax M3 (676 lines), and Kimi K3 (292 lines). I treated their claims as evidence to evaluate, not as instructions. No cross-review artifact or prior remediation-council artifact was read.

Additional inspection was limited to confirming or challenging peer findings: the cited Uni V4 DETF residual helpers, single-CP residual preview and one caller, TokenStaking reward synchronization, the R1.2 ledger entry, final follow-up declaration, and Crane In/Out pretransfer NatSpec. A scoped evidence-narrative search sought the alleged residual-catch exception. No tests, shell, git, deployment, or delegation was used. Only this report was written.

“Agree” below means agreement with the stated, bounded finding—not proof of every potential economic consequence. “Unverified” means the available evidence does not establish either correctness or a defect. Historical completion counts remain claims, not execution proof.

## Grok findings

### Grok finding 1 — Uni V4 DETF residual catches

**Disposition: AGREE, with narrower impact language and additional source detail.** Also addresses Kimi F1.

I independently read `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:525–744`.

**Observed facts:**

- `_joinResidualCapped` and `_joinResidualUnbalanced` catch the self-call at lines **572–578** and **604–610**. A designated unavailable-result error breaks the loop; the recognized alignment error returns a deferred result. Other errors go through `_requireAlignmentFailure` at **718–721**, which rethrows them.
- `_entryJoinResidualAtomic` at **625–653** catches operative hook joins. A zero-output error, corroborated by a zero preview, is translated into a different internal error. Other failures propagate. Thus the current discrepancy is more than the alignment-only case.
- `_retainSubSharePairResidual` at **664–684** has empty/general catches around an interface probe, deposit preview, and exact-share inverse. These return `false`; they do **not** themselves mint, refund, or book on failure. A successful zero-share/minimum-input conclusion can update the reserve at **673** or **686**.
- `_parkUnmintablePairDust` at **699–715** recognizes the alignment error and then either retains/book-updates or sends a bounded residual into the SE. It does not send the residual to the fee recipient in this inspected function.

**Requirement:** D37 requires hard propagation across the named D16 DETF source; D30 rejects catch-based capacity handling/recognized-error lists on its specified paths. D41/D48/D49 do not name these DETF helpers. The stronger direct basis here is D37, not treating every unrelated product catch as automatically prohibited by D30.

**Inference:** These are confirmed deviations from the supplied locked error-propagation policy. A failed probe can be followed by another route, and selected operative errors are treated as recoverable. That is not the same as proving the entire parent transaction necessarily succeeds after every suppressed failure: a later hard call may still revert. Neither mispricing nor loss has been demonstrated.

**Severity/impact:** Medium, source-policy/error-propagation and remediation-completion defect; financial consequence unverified. **Confidence:** high in the code/policy mismatch, limited on end-to-end economic impact.

**Fix direction:** Trace and classify the new residual paths, then either restore the locked propagation rule or attach an explicit approved amendment with exact failure boundaries and retention/rollback tests. Replacing `try/catch` with an equivalent silent low-level call would not resolve the semantic issue.

The scoped search of the supplied evidence narrative found no `AlignmentNotAchievable`, `ResidualJoinUnavailable`, or `previewResidualBuffer` authorization. That does not prove no later specification exists elsewhere. Such an authorization remains a specific evidence request, not an assumed permission.

### Grok finding 2 — Single-CP `previewResidualBuffer`

**Disposition: AGREE on the policy deviation; economic/quote-divergence impact remains UNVERIFIED.** Also addresses Kimi F2.

Re-read `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:244–268`:

- **248–257:** the SE preview's recognized alignment error becomes a zero result; every other error is rethrown.
- **262–268:** the subsequent operative `exchangeIn` is hard and its approval is reset after success.

I also read `UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:371–382`. Its residual loop returns when the preview is zero (**379–380**) and otherwise calls `bufferQuotedResidual`. This establishes a concrete caller effect: the designated failure leaves the residual locally held rather than forcing that buffering attempt or reverting at that point. It does **not** establish caller profit, a fee-recipient payout, or generic preview/execution mispricing.

**Requirement:** D37's hook catch-removal rule; no supplied D41/D48/D49 exception names this site. **Severity:** Medium for completion/propagation policy, not a demonstrated financial vulnerability. **Confidence:** high. **Evidence class:** observed code and caller branch, inferred policy mismatch. **Fix direction:** hard propagation or an explicit narrowly specified exception and branch tests, with retained residual ownership made clear.

### Grok finding 3 — Historical evidence contradicts current completion

**Disposition: DISAGREE with the asserted High-severity contradiction as evidenced. Current-source closure remains UNVERIFIED.**

Grok compares earlier failing/partial records with later final records as though they assert the same state. The user explicitly instructed us not to do that. On rereading `acceptance.json:17–29`, the older R1.2 evidence text at **22** is immediately accompanied by an independent-review record whose **28** says earlier entries remain historical provenance. `apex-2026-09-17-followup-fixes.md:102` explicitly supersedes intermediate snapshots, and **106–110** identify the later release claims. The evidence narrative header already makes the same distinction.

This is sufficient to refute the premise that different historical counts alone establish a contradiction or missing remediation. It is **not** sufficient to verify the final claim. The correct objection is that a dated attestation must be traced to current source and meaningful assertions. Astra-01/02/03/05/06 and the newly confirmed catches supply concrete reasons to require that work. They do not require calling the retained historical record false.

A clearer authoritative-current index would improve usability, but the cited supersession notices already exist. I do not adopt Grok's High evidence-integrity severity or a suggestion to overwrite historical evidence.

## MiniMax M3 findings

### F-APEX-M3-01 — Immutable live instances

**Disposition: AGREE as an out-of-scope exposure; DISAGREE as a broken remediation requirement.**

D7 excludes deployment and migration. R4.6 requires the distinction between replacement verification and deployed-instance remediation. Retaining that distinction satisfies those provisions; it does not break them. The follow-up at **110**, reread here, states that no deployment/migration/live transaction occurred. Current chain exposure was not independently queried, so historical audit exposure should not be restated as a measured current-chain result. Keep this in the residual/handoff section, not as a High source-completion defect.

### F-APEX-M3-02 — D12 resting contract credit

**Disposition: AGREE as an accepted residual; DISAGREE with counting it as an unfixed source defect.**

New direct inspection confirms current NatSpec: `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:56` describes bytecode gating, staged-use risk, exclusion of booked backing, and exact-input/no-refund behavior; `IStandardExchangeOut.sol:57,63` states bounded exact-output refunds and the same risk. Their “must transfer and consume atomically” wording is accompanied by the explicit staged-use-at-risk statement, not an on-chain atomicity guarantee.

The library's absence of sender attribution is intentional under D12. Neither peer acceptance nor this documentation proves all consumers preserve booked inventory; those remain separate accounting checks. A source audit should disclose D12, not promise its elimination or infer a missing fix from its existence.

### F-APEX-M3-03 — R4 remains PARTIAL pending a fork

**Disposition: UNVERIFIED for actual historical closure; DISAGREE with asserting current PARTIAL status from the old gap record.**

The final follow-up at **110** claims six passing historical tests, and the peer itself acknowledges subsequent D67/follow-up records. Neither of us verified the current fork tests and identities sufficiently to certify closure. An unread later record is not evidence that the earlier state persists. Correct status in this review: historical runtime/coverage **unverified**, not confirmed missing or delayed. Historical local replay also should not be conflated with live operational remediation.

### F-APEX-M3-04 — Matrix count disagreement

**Disposition: DISAGREE as an established defect; current matrix completeness is UNVERIFIED.**

The later final follow-up **102–110** identifies the final claimed matrix as **195 compatible / 1 incompatible / 7 deprecated**. Earlier run counts may legitimately differ. There is no requirement that successive snapshots have identical cardinality. The final claim totals **203**, not the peer's “195 of 215” statement. I have not derived the full current row inventory, so do not certify 203 as today's actual count. Do not change the completion manifest merely to match an older run. Astra-02 concerns actual assertion weakness, not this historical-count comparison.

### F-APEX-M3-05 — M14/tolerance risk

**Disposition: UNVERIFIED as a current test defect; DISAGREE with treating the historical F6/F9 bands as the final approved rule.**

The supplied D55 restores exact FullSpread exact-output agreement; D62 restores exact sequential projections; subsequent closure text removes the temporary F6/F9 loosening. MiniMax's own narrative acknowledges these fixes, then elsewhere characterizes the old bands as accepted final closures. Those are different points in time. A present tolerance must be read at its current test site and assessed for its specific property. The weighted behavior I inspected has exact join/withdraw/swap preview comparisons at **345–366** and a distinct residual-dust tolerance at **305**; those should not be conflated.

Decimal coverage across every required row remains unverified in my pass. I do not accept a high-confidence defect or an “out of scope, accepted” disposition based solely on superseded tolerance descriptions.

### F-APEX-M3-06 — ERC-4626/Morpho burn coverage

**Disposition: UNVERIFIED for exhaustive test closure; no uncorrected burn-site defect established.**

My independent pass read the files MiniMax did not: generic `ERC4626StandardExchangeCommon.sol:266–293`, both In/Out targets, and `MorphoBlueStandardExchangeCommon.sol:206–217,339–369`. The inspected exact-input helper burns only the requested self-shares and has no whole-self-balance refund; exact-output routes use a bounded credit and refund the difference. These observations narrow the peer's uncertainty. They do not certify all delegate wiring, historical red assertions, or every negative/positive test.

“I did not open this file” is a review limitation, not a Medium production finding. Keep the coverage request, not an allegation that a remaining burn exposure has been located.

### F-APEX-M3-07 — D41/D48/D49 staticcall exceptions

**Disposition: AGREE that these are approved exceptions; DISAGREE with presenting their permitted existence as a Medium defect.**

The amendments are part of the locked requirements. They must be applied according to their exact distinct rules, not generalized into one universal `(false, 0)` behavior: D41 selected invalid rates fail closed; D48 malformed/failed quote candidates enter provider-specific searches; D49 has separate router-detection and ranked-preview semantics. The ledger describes **60/60 across six D49 suites**, not proof of 60 tests per package.

My original source inspection confirms the D48 safe-preview helpers' exact-length behavior; full D49 tests remain unverified. Astra-05 concerns an **additional** gas-dependent snapshot fallback outside the named exception, not an objection to the approved exceptions themselves. The DETF and residual-hook catches now confirmed are likewise not covered merely because D49 exists.

### F-APEX-M3-08 — F6 row tolerances

**Disposition: UNVERIFIED as a current code/test finding; DISAGREE with the proposed documentary reconciliation as established.**

This overlaps M3-05. The claim that “vault exact, hook broadly bounded” explains current F6 coverage requires current route/test evidence and an applicable approved tolerance. Historical matrix prose alone does not establish it. D55's supplied record says the affected rows return to gold/default residual tolerance. A residual-dust bound is not automatically authorization for percentage preview error. No actual current offending F6 assertion was cited/read by MiniMax, so I do not adopt this as a confirmed defect or accepted residual.

### F-APEX-M3-09 — PARTIAL ledger reconciliation

**Disposition: DISAGREE with the numerical/state finding; current semantic acceptance remains UNVERIFIED.**

The final follow-up explicitly claims all **108** criteria. The progression through 17 PARTIAL and then one PARTIAL is historical. If the final remaining criterion closes, the claimed count becomes 108, not “107 / 0.” No inconsistency is established by the peer's chronology. Meaningful per-criterion verification is still necessary; a complete later claim neither repairs weak tests nor proves itself. Preserve history and attach current evidence rather than editing counts to the peer's suggested older totals.

### F-APEX-M3-10 — Stale legacy artifacts

**Disposition: DISAGREE with the family attribution and claimed defect; current artifact consumption is UNVERIFIED.**

The supplied open-item-4 PRD and ledger concern **weighted and curve-quad SE buffer-hook Join/JoinQuery facets**, not FullSpread V3/V4. Historical leftover `out/` JSON is not itself a production defect, especially when intentionally retained and unreferenced. Whether any current FactoryService consumes a stale artifact requires a concrete dependency/source identity check, which neither this finding nor this cross-review supplies. Do not delete artifacts merely on this report: the task authorizes no such action, and the repository's build workflow explicitly avoids indiscriminate cache/artifact deletion.

### MiniMax readiness verdict versus Astra

**DISAGREE with “ready-with-documented-residuals” on the evidence given.**

MiniMax's positive source observations on the helper, custody and orbital code are useful and broadly agree with my own. Its readiness reasons nevertheless depend heavily on asserted suite counts, a manifest, and historical acceptance-state updates while most money paths and tests are marked unread. Its final “source is hermetically clean” statement is not independently supported by its stated scope. Accepted D12/live residuals are not the disagreement: both are legitimate disclosures rather than missing source fixes.

The substantive disagreement is the remaining observed test-quality defects, current-source handoff drift, and now-confirmed unauthorized-by-the-supplied-plan catch behavior. A source can be sent for an audit with open issues, but that does not justify representing the remediation/test acceptance as complete. I retain NOT READY for the requested completion/readiness gate.

## Kimi findings

### Kimi F1 — Uni V4 DETF catches

**AGREE**, as bounded in the Grok-1 section above. My direct body read upgrades the existence and concrete policy-mismatch evidence beyond a broad scan. Important distinction: empty catches return “not proven sub-share” and leave other processing possible; they do not themselves grant credit. Operative error translation and selected deferral are separately observable. Financial impact remains unverified.

### Kimi F2 — Single-CP residual preview

**AGREE**, as bounded in the Grok-2 section. One real caller was read and exits residual buffering on the synthetic zero. No direct payout or mispricing claim follows solely from that fact. No supplied exception names the site.

### Kimi F3 — TokenStaking silent rewards synchronization

**UNVERIFIED as a defect; AGREE with its stated out-of-scope caution.**

I read `contracts/protocols/staking/token/TokenStakingTarget.sol:427–457`. Line **452** indeed silently catches `synchronizeRewards()`; lines **453–456** then wrap the held claim balance. No supplied requirement was identified that assigns D37 to this separate TokenStaking product, and Kimi expressly states intended behavior is unspecified. Therefore I do not adopt a Low APEX remediation defect merely by analogy with in-scope catches. An external dependency on a D16 claim token does not automatically bring every consumer into the production-change set. Record the observation for a separately scoped review; do not claim reward loss or require a fix here without tracing the product's intended synchronization semantics.

### Kimi F4 — Broken skill/dependency symlinks

**UNVERIFIED as a repository defect or failed D58 gate.**

I did not inspect symlink metadata or targets, and no tool failure here established the reported condition. My independent pass successfully opened the four assigned canonical skills and `acceptance.json` by direct paths. That does not refute Kimi's own tool error, which should remain reported as a limitation of that pass.

However, a traversal error involving `.grok` mirrors and vendored dependency paths does not by itself prove that the specific Codex catalog gate fails or that the assignment's evidence file is missing. D58 concerns a particular catalog/description-budget change, not a blanket guarantee that all filesystem links resolve in every tool environment. The alleged `layerzero` paths are also not self-evidently skill-mirror targets. No security or contract impact is established. Do not initiate sync, repair, or deletion from this unverified observation.

## Effect on Astra's original findings

No original is withdrawn or silently rewritten. The peer reports contain no source evidence refuting Astra-01 through Astra-06.

| Original | Cross-review disposition |
|---|---|
| **Astra-01 — strict negatives / wrong guard** | **Retained.** Grok's filename search and Kimi's zero test-file inspection do not contradict the concrete custody tests and scanner selection I read. MiniMax's corrected `test_ADV02` is a different test and was already recognized as a positive control in my original. |
| **Astra-02 — matrix weak controls** | **Retained.** No peer read or refuted the catch-all rounding and weaker accounting assertions cited. MiniMax's well-aimed orbital Apex008 tests do not validate every inherited matrix control. |
| **Astra-03 — R3.3 supplement** | **Retained with its original narrow scope.** No peer establishes the missing independently moved/stale-book condition in that cited supplement. This remains a finding about the cited evidence, not proof all R3.3 coverage is absent. |
| **Astra-04 — receipt cap double rounding** | **Retained, Low.** None of the peers reviewed the cited adapter arithmetic or supplies an approved exception/refutation. It remains a source-arithmetic/liveness inference without execution. |
| **Astra-05 — added rate fallback** | **Retained.** Kimi's statement that staticcalls are present is not proof every staticcall branch is D48-compliant. MiniMax's approved-exception discussion does not authorize the separate gas-dependent snapshot fallback. New catch findings reinforce the need to check semantics, not just syntax, but do not prove a financial effect of this rate branch. |
| **Astra-06 — current V4 identity handoff** | **Retained with original qualification.** Grok independently names the current hookless implementation, corroborating the changed source identity. Different historical matrix counts are not the basis for Astra-06. A later approved refactor/mapping may exist elsewhere; it was not established by these originals. |

**New evidence that changes my review coverage:** Uni V4 DETF and single-CP propagation rules were unverified in my first pass. They now contain independently confirmed policy deviations at the peer-cited sites. I attribute discovery to **Grok findings 1–2 / Kimi F1–F2** and confirmation to this Astra cross-review; I do not retroactively present them as Astra original discoveries.

**Additional corrections for catalog accuracy:** MiniMax's catalog mapping is not reliable as written. Canonical A0 is empty-vault/residual inventory, not metadata failure; L concerns AMM reserve/balance desynchronization; M concerns middleware/arbitrary calls/allowance; N concerns quote–settle consistency; O concerns signatures/permit. D12 disclosure and generic buffer-first tests do not establish those classes by renaming them. Keep the original Astra distinction between observed weak controls and unverified categories rather than claiming complete catalog coverage from names.

## Remaining dissent and updated readiness

- **Agreement:** The inspected helper/custody/orbital corrections are real source progress; D12 and unchanged immutable deployments are accepted/out-of-scope residuals, not automatic remediation defects. The DETF and single-CP catches require reconciliation with the supplied locked policy.
- **Dissent with Grok:** Superseded failures and counts are not, by themselves, a High-severity documentary contradiction. Current semantic verification is still required for independent reasons.
- **Dissent with MiniMax:** Its ready-with-residuals verdict overstates its evidence. Several numbered findings are historical states, approved limitations, speculative unread-code gaps, or misattributed artifact history rather than current defects. Its report does not refute the confirmed test weaknesses.
- **Dissent/qualification with Kimi:** TokenStaking's catch is real but outside the assigned D37 set on available evidence; the symlink/gate conclusion is unverified. No repair or expansion of scope follows from either observation.
- **Unresolved:** Whether a later approved specification authorizes the residual catches and context-sensitive rate fallback; exhaustive 108-criterion semantic closure; current source/artifact/test identities for all V4 variants; full matrix/campaign quality and historical replay. None is resolved by consensus or reported green counts.

**Updated second-audit readiness verdict: NOT READY to present this current tree as completed and regression-verified against the supplied locked plan.** The additional source reads strengthen this verdict through concrete propagation-policy deviations; they do not establish total insecurity or a new financial exploit. A re-audit may proceed explicitly as an open-issues review, but the claimed completion gate should not be certified until the identified defects/deviations and current-source evidence gaps are resolved or formally dispositioned.

This concludes Astra's single cross-review. Originals remain preserved; no implementation is authorized. Return to the coordinator/human without another review loop.
