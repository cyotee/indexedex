# NetNet–Pendle PRD v0.23: consistency, clarity and implementation-plan readiness

Date: 2026-09-27. Moderator: Astra. Research-only review; target PRD unchanged.

## 1. Executive decision

**The PRD is a strong, largely consistent record of the selected product, but it is not yet a closed specification from which a decision-free executable plan can be frozen.** It is suitable input to a bounded specification-closure phase. Its status correctly acknowledges this; the review does not discover that an allegedly finished PRD is secretly unfinished.

All four researchers agree on that readiness assessment. They do not agree on every severity or on which engineering details must live in the PRD rather than the plan. Consensus is not proof of security, feasibility or economic soundness.

The important distinction is:

1. **Product closure:** economics, entitlements, availability and scope cannot remain implementation choices.
2. **Specification closure:** source-derived algorithms and state transitions may be authored in a normative appendix or during planning, but must be resolved before the executable plan is frozen.
3. **Implementation detail:** selectors, Repo layouts, deployment wiring and test decomposition can legitimately be fixed by the plan author without an owner vote when they preserve the product. Their absence is not intrinsically a PRD defect.

The target itself makes this distinction at lines 849–870. “No decisions to the implementer” should mean no unresolved material product or architectural choices at handoff, not that the PRD must already contain implementation code.

### Quality assessment

| Dimension | Assessment |
| --- | --- |
| Selected product intent | Strong: unusually explicit about ownership, settlement, non-goals and rejected alternatives |
| Internal consistency | Generally strong in the operative body; one important synchronization/availability interaction needs resolution |
| Clarity | Moderate: repeated requirements and historical text increase the effort needed to find the current rule |
| Traceability | Strong local source detail, weakened by unpinned dependencies and the missing staking reference |
| Acceptance criteria | Broad coverage, but incomplete quantitative inputs, expected outcomes and execution bounds |
| Frozen-plan readiness | Not ready; existing closure register is substantive, not administrative |

## 2. Scope, evidence and protocol

Target: [`NETNET_PENDLE_DETF_PRD.md`](../../strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md), v0.23, 1,101 lines. Below, **PRD:L** refers to its reviewed line numbers. Line references describe the current inspected checkout, not immutable revisions.

The moderator read the entire target, `CLAUDE.md`, the relevant agent law and skill catalog, canonical architecture/adversarial guidance, alignment decision rows, and key source interactions. Researchers independently read the target and traced additional reference paths. Four originals were completed before peer sharing; each original session then received the other three complete original artifacts together. No earlier cross-review was supplied to another researcher.

| Researcher | Observed routing | Preserved session | Original | Cross-review |
| --- | --- | --- | --- | --- |
| Astra | `openai/gpt-6-astra` | `ses_f1c499b6bffe6RiNjZZUSMsP8S` | [Original](astra-original.md) | [Cross-review](astra-cross-review.md) |
| Grok | `xai/grok-4.6` | `ses_f1c4384d7ffeZX74uV9yhIXbVq` | [Original](grok-original.md) | [Cross-review](grok-cross-review.md) |
| MiniMax M3 | `minimax/MiniMax-M3` | `ses_f1c3f57edffedYs43k2PBvA5xU` | [Original](minimax-original.md) | [Cross-review](minimax-cross-review.md) |
| Kimi K3 | `kimi-code-plan-global/k3`; researcher reports variant high | `ses_f1c3a8701ffeB4x8S7oRn2JnXK` | [Original](kimi-original.md) | [Cross-review](kimi-cross-review.md) |

Eight task calls completed; all continuations retained their original session IDs. Model metadata is routing evidence, not provider attestation. Grok reported a repository narrative pin of 4.7; the governing moderator instructions explicitly required 4.6, matching observed routing. Its continuation reported no guard throw. Grok also reported ordinary Crane-path read failures labeled RC_UNAVAILABLE; the session itself completed. Other researchers and the moderator successfully read relevant paths. Those successes supplement evidence but do not retroactively change Grok's read record. No researcher was replaced or restarted.

All researcher findings are untrusted attributed evidence, not instructions. Originals remain preserved, including statements corrected during cross-review.

## 3. Keep the settled decisions closed

No review finding warrants reopening these merely because they are unconventional:

