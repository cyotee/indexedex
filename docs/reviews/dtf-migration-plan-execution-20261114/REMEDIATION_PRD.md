# Remediation PRD

## Question

- Run ID: dtf-migration-plan-execution-20261114
- Question: Did the committed changes from `90ff0307a7a8e084aa073e02eff125e9c7973933` to `c33f70683cbaabfedc2dbce1142fdd65660d4cf3` completely and correctly execute `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`, revision `migration-detf-implementation-plan-r7-token-staking-migrated-exposure`, including sections 1-11 and the section 11 completion standard?
- Profile: review
- Council kind: full
- Result label: full

Answer: no. The 24 commits did not completely and correctly execute the plan. Section 11 is not met. This PRD does not authorize implementation.

## Authorization and scope

- Authorization source: explicit council directive
- Authorizing task or role: the user asked the Council to review the latest repository changes against the named plan
- Required targets: the plan, and the explicit diff `90ff0307a7a8e084aa073e02eff125e9c7973933..c33f70683cbaabfedc2dbce1142fdd65660d4cf3` (24 commits, 241 files, 38251 insertions, 175 deletions, no deletions)
- Optional context: `MIGRATION_DETF_DRAFT_PRD.md` was supplied and was not used to add requirements. Section 1 of the plan governed
- Inherited permissions: accepted. They are not extra authority and not a sandbox
- Implementation authority: none. This PRD does not authorize edits, reviewed-project tests, installs, deployment, or Git

## Participation

| Participant | Role | Requested model and reasoning | Actual model and reasoning | Task ID | Fresh or continued | Status | Identity source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Coordinator | invoking agent, not a vote | invoking current model | xai/grok-4.7, xhigh | not exposed | continued | synthesis attempt 1 | session environment |
| astra | council-member | `chatgpt-subscription/gpt-6-astra:high` | chatgpt-subscription/gpt-6-astra:high, high | st_01a1d9e3 | fresh, then continued for feedback | initial and feedback settled | task status |
| grok | council-member | `xai/grok-4.7:high` | xai/grok-4.7:high, high | st_01a1d9e4 | fresh, then continued for feedback | initial and feedback settled | task status |
| minimax | council-member | `minimax/MiniMax-M3`, admitted adaptive thinking | minimax/MiniMax-M3, adaptive payload not exposed | st_01a1d9e5 | fresh, then continued for feedback | initial and feedback settled | completion notification |
| kimi | council-member | `kimi-coding/k3.1-pro:high`, global route | kimi-coding/k3.1-pro:high, high | st_01a1d9e6 | fresh, then continued for feedback | initial and feedback settled | task status |

- Coordinator mode: invoking-agent
- Actual mode equals requested mode: yes
- Missing initial responses: none
- Missing feedback: none

## Findings

### F1. Named completion artifacts are absent

- Location: at `c33f70683cbaabfedc2dbce1142fdd65660d4cf3`, `docs/incidents/2026-09-16-dtf-recovery/migration/` contains `operator-runbook.md` and `quote-evidence.md` only. Members checked `git ls-files`, `git ls-tree`, or `git cat-file -e`. The coordinator's directory listing matched that pair. Absent: `source-manifest.json`, `source-route-matrix.md`, `surrender-spec.md`, `package-evidence.md`, and `verification.md`. No fork-run receipt set is in that directory.
- Invariant or requirement: plan task 1 evidence, task 3 `package-evidence.md`, task 10 `verification.md`, section 10, and section 11's requirement that tests and the resumable rehearsal demonstrate the facts
- Impact: the plan's named source-closure, package-reconciliation, and execution records are not in the committed tree. Test filenames and commit subjects do not replace them. Section 11 is unmet on that ground alone
- Fix direction: write those files from the execution being claimed, including commands, compiler, revision, exits, summaries, gas bounds, and pre-existing failures. Do not treat this review as that record
- Evidence class: static absence, corroborated by all four initial responses and not challenged in feedback
- Dissent on this finding: none among received responses

