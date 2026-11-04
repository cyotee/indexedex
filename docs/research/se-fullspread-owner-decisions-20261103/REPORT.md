# Owner decisions on the open findings

## Question

- Run ID: se-fullspread-owner-decisions-20261103
- Question: For each owner decision on F1 through F12, is there a problem with the decision, and did the owner misunderstand the recommendation?
- Profile: research
- Council kind: full
- Result label: full

## Authorization and scope

- Authorization source: explicit council directive
- Authorizing task or role: the owner asked the council to check these decisions for problems and misunderstandings
- Admitted read scope: the owner responses in the brief, the recommendation in `docs/research/se-fullspread-blockers-resolutions-20261103/REPORT.md`, the pretransfer directive, the blockers file, and the local protocol and access code cited below
- Inherited permissions: accepted. They are not extra authority and not a sandbox.
- Implementation authority: none. This report does not authorize edits, tests, installs, deployment, or Git.

## Participation

| Participant | Role | Requested model and reasoning | Actual model and reasoning | Task ID | Fresh or continued | Status | Identity source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Coordinator | invoking agent | invoking session model | not exposed | not exposed | continued | complete | Native status |
| astra | council-member | `chatgpt-subscription/gpt-6-astra:high` | `chatgpt-subscription/gpt-6-astra:high` | st_01a19fad | fresh, then continued for advisory | completed | Native status |
| grok | council-member | `xai/grok-4.7:xhigh` | `xai/grok-4.7:xhigh` | st_01a19fae | fresh, then continued for advisory | completed | Native status |
| minimax | council-member | `minimax/MiniMax-M3` | `minimax/MiniMax-M3` | st_01a19faf | fresh, then continued for advisory | completed | Native status |
| kimi | council-member | `kimi-coding/k3.1-pro:high`, global route | `kimi-coding/k3.1-pro:high` | st_01a19fb0 | fresh, then continued for advisory | completed | Native status |

- Coordinator mode: invoking-agent
- Actual mode equals requested mode: yes
- Missing initial responses: none
- Missing feedback: none

## Conclusions

F3, F4, F8, F9, F10, and F11 were accepted and were not misunderstood. F5 was accepted. Its sentence still has one wording gap, and that gap is not a misreading by the owner. F1, F2, and F6 contain misunderstandings. F7 and F12 are intentional changes. F7 is not yet one trigger. F12 replaces a lock and does not say so. F13, F14, and F15 were not decided.

### F1. Overstated maximum

Misunderstood: yes. Problem: yes. Changed the recommendation: yes.

The snapshot is a read of the vault's unbooked balance before the call uses it. It is not an ERC-20 transfer alert, and it does not identify who sent the tokens. The stated reason answers a mechanism the recommendation did not propose.

The non-atomic risk is already locked, and it is a different case. If the declared maximum is within the aggregate unbooked balance, another party's staged tokens may be used. That party took the risk. The recommendation did not stop that case.

The over-total case is still the locked rule, and the owner did not say it is replaced. If the maximum is larger than the unbooked balance, refund that balance and do not pull the shortfall (`docs/vaults/PRETRANSFER_DIRECTIVE.md` lines 9-11; blockers file lines 282 and 390).

Missing fact: when any declared maximum exceeds the available unbooked balance, does the whole call process no leg, including every bundle leg and a pretransferred `donate`, or does it process using the available balance?

### F2. Fees on a user route

Misunderstood: yes. Problem: yes. Changed the recommendation: no.

"Do not interleave `compound()`" matches the conclusion that was accepted. "Leave fees untouched" does not match "book any position fees their liquidity modification collects." A deposit that calls `modifyLiquidity` cannot leave accrued fees in the position. `Position.update` computes the owed fees and advances the fee-growth cursor (`lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol` lines 94-102). `PoolManager.modifyLiquidity` adds that fee delta to the caller's delta (`PoolManager.sol` lines 119-120 and 132). The withdrawal lock already books fees collected that way (blockers file line 256). The owner did not replace that lock. Fees left unbooked would sit in the unbooked balance and become the next caller's pretransfer credit.

Kimi records no misunderstanding and no problem. The reason is the unqualified acceptance of the conclusion, which Kimi reads as making "untouched" mean not credited, refunded, deployed, or compounded. That reading is preserved. It is not the only reading the words support.

