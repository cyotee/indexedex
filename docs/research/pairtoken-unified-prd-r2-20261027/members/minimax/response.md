# Pair Token PRD r2 - MiniMax council-member response

## Identity

- Run ID: pairtoken-unified-prd-r2-20261027
- Role: council-member (MiniMax), independent initial pass
- Model route: minimax/MiniMax-M3, adaptive-thinking setting admitted; not a selectable depth
- Owned response: docs/research/pairtoken-unified-prd-r2-20261027/members/minimax/response.md
- Contribution type: research authoring. Not a defect review, not an advisory pass, not a vote for any other member.
- Fresh context: yes. Peers read before submission: no.
- Source PRD identity used: pairtoken-unified-prd-r1, raw SHA-256 recomputed on this machine as `1824df69b7f64cc15252a7ae877d3b3f762773db5bfc4f091591eb1af8a7f6d2`, which matches the assigned hash exactly. The r1 file was read only and was not edited.
- r1 PRD size read: 640 lines, 95,049 bytes, read in full.

## Question and targets

Question: what exact standalone prose integrates every authorized accuracy clarification into one complete Pair Token PRD, without adding behavior or requiring any companion file?

Targets used:

- `docs/research/pairtoken-unified-prd-r2-20261027/brief.md` (run, authorization, authoring contract, the seven clarifications).
- `docs/research/pairtoken-unified-prd-20261027-01a17e03/handoff/PRD.md` (identity pairtoken-unified-prd-r1, hash-verified) - read completely.
- `docs/reviews/pairtoken-prd-sourcify-accuracy-20261027/REMEDIATION_PRD.md` - read only to confirm the seven clarifications and their in-PRD anchors.

Not read, by instruction: member originals, the old requirements, errata, source, any other file. No Sourcify refetch. Nothing was sent to a search or fetch service.

Deliverable shape: local replacement or insertion prose for each of the seven clarifications, the requirement ID each one changes, the cross-references that must move with it, preservation risks, and a recommended disposition. No second PRD body, no source listings, no source line locators.

## Evidence

Anchor verification against the hash-verified r1 PRD (anchors are given as requirement ID plus exact existing text, because r2 line numbers will shift):

| Item | Requirement | Existing text confirmed in r1 |
| --- | --- | --- |
| L1 | PT-EXIT-01 | "Read position liquidity after the burn." |
| L2 | PT-MATH-02 | "Both amount functions sort their two supplied endpoints. The amount0 function rejects a zero lower endpoint with `InvalidPrice()`, including for zero liquidity. Amount1 uses the absolute endpoint difference and does not apply that price-zero check." |
| L3a | PT-MATH-03 | "Equal bounds produce a division failure." |
| L3b | PT-AC-55 | Expected-observation cell: "Respect `Q96`, `InvalidTick`, division failure, and checked candidate cast respectively. Do not rescue a cast overflow by selecting the other candidate first." |
| L4 | PT-CB-02, Add row | Cell: "Positive liquidity modification for that amount, including zero if explicitly requested by callback data" |
| L5a | PT-COMP-03, native row | Cell: "Call `notify(address(0), amount, poolId)` with that native value. Successful completion reports `amount`. A caught notification revert reports zero and leaves the reverted payment in the instance." |
| L5b | PT-COMP-03, ERC-20 caught row | Label "ERC-20, notification revert caught"; cell: "Attempt `approve(feeManager,0)`, ignore its returned Boolean, and report zero. A decoding failure in that cleanup approval can still propagate." |
| L5c | PT-COMP-03, closing paragraph | "The source's catches do not cover all conceivable failures. Factory getter failures, checked arithmetic, malformed approval return data, and local/dependency call-setup failures can abort an operation. Do not specify "fee-manager failure can never block users." A successful notification is not proof that an ERC-20 allowance was consumed or tokens were pulled. Any actual token movement depends on the fee manager and token." |
| L6a | PT-BAL-05 | Bullet: "Native payout uses an empty-calldata value call to the recipient." |
| L6b | PT-BAL-06 | "Paired-entry refund clears the stored reservation before a nonzero empty-calldata value call to the sender." |
| L7a | PT-VIEW-01 | "Position liquidity is read from the first word of that position entry." |
| L7b | PT-BAL-01 | "ERC-20 idle is the token's reported `balanceOf(instance)`." |
| L7c (optional) | PT-DEPENDS-03 | "and external storage reads through `extsload(bytes32)->bytes32`." |

