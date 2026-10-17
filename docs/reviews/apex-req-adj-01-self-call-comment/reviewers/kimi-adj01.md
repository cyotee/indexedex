# Kimi K3 — REQ-ADJ-01 self-call comment: exact replacement (replacement-session original)

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read. Nothing was edited. I did not run Forge.
- **Controlling text:** `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` REQ-ADJ-01 (`:152-161`, re-read this round). Target read this round: `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:41-67`.

## Answer: No blocking question.

The PRD's acceptance criteria and the current code determine the replacement fully. Verified facts:

- The executable (`:57-66`) already chooses an explicit holder: `owner = burnFromInternalBalance ? address(this) : msg.sender` (`:63`), and the caller check is gated by `burnFromInternalBalance && msg.sender != address(this)` (`:57-58`). There is no `this.redeem(...)` or equivalent self-call anywhere in the function; the PRD's premise ("No production self-call into this function was established") matches the code I read.
- The offending sentence is the last one at `:44`: "The vault's own self-call path is unaffected." It teaches a path that does not exist and invites a later agent to preserve or add one.
- The exemption at `:57-58` is code, preserved by the PRD's non-goal ("Do not delete the `msg.sender == address(this)` exemption"); the comment may describe it but must not assert a live self-call route ("Reachability of that exemption was not established").
- The "refunds nothing (API-12)" clause is the internal-balance burn surface, not a pretransfer input surface — outside REQ-SEP-04's closed list (deliberately excluded there) and unchanged by this item.

## The exact replacement NatSpec for lines 41-44

```solidity
    /// @param burnFromInternalBalance Integrating-contract flag only when true and `msg.sender != address(this)`.
    ///        Transfer-and-consume must be atomic; staged use is at integrator risk. Callers with no bytecode
    ///        revert `EOAPretransferNotAllowed()`. When true, redemption burns exactly `amountSharesToRedeem`
    ///        with the vault (`address(this)`) named explicitly as the holder, and refunds nothing (API-12).
    ///        When false, the holder is the caller. The `msg.sender == address(this)` exemption skips the
    ///        caller check; no current self-call route into this function is claimed.
```

Why this shape is closed:

1. The first two lines (flag condition, atomicity, EOA rejection) are accurate today and are kept verbatim — they describe `:57-58` exactly.
2. "the vault (`address(this)`) named explicitly as the holder" describes `:63` — explicit-holder redemption, the required teaching.
3. The exemption sentence documents the code's branch condition while stating that no self-call route is claimed — satisfying both the acceptance criterion and the reachability non-goal without deleting or affirming anything.
4. No code line changes; the function, the exemption, and custody semantics are untouched. No self-call is added to make an old sentence true (acceptance criterion 2).

## Guards

- Comment-only edit at `:41-44`. No production logic, no test change in this item.
- If the cited lines no longer match the text quoted above at implementation time, stop and report; do not substitute.
- The withdrawn V4 twin and every other file stay untouched.

I did not run Forge.
