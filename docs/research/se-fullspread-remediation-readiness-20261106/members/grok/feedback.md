# Advisory feedback

## Identity

- Member: grok
- Phase: advisory review
- Role: council-member
- Requested model: xai/grok-4.7:xhigh
- Runtime identity: not exposed
- Task ID: not exposed

## Draft under review

- Draft ID: draft-se-fullspread-remediation-readiness-20261106-r1
- Path: `docs/research/se-fullspread-remediation-readiness-20261106/coordinator/draft.md`
- Coordinator-supplied SHA-256: `7de78ac3f367b07c4e005441f6fb9fe66ad7801f27a61c861718388eb45973f6`
- Independent fingerprint: not computed

## Disposition

requested-changes

The verdict `not ready` is supported. Verdict and The open choice state the wanted-token `donate` or `compound` split as this response stated it. The requested change is in Closed by the current text. This feedback does not authorize implementation and does not replace the draft.

## Accuracy

The draft states this member's open choice accurately. Peer responses were not read. The other participation rows are not confirmed and are not disputed.

## Concerns

### Closed by the current text

The collapsed bullet says a collapsed candidate returns the input and keeps no swap, then says a first deposit that does not add more than 1,000 liquidity still reverts `MinLiquidityNotMet` and that is not a refund.

The lock's Collapsed candidate paragraph does say return the input and keep no swap. It then splits the disposition. A share mint refunds that input and mints nothing. A donate or compound books that input and does not refund it. The first-deposit sentence is the exception to the share-mint refund, not the only exception to a return.

Two readers of this bullet can diverge. One copies "returns the input" as a refund for every collapsed route except the first deposit. That refunds a collapsed `donate` or `compound`. The other keeps the lock's next sentences and books that input. The draft calls this path closed. The shortened bullet is not one copyable disposition.

Requested change: restate the lock's collapsed route split in that bullet. A later share mint refunds and mints nothing. A donate or compound books that input and does not refund it. The first-deposit floor still reverts and is not a refund. Do not leave "returns the input" as the disposition. This is advice, not an edit. It does not ask the owner to choose.

## Limits

- No FILL.
- This feedback is not a verdict that the code is ready to implement.
- It does not choose whether wanted-token maintenance dust is refunded or booked.
- The coordinator-supplied fingerprint was not recomputed.
- No tests, installs, Git, or sub-agents were run.