Additional checks run on the hash-verified r1 PRD:

- Case-sensitive search for `static`, `stipend`, `gas()`, `remaining gas`: zero matches in the whole document. L6 and L7 are therefore genuinely new normative wording in r2 and are not restatements of an existing r1 sentence.
- The seven clarifications, their wording and their L3 anchors match the accuracy report's L1-L7 items, including the corrected L3 anchors (the equal-bounds sentence in PT-MATH-03 and the PT-AC-55 row), not the earlier 142/549 citations.
- No existing r1 sentence already requires remaining-gas forwarding or a static call context, so neither L6 nor L7 can be phrased as a claim about r1.

## Assumptions

- "Unadorned revert" is used in the PRD's own existing sense from PT-MATH-01 ("these helper failures use an unadorned revert"): a revert carrying no custom error and no reason string. I reuse the PRD's term instead of inventing a new one.
- "Panic" in L5 names a compiler-raised panic inside the callee, caught by a bare catch. It is unrelated to L3's prohibition on asserting a panic selector for the equal-bounds and zero-spacing paths. The two items must not be conflated in the integrated text.
- The coordinator integrates the prose below into one complete r2 document. I supply only local replacement or insertion text plus its rationale; I do not restate the other 620 lines.
- Where a replacement covers a whole sentence or cell, the replacement text is complete and self-contained, so the coordinator can substitute it mechanically without reconciling fragments.
- The L6 sentence is written as a requirement on the instance's own call, not as a description of an archived document, and carries no compilation disclaimer.

## Coverage

| Item | Requirement IDs touched | Edits | New acceptance rows | New requirement IDs |
| --- | --- | --- | --- | --- |
| L1 | PT-EXIT-01 | 1 sentence replaced | 0 | 0 |
| L2 | PT-MATH-02 | 1 paragraph replaced | 0 | 0 |
| L3 | PT-MATH-03, PT-AC-55 | 1 sentence replaced, 1 cell replaced | 0 | 0 |
| L4 | PT-CB-02 (Add row) | 1 cell replaced | 0 | 0 |
| L5 | PT-COMP-03 | 2 cells replaced (1 with label), 1 sentence inserted | 0 | 0 |
| L6 | PT-BAL-05, PT-BAL-06 | 1 bullet replaced, 1 sentence replaced | 0 | 0 |
| L7 | PT-VIEW-01, PT-BAL-01, PT-DEPENDS-03 (recommended) | 1 sentence inserted, 1 clause replaced, 1 fragment annotated | 0 | 0 |

Totals: 7 clarifications, 9 required edits plus 1 recommended annotation, 0 new acceptance rows, 0 new requirement IDs. Every existing requirement ID, all 68 acceptance scenarios, the ABI, constants, formulas, rounding, casts, operation and check order, events, errors, dependency limits and the absent-behavior list are preserved.

## Conclusions

Recommended disposition for every item: **adopt as a local sentence change**, with **no new acceptance row**. The reason is uniform - each clarification restates or disambiguates behavior that an existing scenario already observes, and a new scenario ID would read as a new observable requirement. The brief also prefers a sentence over a new row.

### L1 - checked payout is calculated before the position-liquidity read

Requirement changed: **PT-EXIT-01** (Shared redemption checkpoints).

Replace the final sentence of the PT-EXIT-01 body:

> Read position liquidity after the burn.

with:

> After the burn, calculate the checked payout of PT-EXIT-02 and only then read position liquidity.

Everything else in PT-EXIT-01 stays byte-identical, including the preceding sentence "Insufficient share balance fails checked subtraction."

Cross-references that move with it:

- PT-ERROR-02, "Paired exit" row, already reads "recipient, compound, zero shares/supply, idle reads, caller balance burn, retention arithmetic/liquidity read/removal, minima, payouts." It already places retention arithmetic before the liquidity read, so it needs no edit and must not be reordered. The new PT-EXIT-01 sentence agrees with it rather than duplicating it.
- PT-ERROR-02, "Zap exit" row ("recipient and output token before the same shared redemption path") inherits the order automatically, because both exit routes share PT-EXIT-01.
- PT-EXIT-02 keeps its formulas unchanged: `payout = floor(s*9990/10000)` with checked multiplication, `ell = low128(MD(L,payout,S))`, and the `a0`/`a1` expressions. The new sentence names where the payout is computed; it neither restates nor relocates the formulas.
- PT-AC-23, PT-AC-24, PT-AC-25, PT-AC-26, PT-AC-62 stay valid: they assert amounts, precedence and read order, not the position of the payout computation.

Preservation risks:

- Anchoring matters. The sentence must begin "After the burn"; a shorter "calculate the checked payout, then read position liquidity" could be read as placing the payout before the burn.
- "only then" must not be read as constraining the removal request. PT-EXIT-02 already orders the removal request after `ell` is derived from `L`; the new sentence constrains only the payout/read order.
- PT-EXIT-02 lists `L` among the decomposition's inputs. The new sentence makes clear that `L` is *read* after the payout, not that `L` is unavailable to the payout.
- Do not "clarify" PT-ERROR-02 further. Two normative statements of the same order in two requirements is a drift risk.

Disposition: adopt; one sentence replaced in PT-EXIT-01; no new acceptance row.

### L2 - amount0 sorts its endpoints, amount1 uses the absolute endpoint difference

Requirement changed: **PT-MATH-02** (Amount deltas).

Replace the two endpoint sentences:

> Both amount functions sort their two supplied endpoints. The amount0 function rejects a zero lower endpoint with `InvalidPrice()`, including for zero liquidity. Amount1 uses the absolute endpoint difference and does not apply that price-zero check.

with:

> The amount0 function sorts its two supplied endpoints and rejects a zero lower endpoint with `InvalidPrice()`, including for zero liquidity. The amount1 function uses the absolute endpoint difference and does not apply that price-zero check.

The third sentence of that paragraph ("`L` has width `uint128` and endpoints have width `uint160`; `L*Q96` fits in `uint256`.") is unchanged, as are the four formulas `A0down`, `A0up`, `A1down`, `A1up` and the preceding `Q96`/`Q128` definitions.

Cross-references that move with it:

- PT-VIEW-02's "Their endpoint sorting, not an idealized range-position valuation, controls out-of-range results." stays unchanged and remains numerically true, because the absolute difference equals the sorted difference. This is the only other sentence describing both amount functions' endpoint handling; it is outside L2's scope and must not be edited under this run.
- PT-MATH-03 keeps its own ordering step ("After ordering bounds `a <= b`") and its `Fit` table; it is unaffected.
- PT-AC-33 ("Basket applies its supplied endpoint pairs with sorting and no clamp") is a basket observation and stays as is.

Preservation risks:

- Do not fix this by deleting the word "Both". That leaves "amount functions sort their two supplied endpoints" ungrammatical and drops the amount1 rule. Replace the whole two-sentence span.
- "Amount1" becoming "The amount1 function" is a cosmetic change inside the replaced span; it mirrors the amount0 wording and changes no result.
- The integers are unaffected either way: for sorted endpoints `|b-a| = b-a`, so no formula, scenario, or quoted number changes.

Disposition: adopt; two-sentence replacement in PT-MATH-02; no new acceptance row.

### L3 - equal bounds fail through the MD helper's unadorned revert, not the initialization division

Requirement changed: **PT-MATH-03** (Amounts to liquidity) and the expected-observation cell of **PT-AC-55**.

Replace, in PT-MATH-03:

> Equal bounds produce a division failure.

with:

> Equal bounds make the `b-a` divisor zero, so the `MD` helper fails with the unadorned revert specified in PT-MATH-01. That is a different failure from the zero-spacing initialization division failure of PT-INIT-02; the two shall not be normalized into one application error. PT-ERROR-03 governs both failure classes, and this PRD names no panic selector for either path.

Replace, in the PT-AC-55 row, the expected-observation cell:

> Respect `Q96`, `InvalidTick`, division failure, and checked candidate cast respectively. Do not rescue a cast overflow by selecting the other candidate first.

with:

> Respect `Q96`, `InvalidTick`, the equal-bounds `MD` helper's unadorned revert, and checked candidate cast respectively. The equal-bounds failure is that helper's unadorned revert, not the zero-spacing initialization division failure. Do not rescue a cast overflow by selecting the other candidate first.

The PT-AC-55 scenario column ("Mathematical helper boundary: `T(0)`, tick outside range, equal liquidity-price bounds, or oversized one-side liquidity candidate") and its requirements cell (`PT-MATH-02/03/04`) are unchanged.

Cross-references that move with it:

- PT-MATH-01 already states that `MD` and `MU` "reject `c=0` or an out-of-range result; these helper failures use an unadorned revert." The new PT-MATH-03 sentence points at it; PT-MATH-01 needs no edit.
- PT-ERROR-03 already requires that helper plain reverts and helper custom errors be preserved rather than normalized, and already states that "Standard Solidity 0.8.26 ABI and panic behavior is part of the compilation contract". It stays exactly as written; in particular it must not be edited to name a selector.
- PT-INIT-02's "Zero spacing causes division failure and rolls back the entire initialization." stays verbatim and is now cited as the distinct failure.
- PT-AC-03's zero-spacing expectation ("fresh zero-spacing call fails arithmetic and leaves initialization unset") stays as is.

Preservation risks:

- Do not write a panic selector (for example `Panic(0x12)`) anywhere in the r2 body. The underlying inference was never executed, and the brief prohibits asserting one.
- Do not replace the words "unadorned revert" with a paraphrase such as "division by zero"; that is exactly the ambiguity L3 removes.
- Do not add a guard (for example, an early local rejection of equal bounds with a custom error). The failure stays an arithmetic failure inside the helper.
- The `L0`/`L1` definitions and the `Fit` table in PT-MATH-03 are untouched.

Disposition: adopt; one sentence replaced in PT-MATH-03 and one cell replaced in PT-AC-55; no new acceptance row (PT-AC-55 already covers the boundary and is amended in place).

### L4 - the Add callback row says nonnegative liquidity modification

Requirement changed: **PT-CB-02**, the `1 / Add` row of the operation-encoding table.

Replace the manager-action cell:

> Positive liquidity modification for that amount, including zero if explicitly requested by callback data

with:

> Nonnegative liquidity modification for that amount, including zero if explicitly requested by callback data

The row's payload column (`ABI `uint128 liquidity``), its return column (`(uint256 used0,uint256 used1)`) and every other row of the table are unchanged.

Cross-references that move with it:

- The `2 / Remove` row ("Negative liquidity modification for that amount; zero remains a zero change") and the `3 / Collect` row ("Zero liquidity modification") stay verbatim. After this change the Add row uses the same nonnegative/zero vocabulary as its neighbors.
- PT-CB-03 stays as is; it describes the `modifyLiquidity` call shape and the caller/fee deltas without any positivity rule.
- PT-CB-05 stays as is; it governs the Deploy-time decision to request a modification and how zero is reported, not the callback payload rule.
- PT-AC-46's "No new callback liquidity-positive check is added." stays and is consistent with the new wording.

Preservation risks:

- Keep the zero clause verbatim. Fixing "positive" while dropping "including zero if explicitly requested by callback data" would remove the express permission for an explicit zero payload.
- "Nonnegative" must not be read as requiring a nonzero payload; the row's own zero clause and PT-CB-05/PT-AC-46 forbid that reading.
- Do not add a range statement (for example "at most `uint128` max"). The ABI type already carries the bound.

Disposition: adopt; single-cell replacement; no new acceptance row.

