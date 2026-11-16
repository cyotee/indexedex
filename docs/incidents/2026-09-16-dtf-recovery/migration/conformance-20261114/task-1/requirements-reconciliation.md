# Task 1 requirements reconciliation

Date: 2026-11-15
Plan task: 1 - Reconcile original requirements with approved manual pricing
Status: executor document QA passed; independent AdversarialVerify remains a coordinator gate.

## Source binding

- Approved plan: `.omo/plans/dtf-migration-conformance-remediation-20261114.md`, SHA-256 `31a0f3daff03b0e51830f5428168656eaeb19f81f40dee6f3e7f619be7230683`. All 729 lines were read before editing.
- Original P: `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`, SHA-256 `f5816a8810961ad311bd221fe6e3bbb3b599fa9ad43b76d4c403f48de4aa6d5c`. All 726 lines were read before editing.
- Amended P SHA-256: `93fdd2f045885e00304ec36aa62215127dc1a957f514605129751dd3ae45218e`.
- The amended P was read in full. The exact 495-line Git diff was captured at `E/task-1/p.diff` and inspected hunk by hunk against the original and the approved task.
- The review PRD was absent from the task worktree. It was read, without modification, at `/Users/cyotee/Projects/indexedex/docs/reviews/dtf-migration-plan-execution-20261114/REMEDIATION_PRD.md` because that is the primary checkout's copy of the exact referenced report.
- The approved delta bundle's Hard Constraints/Decisions and the approved draft's manual-pricing decisions were read in the task worktree. The older PRD and historical evidence were not edited.

## Active reconciled specification

Section 1.10, dated 2026-11-14, is present with all four operative paragraphs exactly matching the approved plan. It establishes complete manually configured Weighted inputs, current-owner atomic Stage 1 replacement through the paid owner-first bond until activation, keep-until-reloaded stored credit, stable economic originals, domain-bound configuration provenance, canonical arithmetic and no live evaluation dependency. The older PRD, evidence archives and review report remain historical through an explicit precedence pointer.

## Amendment-to-decision-and-witness map

Task numbers in the witness column are remediation-plan tasks. No runtime witness is claimed by this documentation task.

