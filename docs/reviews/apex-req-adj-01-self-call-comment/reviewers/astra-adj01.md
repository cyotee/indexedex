# Astra — REQ-ADJ-01 replacement-session original

I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This is an independent first pass. No other reviewers' notes were read. The controlling requirement is REQ-ADJ-01 in `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:152–161` in the current file.

## Decision

**No blocking question.** Replace only the NatSpec block currently at `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:41–44` with this exact text:

```solidity
    /// @param burnFromInternalBalance When true, redeem exactly `amountSharesToRedeem` from vault-held
    ///        shares with no share refund (API-12); when false, redeem from `msg.sender`'s shares.
    ///        Redemption passes the selected holder explicitly to internal settlement; it does not
    ///        make an external self-call. For true, transfer-and-consume must be atomic; staged use
    ///        is at integrator risk. When true and `msg.sender != address(this)`, callers with no
    ///        bytecode revert `EOAPretransferNotAllowed()`. The existing `msg.sender == address(this)`
    ///        exemption from that caller check is retained; this does not assert a reachable self-call path.
```

This is the sole proposed edit. Do not change the function signature or body, add a self-call, remove the `msg.sender == address(this)` exemption, alter the source/owner selection, change custody, or expand the task to other documentation or code. No alternative wording or implementer decision is left open.

## Source evidence

**Facts directly read:**

- Target **44** currently says “The vault's own self-call path is unaffected.” That wording presents a current self-call path rather than simply describing a conditional exemption.
- Target **57–58** applies the caller guard only when `burnFromInternalBalance` is true and `msg.sender != address(this)`. The replacement preserves that exact condition and does not incorrectly reject ordinary code-less callers on the false branch.
- Target **60–63** selects the share source and explicitly chooses `address(this)` as holder for internal balance, otherwise `msg.sender`.
- Target **64–66** calls `RebasingAwareERC4626Common.executeRedeem` with that explicit owner. It does not perform an external self-call to make the vault become the caller.
- `RebasingAwareERC4626Common.sol:399–430` defines this as internal settlement, checks the selected source's balance, passes owner/shares/source to `takeShares`, and pays the receiver. The requested amount and explicit holder remain part of that settlement.

**Inference:** the old sentence can mislead future maintenance into treating self-call routing as an architectural requirement. The replacement instead documents the current explicit-holder selection and conditional caller guard.

**Unverified:** reachability of a `msg.sender == address(this)` entry into this function. No such reachability is claimed, and no global absence-of-self-calls proof is implied. The replacement's no-external-self-call statement describes this redemption implementation; the final sentence expressly avoids asserting a reachable self-call path.

## Astra finding — ADJ01-1

- **Title:** NatSpec incorrectly presents internal-balance redemption as an existing self-call path.
- **Severity:** Low.
- **File and line:** `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:41–44`, especially 44.
- **Intended behavior:** REQ-ADJ-01 requires documentation of explicit-holder redemption, with no added self-call and no deletion of the caller-check exemption.
- **Broken invariant:** The comment describes a current self-call path not established by the implementation or review evidence.
- **Impact class:** Documentation accuracy / maintenance misdirection; not a demonstrated money-path defect.
- **Fix direction:** Replace only the four-line NatSpec block with the exact text above. Preserve executable code byte-for-byte.
- **Confidence:** High on the comment/code mismatch; no assertion about global exemption reachability.

## Files examined without another scoped defect

- `RebasingAwareStandardYieldTarget.sol:45–67`: explicit holder/source selection and retained caller-check exemption; no runtime change required for this item.
- `RebasingAwareERC4626Common.sol:399–430`: internal redemption settlement consistent with explicit-holder wording; no additional scoped defect established.
- Controlling application PRD **152–161**: sufficient acceptance criteria and explicit non-goals; no missing owner decision.

Repository routing and canonical testing guidance were read directly earlier in this session. No separate implementation plan or audit report was supplied for this task; none was assumed. Supplied input paths were present; the assigned output was absent before this write.

Only this assigned Markdown report was created. No code, comments in source, tests, controlling PRD, configuration or instruction files were edited. No delegation, shell, build, deployment or tests were used. Return to the coordinator/human and stop; writing this review does not authorize the source-comment edit.

I did not run Forge.