### L5 - both notify catches are catch-all external-call failures

Requirement changed: **PT-COMP-03** (Protocol notification semantics).

Replace the native row's required-behavior cell:

> Call `notify(address(0), amount, poolId)` with that native value. Successful completion reports `amount`. A caught notification revert reports zero and leaves the reverted payment in the instance.

with:

> Call `notify(address(0), amount, poolId)` with that native value. Successful completion reports `amount`. The notification catch is catch-all over that external call: a reverted custom error, a Panic, and an empty revert are all caught. A caught notification failure reports zero and leaves the reverted payment in the instance.

Replace the ERC-20 caught row. Label:

> ERC-20, notification revert caught

becomes

> ERC-20, notification failure caught

and its required-behavior cell:

> Attempt `approve(feeManager,0)`, ignore its returned Boolean, and report zero. A decoding failure in that cleanup approval can still propagate.

becomes

> The notification catch is catch-all over that external call: a reverted custom error, a Panic, and an empty revert are all caught. Attempt `approve(feeManager,0)`, ignore its returned Boolean, and report zero. A decoding failure in that cleanup approval can still propagate.

Insert as the first sentence of the paragraph that closes PT-COMP-03:

> The source's notification catches are catch-all over the notification external call itself and cover nothing else.

The rest of that paragraph stays verbatim:

> The source's catches do not cover all conceivable failures. Factory getter failures, checked arithmetic, malformed approval return data, and local/dependency call-setup failures can abort an operation. Do not specify "fee-manager failure can never block users." A successful notification is not proof that an ERC-20 allowance was consumed or tokens were pulled. Any actual token movement depends on the fee manager and token.

Cross-references that move with it:

- PT-AC-38 ("Caught native failure reports zero. Caught ERC-20 failure attempts allowance reset and reports zero, unless an unhandled cleanup/decode failure aborts.") stays valid; the catch-all widens what is caught without changing what the caught path reports.
- PT-AC-39 ("A factory getter failure also propagates instead of being swallowed by the notification catch") stays valid, because the catch-all is scoped to the notification call only.
- PT-COMP-02's uncapped-protocol-amount example and its checked-subtraction rollback stay untouched.
- PT-ERROR-03 ("External failures cause the outer operation to fail except at the precise fee-notification and low-level-approval boundaries already specified") and PT-ERROR-04 ("Caught protocol-notification failures are exceptions that can allow the outer operation to continue") stay; the clarification stays inside those boundaries.
- PT-BAL-04 (approval helper semantics) stays; "malformed approval return data" remains on the retained uncaught list.

Preservation risks:

- Never write "fee-manager failure can never block users". The existing instruction sentence that forbids it stays in place.
- Do not widen the catch-all to the whole routing step. If the catch were described as covering the approval helper or the factory getters, the retained uncaught list would contradict it. The scope sentence "over the notification external call itself and cover nothing else" is what keeps the two consistent.
- Keep the retained list of uncaught failures word-for-word: factory getter failures, checked arithmetic, malformed approval return data, local/dependency call-setup failures.
- The row label rename is a label-only change with no behavior. If the coordinator prefers zero label churn it may keep "notification revert caught", but that label is then narrower than the catch-all stated in the same row.
- "Panic" here is a caught callee outcome, not a panic selector; keep it separate from L3's prohibition.

Disposition: adopt; two table-cell replacements (one with its label) and one inserted sentence; no new acceptance row (PT-AC-38 and PT-AC-39 already describe the caught and uncaught paths).

### L6 - native payout and paired refund forward remaining gas; neither is a 2300-gas stipend

Requirement changed: **PT-BAL-05** (User payout helper) and **PT-BAL-06** (Native refund difference).

Replace the first bullet of PT-BAL-05:

> - Native payout uses an empty-calldata value call to the recipient.

with:

> - Native payout uses an empty-calldata value CALL to the recipient, forwarding all remaining gas. It is not a 2300-gas stipend call.

Replace the second sentence of PT-BAL-06:

> Paired-entry refund clears the stored reservation before a nonzero empty-calldata value call to the sender.

