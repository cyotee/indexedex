# gx-aave-cross-version-loop: adversarial execution (HEAD 2ba07631)

File: `GxAaveLoopAdversarial.t.sol`. It inherits `AaveCrossVersionLoopE2E_Test`, so the diamond is deployed through the real IndexedexManager/VaultRegistry path, on a local Aave V3.6 and V4 market with mock oracles. tokenA has 18 decimals at $2000; tokenB has 6 decimals at $1.

Run: `forge test .../GxAaveLoopAdversarial.t.sol -vv --match-contract GxAaveLoopAdversarial_Test --match-test test_G`
Result: `Suite result: ok. 12 passed; 0 failed`

## Tests and outcomes

| test | what it attacks | result |
|---|---|---|
| G1 roundTrip_exactIn | Victim deposits, then the attacker deposits 100 A and redeems everything | holds: out = in - 5e6 wei; victim not diluted |
| G2 mintExactShares_thenRedeem | Wrap exact-out mint, then redeem | holds: out <= paid |
| G3 dustExactOutLoop | 40 exact-out exits of 1 wei to 1.2e8 wei each, then a full redeem | holds: every exit burns shares > 0; total out < in |
| G4 rebalanceDerisk_sandwich | Front-run a permissionless de-risk rebalance, then back-run with a small exit and a full exit | holds: NAV step = 0; attacker out = in - 5e6 wei |
| G4b rebalanceThenCheapDeposit | rebalance, deposit, small exit, large exit (the P1 sequence) | holds |
| G5 repeatedRebalance_tailStrandsRawB | 120 hourly de-risks reach the fullUnwind tail; then a sandwich | holds: rawB = 0 (stranded B equals V3 B debt; the floor cancels it) |
| G6 / G6b forceRepay at risk | tokenA down so V3 HF < 1.05; tokenA up so V4 HF < 1.05 | holds: forceRepay de-risks fully, NAV unchanged (the `_safeFraction` HF<=1.06 concern does not bite because the cross leg is healthy) |
| G8 rawBDonation_capture | Donate 50k tokenB, deposit, small exit re-supplies it, exit | holds: attacker spends $650k and gets back $600k |
| G9 v3Liquidation_strandedB_sandwich | After a V3 liquidation, de-risk strands $104k raw tokenB and reported NAV drops 67%; then a sandwich | holds: profit is only 1.1e6 wei, because exits are capped at deliverable tokenA, so the B leg cannot be extracted |
| **G7b PoC v4Liquidation** | tokenA rallies and the vault is liquidated on V4 | **BREAK (user loss)** |
| **G10 v3Liquidation lock** | tokenA drops and the vault is liquidated on V3 | **BREAK (user loss / locked funds)** |

## Finding: the tokenB leg is mis-valued and cannot be delivered; a liquidation of either version turns that into a large loss for holders

Root cause:
- `CrossVersionLoopExecutor.netBalanceOf` (:262-272) floors the tokenB net (V4 supply - V3 debt) at 0, so `navUsd` (:392-399) ignores a tokenB deficit.
- Exits only ever pay tokenA. `_amountForShares` (ExchangeBase:137-157) caps the payout at local + phi*netA_position. `proportionalUnwind` (:305-361) can repay V3 tokenB debt only from V4 tokenB supply.
- There is no path anywhere that converts tokenA into tokenB or tokenB into tokenA.

The P2 hypothesis `aave-loop-nav-floor` covers the same root cause. Its static votes refuted it as interest drift only, on the grounds that supply and debt always move 1:1. A liquidation breaks that 1:1 relationship, and execution shows a large step.

### G7b: V4 liquidation (tokenA rally), the first exiter is overpaid and the victim is stuck
1. Alice (victim) and the attacker each deposit 100 A.
2. tokenA rises until V4 HF < 0.97. No keeper calls forceRepay in the HF 1.05 to 1.00 window: forceRepay has no incentive, liquidation does.
3. The attacker liquidates the vault on V4 (unprivileged `liquidationCall`). This repays 41.9 A of debt and seizes 108k tokenB of collateral. Reported NAV jumps to $620.5k while true NAV is $512.3k: an overstatement of $108,158.
4. The attacker redeems everything first and receives **120.96 A against a fair 100 A**. That is **+$53,767** at the fair oracle price, plus **+$561** from the liquidation.
5. Alice cannot exit in full. Over 60 hours of keeper rebalance/forceRepay attempts and chunked exits she realizes **60.48 A (a loss of 39.5 A, about $101k, against her fair 100 A)**. Her remaining shares are backed by 59 A of V3 collateral pinned behind 108k tokenB of V3 debt, and no tokenB exists to repay it (V4 sB = 0). Reported NAV is $155k against a true $47k.

### G10: V3 liquidation (tokenA drop), positive tokenB net is permanently undeliverable
1. Alice and Bob deposit 100 A each. tokenA falls and a liquidator repays the vault's V3 tokenB debt.
2. That leaves V4 tokenB supply larger than V3 tokenB debt by $208.9k, out of a true NAV of $313.4k.
3. Both holders exit in full and receive **only $104.5k (33% of true NAV)**. **$208.9k of tokenB stays stuck in the vault**, owned by the 1000 MINIMUM_LIQUIDITY shares at address(1). No route can deliver tokenB.

Preconditions and severity:
- A market move of about 16% (V3 leg) or 28% (V4 leg) in tokenA against tokenB, plus a liquidation of the vault before anyone calls the unincentivized `forceRepay`. G6/G6b show forceRepay works when someone calls it.
- The price moves are mock-oracle `setPrice` calls, standing in for oracle updates. The attacker uses no privileged action.
- The family is not in any deployment manifest (`deployments/`), so this matters before deployment. **Medium.**

Fix:
- Value the tokenB leg signed, so a deficit reduces NAV.
- Include raw tokenB in NAV.
- Give a deficit a path to be repaid, for example by swapping tokenA to tokenB, or by adding a tokenB exit leg or a pro-rata dual-token exit.
- Make forceRepay incentivized or trigger it earlier, so de-risking reliably happens before liquidation.
