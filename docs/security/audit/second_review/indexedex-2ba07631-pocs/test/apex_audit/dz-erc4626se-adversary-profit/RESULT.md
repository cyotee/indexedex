# dz-erc4626se-adversary-profit: REFUTED BY EXECUTION (harness ghost-accounting artifact)

The campaign break: slot12 deep run, `~/audits/deep/staking.log` lines 259-279, P4_ERC4626SE_Invariant.
`invariant_adversaryNoProfit` reported +0.7314e18 and `invariant_honestNoLoss` reported -0.2121e18.
Foundry shrank the failing sequence to 3 calls:
1. `advDonate(3.315e36, 8.705e47, false)`: the adversary transfers 13.199e18 protocol-vault receipts straight to the SE. They stay unbooked.
2. `advRateMove(288)`: exogenous +2.88% yield on the protocol vault. The rate goes from 1.37 to 1.409456.
3. `advPretransferMintOutSweep(864000, 16359, 5621111)`: the adversary pretransfers receipts and calls `exchangeOut(receipt -> SE, maxIn = max, pretransferred = true)`. `_receiptForExactShares` credits every unbooked receipt (prepaid = donation + pretransfer), prices the mint on `backing - prepaid`, and sends `prepaid - required` back to msg.sender.

## Replay: DZReplay.t.sol (executed on the audit runner, PASS)
The replay has a control branch that runs only the rate move and no adversary calls. It compares how much the honest actor and the DEAD holder could actually redeem:
- actor0 realizable value: control 243825600000000000001, attack 243825600000000000001. **The real loss is 0 wei.**
- DEAD realizable value: control 1409456000000000000, attack 1409456000000000000. **The real loss is 0 wei.**
- Harness adversary netGain is +0.520781e18. This equals the donated receipts times the rate change: 13.199e18 * (1.409456 - 1.37) = 0.5208e18. That is yield on the adversary's **own** receipts.
- Harness honest netGain is -0.517788e18. It mirrors the figure above. It is pure bookkeeping.

## Root cause (of the false positive)
`fairNav()` counts unbooked donated receipts (`protocolVault.balanceOf(se)`), so a donation raises honest `shareValue` without touching their `exo`.
`advRateMove` then folds the yield earned by the adversary's parked donation into the honest actors' `exo`.
When the adversary reclaims its donation through the pretransfer credit refund, honest ghost wealth falls back to the true value. The ghost therefore shows "honest loss" and "adversary profit", but no value moves between parties.
The vault prices the exact-out mint ex-credit (`totalBefore = backing - prepaid`) correctly, and the minted shares are fair.

## Catalog mapping
The reclaim path is the APEX-2026-039 pretransfer-credit refund-to-msg.sender mechanism. Here the caller only reclaims its own donation, so there is no victim.
This is not APEX-2026-034: the vault holds a 1e18 dead seed and is never empty.
There is no new finding.

## Harness fix
Count the adversary's unbooked donated balance (receipt or underlying) as adversary wealth, or exclude unbooked balances from `fairNav`/`shareValue`. Either way, rate-move yield on parked donations is attributed to the adversary.

Note: the campaign's exact figures (0.7314 / -0.2121) come from the original 12-call run. The shrunk 3-call replay reproduces the same mechanism with 0.52 / -0.52.
