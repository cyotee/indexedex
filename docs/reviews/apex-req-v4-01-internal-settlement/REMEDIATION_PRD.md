# Remediation PRD — legacy V4 yield redemption calls the inherited settlement

- **Status:** WITHDRAWN, 2026-10-15. The owner is deleting `contracts/protocols/dexes/uniswap/v4`. Do not implement this PRD or its plan. Hookless, Pons, and V3 copies are not this withdrawal.
- **Date:** 2026-10-15
- **ID:** REQ-V4-01
- **Origin:** `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md`, REQ-V4-01. Controlling law is `docs/reviews/apex-rc01-explicit-holder/REMEDIATION_PRD.md`.
- **Astra participation:** Substantive question pass and substantive cross-review. Session `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored. No resubmission.
- **Other reviewers:** Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`. MiniMax M3 `ses_ec41255ceffeVhrySLQe8hwwMC`. Kimi K3 is the labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **Owner ruling, 2026-10-15:** Delete `executeNamedHolderRedemption`. Also delete the four-argument `executeZapOutExactIn` on the legacy V4 delegate. Its only caller is the ordinary share exit in `UniswapV4StandardExchangeInTarget.sol`. That exit calls `_executeZapOutExactIn` directly and passes `address(this)`, because the shares were already pulled onto the vault. Do not change the hookless, Pons, or V3 copies. REQ-V4-02 stays a separate item.
- **Authorization:** Writing this PRD does not authorize editing code in this session.

## Required outcome

Legacy V4 yield redemption calls the inherited `_executeZapOutExactIn` and passes the holder it already has. It does not `delegatecall` another contract to do that. A hook join is not this item.

## What is wrong now

`_settleNamedHolder` already receives the holder. Vault-held redemption passes `address(this)`. Ordinary redemption passes `msg.sender`. The helper then `delegatecall`s `executeNamedHolderRedemption` on `UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE` (`UniswapV4StandardYieldExecutionTarget.sol:26-35`).

The facet already inherits `_executeZapOutExactIn` (`UniswapV4StandardExchangeInBase.sol:146-152`). The V3 FullSpread path calls that kind of function directly (`UniswapV3FullSpreadStandardYieldExecutionTarget.sol:26-30`). The old self-call is already gone. The remaining gap is the hop.

## Required repair

Edit only the body of `_settleNamedHolder` in `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol`.

1. Keep the function name, the arguments, and `nonReentrant`.
2. Replace the `delegatecall`, the assembly revert, and the result decode with one internal call:

```solidity
amount_ = _executeZapOutExactIn(tokenOut_, shares_, minimum_, receiver_, holder_);
```

3. Keep `_pokeBoundPoolTwap()` after that call returns. Do not copy the V3 helper's immediate return. V3 does not have this poke.
4. Do not add `_requireNotDisabled`. REQ-V4-02 owns that check. This item does not close it and does not waive it.
5. Do not add V3's `SYMinimumNotMet` check. The inherited function already rejects a short result.
6. Do not change `_redeemVaultHeld` or `_standardRoute`. They already pass the holder.
7. Delete `executeNamedHolderRedemption` and `executeZapOutExactIn` from `UniswapV4StandardExchangeInExecutionDelegate.sol`. Do not delete `executeZapInDeposit`. Do not add a new caller for either deleted function.
8. In `UniswapV4StandardExchangeInTarget.sol`, replace `_delegateExecuteZapOutExactIn` with a direct call to `_executeZapOutExactIn(tokenOut, actualIn, minAmountOut, recipient, address(this))`. Delete `_delegateExecuteZapOutExactIn`. Do not change the deposit delegatecall.
8. Do not edit V3 FullSpread, hookless, or Pons.

If the deployed `UniswapV4StandardExchangeInFacet` runtime exceeds 24,576 bytes after the edit, stop and report the measured size. Do not restore the hop, add a self-call, paste the settlement body, or enable `via_ir` to get under the limit.

## Acceptance criteria

- `_settleNamedHolder` calls `_executeZapOutExactIn` with the five arguments it already has.
- That helper contains no `delegatecall` and no external call to `address(this)`.
- `nonReentrant` and `_pokeBoundPoolTwap()` remain.
- Vault-held redemption still passes `address(this)`. Ordinary redemption still passes `msg.sender`.
- `executeNamedHolderRedemption` and the legacy V4 `executeZapOutExactIn` are deleted. `executeZapInDeposit` remains.
- The ordinary share exit calls `_executeZapOutExactIn` and passes `address(this)`. It does not `delegatecall`.
- `_requireNotDisabled` is not added by this item.
- V3 FullSpread is unchanged.
- An oversized facet is reported. The hop is not put back to hide it.

## Non-goals

- Do not implement REQ-V4-02 here.
- Do not delete the execution delegate. Do not delete `executeZapInDeposit`. Do not change hookless, Pons, or V3 wrappers of the same name.
- Do not restore a self-call.
- Do not delete legacy V4.
- Do not change hookless or Pons `delegatecall` paths.
- Do not claim an unauthorized payout was shown.

## Verification

Implement only after a separate request. This is a production edit. Refresh artifacts before `forge test` with `python3 scripts/forge-artifacts.py`. Re-read the existing legacy V4 vault-held redeem test. It must still pass. It must not assert the old hop. Report the commands, the toolchain, and the facet size. A present call is not a pass until that run is reported.

## Dissent

- The first draft left `executeZapOutExactIn` in place. The owner then ruled that the legacy V4 wrapper is removed and its one caller uses the internal settlement. Hookless, Pons, and V3 copies are not this item.
- Kimi's first pass would fold the disable check into this edit and delete the wrapper. Kimi's cross-review withdrew both.
