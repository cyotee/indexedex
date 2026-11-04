# Clarified Pair Token PRD council report

## Result

Published one complete working PRD at handoff/PRD.md, identity pairtoken-unified-prd-r2. It supersedes pairtoken-unified-prd-r1 as the document to work from. r1 was not edited. No companion report is needed to interpret the PRD.

Published raw SHA-256: 088ba325456c1ce4a93cbe0fc9625e1119352dbb8b209455460322b11d052d8d.

The pinned draft remains coordinator/draft.md, raw SHA-256 b8e85f71b0453afafd3f733ba0019b9ae1eaf7d26bc9c3adfaffb25532ffcf96. The published file differs only by the publication header and by deletion of the undefined phrase "subject to EVM call-gas rules" from PT-BAL-05 and PT-BAL-06. That deletion is a coordinator revision after Grok's reservation. It is not a new member-approved draft.

## Participation

Coordinator: invoking session, not an additional member vote. Astra st_01a17f66, Grok st_01a17f67, MiniMax st_01a17f68, and Kimi st_01a17f69 each contributed exact prose and completed one hash-verified advisory pass. Astra, MiniMax, and Kimi supported the draft. Grok supported it with the one gas-qualifier reservation, which was adopted in the published file only.

## Content

All r1 requirement identifiers and PT-AC-01 through PT-AC-68 are retained. No new identifier was added. The seven authorized clarifications are inside the requirements they change: redemption payout before the liquidity read; amount0 sorting and amount1 absolute difference; MD unadorned revert distinct from initialization division failure; nonnegative Add including zero; catch-all notify failures; remaining-gas native payout and refund, not a 2300-gas stipend; view static calls for the consumed single-slot extsload read and the token balanceOf idle read.

## Limits

This publication does not implement PairToken, prove runtime equivalence, or certify legal clearance. No project tests or builds were run. Give a planner only handoff/PRD.md.
