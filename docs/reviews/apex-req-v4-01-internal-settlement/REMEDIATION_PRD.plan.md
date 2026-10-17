# Implementation plan — legacy V4 yield redemption calls the inherited settlement

- **Date:** 2026-10-15
- **Status:** WITHDRAWN, 2026-10-15. Do not execute. The owner is deleting `contracts/protocols/dexes/uniswap/v4`.
- **Controlling PRD:** [REMEDIATION_PRD.md](./REMEDIATION_PRD.md). Where this plan conflicts with that PRD, the PRD controls.
- **ID:** REQ-V4-01. REQ-V4-02 is not this plan.
- **Council:** Astra `ses_ec412bcc2ffejKLo7nuoEAqbV0`, Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`, MiniMax M3 `ses_ec41255ceffeVhrySLQe8hwwMC`, and Kimi K3 replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. Kimi does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. Astra answered both turns and was not censored. No Forge run. Consensus is not proof.
- **Drafts:** `reviewers/astra-plan-ready.md`, `reviewers/grok-plan-ready.md`, `reviewers/minimax-plan-ready.md`, `reviewers/kimi-plan-ready.md`, and the four `*-plan-ready-cross.md` files. Those drafts are inputs. This file is the consolidation.

## Objective

Stop the legacy V4 yield path and the ordinary share exit from `delegatecall`ing redemption wrappers. Call the inherited `_executeZapOutExactIn`. Delete the two wrappers those calls used. Leave the deposit hop in place.

## What not to do

- Do not add `_requireNotDisabled`. REQ-V4-02 owns that check.
- Do not add `SYMinimumNotMet`. The inherited function already rejects a short result.
- Do not change `_executeZapOutExactIn` or paste its body into a caller.
- Do not change `_redeemVaultHeld` or `_standardRoute`.
- Do not delete `executeZapInDeposit`, `_delegateExecuteZapInDeposit`, the execution delegate contract, `SELF`, or `DelegateCallRequired`.
- Do not change hookless, Pons, or V3 functions of the same name.
- Do not restore either hop, add a self-call, or enable `via_ir` if the facet is over the size limit.

## Order

| Step | Work | Why this order |
| --- | --- | --- |
| 1 | Replace the yield helper body | Its caller must not still name a function this plan deletes. |
| 2 | Replace the ordinary share-exit call and delete its helper | Same reason. The shares are already on the vault. |
| 3 | Delete the two delegate wrappers | Do this only after both callers are gone. |
| 4 | Refresh artifacts, measure the facet, run the named test | A present call is not a pass. |

Before step 3, search the repository again for `executeNamedHolderRedemption` and for the legacy V4 signature `executeZapOutExactIn(address,uint256,uint256,address)`. The expected hits are the two wrappers and the two callers this plan changes. If another production caller exists, stop and report it. Do not delete the wrapper and do not reroute that caller.

## Step 1 — yield helper

In `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol`, replace the body of `_settleNamedHolder` with:

```solidity
function _settleNamedHolder(address tokenOut_, uint256 shares_, uint256 minimum_, address receiver_, address holder_)
    private nonReentrant returns (uint256 amount_)
{
    amount_ = _executeZapOutExactIn(tokenOut_, shares_, minimum_, receiver_, holder_);
    _pokeBoundPoolTwap();
}
```

Keep the function name and arguments. Do not copy the V3 helper's immediate return. V3 does not poke TWAP here.

## Step 2 — ordinary share exit

In `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol`, in `_exchangeIn`, replace the call to `_delegateExecuteZapOutExactIn` with:

```solidity
amountOut = _executeZapOutExactIn(address(tokenOut), actualIn, minAmountOut, recipient, address(this));
```

Keep `_secureShareDelivery` before that call. Keep `_pokeBoundPoolTwap()` after it. Keep the disable check already present on `_exchangeIn`. Do not change the deposit delegatecall.

Delete `_delegateExecuteZapOutExactIn`. Keep the `Address` import. The deposit hop still uses it.

## Step 3 — delete the two wrappers

In `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInExecutionDelegate.sol`, delete `executeNamedHolderRedemption` and the four-argument `executeZapOutExactIn`, including their comments.

Leave these in place:

- `SELF`
- `DelegateCallRequired`
- `executeZapInDeposit`

Do not delete any other declaration because it is unused.

## Step 4 — artifacts, size, and the test

From the repository root, default Foundry profile. Do not set `FOUNDRY_PROFILE=fork`. Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`.

```bash
python3 scripts/forge-artifacts.py plan \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInExecutionDelegate.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol
python3 scripts/forge-artifacts.py test \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInExecutionDelegate.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol \
  -- -vv
```

Measure the deployed runtime of `UniswapV4StandardExchangeInFacet` from the refreshed artifact. If it exceeds 24,576 bytes, stop and report the measured size. Do not restore a hop. Do not paste the settlement body. Do not enable `via_ir`.

The named test must pass. It must not be rewritten to assert the old hop. Report the commands, the toolchain, the facet size, and the test result.

## Done when

- `_settleNamedHolder` calls `_executeZapOutExactIn` and then `_pokeBoundPoolTwap()`. It has no `delegatecall`.
- The ordinary share exit calls `_executeZapOutExactIn` with `address(this)`. `_delegateExecuteZapOutExactIn` is gone.
- `executeNamedHolderRedemption` and the legacy V4 `executeZapOutExactIn` are gone. `executeZapInDeposit` remains.
- `SELF` and `DelegateCallRequired` remain.
- The facet runtime is reported and is at or under 24,576 bytes, or the run stopped and reported the oversize.
- The named test passed after the artifact refresh.

## Dissent recorded, not adopted

- MiniMax's first plan deleted the delegate functions before updating the callers. The cross-review rejected that. The calls are signature strings, so deleting first can still compile while pointing at a missing function.
- Grok's first plan also deleted `SELF` and `DelegateCallRequired`. Grok's cross-review withdrew that. The PRD names exactly two function deletions.
- MiniMax's cross-review still wanted an owner question on those two unused declarations. This plan leaves them. That is the recorded enumeration, not a new cleanup.

I did not run Forge.
