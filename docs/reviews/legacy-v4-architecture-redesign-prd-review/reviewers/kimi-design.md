# Kimi K3 — design pass: flattened legacy V4 Standard Exchange

- **Label:** Replacement-session design pass, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No reviewers' notes were read. No code, draft, or PRD was edited.
- **Date:** 2026-10-14.
- **Controlling direction:** `contracts/protocols/dexes/uniswap/v4/legacy-v4-standard-exchange-architecture-redesign.md`, with the owner's rulings treated as controlling: remove the shared SY import shim with mechanical-only changes for other families; one dedicated callback facet and no replacement execution delegate; fresh-package storage only; 24,576-byte hard limit with 23,000 advisory; preserve supported SE/SY behavior, the full-range managed book, and the funded sleeve; include the REQ-V4-02 disable check; unexpected rebalance failures propagate; V3 FullSpread, hookless, and Pons are not redesigned.
- **Method:** every file under `contracts/protocols/dexes/uniswap/v4/` was inventoried; the package cuts and each facet's `facetFuncs` were read; the Common's sections and both delegates' bodies were read. No new economics is introduced anywhere below; where a rule restates current behavior it is marked (current), and where it restates a recorded correction it is marked (REQ-V4-02) or (D8).
- I did not run Forge.

## 1. Current inventory (verified reads)

**Package cuts (15 total, `UniswapV4StandardExchangeDFPkg.sol:170-171`):** five shared facets — `ERC20Facet`, `ERC5267Facet`, `ERC2612Facet`, `MultiAssetBasicVaultFacet`, `MultiAssetStandardVaultFacet` — and ten family facets:

| Current facet | Current selectors (read from its `facetFuncs`) |
| --- | --- |
| InFacet | `exchangeIn`, `unlockCallback`, + SY execution (`deposit`, `redeem`, `rewardIndexesCurrent`, `claimRewards` via `_appendExecution`) |
| InQueryFacet | `quoteTotalSupply`, `quoteShareBalance`, `quoteAssets`, `quoteTransition`, `quoteExternalExchange`, `quoteExternalDeposit` |
| PositionImportFacet | `importPosition` |
| OutFacet | `exchangeOut` |
| OutQueryFacet | `previewExchangeOut`, `quoteState` |
| LiquidReserveFacet | `canOpenPoolManagerUnlock`, `localReserve`, `deployedReserve`, `targetLiquidReservePercentage`, `actualLiquidReservePercentage`, `rebalanceLiquidReserve`, `twapOracle` |
| InMultiFacet | `exchangeInManyToOne` |
| InMultiQueryFacet | `previewExchangeInManyToOne`, `previewExchangeIn` |
| OutMultiFacet | `exchangeOutOneToMany` |
| OutMultiQueryFacet | `previewExchangeOutOneToMany` + 12 SY query selectors (`exchangeRate`, `yieldToken`, `assetInfo`, `getTokensIn`, `getTokensOut`, `isValidTokenIn`, `isValidTokenOut`, `previewDeposit`, `previewRedeem`, `getRewardTokens`, `accruedRewards`, `rewardIndexesStored` via `_appendQuery`) |

**Structure verified this pass:** `UniswapV4StandardExchangeCommon.sol` (1,335 lines) carries configuration accessors, disable/unlock gates, TWAP, reserve reads/writes, inventory/transition-quote math (`:97-235`), position planning (`:445-565`), rebalance (`:722-941`), import maintenance (`:849-982`), the unlock callback and PoolManager execution primitives (`:984-1106`), swap-quote wrappers (`:1108-1139`), and custody helpers (`:1140-1335`). `InBase` and `OutBase` duplicate `_quoteZapOutAmount` (`InBase.sol:129`, `OutBase.sol:89`). `UniswapV4StandardExchangeOutTarget.sol` is a 14-line unused combiner (no facet inherits it). `UniswapV4StandardExchangeOutExecuteTarget.sol:51` self-calls `previewExchangeOut`; `UniswapV4StandardExchangeOutExecutionDelegate.sol:88,94` self-call public previews; `UniswapV4StandardExchangeInExecutionDelegate.sol` now holds only `executeZapInDeposit` (`:12-17`). `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol` is a 5-line import shim. The shared SY errors live on the compatibility aggregate (`NativeStandardYieldTarget.sol:89-95`).

