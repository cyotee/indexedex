# MiniMax M3 — Legacy V4 redesign implementation plan

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, independent plan draft. No peer notes read. No code, REDESIGN_PRD.plan.md, or REMEDIATION_PRD.md was read or written this round except the rewritten PRD. No Forge run. No exploit procedure.
- **Controlling document:** `docs/reviews/legacy-v4-architecture-redesign-prd-review/REDESIGN_PRD.md` (124 lines, read in full).
- **Verdict:** **No choice remains.** The PRD closes every implementer decision. This plan sequences the edits a later session executes.

## Source confirmation (read for plan order)

The current legacy V4 structure is:

- `UniswapV4StandardExchangeCommon.sol` (god base, 1,335 lines): configuration accessors, disable/unlock gates, TWAP, reserve reads/writes, transition-quote math, rebalance, import maintenance, unlock callback and PoolManager execution primitives, swap-quote wrappers, custody helpers.
- `UniswapV4StandardExchangeInBase.sol` (`NativeStandardYieldQuoteBase, UniswapV4StandardExchangeCommon, ReentrancyLockModifiers`): IN execution primitives.
- `UniswapV4StandardExchangeOutBase.sol` (extends `UniswapV4StandardExchangeInBase`): OUT primitives.
- `UniswapV4StandardExchangeInTarget.sol` (`UniswapV4StandardExchangeInBase, StandardExchangeInExecutionBase`): `_exchangeIn`, delegates deposit to `InExecutionDelegate` via `_delegateExecuteZapInDeposit`, delegates share exit to inherited `_executeZapOutExactIn`.
- `UniswapV4StandardExchangeOutExecuteTarget.sol` (`UniswapV4StandardExchangeOutBase`): `_exchangeOut` self-calls `previewExchangeOut` at line 51; delegates zap-out to `OutExecutionDelegate` via `_delegateExecuteZapOutWithdrawal`.
- `UniswapV4StandardExchangeInQueryTarget.sol` (`UniswapV4StandardExchangeInBase`): 6 transition/external-quote functions.
- `UniswapV4StandardExchangeOutQueryTarget.sol` (`UniswapV4StandardExchangeOutBase`): 2 OUT query functions.
- `UniswapV4StandardExchangeInMultiFacet.sol`, `UniswapV4StandardExchangeOutMultiFacet.sol`, `UniswapV4StandardExchangeInMultiQueryFacet.sol`, `UniswapV4StandardExchangeOutMultiQueryFacet.sol`: all extend thin Multi targets.
- `UniswapV4StandardExchangeLiquidReserveFacet.sol`, `UniswapV4StandardExchangePositionImportFacet.sol`.
- `UniswapV4StandardYieldExecutionTarget.sol` (`UniswapV4StandardExchangeInTarget, NativeStandardYieldExecutionTarget`): legacy V4 SY hook layer.
- `UniswapV4StandardExchangeOutTarget.sol`: 14-line unused combiner (no facet inherits it).
- `UniswapV4StandardExchangeInExecutionDelegate.sol`: `executeZapInDeposit` only.
- `UniswapV4StandardExchangeOutExecutionDelegate.sol`: `executeZapOutWithdrawal`, self-calls `previewExchangeOut`.
- `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol`: 5-line import shim.

The current `facetCuts()` declares 15 package facets (5 shared + 10 family). The plan moves `unlockCallback` to a new dedicated callback facet, adds a callback-target internal function, and preserves the remaining 9 family facets with narrower inheritance.

## Edit order (Step 1–14, sequential)

Callers must be rewired before deletions. The plan performs every internal move and rewiring first, removes the shim and delegates only after all callers are off, and deletes the god bases only after the search proves no caller remains.

### Step 1 — Add the SY error declaration file

**Edit:** create `contracts/vaults/standard/sy/NativeStandardYieldErrors.sol` with the five error declarations from `NativeStandardYieldTarget.sol:90-94` (`InvalidSYToken`, `InvalidSYReceiver`, `ZeroSYAmount`, `UnsupportedNativePayment`, `SYMinimumNotMet`) and matching signatures.

**Why this first:** every SY consumer's error import path changes once this file exists. Done before any consumer edit so a single import edit per consumer replaces the shim and the existing aggregate at once.

### Step 2 — Add the six internal libraries

