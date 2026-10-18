# Grok — RC-02 payout

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-18
- **Controlling text:** RC-02 in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`

The September claim is refuted. `_payUnderlyingLocalFirst` does not redeem `previewWithdraw(shortfall)`.

`ERC4626StandardExchangeCommon.sol:116-127` pays booked local cash first. The shortfall is `vault.withdraw(shortfall, recipient, address(this))`. A normal ERC-4626 `withdraw` sends that asset amount. Local cash is then transferred in the same amount already subtracted from the due. The recipient receives exactly the accounted due. Nothing is sent to `feeTo`.

Callers pass that accounted amount and do not add a second payout:

- `ERC4626StandardExchangeInTarget.sol:97-102` pays and returns the preview.
- `ERC4626StandardExchangeOutTarget.sol:109-114` pays the requested exact-out amount.
- `ERC4626StandardYieldTarget.sol:23-26` pays the same preview.

The old orbital line range is no longer a payout check. No production gap remains. The rule is visible in the helper, so no missing test is named.

Close RC-02

I did not run Forge.