| Amended P location | Owner decision and reconciliation | Future witness |
| --- | --- | --- |
| Header pricing amendment and execution prerequisites | Section 1.10 has explicit precedence; E3 now names supported manual Weighted reproduction rather than frozen capture. | Tasks 4/13 supply current manual-pricing and final-tree evidence. |
| MIG-P01/P02 | Each full original is quoted once per explicit load on one domain-bound book; stored credit is proportional and survives later book sets until explicit replacement. | Tasks 4/7/10: full-original A/B loads and stored-credit conservation. |
| MIG-P10 | Configuration replacement is independent of issuance; current B configuration may coexist with immutable A issuance. | Tasks 4/7/10: same-recipient B-configuration/A-issuance. |
| MIG-P11 and section 1.4 | Activation removes the pricing setter, configuration loaders and issuance selectors, retains reads, and has no set-book/all-records-current gate. | Tasks 4/8/10: actual loupe/cut, mixed books and eligible unset-pricing activation. |
| MIG-P12 and MIG-AC15 | The current proxy owner alone administers manual pricing in Stage 1, including after the paid first bond; activation removes that authority. | Tasks 4/8/10: role negatives, post-purchase setter and post-cut rejection. |
| MIG-P13 and MIG-AC31 | Funding stays before dependent configuration/issuance without a new funding, pricing-readiness or finalization gate. | Tasks 7/10: funding-first resume and unset-pricing owner-bond/activation. |
| Section 1.1 | Capture/no-setter interpretations of MIG-R24-R26 and the stale MIG-R41 role are explicitly superseded; stored credit still prevents live/partial re-quotation. | Tasks 1/4/7 traceability and mixed-book behavior. |
| Sections 1.3, 1.4, 1.8, 5.4, original task 6 and the first invariant | Stored-credit terminology replaces frozen-book terminology without changing original-wallet, Stage 2, remainder, residue or custody rules. | Tasks 6/8/10: surrender and conservation evidence. |
| Section 1.5 | The paid purchase neither replaces nor reprices the book; the setter remains usable afterward until activation. | Tasks 4/10: paid-purchase then set/activate lifecycle. |
| Section 1.7 | NFT 3's two full originals use one book per explicit load and two funded bonds; no live composition or numerical award is approved. | Tasks 5/10: separate contributions, one consumption and two exact clocks. |
| New section 1.10 | The exact approved manual-pricing amendment and historical precedence are normative; review F2's live-composition prerequisite is superseded. | Tasks 4/7/10/13 and final F1-F4. |
| Section 2 source anchors and section 2.1 | Canonical mint math remains the oracle; its effective dependencies come from the manual book, and incident blocks do not authenticate that book. | Task 4 differential vectors and task 3 source authentication. |
| E3 | Supported manual models must match canonical observed-state fixtures, accept deliberate adjustments, reject unsupported domains and make no live evaluation call. | Tasks 4/7/10/13: differential and deliberately adjusted vectors. |
| Section 4 artifact table | The pricing interface/library and retained Weighted Hook target/facet have their approved names; one pure evaluator and one removable setter are specified. | Tasks 4/9: rebuilt artifacts, ABI, salts and proxy census. |
| Section 5.1 | One replaceable complete book contains raw/SE inventories, rates, scales, weights, fees, seigniorage and supported V3 operands; original identity excludes price and configuration identity includes it. | Tasks 4/7/10: stable origins, A/B retention and stale-load rollback. |
| Section 5.2 | Existing canonical mapping, one fee/uplift/user split and unchanged-book component grouping are retained with manual-book symbols. | Task 4 arithmetic intermediates and task 13 regressions. |
| Section 5.3 | Pricing set and explicit configuration load are separate operations; expected-book checks precede quote/mutation and immutable A issuance survives B configuration. | Tasks 4/7/10: no-mutation-on-set, explicit reload and same-recipient history. |
| Section 6 callable surfaces | `setMigrationWeightedPricing(Inputs)`, retained `migrationWeightedPricing()`/`previewOriginalCredit(...)`, final expected-book loader scalars and activation behavior are explicit. | Tasks 4/7/10: ABI, unset reads, loader guards and real receipts. |
| Section 6.1 | Both removable facet surfaces include pricing/configuration/issuance writers; all reads survive and mixed records do not gate activation. | Tasks 4/8/10: actual selector lists and restoration negatives. |
| Original dependency table | Tasks 2/4/7/9 now deliver manual evaluation, expected-book loaders, the pricing cut and mixed-book resumability. | Tasks 4/7/10/13 own those results. |
| Original task 2 | One manual Weighted evaluator replaces capture semantics; canonical observed and deliberately adjusted cases are required. | Remediation task 4 and `migration/quote-evidence.md`. |
| Original task 4 | Explicit loads check expected books; A-prepared/B-current loads revert and same-recipient B/A facts persist. | Remediation tasks 4/7/10. |
| Original task 7 | Both administration surfaces lose every writer, with mixed-book and eligible unset-pricing activation. | Remediation tasks 4/8/10. |
| Original task 9 | Operator checkpoints and resume rules distinguish unsent stale A, mined A under B, retained mixed records and B-configuration/A-issuance. | Remediation tasks 7/10/12. |
| Original task 10 and section 8.2 | Invariants now require live independence, keep-until-reloaded credit, stable originals and postactivation pricing immutability. | Remediation tasks 8/10/13 with successful-action witnesses. |
| Section 8 test rows | Funding/manual-pricing, configuration, activation and script rows cover the amended behavior without changing the 13 arithmetic examples. | Remediation tasks 4/7/8/10/13. |
| MIG-AC21/22 | Canonical full-original quotes are explicit-load artifacts; later books affect only new previews/loads. | Tasks 4/6/7. |
| MIG-AC24 | The A/B witness proves live independence, no mutation on set, explicit Stage 1 replacement and postactivation immutability. | Tasks 4/7/10. |
| MIG-AC36 | Remaining principal changes only the delivered fraction, not the stored original quote. | Tasks 4/6/8. |
| MIG-AC38 | Complete replacement preserves delivered compensation, consumption and the same-recipient B/A witness. | Tasks 4/7/10. |
| MIG-AC49 | NFT quote loading still mints zero and keeps stored quote/original identity stable across book sets. | Tasks 4/5/6/10. |
| MIG-AC51/52 | Consolidation retains one selected book per load, accepted histories, stale-load rejection, mined-A resume and mixed-book activation. | Tasks 4/7/10/12. |
| Section 11 | Completion now requires canonical manual inputs, keep-until-reloaded credit, stable identities, mixed-record support and irreversible writer removal. | Tasks 14/15 and final F1-F4; not closed here. |

## Review finding dispositions

- F2: its selected live-production-composition prerequisite is superseded for pricing. Amended E3 still requires canonical supported observed-state fixtures, deliberate-input cases and unsupported-domain rejection without live evaluation.
- F1: absent named artifacts remain open and belong to later recovery/evidence tasks; this amendment is not those artifacts.
- F3: authenticated source closure and operator records remain open under remediation tasks 3/6/9/13.
- F4: full resumable operator rehearsal remains open under remediation tasks 7/10/12/14; no status literal was changed.
- F5: the substantive adversarial TestBase remains an implementation obligation under remediation tasks 8/13.
- F6: target-gas feasibility remains open under remediation tasks 11/13.

## Preservation and observed QA

- 15 MIG-P rows and all five E gates remain.
- All 53 MIG-AC table rows and the complete ID set 01-53 remain.
- Section 8.1 is byte-identical to the original and still has exactly 13 examples.
- Owner sections 1.1-1.9 remain, with only the authorized pricing-related wording amended; section 1.10 was appended.
- `GIT_MASTER=1 git diff --check` exited 0 with empty output.
- The required obsolete-clause inspection returned zero matches. Three broader capture references remain only as explicit precedence/supersession statements; see `obsolete-clause-check.md`.
- No compiler, contract test, prose unit test, RPC, deployment, install, commit or public action was run.
- Dirty-worktree comparison and cleanup receipts are recorded in `preservation-check.json` and `commands.json`.

## Edit mechanism record

The prepared patch contained 57 unique, ordered, non-overlapping replacements. The shell had no `apply_patch` executable and the harness's deferred `apply_patch` tool returned inactive without changing P. The active exact-replacement patch editor applied those validated replacements, followed by four consistency-only replacements found during the full read. P's original hash was confirmed unchanged immediately before the successful edit. This record does not claim an unavailable tool succeeded.
