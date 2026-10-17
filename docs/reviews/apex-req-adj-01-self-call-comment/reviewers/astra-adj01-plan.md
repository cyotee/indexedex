# Astra — REQ-ADJ-01 implementation draft

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Controlling text: `docs/reviews/apex-req-adj-01-self-call-comment/REMEDIATION_PRD.md`, read in full. No other reviewers' notes were read for this draft. This document does not authorize implementation.

## Scope and current precondition

**No blocking question.** One comment replacement in one source file:

`contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol`

Directly re-read lines **41–67**. The current comment at **41–44** and executable anchors at **57–63** match the pre-edit text identified by the PRD. No drift was observed. The exact PRD-selected text below controls; do not substitute my earlier longer recommendation or any alternative sentence.

## Step 1 — verify exact anchors before editing

In a later authorized implementation session, preserve a pre-edit copy for comparison and verify the existing comment is exactly:

```solidity
    /// @param burnFromInternalBalance Integrating-contract flag only when true and `msg.sender != address(this)`.
    ///        Transfer-and-consume must be atomic; staged use is at integrator risk. Callers with no bytecode
    ///        revert `EOAPretransferNotAllowed()`. Burns exactly `amountSharesToRedeem` from vault-held shares
    ///        and refunds nothing (API-12). The vault's own self-call path is unaffected.
```

Verify pre-edit lines 57–63 are exactly:

```solidity
        if (burnFromInternalBalance && msg.sender != address(this)) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
        }
        RebasingAwareERC4626Common.ShareSource source = burnFromInternalBalance
            ? RebasingAwareERC4626Common.ShareSource.PublicBalanceExactBurn
            : RebasingAwareERC4626Common.ShareSource.CallerOrApprovedOwner;
        address owner = burnFromInternalBalance ? address(this) : msg.sender;
```

If either range differs, **stop and report the drift**. Do not relocate the edit, select a different sentence, or overwrite intervening work. Preserve unrelated pre-existing changes.

## Step 2 — apply the exact replacement

Replace only the four comment lines with the following six lines, verbatim from the controlling PRD:

```solidity
    /// @param burnFromInternalBalance When true, the explicit holder is the vault and redemption burns
    ///        exactly `amountSharesToRedeem` of its shares and refunds nothing (API-12). When false, the
    ///        explicit holder is `msg.sender`. This function does not call `address(this)`. Transfer-and-consume
    ///        must be atomic; staged use is at integrator risk. When true and `msg.sender != address(this)`,
    ///        a caller with no bytecode reverts `EOAPretransferNotAllowed()`. This comment does not claim
    ///        that the `msg.sender == address(this)` exemption is reachable.
```

Do not change any other content. In particular, keep the function signature, caller guard and exemption, source/owner selection, and internal settlement call unchanged. Do not add a self-call, describe an allowance spend, redesign custody, or assert that the exemption is reachable or unreachable. Do not edit another source file, import, test or configuration. Do not add a test.

## Step 3 — static acceptance only

Compare the target against its pre-edit copy. The incremental change must consist solely of the four old NatSpec lines replaced with the six exact lines above. All content before and after that block must remain identical; line-number shifts of two are expected, not executable-code changes. Do not run a formatter that rewrites other lines.

Confirm the new block matches the PRD literally, the old self-call-path sentence is removed, and the existing exemption and explicit-holder code remain intact. Confirm no other file was changed for this item. If verification reveals any additional change, stop and report rather than expanding the scope.

**Do not run Forge, builds, tests or deployments for this task.** No runtime outcome is claimed. Static comparison verifies the authorized comment edit, not the reachability of the exemption.

## Completion criteria

- Both pre-edit anchor ranges matched before the edit, or execution stopped and reported drift.
- For a completed edit, only the exact NatSpec replacement was applied; signature/body and all other source content remain unchanged.
- No tests or other files were added or changed for the implementation.
- No Forge run or claim of runtime validation.

## Evidence and report boundary

Files examined: the controlling PRD in full and the target's lines 41–67. No implementation plan or audit report was supplied in addition to that PRD. Both input paths exist; the assigned output was absent before this write. No additional scoped source defect was established: the executable holder-selection and caller-check logic need no change for this documentation item.

Only this assigned Markdown draft was created. No source comment, executable code, test, PRD, final plan, configuration or instruction file was edited. No peer artifact, delegation, shell, build, test or deployment was used during this draft. Return to the coordinator/human and stop.

I did not run Forge.
