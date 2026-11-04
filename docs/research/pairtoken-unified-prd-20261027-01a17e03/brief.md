# Unified Pair Token PRD council brief

## User authorization and outcome
The user asked: Have the council write a single unified PRD so we have a single document to work from. This authorizes documentation consolidation, not code implementation or economic redesign. The final planner-facing artifact will be /Users/cyotee/Projects/indexedex/docs/research/pairtoken-unified-prd-20261027-01a17e03/handoff/PRD.md, identity pairtoken-unified-prd-r1. It must contain the complete behavioral specification and acceptance scenarios, not a summary, diff, errata annex, report, or set of links. It will supersede the old r2 plus proposed errata as the working document, while preserving both original archives unchanged.

## Admitted inputs for this INITIAL AUTHORING contribution
1. /Users/cyotee/Projects/indexedex/docs/research/pairtoken-behavioral-requirements-20261027-01a17d57/handoff/REQUIREMENTS.md, identity pairtoken-requirements-final-r2, SHA-256 8060c1e3d6ec225f761de647ca29c12536712d1d9188a6600a694d72d44ea848.
2. /Users/cyotee/Projects/indexedex/docs/reviews/pairtoken-requirements-fidelity-20261027-01a17e03/REMEDIATION_PRD.md, the completed four-member fidelity council report.
3. /Users/cyotee/Projects/indexedex/docs/reviews/pairtoken-requirements-fidelity-20261027-01a17e03/coordinator/proposed-errata-r2.md and /Users/cyotee/Projects/indexedex/docs/reviews/pairtoken-requirements-fidelity-20261027-01a17e03/coordinator/resolution.md.
4. This common brief.
The old source evidence and individual peer artifacts are not needed and are excluded. Do not retrieve source, do new research or legal analysis, or reopen old individual originals/feedback. Previously retained personal context can inform your contribution. The prior advisory assignment is complete; this is a new authoring task, not an extra advisory round.

## Consolidation contract
- Preserve every existing requirement ID, all 58 acceptance scenarios, exact ABI/constants/formulas, rounding/casts, operation/check order, events/errors, dependency limits and absent-behavior list. Do not abbreviate the actual standalone content.
- Integrate C1 directly: paired deposit events report pull-returned amounts, nominal for native and checked post-minus-pre balance difference for ERC-20, including zero and checked failure for a negative difference.
- Integrate C2 directly: every idle pair is read currency0 then currency1. Keep paired addition's idle-before-fresh-price order distinct from Deploy's already-held price, and preserve burn/settlement/reservation checkpoints.
- Resolve the prior uncapped-fee concern by including an explicit explanatory consequence in the unified text: a uint16 fee rate may exceed 10000; attempted payment is not capped by collection or a separately segregated principal budget, can use other balance, and a successful native payment followed by idle-underflow can revert the whole transaction. Do not add a fee clamp or imply a successful permanent principal drain.
- Optional, accurate acceptance rows can make already-specified no-add zap, native payout wrapper/zero-output behavior, zero-position compound returns, and receipt/order/uncapped-fee edge cases explicit. They must remain conditional on the stated dependencies and add no new behavior. Preserve old IDs; use new unique IDs for additions.
- A concise product purpose, user operations, scope/non-goals, conformance/release evidence criteria and provenance can make this a PRD. It remains a source-equivalent baseline, not an IndexedEx-specific architecture/IRateProvider/getRate/Crane adaptation. No roadmap or invented implementation choices.
- Carry all external dependency unknowns inside the PRD so no companion report is required. Preserve no-runtime-proof, no-legal-clearance and source-exposure limitations without turning them into new product behavior. Provide no source listings, source line locators, or instructions for the implementation team to consult target code.
- Publish one new final identity. Do not pretend the old r2 was modified or that an errata annex must accompany the final. Original council files remain untouched.

## Your initial contribution
Return INLINE ONLY an independent, concrete authoring contribution: proposed exact prose to integrate or correct, any additional acceptance rows, any preservation/standalone risks, and a concise recommended disposition. Focus on consolidation rather than repeating the completed fidelity review. The coordinator will integrate all contributions into the complete draft and archive your exact response. You need not emit another 80KB complete PRD. No files may be created or edited by you in this phase; do not probe apply_patch, memory, write/edit, or shell tools. No delegation, project commands, tests/builds, Git, installs, live calls or deployments.

## One later advisory pass
After all initial contributions settle, the coordinator writes one full, immutable PRD draft, checks its raw SHA-256 with shasum, and requests one advisory pass. That phase permits ONLY the exact pinned draft, authorized shasum verification, inline six-section feedback, and no source/requirements/peer/original reads or edits. Feedback does not replace the initial contribution. Final revisions are coordinator resolutions, not newly approved final text.

