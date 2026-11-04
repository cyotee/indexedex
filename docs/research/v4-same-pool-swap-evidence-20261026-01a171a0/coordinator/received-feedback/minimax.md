# Coordinator receipt of MiniMax advisory feedback

Native task st_01a1773e, epoch 1. Inline delivery because project-scoped apply_patch was unavailable. This is the complete member-authored feedback, not a rewrite. It does not replace the initial response.

---

Ask: Advisory review of draft `draft-v4-same-pool-swap-evidence-20261026-01a171a0-r1` only - wanted: one evidence-focused disposition.  
For you: Support; the draft accurately represents the MiniMax evidence, preserves the relevant disagreement and limits, does not present unchecked peer numbers as rechecked, and does not convert research into implementation authority.  
Now: No task remains.  
Next: None.

## Identity

- Reviewer: MiniMax member, continuing initial task `st_01a1773e`.
- Review type: advisory review only.
- This feedback does **not replace my initial response**.
- No peer originals or peer feedback were read.

## Draft under review

- Draft ID: `draft-v4-same-pool-swap-evidence-20261026-01a171a0-r1`
- Path: `docs/research/v4-same-pool-swap-evidence-20261026-01a171a0/coordinator/draft.md`
- Exact size reviewed: `19,452` bytes
- SHA-256 before review: `54172c64b0cefb36c78d9c677062f14e833f42acfc0d365064a28ca4e480898f`
- SHA-256 after review: `54172c64b0cefb36c78d9c677062f14e833f42acfc0d365064a28ca4e480898f`
- Hash matched the assignment before and after review.

## Disposition

**support**

## Concerns

| Draft location | Requested change |
|---|---|
| none | No material concern found. |

The draft accurately states that:

- My witness is an **idle-inventory, external-only constant-product model**, not an active core-and-wings execution.
- Its default-spacing path would activate a wing, and exact Wings reachability remains unverified.
- Flash-loan availability remains unverified.
- The witness and matched controls close the loan and opposing inventory rather than marking residual opposing at a convenient price.
- Fixed 49%/50%/51% sizing is not a safety boundary.
- Post-swap-composition denominator corrections remain positive in the checked headline model.
- A corrected anchored TWAP is not an independent price and does not reconstruct uncovered history.
- The current source-level `getRate` is the whole-book quote over supply, while the requested one-share semantics remain a separate proposed distinction.
- The findings are research conclusions, not implementation, test, configuration, deployment, or Git authority.

A standalone arithmetic check of only the MiniMax figures adopted by the draft reproduced:

- headline profit: `5162744.897861870006`;
- no-manipulation control: `-143477.293833896721`;
- manipulation-without-deposit control: `-452033.470528949460`;
- 50% entry: `5053409.393024628982`;
- 51% entry: `4943655.362700939178`;
- 1% entry: `10143708.375864716247`;
- post-swap variants: `3930748.715170613956`, `3370122.044926437549`, and `3930748.715170613956`;

with zero final opposing inventory and zero final shares in each checked case.

## What was not adopted from others

- I did not independently adopt Grok’s unrechecked Domain N figures or fee-grid rows.
- I did not independently adopt Kimi’s unrechecked W4/W5, TWAP-replica, or broader-grid numbers.
- I did not adopt Kimi’s characterization of the current `getRate` as a one-share preview; the draft correctly rejects that characterization.
- I did not independently endorse the coordinator’s non-MiniMax arithmetic as my own recheck.
- I did not read peer originals or peer feedback to reach this disposition.

## Limits

- Review was limited to the exact hash-pinned draft.
- This was not a fresh research pass and did not re-open the original question.
- No project tests, builds, Git operations, deployments, wallets, or credentials were used.
- Project-scoped `apply_patch` was unavailable, so no `members/minimax/feedback.md` was written. This is the complete inline advisory receipt for coordinator filing at `coordinator/received-feedback/minimax.md`.
