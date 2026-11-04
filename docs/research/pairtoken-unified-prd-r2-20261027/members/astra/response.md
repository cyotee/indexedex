# Identity

- Run: `pairtoken-unified-prd-r2-20261027`.
- Member: Astra; requested role: `council-member`; contribution type: independent research authoring.
- Requested model and reasoning: `chatgpt-subscription/gpt-6-astra:high`.
- Runtime-exposed identity: `PI_MODEL=gpt-6-astra`, `PI_REASONING_LEVEL=high`, `PI_SESSION_ID=01a17f66-22aa-7669-9bcf-f125b6b311a1`. Those fields do not independently expose the provider/account binding. I initiated no model, account, or provider substitution.
- Owned output: `docs/research/pairtoken-unified-prd-r2-20261027/members/astra/response.md`.
- Fresh context; no peer responses read; no sub-agent launched. This is my contribution, not a coordinator decision or another member's vote.

# Question and targets

What exact standalone prose integrates every authorized accuracy clarification into one complete Pair Token PRD, without adding behavior or requiring any companion file?

The target is the admitted complete `pairtoken-unified-prd-r1` PRD. The coordinator should incorporate the local replacements and insertions below into the complete r2 document, retaining all unaffected text. This response is an integration contribution, not a replacement PRD, implementation plan, or defect review.

Only L1 through L7 are proposed. No requirement ID is removed or renumbered, no acceptance scenario is added or removed, and no ABI, constant, formula, rounding rule, cast, event, error, dependency limit, or absent behavior is otherwise changed.

# Evidence

I read the complete run brief and complete admitted r1 PRD:

- `docs/research/pairtoken-unified-prd-r2-20261027/brief.md`
- `docs/research/pairtoken-unified-prd-20261027-01a17e03/handoff/PRD.md`

I recomputed SHA-256 directly from the baseline file's raw bytes. The result matches the assigned identity:

`1824df69b7f64cc15252a7ae877d3b3f762773db5bfc4f091591eb1af8a7f6d2`

I also read only the Findings and Recommendations sections of `docs/reviews/pairtoken-prd-sourcify-accuracy-20261027/REMEDIATION_PRD.md`, using its heading index to locate those sections. They confirm the seven authorized clarification subjects. Their reported source analysis is supporting context, not source independently inspected in this contribution.

The baseline itself supplies the integration anchors: PT-ERROR-02 already places retention arithmetic before the liquidity read; PT-MATH-01 already specifies unadorned helper reverts; PT-CB-02 expressly permits zero Add liquidity; and PT-COMP-03 already distinguishes caught notification failures from uncaught surrounding failures. L6 and L7 are newly explicit normative wording for r2, not claims that r1 already stated those call contexts.

# Assumptions

1. The hash-matched r1 is the complete behavioral baseline. The seven authorized clarifications define the entire permitted substantive change.
2. Exact prose below is normative replacement or insertion text only where identified. Integration instructions, risks, and dispositions are member commentary and should not be pasted into the PRD as additional requirements.
3. Existing dependency conditions and failure precedence continue to qualify every scenario. No statement below guarantees successful notification cleanup, native receipt, manager interaction, or token response.
4. An internal reference to another retained requirement in the complete r2 is self-contained. A requirement to consult r1, the accuracy report, source, or this contribution would not be.

# Coverage

