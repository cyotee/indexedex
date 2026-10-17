# Astra independent plan draft — selected legacy V4 redesign

**Date:** 2026-10-15. **Status:** Draft instructions for a separately authorized implementation session. This report does not implement or authorize the redesign.

**Controlling document:** `docs/reviews/legacy-v4-architecture-redesign-prd-review/REDESIGN_PRD.md`, re-read in full. Its selected design overrides my earlier alternatives: sixteen package cuts, no new local-credit slot, and the existing pretransfer calculation retained. No peer notes or consolidated implementation plan were read.

## 1. Fixed scope and source evidence

Use `V4/` below for `contracts/protocols/dexes/uniswap/v4/`; use `T4/` for `test/foundry/spec/protocol/dexes/uniswap/v4/`.

Current spot-checks establish the dependencies that determine ordering:

- `UniswapV4StandardExchangeInTarget.sol:29-37,72-98` inherits InBase and still dispatches deposits to the IN delegate. Its public share exit at 79-83 already uses internal settlement and the vault holder.
- `UniswapV4StandardYieldExecutionTarget.sol:7,11-30` inherits InTarget plus the shared SY execution adapter. It already chooses the two yield holders correctly and performs its post-settlement TWAP poke.
- `UniswapV4StandardExchangeOutExecuteTarget.sol:49-63,105-122` still self-previews and delegates withdrawals.
- Common's function inventory places configuration, inventory/math, custody, PoolManager settlement, import maintenance, and rebalance in the same source. Those responsibilities must move before Common and its inheriting bases are removed.
- `IUniswapV4StandardExchangeDFPkg.sol:22-44` and `UniswapV4_Component_FactoryService.sol:192-232` encode current facet initialization fields. Adding a callback field must be coordinated across both and every construction site.
- `UniswapV4StandardExchangeVaultHeldRedeem.t.sol:24,174` imports InBase and references its slippage error. Deleting InBase requires a mechanical test import/error-namespace migration, not weakening the error expectation.

The only new production component paths are the six libraries, callback target/facet, and shared error file already selected by the PRD. Keep existing family target/facet paths for the other owners. Do not create substitute execution libraries with public/external functions.

## 2. Fixed move map and library dependency order

Create these files under `V4/internal/` in the following order. All callable library functions are `internal`; qualified library calls execute in the calling proxy's context, without another message or delegatecall.

| Order / destination | Exact source responsibility to move |
|---|---|
| 1. `UniswapV4StandardExchangeConfig.sol` | Common configuration accessors, currency-to-face mapping, `_requireNotDisabled`, manager-idle predicate/gate, TWAP address/poke, live policy inputs, symbol fallback and token/dual-array validation. Add the one `_isConfiguredPairToken(address)` predicate using configured ERC-20 faces. House moved legacy-family error/event/type declarations here so deleted bases are not retained as declaration namespaces. Preserve signatures and existing encoded operation/snapshot field layouts. |
| 2. `UniswapV4StandardExchangeAccounting.sol` | Common live free/deployed/fee reads, position information and exact liquidity/token conversions, complete-book snapshots/sync, share/initial-residual math, quote wrappers and all `_inventory*` simulated-state operations; InBase/OutBase previews and their duplicate `_quoteZapOutAmount` collapse to one implementation. Move the current transition decoding/validation and projected deposit/rebalance math from InQueryTarget here. Pure target/deadband/fraction calculations shared by simulation and actual rebalance reside here; Config supplies live policy inputs. |
| 3. `UniswapV4StandardExchangeCustody.sol` | Common `_secureTokenTransfer`, `_secureShareDelivery`, `_transferCurrency`, `_refundUnusedShares`, and current OUT refund logic. Keep the current stored-total-minus-live-deployed calculation, including `_deployedFaceOf` implemented using Accounting's deployed reads. Use existing ERC20Repo operations for own shares, not self-calls. Preserve caller/holder, allowance, pretransfer, and refund behavior; no new credit ledger. |
| 4. `UniswapV4StandardExchangePoolOps.sol` | Common typed unlock initiation, swap/add/remove operations and delta/currency settlement; managed fee collection/position operations; InBase single/dual funded deposit and named-holder redemption bodies; OutExecutionDelegate withdrawal body and OutMultiTarget's payout primitives; direct swap settlement from InBase/OutExecuteTarget. These bodies call Config, Accounting, and Custody. Do not put a public entrypoint or a lock on library functions. |
| 5. `UniswapV4StandardExchangeReserve.sol` | Common's bounded actual deploy/refill/second-deploy orchestration, rebalance snapshot/event handling, and idle-only automatic rebalance. Call Accounting for targets/rounding and PoolOps for real manager operations. Remove ongoing imported-position growth/refill branches. Preserve no-swap policy and propagate unexpected protocol failures. |
| 6. `UniswapV4StandardExchangeImport.sol` | PositionImportTarget's authorization, pool/deadline/minimum checks, actual-proceeds accounting and conversion lifecycle; Common's imported decrease/collect primitive. Preserve NFT custody and temporary-state reader behavior. Call PoolOps and Reserve for managed conversion; do not restore imported growth or approval setup. |

