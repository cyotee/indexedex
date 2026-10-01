# Grok final clarity review — draft remediation PRD

- Reviewer: Grok (xai/grok-4.7)
- Date: 2026-09-25
- Draft read: `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md` (256 lines)
- No source was edited. No peer review file was read.
- Human questions that would change the correction or the acceptance test: none.
- The draft is executable without a new product-law ruling after the two consistency fixes below. Those fixes align a test row and one sentence with requirements the draft already states. They do not ask the owner to pick a new rule.

## Verdict

Consistent with the owner ruling that already-deployed instances are out of scope. Lines 55, 194–196, 218, 222, and 244 do not reopen migration, registry disablement, historical fork replay, or live inventory. Preserved Uniswap trees stay non-deploy source (lines 55, 67, 130, 170, 194).

RC-01’s revert clause, RC-03’s aToken inclusion, and RC-08’s unreachable-branch record are now closed in the draft. No new ruling is required for them.

## Must fix before handoff

### 1. RC-02 test row rejects an acceptance path the same draft allows

- Classification: must fix before handoff
- Draft lines: acceptance `94`; test row `231`
- Contradiction: Line 94 allows either “rounding remainder stays booked on the SE” or “an exact-asset withdrawal whose share charge matches the preview.” Line 231 requires “Any redemption remainder stays booked on the SE.” An exact-asset `withdraw` of the shortfall, which R14.15 and the Stata peer already use, creates no redemption remainder. That implementation would fail the test row while meeting line 94 and paying the recipient exactly the due amount (lines 93 and 95).
- What to change: Rewrite line 231 so the required assertion is the recipient delta equals the accounted due amount, the returned exact-in amount equals that delta, and any remainder that the chosen method does create stays booked on the SE and is not paid to the recipient or to `feeTo`. Exact-asset withdrawal with no remainder passes. Do not add a requirement that a remainder must exist.
- Not a human question: Line 94 already authorizes both mechanisms. The test row is narrower than the requirement. Align the row. Do not ask the owner to ban `withdraw`.

### 2. RC-05 forbids the helper-sharing fix that the same item allows

- Classification: must fix before handoff
- Draft lines: `140`, `142`, `143`, test row `234`
- Contradiction: Line 140 and line 234 allow deleting the unused `exchangeOut` or routing it through the installed guarded helper. Line 142 says the source “must not retain a second public money implementation.” Sharing the helper retains a second `exchangeOut` that is no longer the unguarded refund. An implementer who follows line 140 can fail line 142.
- What to change: Change line 142 so the banned residue is a second public `exchangeOut` that still refunds `maxAmountIn - amountIn` without the credit cap and caller check. A guarded shared helper remains allowed. Installed selectors still do not change (line 141).
- Not a human question: The authorized choice is already in lines 140 and 234.

## Wording cleanup that does not change the requirement

### 3. General red/green rule versus RC-05 and RC-08

- Classification: wording cleanup
- Draft lines: `59` versus `140–142`, `183–184`, `234`, `237`
- Line 59 says every money or control defect has a production-route test that fails on current behavior. RC-05’s proof is source absence plus an unchanged surface suite, because the unsafe function is not on the cut. RC-08’s unreachable-branch record is already the exception at lines 183–184 and 237. Add one clause to line 59 pointing at those two exceptions so the general sentence is not read as cancelling them.

### 4. RC-04 lists the Balancer approve comment; the RC-04 assertion does not

- Classification: wording cleanup
- Draft lines: `123`, `127`, `233`; the correction itself is at `79`
- Line 123 adds `BalancerV3SinglePoolStandardExchange.sol:262` to the comment list. Line 79 already requires that comment to be updated with the allowance change. Line 233’s record list does not mention it. Either add “infinite approve” to the line 233 record, or leave the comment only under RC-01. The executable allowance rule does not change.

### 5. RC-01 “amount that route will spend”

- Classification: wording cleanup
- Draft lines: `79`, `81`
- For true-flag exact-out, the authorized cap is the D15 credit budget, which may exceed the amount the router later pulls. Line 81 already refunds only unused authorized credit. A parenthetical on line 79 — quoted used on a false-flag pull, credit budget on true-flag exact-out, never `type(uint256).max` — would stop an implementer from approving only the post-hoc used amount. D15 already requires that cap. No new ruling.

## No issue

| Topic | Draft lines | Why it does not block |
| --- | --- | --- |
| Already-deployed instances | `55`, `194–196`, `218`, `222`, `244` | Out of scope. No chain read or migration task remains. |
| Preserved Uniswap trees | `55`, `67`, `130`, `170`, `194` | Not a new-deploy source and not an edit target. |
| RC-01 revert cleanup | `79` | Transaction rollback. `try`/`catch` is forbidden. Matches D30 / D34. |
| RC-03 aToken | `108–110`, `232` | Inclusion is required. Exclusion is not a choice. Absent aToken contributes zero. Reward forwarding stays out (`112`, `209`). |
| RC-04 README range | `122` | Stale pull-max and exact-in equality text is inside README lines 32–38. |
| RC-06 return | `153–155`, `236` | Truthful return or removal. Both pass. |
| RC-07 deficit | `166–169`, `236` | Zero credit, then the family’s existing insufficient-credit error if the request is above zero. No new error. Preserved trees are not edited. |
| RC-08 evidence fallback | `183–184`, `237`, `252` | Production route if reachable. Otherwise record the attempt and assert the production check. Not an owner decision. |
| F-M3-01, Grok-5, dust-to-`feeTo`, D12, withdrawn `beforeSwap`, weighted-dust High | `61–67`, `201–210` | Closed. Not new work. |

## Questions for the human

None.