**Edit:** create `contracts/protocols/dexes/uniswap/v4/internal/UniswapV4StandardExchangeConfig.sol`, `Accounting.sol`, `Custody.sol`, `PoolOps.sol`, `Reserve.sol`, `Import.sol`. Each is an internal library with `internal` functions only. Move content from `UniswapV4StandardExchangeCommon.sol` and the bases into these libraries by responsibility (per the table at PRD line 21-31). The single `_quoteZapOutAmount` is moved to `Accounting.sol`; the duplicate in `OutBase` is removed at Step 6.

**Why this first:** no caller is rewired until the libraries exist.

### Step 3 — Add the callback target and facet

**Edit:** create `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCallbackTarget.sol` with the one `unlockCallback` body (validates PoolManager caller, decodes OperationParams, dispatches to `UniswapV4StandardExchangePoolOps`). Create `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCallbackFacet.sol` declaring only `IUnlockCallback.unlockCallback.selector`.

**Why this first:** no caller is rewired until the target exists.

### Step 4 — Rewire the InFacet and its targets

**Edit:** rewrite `UniswapV4StandardExchangeInTarget.sol` to remove the `InBase` and `Common` inheritance and instead call the new internal libraries. Keep the `_executeZapInDeposit` body inline; do not call the delegate. Keep the `_executeZapOutExactIn` body inline. Add `_requireNotDisabled()` to `exchangeIn` (already at the current line 55) and to the SY money entries (REQ-V4-02). Rewrite the `UniswapV4StandardExchangeInFacet.sol` to remove `unlockCallback` from its `facetFuncs` and remove the `UniswapV4StandardYieldExecutionTarget` import. The `UniswapV4StandardYieldExecutionTarget.sol` (legacy V4 SY hook layer) stays but is narrowed: it keeps `_settleNamedHolder`, `_redeemVaultHeld`, and `_standardRoute` overrides, narrowed to call the new internal libraries. The `InFacet` no longer needs to import the legacy V4 SY hook layer for `unlockCallback`; the hook layer's `_settleNamedHolder` already calls the inherited function directly (REQ-V4-01 state).

**Why this first:** the InFacet is the most imported facet; its callers must be rewired before any deletion.

### Step 5 — Rewire the OutFacet and its targets

**Edit:** rewrite `UniswapV4StandardExchangeOutExecuteTarget.sol` to remove the `OutBase` and `InBase` inheritance and call the new libraries. Move the withdrawal body from the OutExecutionDelegate into `UniswapV4StandardExchangePoolOps` (the `_executeFreeZapOutWithdrawalCore` and `_burnPositionLiquidity` operations). The `_executeFreeZapOutExactIn` and idle single-output conversion move to `UniswapV4StandardExchangePoolOps`. Replace the `IStandardExchangeOut(address(this)).previewExchangeOut(...)` self-calls at line 51 with an internal quote that reads stored state. Add `_requireNotDisabled()` to the OUT money routes. Rewrite `UniswapV4StandardExchangeOutFacet.sol` to drop the `_previewExchangeOut` inheritance references. Add the migration of the zap-out execution body from the delegate.

**Why this first:** the OUT self-preview is the most invasive current call shape; it must be removed before the delegate is deleted.

### Step 6 — Rewire the InQuery and OutQuery targets

**Edit:** rewrite `UniswapV4StandardExchangeInQueryTarget.sol` to remove the `InBase` and `Common` inheritance and call the new libraries. Rewrite `UniswapV4StandardExchangeOutQueryTarget.sol` to remove the `OutBase` and `InBase` inheritance and call the new libraries. Update their `facetFuncs` to return the closed selector lists from PRD lines 50-58.

**Why this first:** query facets reference only internal state; their refactor is independent of the money-route refactor.

### Step 7 — Rewire the InMulti and OutMulti targets and their Query targets

**Edit:** rewrite `UniswapV4StandardExchangeInMultiTarget.sol`, `UniswapV4StandardExchangeOutMultiTarget.sol`, `UniswapV4StandardExchangeInMultiQueryTarget.sol`, and `UniswapV4StandardExchangeOutMultiQueryTarget.sol` to remove broad inheritance and call the new internal libraries. The `exchangeInManyToOne` calls `UniswapV4StandardExchangeAccounting._depositInternal` (or equivalent). The `exchangeOutOneToMany` calls the new OUT zap-out conversion internally. Update `facetFuncs` per PRD lines 52-58.

**Why this first:** the multi facets are the lowest-importance target in this list and are independent of the legacy V4 deposit path.

### Step 8 — Rewire the LiquidReserve and PositionImport targets