Astra records the restatement as a change because it is an incompatible instruction beside an acceptance. That classification is preserved. The majority does not record a change, because the owner said the conclusion was correct and did not say the second sentence replaces it.

Missing fact: on a deposit, a bundle deposit, and a share-minting `exchangeIn`, are collected fees booked and not deployed, or is the fee delta left unaccounted?

### F3. Booked total

Misunderstood: no. Problem: no. Changed the recommendation: no.

The acceptance is the actual held balance, the zero-size skip, and revert on a failed step.

### F4. Position ratio

Misunderstood: no. Problem: no. Changed the recommendation: no.

The accepted definition is the token amounts a full-range liquidity unit consumes at the current square-root price and the stored ticks, excluding unpaid fees and booked balances, read immediately before the proportional add. It is not the price itself.

### F5. One-token swap size

Misunderstood: no. Problem: yes, in the accepted sentence. Changed the recommendation: no.

The owner accepted the sentence and did not restate it. The 48% remark is not read as a replacement of that acceptance.

The sentence still equates two amounts that are not the same. The processed token is spent on the swap and again on the following add. "The amount that add requires of the processed token" can be read as the swap's input cost, or as the amount the add itself consumes. Price movement and the swap fee make those different. That is a gap in the recommendation the owner accepted. It is not evidence that the owner misunderstood it.

### F6. Unconverted exit principal

Misunderstood: yes. Problem: yes. Changed the recommendation: no, for the exit sentence itself.

The accepted sentence is an exit rule. It converts all unwanted withdrawn principal into the selected token, or it reverts `AmountOutNotMet` and does not burn shares. Its first clause scopes the old no-revert sentence to the former sleeve. That scope has to travel with the acceptance. The already-locked list still says a redemption "does not have a leftover shortfall revert" with no sleeve limit (blockers file line 380).

The explanation is a different rule. It sizes a swap so the call keeps a remainder of the provided token. That is the deposit and donation shape already locked at blockers line 252 and in the pretransfer directive at line 11. A remainder on the exit is the residual the accepted sentence forbids. "As easy as swapping 48%" is a suggestion to investigate, not an adopted size. It does not replace the F5 acceptance, and fuzzing does not name the amount.

Astra records the qualification as a change of the exit sentence. The other three keep the exit sentence accepted and charge the explanation. Both readings are preserved.

Missing fact: does the remainder discussion belong only to a deposit or maintenance add, leaving the exit rule as accepted? If it is meant to qualify F5, does it withdraw the greatest-liquidity acceptance?

### F7. `Compounded()` and `Donation()`

Misunderstood: no. Problem: yes. Changed the recommendation: yes.

The owner did not accept the council predicate. Emitting because fees are deposited, rather than claimed, is their reason for a deployment trigger. It is not a misreading of a claim mechanism. Grok records a misunderstanding because that reason answers a mechanism the recommendation did not propose. That dissent is preserved. Astra, MiniMax, and Kimi record no misunderstanding.

The new rule names more than one trigger: emit `Compounded()` when booked tokens are deployed, and emit both `Donation()` and `Compounded()` when a donation also collects accrued fees. A booked balance includes a stray transfer and a non-atomic pretransfer, not only fees (blockers file line 254). The locked emission sentence says the event means fees were compounded into the reserve, and a maintenance call that compounds no fees does not emit (blockers file lines 234-240). Line 242 is a different sentence. It is the no-input, no-remainder return. The owner did not say the emission lock is replaced. The problem is the scope of the change, not the absence of a replacement formula.

`Donation()` is an intentional addition. It has no fields in the response. The absence of an existing event of that name is not a defect in the request.

Kimi records no problem and reads every booked deploy as the rule. That reading is preserved.

Missing fact: does `Compounded()` fire when booked tokens are deployed, when the call collects a nonzero fee, or only when both happen?

### F8. Seven-address write

Misunderstood: no. Problem: no. Changed the recommendation: no.

### F9. Selector row

Misunderstood: no. Problem: no. Changed the recommendation: no.

### F10. `donate` signature

Misunderstood: no. Problem: no, in the signature. Changed the recommendation: no.

The three-argument signature, the false-only share donation, and the argument-free `compound()` are accepted. The true branch says it uses F1. That execution waits on the F1 fact above. It is not a second signature defect.

