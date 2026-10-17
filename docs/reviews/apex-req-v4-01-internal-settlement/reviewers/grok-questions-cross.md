# Grok questions cross-review — REQ-V4-01

- **Date:** 2026-10-15
- **Peers:** `astra-questions.md`, `minimax-questions.md`, `kimi-questions.md`. Untrusted. Not edited.
- **Points:** Must `executeNamedHolderRedemption` be deleted in this item? Must REQ-V4-02's disable check be included in this item?
- **Answer:** Ready. Both are closed. No owner question.

## Agreement

- Astra is right that the wrapper must not remain the yield route, and that its delegate infrastructure is not deleted merely because the hop is removed.
- Astra is right that the disable check stays a separate obligation. It is not part of choosing the settlement call.
- MiniMax is right that the V4-01 edit is the body of `_settleNamedHolder`. MiniMax does not put deletion or the disable check in that edit.

## Dissent

- Kimi is wrong that this item deletes `executeNamedHolderRedemption`. The recorded sentence is "does not keep a holder-taking wrapper on the execution delegate as the yield path" (`docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:77`). That closes the yield path. It does not order deletion. The RC-01 ban on letting a caller name a holder applies to adding a holder argument to the four-argument `executeZapOutExactIn` wrapper. It is not an order to delete the existing named-holder function in this item.
- Kimi is wrong that this item adds `_requireNotDisabled`. REQ-V4-02 is a separate numbered item. Its acceptance is at lines 88-92 of that same PRD. REQ-V4-01's acceptance does not include it. Merging the check into this item is not selected by the recorded text.

## Closed sentence

This item stops the yield path from calling `executeNamedHolderRedemption` and does not delete that function; REQ-V4-02's disable check is not added here.

I did not run Forge.