| Clarification | Primary requirement locations | Wording or reference synchronization | Acceptance treatment |
| --- | --- | --- | --- |
| L1 | PT-EXIT-01 | Preserve PT-EXIT-02 and PT-ERROR-02 verbatim. | Preserve PT-AC-23, PT-AC-26 and PT-AC-62. |
| L2 | PT-MATH-02 | Replace the collective endpoint-sorting description in PT-VIEW-02 and PT-AC-33. | Change only the expected-observation wording in PT-AC-33. |
| L3 | PT-MATH-03 | Distinguish PT-MATH-01 helper failure from PT-INIT-02 initialization failure; retain PT-ERROR-03. | Change PT-AC-55 expected observation and supplement its requirement references. |
| L4 | PT-CB-02, Add row | Preserve PT-CB-03 and the positive-add trigger conditions elsewhere. | Preserve PT-AC-46. |
| L5 | PT-COMP-03 | Preserve the routing table, PT-BAL-04 and PT-ERROR-03/04. | Preserve PT-AC-38/39 and PT-AC-68. |
| L6 | PT-BAL-05 and PT-BAL-06 | Preserve PT-DEP-05, PT-EXIT-03/04 and PT-EVENT-03. | Preserve PT-AC-14, PT-AC-59, PT-AC-64 and PT-AC-65. |
| L7 | PT-DEPENDS-03 and PT-BAL-01 | These govern the reads used by PT-VIEW-01/02 and the existing idle checkpoints. No additional guard is inserted. | Preserve existing read-order and dependency-failure scenarios, including PT-AC-62. |

All 68 existing acceptance scenarios remain. No optional acceptance row is needed.

# Conclusions

## L1 - State the intervening payout calculation

**Requirement changed:** PT-EXIT-01.

Replace its final two sentences, beginning with "Insufficient share balance fails checked subtraction.", with:

> Insufficient share balance fails checked subtraction. After the caller burn, calculate `payout = floor(s*9990/10000)` using checked multiplication, then read position liquidity.

**Cross-references:** PT-EXIT-02 retains the same payout formula and decomposition. PT-ERROR-02 retains its existing paired-exit order without alteration. PT-AC-62 continues to place the idle reads before the burn; it does not need another sentence to restate the later checkpoints.

**Preservation risk:** Do not move the calculation before the caller burn, move the liquidity read before the calculation, or replace the checked multiplication with full-precision `MD`. Those changes could alter failure precedence or the accepted arithmetic domain. Do not move the pre-burn supply snapshot or either idle read.

**Recommended disposition:** Adopt the local replacement. It makes the detailed checkpoint description agree explicitly with the existing error-order requirement.

## L2 - Distinguish endpoint sorting from absolute difference

**Requirement changed:** PT-MATH-02.

Replace the paragraph beginning "Both amount functions sort their two supplied endpoints." with:

> The amount0 function sorts its two supplied endpoints and rejects a zero lower endpoint with `InvalidPrice()`, including for zero liquidity. The amount1 function uses the absolute difference between its supplied endpoints and does not apply that price-zero check. `L` has width `uint128` and endpoints have width `uint160`; `L*Q96` fits in `uint256`.

The opening sorted-variable convention and all four integer formulas remain verbatim. Using `a <= b` to express the formulas does not require both functions to implement endpoint sorting.

**Required synchronized wording in PT-VIEW-02:** Replace only "Their endpoint sorting, not an idealized range-position valuation, controls out-of-range results." with:

> The amount0 function's endpoint sorting and the amount1 function's absolute endpoint difference, not an idealized range-position valuation, control out-of-range results.

**Required synchronized wording in PT-AC-33:** Keep the scenario and requirement-reference cells. Replace its expected-observation cell with:

> Basket applies its supplied endpoint pairs using amount0 endpoint sorting and the amount1 absolute endpoint difference, with no clamp. Fundable-liquidity calculation separately selects its one-sided branch. An idealized range formula must not replace basket behavior.

**Cross-references:** PT-AC-33 retains `PT-MATH-02/03, PT-VIEW-02`. PT-MATH-03's separate ordering of liquidity bounds remains unchanged.

**Preservation risk:** Do not change `b-a` in the displayed sorted-variable formulas, move the amount0 zero-price rejection, add that rejection to amount1, or clamp basket price to the usable range. Merely fixing PT-MATH-02 while leaving the collective sorting descriptions elsewhere would leave an avoidable ambiguity.

**Recommended disposition:** Adopt the primary paragraph and both synchronized sentences as one L2 clarification. They add no numerical behavior.

## L3 - Name the equal-bounds helper failure precisely

