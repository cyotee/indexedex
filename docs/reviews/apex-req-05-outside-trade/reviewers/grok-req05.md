# Grok — REQ-05 outside-trade credit

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-17
- **Controlling text:** REQ-05 in `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`, as named by OD-04 and OD-08.

REQ-05 is not complete.

The deleted tree `contracts/protocols/dexes/uniswap/v4` is not this item. `UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol` is not the proof.

## What each family shows

| Family | Pool trade is not a vault call | Book is not refreshed | Next credit uses only held tokens |
| --- | --- | --- | --- |
| V3 FullSpread | Yes. `FeeCompound.t.sol:64` calls `pool.swap`. | Yes. Lines 65–67. | No. |
| V4 hookless FullSpread | Yes. `AttributionAndBooking.t.sol:39` calls `poolManager.swap`. | Yes. Lines 40–42. | No. |
| V4 Pons-family FullSpread | Yes. `AttributionAndBooking.t.sol:42` calls `poolManager.swap`. | Yes. Lines 43–45. | No. |
| Wings vault | Yes. `VaultMoney.t.sol:33` calls `manager.swap` through the pool actor. | Yes. Lines 34–36. | No. |

## Missing requirement

Each family is missing the same acceptance sentence: the following credit uses only tokens the vault holds.

The later deposit checks `minted == preview`. V3, hookless, and Pons also check that the caller receives that mint. Those checks show quote and execution agree. They do not show the credit is limited to tokens the vault holds. One family does not close another.

No repair is added beyond that existing acceptance sentence.

I did not run Forge.
