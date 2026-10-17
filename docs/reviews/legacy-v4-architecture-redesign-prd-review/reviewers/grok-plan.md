# Grok plan — legacy V4 redesign

- **Date:** 2026-10-15
- **PRD:** `docs/reviews/legacy-v4-architecture-redesign-prd-review/REDESIGN_PRD.md`, read in full.
- **Choice:** No choice remains. This plan sequences that design. It does not pick another.

Do not restore a delegate. Do not add `_requireNotDisabled` except on SY `deposit` and `redeem`. Existing checks stay, including `UniswapV4StandardExchangeInTarget.sol:55`. Do not add a local-credit slot. Do not redesign V3, hookless, or Pons.

## Order

| Step | Work | Why this order |
|---|---|---|
| 1 | Add the SY error file and repoint shim imports | The shim cannot be deleted while importers remain. |
| 2 | Add the six internal libraries by moving existing bodies | Callers can be rewired only after the destinations exist. |
| 3 | Add the callback facet and move `unlockCallback` | The selector must have one owner before the old declaration is removed. |
| 4 | Rewire deposit, share exit, yield redemption, and `exchangeOut` | Callers must not still name a function this plan deletes. |
| 5 | Add the SY disable check | It sits on the rewired yield entries, not on a view. |
| 6 | Delete delegates, helpers, bases, and the unused combiner | Only after the searches and rewires in steps 4 and 7. |
| 7 | Search, then delete only unconsumed quote helpers and the three import-maintenance functions | A found consumer stops that deletion. |
| 8 | Refresh artifacts, measure, and run the named suites | A present call is not a pass. |

## Step 1 — SY errors, then the shim

Create `contracts/vaults/standard/sy/NativeStandardYieldErrors.sol` with the existing SY error declarations and the same signatures. Do not delete `NativeStandardYieldTarget.sol`.

Repoint every importer of `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol` to `NativeStandardYieldTarget.sol` or `NativeStandardYieldErrors.sol`, matching which declaration that importer uses. Change only the import path. Current importers include the legacy yield target and the V3, hookless, Pons, constant-product, and hook files found by search. Do not edit their redemption bodies.

Delete the shim only after that search shows no remaining importer.

## Step 2 — move bodies, do not delete sources yet

Create these files by moving the current functions. Do not write a second copy.

| Destination | Move |
|---|---|
| `contracts/protocols/dexes/uniswap/v4/internal/UniswapV4StandardExchangeConfig.sol` | Pool, token, manager, and oracle reads; one token-validity predicate; the existing `_requireNotDisabled`; unlock-state gates. |
| `internal/UniswapV4StandardExchangeAccounting.sol` | The book and the one `_quoteZapOutAmount` now in `UniswapV4StandardExchangeInBase.sol`. Share and issuance math. |
| `internal/UniswapV4StandardExchangeCustody.sol` | The current pull, credit, named-holder burn, payout, and operation-bounded refund. |
| `internal/UniswapV4StandardExchangePoolOps.sol` | The current swap, liquidity add or remove, fee collect, `_executeZapInDeposit`, and the OUT delegate's `executeZapOutWithdrawal` body. |
| `internal/UniswapV4StandardExchangeReserve.sol` | The current deadband and ratio-limited rebalance. Remove any catch-all. An unexpected external failure reverts. |
| `internal/UniswapV4StandardExchangeImport.sol` | Authorization, matching pool, decrease and collect, and conversion into the managed book. |

Leave `UniswapV4StandardExchangeCommon.sol`, `UniswapV4StandardExchangeInBase.sol`, and `UniswapV4StandardExchangeOutBase.sol` in place until step 6.

## Step 3 — callback facet

Add `UniswapV4StandardExchangeCallbackTarget.sol` and `UniswapV4StandardExchangeCallbackFacet.sol`. Move the current `unlockCallback` body from `UniswapV4StandardExchangeInTarget.sol` into the callback target. The facet's `facetFuncs` contains only `IUnlockCallback.unlockCallback.selector`.

In the same edit, remove that selector from `UniswapV4StandardExchangeInFacet.facetFuncs`. Leave `exchangeIn` and the four SY execution selectors there: `deposit`, `redeem`, `rewardIndexesCurrent`, and `claimRewards`.

Add the callback facet to `IUniswapV4StandardExchangeDFPkg` and `UniswapV4StandardExchangeDFPkg.facetCuts` in this order: the five shared facets, callback, IN, IN query, position import, OUT, OUT query, liquid reserve, IN multi, IN multi query, OUT multi, OUT multi query. No other family facet is added.