with:

> Paired-entry refund clears the stored reservation before a nonzero empty-calldata value call to the sender that forwards all remaining gas; it is not a 2300-gas stipend call.

The remaining PT-BAL-05 content is unchanged: the ERC-20 payout bullet, the `WrappedError(address target,bytes4 selector,bytes reason,bytes details)` bullet with `bytes4(0)` for native and the `NativeTransferFailed()`/`ERC20TransferFailed()` details, and the closing paragraph about nominal transfer amounts and uncompensated fee-on-transfer effects. The remaining PT-BAL-06 content is unchanged: "Refund failure uses PairToken `TransferFailed`, not the wrapped payout error. Refund zero skips the call. Native receipts outside a reservation are idle property; the receiver does not authenticate a manager or refund sender."

Cross-references that move with it:

- PT-ERROR-01's `TransferFailed` row and PT-ERROR-03 stay as is; gas policy is not a failure mode and introduces no new error.
- PT-DEPENDS-05 ("recipient acceptance of native value ... not supplied") stays; forwarding all remaining gas does not imply that a recipient accepts the value.
- PT-AC-65 (native payout rejected by the recipient, `WrappedError` with `bytes4(0)` and the complete raw reason bytes) and PT-AC-59 (refund after minting, zero refund skips the call) stay valid.
- The two sites are named differently on purpose: the payout is the low-level CALL in the currency helper, the refund is a Solidity value call. Both forward all remaining gas and neither is a stipend call.

Preservation risks:

- The sentence must be written as a requirement on the instance's own call. It must not read as a claim about the archived r1 or as a historical statement; r2 states it as a normative requirement and the r2 document is what a reader needs.
- Do not put a compilation disclaimer in the PRD body (for example "subject to compiler defaults" or "as compiled today"). The brief forbids it, and the requirement is the instance's call regardless.
- Keep the payout and refund sentences separate. They have different call sites, different error shapes (`WrappedError` versus `TransferFailed`), and different zero-skip rules; merging them would blur both.
- "Forwards all remaining gas" must not be expanded into an execution claim such as "the recipient may consume arbitrary gas" or "the recipient will accept the payment". It is a statement about the gas argument of the CALL.
- "Not a 2300-gas stipend call" is a prohibition of the alternative. Do not let it drift into permitting a different fixed cap.

Disposition: adopt; one bullet replaced in PT-BAL-05 and one sentence replaced in PT-BAL-06; no new acceptance row.

### L7 - the consumed extsload read and the token balanceOf idle read are view static calls

Requirement changed: **PT-VIEW-01** (Manager state identity) and **PT-BAL-01** (Idle property).

In PT-VIEW-01, insert after the sentence "Position liquidity is read from the first word of that position entry.":

> Each of those storage reads is a single-slot `extsload(bytes32)->bytes32` `view` static call.

In PT-BAL-01, replace the clause:

> ERC-20 idle is the token's reported `balanceOf(instance)`.

with:

> ERC-20 idle is the token's reported `balanceOf(instance)`, read as a `view` static call.

Recommended consistency annotation, in **PT-DEPENDS-03**, so that Part III alone tells a planner the call context of the interface it lists. Replace the trailing fragment:

> and external storage reads through `extsload(bytes32)->bytes32`.

with:

> and external storage reads through `extsload(bytes32)->bytes32`, a `view` function.

This annotation adds no behavior: it records the mutability of a dependency interface whose call context PT-VIEW-01 already fixes.

Cross-references that move with it:

- PT-DEPENDS-05 ("ERC-20 balance, approval and transfer implementations ... are not supplied") stays. The view requirement binds how the instance calls, not what the token's implementation is.
- PT-BAL-02's pull-measurement reads are a separate checkpoint and stay untouched (see Limits).
- Every idle-pair sampling site inherits the statement without edits: PT-VIEW-02 (basket), PT-DEP-03 (paired addition), PT-COMP-04 (compound idle sample), PT-CB-05 (Deploy addition), PT-EXIT-01 (redemption idle sample). PT-BAL-01's "read currency0 idle before currency1 idle" rule is unchanged.
- PT-AC-31 (donation) and PT-AC-62 (idle-pair read order) stay as is.

