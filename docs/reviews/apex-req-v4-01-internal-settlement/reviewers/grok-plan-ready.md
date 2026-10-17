# Grok plan readiness — REQ-V4-01

- **Date:** 2026-10-15
- **PRD:** `docs/reviews/apex-req-v4-01-internal-settlement/REMEDIATION_PRD.md`, read in full.
- **Answer:** Ready. No owner decision remains.

The owner ruling already deletes `executeNamedHolderRedemption` and the legacy V4 four-argument `executeZapOutExactIn`. It already sends that wrapper's one caller to `_executeZapOutExactIn` with `address(this)`. REQ-V4-02 stays out. The inherited declaration already takes the holder (`UniswapV4StandardExchangeInBase.sol:146-152`). The two yield callers already pass `address(this)` and `msg.sender`.

## Mechanical closures a plan must state

1. **Order.** Edit the yield body first. Then replace the share-exit caller and delete its helper. Then delete the two delegate functions. Do not delete the wrapper before its caller is replaced.
2. **Yield call.** In `_settleNamedHolder`, replace the `delegatecall`, assembly revert, and decode with `amount_ = _executeZapOutExactIn(tokenOut_, shares_, minimum_, receiver_, holder_);`, then keep `_pokeBoundPoolTwap()`. Keep the name, arguments, and `nonReentrant`. Do not change `_redeemVaultHeld` or `_standardRoute`.
3. **Share-exit call.** In `UniswapV4StandardExchangeInTarget._exchangeIn`, replace `_delegateExecuteZapOutExactIn(address(tokenOut), actualIn, minAmountOut, recipient)` with `_executeZapOutExactIn(address(tokenOut), actualIn, minAmountOut, recipient, address(this))`. Keep the `_pokeBoundPoolTwap()` already after that call. Do not change `_delegateExecuteZapInDeposit`.
4. **Deletions.** Delete `_delegateExecuteZapOutExactIn`. Delete `executeNamedHolderRedemption` and `executeZapOutExactIn` from `UniswapV4StandardExchangeInExecutionDelegate.sol`. Delete `SELF` and `DelegateCallRequired` with them; only the deleted named-holder function uses them. Do not delete the delegate contract or `executeZapInDeposit`. Do not delete the hookless, Pons, or V3 functions of the same name.
5. **Measured unit.** After the edit, measure the runtime of `UniswapV4StandardExchangeInFacet`. If it exceeds 24,576 bytes, stop and report that size. Do not restore the hop, add a self-call, paste the settlement body, or enable `via_ir`.
6. **Test file.** Refresh artifacts with `python3 scripts/forge-artifacts.py`, passing the edited production sources and `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol` as the test root, then run that file. It must pass. It must not assert the old hop. Do not add a test. Do not add `_requireNotDisabled` or V3's `SYMinimumNotMet` check.

I did not run Forge.