**Requirement changed:** PT-MATH-03.

Replace only "Equal bounds produce a division failure." with:

> Equal liquidity-price bounds make the `b-a` denominator zero and fail through the `MD` helper with an unadorned revert, as specified in PT-MATH-01. This is distinct from the zero-tick-spacing initialization division failure in PT-INIT-02.

**Acceptance requirement changed:** PT-AC-55.

Keep its ID and scenario cell. Replace its expected-observation cell with:

> Respect `Q96`, `InvalidTick`, the `MD` helper's unadorned revert for equal liquidity-price bounds, and checked candidate cast respectively. The equal-bounds failure is distinct from the zero-tick-spacing initialization division failure in PT-INIT-02. Do not rescue a cast overflow by selecting the other candidate first.

Replace its requirement-reference cell with:

> PT-MATH-01/02/03/04, PT-INIT-02, PT-ERROR-03

**Cross-references:** PT-MATH-01, PT-INIT-02, PT-ERROR-03 and PT-AC-03 retain their existing text. The supplemented PT-AC-55 references make its distinction resolvable entirely within r2.

**Preservation risk:** Do not introduce an equal-bounds or spacing admission guard, a new error, a specific initialization panic selector, or a claim that the initialization failure was executed. Preserve both candidate-conversion checks before selecting the minimum and all formulas.

**Recommended disposition:** Adopt the local prose and acceptance-cell changes together. Distinguish the failure paths without adding an unverified byte-level assertion about initialization.

## L4 - Make the Add row's nonnegative domain explicit

**Requirement changed:** PT-CB-02.

Replace the Add row with:

| Value / operation | Payload contract | Manager action | Inner return content |
| --- | --- | --- | --- |
| 1 / Add | ABI `uint128 liquidity` | Nonnegative liquidity modification for that amount, including zero if explicitly requested by callback data | `(uint256 used0,uint256 used1)` |

The displayed header is identification context; retain the existing table and replace only its Add row.

**Cross-references:** PT-CB-03 continues to define modification and return semantics. PT-AC-46 already states that no callback liquidity-positive check is added and needs no revision.

**Preservation risk:** This change concerns the callback's decoded input domain. It does not remove the positive-liquidity conditions that determine whether paired entry or Deploy requests an addition, nor does it add a special zero-liquidity early return.

**Recommended disposition:** Adopt the one-word substantive correction while retaining the express zero permission.

## L5 - Specify both catch-all notification boundaries

**Requirement changed:** PT-COMP-03.

Keep all four routing-table rows. Replace the paragraph following that table with:

> Both the native and ERC-20 `notify` catches are catch-all handlers for failures of the external notification call, including custom errors, `Panic`, and empty reverts. Each caught failure follows the corresponding reporting and cleanup behavior in the table. These catches do not cover all conceivable failures. Factory getter failures, checked arithmetic, malformed approval return data, and local/dependency call-setup failures can abort an operation. A successful notification is not proof that an ERC-20 allowance was consumed or tokens were pulled. Any actual token movement depends on the fee manager and token.

**Cross-references:** PT-BAL-04 retains approval decoding and return-value behavior. PT-ERROR-03/04 retain propagation and atomicity. PT-AC-38 already describes caught notification failures and the cleanup exception; PT-AC-39 covers approval and factory failures. Neither needs a new row or a changed premise.

**Preservation risk:** A catch-all notification boundary is not a catch-all around the entire protocol-routing operation. Preserve the malformed cleanup-approval failure, the full existing uncaught-failure list, and the absence of an unconditional success-path allowance reset. Do not claim that fee-manager failure can never block users or that successful notification proves token movement. PT-AC-68's later uncaught idle-underflow rollback remains intact.

**Recommended disposition:** Adopt the replacement paragraph. It specifies the caught error classes without broadening the catch boundary.

## L6 - Add the native call-gas requirements

**Requirements changed:** PT-BAL-05 and PT-BAL-06.

This is newly explicit normative wording for r2. It is not a claim that r1 already specified remaining-gas forwarding.

