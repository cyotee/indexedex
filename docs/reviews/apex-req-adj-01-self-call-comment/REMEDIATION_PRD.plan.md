# Implementation plan — REQ-ADJ-01 self-call comment

- **Date:** 2026-10-17
- **Status:** Source step executed. The prescribed execution report is missing. Confirmation: `docs/reviews/apex-req-adj-01-execution-confirmation/REMEDIATION_PRD.md`. Writing this plan did not authorize implementation.
- **Controlling PRD:** [REMEDIATION_PRD.md](./REMEDIATION_PRD.md). Where this plan conflicts with that PRD, the PRD controls.
- **ID:** REQ-ADJ-01.
- **Council:** Astra replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi` does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`. MiniMax replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t` does not recall `ses_ebdf718feffemWQNf7wuTpapqX`. Kimi replacement `ses_ec3d04e91ffeJa0is24e2jZv06` does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. Astra was not censored. Kimi's build step was retracted. No Forge run. Consensus is not proof.

## What to do

Replace one NatSpec block. Do not change executable code.

## What not to do

- Do not offer another sentence.
- Do not change the function signature or body.
- Do not add a self-call. Do not delete the `msg.sender == address(this)` exemption.
- Do not describe an allowance spend. Do not claim the exemption is reachable or unreachable.
- Do not edit any other file. Do not add or change a test.
- Do not run Forge, a build, or a test. This comment does not change bytecode.
- Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`.
- Do not run `scripts/sync-crane-skills.sh` or `scripts/submodule-commit.sh`. This file is not a Crane submodule path.

## Step 1 — anchors

File: `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol`.

Stop and report if lines 41–44 are not:

```solidity
    /// @param burnFromInternalBalance Integrating-contract flag only when true and `msg.sender != address(this)`.
    ///        Transfer-and-consume must be atomic; staged use is at integrator risk. Callers with no bytecode
    ///        revert `EOAPretransferNotAllowed()`. Burns exactly `amountSharesToRedeem` from vault-held shares
    ///        and refunds nothing (API-12). The vault's own self-call path is unaffected.
```

Stop and report if lines 57–63 are not the caller check, the source selection, and `address owner = burnFromInternalBalance ? address(this) : msg.sender;`.

Do not choose another site.

## Step 2 — replacement

Replace lines 41–44 with exactly:

```solidity
    /// @param burnFromInternalBalance When true, the explicit holder is the vault and redemption burns
    ///        exactly `amountSharesToRedeem` of its shares and refunds nothing (API-12). When false, the
    ///        explicit holder is `msg.sender`. This function does not call `address(this)`. Transfer-and-consume
    ///        must be atomic; staged use is at integrator risk. When true and `msg.sender != address(this)`,
    ///        a caller with no bytecode reverts `EOAPretransferNotAllowed()`. This comment does not claim
    ///        that the `msg.sender == address(this)` exemption is reachable.
```

The following lines move down by two. That shift is expected. The function body must remain byte-for-byte the same.

## Step 3 — check

The diff must show one changed region in this one file, and that region must be only the comment. If any other line changes, stop and report. Do not repair it in this item.

There is no Forge command.

Record the diff in `EXECUTION_REPORT.md`. A saved note is not an independent reviewer rerun.

## Done when

- Lines 41–46 are the replacement comment above.
- The function signature and body are unchanged.
- The exemption remains.
- No other file and no test changed.
- No Forge command was run for this item.
