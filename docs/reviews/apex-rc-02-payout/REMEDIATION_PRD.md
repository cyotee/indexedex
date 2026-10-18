# Remediation PRD — RC-02 local-first payout

- **Status:** CLOSED
- **Date:** 2026-10-18
- **Review target:** Whether `_payUnderlyingLocalFirst` still pays more than the accounted amount.
- **Inputs:** RC-02 in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`. Current `ERC4626StandardExchangeCommon.sol`, its three callers, and OpenZeppelin `ERC4626.sol` `withdraw` semantics.
- **Astra participation:** Substantive original and cross-review. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored.
- **Grok:** `ses_ec4128917ffeeVds3Y2p7xrVjp`.
- **MiniMax M3:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. It does not recall `ses_ebdf718feffemWQNf7wuTpapqX`. The first pass and cross-review task wrappers returned no text. Both saved reports are substantive and are counted. The first pass said do not close. The cross-review withdrew that.
- **Kimi K3:** Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **Library source:** OpenZeppelin `ERC4626.withdraw` transfers the requested assets and burns `previewWithdraw` shares. Retrieved 2026-10-18 from `https://github.com/openzeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC4626.sol`.
- **Execution evidence:** No Forge run. Consensus is not proof.

Writing this close does not authorize implementation.

## Required outcome

No production change. RC-02 is closed because the current helper already pays the exact due amount.

## Confirmed

- `_payUnderlyingLocalFirst` pays booked local cash first, then calls `vault.withdraw(shortfall, recipient, address(this))`. `ERC4626StandardExchangeCommon.sol:116-127`.
- A normal `withdraw` sends exactly that asset amount. The rounded share cost is burned from the Standard Exchange, not paid to the recipient as extra tokens.
- The three callers pass the accounted amount: exact-out at `ERC4626StandardExchangeOutTarget.sol:112`, exact-in at `ERC4626StandardExchangeInTarget.sol:100`, and the yield redemption at `ERC4626StandardYieldTarget.sol:26`.
- Nothing is sent to `feeTo`.

## Dissent

MiniMax's first pass treated `withdraw` as if it paid a rounded share redemption. That claim is withdrawn. Astra, Grok, and Kimi rejected it. No remaining dissent.

## Non-goals

Do not add a cap, a pull-back, or a payment to `feeTo`. Do not change the separate receipt-input `redeem` route. That route burns an exact receipt amount. It is not this payout.
