# MiniMax M3 — Legacy V4 Standard Exchange flattened design

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, independent design pass. No peer notes read. No draft, plan, or REMEDIATION_PRD.md was read or written this round except the cited source files and the draft. No Forge run. No exploit procedure.

This design names successor components, one per responsibility; every installed selector and its one facet owner; and a keep/move/delete list. It is the implementer's instruction set, not a future plan's.

## Owner rulings (2026-10-14) taken as controlling

- Remove `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol` (the 5-line import shim). Mechanical compatibility changes only for V3 FullSpread, hookless V4, and Pons V4.
- One dedicated callback facet for legacy V4. No new replacement execution delegate. The two existing execution delegates (`UniswapV4StandardExchangeInExecutionDelegate.sol` and `UniswapV4StandardExchangeOutExecutionDelegate.sol`) stay as CREATE3 routing; no new delegate is added.
- Fresh-package storage only. No existing-instance compatibility or migration.
- Hard runtime limit **24,576 bytes** per facet. Design target **23,000 bytes** per facet for headroom. A facet exceeding the hard limit blocks completion.
- Supported SE/SY behavior, the full-range managed book, and the funded sleeve are preserved.
- REQ-V4-02 disable check is included (legacy V4 only, applied consistently; not the V3/FullSpread exemption).
- Unexpected rebalance failures propagate; no blanket catch-and-book.
- V3, hookless, and Pons are not redesigned.

## Current inheritance problem

Current chain for `UniswapV4StandardExchangeInFacet`:
```
InFacet
  -> UniswapV4StandardYieldExecutionTarget  (legacy V4-specific; narrow)
  -> UniswapV4StandardExchangeInTarget      (broad: pulls in InBase + SY + StandardExchangeInExecutionBase)
  -> UniswapV4StandardExchangeInBase       (broad: 402 lines; In + Out + Common)
  -> NativeStandardYieldQuoteBase, UniswapV4StandardExchangeCommon, ReentrancyLockModifiers
  -> NativeStandardYieldExecutionTarget     (5-line shim, to be removed)
  -> NativeStandardYieldMoneyTarget          (deposit, redeem, _standardRoute — imports shared SY)
  -> NativeStandardYieldValidation, StandardExchangeInExecutionBase
  -> NativeStandardYieldRewardsTarget       (rewardIndexesCurrent, claimRewards)
  -> NativeStandardYieldPreviewTarget       (previewDeposit, previewRedeem, discovery, etc.)
  -> NativeStandardYieldTarget              (compatibility aggregate; errors stay for cross-family mechanical compat)
```

The InFacet pulls in the full SY surface (money, rewards, preview, discovery) plus the entire SE Common base plus the import shim. This is the broad-inheritance problem the owner ruling names.

The self-call to `IStandardExchangeOut(address(this)).previewExchangeOut` in `UniswapV4StandardExchangeOutExecutionDelegate.sol:88,94` is the "OUT self-preview" the draft calls out. It is removed and replaced with an internal quote that reads stored state via the OutTarget's own local functions.

## Successor components (one per responsibility)