**Edit:** rewrite `UniswapV4StandardExchangeLiquidReserveTarget.sol` to call `UniswapV4StandardExchangeReserve` and the new internal libraries. Rewrite `UniswapV4StandardExchangePositionImportTarget.sol` to call `UniswapV4StandardExchangeImport` and the new libraries. Update `facetFuncs` to return only the closed selector lists from PRD lines 60-61.

**Why this first:** these two facets reference the new Reserve and Import libraries only.

### Step 9 — Add `_requireNotDisabled()` to the SY money entries

**Edit:** in `UniswapV4StandardExchangeInTarget.sol` (or the legacy V4 SY hook layer if the SY path is in there), add `_requireNotDisabled()` to the SY `deposit` and `redeem` entry points. Do not add the check to view selectors.

**Why this first:** REQ-V4-02 is recorded; this is a single check insertion.

### Step 10 — Verify no importers remain for the god bases and unused combiner

**Action:** repo-wide search:

- `grep -rn "UniswapV4StandardExchangeOutTarget"` in the entire repo: must return zero non-test, non-doc references outside the file itself. If a consumer exists, stop and report it (PRD line 83).
- `grep -rn "UniswapV4StandardExchangeInBase\|UniswapV4StandardExchangeOutBase\|UniswapV4StandardExchangeCommon"` in the family files: the only references must be the new internal libraries and the new targets' import lines. After Steps 4-8, the only importers of these should be the new library files and the file deletion path.

**Why this before deletion:** the PRD requires a zero-reference search (line 83) and a repository-wide consumer search before any quote-helper deletion (line 88).

### Step 11 — Delete the two execution delegates and their wiring

**Edit:** delete `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInExecutionDelegate.sol` and `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutExecutionDelegate.sol`. Remove both delegate constructor arguments and both delegate factory deployments. Update `contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol` to drop the delegate deployers and remove the delegate constructor arguments. Remove `_delegateExecuteZapInDeposit` and `_delegateExecuteZapOutWithdrawal` from `UniswapV4StandardExchangeInTarget.sol` and `UniswapV4StandardExchangeOutExecuteTarget.sol` (the bodies are already inline from Steps 4-5).

**Why this order:** Steps 4-5 moved the bodies inline; Step 11 removes the now-unused hop. Withdrawing the deposit delegate before rewiring the body would leave a broken build.

### Step 12 — Delete `UniswapV4StandardExchangeCommon`, `InBase`, `OutBase`, and the unused `OutTarget`

**Edit:** delete the four files. `Common` is no longer imported (Step 10). `InBase` is no longer imported (Step 4, 6, 7). `OutBase` is no longer imported (Step 5, 6, 7). `OutTarget` had zero importers (Step 10).

**Why this order:** callers are rewired; verification is done.

### Step 13 — Delete the imported-position maintenance branches and the SY shim

**Edit:** delete the three imported-position maintenance functions (`_deployExcessImported`, `_increaseImportedPositionCommon`, `_increaseImportedPosition`) from `UniswapV4StandardExchangeImport.sol`. Keep the import decrease and collect used by `importPosition`. Delete `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol` (the 5-line shim). Repoint every consumer's import to `NativeStandardYieldTarget.sol` (the compatibility aggregate) or `NativeStandardYieldErrors.sol` (the new error file). Update the compatibility aggregate to import errors from the new file; the aggregate still keeps the existing behavior declarations, only the error declarations move to the new file.

**Why this order:** all internal refactors are done; consumers only need import-path changes. Per PRD line 86, the plan states these import-path changes as mechanical for other families, not as functional rewrites.

### Step 14 — Update `TestBase_UniswapV4StandardExchange` and DFPkg wiring

**Edit:** update `contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol` to construct the new package with the 14 cuts (5 shared + callback + 8 family: IN, IN query, position import, OUT, OUT query, liquid reserve, IN multi, IN multi query, OUT multi, OUT multi query). Update `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol` and `IUniswapV4StandardExchangeDFPkg.sol` to include the new CallbackFacet in `PkgInit`, `facetCuts`, and `facetAddresses`. Update `UniswapV4_Component_FactoryService.sol` to drop the two delegate deployers and to include the CallbackFacet deployer. Update `facetInterfaces` in DFPkg to include the new callback facet's interface.

**Why this order:** the TestBase and DFPkg are last; they depend on the new facets and library names.

## Package cut order (per PRD line 63)

`UniswapV4StandardExchangeDFPkg.facetCuts` installs, in this exact order:

1. `ERC20Facet` (shared)
2. `ERC5267Facet` (shared)
3. `ERC2612Facet` (shared)
4. `MultiAssetBasicVaultFacet` (shared)
5. `MultiAssetStandardVaultFacet` (shared)
6. `UniswapV4StandardExchangeCallbackFacet` (new, dedicated `unlockCallback` only)
7. `UniswapV4StandardExchangeInFacet` (`exchangeIn` + SY money entries)
8. `UniswapV4StandardExchangeInQueryFacet` (6 transition/external-quote functions)
9. `UniswapV4StandardExchangePositionImportFacet` (`importPosition`)
10. `UniswapV4StandardExchangeOutFacet` (`exchangeOut`)
11. `UniswapV4StandardExchangeOutQueryFacet` (2 OUT query functions)
12. `UniswapV4StandardExchangeLiquidReserveFacet` (7 reserve selectors)
13. `UniswapV4StandardExchangeInMultiFacet` (`exchangeInManyToOne`)
14. `UniswapV4StandardExchangeInMultiQueryFacet` (2 multi-IN preview)
15. `UniswapV4StandardExchangeOutMultiFacet` (`exchangeOutOneToMany`)
16. `UniswapV4StandardExchangeOutMultiQueryFacet` (2 multi-OUT preview + 12 SY selectors)

15 + 1 = 16 family-cuts + 5 shared = 21 package cuts total. No other family facet is added. The shared five facets are unchanged. The legacy V4 SY hook layer (`UniswapV4StandardYieldExecutionTarget.sol`) is narrowed and stays as the abstract contract the InFacet (or the InTarget) extends for the legacy V4 specific `_settleNamedHolder` / `_redeemVaultHeld` / `_standardRoute` overrides. It is not a separate package cut; it is part of the InFacet's inheritance graph.

## What is moved, deleted, kept (explicit)

### New files (added)

- `contracts/vaults/standard/sy/NativeStandardYieldErrors.sol` (Step 1)
- `contracts/protocols/dexes/uniswap/v4/internal/UniswapV4StandardExchangeConfig.sol` (Step 2)
- `contracts/protocols/dexes/uniswap/v4/internal/UniswapV4StandardExchangeAccounting.sol` (Step 2)
- `contracts/protocols/dexes/uniswap/v4/internal/UniswapV4StandardExchangeCustody.sol` (Step 2)
- `contracts/protocols/dexes/uniswap/v4/internal/UniswapV4StandardExchangePoolOps.sol` (Step 2)
- `contracts/protocols/dexes/uniswap/v4/internal/UniswapV4StandardExchangeReserve.sol` (Step 2)
- `contracts/protocols/dexes/uniswap/v4/internal/UniswapV4StandardExchangeImport.sol` (Step 2)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCallbackTarget.sol` (Step 3)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCallbackFacet.sol` (Step 3)

### Deleted files (after search confirms zero importers)

- `UniswapV4StandardExchangeInExecutionDelegate.sol` (Step 11)
- `UniswapV4StandardExchangeOutExecutionDelegate.sol` (Step 11)
- `UniswapV4StandardExchangeCommon.sol` (Step 12)
- `UniswapV4StandardExchangeInBase.sol` (Step 12)
- `UniswapV4StandardExchangeOutBase.sol` (Step 12)
- `UniswapV4StandardExchangeOutTarget.sol` (Step 12)
- `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol` (Step 13)

### Deleted functions (within Import.sol)

- `_deployExcessImported` (Step 13)
- `_increaseImportedPositionCommon` (Step 13)
- `_increaseImportedPosition` (Step 13)

### Kept (refactored, narrowed)

