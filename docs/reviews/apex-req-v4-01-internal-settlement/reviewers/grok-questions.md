# Grok questions — REQ-V4-01

- **Date:** 2026-10-15
- **Question:** Does REQ-V4-01 still need an owner decision before a PRD?
- **Answer:** Ready. No owner decision remains. The recorded text already selects the internal call.

## Why no question is asked

`docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:75-79` already says legacy V4 yield redemption calls the inherited `_executeZapOutExactIn`, passes `address(this)` or the original caller, does not `delegatecall` or externally call `address(this)`, and does not keep the holder-taking wrapper as the yield path. If a deployed unit no longer fits, that fact is reported. The delegate hop is not the substitute. V3's internal call is the matching shape and is not rewritten.

The explicit-holder PRD at `docs/reviews/apex-rc01-explicit-holder/REMEDIATION_PRD.md:17` and `:78-79` selects the same internal call. Its plan at `REMEDIATION_PRD.plan.md:140` names the limit and the forbidden substitute: if a deployed unit no longer fits 24,576 bytes, report that. Do not restore a call to self, and do not move the yield path onto a delegate, to get under the limit.

Current source can make that call. `UniswapV4StandardYieldExecutionTarget` inherits `UniswapV4StandardExchangeInTarget`, which inherits `UniswapV4StandardExchangeInBase`. The inherited declaration is `_executeZapOutExactIn(address,uint256,uint256,address,address)` at `UniswapV4StandardExchangeInBase.sol:146-152`. The two callers already pass the holders: vault-held passes `address(this)` at `UniswapV4StandardYieldExecutionTarget.sol:14`, and ordinary redemption passes `msg.sender` at `:21`. The defect is the body at `:29-33`, which `delegatecall`s `executeNamedHolderRedemption` on the execution delegate. V3's matching body is the internal call at `UniswapV3FullSpreadStandardYieldExecutionTarget.sol:29`.

No function name, error name, or line layout is left for the owner.

## Mechanical closures the PRD must state

These are not new choices. They stop an implementer from reading "matching shape" as permission to copy V3's omissions or to redesign the delegate.

- Replace only the `delegatecall` in `_settleNamedHolder`. The body assigns `amount_ = _executeZapOutExactIn(tokenOut_, shares_, minimum_, receiver_, holder_)`, then calls `_pokeBoundPoolTwap()`. Do not return before the poke. V3 has no poke there. REQ-V4-02 already requires this poke to remain.
- Do not add a function. Do not rename `_settleNamedHolder`. Do not change the two holder arguments already at lines 14 and 21.
- Do not call `executeNamedHolderRedemption`. Do not delete that function, and do not change the four-argument `executeZapOutExactIn` wrapper, in this item.
- Keep `nonReentrant` on `_settleNamedHolder`. Do not add a second lock to `_executeZapOutExactIn`.
- Do not add V3's `SYMinimumNotMet` check. The inherited function already reverts `UniswapV4ExchangeIn_SlippageExceeded` when output is below `minAmountOut`.
- Do not add `_requireNotDisabled` in this item. REQ-V4-02 owns that sentence.
- Do not edit `UniswapV3FullSpreadStandardYieldExecutionTarget`. Do not edit hookless or Pons. Do not delete legacy V4.
- The deployed unit that contains this body is `UniswapV4StandardExchangeInFacet`. If its runtime exceeds 24,576 bytes, report that size and stop. Do not restore the delegate hop, a self-call, or a move onto the execution delegate to get under the limit.
- Do not invent a new test. The acceptance is the source call shape already recorded.

I did not run Forge.