## 2. Successor components (paths, one responsibility each, consumers named)

All new files live under `contracts/protocols/dexes/uniswap/v4/`. They are internal-function libraries in the pattern of the existing `UniswapV4QuoteService.sol` — no new inheritance bases, no linked public libraries, no delegate. Inlining per consumer is accepted; size is measured per facet, not assumed (draft `:149`).

| Component (new file) | One responsibility | Contents (moved from) | Consumers |
| --- | --- | --- | --- |
| `UniswapV4SeConfig.sol` | Configuration and policy gates | Pool key/currency/token accessors, `_erc20Face`, WETH face, `_twapOracle`/`_pokeBoundPoolTwap`, `_requireNotDisabled`, `canOpenPoolManagerUnlock`/`_requireCanOpenPoolManagerUnlock`, and the single internal token-validity predicate `_isConfiguredPairToken(address)` (Common `:303-415`, `:369-373`; draft req 3) | Every family facet |
| `UniswapV4SeInventory.sol` | The book | `_freeBalances`, `_deployedAmounts`, `_totalVaultReserves`, `_freeBalancesForShareMath`, `_syncVaultReserves`, share math (`_sharesOutForDeposit`, `_initialResidualShares`, `_quoteInitialShares`), `_collectablePositionFees`, `_deployedFaceOf`, inventory snapshot/compose helpers for transition quotes (Common `:97-235`, `:320-333`, `:593-635`; `InBase` reserve sections) | Settlement, Quotes, TransitionQuery, LiquidReserve, SY surfaces |
| `UniswapV4SePoolOps.sol` | PoolManager primitives inside the unlock | OperationParams decode/dispatch, `_executeUnlock` initiation, `_executeSwap`, `_executeAddLiquidity`, `_executeRemoveLiquidity`, `_settleSwapDelta`, `_settleModifyLiquidityDelta`, `_settleCurrency`/`_takeCurrency` incl. native ETH/WETH wrap (Common `:664-672`, `:984-1106`) | CallbackFacet owns decode/dispatch; In/Out/LiquidReserve/Import facets use only the initiation helper |
| `UniswapV4SePosition.sol` | The managed full-range position | `_managedTicks`, `_managedLiquidityPlan(+AtState)`, `_managedLiquidityBudgets`, `_setCenterPlan`, `_createManagedPositionsIfNeededCommon`, `_burnManagedLiquidityFraction`, `_quoteManagedWithdrawal`, `_quotePositionWithdrawal`, `_currentLiquidity`, `_positionInfo`, `_positionAmounts`, `_amountsForLiquidityAtPrice`, `_collectManagedFeesIfIdle` (Common `:415-635`, `:914-949`) | Settlement, Quotes, Import, LiquidReserve |
| `UniswapV4SeQuotes.sol` | Route/exit quote composition | One consolidated `_quoteZapOutAmount` (deduplicating `InBase:129` and `OutBase:89`), `_quoteSwapAfterWithdrawal`, zap-in previews, dual-exit quote, direct swap quotes — all over the kept `UniswapV4QuoteService.sol` (Common `:1108-1139`; `InBase`/`OutBase` preview functions; `InQueryTarget`/`OutQueryTarget` previews) | Query facets, Settlement, TransitionQuery, SY previews |
| `UniswapV4SeSettlement.sol` | Money movement and custody with explicit roles | `_secureTokenTransfer`, `_secureShareDelivery` (pull/credit semantics unchanged, current), `_refundExcess`, `_refundUnusedShares`, `_transferCurrency`, direct swap in/out, zap-in single/dual deposits, holder-parameterized zap-out exact-in (current post-REQ-V4-01 shape), zap-out withdrawal, dual-exit payment; every operation takes explicit `payer`/`holder`/`receiver` arguments (draft req 2). No `exchangeIn`/`previewExchange*` self-call anywhere; the OUT self-preview at `OutExecuteTarget:51` and delegate self-previews at `OutExecutionDelegate:88,94` become internal `UniswapV4SeQuotes` calls | InFacet, OutFacet, ImportFacet |
| `UniswapV4SeRebalance.sol` | Sleeve policy and execution | Target/floor/deadband reads, the bounded deploy-excess/refill-deficit adjustment, post-operation rebalance hook. (D8): "best effort" is a precomputed bounded no-op-capable adjustment; unexpected external protocol failures propagate — no catch around PoolManager calls, and comments promising swallowed failures are removed (Common `:333-369`, `:722-941`) | LiquidReserveFacet, Settlement post-op hooks |
| `UniswapV4SeImport.sol` | NFT intake and conversion | Authorization (PositionManager, NFT owner), matching-pool validation, deadline/minimum, decrease/collect of the imported NFT, conversion into the managed book, custody disposition (PositionImportTarget `:27-106`; Common `:951-982` decrease/collect only) | ImportFacet only |