In PT-BAL-05, replace only the native-payout bullet with:

> Native payout uses an empty-calldata value `CALL` to the recipient, forwarding remaining gas subject to EVM call-gas rules, not a fixed 2300-gas stipend.

In PT-BAL-06, replace only its first sentence with:

> Paired-entry refund clears the stored reservation before a nonzero empty-calldata value call to the sender that forwards remaining gas subject to EVM call-gas rules, not a fixed 2300-gas stipend.

**Cross-references:** Keep the rest of PT-BAL-05 and PT-BAL-06 verbatim. Native payout still uses the specified `WrappedError`, native refund still uses `TransferFailed`, and zero refund still skips the call. PT-DEP-05 and PT-EVENT-03 retain refund timing and recipient identity. PT-EXIT-03/04 and PT-AC-64 retain the difference between paired zero-output skipping and chosen-leg zero-value payout. PT-AC-65 retains the full wrapped failure payload.

**Preservation risk:** Forwarding remaining gas does not guarantee recipient success or dispense with EVM call-gas rules. Do not substitute a stipend, change calldata, relocate reservation clearing, redirect the refund to `to`, change the shared reentrancy guard's scope, or normalize the two failure modes. No compilation disclaimer belongs in the inserted PRD text.

**Recommended disposition:** Adopt both sentences as authorized new normative call-context wording. No new acceptance scenario is required.

## L7 - Add the consumed reads' static context

**Requirements changed:** PT-DEPENDS-03 and PT-BAL-01.

This is newly explicit normative wording for r2. It is not a claim that r1 already specified these consumed calls' static context.

In PT-DEPENDS-03, insert immediately after the paragraph listing required interactions:

> The consumed single-slot `extsload(bytes32)->bytes32` interface is external view, and each such read is made as a static call (`STATICCALL`).

In PT-BAL-01, replace only "ERC-20 idle is the token's reported `balanceOf(instance)`." with:

> ERC-20 idle is the token's reported `balanceOf(instance)`, obtained through a view static call (`STATICCALL`).

**Cross-references:** PT-VIEW-01 retains all storage-key derivations, field extraction and layout limits. PT-VIEW-02 and the route-specific idle checkpoints continue to use these reads in their existing order. PT-BAL-01 still distinguishes native balance arithmetic from a token call. PT-ERROR-03 retains external-call and decoding failure behavior. These existing connections need no additional normative sentence or acceptance row.

**Preservation risk:** Static call context is the required caller behavior, not a new admission test of dependency bytecode or interface honesty. Do not add a non-view-dependency guard, a new custom error, a fallback to a mutable call, a compatibility guarantee for arbitrary managers, or new balance reads. Preserve all slot semantics, native-reservation arithmetic and read ordering.

**Recommended disposition:** Adopt both insertions as authorized new normative call-context wording.

## Combined disposition

Adopt L1 through L7 using the exact local changes above, including L2's synchronized descriptions and L3's existing acceptance-row update. Integrate them directly into the complete r2 body; do not publish this response as an errata dependency. Preserve every existing ID and all 68 acceptance scenarios. Retain the complete unaffected ABI, constants, formulas, events, errors, checkpoints, dependency limits and absence list.

L6 and L7 should be recorded as newly expressed requirements in the coordinator's revision accounting, without implying that r1 already contained their wording. That provenance distinction does not weaken their normative force in r2 and need not become a compilation or evidence disclaimer inside the affected requirements.

# Limits

This contribution establishes a bounded editorial integration proposal against the hash-verified r1 and authorized clarification text. It does not independently re-audit source, prove runtime equivalence, or supply evidence of execution. I did not read peer responses, old requirements, errata, target source, or the accuracy report's other substantive sections. I made no public query or Sourcify retrieval and ran no project test, build, installation, deployment, Git operation, or wallet action.

No implementation is authorized. This member response is not the complete published r2, and its delivery alone does not establish that the coordinator integrated every replacement or preserved the complete final document.
