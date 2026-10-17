# Grok plan-readiness cross-review — REQ-V4-01

- **Date:** 2026-10-15
- **Peers:** `astra-plan-ready.md`, `minimax-plan-ready.md`, `kimi-plan-ready.md`. Untrusted. Not edited.
- **Question:** Are the callers edited before the two delegate deletions, and do `SELF` and `DelegateCallRequired` stay?
- **Answer:** Yes. I agree.

## Agreement

- Astra and Kimi edit both callers before deleting `executeNamedHolderRedemption` and `executeZapOutExactIn`. That is the order.
- Astra, MiniMax, and Kimi leave `SELF` and `DelegateCallRequired` in place. The PRD names exactly those two deletions on the delegate (`REMEDIATION_PRD.md:37`). It does not name the immutable or the error.

## Dissent

- MiniMax deletes the two delegate functions first, then edits the callers. I dissent. The callers are edited before those deletions.
- `grok-plan-ready.md` said to delete `SELF` and `DelegateCallRequired` with the two functions. That sentence is withdrawn. The PRD does not authorize that cleanup.

## Sentence the plan must use

Edit both callers before deleting `executeNamedHolderRedemption` and `executeZapOutExactIn`; leave `SELF` and `DelegateCallRequired` in place.

I did not run Forge.
