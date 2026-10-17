# Grok — REQ-ADJ-01 documentation check

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-17
- **Controlling text:** REQ-ADJ-01 in `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md`

No blocking question.

## Finding

- **Title:** The redeem comment still teaches a vault self-call.
- **Severity:** Low.
- **File and line:** `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:41-44`. The exemption at lines 57–58 stays.
- **Intended behavior:** The comment describes explicit-holder redemption. A true flag burns vault-held shares. A false flag burns the caller's shares. This function does not call `address(this)`.
- **Broken requirement:** Line 44 says the vault's own self-call path is unaffected. No self-call into `redeem` is in this function.
- **Impact class:** Documentation. A later edit could add a self-call or delete the exemption to match the sentence.
- **Fix direction:** Replace lines 41–44 with the NatSpec below. Do not add a self-call. Do not delete the `msg.sender == address(this)` exemption. Do not redesign custody.
- **Confidence:** High. The holder choice is at lines 60–63. `takeShares` burns that holder and does not refund the remainder.

## Exact replacement

```solidity
    /// @param burnFromInternalBalance When true, the explicit holder is the vault: burn exactly
    ///        `amountSharesToRedeem` of its shares and refund nothing (API-12). When false, the explicit
    ///        holder is `msg.sender`. A true flag from any other caller must transfer and consume in the
    ///        same call; a caller with no bytecode reverts `EOAPretransferNotAllowed()`.
```

Reachability of the exemption is not established. That is not a question for this comment.

I did not run Forge.
