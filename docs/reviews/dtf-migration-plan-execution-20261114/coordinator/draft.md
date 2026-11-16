# Coordinator draft

## Draft identity

- Draft ID: draft-dtf-migration-plan-execution-20261114-r1
- Path: `docs/reviews/dtf-migration-plan-execution-20261114/coordinator/draft.md`
- Run ID: dtf-migration-plan-execution-20261114
- Status: pending advisory review. This file is not the final.
- Fingerprint: not computed
- Sources: the four settled initial responses, re-read plan text, and coordinator re-reads named below. The coordinator is not an extra vote.

## Participation

- Council kind: full
- Requested members: astra, grok, minimax, kimi
- Substantive initial responses: astra `st_01a1d9e3`, grok `st_01a1d9e4`, minimax `st_01a1d9e5`, kimi `st_01a1d9e6`
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking-agent
- Coordinator is an independent vote: no

## Question

Did the committed changes from `90ff0307a7a8e084aa073e02eff125e9c7973933` to `c33f70683cbaabfedc2dbce1142fdd65660d4cf3` completely and correctly execute `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`, revision `migration-detf-implementation-plan-r7-token-staking-migrated-exposure`, including sections 1-11 and the section 11 completion standard?

## Proposed text

No. The committed range does not completely and correctly execute the plan. Section 11 is not met. Static reading found a substantial implementation of several accepted mechanisms. That is not completion, and it is not a passing test run. This draft does not authorize implementation, deployment, funding, activation, or a plan edit.

The four responses agree on that negative sentence. They do not agree on every supporting finding. Disagreements are preserved below and are not smoothed into consensus.

### D1. Named task evidence artifacts are absent

- Location: at `c33f70683cbaabfedc2dbce1142fdd65660d4cf3`, `docs/incidents/2026-09-16-dtf-recovery/migration/` contains `operator-runbook.md` and `quote-evidence.md` only. Members independently checked `git ls-files`, `git ls-tree`, or `git cat-file -e`. The coordinator's earlier directory listing matched that pair. Absent names: `source-manifest.json`, `source-route-matrix.md`, `surrender-spec.md`, `package-evidence.md`, and `verification.md`. No fork-run receipt set is in that directory.
- Requirement: plan task 1 evidence, task 3 `package-evidence.md`, task 10 `verification.md`, section 10, and section 11's requirement that tests and rehearsal demonstrate the facts.
- Impact: source-route closure, package reconciliation, and the execution record the plan named are not in the committed tree. Test filenames and commit subjects do not replace those files.
- Fix direction: write the named files from the execution actually being claimed, including commands, compiler, revision, exits, summaries, gas bounds, and pre-existing failures, or change the plan's evidence names in a later authorized revision. Do not treat this review as that record.
- Evidence class: static absence, corroborated by all four responses. Adopted.
- Dissent: none on absence. Severity labels differ. Astra called the source and verification gaps high and the package gap medium. The draft does not assign a new severity scale.

### D2. Committed quote evidence does not close E3

- Location: `docs/incidents/2026-09-16-dtf-recovery/migration/quote-evidence.md` lines 1-8 and 165-175, re-read by the coordinator. `UniswapV4DetfMigrationSnapshotLib.sol` admits direct contribution-to-pair routes, recognized V3 deposit inputs, and raw DETF output. Members who read the library reported no live preview fallback inside evaluation.
- Requirement: task 2 and gate E3 require a frozen evaluator for the actual configured reserve and routes, with differential vectors in `quote-evidence.md`.
- Impact: the file says the bounded increment is not completion of task 2, E3, the full plan, or lifecycle integration. It also says there is no identified production recovery binding, and that several nested quote models are not certified. The library can be a correct limited implementation. It is not E3 closure for the recovery reserve.
- Fix direction: pin the actual recovery composition and either close every reachable nested model with frozen vectors or record the unsupported domain as an E3 blocker. Do not delete the disclaimer while it is accurate.
- Evidence class: document text re-read, plus member source reads of the snapshot library. Adopted.

### D3. Required source rows remain unresolved

- Location: `operator-runbook.md` heading `Required categories still blocked`, re-read by the coordinator. The table includes TokenStaking raw weight with ordinary atomic surrender unsupported, underlying SE shares with direct-user integration absent, fungible LP with integration absent, and earlier liquidation with disabled or unproved exits. The same section says full original task 9 and release remain open.
- Requirement: section 3 and task 1. Unresolved rows prevent full implementation completion. A source with no exposure must be proved absent, not omitted. Section 11 requires every required legacy source to be supported with configured original-wallet surrender and conservation.
- Impact: adapter code for several categories was read by the members. The plan's completeness rule is not satisfied by the existence of a code path while the repository's own operator record still lists unresolved rows.
- Fix direction: close each row with executable evidence or a concrete blocker in the missing source artifacts. Do not invent approved numerical awards. The plan already says recipient amounts and operational issuance are separate execution inputs.
- Evidence class: runbook text re-read. Adopted as a completion failure. The narrower point about unapproved award amounts is in the disagreement table, not this finding.