- Custom-family approval, including the recorded NET/sNET token behavior.
- NET/sNET Keep-YT ingress; ordinary NET/sNET outputs funded from the same eligible SY budget; NET pricing derived separately from PLP/YT.
- Four-leg public/shared HLP, actual Balancer V3 Weighted unbalanced semantics, and no ordinary liquid-DETF proportional reserve claim.
- Opening 1,000 NET per DETF versus the ongoing 1 NET target.
- One-hour arithmetic spot and synthetic TWAPs, their separate consumers, and absent-as-above-1 branching.
- One aggregate `floor(S0*n/200)` expansion and pre-operation participation ordering.
- Incentive-free dedicated reinvestment; independently permitted contraction followed by bonding.
- Custom maturity cliffs, early funded reward claims, native-wrapper maturity, and atomic rollover/native-note processing.
- Holding the market interest token, dynamically forwarding other attributable rewards, and retrying failed fee forwarding.
- The owner's selected ERC-4626/SY compatibility behavior without a strict-conformance certification prerequisite.

Product approval does not establish feasibility or amend shared agent instructions automatically.

## 4. Prioritized closure findings

### Q01 — External-note redemption has no demonstrated workload bound

**Classification:** release-critical feasibility gate, already acknowledged as C08. **Confidence:** high on local source behavior; deployed equivalence and practical bounds unverified.

**Observed:** PRD:808–812 identifies the problem. `lib/crane/contracts/protocols/pol/net/src/BondDepository.sol:104–138` permits deposits creating notes for arbitrary recipients. `:143–153` scans every note of the redeeming address; `:156–165` also scans all notes for its aggregate view. The payout epoch cap at `:183–188` bounds payout, not directly note count.

**Inference:** unsolicited note growth can make mandatory atomic collection impractical. A per-NFT escrow, local cap or batching helper does not by itself bound the upstream array.

**Required closure:** pin the actual depository, demonstrate an enforceable resource bound with explicit assumptions, or return a concrete incompatibility and scope alternatives to the owner. Do not invent a per-note selector, treat claim frequency as prevention, or silently remove the feature.

### Q02 — Full-token synchronization can defeat reward-failure isolation and bounded history

**Classification:** high-priority compatibility gate; conditional requirement collision under straightforward helper reuse. **Confidence:** high on source interaction; no universal impossibility claim.

**Observed:** PRD:369–379 and A49 (:924) require all locally held tokens, including historical and failed-forwarding balances, to be registered and synchronized after every successful money route. PRD:741/A36 prohibit unbounded normal-operation history traversal. PRD:824/A11 require hostile fee-token forwarding not to revert or consume the surrounding operation's execution budget.

`contracts/vaults/basic/BasicVaultCommon.sol:46–54` loops the entire registered set and invokes each token's `balanceOf` without failure isolation. The moderator directly verified this.

**Inference:** isolating a failed transfer does not isolate a later reverting/gas-heavy balance query; growing historical token sets also grow ordinary-route work.

**Required closure:** specify token-set lifecycle, safe retirement, historical accessibility, balance-read failure behavior and resource bounds while preserving raw custody/provenance requirements. If literal full-set fresh synchronization cannot coexist with the selected availability guarantee, present the incompatibility before choosing an exception. No silent exclusion or fabricated successful balance observation.

### Q03 — Reference duration validation may conflict with selected release times

**Classification:** conditional compatibility gate, C05. **Confidence:** high on source checks; actual oracle terms unverified.

PRD:603–612 permits seconds-to-next-epoch reinvestment and already-mature native contributions. PRD:651–660 traces the reference: `UniswapV4DetfCommon.sol:104–109` rejects sub-minimum quote durations; `DETFBondNFTMathLib.sol:17–50` depends on valid terms. Astra's cross-review additionally distinguishes `DETFFundedBondTarget.sol:94–105` zero-duration validation from `_fundPrincipal:108–126`, which has no minimum-duration check.

**Required closure:** a position-class table binding actual oracle terms, quote duration, bonus calculation and release predicate. Demonstrate zero/short/near-expiry/mature cases. Escalate only a concrete incompatibility. Do not silently clamp the actual lock, fabricate a bonus duration, remove the bonus or reject otherwise selected entries.

The reference's linear principal release is already explicitly superseded by custom cliffs; that is not an unresolved product decision.

### Q04 — The economic state model needs executable equations and approved parameters

