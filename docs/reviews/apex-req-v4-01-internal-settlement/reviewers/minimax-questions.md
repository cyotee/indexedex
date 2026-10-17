# REQ-V4-01 question pass — MiniMax M3

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, independent question pass. No peer notes read. No PRD, code, or test edited. No Forge run. No exploit procedure.
- **Question:** Does REQ-V4-01 still need an owner decision before a PRD, or is the recorded requirement enough to write one with no implementer choice?

## Verdict

**Ready. The recorded requirement is enough.** The owner does not need to make a new decision. The recorded text plus the V3 FullSpread model at `UniswapV3FullSpreadStandardYieldExecutionTarget.sol:26-30` is sufficient to write a PRD with no implementer choice.

I am not asking the owner to pick a function name, error name, or line layout. The V3 file already names the function (`_settleNamedHolder`), already names the holder parameter (`holder_`), already selects `address(this)` for vault-held redemption and `msg.sender` for ordinary redemption, already keeps `nonReentrant` and `_pokeBoundPoolTwap`, and already uses the direct internal call to the inherited function. The V4 edit is the same shape, applied to a different file.

## What I read this round

- `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` lines 68-80 (the REQ-V4-01 section).
- `docs/reviews/apex-rc01-explicit-holder/REMEDIATION_PRD.md` lines 25-114 (yield-redemption / inherited-settlement / size-limit sentences).
- `docs/reviews/apex-rc01-explicit-holder/REMEDIATION_PRD.plan.md` lines 38-44 (V4 settlement signature), 59-70 (V4 yield facet), 86-100 (V3 settlement and yield facet), 138-140 (size-limit instruction), 156-162 (Done-when).
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol` lines 26-36 (current V4 yield wrapper, the forbidden `delegatecall`).
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol` lines 146-152 (`_executeZapOutExactIn` already has `holder_`) and 186-192 (`_executeFreeZapOutExactIn` already has `holder_`).
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardYieldExecutionTarget.sol` lines 26-30 (the V3 model that the V4 edit must mirror).

## Why the recorded requirement is enough

The recorded REQ-V4-01 acceptance criteria at `apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:74-79` say:

- "Legacy V4 yield redemption calls the inherited `_executeZapOutExactIn` and passes `address(this)` or the original caller."
- "It does not `delegatecall` or externally call `address(this)`."
- "It does not keep a holder-taking wrapper on the execution delegate as the yield path."
- "If a deployed unit no longer fits the runtime limit, that fact is reported. The delegate hop is not the silent substitute."
- "V3 FullSpread's internal call is left as the matching shape, not rewritten to copy the V4 hop."

The recorded text selects the exact shape:
- The internal call goes to the **inherited** `_executeZapOutExactIn` (not a pasted body, not a new function, not a delegatecall).
- The holder is **the parameter** of that function (not hardcoded, not derived from a self-call, not from `executeIn`'s caller).
- The V3 model is the matching shape; the V3 file is "left as the matching shape, not rewritten."

The V3 file at `UniswapV3FullSpreadStandardYieldExecutionTarget.sol:26-30` shows the exact pattern:

```solidity
function _settleNamedHolder(address tokenOut_, uint256 shares_, uint256 minimum_, address receiver_, address holder_)
    private nonReentrant returns (uint256)
{
    return _executeZapOutExactIn(tokenOut_, shares_, minimum_, receiver_, holder_);
}
```

The V4 file at `UniswapV4StandardYieldExecutionTarget.sol:26-36` currently has the same wrapper signature, the same `nonReentrant`, the same `_pokeBoundPoolTwap()` call, but uses the forbidden `UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE.delegatecall` with a holder-taking wrapper function `executeNamedHolderRedemption` instead of the direct internal call. The fix is to replace the delegatecall with the same direct internal call the V3 file uses.

The V4 inherited function `_executeZapOutExactIn` at `UniswapV4StandardExchangeInBase.sol:146-152` already accepts `holder_` as the last parameter. The V3 inherited function at `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:183-228` already accepts `holder_`. Both are ready. The plan's prior work added the `holder_` parameter to the V4 inherited function; the V4 yield wrapper is the one that did not adopt that change. The yield wrapper is a one-file edit.

The recorded requirements plus the V3 model produce a one-file mechanical edit with no implementer choice:
1. Replace the `delegatecall` block in `_settleNamedHolder` at `UniswapV4StandardYieldExecutionTarget.sol:29-32` with a direct call to `_executeZapOutExactIn(tokenOut_, shares_, minimum_, receiver_, holder_)`.
2. Keep `nonReentrant` on `_settleNamedHolder` (already there at line 27).
3. Keep `_pokeBoundPoolTwap()` after the internal call (already there at line 35).
4. Drop the assembly revert pattern; a direct internal call reverts with a normal Solidity error.
5. The caller of `_settleNamedHolder` already passes the right holder: `_redeemVaultHeld` at the SY entry point passes `address(this)`; the share branch of `_standardRoute` passes the original caller. The recorded text says "Vault-held and ordinary redemption pass the holder, then..." (RC-01 PRD line 25). The yield wrapper takes the holder as a parameter and forwards it; the entry point above the wrapper chooses the holder. This is mechanical.
6. If the compiled unit exceeds 24,576 bytes after the edit, the implementer reports that fact; the delegate hop is not the silent substitute.

No new owner decision is required for any of these steps. The recorded acceptance criteria select the function (inherited), the call shape (internal, not delegatecall), the holder (parameter, `address(this)` for vault-held, original caller for ordinary), the reentrancy and TWAP preservation, and the size-limit report-on-exceed instruction. The V3 file is the matching shape; the V4 edit applies that shape to the V4 file. There is no choice between the V3 shape and an alternative shape; the V3 shape is the recorded answer.

## Mechanical closure the PRD must state

A future PRD must state the following so the implementer does not choose. None of these is a new owner decision; each is a specification of the recorded requirement applied to the one-file edit.

1. **Edit file:** `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol`, the body of `_settleNamedHolder` at lines 29-32.
2. **Replace** the `delegatecall` to `UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE.executeNamedHolderRedemption` with a direct internal call to `_executeZapOutExactIn(tokenOut_, shares_, minimum_, receiver_, holder_)`.
3. **Keep** `nonReentrant` on `_settleNamedHolder` and `_pokeBoundPoolTwap()` after the internal call.
4. **Drop** the `assembly ("memory-safe") { revert(add(result_, 32), mload(result_)) }` pattern; a direct internal call reverts with a normal Solidity error from `_executeZapOutExactIn`.
5. **The caller of `_settleNamedHolder` passes the holder.** `_redeemVaultHeld` (vault-held) passes `address(this)`. The share branch of `_standardRoute` (ordinary) passes the original caller. This matches the V3 model at `UniswapV3FullSpreadStandardYieldExecutionTarget.sol:15, 22` and the RC-01 PRD line 25.
6. **If the compiled unit exceeds 24,576 bytes after the edit, the implementer reports that fact and does not restore the delegate hop.** This is the recorded size-limit instruction at `apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:78` and the plan's instruction at `apex-rc01-explicit-holder/REMEDIATION_PRD.plan.md:140`.
7. **Do not paste the body of `_executeZapOutExactIn` into the yield target.** The recorded text at `apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:73` requires "an internal call that passes the holder," not a duplicated engine. The V3 model calls the inherited function; the V4 edit must do the same.
8. **Do not modify `_executeZapOutExactIn` or `_executeFreeZapOutExactIn` in `UniswapV4StandardExchangeInBase.sol`.** Both already accept `holder_` (lines 151 and 192). The recorded text at `apex-rc01-explicit-holder/REMEDIATION_PRD.plan.md:38-44` and `:78-80` required this in the prior work.
9. **Do not change `_redeemVaultHeld` or `_standardRoute` in the calling site above the yield target.** The yield target is a one-file edit; the calling sites already pass the right holder and only need the wrapper to forward it. The recorded text at `apex-rc01-explicit-holder/REMEDIATION_PRD.plan.md:59-66` separates "settlement signature" from "yield facet" edits; the V4 yield target is the second step, the calling sites are already aligned with the prior settlement-signature step.
10. **V3 FullSpread is left alone.** The recorded text at `apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:79` and `apex-rc01-explicit-holder/REMEDIATION_PRD.md:107` says: "V3 FullSpread's internal call is left as the matching shape, not rewritten to copy the V4 hop." The V4 edit copies the V3 shape; the V3 file is not changed.
11. **The acceptance criteria at `apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:74-79` are restated in the new PRD.** The new PRD does not invent new criteria; it restates the recorded acceptance criteria for the V4 yield target.
12. **The recorded non-goals are restated.** The new PRD does not relax any of: do not restore a self-call; do not add a caller check in front of a self-call; do not treat hookless or Pons `delegatecall` to a different contract as this defect; do not delete legacy V4. (These are at `apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:80`.)

These are mechanical closures of the recorded requirement, not new decisions. The implementer follows them because the recorded text selects them; the owner does not need to be asked again.

## What I am not asking

- I am not asking the owner to pick a function name. The V3 file already has `_settleNamedHolder`; the V4 wrapper already has `_settleNamedHolder`. The PRD will say "edit the body of `_settleNamedHolder`."
- I am not asking the owner to pick an error name. The direct internal call uses the inherited function's revert reasons; no new error is introduced.
- I am not asking the owner to pick a line layout. The edit is in one file, in one function, replacing the body of a 7-line block.
- I am not asking the owner to decide between the V3 internal-call shape and an alternative. The recorded text at `apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:72, 79` and `apex-rc01-explicit-holder/REMEDIATION_PRD.md:13, 79` selects the V3 shape. There is no alternative under selection.
- I am not asking the owner to choose between passing `address(this)` and `msg.sender` as the holder. The RC-01 PRD at line 25 specifies: "Vault-held redemption passes `address(this)`. Ordinary redemption passes the original caller." The V3 file at lines 15 and 22 implements this. The V4 wrapper takes `holder_` as a parameter; the calling site selects the right holder.

## Summary

The recorded REQ-V4-01 requirement plus the V3 FullSpread model is sufficient. A PRD can be written with no implementer choice. The mechanical closure is a one-file, one-function body edit in `UniswapV4StandardYieldExecutionTarget.sol`. The owner does not need to be asked again.

I am ready. No new owner decision is required to write the PRD.

I did not run Forge.