### D4. Task 9 is explicitly open in the operator implementation

- Location: `scripts/recovery/dtf-migration/execution.ts` lines 98 and 185 return `fullTask9: "open"` on both the simulate path and the receipt path. `preparation.ts` line 110 sets `fullTask9: "open"`, and line 134 writes the same status into `blocked.json`. The coordinator re-read those lines. The runbook repeats that full original task 9 remains open.
- Requirement: task 9 and section 11 require a resumable rehearsal that demonstrates the facts.
- Impact: resume machinery can exist while the implementation still reports task 9 open. That status is source, not a checkbox inference.
- Fix direction: change the status only after the full rehearsal the plan describes has been demonstrated and recorded. Do not apply that edit here.
- Evidence class: source observation. Raised by Kimi and re-read by the coordinator. The other responses did not cite these lines. Their silence is not disagreement.

### D5. The planned adversarial TestBase is absent

- Location: section 4 names `TestBase_UniswapV4DetfMigration_Adversarial.sol`. `git ls-files` and member tree checks found no such path. `TestBase_UniswapV4DetfMigration.sol` is present.
- Requirement: section 4's named adversarial base, and section 8.2's adversarial catalog.
- Impact: the named file was not delivered. Other invariant and hostile-contribution tests exist. They were not established as a substitute, and no test was run.
- Fix direction: add the named base, or record in a later plan revision which catalog cases now live elsewhere. Do not add an empty alias to satisfy the filename.
- Evidence class: verified absence. Raised by Grok, Astra, and Kimi. MiniMax did not separately name it. That omission is not support for treating the file as present.

### D6. Shared direct-pair quote now reverts on zero raw output

- Location: diff of `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol` from `90ff0307a7a8e084aa073e02eff125e9c7973933` to `c33f70683cbaabfedc2dbce1142fdd65660d4cf3`, re-read by the coordinator. The old direct-pair branch assigned `Math.descale` and reverted only when `amountOut >= rawReserves`. Current `rawOutput` at lines 156-160 also reverts `Math.ZeroAmount` when descale is zero. `_outputBudget` calls it when `standardExchanges[j] == address(0)`.
- Requirement: section 4.1 and task 10 require ordinary packages to keep their specified behavior when shared code changes. Task 2 allows factoring quote math only where required for reuse.
- Impact: every ordinary caller of this shared library, not only Migration, now reverts on a direct-pair quote that previously returned zero. Whether a production quote hits that dust case was not executed.
- Fix direction: keep the factored helper for the frozen evaluator, and preserve the previous zero return on the live direct-pair path unless an ordinary-package requirement says zero output must revert. Record the ordinary regression the plan requires. Do not apply that edit here.
- Evidence class: static diff. Raised by Grok. Astra read the shared hunks and reported no ordinary-family regression. That report is not adopted for this hunk because the coordinator re-read the before and after text. MiniMax did not read this hunk. Kimi read the shared hunks and did not flag this change.

### D7. Earlier NFT configuration and preview reject token IDs below 3

- Location: `MigrationLegacyNftLib.preview` rejects `tokenId_ < 3` after `requireSource`, which admits both the weighted collection and `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391`. `_configureNftEntitlements` applies `input_.tokenId < 3` without a collection test. The coordinator re-read both checks. Plan line 171 says reserved IDs are not user purchases for the weighted NFT only.
- Requirement: section 2.1's reserved-ID sentence is weighted-specific. Section 3 requires both NFT models as separate rows. Section 6 rejects burned or empty positions by actual state, not by an unstated earlier-collection id floor.
- Impact: an earlier-collection token 0, 1, or 2 cannot be configured or surrendered even if it has eligible shares and a matching wallet. If those ids are also reserved on the earlier source, the gate matches that source. That occupancy was not read.
- Fix direction: apply the floor only to the weighted collection unless earlier-source evidence shows the same reserved ids, and put that evidence in the missing source matrix. Do not apply the edit here. New-bond `ownerOf(0)`, `ownerOf(1)`, and `ownerOf(2)` checks are a different reserved-role rule and are not this finding.
- Evidence class: static source plus plan text. Raised by Grok. The other three did not raise it. Their silence is not a reading of earlier token occupancy.

### D8. The runbook's activation census does not match the sixteen-selector cut