**Dependency rule:** Config has no execution dependency; Accounting may use Config, existing repos and canonical read/quote math; Custody may use Config/Accounting; PoolOps may use those three but not Reserve or Import; Reserve may use PoolOps; Import may use all five. No new circular orchestration is introduced.

To maintain that order, lift automatic rebalance call sites currently nested in PoolOps-bound deposit/redemption/swap bodies into their existing target orchestration at the same logical point relative to payout, synchronization, and TWAP. Do not append rebalance indiscriminately to blocked paths or reorder it ahead of funding/limits. The moved settlement core remains single-source; targets perform only their route's existing completion sequence.

The phrase “used inside the unlock” does not force all PoolOps functions to run inside a manager callback. Only actual swap/modifyLiquidity/delta-settlement primitives do so. Funded deposit/redemption orchestration executes outside that callback; blocked deposits still remain in the sleeve and supported blocked exits settle locally. Nested unlocks remain prohibited.

Keep `UniswapV4QuoteService.sol` and the canonical Crane math. No alternate NAV formula, hook-fee treatment, quote iteration rule, or rounding convention is selected by this relocation.

## 3. Ordered implementation stages

### Stage A — establish destinations without breaking existing consumers

1. Read repository implementation rules and record the starting working-tree changes without resetting unrelated work.
2. Create the six internal libraries according to section 2. At this stage the old sources remain so existing consumers still compile; temporary copies are staging only, not final second engines.
3. Create `contracts/vaults/standard/sy/NativeStandardYieldErrors.sol` as an abstract error-only declaration carrying exactly the five existing SY errors and signatures. Preserve `NativeStandardYieldTarget.sol` and its behavioral aggregate for other families. Move its error declarations into the new declaration and inherit it so existing compatible error namespaces remain available. Any mechanical source-reference adjustment must retain exactly the same selector/signature, not alter a test expectation's meaning.
4. Repoint imports of the five-line shared execution shim to the actual execution declaration in `NativeStandardYieldTarget.sol` before deleting the shim. Other-family redemption implementations, modifiers and route behavior are not edited. Do not replace the shim with another forwarding file.
5. Keep family interfaces in their current defining files unless a file is being removed. The import-position interface already resides in retained InTarget; leave that declaration there. No interface-name or selector change is needed.

### Stage B — rewire read surfaces before removing their bases

