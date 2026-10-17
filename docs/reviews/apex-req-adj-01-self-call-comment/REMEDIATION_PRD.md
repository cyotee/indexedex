# Remediation PRD — REQ-ADJ-01 self-call comment

- **Status:** DRAFT
- **Date:** 2026-10-17
- **ID:** REQ-ADJ-01
- **Review target:** `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:41-44`
- **Inputs:** REQ-ADJ-01 in `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md`. No separate implementation plan or audit report was supplied.
- **Astra participation:** Substantive first pass and cross-review. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored.
- **Grok:** `ses_ec4128917ffeeVds3Y2p7xrVjp`.
- **MiniMax M3:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. It does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Kimi K3:** Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **Runtime:** No Forge run. Source was read. Consensus is not proof.

Writing this PRD does not authorize implementation.

## Required outcome

The redeem comment describes an explicit holder and does not teach a vault self-call. The function body does not change.

## REQ-ADJ-01-1 — Replace the self-call sentence

- **Severity:** Low
- **File and line:** `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:41-44`. The exemption at `:57-58` stays.
- **Intended behavior:** Comments must not tell a later agent that internal-balance redemption is a vault self-call. The function already names the holder and does not call `address(this)`.
- **Broken requirement or invariant:** Line 44 says the vault's own self-call path is unaffected. No production self-call into this function was established.
- **Acceptance criteria:**
  - Replace lines 41–44 with exactly:

```solidity
    /// @param burnFromInternalBalance When true, the explicit holder is the vault and redemption burns
    ///        exactly `amountSharesToRedeem` of its shares and refunds nothing (API-12). When false, the
    ///        explicit holder is `msg.sender`. This function does not call `address(this)`. Transfer-and-consume
    ///        must be atomic; staged use is at integrator risk. When true and `msg.sender != address(this)`,
    ///        a caller with no bytecode reverts `EOAPretransferNotAllowed()`. This comment does not claim
    ///        that the `msg.sender == address(this)` exemption is reachable.
```

  - Do not change the function signature or body.
  - Do not add a self-call. Do not delete the exemption at lines 57–58.
  - Do not edit any other file. Do not add or change a test.
  - If lines 41–44 or 57–63 no longer match the text read for this PRD, stop and report. Do not choose another sentence.
- **Non-goals:** Do not redesign custody. Do not describe an allowance spend. Do not claim the exemption is reachable. Do not claim it is unreachable.

## Dissent

The four drafts agreed on the facts and differed in wording. MiniMax's allowance clause is rejected because this function body does not show an allowance spend. Kimi's first opening, which said the flag applies only when `msg.sender != address(this)`, is rejected because the flag can be true when the caller is the vault. Astra's longer block is equivalent in substance. This PRD selects the block above so the implementer has one text.

## Unverified

No production caller of this function with `msg.sender == address(this)` was established. That is why the exemption stays and the comment does not claim it is reachable.
