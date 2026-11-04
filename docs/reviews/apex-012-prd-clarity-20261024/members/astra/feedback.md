# Member feedback
## Identity
- Run ID: apex-012-prd-clarity-20261024
- Member label: astra
- Phase: advisory review
- Owned path: docs/reviews/apex-012-prd-clarity-20261024/members/astra/feedback.md
- Requested role: council-member
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued
- Initial response path: docs/reviews/apex-012-prd-clarity-20261024/members/astra/response.md
- Initial response preserved: yes

## Draft reviewed
- Draft ID: draft-apex-012-prd-clarity-20261024-r1
- Path: docs/reviews/apex-012-prd-clarity-20261024/coordinator/draft.md

## Disposition

requested-changes

The verdict and the principal economic constraints are supported. The draft does not explicitly adopt a new economic design, but its compression drops implementation-changing questions and presents some already-rejected alternatives as open decisions. The statement that all narrower questions are covered by the thirteen questions is not accurate.

## Concerns

### 1. Fee questions have been reduced to redemption allocation

**What was dropped:** Requirements question 6 asks whether fees on burn belong to the exiting slice or remaining position. It does not preserve my initial Q7-Q8: whether pre-entry uncollected fees belong to existing holders, when that ownership is fixed, how other-token fees participate, whether fees arising during the acting holder's swap belong to the remaining positions, or whether every completed target-fee collection must update the counter exactly once. Question 8's optional harvest sequencing does not answer these ownership and accounting questions.

An implementation that mints before recognizing old accrued fees differs from one that preserves them for old holders. Crediting target fees only during an explicit harvest differs from crediting incidental collections during an add or burn.

**Smallest change:** Expand question 6 to cover entry and exit fee ownership, snapshot timing, and incidental collections. Explicitly ask whether collection is optional but accounting for a completed qualifying collection is mandatory. Carry the answer into the counter equations.

### 2. Entry snapshots, idle contributions, and leftovers are not covered sufficiently

**What was dropped:** Questions 2-4 do not explicitly preserve the ownership snapshot from initial Q4 or the contribution/refund rules from Q6. A pre-swap token mix and a post-swap token mix differ when existing vault liquidity fills entry. Asking how much to swap does not fix the baseline for old-holder entitlement, fee attribution, or the entrant's claim on other token.

Question 3 asks whether a deposit leaves some target idle, but not whether the entrant must contribute proportionally to preexisting idle target and other, or whether unused input is refunded versus accepted into shared inventory. Those alternatives change minted shares, counter credit, and old-holder dilution.

**Smallest change:** Add explicit questions identifying the supply/liquidity/idle/fee snapshots and the accepted-versus-refunded input rule. Include idle other as well as idle target. Do not treat a general request for a mint formula as a substitute for these observable decisions.

### 3. Per-position rounding and non-bootstrap empty states remain omitted

**What was dropped:** Question 2 asks for a rounding direction and tolerance in Test 1, but does not specify rounding of each position's addition/removal, ownership of residuals, or behavior when positive input produces zero shares or a share redemption rounds to zero liquidity. Question 7 covers the first deposit, not initial Q10's empty slots or entirely idle holdings while supply remains positive.

These cases determine whether an operation reverts, burns shares for no LP withdrawal, retains dust for remaining holders, or populates a previously empty slot.

**Smallest change:** Expand question 2 to request per-component rounding, zero-result behavior, and residual ownership. Add the nonzero-supply empty-slot/all-idle case to question 7, explicitly constrained by the settled prohibition on later deposits opening new ranges.

### 4. The counter question lacks its domain and permissible-debit invariant

**What was dropped:** Question 1 preserves the main gross/net and zero-supply questions but not the remaining part of initial Q2: what guarantees that an allowed debit does not exceed the stored counter, and what happens if it does. A lagging counter is expressly not a current inventory measurement, so its safety cannot be inferred from token backing alone.

**Smallest change:** Append a request for the counter's domain and invariant governing permissible debits, including the behavior of any allowed state with a debit greater than the counter. Also distinguish internal LP custody transfers from economic counter events in the operation equations. Do not select a signed, clamped, or reverting implementation on the owner's behalf.

### 5. The donation boundary question disappeared

**What was dropped:** Initial Q20 has no counterpart in the thirteen questions. A direct unbooked transfer and a pool fee-growth donation later collected as target fees are not the same accounting event. The target's broad donation exclusion and permission to credit collected target fees need a boundary, especially while 040 stays open.

**Smallest change:** Restore a question defining the donation classes covered by 012 and the classes left to 040. The answer changes the counter and tests; it is not merely terminology.

### 6. Test-changing requirements were excluded from the admission criterion