## 3. Facet partition and selector ownership (frozen)

Nine family facets (one new, two split, two dissolved by merge) plus the five unchanged shared facets; 14 package cuts. Each selector has exactly one owner; no selector keeps a compatibility alias. Shared facets' selector sets are those facets' existing `facetFuncs`, unchanged, and are not this family's surface.

| New facet (file under `…/uniswap/v4/`, `UniswapV4Se*Facet.sol` naming) | Owned selectors | Responsibility |
| --- | --- | --- |
| `UniswapV4SeCallbackFacet` (new) | `IUnlockCallback.unlockCallback` | The sole PoolManager unlock callback: validates the protocol caller, decodes OperationParams, dispatches to `UniswapV4SePoolOps` settlement |
| `UniswapV4SeInFacet` | `IStandardExchangeIn.exchangeIn`; `IStandardExchangeInMulti.exchangeInManyToOne`; SY `deposit`, `redeem`, `rewardIndexesCurrent`, `claimRewards` | All value entry and exact-in exit: direct swap-in, zap-in single/dual, share redemption, SY money. `_requireNotDisabled` on every money route (current `InTarget:55` policy) including the SY paths (REQ-V4-02). SY entries are explicit operations, not `_standardRoute(bool)` |
| `UniswapV4SeOutFacet` | `IStandardExchangeOut.exchangeOut`; `IStandardExchangeOutMulti.exchangeOutOneToMany` | All exact-output exits: direct swap-out, zap-out withdrawal, dual exit — via `UniswapV4SeSettlement` internal calls, no OUT delegate hop, no self-preview |
| `UniswapV4SeInQueryFacet` | `IStandardExchangeIn.previewExchangeIn`; `IStandardExchangeInMulti.previewExchangeInManyToOne`; `IStandardExchangeExternalQuote.quoteExternalDeposit`; `IStandardExchangeExternalQuote.quoteExternalExchange` | Inbound previews and external-math quotes |
| `UniswapV4SeOutQueryFacet` | `IStandardExchangeOut.previewExchangeOut`; `IStandardExchangeOutMulti.previewExchangeOutOneToMany` | Outbound previews |
| `UniswapV4SeTransitionQueryFacet` (split from InQuery/OutQuery) | `IStandardExchangeTransitionQuote.quoteState`, `quoteTotalSupply`, `quoteShareBalance`, `quoteAssets`, `quoteTransition` | Snapshot production and simulated-state quotes only; simulation state never writes persistent storage (draft req 5) |
| `UniswapV4SeSyQueryFacet` (split from OutMultiQuery) | the 12 SY discovery/preview selectors: `exchangeRate`, `yieldToken`, `assetInfo`, `getTokensIn`, `getTokensOut`, `isValidTokenIn`, `isValidTokenOut`, `previewDeposit`, `previewRedeem`, `getRewardTokens`, `accruedRewards`, `rewardIndexesStored` | Pendle SY read surface; the public `isValidTokenIn/Out` wrap the Config predicate and are never consumed by execution (draft req 3) |
| `UniswapV4SeImportFacet` (renamed from PositionImportFacet) | `IUniswapV4StandardExchangePositionImport.importPosition` | NFT intake/conversion; no ongoing imported-position maintenance |
| `UniswapV4SeLiquidReserveFacet` (unchanged surface) | the 7 `IUniswapV4StandardExchangeLiquidReserve` selectors | Sleeve views and the permissionless bounded rebalance |