| Path | Responsibility |
|---|---|
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCallbackFacet.sol` (NEW) | One responsibility: own `unlockCallback(bytes)` and its underlying target only. No other selectors. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCallbackTarget.sol` (NEW) | One responsibility: `_unlockCallback(bytes)` plus the underlying unlock-and-decode plumbing. No SE money, no SY money, no queries. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol` (kept, narrowed) | One responsibility: own `exchangeIn` and the SY money selectors (deposit, redeem, rewardIndexesCurrent, claimRewards) that attach to the in-route. Pulls in only the narrowed InBase and the narrowed legacy V4 SY hooks. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutFacet.sol` (kept, narrowed) | One responsibility: own `exchangeOut` and the SY money selectors that attach to the out-route. Pulls in only the narrowed OutBase. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInQueryFacet.sol` (kept, narrowed) | One responsibility: own all IN-side queries (transition, external-quote, SY preview, SY discovery, SY total supply, SY share balance). Pulls in only the narrowed InQueryBase. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutQueryFacet.sol` (kept, narrowed) | One responsibility: own all OUT-side queries (preview, transition). Pulls in only the narrowed OutQueryBase. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiFacet.sol` (kept, narrowed) | One responsibility: own `exchangeInManyToOne` and its SY money attachment. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiFacet.sol` (kept, narrowed) | One responsibility: own `exchangeOutOneToMany` and its SY money attachment. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiQueryFacet.sol` (kept, narrowed) | One responsibility: own `previewExchangeInManyToOne` and `previewExchangeIn`. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet.sol` (kept, narrowed) | One responsibility: own `previewExchangeOutOneToMany` and its SY query attachment. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangePositionImportFacet.sol` (kept, narrowed) | One responsibility: own `importPosition` only. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeLiquidReserveFacet.sol` (kept, narrowed) | One responsibility: own the seven liquid-reserve selectors (canOpenPoolManagerUnlock, localReserve, deployedReserve, targetLiquidReservePercentage, actualLiquidReservePercentage, rebalanceLiquidReserve, twapOracle). |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol` (kept, narrowed) | One responsibility: host `_exchangeIn` and the in-route money operations. No SY money, no queries. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutTarget.sol` (kept, narrowed) | One responsibility: host `_executeDirectSwapOut`, the OUT zap-out delegate routing, pretransfer/payment logic, and rebalance/poke plumbing. No self-preview. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInQueryTarget.sol` (kept, narrowed) | One responsibility: host the IN transition + external-quote functions only. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutQueryTarget.sol` (kept, narrowed) | One responsibility: host the OUT preview + transition only. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiTarget.sol` (kept) | One responsibility: host `exchangeInManyToOne` only. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiTarget.sol` (kept) | One responsibility: host `exchangeOutOneToMany` only. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiQueryTarget.sol` (kept) | One responsibility: host `previewExchangeInManyToOne` only. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol` (kept) | One responsibility: host `previewExchangeOutOneToMany` only. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangePositionImportTarget.sol` (kept, narrowed) | One responsibility: host the position-import lifecycle (initialize, collect, convert, finalize). |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeLiquidReserveTarget.sol` (kept, narrowed) | One responsibility: host the liquid-reserve percentage read/write and the bounded rebalance orchestration. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol` (kept, narrowed) | One responsibility: host the IN execution primitives: `_previewExchangeIn`, `_quoteZapOutAmount`, `_executeZapOutExactIn(tokenOut, shares, minOut, recipient, holder)`, `_executeFreeZapOutExactIn(...)`, `_executeZapInDeposit(tokenIn, amountIn, minSharesOut, recipient)`. No duplicated OUT quote, no OutBase inheritance. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutBase.sol` (kept, narrowed) | One responsibility: host the OUT execution primitives: `_executeDirectSwapOut(...)`, OUT zap-out primitive (delegated to the OutExecutionDelegate), pretransfer/payment, rebalance orchestration, `_refundExcess`, `_syncVaultReserves`, `_pokeBoundPoolTwap`. Self-preview to `address(this).previewExchangeOut` is replaced with internal quote that reads stored state. No duplicated `_quoteZapOutAmount`. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol` (REPLACED, narrowed) | One responsibility: legacy V4-specific SY hooks for the InFacet only: `_settleNamedHolder(tokenOut, shares, minimum, receiver, holder)` (already an internal call from REQ-V4-01), `_redeemVaultHeld(...)` and `_standardRoute(...)` overrides for the SY share/money shape. Does not import the shared SY aggregate. Does not pull in the full SY preview/rewards/discovery surfaces. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInExecutionDelegate.sol` (kept) | One responsibility: `executeZapInDeposit` (the one CREATE3-routed deposit call from InTarget). No new wrappers added. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutExecutionDelegate.sol` (kept, narrowed) | One responsibility: `executeZapOutWithdrawal` (the CREATE3-routed zap-out call from OutTarget). Removes the self-preview to `address(this).previewExchangeOut` at the current line 88 and replaces it with an internal quote that reads stored state. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4PositionRepo.sol` (kept) | One responsibility: managed-position storage layout (imported flag, tokenId, ticks, salt, authorized PositionManager). |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4PoolKeyAwareRepo.sol` (kept) | One responsibility: pool-key storage layout. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4PoolManagerAwareRepo.sol` (kept) | One responsibility: pool-manager storage layout. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4QuoteService.sol` (kept) | One responsibility: shared pool/quote primitives. |
| `contracts/protocols/dexes/uniswap/v4/IUniswapV4StandardExchangeDFPkg.sol` (kept, interface) | One responsibility: DFPkg interface. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol` (kept, refactored) | One responsibility: facet cuts and constructor wiring. Updated to include the new CallbackFacet. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol` (kept, refactored) | One responsibility: factory-service wiring. |
| `contracts/vaults/standard/sy/NativeStandardYieldErrors.sol` (NEW) | One responsibility: holds the error declarations only (`InvalidSYToken`, `InvalidSYReceiver`, `ZeroSYAmount`, `UnsupportedNativePayment`, `SYMinimumNotMet`). Cross-family mechanical compat; other families import this. |
| `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol` (kept, slimmed) | One responsibility: compatibility aggregate. Imports `NativeStandardYieldErrors`. The legacy V4 family does not import this in the new InBase/InTarget. The legacy V4 InFacet does not import this. |
| `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol` (DELETED) | Was: 5-line import shim. Owner ruling D3. |

## Every installed selector and its one facet owner

The flatten uses the existing fifteen-facet count plus one new dedicated callback facet. The existing facets keep their names; their `facetFuncs()` arrays are rewritten so each facet owns a single group of selectors and no other facet duplicates those selectors. The DFPkg interface is updated to include the new callback facet.

| Selector | Owner facet (single, no duplication) |
|---|---|
| `exchangeIn` | `UniswapV4StandardExchangeInFacet` |
| `unlockCallback` | `UniswapV4StandardExchangeCallbackFacet` (NEW, dedicated) |
| `exchangeOut` | `UniswapV4StandardExchangeOutFacet` |
| `exchangeInManyToOne` | `UniswapV4StandardExchangeInMultiFacet` |
| `exchangeOutOneToMany` | `UniswapV4StandardExchangeOutMultiFacet` |
| `previewExchangeIn` | `UniswapV4StandardExchangeInQueryFacet` |
| `previewExchangeOut` | `UniswapV4StandardExchangeOutQueryFacet` |
| `previewExchangeInManyToOne` | `UniswapV4StandardExchangeInMultiQueryFacet` |
| `previewExchangeOutOneToMany` | `UniswapV4StandardExchangeOutMultiQueryFacet` |
| `quoteState` | `UniswapV4StandardExchangeOutQueryFacet` |
| `quoteAssets` | `UniswapV4StandardExchangeInQueryFacet` |
| `quoteShareBalance` | `UniswapV4StandardExchangeInQueryFacet` |
| `quoteTransition` | `UniswapV4StandardExchangeInQueryFacet` |
| `quoteExternalExchange` | `UniswapV4StandardExchangeInQueryFacet` |
| `quoteTotalSupply` | `UniswapV4StandardExchangeInQueryFacet` |
| `quoteExternalDeposit` | `UniswapV4StandardExchangeInQueryFacet` |
| `importPosition` | `UniswapV4StandardExchangePositionImportFacet` |
| `canOpenPoolManagerUnlock` | `UniswapV4StandardExchangeLiquidReserveFacet` |
| `localReserve` | `UniswapV4StandardExchangeLiquidReserveFacet` |
| `deployedReserve` | `UniswapV4StandardExchangeLiquidReserveFacet` |
| `targetLiquidReservePercentage` | `UniswapV4StandardExchangeLiquidReserveFacet` |
| `actualLiquidReservePercentage` | `UniswapV4StandardExchangeLiquidReserveFacet` |
| `rebalanceLiquidReserve` | `UniswapV4StandardExchangeLiquidReserveFacet` |
| `twapOracle` | `UniswapV4StandardExchangeLiquidReserveFacet` |
| `deposit` (SY) | `UniswapV4StandardExchangeInFacet` (SY money surface) |
| `redeem` (SY) | `UniswapV4StandardExchangeInFacet` (SY money surface) |
| `rewardIndexesCurrent` (SY) | `UniswapV4StandardExchangeInFacet` (SY money surface) |
| `claimRewards` (SY) | `UniswapV4StandardExchangeInFacet` (SY money surface) |
| `previewDeposit` (SY) | `UniswapV4StandardExchangeInQueryFacet` (SY preview surface) |
| `previewRedeem` (SY) | `UniswapV4StandardExchangeInQueryFacet` (SY preview surface) |
| `exchangeRate` (SY) | `UniswapV4StandardExchangeInQueryFacet` (SY discovery surface) |
| `yieldToken` (SY) | `UniswapV4StandardExchangeInQueryFacet` (SY discovery surface) |
| `assetInfo` (SY) | `UniswapV4StandardExchangeInQueryFacet` (SY discovery surface) |
| `getTokensIn` (SY) | `UniswapV4StandardExchangeInQueryFacet` (SY discovery surface) |
| `getTokensOut` (SY) | `UniswapV4StandardExchangeInQueryFacet` (SY discovery surface) |
| `isValidTokenIn` (SY) | `UniswapV4StandardExchangeInQueryFacet` (SY discovery surface) |
| `isValidTokenOut` (SY) | `UniswapV4StandardExchangeInQueryFacet` (SY discovery surface) |
| `getRewardTokens` (SY) | `UniswapV4StandardExchangeInQueryFacet` (SY discovery surface) |
| `accruedRewards` (SY) | `UniswapV4StandardExchangeInQueryFacet` (SY discovery surface) |
| `rewardIndexesStored` (SY) | `UniswapV4StandardExchangeInQueryFacet` (SY discovery surface) |

The OutFacet does not own any SY selectors. The OutFacet owns only `exchangeOut`. The OutQueryFacet owns the two OUT queries (`previewExchangeOut`, `quoteState`). SY rewards and SY preview/discovery on the OUT side are not in the supported Pendle SY surface; the legacy V4 vault's native SY only has the In-side SY surface (deposit, redeem, rewards) plus In-side queries (transition, external). The Out-side surface is SE-only. This matches the current Pendle SY contract (`IStandardizedYield`) which exposes the money surface without a separate Out-side.

The InMulti and OutMulti facets own their own money selectors (`exchangeInManyToOne` and `exchangeOutOneToMany`) plus the SY money attachment on their side. The InMultiQuery and OutMultiQuery facets own their own preview selectors.

Each facet's `facetFuncs()` array returns exactly the selectors in the table above for that facet. No selector appears in two facets' `facetFuncs()`. The DFPkg's `facetCuts()` array updates to include the new `UniswapV4StandardExchangeCallbackFacet` and to map each selector to its single owner.

## Keep / Move / Delete list

### KEEP (refactored, narrower)

- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol` (narrowed `facetFuncs`; narrowed inheritance)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutFacet.sol` (narrowed `facetFuncs`; narrowed inheritance)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInQueryFacet.sol` (narrowed `facetFuncs`; narrowed inheritance)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutQueryFacet.sol` (narrowed `facetFuncs`; narrowed inheritance)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiFacet.sol` (narrowed)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiFacet.sol` (narrowed)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiQueryFacet.sol` (narrowed)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet.sol` (narrowed)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangePositionImportFacet.sol` (narrowed)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeLiquidReserveFacet.sol` (narrowed)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol` (narrowed; `_exchangeIn` only; pulls in narrowed InBase + narrowed legacy V4 SY hooks; pulls in `UniswapV4StandardYieldExecutionTarget` (new narrow file, not the deleted shim); pulls in `StandardExchangeInExecutionBase` for the four-arg SE surface)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutTarget.sol` (narrowed; `_executeDirectSwapOut`, the OUT zap-out delegate routing, pretransfer/payment, rebalance/poke; self-preview removed; pulls in narrowed OutBase)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInQueryTarget.sol` (narrowed; IN transition + external-quote only)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutQueryTarget.sol` (narrowed; OUT preview + transition only)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiTarget.sol` (unchanged)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiTarget.sol` (unchanged)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiQueryTarget.sol` (unchanged)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol` (unchanged)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangePositionImportTarget.sol` (narrowed)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeLiquidReserveTarget.sol` (narrowed)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol` (narrowed; IN primitives only; the duplicated `_quoteZapOutAmount` is removed from this file and moved to a shared Service)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutBase.sol` (narrowed; OUT primitives only; `_quoteZapOutAmount` is removed from this file and moved to a shared Service; self-preview removed)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInExecutionDelegate.sol` (kept; `executeZapInDeposit` only; no new wrappers; the `SELF` immutable and `DelegateCallRequired` error remain)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutExecutionDelegate.sol` (kept, narrowed; `executeZapOutWithdrawal` only; self-preview removed and replaced with an internal quote that reads stored state)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4PositionRepo.sol`
- `contracts/protocols/dexes/uniswap/v4/UniswapV4PoolKeyAwareRepo.sol`
- `contracts/protocols/dexes/uniswap/v4/UniswapV4PoolManagerAwareRepo.sol`
- `contracts/protocols/dexes/uniswap/v4/UniswapV4QuoteService.sol`
- `contracts/protocols/dexes/uniswap/v4/IUniswapV4StandardExchangeDFPkg.sol` (interface; updated to include the new callback facet field)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol` (facet cuts updated; constructor updated to wire the new callback facet)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol` (factory wiring updated)
- `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol` (kept, slimmed; imports `NativeStandardYieldErrors` for the error declarations; this is the compatibility aggregate for V3/hookless/Pons)

