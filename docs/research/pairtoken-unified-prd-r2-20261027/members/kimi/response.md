# Identity

- Member: Kimi
- Run ID: `pairtoken-unified-prd-r2-20261027`
- Role: independent council-member authoring contribution
- Requested model and reasoning: `kimi-coding/k3.1-pro:high`, global route
- Target: `pairtoken-unified-prd-r1`, admitted for integration into the coordinator's standalone `pairtoken-unified-prd-r2`
- Fresh context: yes; no peer responses were read

# Question and targets

The question is what exact prose integrates the seven authorized accuracy clarifications into one complete Pair Token PRD without adding behavior or requiring a companion file. This response supplies local replacement and insertion prose, not another complete PRD. The coordinator should apply these changes to the otherwise preserved r1 text when publishing r2.

Every existing requirement ID, all 68 acceptance scenarios, the ABI, constants, formulas, rounding, casts, checkpoints, events, errors, dependency limits, and absent-behavior statements remain unchanged except for the local sentences specified below. No new acceptance row is needed.

# Evidence

- The complete admitted r1 PRD was read. Its raw size is 95,049 bytes, and its recomputed raw SHA-256 is `1824df69b7f64cc15252a7ae877d3b3f762773db5bfc4f091591eb1af8a7f6d2`, exactly matching the assigned hash.
- The r2 brief authorizes exactly L1 through L7 and requires standalone integration without new behavior.
- The admitted accuracy findings and recommendations confirm the same seven wording clarifications. L6 and L7 are new normative wording for r2, not claims that r1 already contained these requirements.
- The replacement locations below were checked against the pinned r1 text: PT-EXIT-01, PT-MATH-02, PT-MATH-03, PT-CB-02, PT-COMP-03, PT-BAL-05, PT-BAL-06, PT-BAL-01, PT-DEPENDS-03, and PT-AC-55.

# Assumptions

- The coordinator will retain all unaffected r1 prose verbatim and will handle the separate r2 identity and publication metadata.
- Internal cross-references remain valid as written; none requires renumbering or relocation.
- No optional acceptance scenario is necessary because each clarification is clearer as an integrated sentence in the existing normative text.
- The recommended dispositions concern documentation only and do not authorize implementation or execution.

# Coverage

## L1 - Checked payout precedes the position-liquidity read

**Requirement changed:** PT-EXIT-01.

**Exact replacement:** Replace the final sentence, `Read position liquidity after the burn.`, with:

> After the caller burn, calculate `payout = floor(s*9990/10000)` with checked multiplication, then read position liquidity.

**Cross-references:** No cross-reference moves. PT-EXIT-02 retains the same payout formula and subsequent decomposition. PT-ERROR-02 already orders paired exit as caller balance burn, then retention arithmetic/liquidity read/removal.

**Preservation risks:** Do not move the burn ahead of the two idle reads, change the burned amount from `s` to `payout`, weaken checked multiplication, or reorder removal ahead of the liquidity read. Keep all PT-EXIT-02 formulas and PT-ERROR-02 precedence unchanged.

**Recommended disposition:** Adopt the one-sentence replacement; add no acceptance row.

## L2 - Amount0 sorting and amount1 absolute difference

**Requirement changed:** PT-MATH-02.

**Exact replacement:** Replace the first three sentences after the four amount formulas with:

> The amount0 function sorts its two supplied endpoints and rejects a zero lower endpoint with `InvalidPrice()`, including for zero liquidity. The amount1 function uses the absolute endpoint difference and does not apply that price-zero check.

**Cross-references:** No cross-reference moves. PT-VIEW-02 and PT-AC-33 continue to describe the resulting out-of-range amount behavior; PT-MATH-01 continues to define `MD` and `MU`.

**Preservation risks:** Do not alter any integer formula, add an amount1 zero-price check, remove the amount0 zero-liquidity rejection, or replace the absolute difference with a signed subtraction. Keep the existing width and `L*Q96` fit sentence immediately after the replacement.

**Recommended disposition:** Adopt the two-sentence replacement; add no acceptance row.

## L3 - Equal-bounds MD revert versus initialization division failure

**Requirements changed:** PT-MATH-03 and PT-AC-55.

**Exact replacement in PT-MATH-03:** Replace `Equal bounds produce a division failure.` with:

> Equal bounds produce the `MD` helper's unadorned revert, not the initialization division failure caused by zero tick spacing.

**Exact replacement in PT-AC-55:** Replace the complete Expected observation cell with:

> Respect `Q96` and `InvalidTick`; observe the `MD` helper's unadorned revert for equal liquidity-price bounds, distinct from the initialization division failure caused by zero tick spacing; retain the checked candidate cast for an oversized one-side liquidity candidate. Do not rescue a cast overflow by selecting the other candidate first.

**Cross-references:** No cross-reference moves. PT-MATH-01 already defines the MD helper's unadorned revert; PT-INIT-02 retains the zero-spacing initialization division failure; PT-ERROR-03 continues to prohibit normalizing unlike failures into one application error.

