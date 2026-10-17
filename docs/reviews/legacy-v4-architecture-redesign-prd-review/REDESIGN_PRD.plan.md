> **Superseded — legacy family deleted (2026-10-15).** Retained as historical evidence only. Do not execute this plan or restore its implementation. See the [removal report](../legacy-v4-removal/EXECUTION_REPORT.md).

# Implementation plan — flatten the legacy V4 Standard Exchange

- **Date:** 2026-10-15
- **Status:** WITHDRAWN, 2026-10-15. Do not execute. The owner is deleting `contracts/protocols/dexes/uniswap/v4`.
- **Controlling PRD:** [REDESIGN_PRD.md](./REDESIGN_PRD.md). Where this plan conflicts with that PRD, the PRD controls.
- **Council:** Astra `ses_ec412bcc2ffejKLo7nuoEAqbV0`, Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`, MiniMax M3 `ses_ec41255ceffeVhrySLQe8hwwMC`, and Kimi K3 replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. Kimi does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. Astra answered both turns and was not censored. No Forge run. Consensus is not proof.
- **Drafts:** `reviewers/astra-plan.md`, `reviewers/grok-plan.md`, `reviewers/minimax-plan.md`, `reviewers/kimi-plan.md`, and the four `*-plan-cross.md` files. Those drafts are inputs. This file is the consolidation.

## Objective

Move the legacy V4 god base into the six named internal libraries. Delete both execution delegates. Move `unlockCallback` to its own facet. Keep every other installed selector on its current facet. Preserve the current economics, including the stored-reserve pretransfer credit calculation.

## What not to do

- Do not add a seventh library, a second callback facet, or a replacement delegate.
- Do not merge or split the current facet groups. The only selector that moves is `unlockCallback`.
- Do not add `_requireNotDisabled` except on SY `deposit` and `redeem`. Checks that already exist stay.
- Do not move the twelve SY query selectors off `UniswapV4StandardExchangeOutMultiQueryFacet`.
- Do not add a local-credit storage slot or repair the stored-reserve credit residual.
- Do not restore a hop, a self-call, or `via_ir` if a facet exceeds 24,576 bytes.
- Do not redesign V3, hookless, or Pons. Their only change is an import path.

## Package cuts

The package installs sixteen cuts: the five unchanged shared facets, then callback, IN, IN query, position import, OUT, OUT query, liquid reserve, IN multi, IN multi query, OUT multi, OUT multi query. There is no twenty-first cut. The callback facet is the only addition to the current fifteen.

## Order

| Step | Work | Why this order |
| --- | --- | --- |
| 1 | Add the SY error file and repoint shim imports | The shim cannot be deleted while importers remain. |
| 2 | Create the six libraries by moving existing bodies | Callers cannot switch until the destinations exist. |
| 3 | Add the callback target and facet | `unlockCallback` needs a home before it leaves the IN facet. |
| 4 | Rewire family targets off the bases and delegates | Live callers must leave before those files are deleted. |
| 5 | Wire the package and factory | The new facet must be installed and the delegate constructors removed. |
| 6 | Delete only after a zero-reference search | A string-encoded call can still compile against a missing function. |
| 7 | Update the TestBase, refresh artifacts, measure, and run | A present call is not a pass. |

## Step 1 — errors, then imports

Create `contracts/vaults/standard/sy/NativeStandardYieldErrors.sol` with the five existing errors and the same signatures: `InvalidSYToken`, `InvalidSYReceiver`, `ZeroSYAmount`, `UnsupportedNativePayment`, and `SYMinimumNotMet`.

Repoint every importer of `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol` to the file that defines the symbol it uses: `NativeStandardYieldTarget.sol` or `NativeStandardYieldErrors.sol`. Other families change only that import path. Do not change their redemption architecture.

Search again. Delete the shim only after that search shows no remaining importer. Keep `NativeStandardYieldTarget.sol`.

## Step 2 — move bodies into the six libraries

Create these files under `contracts/protocols/dexes/uniswap/v4/internal/`. Move existing bodies. Do not rewrite the economics.

| File | What moves into it |
| --- | --- |
| `UniswapV4StandardExchangeConfig.sol` | Pool key, token faces, managers, TWAP read, the one token-validity predicate, `_requireNotDisabled`, and the unlock-state gates. |
| `UniswapV4StandardExchangeAccounting.sol` | Sleeve, exact deployed amounts, and earned fees counted once. The one `_quoteZapOutAmount`. Share and issuance math. |
| `UniswapV4StandardExchangeCustody.sol` | Pull, credit, burn by explicit holder, payout, and the current operation-bounded refund. |
| `UniswapV4StandardExchangePoolOps.sol` | Swap, liquidity add or remove, fee collect, zap-in deposit, and zap-out withdrawal. Unlock decode types live here. Do not add a seventh file for them. |
| `UniswapV4StandardExchangeReserve.sol` | Deadband and ratio-limited rebalance. No catch-all. |
| `UniswapV4StandardExchangeImport.sol` | NFT authorization, matching pool, decrease and collect, and conversion into the managed book. |

Do not carry `_deployExcessImported`, `_increaseImportedPositionCommon`, or `_increaseImportedPosition` into `Import.sol`. Those functions are deleted, not moved. Keep the decrease and collect used by `importPosition`.

Replace the self-call at `UniswapV4StandardExchangeOutExecuteTarget.sol` that calls `previewExchangeOut` on `address(this)` with the internal quote. Do the same for the OUT delegate's self-previews before that delegate is deleted.

## Step 3 — callback facet

Create `UniswapV4StandardExchangeCallbackTarget.sol` and `UniswapV4StandardExchangeCallbackFacet.sol`. The target validates the PoolManager caller and settles through `PoolOps`. The facet declares only `IUnlockCallback.unlockCallback`.

## Step 4 — rewire callers

- In `UniswapV4StandardExchangeInTarget.sol`, the deposit branch calls `_executeZapInDeposit` internally. Remove `_delegateExecuteZapInDeposit` and the execution-delegate constructor argument. Remove `unlockCallback` from this target and from `UniswapV4StandardExchangeInFacet.facetFuncs`. The share exit already calls `_executeZapOutExactIn(..., address(this))`. Leave that call.
- Keep `UniswapV4StandardYieldExecutionTarget.sol` as the SY hook layer. It calls the internal libraries. Add `_requireNotDisabled` only on SY `deposit` and `redeem`, before burn or token movement. Vault-held yield still passes `address(this)`. Ordinary yield still passes `msg.sender`. Keep the following `_pokeBoundPoolTwap`.
- `exchangeOut` calls the internal quote and the withdrawal body in `PoolOps`. Delete `_delegateExecuteZapOutWithdrawal`. Do not write a second copy of that body.
- Query, multi, import, and liquid-reserve targets become thin callers of the libraries. They do not inherit `Common`, `InBase`, or `OutBase`. A query facet does not inherit an execution target.
- The twelve SY discovery and preview selectors stay on `UniswapV4StandardExchangeOutMultiQueryFacet`.

## Step 5 — package wiring

Update `IUniswapV4StandardExchangeDFPkg.sol`, `UniswapV4StandardExchangeDFPkg.sol`, and `UniswapV4_Component_FactoryService.sol`.

`facetCuts` and `facetAddresses` each have exactly these sixteen entries, in this order:

1. `ERC20Facet`
2. `ERC5267Facet`
3. `ERC2612Facet`
4. `MultiAssetBasicVaultFacet`
5. `MultiAssetStandardVaultFacet`
6. `UniswapV4StandardExchangeCallbackFacet`
7. `UniswapV4StandardExchangeInFacet`
8. `UniswapV4StandardExchangeInQueryFacet`
9. `UniswapV4StandardExchangePositionImportFacet`
10. `UniswapV4StandardExchangeOutFacet`
11. `UniswapV4StandardExchangeOutQueryFacet`
12. `UniswapV4StandardExchangeLiquidReserveFacet`
13. `UniswapV4StandardExchangeInMultiFacet`
14. `UniswapV4StandardExchangeInMultiQueryFacet`
15. `UniswapV4StandardExchangeOutMultiFacet`
16. `UniswapV4StandardExchangeOutMultiQueryFacet`

Drop both delegate deployments and both delegate constructor arguments. Do not deploy a replacement delegate.

## Step 6 — delete after the search

Search the repository again. Then delete, in this order, and only when the search shows no remaining importer:

1. `UniswapV4StandardExchangeInExecutionDelegate.sol` and `UniswapV4StandardExchangeOutExecutionDelegate.sol`
2. `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol`, if step 1's second search is still clean
3. `UniswapV4StandardExchangeOutTarget.sol`, if it still has no importer
4. `UniswapV4StandardExchangeCommon.sol`, `UniswapV4StandardExchangeInBase.sol`, and `UniswapV4StandardExchangeOutBase.sol`

If a quote helper still has a consumer, do not delete it. Report the consumer. If `UniswapV4StandardExchangeOutTarget.sol` has an importer, stop and report it. Do not delete a shared repo field. Do not delete `NativeStandardYieldTarget.sol`.

## Step 7 — artifacts, size, and tests

Update `contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol` to the new factory and the sixteen cuts. Tests still deploy the production proxy. Do not mock the facet.

From the repository root, default Foundry profile. Do not set `FOUNDRY_PROFILE=fork`. Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`. Pass every edited production source as a positional argument, including the new libraries, the callback facet, the edited family targets, the package, the factory service, and `NativeStandardYieldErrors.sol`.

