# PRD consistency and quality — Astra

## Conclusion

**No blocking clarification identified. The current PRD is sufficiently specific to implement stage 1 after an explicit implementation request.**

I read the complete current `REMEDIATION_PRD.md` (362 lines, updated 2026-10-06). I did not read other reviewers' new answers, inspect implementation changes, run commands, or edit code. This assessment concerns requirements consistency, not verification that the current source implements them.

OD-01 through OD-07 close the earlier owner choices:

- REQ-01/02 distinguish a successful zero preview from a reverting dependency. The interface-probe catch is expressly excluded from this stage's decision; it must not be silently treated as approved D37 closure.
- REQ-07 removes the self-snapshot branch rather than replacing it with a mandatory snapshot. The caller-supplied projection path and D48 safe-preview handling remain.
- REQ-06 defines the primary share cap, positive-payout eligibility, receipt-liquidity bound, and dependent `maxWithdraw`. There is no remaining choice between the former double-floor calculation and an uncapped owner-balance return.
- REQ-05 no longer requires historical red execution or reconstructing obsolete accounting boundaries on replacement vaults.
- OD-05 preserves the current FullSpread package split and expressly excludes authorizing a Pons-bound wings package.
- OD-06 distinguishes scoped stage-1 repair validation from stage-2 program-wide verification and submission approval. A targeted wings regression in REQ-05 is not certification of the whole wings product; those statements are compatible.
- OD-07 permits the required executable production-route tests while restricting descriptions in names, comments, and reports. The earlier test-content ambiguity is resolved.

## Blocking questions

**None.** I would not reopen the recorded owner decisions or ask the owner to choose implementation mechanics already constrained by their invariants.

## Non-blocking quality notes

These are wording/checklist improvements, not additional policy choices or new defects.

### NQ-01 — Qualify the zero-limit case in the redemption acceptance sentence

- **Reference:** OD-03:123–126; REQ-06:271–275.
- REQ-06 explicitly permits `maxRedeem == 0` when no eligible positive-payout amount exists. Its next sentence says “redeem at maxRedeem succeeds” without qualifying that case.
- Read that success criterion as applying when the returned maximum is **positive**, with ordinary authorization/receiver/transfer preconditions satisfied. It must not be interpreted as requiring a zero-share redemption to succeed.
- Adding that qualifier and an explicit no-eligible-payout test would improve the checklist. The preceding positive-payout rule already determines the intended result, so this is not an owner-choice blocker.

### NQ-02 — Enumerate all three residual outcomes in the test checklist

- **Reference:** REQ-01:188–191.
- The bullets specify three outcomes: successful zero preview with retention; nonzero preview followed by operative failure; and reverting preview. “Tests assert those two outcomes” at line 191 is an imprecise summary.
- Replace “two” with an explicit reference to all three outcomes. Exact failure propagation and unchanged state should remain distinct from successful booked retention. The preceding acceptance bullets already require all three.

### NQ-03 — Keep held inventory distinct from available input credit

- **Reference:** REQ-05:249,253–254; whole-PRD non-goal:355; retained D12/D15 rules.
- “Credit uses only tokens the vault holds” is a necessary but not sufficient assertion: held inventory can include booked backing. The outside-trade regression should also bind credit to the applicable unbooked availability/observed-delivery rule and preserve booked inventory, with a funded positive control.
- This follows the retained locked accounting requirements; it is not a request to change OD-04 or reintroduce historical stored-total cases. An explicit cross-reference would prevent an implementer from mistaking a physical-balance bound for the complete property.

### NQ-04 — State what the low-budget rate test isolates

- **Reference:** OD-02:105–109; REQ-07:289–293.
- The low-budget acceptance test should use a budget sufficient for the ordinary live-preview path. It proves removal of gas-dependent snapshot selection, not an impossible promise that any arbitrarily small budget returns a rate.
- Separately test snapshot acquisition failure at the caller that requests the snapshot, and supplied-state quote failures on the projection path. Preserve D48's specified quote-candidate failure behavior; “no fallback to live rate” is not permission to remove that existing exception.
- These are test-boundary clarifications already implied by OD-02 and REQ-07's non-goals, not unresolved fix choices.

### NQ-05 — Label stage-1 evidence as provisional rather than submission certification

- **Reference:** OD-06:158–160; REQ-08:305–309.
- REQ-08 still uses “submission tree” and “disposition used for submission.” During stage 1, the implementation should produce a source-bound current map and repair-run evidence, with stage-2 verification explicitly pending.
- Stage 2 must refresh or validate those identities if the source changes before submission. This reconciles REQ-08 with OD-06 without weakening either requirement or certifying all 108 criteria during stage 1.

### NQ-06 — Preserve the explicit exclusions in the handoff

- **Reference:** REQ-01:192; OD-04:136; whole-PRD non-goal:354.
- Leaving the `supportsInterface` probe disposition out of REQ-01 is a scoped deferral, not a newly approved catch exception. Record it as unresolved for the broader pass rather than claiming exhaustive D37 closure.
- Not requiring old vulnerable source to compile for a historical demonstration does not itself authorize deleting that source. The whole-PRD read-only preservation restriction still supplies the stage-1 boundary. No deletion is necessary to execute the required replacement-vault tests.

**Stage-1 handoff assessment:** executable as written with the recorded ODs taking precedence over superseded requirements. The quality notes above can tighten the acceptance checklist without another owner decision. Stage-1 success remains explicitly insufficient for audit submission.
