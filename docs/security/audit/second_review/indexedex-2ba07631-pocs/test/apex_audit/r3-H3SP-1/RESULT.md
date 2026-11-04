# r3 / H3SP-1: ComposedStable primary redemption pays one reserve leg and forfeits the other

Status: CONFIRMED by execution (honest-user loss, no attacker). Suite result: ok, 3 passed; 0 failed (t4, profile audit).
File: test/apex_audit/r3-H3SP-1/H3SP1_OneLegRedemption.t.sol

## Setup
Production ComposedStable fixture (TestBase_ComposedFundedRoutes). Reserve weights are 50/25/25, deploy config mint=1e30 and burn=1e29, so the primary burn gate is open (synthetic price 0.9286e18 < burnThreshold). alice buys 100e18 stable BPT worth of DETF and holder2 buys the same, both by the normal exchangeIn path. No cheatcodes run during the measured operations. Each branch starts from the same snapshot.

## Results
test_exactOut_forfeitFlowsToRemainingHolders [PASS]
- exactIn: 23,203,683,264 DETF -> WETH pays 12.1783 WETH (both legs consolidated).
- exactOut of the same 12.1783 WETH: quote = paid = 42,540,170,043 DETF (1.833x).
- Fair value of those 42.54e9 DETF on the exact-in route from the same state is 22.3270 WETH.
- **alice loses 10.1486 WETH, 45.45% of the fair value she burned.** This equals the common-leg share of the slice; the stable leg is 54.5% by value.
- The protocol keeps 10.72 reserve LP from the re-join. LP per DETF rises from 3.3672e26 to 3.3930e26.
- holder2 then redeems everything to WETH and gets 42.6922 WETH instead of 42.4946, a gain of 0.19764 WETH. The pro-rata share of alice's forfeit predicts 0.19764 WETH, so the two agree to within 0.001%. This closes the value-flow loop: the forfeit goes to the remaining holders.

test_exactIn_toStableBpt_forfeitFlowsToRemainingHolders [PASS]
- The same 23.2e9 DETF sent exact-in to stablePool BPT returns BPT worth 6.6427 WETH, against 12.1783 WETH on the WETH route. That is a 45.45% loss.
- holder2's gain is 0.107325 WETH, against 0.107306 WETH expected pro-rata.

test_exactOut_toStableBpt_vs_exactIn [PASS]
- BPT exact-out and BPT exact-in charge the same DETF (ratio 1.0000x). Both BPT routes are one-leg. The only route that pays full non-DETF backing is exact-in to rateAsset or a route token, which is the inconsistent reference.

## Root cause
ComposedStableCommonDetfCommon.sol:
- _previewReserveDetfInForPoolBptOut (754-761, primary branch): lp = amount*S/raw[leg]. The DETF charge is sized as if the selected leg were the whole backing.
- _executeExactOutExit (917-935): burns funded DETF, exits lp proportionally, delivers only the selected leg, then re-joins self, the unused selected leg and the whole other leg into protocol LP (line 934).
- _consolidatePoolBptsToTokenOut (843-851): exact-in to a pool-BPT output pays one leg and re-joins the other.
- By contrast, the exact-in path to WETH or a route token (853-861) consolidates both legs.

## Impact
An honest user who redeems through exactOut (any direct output: WETH, rateAsset, stable or common BPT) or through exactIn to a pool BPT while the burn gate is open loses about the other leg's value share, 45% here. The quote matches the charge, so maxAmountIn or slippage limits give no protection. The loss accrues pro-rata to remaining DETF holders. Attacker profit is limited to that pro-rata accrual; no extraction path was demonstrated. Suggested fix: on the primary path, consolidate both legs into the requested output (as the exact-in WETH path does). Alternatively, size exact-out from the total non-DETF value: lp = valueOut * S / (value(stable raw)+value(common raw)).

## Not executed
The MixedBuffer, MVW and UniswapV4 multi-leg sibling locations from the hypothesis were not tested here. Only the ComposedStable core is confirmed.
