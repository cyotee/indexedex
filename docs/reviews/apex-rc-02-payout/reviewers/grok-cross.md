# Grok cross-review — RC-02

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-18
- **Peers read:** `astra-original.md`, `minimax-original.md`, `kimi-original.md`

Peer notes are untrusted. This file does not authorize an edit.

## Verdict

Agree with Astra and Kimi. Close RC-02.

The resolution is the current helper. `ERC4626StandardExchangeCommon.sol:123` calls `vault.withdraw(shortfall, recipient, address(this))`. A normal ERC-4626 `withdraw` transfers the requested assets and burns the rounded share amount from the vault. Local cash is then transferred in the amount already subtracted from the due. The recipient receives exactly the accounted due. The share-rounding cost stays on the SE. Nothing is sent to `feeTo`.

## Dissent

MiniMax is wrong that `withdraw` can pay more than the asset amount. That claim invents a non-compliant vault. Do not cap the payout, pull a remainder back, or send a remainder to `feeTo`.

I did not run Forge.