Facet bodies are thin: validate the call (via Config), invoke the responsible library operation, enforce the result, emit the existing events. No facet inherits another facet's target; no query facet inherits an execution surface; SY query and SY money no longer share an aggregate on this family.

## 4. Keep / move / delete list (file granularity)

**Keep unchanged:**
- `UniswapV4PoolKeyAwareRepo.sol`, `UniswapV4PoolManagerAwareRepo.sol`, `UniswapV4PositionRepo.sol` — storage layouts intact. Imported-position custody fields remain as the custody record of the emptied NFT; their growth write paths disappear with the deleted maintenance functions. Each field's remaining reader/writer is documented in the implementation evidence (draft req 6). No shared-field change (fresh-package storage rule).
- `UniswapV4QuoteService.sol`; `interfaces/IUniswapV4StandardExchangeLiquidReserve.sol`.
- Shared SY components in `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol` — the Money/Preview/Discovery/Rewards targets stay; other families' behavior is unchanged.

**Move (content relocates; the file dissolves):**
- `UniswapV4StandardExchangeCommon.sol` → Config / Inventory / PoolOps / Position / Quotes / Settlement / Rebalance / Import per section 2. The name `UniswapV4StandardExchangeCommon` does not survive as a base.
- `UniswapV4StandardExchangeInBase.sol`, `UniswapV4StandardExchangeOutBase.sol` → Settlement / Quotes; the `_quoteZapOutAmount` duplication collapses to the single Quotes copy.
- All current Target files (`InTarget`, `OutExecuteTarget`, `OutMultiTarget`, `InMultiTarget`, `PositionImportTarget`, `LiquidReserveTarget`, `InQueryTarget`, `OutQueryTarget`, `InMultiQueryTarget`, `OutMultiQueryTarget`, `UniswapV4StandardYieldExecutionTarget`) → their external functions become the thin facet methods of section 3. `NativeStandardYieldQuoteBase`'s `_previewExchangeIn` hook is implemented inside the InQuery/SyQuery facets via the Quotes library.
- Facet files → recreated for the section-3 set; `InMultiFacet`, `OutMultiFacet`, `InMultiQueryFacet`, `OutMultiQueryFacet` dissolve; `UniswapV4SeCallbackFacet`, `UniswapV4SeTransitionQueryFacet`, `UniswapV4SeSyQueryFacet` are new.
- `UniswapV4StandardExchangeDFPkg.sol` + `IUniswapV4StandardExchangeDFPkg.sol` → regenerated for the 14-cut package; PkgArgs behavior preserved.
- `UniswapV4_Component_FactoryService.sol` → deployers for the new facet set; delegate deployers and delegate constructor wiring removed.
- `contracts/protocols/dexes/uniswap/v4/test/` TestBase → updated to the new FactoryService/package shape; production-proxy deployment path unchanged.

**Delete:**
- `UniswapV4StandardExchangeInExecutionDelegate.sol` and `UniswapV4StandardExchangeOutExecutionDelegate.sol` — both execution delegates, with their factory wiring (owner ruling: no replacement execution delegate; the deposit zap-in currently on the IN delegate moves into `UniswapV4SeSettlement` as an internal operation).
- `UniswapV4StandardExchangeOutTarget.sol` — unused combiner (verify zero importers at implementation; today: none).
- `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol` — the import shim. Every consumer's import is repointed at `NativeStandardYieldTarget.sol`; that is the only change other families receive, verified by their existing suites compiling and passing unchanged.
- The `NativeStandardYieldTarget` compatibility aggregate contract (after the error move below); its content already lives in the Money/Preview halves.
- The imported-position maintenance functions `_deployExcessImported`, `_increaseImportedPositionCommon`, `_increaseImportedPosition` (Common `:849-868`, `:951-969`; `InBase:399-401`). The import's decrease/collect operation is preserved inside `UniswapV4SeImport.sol`.
- The self-preview/self-call sites: `OutExecuteTarget.sol:51`, `OutExecutionDelegate.sol:88,94` — replaced by internal Quotes calls; a final grep for `address(this))` typed calls in the family is part of done-when.

