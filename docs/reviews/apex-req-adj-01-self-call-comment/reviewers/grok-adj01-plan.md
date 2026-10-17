# Grok plan draft — REQ-ADJ-01

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-17
- **Controlling text:** `docs/reviews/apex-req-adj-01-self-call-comment/REMEDIATION_PRD.md`

This draft does not authorize an edit. No implementer choice.

## Stop first

Stop and report if `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol` lines 41–44 are not:

```solidity
    /// @param burnFromInternalBalance Integrating-contract flag only when true and `msg.sender != address(this)`.
    ///        Transfer-and-consume must be atomic; staged use is at integrator risk. Callers with no bytecode
    ///        revert `EOAPretransferNotAllowed()`. Burns exactly `amountSharesToRedeem` from vault-held shares
    ///        and refunds nothing (API-12). The vault's own self-call path is unaffected.
```

Stop and report if lines 57–63 are not:

```solidity
        if (burnFromInternalBalance && msg.sender != address(this)) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
        }
        RebasingAwareERC4626Common.ShareSource source = burnFromInternalBalance
            ? RebasingAwareERC4626Common.ShareSource.PublicBalanceExactBurn
            : RebasingAwareERC4626Common.ShareSource.CallerOrApprovedOwner;
        address owner = burnFromInternalBalance ? address(this) : msg.sender;
```

Do not choose another sentence.

## The only edit

Replace lines 41–44 with exactly:

```solidity
    /// @param burnFromInternalBalance When true, the explicit holder is the vault and redemption burns
    ///        exactly `amountSharesToRedeem` of its shares and refunds nothing (API-12). When false, the
    ///        explicit holder is `msg.sender`. This function does not call `address(this)`. Transfer-and-consume
    ///        must be atomic; staged use is at integrator risk. When true and `msg.sender != address(this)`,
    ///        a caller with no bytecode reverts `EOAPretransferNotAllowed()`. This comment does not claim
    ///        that the `msg.sender == address(this)` exemption is reachable.
```

Do not change the function signature or body. Do not add a self-call. Do not delete the exemption at lines 57–58. Do not edit any other file. Do not add or change a test. Do not run Forge.

I did not run Forge.