### MOVE (slim down, replace broad inheritance with narrow)

- The `UniswapV4StandardYieldExecutionTarget` (the file at `contracts/protocols/dexes/uniswap/v4/`) is REPLACED, not moved. The new file at the same path is the legacy V4-specific narrow hook for the InFacet only (the `_settleNamedHolder`, `_redeemVaultHeld`, and `_standardRoute` overrides for the legacy V4 SY shape). It does not import the shared SY aggregate, the shared SY execution, the shared SY preview, or the shared SY rewards/discovery.

### DELETE

- `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol` (the 5-line import shim). Owner ruling D3.
- The 5-argument `executeNamedHolderRedemption` and the 4-argument `executeZapOutExactIn` in `UniswapV4StandardExchangeInExecutionDelegate.sol` (already deleted in the REQ-V4-01 work; this design keeps that state).
- The `_executeZapOutExactIn` 4-argument wrapper with `address(this)` in `UniswapV4StandardExchangeOutExecutionDelegate.sol` (the inner 4-arg wrapper that did the pre-REQ-V4-01 work; the new outer `executeZapOutWithdrawal` replaces it with the holder argument and the new direct internal call).
- The duplicated `_quoteZapOutAmount` in `UniswapV4StandardExchangeOutBase.sol` (removed and moved to a shared Service).
- The `_settleNamedHolder` assembly-revert pattern and the manual revert bubbling in the legacy V4 yield target (already replaced in the REQ-V4-01 work).
- The self-preview call `IStandardExchangeOut(address(this)).previewExchangeOut(...)` in `UniswapV4StandardExchangeOutExecutionDelegate.sol:88,94` (replaced with an internal quote that reads stored state).
- The broad inheritance chain that pulls the full SY surface into the InFacet: the new InBase does not import the shared SY aggregate. The new `UniswapV4StandardYieldExecutionTarget` (legacy V4 narrow file) does not pull in the shared SY preview/rewards/discovery.

