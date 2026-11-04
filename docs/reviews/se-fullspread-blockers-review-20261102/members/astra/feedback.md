# Astra advisory feedback

## Identity

- Member: astra
- Profile: review
- Phase: advisory feedback
- Requested role: council-member
- Requested model: `chatgpt-subscription/gpt-6-astra:high`
- Runtime role, model, provider, reasoning setting, and task identity: not exposed as independently identified runtime metadata.
- Peer feedback read: no.

## Draft under review

- Draft ID: `draft-se-fullspread-blockers-review-20261102-r1`
- Exact file read: `docs/reviews/se-fullspread-blockers-review-20261102/coordinator/draft.md`
- Fingerprint: not computed. No hash was computed.
- The complete draft was readable. No alternative draft or other file was read for this advisory.

## Disposition

requested-changes

## Accuracy of my findings

The draft accurately carries the main concerns about observable share scaling (D9), reserve composition (D3), maintenance event predicates (D10), batch-swap scope (D13), and the maintenance/user-input distinction in the matrix (D6). It preserves that I did not independently raise the genesis cross-lock in D1 or the authorization-identity finding in D8.

However, D4 combines my unbacked-maximum finding with a staged-pretransfer objection I expressly did not adopt, then states a clipped-input remedy that does not settle the refund problem. D2, D5, D15, and D17 omit load-bearing parts of my original findings. Several fix directions also read as decided product requirements rather than advisory directions. The corrections below do not select answers to those product questions.

## Corrections by draft section

### D4. Separate the accepted non-atomic risk from the unresolved maximum/refund contract

The draft itself quotes the lock accepting that a non-atomic pretransfer can be booked. My original coverage explicitly treated that risk as accepted, not as a new defect. D4's statement that another implementation leaves staged funds unbooked "as B-13 requires" treats an exchange-call attribution rule as a maintenance prohibition without establishing that scope.

Preserve the differing member positions, but do not represent the staged-transfer objection as my finding or ask for acceptance as though no acceptance were recorded. Identify any claimed surviving contradiction separately from the accepted non-atomic risk.

The final fix direction, "use the unbooked balance and do not pull the difference," selects an outcome without defining the refund base. My example concerned a maximum of 100, available unbooked input of 60, and use of 40: refunding maximum minus used still demands 60 after 40 has been spent. Merely limiting the input considered for execution does not reconcile that with exclusion of booked funds.

Replace the declarative remedy with the unresolved requirement: the backing condition, admitted input amount, refund base, and failure behavior must agree. Do not silently choose clipping, rejection, or a revised maximum definition.

### D2. Restore the omitted share-donation branch and distinguish advice from a lock

D2 captures the underlying gift plus opposite booked-token case. It omits the other load-bearing branch of my R2: a share donation is said to burn shares and not run the swap, while the booking lock says unqualifiedly that `donate()` also compounds.

Add the question of whether a share donation enters maintenance processing of underlying fees and booked balances, and how the no-swap sentence applies to that processing. Otherwise two implementors can still disagree after D2's underlying-donation example is resolved.

The direction "the booking rule governs" currently reads as a resolution. Identify it as a proposed reconciliation, or ask for authoritative scope and precedence. This feedback does not choose that precedence.

### D5 and D10. Preserve the zero-addable-liquidity execution outcome, not only its event

D5 includes my concern about exact exhaustion versus dust. D10 mentions a maintenance call that deploys nothing, but only asks whether it emits.

My R5 also required an execution contract for a positive combined balance that produces no addable liquidity: how the best-effort/no-revert requirement and exact-exhaustion language apply to that state. Naming the event does not settle whether the operation succeeds and books the balance or fails before reaching the event predicate.

Carry that branch explicitly in D5 and cross-reference it from D10. Do not select its result in this advisory.

D5 also directs a particular scarcity definition while "Not a defect" says the draft does not choose the scarcer-token formula. Make the recommendation's status consistent across those sections rather than presenting it as an already locked answer.

### D15 and D14. Restore the complete public ABI/package-schema finding

D15 reduces my R8 mainly to listing the seven component getters. My finding also covers:

- The complete position-facet getter manifest, including whether and how salt is exposed.
- Getter signatures, return types, and layouts.
- Final package field names, types, ordering, and initialization sources for the new inputs.

These are observable ABI choices; naming the stored components does not close them. D14 resolves only the existence of the WETH package field, not the broader schema.

Restore those requirements under D15 or a separately named subsection. D14's attribution should also distinguish my acceptance of internal storage-home freedom from my requirement that the eventual public package schema be explicit. I did not treat an unspecified public schema as harmless.

The proposed single-copy and `StateView` directions may be coordinator recommendations, but this advisory does not independently verify or adopt them from source.

### D12. Distinguish unsupported routes, supported-quote failures, and EVM exhaustion

My R9 did not infer that every failed supported preview returns zero. Zero was specified for unsupported routes; B-06's explicit out-of-gas exception was already part of the reviewed text.

D12 should preserve those categories rather than treating zero, a deliberate revert, and EVM exhaustion as three interchangeable implementor choices. State the unresolved boundary for a supported quote that cannot finish, including any lower-level failure, without enlarging the unsupported-route zero rule or reopening the already stated EVM exception.

The draft correctly avoids making the quote algorithm itself an owner decision unless it changes observable behavior.

### D16. Do not turn a required rewrite activity into a new pre-rewrite gate

My B-08 coverage treated consumer enumeration as an explicit obligation of the comprehensive PRD pass, not a defect caused by its absence from the blockers file. D16 acknowledges that distinction but then says the pass starts only once the list exists.

That changes the stated sequencing. Keep the consumer inventory as required work that must be completed and incorporated during the authorized comprehensive pass before its result is treated as complete. If a separate prerequisite is proposed, label it as a proposed workflow change, not an existing lock or my finding.

The spot-checked source claims remain coordinator evidence. I did not re-open or independently verify them during this draft-only advisory.

### D17 and Coverage adopted from responses. Restore the B-03 summary defect and correct attribution

My R10 specifically flagged B-03's concluding "a no-fee `compound()` returns unchanged" because it omits the booked-remainder exception. D17 omits that correction, and the coverage table labels B-03 consistent for all four members.

Distinguish the consistent empty-call decision line from the defective no-fee summary. Add the summary correction to D17 and amend coverage accordingly. D10's event discussion does not replace this processing requirement.

The N-03 coverage row attributes the defect only to Grok even though D6 itself identifies Kimi and my R10. Align the table with that prose.

### D9 and the PRD invalidation table. Separate the share-unit defect from the metadata question

D9 accurately represents my optional stored-balance scaling finding. My R1 did not independently conclude that the retained `decimals() = 18` requirement had become unspecified.

The draft can require the selected share-unit policy to be consistent with metadata, but should identify any claim that metadata itself must be reopened as an additional inference, not as part of my finding. The invalidation table should not imply that my review withdrew an existing metadata requirement.

## Omitted load-bearing findings

The omissions needing explicit restoration are:

| Draft section | Omitted part of my original finding |
| --- | --- |
| D2 | Whether share donation also processes underlying maintenance inventory despite the no-swap sentence. |
| D5, with D10 cross-reference | Execution and booking behavior when positive inventory produces no addable liquidity, separately from event emission. |
| D15, with D14 cross-reference | Complete position getter ABI and complete package input schema, not only component getter names. |
| D17 and coverage | B-03's no-fee summary can suppress required remainder-only processing. |

## What was not adopted from others

I did not read peer feedback or reopen peer responses. The draft's attributed positions are not independent evidence that I endorsed them.

I do not adopt the staged-pretransfer objection as an unaccepted risk, the new pre-rewrite consumer-list gate, or the draft's declarative product resolutions. Findings newly attributed to other members remain their or the coordinator's findings; this advisory does not supply source verification or a product answer for them.

## Limits

This advisory used only the complete named draft and the existing conversation context. No hash, source lookup, peer-feedback read, sub-agent, Forge run, test, install, or Git operation was performed. Only `members/astra/feedback.md` was written.

The corrections concern fidelity, completeness, and the distinction between a finding and a proposed resolution. They do not answer the open product questions and do not demand another council round.

This feedback does not authorize implementation, does not authorize a PRD edit, and does not replace the draft.