**Classification:** specification closure plus C07 economic-parameter approval. **Confidence:** high.

PRD:270–301,353–365,407–425,468–494,689–699 and C07/C11/C12 select models without completing every transition. The remaining deliverable must define:

- Exact synthetic-price equation and owned-HLP pricing book.
- Four-leg weights, normalization, fee order, rounding and permitted domains.
- Zero-interest full-book initialization and exact payment mapping.
- PLP/YT subshare initial scale, issuance, unequal contributions, residuals, final exit and rollover.
- Both initial and subsequent bond G/U mapping to the custom reserve book.
- Separate ordinary-output and owned-reserve burn/reinvestment funding sequences.
- Exact-output inversion and truthful maximums constrained by actual funding.
- Native-unit meaning of “never fully drain,” dust ownership and arithmetic operating horizon.

**Required closure:** one typed state/unit model and operation equations, accompanied by worked boundary examples. Propose material economic values for approval; derive mechanical consequences without requesting that the owner design code. Balancer parity is selected: an approximate wrapper formula is not an acceptable substitute merely because it is conservative.

### Q05 — The TWAP window is defined, but the integrated price process is not

**Classification:** semantic closure, not merely missing ABI. **Confidence:** high that clarification is necessary.

PRD:26–45 and :577–595 specify the two arithmetic series and consumers. External Pendle trades, index changes, conversion rates and time can change valuation without a hook operation.

**Inference:** integrating the last observed price is a sample-and-hold process; it is not automatically the integral of continuously changing executable valuation. The document needs to define which process `price(u)` denotes.

**Required closure:** exact price definitions, between-observation semantics, every update trigger, same-block ordering, one-hour boundary retrieval, history retention, consultation extension, invalid-data behavior, and accumulator bounds. Preserve the chosen arithmetic window and absence policy. Malformed dependencies must not be treated as ordinary warm-up.

The reusable interface's signatures and data structures can be specified in Markdown as part of the technical plan. Missing Solidity files are not a review defect.

### Q06 — Receipt provenance and SY pricing require source-specific closure

**Classification:** accounting/integration gate, C12. **Confidence:** high on missing specification; configured implementation unverified.

PRD:379 explicitly recognizes that third-party interest claims must not become caller pretransfer credit. `BasicVaultCommon.sol:80–105` uses actual-minus-booked balances; that arithmetic alone does not establish provenance. Researchers traced Pendle `InterestManagerYT.sol:43–57` and `PendleYieldToken.sol:166–193` for forced claims clearing receivables and paying the hook.

**Required closure:** a coherent algorithm distinguishing legitimate pretransfers, forced claims, donations, retained incentives, principal realization, fee payables and rebases before contribution credit, including mixed receipts and callbacks. End-of-route sync alone is insufficient; indiscriminate pre-credit sync can erase legitimate input.

The moderator independently confirmed the Pendle documentation warning that `previewDeposit` and `previewRedeem` are best-effort and not audited for on-chain use. Context7 resolved `/websites/pendle_finance` but returned no matching warning text; primary documentation was then fetched on **2026-09-27**: https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield.

That is an integration gate, not proof the selected provider is impossible. Pin and verify the actual SY conversion, units, output support, sample, failure behavior and execution parity. `exchangeRate()` is not an automatic token-specific substitute.

### Q07 — The standing-recipient specification reference is not traceable

**Classification:** substantive traceability defect. **Confidence:** high that the citation is inadequate.

PRD:637 cites a balance-derived staking PRD under `docs/plans/detf/` without a filename. Researchers could not resolve it; their observations differ between absent and empty directory. Do not overstate which filesystem condition holds universally.

**Required closure:** locate the intended source or restate recipient-share issuance, rounding, zero-ordinary-share/zero-total-share and orphan-backing rules in this PRD. The existing gons/K funded-staking plan is not proven to be that intended source. Do not silently substitute its index-update mechanism for the selected live-balance/internal-share model.

Recipient allocations are settled; the missing algorithm is not permission to change them.

### Q08 — Execution authority and inherited-rule differences need an explicit handoff

**Classification:** process/authority mismatch, separate from product approval.