`UniswapV4_Component_FactoryService.deployUniswapV4StandardExchangeCallbackFacet` deploys that facet with no delegate argument.

## Step 4 — rewire callers

In `UniswapV4StandardExchangeInTarget.sol`, replace the body of `_delegateExecuteZapInDeposit` with a direct call to `_executeZapInDeposit(tokenIn, amountIn, minSharesOut, recipient)`. Then delete `_delegateExecuteZapInDeposit`. The share-exit line stays:

`amountOut = _executeZapOutExactIn(address(tokenOut), actualIn, minAmountOut, recipient, address(this));`

In `UniswapV4StandardExchangeOutExecuteTarget.sol`, replace `IStandardExchangeOut(address(this)).previewExchangeOut(...)` with the internal quote. Replace `_delegateExecuteZapOutWithdrawal(...)` with the moved withdrawal function in `UniswapV4StandardExchangePoolOps`. Then delete `_delegateExecuteZapOutWithdrawal`.

In `UniswapV4StandardYieldExecutionTarget.sol`, keep:

```solidity
amount_ = _executeZapOutExactIn(tokenOut_, shares_, minimum_, receiver_, holder_);
_pokeBoundPoolTwap();
```

Vault-held redemption still passes `address(this)`. Ordinary redemption still passes `msg.sender`.

## Step 5 — disable check

Add the existing `_requireNotDisabled` at the start of the SY `deposit` and `redeem` paths in `UniswapV4StandardYieldExecutionTarget.sol`, before burn or token movement. Do not add it to a view selector, `exchangeIn`, `exchangeOut`, a dual-token entry, `importPosition`, or `rebalanceLiquidReserve`.

## Step 6 — deletions after the rewires

Delete these only after step 4 has removed their callers:

- `UniswapV4StandardExchangeInExecutionDelegate.sol`
- `UniswapV4StandardExchangeOutExecutionDelegate.sol`
- `deployUniswapV4StandardExchangeInExecutionDelegate`
- `deployUniswapV4StandardExchangeOutExecutionDelegate`
- the `executionDelegate` argument in `deployUniswapV4StandardExchangeInFacet` and the matching OUT facet deployer

Delete `UniswapV4StandardExchangeCommon.sol`, `UniswapV4StandardExchangeInBase.sol`, and `UniswapV4StandardExchangeOutBase.sol` only after no file inherits them.

Search again for importers of `UniswapV4StandardExchangeOutTarget.sol`. The current search finds only that file. If the new search is still empty, delete it. If an importer exists, stop and report it. Do not delete it.

## Step 7 — conditional deletions

Delete `_deployExcessImported`, `_increaseImportedPositionCommon`, and `_increaseImportedPosition` only after `UniswapV4StandardExchangeImport.sol` contains the decrease and collect used by `importPosition`. Do not delete that decrease and collect. Do not delete a shared repo field.

Search the repository for each legacy zap quote helper. Delete one only when that search shows no consumer. If a consumer exists, report it and leave the helper.

## Step 8 — commands

From the repository root, default profile. Do not set `FOUNDRY_PROFILE=fork`. Do not enable `via_ir`. Pass the edited production sources to the helper. Use this test root:

`test/foundry/spec/protocol/dexes/uniswap/v4/`

```bash
python3 scripts/forge-artifacts.py plan \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_FullRangeBook.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_LocalLiquidBuffer.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/adversarial \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/decimals
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_FullRangeBook.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_LocalLiquidBuffer.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/adversarial \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/decimals \
  -- -vv
```

Those files must pass through the production TestBase. Do not rewrite an assertion to bless a deleted hop.

After the refresh, measure the runtime of every deployed family facet, including `UniswapV4StandardExchangeCallbackFacet`. If any exceeds 24,576 bytes, stop and report that size. Record a miss of the 23,000-byte advisory target. Do not restore a hop, a self-call, or `via_ir`.

The twelve SY query selectors stay on `UniswapV4StandardExchangeOutMultiQueryFacet`: `exchangeRate`, `yieldToken`, `assetInfo`, `getTokensIn`, `getTokensOut`, `isValidTokenIn`, `isValidTokenOut`, `previewDeposit`, `previewRedeem`, `getRewardTokens`, `accruedRewards`, and `rewardIndexesStored`.

I did not run Forge.