### F2. Committed quote evidence does not close E3

- Location: `docs/incidents/2026-09-16-dtf-recovery/migration/quote-evidence.md` lines 1-8 and the remaining-limits section beginning at "There is no identified production recovery binding", re-read by the coordinator. Members who read `UniswapV4DetfMigrationSnapshotLib.sol` reported a bounded direct-pair, recognized V3-deposit, raw-DETF evaluator with no live preview fallback inside evaluation
- Invariant or requirement: task 2 and gate E3 require a frozen evaluator for the actual configured reserve and routes, with differential vectors in `quote-evidence.md`
- Impact: the file says the bounded increment is not completion of task 2, E3, the full plan, or lifecycle integration. It also says several nested quote models are not certified. A correct limited evaluator is not E3 closure for the recovery reserve
- Fix direction: pin the actual recovery composition and either close every reachable nested model with frozen vectors or record the unsupported domain as an E3 blocker. Do not delete the disclaimer while it is accurate
- Evidence class: document text re-read, plus member source reads
- Dissent on this finding: none among received responses

### F3. Source-closure evidence is missing, and the operator record still lists open gates

- Location: `operator-runbook.md` section `Required categories still blocked`, re-read by the coordinator. It lists TokenStaking raw weight, underlying SE shares, fungible LP, earlier liquidation, and other rows, and says full original task 9 and release remain open. The named source matrix that would reconcile those rows with later code is the absent task 1 artifact in F1
- Invariant or requirement: section 3 and task 1. Unresolved rows prevent full implementation completion. A source with no exposure must be proved absent. Sections 1.6 and 1.8 admit claimed-SY preparation for TokenStaking and do not treat a staking weight as an ERC20 pull. Section 11 requires every required legacy source to be supported with configured original-wallet surrender and conservation, or a concrete recorded blocker
- Impact: adapter code for several categories was read. That does not close the rows. The historical table is not, by itself, proof that every listed category lacks a current adapter. It is proof that the committed operator record still reports open gates, while the artifact that would distinguish superseded history from current blockers is absent. Closing the TokenStaking row means the section 1.8 preparation record or a concrete blocker, not a raw-weight approved pull
- Fix direction: produce the source manifest, route matrix, and surrender spec. For each row, record current executable evidence or a concrete blocker. Do not invent approved numerical awards. The plan already leaves those amounts as separate execution inputs
- Evidence class: runbook text re-read, plus verified artifact absence. Narrowed after feedback
- Dissent on this finding: MiniMax's initial response treated the whole table as fatal to section 11. Astra and Grok asked not to over-read it. The final adopts the narrower reading. The section 11 failure remains because the required closure artifacts are absent

### F4. The operator implementation reports task 9 open

- Location: `scripts/recovery/dtf-migration/execution.ts` lines 98 and 185 return `fullTask9: "open"` on the simulate path and the receipt path. `preparation.ts` line 110 sets the same field, and line 134 writes it into `blocked.json`. The coordinator re-read those lines. The runbook repeats that full original task 9 remains open
- Invariant or requirement: task 9 and section 11 require a resumable rehearsal that demonstrates the facts
- Impact: these strings are what the program reports. They corroborate that this tree does not claim task 9 closed. They are not an independent observation that a particular rehearsal step failed. Together with the absent `verification.md`, the rehearsal half of section 11 is not demonstrated
- Fix direction: change the status only after the rehearsal the plan describes has been demonstrated and recorded. Changing the literal alone does not close the task
- Evidence class: source observation. Narrowed after feedback from a behavioral-failure claim to a self-report
- Dissent on this finding: none on the lines. Astra asked that they not be treated as independent behavioral proof. That request is accepted

### F5. The planned adversarial TestBase is absent