6. Rewrite the current InQuery, OutQuery, InMultiQuery, OutMultiQuery and LiquidReserve targets to consume Config/Accounting functions rather than inherit Common/InBase/OutBase execution graphs. Keep their public signatures and ownership unchanged.
7. Expand their exact selector arrays as specified in section 4. The twelve SY query/discovery selectors remain on OutMultiQueryFacet. For own shares/supply use ERC20Repo, not `IERC20(address(this))` calls.
8. Keep public validation/discovery independent of execution: all legacy V4 wrappers use the same internal configured-token predicate, not a self-call to `isValidTokenIn` or construction of token arrays to validate one token.
9. Move error references in family tests from deleted Common/InBase/OutBase namespaces to Config's identical declarations before deleting those bases. For example, preserve the exact slippage selector expected by the vault-held redeem suite. Do not retain empty old bases just to satisfy test imports.

### Stage C — install the callback owner and rewire money callers

10. Add `V4/UniswapV4StandardExchangeCallbackTarget.sol`. Its sole external product function is `unlockCallback(bytes)`: validate the actual PoolManager caller, decode the existing operation type, call the appropriate PoolOps callback primitive, and return the same encoded result. It does not take the public money-entry lock.
11. Add matching `UniswapV4StandardExchangeCallbackFacet.sol` with exactly `IUnlockCallback.unlockCallback.selector` in `facetFuncs`. Remove that selector and function from InFacet/InTarget in the same coordinated package change; never construct a package with duplicate owners.
12. Rewrite InTarget to route through the internal libraries. Its ordinary pair deposit calls `PoolOps._executeZapInDeposit`; its share exit calls `PoolOps._executeZapOutExactIn(address(tokenOut), actualIn, minAmountOut, recipient, address(this))` after the existing share delivery. Existing SE disable, deadline, pretransfer and minimum checks stay. Keep the original supported route set; do not add an exact-output share-mint route.
13. Keep `UniswapV4StandardYieldExecutionTarget.sol` as the legacy V4 SY execution target, but remove inheritance that imports the SE dispatcher/shared generic routing. Implement its existing SY ABI with explicit internal deposit/redemption calls and preserved validation/events/rewards. Make InFacet inherit the now-independent InTarget and YieldExecutionTarget plus `IFacet`, so removing YieldExecutionTarget's InTarget inheritance does not remove `exchangeIn` from the installed implementation. Neither target inherits the other; both use the same internal libraries. The yield target supplies the four SY execution selectors already owned by InFacet. Vault-held redemption passes the vault holder; ordinary redemption passes the original caller. Do not stage caller shares or use a synthetic pretransfer flag.
14. **Only new disable checks:** put `Config._requireNotDisabled()` on SY `deposit` and SY `redeem` after their existing request validation and before their first funding/burn/movement. Preserve all disable checks that already exist on SE/import/rebalance entries; add none to previews, discovery, rewards, token transfers, or other families.
15. Preserve one existing shared reentrancy lock per money entry. Explicit SY internal calls must not re-enter guarded SE functions. Keep TWAP completion after settlement; do not turn V3's immediate-return shape into a skipped V4 poke.
16. Rewrite OutExecuteTarget and OutMultiTarget to call Accounting quotes and PoolOps withdrawal/payout internally. Replace the existing self-preview at OutExecuteTarget line 51 and the OUT delegate's internal self-preview helpers with the corresponding Accounting routines. Preserve current funding/refund and payout semantics; this PRD explicitly excludes correcting the stored-reserve residual.
17. Rewrite InMultiTarget, PositionImportTarget and LiquidReserveTarget to call the designated libraries with the same supported behavior and completion sequencing. Reserve's explicit entry still uses its existing idle gate; automatic blocked adjustments remain no-ops. Unexpected operative protocol failures propagate without a new catch.

### Stage D — coordinate package/factory/TestBase wiring