- `UniswapV4StandardExchangeInFacet.sol`, `UniswapV4StandardExchangeOutFacet.sol`, `UniswapV4StandardExchangeInQueryFacet.sol`, `UniswapV4StandardExchangeOutQueryFacet.sol`, `UniswapV4StandardExchangeInMultiFacet.sol`, `UniswapV4StandardExchangeOutMultiFacet.sol`, `UniswapV4StandardExchangeInMultiQueryFacet.sol`, `UniswapV4StandardExchangeOutMultiQueryFacet.sol`, `UniswapV4StandardExchangeLiquidReserveFacet.sol`, `UniswapV4StandardExchangePositionImportFacet.sol`: their bodies call the new libraries; they do not inherit `Common`/`InBase`/`OutBase`; query facets do not inherit execution targets.
- `UniswapV4StandardExchangeInTarget.sol`, `UniswapV4StandardExchangeOutExecuteTarget.sol`, `UniswapV4StandardExchangeInQueryTarget.sol`, `UniswapV4StandardExchangeOutQueryTarget.sol`, `UniswapV4StandardExchangeInMultiTarget.sol`, `UniswapV4StandardExchangeOutMultiTarget.sol`, `UniswapV4StandardExchangeInMultiQueryTarget.sol`, `UniswapV4StandardExchangeOutMultiQueryTarget.sol`, `UniswapV4StandardExchangeLiquidReserveTarget.sol`, `UniswapV4StandardExchangePositionImportTarget.sol`: same name, narrowed inheritance.
- `UniswapV4StandardYieldExecutionTarget.sol`: kept, narrowed to legacy V4 SY hook layer (`_settleNamedHolder`, `_redeemVaultHeld`, `_standardRoute` overrides). Does not import the shim, the broad aggregate, or the new internal libraries directly.
- `UniswapV4StandardExchangeDFPkg.sol`, `IUniswapV4StandardExchangeDFPkg.sol`, `UniswapV4_Component_FactoryService.sol`, `test/bases/TestBase_UniswapV4StandardExchange.sol`: rewired for the new package and the new CallbackFacet, drop the two delegate deployers.
- The eleven existing repos stay the storage owners; no new family storage slot is added.

### Kept (untouched)

- The five shared facets: `ERC20Facet`, `ERC5267Facet`, `ERC2612Facet`, `MultiAssetBasicVaultFacet`, `MultiAssetStandardVaultFacet`.
- The V3, hookless, and Pons families.
- `NativeStandardYieldTarget.sol` (compatibility aggregate) — only its error declarations move to the new file.
- All shared repos.

## What is not done in this item (explicit)

- The pretransfer-credit residual correction is not in this item (PRD line 113). The current calculation is preserved as-is.
- New economics (share token, NAV formula, holder-selecting endpoint, substitute delegate) is not introduced.
- Live-instance upgrade and storage-compatibility claims are not made.
- A passing test and a measured size are not claimed. The plan requires the implementer to measure and run.

## Test files to run

The existing legacy V4 suites run unchanged against the rebuilt package through the updated `TestBase_UniswapV4StandardExchange.sol`. The plan names the following files:

- `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol` (vault-held redeem)
- `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_FullRangeBook.t.sol` (full-range book, including its facet-size assertion)
- `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_LocalLiquidBuffer.t.sol` (local liquid buffer)
- `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangePositionImport.t.sol` (NFT import)

The `adversarial/` and `decimals/` variants under `test/foundry/spec/protocol/dexes/uniswap/v4/` are also included. Production-proxy tests are run through the registry path. No mocks. Assertions are not rewritten to bless the old hops.

The plan does not add an economic assertion the PRD does not already state.

## Artifact and verification commands

The plan runs the following commands, in this order, from the repository root:

1. `forge build` to compile the new package.
2. `python3 scripts/forge-artifacts.py plan --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol` and the other test roots above, to inspect artifact selection. The plan does not pass a production source argument (the redesign has no production-bytecode change outside the legacy V4 family, and the helper accepts no production path per `docs/testing/ARTIFACT_BUILDS.md`).
3. `python3 scripts/forge-artifacts.py test` with the four test roots above to refresh runtime artifacts and run the suites. Hard cap: 24,576 bytes per facet. Advisory target: 23,000 bytes per facet. The plan records the measured runtime of every family facet.
4. The plan reports: toolchain (Forge 1.5.1-stable, solc 0.8.35, optimizer on, one run, `via_ir = false`), commands actually run, every result, measured facet runtime, and any failure.
5. If any facet exceeds 24,576 bytes, the plan stops and reports the dependency/size evidence. It does not restore a hop, a self-call, or `via_ir`. It does not combine groups, move selectors, or remove functionality unilaterally.

## What I am not adding

- I am not adding product economics. The PRD line 11 says "Do not invent a new economic model." This plan preserves the current calculation.
- I am not adding a new share token, NAV formula, or public holder-selecting endpoint. PRD line 112 forbids these.
- I am not restoring a delegate. D4 says both delegates are deleted; no replacement.
- I am not adding a new local-credit storage slot. PRD line 17 forbids it.
- I am not redesigning V3, hookless, or Pons. PRD line 114 forbids it.
- I am not making a passing-test or measured-size claim. The plan requires measurement and honest reporting.

I did not run Forge.