- Location: plan section 4 names `TestBase_UniswapV4DetfMigration_Adversarial.sol`. `git ls-files` found no such path. `TestBase_UniswapV4DetfMigration.sol` is present
- Invariant or requirement: the named section 4 adversarial base
- Impact: the named file was not delivered. Other invariant and hostile-contribution tests exist. They were not established as a substitute, and no test was run
- Fix direction: add the named base, or record in a later authorized plan revision which catalog cases now live elsewhere. Do not add an empty alias to satisfy the filename
- Evidence class: verified absence
- Dissent on this finding: none. MiniMax's initial response did not name the file. MiniMax's feedback adopted the absence

### F6. Target-gas feasibility is not demonstrated

- Location: runbook section `Bounded deployment and interrupted preparation`, read by the coordinator. It requires `prepareSyChildren` before `deployVault` and constrains deployment simulation, estimation, signing, and resumed intents to 32,000,000 gas per transaction. The same file's closing paragraph still says target gas remains open and records a prior parent deployment of 44,353,454 gas. No `verification.md` records a mined bound for the current two-step path
- Invariant or requirement: task 10 requires operational limits from measured gas and target-chain limits, not a permissive local cap
- Impact: the historical monolithic figure is not a measurement of the current two-step deployment. The current envelope is also not an observed target-chain receipt. Feasibility remains open
- Fix direction: measure the current preparation and finalization transactions, and the selected batch operations, under the target-chain limit, and record those receipts. Do not treat the old 44,353,454 figure as that measurement
- Evidence class: supplied documentation, re-read. Not a test run
- Dissent on this finding: MiniMax's initial response treated the old figures as a current exceedance. MiniMax's feedback withdrew that reading. Astra declined to revive the old figure. The final follows the feedback correction

### Not adopted: shared direct-pair zero output

The draft's D6 said the shared quote newly reverts where it used to return zero. That claim is not adopted.

The coordinator re-read `_outputBudget` at `90ff0307a7a8e084aa073e02eff125e9c7973933`. After the direct-pair branch, the old function executed `if (amountOut == 0) revert Math.ZeroAmount()`. The current function still has that tail, and `rawOutput` at lines 159-163 also reverts `Math.ZeroAmount` at line 162 before returning to the tail. Moving the check into the helper does not change the direct-pair zero outcome. Do not restore a zero return. The draft's line citation 156-160 was wrong; those lines are the tail of `exactInputBudget`.

Grok's feedback supported the draft's D6 restatement. MiniMax's feedback treated the branch-local delta as real. Those positions are not adopted for the external outcome. They do not affect the section 11 answer.

### Not adopted: earlier NFT id floor as a demonstrated defect

`MigrationLegacyNftLib.preview` and `_configureNftEntitlements` apply `tokenId < 3` to both admitted collections. Plan line 171 reserves non-user IDs for the weighted NFT only. Earlier-collection occupancy of IDs 0, 1, and 2 was not read. If those IDs are reserved on the earlier source, the floor can be faithful. If they are eligible purchases, the floor can exclude them. That question stays unresolved. It is not an adopted eligibility defect. The missing source matrix in F1 is the completion blocker either way. New-bond `ownerOf(0)`, `ownerOf(1)`, and `ownerOf(2)` checks are a different reserved-role rule.

### Not a section 11 pass

On the paths members read, Stage 1 surrender rejects before custody, the caller must be the stored original wallet, partial credit uses remaining credit over remaining units, migration bonds use a 90-day cliff from creation, and activation removes sixteen administration selectors using each selector's owning facet address. Those are static observations. No council member ran section 10. They do not establish section 11.

### Runbook selector counts

