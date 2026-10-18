# Grok — RC-08 named error

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-18
- **Controlling text:** RC-08 in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`

No existing error means held LP is not exactly the booked LP reserve. `InsufficientLPBacking` at `UniswapV2StandardExchangeOutTarget.sol:1015-1018` reverts only when `held < required`. Do not reuse it.

Add this error to `UniswapV2LpBacking`, and add `requireEqual(uint256 held, uint256 booked)` that reverts it:

```solidity
error LPReserveMismatch(uint256 held, uint256 booked);
```

Replace both blank reverts with that function. Keep the comparison `held != booked`.

- Line 880: `held` is `indexSource.pool.balanceOf(address(this))`. `booked` is `vault.vaultLpReserve`.
- Line 1007: `held` is `indexSource.pool.balanceOf(address(this))`. `booked` is `vault2.vaultLpReserve`.

Do not change either comparison to `<`.

LPReserveMismatch(uint256 held, uint256 booked)

I did not run Forge.