- Location: `UniswapV4DetfMigrationAllocationTarget._administrationSelectors` allocates 16 selectors. The coordinator re-read that body. The two removable facets each declare eight functions, and members who compared them reported a match. The runbook says "all eleven" in the weighted-SY increment and "all twelve" in the earlier-receipt increment. The coordinator re-read both phrases.
- Requirement: section 6.1 and task 7 require the exact removable set and a selector census.
- Impact: the cut read in source removes sixteen administration selectors. An operator using the runbook's later sentences would under-count that set. This is a stale census, not a finding that a selector was left installed.
- Fix direction: regenerate the census from the deployed loupe after the final composition and remove the superseded counts. Do not apply that edit here.
- Evidence class: source plus runbook text. Raised by MiniMax. Astra and Kimi confirmed the sixteen-selector cut and did not treat the census mismatch as a cut defect.

### Examined mechanisms that are not a section 11 pass

On the paths the members read, Stage 1 surrender rejects before custody, the caller must be the stored original wallet, partial credit uses remaining-credit over remaining-units with the final unit taking residue, a two-contribution NFT can fund two bonds in one surrender, migration bonds use a 90-day cliff from creation, activation removes the installed administration selectors with the owning facet address, and the owner-paid first bond is a prerequisite. Those are static observations. No member ran the section 10 commands. They do not cancel D1-D8, and they do not establish section 11.

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| Historical parent-deployment gas | MiniMax treats the runbook's 42,985,865 and 44,353,454 figures, against a recorded 32,000,000 limit, as an open feasibility gate. Astra does not re-report that old figure as an unfixed current defect because the runbook opening now splits `prepareSyChildren` and `deployVault` and constrains each transaction to 32,000,000 gas. Kimi says source-level 32,000,000 call limits are not observed target-chain feasibility, and the runbook still leaves target gas open. | The coordinator re-read both the split-envelope opening and the closing sentence that target gas remains open. The historical monolithic figure is not proof that the current two-step deployment exceeds 32,000,000. Target-gas feasibility is still not demonstrated. No `verification.md` records a mined bound. |
| Unapproved operational awards | MiniMax treats the runbook statement that approved operational allocations are absent as fatal to section 11. Astra separates operational award approval and deployment permission from implementation completion. Kimi does not invent numerical allocations as requirements. | Unapproved award amounts are not, by themselves, D3. The plan withholds that approval. Unresolved route and integration rows remain D3. |
| Ordinary shared-hunk regression | Astra reported no ordinary-family regression in the 25 shared hunks. Grok reported the zero-output revert. Kimi read the hunks and did not flag it. MiniMax did not read the hunk. | D6 adopts the re-read diff. Astra's general report is not adopted for that hunk. Whether production quotes hit the dust case was not executed. |
| Whether examined money paths are defect-free | Astra and Kimi reported no specific money-loss defect on the activation, surrender, cliff, and reward paths they read. Grok reported D7. MiniMax reported no defect on gating, arithmetic, cliff funding, and wrong-wallet checks, and did not read the earlier-NFT floor as a defect. | D7 stands as a plan-text divergence with unread earlier occupancy. It is not a demonstrated theft. The no-defect reports are limited to the paths each member named. |

## Evidence gaps

- No member ran `forge build`, `forge test`, the fork profile, or the operator rehearsal. Supplied runbook and quote-evidence prose is supplied documentation, not observed runtime.
- The 241-file diff was not read hunk by hunk by any member. Astra left 168 files unread. Kimi left 143 unread. Those sets differ. Unread files block a positive correctness claim. They are not assumed defective.
- Earlier-collection token IDs 0, 1, and 2 were not read from a pinned source.
- Optional r20 PRD was not used to add requirements. Section 1 of the plan governed.
- Untracked incident inputs and `.omo/ulw-execute` files are outside the required diff and were not adopted as substitutes for the missing committed artifacts.

## Coverage adopted from responses

| Target | Status | Adopted from | Conflict or gap |
| --- | --- | --- | --- |
| Plan sections 1-11 | examined | all four | Checkbox state was re-read and is not the completion standard |
| Incident `migration/` artifact set | examined | all four, coordinator listing | Absence findings adopted |
| Snapshot library and quote-evidence disclaimer | examined | all four; disclaimer re-read | E3 not closed |
| Surrender, activation, cliff, and owner-first bond paths named by members | partially examined | all four, with different file lists | Static only; no executed rollback |
| Shared claim-lib direct-pair diff | examined by coordinator | Grok raised it; coordinator re-read the diff | Astra's no-regression report not adopted for this hunk |
| `execution.ts` and `preparation.ts` task-9 status | examined by coordinator for the cited lines | Kimi | Other members did not cite these lines |
| Remaining diff hunks | partially examined | member coverage tables | Named unread sets differ; no member examined every hunk |

## Limits

- Static, supplied-document, and coordinator-re-read claims stay distinguished. Nothing here is an observed test pass.
- This draft does not claim permission confinement.
- Original response files were read and are preserved.
- No project code, configuration, or Git action is authorized by this draft.
- Member agreement on the negative sentence is not proof that every unread file is correct or incorrect.