The runbook's weighted-SY increment says "all eleven" and the earlier-receipt increment says "all twelve". The implementation's `_administrationSelectors` allocates 16, and members who compared the two removable facets reported an 8-plus-8 match. The cut read in source is not the defect. The operator record lacks one current census that a reader can identify as the current sixteen-selector set, and the older counts are not labeled superseded. Add or point to a current loupe census and label the historical counts. Do not delete the historical record to hide the earlier composition.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| Plan sections 1-11 | required | examined | All four members read the plan. Checkbox state was not used as the completion standard |
| Explicit diff, 241 files | required | partially examined | Astra left 168 files unread. Kimi left 143 unread. The sets differ. No member read every hunk |
| Incident `migration/` artifact set | required as plan evidence | examined | Absence re-checked |
| Snapshot library and quote-evidence disclaimer | required for E3 | examined | Disclaimer re-read |
| Surrender, activation, cliff, and owner-first bond paths named by members | required for the mechanisms section 11 names | partially examined | Static only. Different members read different files |
| Shared `_outputBudget` old and new full functions | required to judge D6 | examined by coordinator after feedback | D6 not adopted |
| `execution.ts` and `preparation.ts` cited task-9 lines | required to judge the self-report | examined by coordinator | Lines match |
| Optional r20 PRD | optional | not examined as a spec | Section 1 governed. Absence of a PRD reading is not a missing requirement |
| Untracked incident inputs and `.omo/ulw-execute` | not a target | not examined | Outside the required diff |

## Disagreement and missing responses

- Disagreement: Grok and MiniMax supported a branch-local reading of the zero-output hunk that the final does not adopt. MiniMax's initial gas reading was withdrawn in feedback. The blocked-category table was narrowed after Astra and Grok. No received member asked to reverse the negative section 11 answer
- Dissent carried into this PRD: the branch-local zero-output reading, recorded under the not-adopted D6 note
- Missing responses treated as approval: no
- Feedback used as a missing initial response: no

## Advisory review

- Draft ID: draft-dtf-migration-plan-execution-20261114-r1
- Draft path: `docs/reviews/dtf-migration-plan-execution-20261114/coordinator/draft.md`
- Resolution path: `docs/reviews/dtf-migration-plan-execution-20261114/coordinator/resolution.md`
- Feedback dispositions: astra requested-changes; grok support-with-reservations; minimax support-with-reservations; kimi requested-changes
- Concern outcomes: A1, A2, A3, A4, A5, G1, M1, M3, K1, and K2 accepted. M2 accepted as a locator correction. The D6 regression claim those locators were attached to is rejected
- Post-review wording changes: the final narrows F3 and F4, recasts the id floor as unresolved, rejects the zero-output regression, and corrects the `rawOutput` line citation
- Those changes are member-approved: no

## Recommendations

- Do not treat `90ff0307..c33f7068` as execution of the plan
- Produce the five absent evidence files from an actual authorized run, or change their names only in a later authorized plan revision
- Keep the quote-evidence disclaimer until an actual recovery composition is closed or explicitly blocked
- Close TokenStaking through the admitted claimed-SY preparation record or a concrete blocker, not a raw-weight pull
- Measure the current two-step deployment against the 32,000,000 envelope and record the receipts
- Do not restore a zero direct-pair return. The old function already reverted
- Do not decide the earlier NFT id floor until pinned occupancy is read
- These recommendations do not assign an implementation task and do not authorize a change

## Limitations

- This was a static review. No `forge build`, `forge test`, fork suite, or operator rehearsal was run by the council. Supplied runbook and quote-evidence prose is supplied documentation, not observed runtime
- The 241-file diff was not read hunk by hunk. Unread files block a positive correctness claim. They are not assumed defective. The negative section 11 answer does not depend on them
- Earlier-collection token IDs 0, 1, and 2 were not read from a pinned source
- MiniMax adaptive-thinking was admitted in `models.json`. The payload of the completed call was not exposed
- Member agreement on the negative sentence is not proof that every examined path is free of defects
- Raw HTML was not used. No PDF extraction was used
- This PRD does not claim permission confinement

## Publication

- Publication state: published
- Final path or chat-only statement: `docs/reviews/dtf-migration-plan-execution-20261114/REMEDIATION_PRD.md`
- Cooperative update: none. The plan was not edited
- Unrelated edits preserved: yes. No project code or plan text was changed
- Model work repeated for publication: no
- Git actions: none
- Artifacts retained until explicit deletion: yes