### F11. Batch-swap routes

Misunderstood: no. Problem: no. Changed the recommendation: no.

Acceptance adopts the stated assumption. The one-token exit is single-output `exchangeBundleOut`.

### F12. Live `feeTo()`

Misunderstood: no. Problem: yes. Changed the recommendation: yes.

The reconsideration is explicit. Current `feeTo()` is to have owner controls after that value changes. That replaces the report's freeze. It is not a misunderstanding of the freeze.

It also collides with a lock the response does not name. Initialization sets the owner to the address returned by `feeTo()`, and that stored address is the owner `onlyOwnerOrOperator` uses (blockers file line 80, repeated in the already-locked list). The existing guard compares that stored owner, a global operator, or a function operator (`OperableRepo.sol` lines 213-216). It does not read `feeTo()`. A new modifier can. Reusing the existing function-operator setter unchanged would still leave a stored-owner check inside that setter (`OperableRepo.sol` lines 103-108). That is an integration constraint, not proof that the decision cannot be performed.

"If possible" conditions reuse of the Operable repo. It does not make operator authorization optional. Keeping the initialized address as a second owner is not an equally faithful reading of "the currently configured `feeTo()`." Grok still records that stored-owner question because the initialization sentence was not replaced. That dissent is preserved. The zero-address case was not decided in this response, and it is not assigned as a missing fact of this decision.

The decision needs to say, on the record, that it replaces the initialization-owner sentence.

### F13 through F15

Not decided. Silence is not acceptance.

## Evidence

| Item | Source | Class | Used for |
| --- | --- | --- | --- |
| Owner responses | `docs/research/se-fullspread-owner-decisions-20261103/brief.md` | coordinator-supplied | The decisions under review |
| Recommendation sentences | `docs/research/se-fullspread-blockers-resolutions-20261103/REPORT.md` | source observation | What was accepted or changed |
| Overstated refund | `docs/vaults/PRETRANSFER_DIRECTIVE.md` lines 9-11; blockers file lines 282 and 390 | source observation | F1 |
| Fee collection | `Position.sol` lines 94-102; `PoolManager.sol` lines 119-120 and 132 | source observation | F2 |
| Emission lock | blockers file lines 234-240 and 254 | source observation | F7 |
| No-revert sentence | blockers file line 380 | source observation | F6 |
| Initialization owner | blockers file line 80 | source observation | F12 |
| Operator guard | `OperableRepo.sol` lines 103-108 and 213-216 | source observation | F12 |
| Member responses and feedback | `members/*/response.md`, `members/*/feedback.md` | source observation | Classifications and dissent |

No public query was used. Private excerpts were not sent to a search service. The fee-delta read was not executed.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| Owner responses F1-F12 | required | examined | Each has a classification |
| Recommendation report | required | examined | Compared with each response |
| F13-F15 | required as a silence record | examined | Not decided |
| Pretransfer directive and blockers file | optional | examined | Used where a decision met a lock |
| PRD | optional | not examined as an edit target | Not edited, and not used as authority over a lock |

## Disagreement and missing responses

- Disagreement: F2 on whether "untouched" is a misunderstanding; F5 on whether the accepted sentence's amount identity is a problem; F6 on whether the explanation changes the exit sentence; F7 on misunderstanding and on whether every booked deploy is copyable; F12 on whether the stored owner remains an open question.
- Dissent carried into this report: Kimi on F2 and F7; Astra on F2's change classification, F5, and F6; Grok on F7's misunderstanding and F12's stored-owner question.
- Missing responses treated as approval: no
- Feedback used as a missing initial response: no

## Advisory review

- Draft ID: draft-se-fullspread-owner-decisions-20261103-r1
- Draft path: `coordinator/draft.md`
- Resolution path: `coordinator/resolution.md`
- Feedback dispositions: astra requested-changes; grok requested-changes; minimax requested-changes; kimi requested-changes
- Post-review wording changes: the F1 fact, the F4 definition, the F5 wording assessment, the F6 scope and 48% distinction, the F7 classification and citation, and the F12 lock collision
- Those changes are member-approved: no

## Limits

- This report does not edit the blockers file, the PRD, or the prior resolution draft.
- It does not authorize implementation.
- The fee-collection reads were not executed.
- F13 through F15 were not answered.
