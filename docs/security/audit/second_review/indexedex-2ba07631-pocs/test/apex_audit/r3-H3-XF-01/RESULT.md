# r3 H3-XF-01 — transient sDETF stake ratchets fee/creator standing weights

Test: test/apex_audit/r3-H3-XF-01/R3StakingWeightRatchet.t.sol (live 4663 fork, block 26240176)
Run: forge test .../R3StakingWeightRatchet.t.sol -vv --skip "'*/p4-fs/*'"  -> 3/3 PASS

## Executed results
- Unprivileged flash ratchet (PM unlock, take 100M DTF, hook buy -> peak 3,471,462,222,303 raw DETF, stake+unstake, sell back, repay):
  ordinary share of W 5834 -> 5110 bps; fee 1249 -> 1466; creator 2916 -> 3422. totalGons unchanged. Attacker ends 0 DETF / 0 sDETF.
  Cost: 17,800.89 DTF of own capital (hook fees), about 0.0012 WETH.
- Persistence (test_A): over 3 identical honest 2M-DTF mints, alice gets 141,641,277 instead of 161,828,651 raw sDETF (-12.47%).
  fee+creator get 3,648,491,362 instead of 3,127,380,099.
- Creator self-dealing (test_B, ownerOf NFT #2 runs the attack): +364,777,884 raw sDETF over 3 events, worth 3,425 DTF at the hook,
  against a 17,801 DTF cost. That is a NET LOSS of 14,376 DTF. Break-even needs about 16M DTF of later mint volume (the ratchet is permanent).
- Repeat (test_C): a second round of the same size adds nothing. Weights track the historical peak of totalGons, so a bigger peak is needed to move them further.

## Verdict
The mechanism is confirmed by execution, but the economic impact is low:
- Victim absolute loss is small. Alice loses about 20.2M raw sDETF (about 190 DTF) per 6M DTF of minting, and the attacker spends 17.8k DTF.
- A non-creator attacker gains nothing. The creator gains only after more than 16M DTF of future mint volume.
- The spec intends this behavior. DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md §4.4 counts freely unstakable stake in O and says: "An unstake never reduces standing weights."
  RebasingClaimTokenDFPkg_Deploy.t.sol::test_standingRecipientsReceiveNewExpansionAfterAllStakeUnstakes asserts that standing weights keep earning after every staker has left.
- The spec does not discuss a flash-sized, same-tx peak of O. Report this as low/informational. Suggested fix: compute the target from a time-weighted or epoch-settled O, or top up weights only at reward-distribution time, using the O that is present then.

## Reviewer re-run (2026-10-21, fork block 26240208): 3/3 PASS
- Added a check in test_A that normalises by the total funded reward (accountedBacking delta). The pot is about the same in both runs: 7,357,537,451 in control and 7,350,956,196 attacked. Alice's share of the pot falls from 21,991 ppm to 19,265 ppm (-12.4%), and the test asserts this. The loss is not caused by a smaller reward.
- Units: DETF/sDETF use 9 decimals. Alice's loss of 20.18M raw is 0.0202 DETF, about 190 DTF, about 1.3e-5 WETH. All ordinary stakers together lose about 7.2% of each funded pot, about 5k DTF per 6M DTF minted.
- Severity: LOW. The cost is trivial, so this is cheap griefing. It is permanent but bounded by the hook's DETF depth. It has no attacker profit, and creator self-dealing loses money unless future mint volume exceeds 16M DTF. The spec intends top-up-only weights.
