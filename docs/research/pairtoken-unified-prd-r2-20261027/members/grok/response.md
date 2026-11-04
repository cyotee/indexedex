# Grok authoring response

## Identity

- Participant: Grok.
- Role: council-member. This is not a coordinator vote, and it is not a vote for any other member. The invoking session also using a Grok model does not make this response the coordinator's.
- Run ID: pairtoken-unified-prd-r2-20261027.
- Profile: research. This is an authoring contribution. It is not a defect review and not an advisory pass.
- Requested model and reasoning: xai/grok-4.7:xhigh. No model, account, or provider was substituted by this member.
- Owned response: docs/research/pairtoken-unified-prd-r2-20261027/members/grok/response.md.
- Fresh context: yes. Peer responses were not read.
- Admitted r1: docs/research/pairtoken-unified-prd-20261027-01a17e03/handoff/PRD.md, identity pairtoken-unified-prd-r1.
- Assigned raw SHA-256: 1824df69b7f64cc15252a7ae877d3b3f762773db5bfc4f091591eb1af8a7f6d2.
- Recomputed raw SHA-256 over the file bytes, not over read-tool text: 1824df69b7f64cc15252a7ae877d3b3f762773db5bfc4f091591eb1af8a7f6d2. Match: yes. Size: 95049 bytes, 641 lines, LF endings, no CR.
- This contribution does not authorize implementation.

## Question and targets

Question: What exact standalone prose integrates every authorized accuracy clarification into one complete Pair Token PRD, without adding behavior or requiring any companion file?

Target of the prose: the complete r1 text, integrated by the coordinator into one new document, identity pairtoken-unified-prd-r2. r1 stays an unchanged archive. A reader of r2 must not need the accuracy report, r1, source, or the council brief.

The only behavioral wording changes are the seven authorized clarifications:

1. L1. In PT-EXIT-01, after the caller burn, the checked payout is calculated before the position-liquidity read. Keep PT-ERROR-02 and the formulas.
2. L2. In PT-MATH-02, the amount0 function sorts its endpoints and the amount1 function uses the absolute endpoint difference. Do not change the integer formulas.
3. L3. At the equal-bounds sentence in PT-MATH-03 and in PT-AC-55, distinguish the MD helper's unadorned revert from the initialization division failure. Do not assert an unexecuted panic selector. Do not add a guard.
4. L4. In the Add callback row, say nonnegative liquidity modification, and keep the express permission for zero.
5. L5. In PT-COMP-03, both notify catches are catch-all external-call failures, including custom errors, Panic, and empty reverts. Do not say fee-manager failure can never block users. Keep the existing list of failures that are not caught.
6. L6. New normative wording, not a claim about r1: native payout is an empty-calldata CALL forwarding remaining gas, and the paired refund is an empty-calldata value call forwarding remaining gas. Neither is a 2300-gas stipend. Keep the existing failure modes. Do not put a compilation disclaimer in the PRD.
7. L7. New normative wording: the consumed single-slot extsload read and the token balanceOf idle read are view static calls. Do not add a new guard against a non-view dependency.

No other clarification is authorized. Optional acceptance rows are not recommended. Each clarification is visible in an existing sentence. A new row is not required for the published r2 to stand alone.

## Evidence

The complete r1 PRD was read. Its raw hash matches the assigned hash. The accuracy report was used only to confirm the seven findings and the recommendation that a later revision apply L1 through L7 as wording clarifications, without a fee clamp, a gas stipend, a new static-call guard, or an accounting change. Process narrative in that report was not treated as a requirement. Source was not read. Sourcify was not refetched. Peer responses were not read.

The sentences that the substitutions replace are these, and no others carry the same inaccurate or missing proposition:

- PT-EXIT-01 ends: "Insufficient share balance fails checked subtraction. Read position liquidity after the burn."
- PT-EXIT-02 states `payout = floor(s*9990/10000)` with checked multiplication, then `ell = low128(MD(L,payout,S))`. Those formulas already use the payout before they use `L`. They do not themselves say when `L` is read.
- PT-ERROR-02 paired-exit order is: "recipient, compound, zero shares/supply, idle reads, caller balance burn, retention arithmetic/liquidity read/removal, minima, payouts." That order stays.
- PT-MATH-02 formulas are unchanged. The operational sentence is: "Both amount functions sort their two supplied endpoints. The amount0 function rejects a zero lower endpoint with `InvalidPrice()`, including for zero liquidity. Amount1 uses the absolute endpoint difference and does not apply that price-zero check."
- PT-VIEW-02 says: "Their endpoint sorting, not an idealized range-position valuation, controls out-of-range results."
- PT-AC-33 says: "Basket applies its supplied endpoint pairs with sorting and no clamp."
- PT-MATH-03 says: "Equal bounds produce a division failure."
- PT-AC-55 expects: "Respect `Q96`, `InvalidTick`, division failure, and checked candidate cast respectively."
- PT-MATH-01 already says MD and MU failures on a zero denominator or an out-of-range result "use an unadorned revert."
- PT-INIT-02 already says: "Zero spacing causes division failure and rolls back the entire initialization." PT-AC-03 already says a fresh zero-spacing call "fails arithmetic."
- PT-CB-02 Add manager-action cell: "Positive liquidity modification for that amount, including zero if explicitly requested by callback data."
- PT-COMP-03 native cell says "A caught notification revert reports zero and leaves the reverted payment in the instance." The ERC-20 catch row is "ERC-20, notification revert caught." The following paragraph already lists factory getter failures, checked arithmetic, malformed approval return data, and local/dependency call-setup failures, and it already says not to specify that fee-manager failure can never block users.
- PT-BAL-05 says: "Native payout uses an empty-calldata value call to the recipient." Failed payouts already use `WrappedError` with the stated fields. No gas, stipend, or remaining-gas sentence exists.
- PT-BAL-06 says the paired refund is "a nonzero empty-calldata value call to the sender" and that failure uses PairToken `TransferFailed`, not the wrapped payout error. Zero refund already skips the call.
- PT-VIEW-01 specifies the slot0, active-pool-liquidity, and position-entry reads and does not say they are static.
- PT-DEPENDS-03 names `extsload(bytes32)->bytes32` and does not say view or static.
- PT-BAL-01 says: "ERC-20 idle is the token's reported `balanceOf(instance)`." It does not say that idle read is static. PT-GET-05 `balanceOf` is the share getter, not this token idle read.

The accuracy report's L6 fix direction described source call shape and asked not to claim that r1 already required remaining gas. The accuracy report's L7 fix direction asked not to claim that r1 already required the static context. This brief instead requires those two sentences as new normative wording, and it forbids a compilation disclaimer in the PRD. The substitutions below follow the brief. They do not say that r1 already required the sentence, and they do not describe the sentence as a claim about r1.

## Assumptions

- The coordinator copies the complete r1 text and applies only the substitutions in Conclusions, then publishes that text as pairtoken-unified-prd-r2. This member does not emit the 90KB document.
- "Checked payout" means the existing PT-EXIT-02 value `floor(s*9990/10000)` with checked multiplication. It does not mean the later `MinOut` check. PT-ERROR-02 already places minima after removal and payouts after minima.
- The formula preamble "sorted as `a <= b`" defines the integer expressions. It is not the operational claim that both runtime functions sort. It stays.
- "Unadorned revert" means the helper failure class already named in PT-MATH-01. It is not a newly chosen panic selector. "Initialization division failure" means the failure already named in PT-INIT-02. Neither class is given a selector here.
- "Forwarding remaining gas" means the named call is not a 2300-gas stipend and is not given any other fixed stipend by this clarification. It does not add an EIP-150 fraction, a numeric gas limit, or a new error. Existing failure modes remain the only failure modes.
- "View static call" means the instance performs that consumed read as a static call. It does not add a preflight, code-existence check, or rejection of a dependency whose own body is not view.
- Amount1's absolute endpoint difference is the required integer rule. This clarification does not add a separate prohibition on computing that absolute difference by sorting, and it does not permit amount1 to apply the amount0 zero-price check.
- No new acceptance identifier is needed. PT-AC-01 through PT-AC-68 remain the complete scenario set. PT-AC-33 and PT-AC-55 change local observation text only.
- Identity retitling, the r2 supersession sentence, and deletion of any companion-file pointer are coordinator publication duties. They are not an eighth behavioral clarification. The substitutions below do not depend on a companion file.