```bash
python3 scripts/forge-artifacts.py plan \
  <each edited production source> \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4
python3 scripts/forge-artifacts.py test \
  <each edited production source> \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4 \
  -- -vv
```

The test root includes the vault-held redeem suite, the full-range book suite, the local liquid buffer suite, and the `adversarial/` and `decimals/` variants. Do not rewrite an assertion to bless a removed hop. If a test encodes the old delegation, stop and report that conflict.

Measure every deployed family facet runtime. The hard limit is 24,576 bytes. The advisory target is 23,000 bytes. Record a miss below the hard limit. If any facet exceeds 24,576 bytes, stop and report that facet and its measured size. Do not restore a hop.

The 31,908-byte figure is not a baseline.

Report the commands, the toolchain, every facet size, the search results, and the test result.

## Done when

- The six libraries and the callback facet exist. Both delegates, the shim, the three bases, and the unused combiner are gone.
- No in-scope path calls or `delegatecall`s `address(this)` to reuse an entrypoint, quote, or settlement.
- The package has the sixteen cuts above, in that order.
- SY `deposit` and `redeem` call `_requireNotDisabled` before burn or movement. No other new disable check was added.
- Every deployed family facet is at or under 24,576 bytes, or the run stopped and reported the oversized facet.
- The named suites passed after the artifact refresh, or the report names the failure and did not hide it.

## Dissent recorded, not adopted

- MiniMax's plan counted twenty-one cuts and deleted the SY shim before the repoint. The cross-review rejected both. This plan uses sixteen cuts and repoints first.
- MiniMax's plan also described adding `_requireNotDisabled` on OUT routes that already have it. This plan adds that check only on SY `deposit` and `redeem`.
- Astra's earlier sixteen-family-facet split and new credit slot are not this plan.

I did not run Forge.
