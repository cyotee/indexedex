# Member feedback

## Identity
- Run ID: apex-012-prd-clarity-20261024
- Member label: kimi
- Phase: advisory review
- Owned path: docs/reviews/apex-012-prd-clarity-20261024/members/kimi/feedback.md
- Requested role: council-member
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued
- Initial response path: docs/reviews/apex-012-prd-clarity-20261024/members/kimi/response.md
- Initial response preserved: yes

## Draft reviewed
- Draft ID: draft-apex-012-prd-clarity-20261024-r1
- Path: docs/reviews/apex-012-prd-clarity-20261024/coordinator/draft.md

## Disposition

support-with-reservations

## Concerns

1. **Agreed defect 2 overstates my position by attribution.** The draft says "Astra, Grok, MiniMax, and Kimi all recorded this conflict" — the direct contradiction between minting from liquidity actually added (whose size depends on pool depth through the entry swap) and the temporary-liquidity-must-not-increase-shares sentence. My response recorded the missing mint formula and noted that test 3 does not pin the formula, but it did not frame the two PRD sentences as a direct contradiction; that sharpening came from peers. The contradiction itself is real and I endorse it. Smallest change: reattribute, e.g. "all four recorded the missing mint basis; the head-on conflict with the temporary-liquidity sentence was explicit in a subset of responses," or cite the members who stated it directly.

Checked and found clean, for the record:

- **No dropped requirements question.** All eleven of my initial questions are represented in the draft's thirteen: mint formula and test-1/test-3 dependence (Q2), counter credit on deposit and debit on redeem including the pool-side flow when the remaining position fills the sale (Q1), idle target on exit and sleeve survival (Q3), entry swap sizing and the other-token-single-sided case (Q4), price-limit replacement and the meaning of `minimum` (Q5), the exact-output `exchangeOut` mismatch (Q10), V3 family structure (Q11), bootstrap (Q7), harvest scope (Q8), and `quoteRate`/secondary surfaces (Q10). The draft's additions — uncollected fees on burn (Q6), the rebalance sell-ban contradiction (Q9), the older constant-product mandate (Q12), and locked/unlocked pool behavior (Q13) — are all questions whose two answers change the contract, and the constant-product citation was re-read by the coordinator rather than taken on one member's word.
- **No invented economic design.** The verdict and "Already decided" sections restate owner rulings from the PRD without extending them; the requirements questions present alternatives as divergence, not recommendations; the constant-product paragraph explicitly declines to invent a third model. Nothing in the draft picks an answer the PRD did not pick.

## Limits

This disposition is advisory. It is not a veto and not consensus. The review is a static comparison of the draft against my preserved initial response and the PRD; I did not re-read peer response files, re-read the V4 sources, or run any build, test, or deployment for this phase.