18. Add `IFacet uniswapV4StandardExchangeCallbackFacet` to `IUniswapV4StandardExchangeDFPkg.PkgInit`, immediately after the five shared-facet fields. Add the matching field to `Univ4SePkgInitCore` and copy it in the builder. Preserve `PkgArgs` (`PoolKey poolKey`), existing instance-salt derivation, metadata and other protocol dependencies.
19. Add the callback immutable/assignment in DFPkg and install the sixteen cuts in section 4; `facetAddresses` uses that identical order. Preserve the package's existing interface support and unchanged factory-installed introspection.
20. In `UniswapV4_Component_FactoryService.sol`, add `deployUniswapV4StandardExchangeCallbackFacet`. Existing IN/OUT facet constructors lose execution-delegate arguments. Update creation-code construction accordingly; do not pass empty delegate addresses to legacy constructors. Preserve established names/salts for retained components and use the callback's exact contract name for its new factory identity.
21. Update `V4/test/bases/TestBase_UniswapV4StandardExchange.sol` and other legacy package initialization sites for the callback field. Preserve manager-registry deployment. Update package/facet declaration expectations rather than copying old selector arrays that include the moved callback.

Treat stages B–D as one dependency-connected source migration. Do not run deployment tests against an intermediate cut/constructor combination. A syntax/type failure in an intermediate checkpoint is repaired within this mapping, not used to keep the old delegate architecture.

### Stage E — delete obsolete code only after rewiring

22. Search production and tests for calls/imports of each retiring definition; update permitted callers and exact error-namespace imports first.
23. Delete the two execution-delegate contracts, their deployment helpers, addresses/constructor wiring, `_delegateExecuteZapInDeposit`, and `_delegateExecuteZapOutWithdrawal`. Delete their now-contained declarations with the contracts; do not introduce a replacement delegate.
24. Delete Common, InBase, and OutBase only after all required bodies/declarations have moved and their inheritance/import references are gone. Delete the shared SY import shim only after every importer points to the defining file.
25. Delete `_deployExcessImported`, `_increaseImportedPositionCommon`, and `_increaseImportedPosition`, and the obsolete growth-only branches/approvals that call them. Preserve the import's decrease/collect operation and temporary import readers. Do not delete a shared Repo field or change its layout.
26. Delete OutTarget only if its importer search is empty. For any additional quote helper, first search all repository source consumers; if one exists, report it and keep that helper. Do not use a folder-local search to justify breaking another family. Searches are factual stop/keep conditions already prescribed by the PRD, not architectural alternatives.
27. Verify no residual self-preview, own-state self-call, encoded execution hop, old base inheritance, or deleted-symbol import remains on a legacy V4 production path. View calls to genuine external protocols remain necessary. Factory initialization machinery is not a runtime vault settlement substitute.

## 4. Fixed package cuts and selector lists

Keep all existing ABI signatures. A name below means its current interface-qualified `.selector`, not a newly chosen signature. The package has **sixteen**, not fourteen or twenty-one, cuts:

| Cut index | Facet | Selectors |
|---|---|---|
| 0 | ERC20Facet | `IERC20Metadata.name`, `symbol`, `decimals`; `IERC20.totalSupply`, `balanceOf`, `allowance`, `approve`, `transfer`, `transferFrom` |
| 1 | ERC5267Facet | `IERC5267.eip712Domain` |
| 2 | ERC2612Facet | `IERC20Permit.permit`, `nonces`, `DOMAIN_SEPARATOR` |
| 3 | MultiAssetBasicVaultFacet | `IBasicVault.vaultTokens`, `reserveOfToken`, `reserves` |
| 4 | MultiAssetStandardVaultFacet | `IStandardVault.vaultFeeTypeIds`, `contentsId`, `vaultTypes`, `vaultConfig` |
| 5 | UniswapV4StandardExchangeCallbackFacet | `IUnlockCallback.unlockCallback` |
| 6 | UniswapV4StandardExchangeInFacet | `IStandardExchangeIn.exchangeIn`; SY `deposit`, `redeem`, `rewardIndexesCurrent`, `claimRewards` |
| 7 | UniswapV4StandardExchangeInQueryFacet | transition `quoteAssets`, `quoteShareBalance`, `quoteTransition`, `quoteTotalSupply`; external quote `quoteExternalExchange`, `quoteExternalDeposit` |
| 8 | UniswapV4StandardExchangePositionImportFacet | `IUniswapV4StandardExchangePositionImport.importPosition` |
| 9 | UniswapV4StandardExchangeOutFacet | `IStandardExchangeOut.exchangeOut` |
| 10 | UniswapV4StandardExchangeOutQueryFacet | `IStandardExchangeOut.previewExchangeOut`; transition `quoteState` |
| 11 | UniswapV4StandardExchangeLiquidReserveFacet | reserve interface `canOpenPoolManagerUnlock`, `localReserve`, `deployedReserve`, `targetLiquidReservePercentage`, `actualLiquidReservePercentage`, `rebalanceLiquidReserve`, `twapOracle` |
| 12 | UniswapV4StandardExchangeInMultiFacet | `IStandardExchangeInMulti.exchangeInManyToOne` |
| 13 | UniswapV4StandardExchangeInMultiQueryFacet | `IStandardExchangeInMulti.previewExchangeInManyToOne`; `IStandardExchangeIn.previewExchangeIn` |
| 14 | UniswapV4StandardExchangeOutMultiFacet | `IStandardExchangeOutMulti.exchangeOutOneToMany` |
| 15 | UniswapV4StandardExchangeOutMultiQueryFacet | `IStandardExchangeOutMulti.previewExchangeOutOneToMany`; the twelve SY selectors below |

