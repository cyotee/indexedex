# Grok — remediation PRD consistency

Reviewer: Grok. Targeted follow-up. OD-01 through OD-07 were not re-opened. No peer answer files were read. No code was edited.

Stage 1 is not consistent enough to implement as written. Two contradictions change the fix or the stage-1 test. Other requirements are executable once those are resolved.

## Blocking clarifications

### GQ-C01

- **Id:** GQ-C01
- **Affects:** OD-01, REQ-01, REQ-02
- **Contradiction:** OD-01 says a preview result of `0` is the only signal that a residual cannot be processed, the leftover stays booked to holders, and the operative join is not called. REQ-01 then points the book-and-wait path at `_pairQuoteIsZero`, which is a successful Standard Exchange `previewExchangeIn` of `0`, and tells the implementer to remove the hook-join translation catches. Those catches today sit in front of hook `joinSingleAssetExactIn` / `joinUnbalanced`, not in front of that SE preview. REQ-02, which OD-01 also decides, says a zero residual preview "stays owned locally" and its non-goal says not to change a D6 path that already matches. "Booked to holders" and "owned locally" are not the same result in this tree.
- **Outcomes that change the fix:**
  1. Book-and-wait applies only to a successful SE `previewExchangeIn` of `0`. Hook residual joins become hard calls. A hook preview of `0`, or a join revert, rolls the parent back. REQ-02's test asserts the hook amount is not paid out and does not add a new holder-reserve update.
  2. Book-and-wait also applies to a successful hook join preview of `0`. The hook join is not called after that zero. A reverting hook preview, or a join revert after a nonzero preview, rolls the parent back. The leftover is booked to holders on both the DETF path and the hook path. REQ-02's "locally owned" wording is replaced by that book assertion.

### GQ-C02

- **Id:** GQ-C02
- **Affects:** OD-04, OD-06, REQ-05, REQ-08
- **Contradiction:** OD-06 says stage 1 implements and tests the repairs in this PRD, and that stage 1 does not certify the wings vault. Stage 2 is what covers the new vaults and the broader APEX program. OD-04 and REQ-05 require an outside-trade credit test for both FullSpread and the wings vault. REQ-08 requires a current-tree map plus regenerated build, selector, size, and named APEX regressions, and also says that regeneration is a separate execution request. The wings vault sources exist under `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`, so the obstacle is scope, not a missing directory.
- **Outcomes that change the stage-1 test:**
  1. Stage 1 includes the FullSpread outside-trade test, the wings outside-trade test, the snapshot-to-current map, and the regenerated build, selector, size, and named APEX regressions. Stage 1 is not done without those results.
  2. Stage 1 includes only the FullSpread outside-trade test, the relabeling of the reserve-reconcile supplement, and the source map. The wings outside-trade test and the regenerated build, selector, size, and APEX regressions wait for stage 2. REQ-05 and REQ-08 acceptance criteria must say that split, or an implementer will either skip a required test or run the submission suite inside stage 1.

## Non-blocking quality notes

- OD-02 and REQ-07 agree. Delete the empty-state self-snapshot. Keep caller-supplied `quoteRate` and the D48 exact-length rule. No further choice is required for that repair.
- OD-03 and REQ-06 agree. `maxRedeem` is the largest owner share amount whose `previewRedeem` is at least one receipt and no greater than held receipts. `maxWithdraw` is `previewRedeem` of that cap. A zero-receipt burn is not advertised. Do not invert `maxWithdraw` through `convertToShares`.
- REQ-01's non-goal already tells stage 1 not to decide the `supportsInterface` probe. Leave that catch untouched. The general OD-01 sentence "any revert rolls back" should not be read as deleting a site this PRD explicitly defers.
- OD-04 does not order deletion of preserved Uniswap V3/V4 source. The whole-PRD non-goal still forbids changing that source. Stage 1 should not delete it.
- REQ-03 and REQ-04 name the tests and the assertions. The exact error selectors are in the production functions those tests must reach. That is not an owner choice.
- Kimi F3 and F4 remain out of this PRD. Do not pull them into stage 1.