### ADD (new files)

- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCallbackFacet.sol` (NEW; one responsibility: own `unlockCallback`)
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCallbackTarget.sol` (NEW; one responsibility: `_unlockCallback` plus the underlying unlock-and-decode plumbing)
- `contracts/vaults/standard/sy/NativeStandardYieldErrors.sol` (NEW; one responsibility: hold the error declarations only)

The shared `_quoteZapOutAmount` is moved to a new Service library, not a new file under the protocol's directory. This is a re-arrangement, not a new component. The implementer can co-locate the Service with the existing `UniswapV4QuoteService.sol` or in a new `UniswapV4StandardExchangeQuoteService.sol` if the existing one is shared. The Service is internal, not a facet.

## Resolving the draft's deferrals

This design closes the deferrals the draft leaves to the implementation plan. The implementer is told:

- Which file replaces the broad `UniswapV4StandardExchangeCommon` (the narrowed `InBase` and `OutBase`, and the new narrow `UniswapV4StandardYieldExecutionTarget` for legacy V4 SY hooks).
- Which selectors go on which facets (the table above; each facet's `facetFuncs()` is exactly the list in the row for that facet).
- Which validations to consolidate (none across families; the REQ-V4-02 disable check is included in the legacy V4 direct yield path; the rest of the validation list is preserved at the same call sites; no blanket consolidation is proposed).
- Which unused legacy zap helpers to remove (the duplicated `_quoteZapOutAmount` is removed; the self-preview in the OutExecutionDelegate is removed; the REQ-V4-01 wrappers are already removed).
- The selector-to-facet table is the table above. It is not deferred.

## Measurement and acceptance gate

- After the edit, measure each facet's runtime. Hard limit 24,576 bytes. Design target 23,000 bytes.
- A target miss below the hard limit is recorded as a gap, not a failure.
- A facet exceeding the hard limit blocks completion.
- The OUT self-call (`IStandardExchangeOut(address(this)).previewExchangeOut`) is removed. The placeholder for that call is the internal quote that reads stored state.
- The IN delegation `executeZapInDeposit` stays (one CREATE3 hop for the deposit) and the OUT delegation `executeZapOutWithdrawal` stays (one CREATE3 hop for the zap-out). No new execution delegates.
- REQ-V4-02 disable check is applied on the legacy V4 direct yield path, consistently with the recorded acceptance criteria at `apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:88-91`.

I did not run Forge.