## Coverage

| Item | Requirement whose sentence changes | Cross-reference that must move with it | Left unchanged on purpose |
| --- | --- | --- | --- |
| L1 | PT-EXIT-01 | None. PT-ERROR-02 already orders retention arithmetic before the liquidity read and must keep that wording. | PT-EXIT-02 formulas; PT-AC-23; PT-AC-62 idle-before-burn sentence |
| L2 | PT-MATH-02 | PT-VIEW-02; PT-AC-33 | Four amount formulas; "sorted as `a <= b`" preamble; currency-sorting sentence in PT-INIT-02 |
| L3 | PT-MATH-03; PT-AC-55 observation and its requirement citation | Citation gains PT-MATH-01 and PT-INIT-02. Those requirement bodies do not change. | PT-AC-03 "fails arithmetic"; PT-ERROR-03 failure classes |
| L4 | PT-CB-02 Add manager-action cell | None | Remove and Collect rows; PT-DEP-03 positive-add request; PT-AC-46 |
| L5 | PT-COMP-03, both notify rows and the governing paragraph | None required. PT-AC-38 remains compatible. | Approval-false row; cleanup-approval propagation; not-caught list; PT-AC-39 |
| L6 | PT-BAL-05 native-payout bullet; PT-BAL-06 first sentence | None required. PT-AC-65 keeps its wrapped-error fields. | ERC-20 payout bullet; notify value transfer; zero-refund skip |
| L7 | PT-VIEW-01; PT-BAL-01; PT-DEPENDS-03 | The three already-specified extsload consumption sites are named in PT-VIEW-01 so the singular interface sentence is not read as one slot only. | PT-GET-05 share `balanceOf`; PT-BAL-02 receipt reads; factory view table; no new scenario |

All 68 scenarios, every existing requirement ID, the ABI, constants, formulas, rounding, casts, operation and check order, events, errors, dependency limits, and the absent-behavior list stay, except the local sentences below.

## Conclusions

Adopt all seven substitutions. Do not add a requirement ID, an acceptance ID, a fee clamp, a 2300-gas stipend, a new guard, `getRate`, target normalization, or an accounting change. Do not put source listings or source line locators in the PRD. Do not tell the reader to consult r1, the accuracy report, or source.

### L1. PT-EXIT-01 payout before the liquidity read

Requirement ID: PT-EXIT-01.

Replace:

"Insufficient share balance fails checked subtraction. Read position liquidity after the burn."

With:

"Insufficient share balance fails checked subtraction. After that caller burn, the checked payout is calculated before the position-liquidity read. The checked payout is the PT-EXIT-02 calculation, not the later output-minimum check."

Cross-reference that must move: none. PT-ERROR-02 stays word for word, including "caller balance burn, retention arithmetic/liquidity read/removal, minima, payouts." PT-EXIT-02's formula bullets stay in their current order.

Preservation risks:

- Do not move `MinOut` or the zap minimum to before the liquidity read. "Checked payout" is the checked multiplication, not the minimum check.
- Do not edit the payout, `ell`, idle-fraction, or removal formulas.
- Do not move the idle snapshots to after the burn. PT-AC-62's "Redemption samples before burning" refers to those idle samples and stays.
- Do not insert an external call between the payout calculation and the liquidity read.

Recommended disposition: adopt the two-sentence replacement. No new acceptance row. The order is an internal checkpoint; PT-AC-23 already fixes the integers.

### L2. Amount0 sorts; amount1 uses the absolute difference

Requirement ID: PT-MATH-02.

Replace:

"Both amount functions sort their two supplied endpoints. The amount0 function rejects a zero lower endpoint with `InvalidPrice()`, including for zero liquidity. Amount1 uses the absolute endpoint difference and does not apply that price-zero check."

With:

"The amount0 function sorts its two supplied endpoints and rejects a zero lower endpoint with `InvalidPrice()`, including for zero liquidity. The amount1 function uses the absolute endpoint difference and does not apply that price-zero check."

Leave the four formulas, the width sentence, and the preamble "For nonnegative sqrt-price integers sorted as `a <= b`" unchanged.

Cross-references that must move, because they otherwise restate sorting as the rule for both basket amount functions:

PT-VIEW-02, replace "Their endpoint sorting, not an idealized range-position valuation, controls out-of-range results." with:

"Amount0 endpoint sorting and the amount1 absolute endpoint difference, not an idealized range-position valuation, control out-of-range results."

PT-AC-33, replace "Basket applies its supplied endpoint pairs with sorting and no clamp." with:

"Basket applies its supplied endpoint pairs with amount0 endpoint sorting, the amount1 absolute endpoint difference, and no clamp."

The rest of each of those sentences stays. PT-AC-33 keeps ID PT-AC-33 and the same requirement citation.

Preservation risks:

- Do not change `A0down`, `A0up`, `A1down`, or `A1up`.
- Do not add "amount1 shall not sort" as an implementation-shape rule. The required rule is the absolute endpoint difference and the absence of the zero-price check. Sorting used only to compute that absolute difference does not change the integer and is not forbidden by this sentence.
- Do not extend the amount0 `InvalidPrice()` check to amount1.
- Do not edit PT-INIT-02's unrelated "currencies are sorted" clause.

Recommended disposition: adopt all three sentence replacements. No new acceptance row. PT-AC-33 is the existing scenario and only loses the over-broad word "sorting."

### L3. Equal bounds are the MD unadorned revert

Requirement IDs: PT-MATH-03 and PT-AC-55.

In PT-MATH-03, replace "Equal bounds produce a division failure." with:

"Equal bounds fail through the MD helper's unadorned revert specified in PT-MATH-01. That failure is distinct from the initialization division failure in PT-INIT-02. No additional local guard is added."

In PT-AC-55, replace the expected observation with:

"Respect `Q96`, `InvalidTick`, the MD helper's unadorned revert, and checked candidate cast respectively. Equal bounds are that unadorned revert, distinct from the initialization division failure. Do not rescue a cast overflow by selecting the other candidate first."

Replace the PT-AC-55 requirement citation `PT-MATH-02/03/04` with `PT-MATH-01/02/03/04, PT-INIT-02`. Keep the scenario cell, including "equal liquidity-price bounds," and keep ID PT-AC-55.

Cross-reference that must move: the citation only. Do not rewrite PT-MATH-01, PT-INIT-02, PT-AC-03, or PT-ERROR-03. Those existing sentences are what the new sentences point at.

Preservation risks:

- Do not name a panic selector for either failure. Do not write that unchecked division panics. That selector was not established for this document.
- Do not add an equal-bounds precondition, a spacing-positive check, or any other guard. PT-INIT-02 already forbids a local positive-spacing validation; do not weaken that sentence and do not replace it with a selector.
- Do not collapse the two failures into one application error. PT-ERROR-03 already forbids that normalization.
- Do not copy L5's "including Panic" into this equal-bounds sentence.

Recommended disposition: adopt both sentence replacements and the citation addition. No new acceptance row. The "no additional local guard" clause is an absence, not a new check.

### L4. Add modification is nonnegative, including zero

Requirement ID: PT-CB-02, Add row only.

Replace the manager-action cell:

"Positive liquidity modification for that amount, including zero if explicitly requested by callback data"

With:

"Nonnegative liquidity modification for that amount, including zero if explicitly requested by callback data"

Cross-reference that must move: none.

Preservation risks:

- Keep the express zero permission in that same cell. "Nonnegative" without "including zero" would reopen the contradiction this clarification closes.
- Do not change the Remove row's "zero remains a zero change," the Collect row, or the Deploy row.
- Do not change PT-DEP-03's rule that a paired-entry addition is requested when the computed liquidity is positive. That is the caller's decision not to request a zero Add. It is not a callback ban on an explicitly supplied zero.
- Do not turn PT-AC-46's "No new callback liquidity-positive check is added" into a new positive check.

Recommended disposition: adopt the one-word replacement and keep the zero clause verbatim. No new acceptance row.

### L5. Both notify catches are catch-all

Requirement ID: PT-COMP-03.

In the native row, replace "A caught notification revert reports zero and leaves the reverted payment in the instance." with:

"A catch-all external-call failure of that notify, including a custom error, Panic, or empty revert, reports zero and leaves the reverted payment in the instance."

Replace the ERC-20 condition "ERC-20, notification revert caught" with:

"ERC-20, notify catch-all external-call failure"

Leave that row's required behavior unchanged: attempt `approve(feeManager,0)`, ignore its returned Boolean, report zero, and a decoding failure in that cleanup approval can still propagate.

Insert this sentence immediately before "The source's catches do not cover all conceivable failures.":

"Both notify catches are catch-all external-call failures of the notify call, including custom errors, Panic, and empty reverts. They do not catch the failures named in the following sentences."

Then keep the existing paragraph word for word, including the not-caught list and this sentence: "Do not specify "fee-manager failure can never block users.""

Cross-reference that must move: none. PT-AC-38's "reverts" remains compatible with the catch-all sentence and does not need a rewrite. PT-AC-39 already keeps factory-getter and malformed-approval failures outside the catch.

Preservation risks:

- Do not delete or soften "Do not specify "fee-manager failure can never block users."" Do not replace it with a claim that fee-manager failure can never block users.
- Do not drop factory getter failures, checked arithmetic, malformed approval return data, or local/dependency call-setup failures from the not-caught list.
- Do not describe the approval helper's false return, or the cleanup `approve`, as catch-all. The cleanup decoding failure must still be able to propagate.
- Do not extend the catch to share transfers, pulls, payouts, or manager calls.

Recommended disposition: adopt the two row edits and the inserted governing sentence. No new acceptance row. An optional clause in PT-AC-38 is not required; prefer the PT-COMP-03 sentence.

### L6. Remaining gas for native payout and paired refund

Requirement IDs: PT-BAL-05 and PT-BAL-06.

This is new normative wording. Do not write that r1 already required it, that r1 omitted it, or that the sentence depends on a compiler. Do not put a compilation disclaimer in the PRD.

In PT-BAL-05, replace "Native payout uses an empty-calldata value call to the recipient." with:

"Native payout is an empty-calldata CALL forwarding remaining gas to the recipient, and it carries the payout value. It is not a 2300-gas stipend."

Keep every other PT-BAL-05 bullet and paragraph, including `WrappedError`, `bytes4(0)`, `NativeTransferFailed()`, raw `reason` bytes, nominal amounts, and the ERC-20 payout rule.

In PT-BAL-06, replace "Paired-entry refund clears the stored reservation before a nonzero empty-calldata value call to the sender." with:

"Paired-entry refund clears the stored reservation before a nonzero empty-calldata value call forwarding remaining gas to the sender. That call is not a 2300-gas stipend."

Keep the immediately following failure sentence word for word: "Refund failure uses PairToken `TransferFailed`, not the wrapped payout error. Refund zero skips the call." Keep the rest of PT-BAL-06.

Cross-reference that must move: none. PT-AC-65 stays. Its wrapped-error fields are an existing failure mode, not a gas rule.

Preservation risks:

- Do not drop the payout value transfer when replacing "value call" with the authorized CALL sentence.
- Do not normalize the refund sentence to CALL, and do not drop "forwarding remaining gas" from either sentence. The authorized phrases differ; the gas rule is the same. Neither call is a 2300-gas stipend.
- Do not add a numeric gas limit, an EIP-150 fraction, a stipend of any size, or a new gas error.
- Do not move the remaining-gas sentence onto fee-manager `notify`, `settle`, `take`, or the ERC-20 payout. Those calls are outside L6.
- Do not apply the refund gas sentence to a zero refund. Zero refund still skips the call.
- The gas rule does apply to a native payout call that is actually made, including the chosen-leg zero-value payout that PT-EXIT-04 still attempts. That does not create a new payout.