**Error namespace move (shared SY, mechanical):** new `contracts/vaults/standard/sy/NativeStandardYieldErrors.sol` holds `InvalidSYToken`, `InvalidSYReceiver`, `ZeroSYAmount`, `UnsupportedNativePayment`, `SYMinimumNotMet` with identical signatures. References are repointed (e.g., `NativeStandardYieldTarget.InvalidSYToken` → `NativeStandardYieldErrors.InvalidSYToken`). No error signature, selector, or behavior changes; other families get this mechanical edit only.

## 5. Behavior pins (no new economics)

1. Current SE route set, directions, credit/refund rules, and events are preserved exactly (draft reqs 1, 7): pull measures the transfer; true-flag credit is bounded to the current operation; exact-out false-flag pulls the quoted input; booked reserves are never caller credit; code-less pretransfer callers revert `EOAPretransferNotAllowed`; the holder is explicit (`address(this)` vault-held, caller otherwise); no self-call infers identity anywhere.
2. The full-range managed book and funded sleeve are preserved: complete-book accounting counts sleeve + deployed + earned fees once; share pricing, activation minimums, and initial residual-share treatment are unchanged; FoT/rebasing underlyings remain forbidden; 18-decimal shares, PoolKey ordering, and the WETH face are preserved.
3. (REQ-V4-02) The SY `deposit`/`redeem` entries and every `exchangeIn`/`exchangeOut` money route call `_requireNotDisabled()` before movement. This is the legacy family's existing unconditional policy extended to the SY path — not the FullSpread exemption.
4. (D8) Rebalance is the precomputed bounded adjustment: insufficient deployable ratio, rounding, or deadband produce a no-op; unexpected external failures propagate atomically; no catch-and-book, no self-call boundary, no arbitrary executor.
5. Lock-state semantics are preserved: idle vs unlocked contexts stay distinct; no nested unlock; the callback validates its caller; blocked deposits stay funded in the sleeve; blocked exits pay only from sufficient local inventory.
6. Import converts and ends: a successful import leaves no active imported NFT backing normal operations; the emptied NFT's custody disposition is unchanged; no recovery rights or migration protocol are added.

## 6. Size gate

Measure every family facet's deployed runtime after each material step and at completion, with compiler settings recorded (Forge 1.5.1, solc 0.8.35, optimizer on, one run, `via_ir = false`). Hard gate: 24,576 bytes each. Advisory target: 23,000 bytes; a miss below the hard limit is recorded, not a failure; exceeding the hard limit stops completion and is reported — no self-call, delegate hop, via_ir, or functionality removal may be used to pass. No size reduction is assumed from file deletion, visibility changes, or library inlining; only measurements count. The size mechanism expected (but not assumed): pool-execution primitives land once on the callback facet; each money facet carries only the settlement paths its routes invoke.

## 7. Validation anchors

Reuse and extend the existing suites under `test/foundry/spec/protocol/dexes/uniswap/v4/` — the vault-held redeem suite, the full-range book suite (including its facet-size assertion), the local liquid buffer suite, and the `adversarial/` and `decimals/` variants — retargeted to the new package wiring through the updated TestBase. Add the draft's required-matrix rows as they map onto the flattened boundaries (selector/loupe coverage per facet; SY consumer compile-and-pass checks for the mechanical shared-SY edits; import lifecycle across callbacks). Tests exercise the production proxy through the registry path; no mocks; `scripts/forge-artifacts.py` refresh before runs; commands and measured sizes are reported.

## 8. Non-goals restated

No V3 FullSpread, hookless, or Pons change (their same-named wrappers/delegates are untouched). No DETF or hook-package change. No Pendle interface change, no new public holder-selecting endpoint, no substitute delegate or trampoline, no token allowlist, no live-instance migration or deployment, no storage-compat claim for existing instances. No behavior change beyond the recorded REQ-V4-02 and D8 items.

I did not run Forge.