**Preservation risks:** Do not assert an unexecuted panic selector, assign the initialization failure to equal liquidity bounds, add an equal-bounds guard, or change the checked `uint128` cast and candidate-evaluation order.

**Recommended disposition:** Adopt both replacements together; add no acceptance row.

## L4 - Nonnegative Add liquidity modification

**Requirement changed:** PT-CB-02, Add callback row.

**Exact replacement:** Replace the Add row's Manager action cell with:

> Nonnegative liquidity modification for that amount, including zero if explicitly requested by callback data

**Cross-references:** No cross-reference moves. PT-CB-03 continues to define modification and settlement semantics, and PT-AC-46 continues to reject any new callback liquidity-positive check.

**Preservation risks:** Do not remove the express zero permission, make zero an error, or change the signed modification semantics of Remove or Collect.

**Recommended disposition:** Adopt the one-word clarification from positive to nonnegative while retaining the rest of the cell; add no acceptance row.

## L5 - Catch-all notify failure handling

**Requirement changed:** PT-COMP-03.

**Exact replacement:** Replace the first sentence following the notification table, `The source's catches do not cover all conceivable failures.`, with:

> Both `notify` catches are catch-all handlers for external-call failures, including custom errors, `Panic`, and empty reverts. The catches do not cover all conceivable failures.

The following sentences remain verbatim, including the complete uncaught-failure list and the prohibition on saying that fee-manager failure can never block users.

**Cross-references:** No cross-reference moves. PT-AC-38 and PT-AC-39 retain the notification and approval distinctions; PT-ERROR-04 retains the atomicity consequences of caught and uncaught failures.

**Preservation risks:** Do not narrow the catches to `Error(string)`, broaden them to factory getters, checked arithmetic, malformed approval return data, or call-setup failures, or remove the ERC-20 cleanup approval and its possible decoding failure. Do not add a guarantee that fee-manager failure can never block users.

**Recommended disposition:** Adopt the two-sentence replacement and preserve the remainder of PT-COMP-03 verbatim; add no acceptance row.

## L6 - Remaining-gas native payout and paired refund

**Requirements changed:** PT-BAL-05 and PT-BAL-06.

**Exact replacement in PT-BAL-05:** Replace the Native payout bullet with:

> - Native payout uses an empty-calldata `CALL` with the payout value to the recipient and forwards remaining gas; it does not use a 2300-gas stipend.

**Exact replacement in PT-BAL-06:** Replace its first sentence with:

> Paired-entry refund clears the stored reservation before a nonzero empty-calldata value call to the sender that forwards remaining gas; it does not use a 2300-gas stipend.

**Cross-references:** No cross-reference moves. PT-AC-14 and PT-AC-59 retain refund checkpoint behavior; PT-AC-65 retains native payout failure behavior; PT-ERROR-01, PT-ERROR-03, and PT-ERROR-04 retain their error and rollback rules.

**Preservation risks:** These are new normative r2 sentences, not retrospective claims about r1 wording. Do not introduce `transfer`/`send`-style stipend semantics or a compilation disclaimer. Keep native payout failure wrapped as `WrappedError`, paired refund failure as `TransferFailed`, reservation clearing before the refund, zero-refund call skipping, and the existing chosen-leg zero-value payout behavior.

**Recommended disposition:** Adopt both replacements as normative r2 wording; add no acceptance row.

## L7 - View static calls for consumed reads

**Requirements changed:** PT-BAL-01 and PT-DEPENDS-03.

**Exact replacement in PT-BAL-01:** Replace its second sentence with:

> ERC-20 idle is the token's reported `balanceOf(instance)`, obtained through a `view` static call.

**Exact insertion in PT-DEPENDS-03:** Insert immediately after its first sentence, which lists the required PoolManager interactions:

> Each consumed single-slot `extsload` read is a `view` static call.

**Cross-references:** No cross-reference moves. PT-VIEW-01 retains the storage-layout and slot-consumption rules; PT-ERROR-03 retains manager and token balance-read failure and decoding behavior.

**Preservation risks:** These are new normative r2 sentences, not retrospective claims about r1 wording. Do not add a guard against a non-view dependency, invent a new fallback for static-call failure, or extend this clarification into changed transfer, approval, settlement, or other external-call behavior.

**Recommended disposition:** Adopt the replacement and insertion together; add no acceptance row.

# Conclusions

Adopt L1 through L7 exactly as the local edits above. No requirement ID or acceptance-scenario ID changes, no cross-reference relocation, and no new acceptance rows are recommended. The resulting r2 remains a single standalone PRD: a reader needs no r1 copy, accuracy report, source listing, or companion errata to interpret these requirements.

The coordinator should preserve every other byte of normative content while integrating these sentences into the complete r2 document. This response intentionally does not reproduce the full PRD.

# Limits

This is an authoring contribution based only on the admitted documentation. It does not provide new source verification, runtime evidence, implementation, tests, deployment, or legal conclusions. No Sourcify refetch or public search was performed. The coordinator remains responsible for applying the prose to the complete r2 artifact and verifying that all unaffected content and all 68 scenarios remain present.