The twelve SY selectors at cut 15, in their existing appender order, are:

1. `IStandardizedYield.exchangeRate`
2. `IStandardizedYield.yieldToken`
3. `IStandardizedYield.assetInfo`
4. `IStandardizedYield.getTokensIn`
5. `IStandardizedYield.getTokensOut`
6. `IStandardizedYield.isValidTokenIn`
7. `IStandardizedYield.isValidTokenOut`
8. `IStandardizedYield.previewDeposit`
9. `IStandardizedYield.previewRedeem`
10. `IStandardizedYield.getRewardTokens`
11. `IStandardizedYield.accruedRewards`
12. `IStandardizedYield.rewardIndexesStored`

There remain 60 package product selectors; unlockCallback changes owner, not ABI. Keep factory base introspection and temporary post-deploy behavior unchanged. Declaration tests and live loupe assertions must compare this table to actual cuts; a passing call through a different selector is not surface coverage.

## 5. Tests and verification sequence

### Fixed test selection

Run the entire `T4/` subtree, including its `adversarial/` and `decimals/` suites. The following current named anchor files were located and are mandatory members, not a menu:

- `UniswapV4StandardExchangeVaultHeldRedeem.t.sol`
- `UniswapV4StandardExchange_FullRangeBook.t.sol`
- `UniswapV4StandardExchange_LocalLiquidBuffer.t.sol`
- `UniswapV4StandardExchange_LocalLiquidBuffer_H2.t.sol`
- `UniswapV4StandardExchange_MultiJoinExit.t.sol`
- `UniswapV4StandardExchange_NativeEthWrap.t.sol`
- `UniswapV4StandardExchange_TwapPoke.t.sol`
- `UniswapV4StandardExchange_Univ4SeNestedCaller.t.sol`
- `UniswapV4StandardExchangeRoutes_Test.t.sol`
- `UniswapV4StandardExchangeDFPkg_Deploy.t.sol`
- existing `*_IFacet_Test.t.sol` files, including InFacet and OutMultiQueryFacet.

Add `T4/UniswapV4StandardExchangeCallbackFacet_IFacet_Test.t.sol` using the existing declaration-test conventions. Extend the existing package/live-proxy surface tests for the new callback owner and duplicate/missing selector rejection. Extend the vault-held redeem suite with disabled SY deposit and disabled SY redemption rejection, preserving existing holder/minimum tests. Keep existing protocol-caller, genuine outer-unlock, unexpected-rebalance-failure, import conversion and TWAP assertions; add the required assertion in the named existing family suite if its source inventory shows it absent, rather than changing economics to make a legacy test green.

Mechanical import/declaration and expected facet-owner updates are allowed. Do not delete or weaken behavioral tests to bless a self-call, unavailable blocked route, changed custody calculation, or different rounding result. Report any substantive expectation conflict rather than selecting new product behavior.