Recommended disposition: adopt both replacements as normative requirements. No compilation disclaimer. No new acceptance row. A recipient-gas scenario would restate the sentence and could be misread as a new success guarantee; do not add one.

### L7. Consumed extsload and idle balanceOf are view static calls

Requirement IDs: PT-VIEW-01, PT-BAL-01, and PT-DEPENDS-03.

This is new normative wording. Do not write that an existing view getter already required it.

In PT-VIEW-01, after "These are dependency-access semantics, not an assertion that every address satisfying the manager ABI has that layout." insert:

"The consumed single-slot extsload reads of slot0, active-pool liquidity, and the position entry are view static calls. Do not add a guard against a non-view dependency."

In PT-BAL-01, immediately after "ERC-20 idle is the token's reported `balanceOf(instance)`." insert:

"The token balanceOf idle read is a view static call. Do not add a guard against a non-view dependency."

In PT-DEPENDS-03, replace "and external storage reads through `extsload(bytes32)->bytes32`." with:

"and the consumed single-slot extsload read `extsload(bytes32)->bytes32`, which is a view static call."

Leave the following PT-DEPENDS-03 paragraphs unchanged.

Cross-reference that must move: the three consumption sites already named in PT-VIEW-01. Naming them applies the one authorized extsload rule to the reads the PRD already specifies. It does not add a read, a batch `extsload`, or a layout change. No caller requirement needs a second copy. PT-COMP-05, PT-EXIT-01, and PT-API-08 already consume those reads through PT-VIEW-01.

Preservation risks:

- Do not add a preflight, extcodesize check, or rejection when the dependency is not view. A non-view dependency that fails under the static call still fails through the existing read-failure rules in PT-ERROR-03. That is not a new guard.
- Do not mark PT-GET-05. That `balanceOf` is the share getter.
- Do not extend this sentence to PT-BAL-02's pre-call and post-call receipt reads, to `approve`, or to `transfer`. The authorized idle read is the PT-BAL-01 read only.
- Do not use L7 to reorder the L1 payout calculation and liquidity read, and do not use L1 to make the liquidity read non-static.
- Do not add a static-call sentence to the factory view table. Those methods are already specified as view.

Recommended disposition: adopt the three insertions. No new acceptance row. No new guard.

### Integration rule for the coordinator

Apply the substitutions to a full copy of r1. Do not abbreviate unchanged sections. Do not add a companion pointer. Set the published identity to pairtoken-unified-prd-r2 and state that it supersedes r1 as the single working document, with r1 remaining an unchanged archive and not a normative input. That frame change is publication work, not an extra behavioral clarification, and it must not alter any requirement, scenario, formula, or absence.

Recommended disposition of the whole contribution: adopt. All seven are local sentence clarifications. None should be dropped, widened into a guard, or deferred to a companion file.

## Limits

- This member read the brief, the complete r1 PRD, and the findings and recommendations of the accuracy report. Member originals, old requirements, errata, and source were not read. Sourcify was not refetched. No excerpt was sent to a search service. Peer responses were not read.
- The raw hash was recomputed from the r1 file bytes and matched the assigned hash. r1 was not edited.
- L6 and L7 are adopted as the brief's new normative sentences. This pass did not re-derive call opcodes or view modifiers from source, because source was not admitted. The accuracy report confirmed that those sentences were the authorized missing call-context clarifications and that they must not be described as already required by r1.
- No panic selector is asserted for equal bounds or for zero tick spacing. The unchecked-division panic inference was not executed and is not used.
- No acceptance scenario was executed. This response does not authorize implementation, tests, builds, deployment, or Git actions.
- The coordinator integrates and publishes the complete r2 PRD. This file is the prose to integrate. It is not itself the PRD, and it is not a second working specification.
