# Clarification questions

## Identity

- Run ID: se-fullspread-plan-execution-20261104
- Follow-up ID: questions-se-fullspread-plan-execution-20261104-r1
- Member label: minimax
- Phase: clarification questions
- Requested role: council-member
- Requested model and reasoning: minimax/MiniMax-M3, admitted adaptive thinking
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued
- Documents read in this pass: `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md` and `docs/reviews/se-fullspread-plan-execution-20261104/coordinator/questions-assignment.md`. No other file was read.
- Peer questions read: no
- Question count: 4

## Questions

Each question below identifies a place where the published PRD leaves a decision unmade, so that two careful readers of the PRD would act on it differently. No question here files a new defect, and none asks to reopen an item the PRD already lists as unresolved.

### Q1 - Which amount is the comparison basis for the one-token exit minimum

- PRD section: "Findings, F2" (Impact and Fix direction) and "Recommendations", first bullet
- The two readings: (a) the caller's minimum is compared against the swap's actual proceeds, that is the wanted-token amount the pool produced, so a shortfall between the quote and the pool reverts `AmountOutNotMet`; (b) the minimum is compared against the recipient's receipt, that is the token balance increase at `recipient`, so the check passes whenever the recipient ends up holding at least the minimum. The two readings diverge whenever the vault retains residue of the wanted token, whenever the recipient already held that token before the call, or whenever the pool's delivered amount differs from the amount credited to the recipient.
- Why the PRD does not settle it: F2 records that the current code compares the minimum with `plan.amountOut` before execution and then pays that same planned amount, and it states that a shortfall between the quote and the pool "is inference, not an observed result". Its Fix direction then asks the reader to "say whether that amount is the swap proceeds, the recipient receipt, or both". The first Recommendation bullet tells the reader what not to describe, but it never states the basis on which the comparison should be made, and the "amountOut" value the vault reports to the caller is left equally unassigned between the two.
- The one answer that removes the split: state the single basis for the comparison and for the reported `amountOut`, as one of the swap proceeds, the recipient receipt, or both, and say whether the other quantity is also checked.

### Q2 - Whether plan section 4's "component" sentence covers the six infrastructure addresses, and what follows for F5 either way

- PRD section: "Findings, F5" (Impact and Fix direction) and "Recommendations", third bullet
- The two readings: (a) "component" in plan section 4 covers every binding the package stores, so `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, and `universalRouter` must each be rejected with `InvalidComponent` when code-empty, exactly as the facets and linked libraries are; (b) "component" covers the diamond cut and the linked libraries only, so those six are ordinary configuration addresses and need no code-empty check. The PRD states the coordinator's reading (a) as a reading and records that it "is not a quotation Grok accepted".
- Why the PRD does not settle it: the third Recommendation bullet asks the reader to "Decide explicitly whether the six infrastructure addresses are components that must be code-checked", and F5's Fix direction is conditional on the same point ("if the plan's component sentence covers them"). The PRD does not say which answer is adopted, and it does not say what happens to F5 under the other answer: F5 currently sits in "Findings" with no conditional marker, so a reader who takes reading (b) must decide on their own whether the finding stands as a defense-in-depth item or is withdrawn as unsupported by the plan.
- The one answer that removes the split: state whether plan section 4's component sentence covers the six stored infrastructure addresses, and state whether F5 stands as a defect to remediate under either answer or only under the answer that includes them.

### Q3 - Whether remediating `Package.t.sol` includes completing FS-A16, and if not, which file carries the missing half

- PRD section: "Findings, F9" (Invariant or requirement, Impact, and Fix direction) and "Recommendations", sixth bullet
- The two readings: (a) the Fix direction is the complete instruction for this file, so the remediation is the missing FS-A01 through FS-A04 assertions and FS-A16 stays as it is, since the PRD calls FS-A16 "partly present" rather than missing; (b) the same PRD paragraph states that plan section 13 assigns FS-A01 through FS-A04 and FS-A16 to `Package.t.sol`, and FS-A16's own requirement has two halves, "issuance does not read `exchangeRate`" and "`getRate` is absent", of which only the second is covered by the current file, so a reader who adds only FS-A01 through FS-A04 leaves the file still not carrying its assigned row and must add the issuance half as well.
- Why the PRD does not settle it: F9 names FS-A16 in the assigned set and records that it "is not rejected and it is not fully covered", then directs only "Add the missing FS-A01 through FS-A04 assertions". The sixth Recommendation bullet likewise names only the FS-A01 through FS-A04 assertions. The PRD never says whether FS-A16's remaining half is part of this remediation, and it names no other file as its destination.
- The one answer that removes the split: state whether the `Package.t.sol` remediation must also complete FS-A16's issuance half, and if it must not, name the file that carries it.

### Q4 - Which routes the standalone and composed gas measurements must cover, and where the composed measurement lives

- PRD section: "Findings, F11" (Invariant or requirement, Impact, and Fix direction) and "Recommendations", sixth bullet
- The two readings: (a) the standalone measurement is one case per money or maintenance call named in the plan's six routes, and the composed measurement is a single composed-route case added to `BufferHookIntegration.t.sol`, the only composed file the PRD's Impact names as lacking a ceiling; (b) the composed rule applies per composed hook route, so the measurement must be added to each of the row files named in plan section 12 in addition to or instead of `BufferHookIntegration.t.sol`, and the standalone set must be the specific six money and maintenance routes rather than an unspecified selection of public calls.
- Why the PRD does not settle it: F11's Impact reports only that a text search found no ceiling in `Money.t.sol` and `BufferHookIntegration.t.sol`, and its Fix direction says "Add the standalone and composed measurements the plan describes". The PRD does not enumerate the six standalone routes, does not say whether the composed measurement is one case or one per route, and does not name the files that must carry it. A reader who takes reading (a) produces a smaller test set than a reader who takes reading (b), and the two sets cannot both satisfy the quoted rule.
- The one answer that removes the split: enumerate the standalone routes the measurement must cover and state whether the composed measurement is a single case or one per composed route, naming the file or files that must carry each.

## Not filed

- The unresolved list in the PRD ("Unresolved, not adopted and not rejected"), including the exit projection, the zero-liquidity floor path, the identity-bind and partial-consumption assertions, the classification of recorded rejections, the share-burn allowance reading, the native credit receipt, the repo-wide migration, and the index line anchors. Each is already named as unresolved or as a non-finding in the PRD, and the PRD states the limit it draws for each. Re-asking any of them would reopen an item the PRD already handles.
- F3, F4, F7, F9's selector-cut assertions, and F10's assertion content. In each case the PRD either quotes the governing plan sentence and states the branch outcome, or states the decision the reader must make. They leave no split for a later reader to resolve.
- Anything about targets 2-42 or 44-48, the section 13 test-plan coverage, or the completeness of the finding set. The PRD states those limits in "Question", "Coverage", and "Limitations".

## Limits

- Static reading only. No compile, test, gas measurement, install, deployment, or Git action was run in this pass, and none is authorized by this file.
- These questions are about the published PRD's text, not about the reviewed project's code. No project file was opened in this pass, and no question here asserts a defect in the tree.
- Peer questions, peer responses, and peer feedback were not read. Nothing in this file is adopted from another member.
- This file does not replace the PRD, does not amend the plan, the draft, or the resolution, and does not authorize implementation. It states questions for the coordinator to resolve in the PRD or to carry forward.
- Coordinator changes after this pass belong in the PRD and its publication record. They are not member-approved text.
- Assignment boundary: this file authorizes no edits outside `members/minimax/questions.md`, no project code or configuration change, and no Git action.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