### Artifact commands for the later session

The following are prescribed commands, not commands executed in this planning session. Run from the repository root in the existing default hermetic profile. After Stage E, the shell globs refer only to surviving/new sources; do not pass deleted source paths.

```bash
V4=contracts/protocols/dexes/uniswap/v4
T4=test/foundry/spec/protocol/dexes/uniswap/v4
SY=contracts/vaults/standard/sy

git diff --check

python3 scripts/forge-artifacts.py plan \
  "$V4"/*.sol "$V4"/internal/*.sol \
  "$SY/NativeStandardYieldTarget.sol" "$SY/NativeStandardYieldErrors.sol" \
  --test-root "$T4"

python3 scripts/forge-artifacts.py build \
  "$V4"/*.sol "$V4"/internal/*.sol \
  "$SY/NativeStandardYieldTarget.sol" "$SY/NativeStandardYieldErrors.sol" \
  --consumer "$T4/**/*.t.sol"

forge build --sizes
```

The targeted build refreshes runtime dependencies first. The full build compiles affected shared-SY importers and produces a size report before runtime testing. Record sizes for each of the eleven family facets, as well as any other deployed facet affected by mechanical shared-source edits. Stop on a runtime above **24,576 bytes**; record but do not fail solely for an advisory **23,000-byte** miss. Do not treat the unverified 31,908 figure as the current result or skip the structural redesign because an intermediate build fits.

Only after the build/size checks succeed:

```bash
python3 scripts/forge-artifacts.py test \
  "$V4"/*.sol "$V4"/internal/*.sol \
  "$SY/NativeStandardYieldTarget.sol" "$SY/NativeStandardYieldErrors.sol" \
  --test-root "$T4" \
  --test-root test/foundry/spec/vaults/standard/sy \
  -- -vv

git diff --check
```

The second test root exercises the existing shared native-SY surface after mechanical declaration/import migration; other-family product behavior is not an edit target. The helper accepts sources as positional arguments and repeated test roots (`scripts/forge-artifacts.py:387-415`). Do not use an invented `--source` flag. `docs/testing/ARTIFACT_BUILDS.md:14-24,30-53` requires refreshed runtime artifacts and explicit surviving replacements after deletion; source presence or stale artifacts are not evidence.

No profile, source/test-root configuration, compiler optimization policy, `via_ir`, cache deletion, or live deployment change is permitted. Wait for compilation. Record all command results, toolchain, runtime sizes, selected test counts and failures. An unrelated full-build failure is reported as such; it is not permission to repair another product in this task or claim compile acceptance.

## 6. Completion and stop rules

Done means the selected sixteen-cut design is wired; all former delegate callers use internal operations; both delegate contracts and the three old bases are removed; query paths have no execution inheritance/self-preview; twelve SY query selectors remain on their existing owner; SY-only new disable checks are covered; existing guards, local-credit calculation, full-range/sleeve behavior, and other-family behavior are preserved; required tests and runtime measurements are reported.

If an unexpected consumer blocks a permitted deletion, preserve it and report the specific dependency as directed by the PRD. If a deleted error namespace prevents compilation, perform the specified signature-preserving namespace migration rather than retaining a broad execution base. If a runtime is oversized, stop with measurements; do not add facets, repartition selectors, restore delegates, change compiler policy, or remove a supported route without a new approved design revision.

**No owner/product choice remains.** This draft fixes the move ownership, dependency order, retained targets, cut order, test roots, and artifact sequence needed to execute the selected design. The PRD's consumer-search and size contingencies are stop/report conditions, not an implementer architecture menu. No additional PRD sentence is requested by this pass.

The test-directory discovery returned its 100-file limit, so the fixed verification selection is the full family subtree rather than a claim that the displayed filenames were exhaustive. No peer artifact was read. Only this assigned plan draft was written; no production, test, script, configuration, or controlling document was changed.

I did not run Forge.
