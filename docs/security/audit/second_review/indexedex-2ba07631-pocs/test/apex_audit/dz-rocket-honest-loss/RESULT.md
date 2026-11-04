# dz-rocket-honest-loss: refuted_by_execution (harness valuation artifact)

Break: deep staking campaign (the audit runner ~/audits/deep/staking.log, seed 0x835ec620..., runs 1024 x depth 100),
P4_Rocket_Invariant invariant_honestNoLoss -23216372312380641 (cumulative over the original 42 calls).
Shrunk sequence (3 calls), from cache/invariant/failures/P4_Rocket_Invariant/invariant_honestNoLoss:
1. advDonate(tokSeed odd -> rETH, 25e18 -> bounded to 5e18, bare=true): the adversary sends 5 rETH raw to the vault (unbooked).
2. advRateMove: rETH rate goes from 1.1 to 1.1198 (+1.8%).
3. advPretransferMintOutSweep(rETH, maxAmountIn=max): the exact-out credit includes the adversary's own unbooked 5 rETH; the unused credit is refunded to msg.sender, so the adversary gets its own donation back.

## Why this is not a protocol bug
- Rocket deposit fee: HermeticDepositPool.depositFeeBps defaults to 0 and the harness never sets it. P5a b06 (fee-blind quote) and staking-fee-and-par-externalization cannot be the cause.
- The harness fairNav uses raw `balanceOf(vault)`, so the adversary's unbooked donation counts as honest wealth. advRateMove then books the rate gain on that donated rETH into the honest actors' `exo`. When the adversary reclaims its own rETH, honest wealth falls back and the harness reports -(honest share x 5 rETH x 0.0198) = -0.099e18 in replay. The campaign's -0.0232e18 is the same effect, netted against the rest of the 42-call history. The adversary's matching +0.099e18 is the appreciation of its own rETH. In the full campaign, adversaryNoProfit stayed green because the adversary's cumulative netGain absorbed it.
- Honest actor 0's real claim, priced on booked reserves only, goes from 209.999 to 213.420 ETH. That is exactly the rate move on its own booked rETH, with no loss.
- Weaponisation is refuted. Any honest operation calls `_syncAllExpectedHoldReserves`, which books the donation, so it can no longer be reclaimed. A donate -> honest mint -> reclaim sandwich gives a refund of 0, the victim's 100 WETH mint is worth exactly 100, and the attacker loses its donation.
- The self-refund of the donor's own unbooked balance is the known resting-credit class (APEX-2026-039, prepaid-credit-refund-sweep); here only the donor's own funds move.

## Tests (RocketHonestLoss.t.sol, 5/5 PASS)
- test_replay_shrunk_reproduces: the harness flags honest0 at -0.099e18 and the adversary at +0.099e18; the booked claim only rises with the rate; unbooked rETH ends at 0.
- test_replay_bookedValuation_noHonestLoss: with fairNav on booked reserves, honest netGain is 0 and the adversary's gain equals the appreciation of its own 5 rETH.
- test_sandwich_honestMint_refuted: unbooked rETH after the victim's mint is 0, the reclaim refunds 0, the victim's value is 100/100, and the attacker ends at 107.10 against 122.00 spent.
- test_selfRefund_noHonestOp: control; the donor reclaims 19.999999999999090909 of its 20 rETH.

## Harness fix
In P4Common/host, value the vault on booked reserves (`reserveOfToken`), or exclude `_unbooked` from fairNav. Alternatively, attribute unbooked balances to the adversary in `wealth(ADV)`, as is already done for parked shares.