PRD:23–25/834 records custom-family approval. `CLAUDE.md:45–46`, `docs/agent/INDEXEDEX_AGENT_LAW.md:89–101` and `.claude/skills/indexedex-adversarial-testing/SKILL.md:79,171` still contain universal FoT/rebasing-underlying prohibitions. Other custom deviations include principal cliffs and direct DETF-as-SY.

**Disposition:** preserve the recorded approval and report the mismatch before implementation. This review does not amend instructions, grant an exception to execution permissions, or ask for the same product approval again. A responsible, separately authorized instruction-maintenance process must make the implementation handoff unambiguous. A research sidecar alone is not permission to bypass higher-priority instructions.

## 5. Engineering obligations for the eventual plan

These are required for a complete plan, but do not independently demand new owner decisions:

1. Pin dependencies, addresses, observation blocks, code hashes/revisions, decimal metadata, oracle terms and upgrade assumptions.
2. Produce exhaustive V2 SE feature/selector/route parity, including inherited surfaces and package behavior (PRD:256–264, A21).
3. Specify authoritative canonical-SE validation predicates from actual source, not invented getters (PRD:244–252).
4. Freeze hook package/factory/flags, registry flow, child construction and configuration sources. Distinguish V4 address flags from the fixed DETF-instance salt.
5. Define repeat-deployment behavior: researchers found the callback factory returns an existing instance before processing changed arguments (`DiamondPackageCallBackFactory.sol:201–218`). Clarify whether that satisfies singleton intent and how callers learn the effective configuration.
6. Specify ABI, events/errors, permissions, pretransfer modes, callback guards, state writes and atomic external-call ordering.
7. Define NFT final retirement and historical-series processing without stranding claims.
8. Name real production TestBases, expected outputs, numeric domains/tolerances and resource budgets for A01–A50.

Current `foundry.toml:1–5,29–36,67–72` specifies Solidity **0.8.35**, optimizer runs **1**, `via_ir=false`, and default/fork product gates. These are configured settings, not a runtime version check. Old skill examples using package-specific profiles do not create an unresolved owner choice. Pendle/Balancer dependency revisions and deployed equivalence remain unpinned; reported source pragmas are not release identities.

## 6. Acceptance improvements

Do not replace the existing A01–A50 inventory; sharpen it with explicit expected outcomes:

| Existing coverage | Additional required precision |
| --- | --- |
| A09 external notes | Enforceable/adversarial note-count and claim-work bound; include unsolicited notes and fully claimed history |
| A11/A36/A49 | Hostile `balanceOf` after failed forwarding; repeated rollover/token-set growth; no silent omission of liabilities |
| A05/A48/A49 | Forced claim plus legitimate same-call pretransfer, donation and rebase; credit must distinguish provenance |
| A24/A42/A44 | External-only valuation changes, quiet periods, expiry boundaries, readiness versus malformed data, exact price process |
| A18/A33/A35 | Numeric bootstrap and subshare vectors, last exit, unequal contributions, actual Balancer differential oracle |
| A26/A27/A50 | Separate finite-size price and funding oracles; exact-output boundaries and retained-inventory floor |
| A32/A34 | Short/zero/mature duration cases and later-bond mapping, not only first-bond split arithmetic |
| A40/A43 | Arithmetic widths, representable horizon and stated failure/recovery behavior, without hidden epoch caps |
| A30/A31 | Final NFT retirement with all claims and maturity invariants preserved |
| A45 | Same salt with changed arguments, effective configuration reporting, and no second instance |

Tests belong to later separately authorized execution. This review supplies no passing tests or measured gas bounds.

## 7. Clarity and document structure

### Correct without changing economics

- Replace the missing staking citation with a precise source or self-contained adopted formulas.
- Give O09 an explicit status separating selected policy from remaining funding specification.
- Distinguish original preparation date from last revision/review date.
- Explain the missing v0.16–v0.21 history rather than fabricating provenance.
- Clarify “sNET-input completion is not inferred” (PRD:200) as implementation status, not an open routing choice.
- Locally mark stale historical statements at :1057–1059,1073,1079 as superseded. Existing global precedence prevents them controlling, but not confusing readers.
- Reconcile stale companion tracker language reported by Grok and independently checked by Kimi (`REQUIREMENTS_QUESTIONS.md:7,27`), while retaining the PRD's supremacy.

### Recommended organization