**What the draft got wrong:** The Requirements questions introduction narrows the criterion to answers that change the contract. The assignment includes changes to contracts, tests, or vault behavior. Disagreement dismisses initial Q21 as a test-wording fix, which is not a valid reason to drop it under that criterion.

The unconditional numerical inequalities in Test 2 can reject a correct execution whose payout happens to equal the comparison value. The draft also omits the separate quality finding that Tests 1, 5, and 6 need independently expected component/counter outcomes, rather than recomputing a ratio or reading the counter written by the implementation under test.

**Smallest change:** Restore the full admission criterion and Q21's distinction between computational independence and numerical inequality. Add the test-oracle quality finding, with a direction to derive expected transitions and component changes independently after the requirements are resolved. No economic redesign is needed.

### 7. The temporary-liquidity conflict is overstated and incompletely preserved

**What the draft got wrong:** Agreed defect 2 states that the same deposit then mints more shares when an outsider adds liquidity. The justified claim is that external depth can change legitimate execution and actual affordable liquidity, so equality is not guaranteed by the described algorithm. An unconditional increase has not been demonstrated for every portfolio, placement rule, and rounding outcome.

The draft also drops the distinction between Entry's “must not increase” and Test 3's “same number.” The latter additionally prohibits decreases.

**Smallest change:** Change the universal increase claim to a possible change in actual execution and minted shares. Explicitly ask which of equality, non-increase, and actual proportional-liquidity issuance governs, under what controlled conditions. Retain this as a conflict requiring an owner answer, not as authority to choose a replacement pricing model.

### 8. Several questions reopen settled constraints or imply noncompliant accounting alternatives

**What the draft got wrong:**

- Question 3 asks whether shares include idle balances, although the target's Accounting section already includes them. The unresolved issue is how contributions and withdrawals preserve that ownership.
- Question 9 offers keeping rebalance allowed to sell other token, while Already decided correctly states that other token converts only on the acting holder's entry or exit.
- Question 2's proposed summed liquidity expression can be mistaken for an admissible canonical formula. Summing additions across ranges is not equivalent to preserving a common fractional claim on each range. Agreed defect 1 also lists a target-balance ratio without explaining that any candidate must satisfy the already-selected all-position ownership rule.

These are not adopted designs in the draft, but the presentation invites answers that violate its own preserved decisions.

**Smallest change:** Reframe the idle question around implementation of the already-required idle ownership. Reframe rebalance around the disposition of the existing sale path while preserving the ban and deferring 025's loss-cap work. Request the per-slot/common-fraction equation without suggesting an aggregate sum or target-only valuation as an unconstrained design choice.

### 9. Existing quote decisions are described as missing, while exact-output details remain missing

**What the draft got wrong:** Agreed defect 9 and question 10 imply that `quoteRate` and `liquidationValue` lack any disposition. The target already directs `getRate` and `quoteRate` to the counter and supply, and permits `liquidationValue` to remain outside the money/rate paths as a labeled quote. An optional non-executing quote is not itself a defect merely because it provides another number.

Conversely, the exact-output issue is not fully closed by asking whether the route executes new accounting or reports a preview. An executable exact-output route needs rules for executed input, maximum input, refunds, and any surplus from discrete slice sizing.

**Smallest change:** Preserve the existing counter/preview decisions and ask only the unresolved compatibility questions, including treatment of encoded projected state where relevant. Expand the exact-output question to cover support/unavailability and executed-amount/refund/surplus rules. Do not reopen live valuation for `quoteRate`.

### 10. The older-mandate claim needs a narrower evidentiary status

**What the draft got wrong:** The draft calls the older constant-product sentence a confirmed conflict because the 012 PRD does not explicitly supersede it. Textual omission of a supersession statement alone does not establish that an older general requirement overrides or remains applicable to a newer family-specific owner ruling.

I did not examine that older document in my independent response, and this advisory assignment permits reviewing only the draft. I therefore cannot independently confirm the source's scope, applicable family, or precedence. The draft may accurately report the coordinator's read, but that is different from establishing an unresolved economic mandate.

**Smallest change:** Label the citation as additional coordinator context and distinguish the verified wording from the still-to-be-established applicability/precedence question. Keep any clarification administrative: identify the governing document for these Wings families. Do not invite a choice of a third economic model or disturb the explicit V3 FullSpread exclusion.

## Limits

- I reviewed only the specified coordinator draft during this advisory pass. Comparison with my initial questions uses my preserved response from this session; I did not reread or modify it.
- I did not read peer responses, the older mandate document, or additional project sources in this pass. I cannot independently verify the draft's statements about every member's agreement or its new cross-document citation.
- The draft's principal verdict is supported. These concerns request retention and precision of requirements, not a new economic design or implementation.
- No runtime validation, Forge command, installation, deployment, commit, or sub-agent was used.
- Only this owned feedback file was authored.
- This disposition is advisory. It is not a veto and not consensus.
