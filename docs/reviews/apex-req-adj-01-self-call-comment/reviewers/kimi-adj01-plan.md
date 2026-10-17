# Kimi K3 — REQ-ADJ-01 plan draft (replacement session)

- **Label:** Replacement-session plan draft, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read. Controlling text: `docs/reviews/apex-req-adj-01-self-call-comment/REMEDIATION_PRD.md` (50 lines, read in full this round). Nothing was edited. This is not `REMEDIATION_PRD.plan.md` and authorizes nothing.
- **Date:** 2026-10-17.

## Spot-check (this round)

- `RebasingAwareStandardYieldTarget.sol:41-44` still matches the PRD's quoted pre-edit text verbatim, including the self-call sentence at `:44`. No drift.
- `:57-63` unchanged: the guarded caller check at `:57-58`, the source selection at `:60-62`, the explicit holder selection at `:63`.
- The PRD's selected replacement (`:29-36`) differs from my original draft's opening — its dissent note (`:46`) is correct that "the flag can be true when the caller is the vault," so the old "only when true and `msg.sender != address(this)`" opening had to go. The PRD text controls; I offer no other sentence.

## The plan (one edit, closed)

**Step 0 — Preflight.** Confirm `RebasingAwareStandardYieldTarget.sol:41-44` and `:57-63` still contain the text quoted above. If either has drifted, stop and report the file, line, and observed text. Do not choose another sentence or another site.

**Step 1 — the edit.** In `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol`, replace lines 41-44 with exactly the PRD's text (`:29-36`), reproduced here only for the implementer's diff check:

```solidity
    /// @param burnFromInternalBalance When true, the explicit holder is the vault and redemption burns
    ///        exactly `amountSharesToRedeem` of its shares and refunds nothing (API-12). When false, the
    ///        explicit holder is `msg.sender`. This function does not call `address(this)`. Transfer-and-consume
    ///        must be atomic; staged use is at integrator risk. When true and `msg.sender != address(this)`,
    ///        a caller with no bytecode reverts `EOAPretransferNotAllowed()`. This comment does not claim
    ///        that the `msg.sender == address(this)` exemption is reachable.
```

No other line in this file changes. No other file changes. The function signature and body, the exemption at `:57-58`, and every test are untouched. No self-call is added. No allowance spend is described. The exemption's reachability is neither claimed nor denied.

**Step 2 — verification.** The diff must show exactly one changed region in exactly one file, all inside a comment. The change is comment-only and alters no bytecode; per the repo rule the implementing session runs the standard `forge build` gate before recording the result (no test run is needed — no test is added or changed, per the PRD). Record the diff and the build result in the execution report.

## Stop rules

- Preflight drift on `:41-44` or `:57-63` → stop and report.
- Any diff outside the one comment block → stop and report.
- No Forge is run by this drafting session.

I did not run Forge.