Preservation risks:

- Do not add a guard: no requirement may check that a dependency is view, fall back to a non-view call, or revert when a dependency turns out to be non-view. The sentence is about the instance's call, and nothing else.
- Do not phrase it as a constraint on the manager's or token's implementation ("the manager must implement `extsload` as `view`"). The requirement is about the read the instance performs.
- Do not present this as already required by r1; it is new normative wording.
- The PT-VIEW-01 insertion is additive only. The paragraph's other sentences, including "These are dependency-access semantics, not an assertion that every address satisfying the manager ABI has that layout", stay.

Disposition: adopt; one sentence inserted in PT-VIEW-01, one clause replaced in PT-BAL-01, and the recommended PT-DEPENDS-03 annotation; no new acceptance row.

### Optional acceptance rows

**Recommended: none.** Each clarification is already observable in an existing scenario - PT-AC-23/24 (L1), PT-AC-33 (L2), PT-AC-55 amended in place (L3), PT-AC-46 (L4), PT-AC-38/39 (L5), PT-AC-59/65 (L6), PT-AC-31/62 (L7). Adding PT-AC-69 or later would introduce a new ID and read as a new requirement rather than a clarification of an existing one. If the coordinator wants L6 and L7 to be visible in the scenario part of the document, the sentence-level edits above are the cheaper and more faithful route.

### Coordinator-side publication hygiene (not one of the seven items, flagged only)

The r2 document must carry its own identity and must not require r1. Concretely: the header line "Document identity: pairtoken-unified-prd-r1." becomes "Document identity: pairtoken-unified-prd-r2.", the sentence "This PRD supersedes the archived pairtoken-requirements-final-r2 and its proposed errata as the single working specification." gains r1 as an archived predecessor, and the sentence "All original requirement identifiers and PT-AC-01 through PT-AC-58 are retained. PT-CONFORM-03 is the single added requirement identifier, and PT-AC-59 through PT-AC-68 are ten added acceptance scenarios." stays true, with one clause noting that r2 integrates accuracy clarifications without adding or removing any identifier. These are publication duties of the coordinator, not authorized clarifications from this member.

## Limits

- This is static reading of the hash-verified r1 PRD plus the accuracy report's findings and recommendations. No build, no test, no execution, no source re-read, no Sourcify refetch, and no external service call of any kind.
- The L6 and L7 sentences are authored as authorized normative wording. I did not independently confirm gas forwarding or static-call context by compilation or execution; the accuracy report records that Solidity `.call` gas forwarding and the unchecked-division panic were not confirmed by execution. The r2 text therefore states the requirement without an evidentiary disclaimer, and the requirement itself carries the weight.
- I read the whole r1 PRD but verified only the seven authorized clarifications against it. I make no claim about the accuracy of the other 620 lines.
- Residual, deliberately outside the authorized seven: PT-BAL-02's pull-measurement reads (the pre-call and post-call `balanceOf` around `transferFrom`) are also token balance reads, but they are not the idle read that L7 names, so they keep their current wording. If the coordinator judges that the view context should cover those reads as well, that is a separate authorization, not part of this contribution.
- Residual, deliberately outside the authorized seven: PT-VIEW-02's "Their endpoint sorting" and PT-AC-33's "sorting" continue to describe both amount functions. They remain numerically equivalent after L2 because the absolute difference equals the sorted difference, but a reader who wants the same vocabulary everywhere would need an explicit decision.
- The equal-bounds and zero-spacing paths remain without a named panic selector in r2, and PT-ERROR-03's statement that standard Solidity 0.8.26 ABI and panic behavior is part of the compilation contract remains the governing sentence.
- Cross-reference anchors in this response are quoted from the hash-verified r1 bytes. After integration, r2 line numbers differ; the coordinator should locate the same sentences by their exact existing text.
- I did not read peer responses, member originals, the old requirements, errata or source, and I do not vote for any other member.
