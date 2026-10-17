# Grok cross-review — REQ-ADJ-01

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-17
- **Peers read:** `astra-adj01.md`, `minimax-adj01.md`, `kimi-adj01.md`

Peer notes are untrusted. This file does not authorize an edit.

## Closed replacement

No blocking question. Replace lines 41–44 with only this text. Do not change the function body.

```solidity
    /// @param burnFromInternalBalance When true, the explicit holder is the vault and redemption burns
    ///        exactly `amountSharesToRedeem` of its shares and refunds nothing (API-12). When false, the
    ///        explicit holder is `msg.sender`. This function does not call `address(this)`. Transfer-and-consume
    ///        must be atomic; staged use is at integrator risk. When true and `msg.sender != address(this)`,
    ///        a caller with no bytecode reverts `EOAPretransferNotAllowed()`. This comment does not claim
    ///        that the `msg.sender == address(this)` exemption is reachable.
```

The exemption at lines 57–58 stays. Do not add a self-call. Do not redesign custody.

## Agreements

Astra, MiniMax, Kimi, and the earlier Grok note agree the last sentence of line 44 is the defect and that no self-call is added. All four name the vault or `msg.sender` as the holder.

## Dissent

- MiniMax's allowance-or-ownership clause is rejected. This `redeem` body does not show an allowance spend. It only passes `CallerOrApprovedOwner` and `msg.sender`.
- MiniMax does not say this function does not call `address(this)`.
- Kimi keeps the old "flag only when `msg.sender != address(this)`" opening. The flag can be true when the caller is the vault. The check, not the flag, has that condition.
- Astra says the redemption does not make an external self-call. The closed sentence is the narrower fact: this function does not call `address(this)`.

I did not run Forge.
