# Identity

- Run ID: apex-012-deposit-process-20261024
- Member label: minimax
- Review role: council-member
- Draft under review: draft-apex-012-deposit-process-20261024-r1

# Draft reviewed

- Path: `docs/reviews/apex-012-deposit-process-20261024/coordinator/draft.md`
- I compared the draft against my owned initial response. I did not read or modify peer response files, the draft, or my initial `response.md`.

# Disposition

support-with-reservations

# Concerns

1. **The draft does not materially misstate my conclusion.** It correctly attributes the prior review's entry-sale assumption to the PRD Entry sentence, correctly states that the existing V4 deposit does not execute an opposing-token sale, and correctly summarizes my position that a positive target-only mint into a position already holding other token necessarily gives the new holder a slice of that pre-existing other token. It also correctly leaves the owner decision open rather than selecting one.

2. **The MiniMax summary is too compressed and could be read as rejecting every target-only deposit.** My conclusion was narrower: under the owner's no-sale correction, a target-only proportional deposit remains valid when the pre-deposit position contains no other token; when the position already contains other token, the target-only deposit must revert unless the owner separately approves a conversion or reconciles the PRD Entry and no-gift rules. The draft should state that scope directly.

3. **The draft should distinguish the gift conflict from two additional reasons that quote removal alone does not fix.** In my response, the unchanged sequence also lacks a valid replacement for `Accounting.issue`'s `value` input, and it mints before `_place`, so it cannot directly mint from the liquidity actually added against the pre-add position. These points support the same conclusion but should not be omitted from the final synthesis if the final report is intended to preserve the basis of the member findings.

4. **The wording about owner rejection should remain precise.** The correction invalidates the counterfactual premise that the existing deposit sells target for other token and supplies no approval for an entry conversion. Describing this as the owner having rejected the entry swap is defensible only if that is the intended scope of the correction; otherwise, the clearer formulation is that the draft records the correction and leaves any future conversion for owner approval. This is a wording concern, not a request to select an owner option.

# Limits

- Advisory review only; no code, draft, or peer file was changed.
- Static comparison of draft r1 against my initial response; no Forge run.
- This feedback does not choose among the draft's owner decisions and does not reopen the underlying implementation review.