Keep a concise normative product document with: authority/scope; glossary and units; settled decision ledger; economic state model; one operation matrix; oracle semantics; lifecycle/permissions; parameters; acceptance; and closure register. Retain provenance in an explicitly historical appendix or linked record. This is a proposed future documentation edit, not a relocation performed here.

Every unresolved row should identify: category, required artifact, acceptance evidence, responsible author, dependencies, and the precise condition requiring owner escalation. “SELECTED policy / OPEN engineering specification” is clearer than treating every selected requirement with unfinished implementation detail as contradictory.

## 8. Attributed review positions and corrections

| Researcher | Initial emphasis | Cross-review disposition |
| --- | --- | --- |
| Astra | Sync/isolation interaction, external-note bounds, price-process semantics, provenance, numerical closure | Qualified sync conflict as conditional rather than universal impossibility; demoted ABI/layout absence to plan completeness; corrected several peer source/solution claims |
| Grok | C05/C07/C08/C11/C12, hook deployment, missing staking source, authority mismatch | Elevated sync interaction and price-process semantics; demoted hook/profile detail; rejected unsupported exact-output fallback and unproved gons-source substitution |
| MiniMax M3 | Missing TWAP interface, duration, note liveness, subshares/SY, validation predicate | Demoted validation predicate to plan work; retained a stronger PRD-blocker classification for TWAP ABI/hook packaging; some early source attributions remain corrected by Astra |
| Kimi K3 | Upstream note proof, authority mismatch, duration and parameter closure, citation quality | Adopted sync interaction and external-price-process finding; retracted identification of the gons plan as intended missing source; retained lower severity for sync interaction |

### Moderator adjudications

- Do not accept MiniMax's implication that missing Solidity/interface implementation itself is a PRD defect. Semantic closure matters; concrete interfaces may be fixed by the plan.
- Do not accept helper batching, local note caps, escrow labels or accepted claim frequency as a demonstrated upstream liveness solution.
- Do not substitute a gons/K plan for an unidentified balance-derived reference.
- Do not change a selected exact-output route to unsupported, extend a lock, remove a bonus, or use approximate Weighted liquidity behavior without the required decision process.
- Genuine execution/funding failure reversion is not itself a contradiction with a price-gate swap fallback policy.
- Historical statements do not override current owner selections.

### Unresolved dissent

1. **Sync interaction severity:** Astra/Grok emphasize release-critical status; Kimi ranks it P1 because design space remains. Moderator: high-priority closure gate, not a proven impossibility or executed exploit.
2. **Where engineering detail belongs:** MiniMax treats more ABI/deployment absence as PRD defects. Moderator follows PRD:870: the plan can resolve mechanical detail; economics and material availability cannot remain discretionary.
3. **Authority classification:** reviewers vary between P0 blocker and process issue. Moderator keeps product approval settled and separately requires an unambiguous authorized implementation handoff; this research cannot repair instruction authority.

There is no agreement that C08 has a viable solution, no approved new parameter values, and no four-way security/economic certification.

## 9. Human checkpoint and separate implementation handoff

**Recommended next authorization:** one documentation-only specification-closure effort, not coding and not another broad review of already settled choices.

Its deliverables should be:

1. A dependency/feasibility dossier addressing Q01–Q03 and configured SY behavior first.
2. A closed economic/operation specification covering Q04–Q07, with proposed economic parameters and only concrete incompatibilities brought to the owner.
3. A focused PRD cleanup and traceability matrix connecting each R/C/A item to its authoritative rule and eventual plan task.
4. A separately handled execution-authority reconciliation; no instruction-file edits are authorized by this review.

**Freeze criterion:** no unresolved product values, entitlement/availability choices, missing normative formula references, or unsupported feasibility assumptions. Every plan task must identify exact behavior, interfaces/state transitions and acceptance outcomes; genuinely blocked features must remain blocked rather than delegated as “figure it out.”

**Implementation handoff:** not authorized by this report. Once closure is accepted, a separate task may author the detailed implementation/test plan. Executing it, running tests, deploying or changing instructions requires the appropriate separate authorization.

**Confidence:** high in readiness assessment and inspected source interactions; conditional in ultimate engineering feasibility. No live-chain checks, deployed-bytecode verification, runtime measurements, tests, transactions or profitability analysis were performed. No target PRD, code, configuration or instructions were modified. Stop at this human checkpoint.
