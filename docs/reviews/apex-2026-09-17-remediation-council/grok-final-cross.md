# Grok final-clarity cross-review

- Reviewer: Grok (xai/grok-4.7)
- Date: 2026-09-25
- Current draft re-read at the cited lines. Peer files were not read. The remediation PRD was not edited.
- Own clarity findings are not withdrawn.
- Human questions that remain: none.

## Own must-fix items

Both still stand. Re-read of the current draft did not remove them.

### Line 231 remainder — still a must-fix

- Verdict: still stands
- Current text: line 94 still allows “remainder stays booked” **or** “an exact-asset withdrawal whose share charge matches the preview.” Line 231 still says “Any redemption remainder stays booked on the SE.”
- Why it still matters: an exact-asset `withdraw` of the shortfall creates no remainder. It meets lines 93 and 95 and fails line 231. That is a handoff contradiction, not a new product choice.
- Fix that does not need a ruling: rewrite line 231 so the recipient delta equals the accounted due amount, and any remainder the chosen method does create stays booked and is not paid to the recipient or to `feeTo`. Do not require a remainder to exist.

### Line 142 second implementation — still a must-fix

- Verdict: still stands
- Current text: line 140 and test row 234 still allow delete **or** route through the installed guarded helper. Line 142 still says the source “must not retain a second public money implementation.”
- Why it still matters: sharing the helper retains a second `exchangeOut` that is no longer the unguarded refund. An implementer who follows line 140 can fail line 142.
- Fix that does not need a ruling: qualify line 142 so the banned residue is a second public `exchangeOut` that still refunds `maxAmountIn - amountIn` without the credit cap and caller check.

## Peer claims

### Astra — no must-fix and no human question

- Verdict: **Dissent on “no must-fix.” Agree that no human question remains.**
- Lines 94 and 231 still conflict. Lines 140, 142, and 234 still conflict. Those are handoff defects even though neither needs an owner ruling.
- Agree that line 142 should be qualified so helper-sharing remains allowed. That is the same edit as the second must-fix. Calling it optional wording understates the contradiction.
- Agree that blanket red/green language should point at the explicit evidence alternatives. That matches the wording cleanup on line 59 versus lines 183–184, 234, and 237. It does not change the requirement.
- Agree that “live D16” and “empty panic” are wording only. They were not must-fix items. Line 236 already says a below-book request authorizes zero new credit and reverts the family’s existing insufficient-credit error rather than an empty panic.

### MiniMax — no must-fix; no human question

- Verdict: **Dissent on “no must-fix.” Agree that no human question remains.**
- The two contradictions above are still in the current draft. They do not reopen product law. They do need to be aligned before an implementer treats the test row and line 142 as the stricter rule.

### Kimi — must fix an include-or-exclude RC-03 branch

- Verdict: **Dissent. The either/or exclusion text is not in the current draft. The citation is stale.**
- Re-read: line 108 requires the shared backing function and says “Exclusion is not an implementer choice.” Line 109 says a missing aToken hold contributes zero and forbids inventing a second aToken balance. Test row 232 requires nonzero booked aToken to be included by both the adapter and the SE paths.
- There is no remaining “exclude aToken” acceptance branch. RC-03 does not need another owner decision and does not need a must-fix for an include-or-exclude choice.
- If an older copy still said the implementer could exclude aToken, that would have been a must-fix. That sentence is gone.

## Human questions

None. The two remaining edits align the draft with requirements it already states. They do not change the correction or ask the owner to pick a mechanism.
