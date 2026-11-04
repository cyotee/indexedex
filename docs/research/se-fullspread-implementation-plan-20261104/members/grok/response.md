# Grok initial response

## Identity

- Member: grok
- Profile: research
- Phase: initial independent response
- Requested role: council-member
- Requested model: `xai/grok-4.7:xhigh`
- Runtime identity: not exposed
- Task ID: not exposed
- Peers read before submission: no

## Question and targets

Question: write the complete implementation and testing plan for `UniswapV4FullSpreadStandardExchangeVault` from the current PRD, specific enough that an implementer can build and test it without a product decision. The plan does not authorize implementation.

Targets: the current full-spread PRD; the 2026-11-04 owner-override section of the blockers file; `docs/vaults/PRETRANSFER_DIRECTIVE.md`; the accepted return-ABI report; the preview-consumer report and its index; the stage-one gas-ceiling sentences the PRD says stay; `IOperable` appointment selectors; `ERC20Repo._mint`; the live V2 disable call site. Optional context used only to name files and the matrix-row addition: the factory file that owns the temporary hook, the seven named hook-matrix behavior files, and the Crane package shape needed for names the PRD left open.

## Evidence

Read in full:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`
- `docs/vaults/PRETRANSFER_DIRECTIVE.md`
- `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`
- `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md`

Read for the assigned sections:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md` lines 1-120, including the 2026-11-04 override at lines 43-59. Later status sentences in that file that say the PRD has not been edited are not locks.
- `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` lines 956-964, the ceiling meter. The following stage-one sentences about a collection-only fallback and a preflight work-error reject are not the meter.
- `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md` lines 1-8. Occurrences: 1626. Files: 618. Not pasted below.
- `lib/crane/contracts/access/operable/IOperable.sol` lines 92-107. `setOperator(address,bool)` selector comment `0x558a7297`. `setOperatorFor(bytes4,address,bool)` selector comment `0x755dbe7c`.
- `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol` lines 192-197 and 329-332. `_increaseBalanceOf` reverts `ERC20InvalidReceiver` for `address(0)`. `_mint` writes `balanceOf[recipient]` and `totalSupply` directly, then emits `Transfer`.
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol` lines 374-381. The predicate is `address(tokenIn) != address(this)` then `_requireNotDisabled()`. That file checks the predicate before the deadline. The 2026-11-04 lock reorders those two checks.
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol` lines 68-72. The helper reverts `IVaultRegistryDisableQuery.VaultDisabled(address(this))`.

Naming context, not economics:

- `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol` line 31 imports `PostDeployAccountHookFacet`. Line 136 stores it as `POST_DEPLOY_HOOK_FACET`. Lines 417-450 remove it in `postDeploy`.
- `lib/crane/contracts/access/operable/OperableTarget.sol` lines 47-64 gate appointment with `onlyOwner`. That facet is not installed.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultRepo.sol` lines 13-15. Its namespace string is `indexedex.vaults.standard.exchange.uniswap.v4.pairToken`, formed with `keccak256(abi.encode(...)) - 1`.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultRepo.sol` uses `keccak256("indexedex.vaults.standard.exchange.uniswap.v4.upperLowerWings")` without `abi.encode` and without `- 1`.
- The seven behavior files named in FS-TEST-04 exist. A concrete row extends the behavior and overrides `_newFixture()`, as `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV3FullSpreadStandardExchangeVault.t.sol` does.
- `lib/crane/contracts/interfaces/IStandardExchangeOut.sol` lines 67-80. `exchangeOut` takes `deadline`. `previewExchangeOut` does not.
- `lib/crane/contracts/interfaces/IStandardExchangeErrors.sol`. `DeadlineExceeded(uint256,uint256)`, `AmountOutNotMet(uint256,uint256)`, and argument-bearing `InvalidRoute(address,address)` already exist. `MinAmountNotMet(uint256,uint256)` already exists and is not declared for this family.
- `contracts/interfaces/ISecurePullErrors.sol` already declares `EOAPretransferNotAllowed()`.
- `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol` already declares `AlreadyUnlocked()`.
- PairToken `initAccount` calls `EIP712Repo._initialize(decoded_.name, "1")`. That is the version string used below. It is not PairToken economics.

Not read: peer responses, `coordinator/draft.md`, other members' files, `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`, and the November 1 plan-readiness report. FS-TEST-04 is the inventory.

## Assumptions

No product question is left open. Placements the PRD did not name are implementation names in Conclusions heading 19. They are decided there. They are not assumptions and they are not new requirements.

The only operational assumption is that the shared ERC-20 facet already used by Standard Exchange vaults is the facet installed for the nine canonical selectors, and that its `decimals()` is set to 18 at initialization if that facet stores decimals. There is one `decimals()` selector. It is not a second family selector.

## Coverage

The Conclusions section covers package inputs, initialization, storage, the selector cut, check order, every money route, both unlock paths, quotes, events, errors, operators, disable, hook rows, the 32-byte migration, the gas meter, every FS-A row, and every 010-054 inventory row.

Not reopened: the sleeve, `getRate`, zap caps, tick bounds, a quote step cap, a Donation interface, `WithRefund`, a refund return on `exchangeOut`, a stored owner, a principal-only exit, and every FS-TEST-04 "no" row.

## Conclusions

### 1. Authority

This plan does not authorize implementation, deployment, a registry migration, a PRD edit, or a hook-economics edit. It is an implementation and testing plan for a later implementer. Consultation is not approval to code.

### 2. Sources and precedence

Use this order. A later item does not revive a sentence a higher item replaced.

1. A dated 2026-11-04 lock in the PRD, and the same dated override in `IMPLEMENTATION_PLAN_BLOCKERS.md` lines 43-59, wins over a 2026-11-03 override, an earlier sentence in the blockers file, an undated recap, and an older PRD sentence.
2. The current PRD is the operative requirements text. Status lines that say the PRD has not been edited are not locks.
3. `docs/vaults/PRETRANSFER_DIRECTIVE.md` is binding for calls that take `pretransferred`. It wins over an older pretransfer sentence, including the accepted ABI report's short-declaration revert.
4. `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md` is the accepted return ABI and the bundle interfaces. Its owner lock wins over that report's earlier council text. A later full-spread lock wins over a sentence there.
5. `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md` and `INDEX.md` enumerate the 64-byte preview migration. Cite the index. Do not paste it.
6. The stage-one gas meter that stays is 12,000,000 including overhead, measured as an 11,900,000 call body plus 100,000 overhead, and a 5,000,000 preview ceiling. For a composed hook route, the full-spread sentence wins: judge the whole transaction against 12,000,000. Do not import the stage-one collection-only fallback or its preflight work-error reject.
7. PairToken stage one is not an economics authority. Do not inherit S1-ACC-02, S1-ACC-07, S1-D03's dead-share sentence, S1-OP-02's zap caps, S1-OP-05's ratio swap and quarter-cap, S1-P05, S1-P07, S1-EXIT-01's collection-only fallback, S1-X15, or S1-X17. Do not apply S1-A10, S1-A13, S1-A15, S1-A19, S1-A46, S1-A62, S1-A64, or S1-A70 as issuance, zap-cap, remainder, or consumption-check rows. S1-A40 is not an inherited pass for `exchangeIn`.

### 3. Adopted readings

These are closed. They are not a menu.

- A pass-through is an exact-input pool swap at `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`. It is not the FS-OWN-33 liquidity-targeting swap. That shape is only for a one-sided deposit and a one-token `donate` or `compound`.
- A planned manager action is one `swap` or one `modifyLiquidity`, not one public call. A one-sided deposit that swaps and then adds liquidity uses two sequential unlocks in the same call. No external call runs between them except settlement of the first action.
- The gas numbers stay 12,000,000 and 5,000,000. The local cold-call meter is an 11,900,000 measured call body plus 100,000 overhead. A composed hook route is judged on the whole transaction against 12,000,000. If it does not fit, record it unresolved. Do not pass it and do not waive it.
- `Donation()` and `Compounded()` are empty marker events. Do not add a Donation interface or an ERC-165 id for it.
- The live `feeTo()` owner appoints global operators with `setOperator(address,bool)` and function operators with `setOperatorFor(bytes4,address,bool)`. The maintenance check has those three arms: the live `feeTo()` address, a global operator, or a function operator whose grant is for `msg.sig`. Do not use `OperableModifiers.onlyOwnerOrOperator`. Do not use `MultiStepOwnableRepo._onlyOwner`. Do not store `feeTo()` at initialization.
- Disable blocks every execution route except a withdrawal, `donate`, and `compound`. A missed deadline reverts `DeadlineExceeded` before the disable check. The V2 file's opposite order is not copied.
- FS-TEST-04 is the audit inventory. A "no" row stays no. An "integration only" row stays integration only. Do not add an audit ID. Do not treat a November 1 "expected result blocked" cell as open. Booked-remainder rows can pass.
- A bundle pretransfer shortfall reverts before any leg, spends nothing, and mints nothing. Do not declare a new error. The test does not pin a new selector.
- Borrowed-path initialized, idle, callback-hash, and reservation failures revert. That revert is not `ReentrantOperation` and not `SettlementMismatch`. Use a bare `revert()` for those four checks.
- The floor mint uses `ERC20Repo._mint`, which writes `balanceOf` and `totalSupply` directly. Do not use `_increaseBalanceOf`. Do not use the shared ERC-20 facet mint path.

### 4. File map, including Crane files and family files

Create the family under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`. Do not edit PairToken or Wings to host it.

Production files:

- `interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol`
- `interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol`
- `UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol`
- `UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService.sol`
- `UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol`
- `UniswapV4FullSpreadStandardExchangeVaultTypes.sol`
- `UniswapV4FullSpreadStandardExchangeVaultRepo.sol`
- `UniswapV4FullSpreadStandardExchangeVaultMath.sol`
- `UniswapV4FullSpreadStandardExchangeVaultProjection.sol`
- `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol`
- `UniswapV4FullSpreadStandardExchangeVaultExecution.sol`
- `UniswapV4FullSpreadStandardExchangeVaultMoneyFacet.sol`
- `UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol`
- `UniswapV4FullSpreadStandardExchangeVaultQuoteFacet.sol`
- `UniswapV4FullSpreadStandardExchangeVaultQuoteTarget.sol`
- `UniswapV4FullSpreadStandardExchangeVaultOutFacet.sol`
- `UniswapV4FullSpreadStandardExchangeVaultOutTarget.sol`
- `UniswapV4FullSpreadStandardExchangeVaultQueryFacet.sol`
- `UniswapV4FullSpreadStandardExchangeVaultQueryTarget.sol`
- `UniswapV4FullSpreadStandardExchangeVaultCallbackFacet.sol`
- `UniswapV4FullSpreadStandardExchangeVaultCallbackTarget.sol`
- `UniswapV4FullSpreadStandardExchangeVaultOperableFacet.sol`
- `UniswapV4FullSpreadStandardExchangeVaultOperableTarget.sol`
- `UniswapV4FullSpreadStandardExchangeVaultFeeToOwnerModifiers.sol`
- `UniswapV4FullSpreadStandardExchangeVaultMaintenanceModifiers.sol`

`OperableFacet`, `OperableTarget`, and the two modifier filenames are implementation names. They are not new requirements. Do not shorten a target to `MoneyTarget.sol`. Do not create SY money or SY query files.

The `SwapProjection` library is declared in the Projection file. The `ExecutionPreparation` library is declared in the Execution file. The FactoryService deploys both as linked components. Do not add a seventh linked-library slot.

Crane files, not inside the family directory:

- `lib/crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4ProtocolAwareRepo.sol`
- `lib/crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4ProtocolAwareFacet.sol`
- `lib/crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4SinglePositionAwareRepo.sol`
- `lib/crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4SinglePositionAwareFacet.sol`

One repo and one facet for each pair. Do not split the seven architecture addresses into seven repos. Crane tests for both pairs live under `lib/crane/test/foundry/spec/protocols/dexes/uniswap/v4/aware/`.

Family tests:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPackage.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMoney.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultNative.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultQuotesAndRate.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultCallbacks.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultAlreadyUnlocked.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultBufferHookIntegration.t.sol`

The temporary-hook facet is `PostDeployAccountHookFacet`, cited from `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol` line 31. It is factory-owned. It is not a family file and not a `PkgInit` field.

Accepted interfaces to add or update, because the bundle interfaces are not in the tree and `IStandardExchangeIn` still returns one word:

- Update `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` to the accepted tuple return. Keep selectors `0x89d61912` and `0xd02d3063`.
- Add the accepted bundle interfaces from the return-ABI report if they are still absent. Do not invent further selector hex.

### 5. Package, initialization, and validation, with the chosen field names

`PkgInit` and `PkgArgs` are declared on `IUniswapV4FullSpreadStandardExchangeVaultDFPkg`, not on the package contract.

`PkgInit`, in this binding order. Field names the PRD left open are labeled again in heading 19.

1. `erc20Facet`
2. `erc2612Facet`
3. `erc5267Facet`
4. `multiAssetBasicVaultFacet`
5. `standardVaultFacet`
6. `moneyFacet`
7. `quoteFacet`
8. `outFacet`
9. `queryFacet`
10. `callbackFacet`
11. `operableFacet`
12. `uniswapV4ProtocolAwareFacet`
13. `uniswapV4SinglePositionAwareFacet`
14. `poolManager`
15. `positionDescriptor`
16. `positionManager`
17. `quoter`
18. `stateView`
19. `reservesLens`
20. `universalRouter`
21. `registry`
22. `oracle`
23. `weth`
24. `diamondFactory`
25. `linkedLibraries` as `address[6]`, in order Math, Projection, SwapProjection, Planner, Execution, ExecutionPreparation

`syMoneyFacet` and `syQueryFacet` are absent. `wrappedNative` is absent. Do not pass a PairToken facet address into this package. `poolManager` is an address binding. It is not permission to install a family `poolManager()` selector.

`PkgArgs` is only:

- `PoolKey poolKey`
- `string name`
- `string symbol`

No `rateAsset`, no `maxZapBps`, no `maxZapTickMove`, no hook allowlist, no wrapped-native argument.

`bindingHash` covers every `PkgInit` field, including `weth` and the six architecture addresses. `calcSalt` and `processArgs` run by delegatecall. They use immutable bindings and self calls.

`deployVault(PkgArgs) returns (address)` goes through the bound IndexedEx vault registry. No second factory. The package does not CREATE3 the PoolManager. Tests deploy that manager through the current artifact-backed CREATE3 helper. The hook under test and this vault bind that same manager.

`processArgs` reverts `NotCalledByRegistry` unless `msg.sender` is the bound registry and `address(this)` is the bound `diamondFactory`. Both conjuncts are required.

Reject, without a partial diamond:

- A missing or code-empty component, a family facet whose linked-component hash does not match, or a cut that installs `getRate` or `rateAsset`. `InvalidComponent`.
- A pool key that is not initialized on the bound manager, or whose hook is not `address(0)`. `InvalidPoolKey`. Do not reject an inherited domain. Do not reject tick spacing.
- The `processArgs` context failure. `NotCalledByRegistry`.
- Proxy initialization that does not match the bound package and arguments. `InvalidInitializationContext`.
- A second initialization. `AlreadyInitialized`.

Do not declare `InvalidRateAsset`, `InvalidZapLimits`, or `InvalidWrappedNative`. There is no argument for those checks.

Initialization writes:

- Name and symbol from `PkgArgs`.
- EIP-712 domain name equal to `PkgArgs.name`, version `"1"`, through `EIP712Repo._initialize(name, "1")`. That version is an implementation note for inventory 052, not a new token.
- The pool key, `TickMath.minUsableTick` of the pool's tick spacing, `TickMath.maxUsableTick` of that spacing, and salt `bytes32(0)` into `UniswapV4SinglePositionAware`. Those four values are instance storage. They are not package immutables.
- The seven package-immutable addresses into `UniswapV4ProtocolAwareRepo`. One write. Do not also store them in the family repo.
- `weth` through `WETHAwareRepo._setWeth`. Do not hardcode the Robinhood `WETH9` constant.
- Do not store `feeTo()`. Do not store a rate token, a rate-provider address, a sleeve target, or a zap cap.
- Do not create the position. The first depositor creates it.
- Do not mint the floor at initialization. The floor is minted on the first successful deposit.

`multiAssetBasicVaultFacet` is the implementation name that replaces a single `basicVaultFacet`. It is the shared `MultiAssetBasicVaultFacet` address. The cut installs only `vaultTokens` from it.

`queryFacet` is the family custom facet. It installs only `reserveOfToken` and `reserves`.

`operableFacet` is the implementation name for the home of the locked `IOperable` selectors. The stock `OperableFacet` is not installed, because `OperableTarget` gates appointment with `onlyOwner`.

### 6. Storage

Family slot, an implementation name:

```solidity
bytes32 internal constant DEFAULT_SLOT = bytes32(
    uint256(keccak256(abi.encode("indexedex.vaults.standard.exchange.uniswap.v4.fullSpread"))) - 1
);
```

FS-A04 asserts this slot is not PairToken's `indexedex.vaults.standard.exchange.uniswap.v4.pairToken` slot and not Wings' `keccak256("indexedex.vaults.standard.exchange.uniswap.v4.upperLowerWings")` slot.

Family `Storage` holds only:

- `bool initialized`
- `OperationKind operation`, with `None` as idle
- `bool guardHeld`
- `bytes32 callbackHash`
- `uint256 reserved0`
- `uint256 reserved1`
- `mapping(address token => uint256 amount) booked`

`reserved0` and `reserved1` are the reservation words for `vaultTokens()[0]` and `vaultTokens()[1]`. They record an in-flight amount only inside a planned action and are cleared before external return. They are not a second credit product. A nonzero word at borrowed entry is the unnamed reservation failure.

`booked` is the parking lot for underlying tokens. It is not a reserve. It is not redeemable idle. It is not the pretransfer balance. Do not book the share. Do not store a fee-origin flag.

Do not store in the family slot: `feeTo`, the seven architecture addresses, the pool key, ticks, salt, a rate provider, a local-reserve target, a last-committed snapshot, or zap limits.

Other slots, each used once:

- Share balances and `totalSupply` stay in `ERC20Repo`'s standard slot. The floor mint calls `ERC20Repo._mint` on that slot.
- Operator grants stay in `OperableRepo`. Do not copy them into the family slot.
- WETH stays in `WETHAwareRepo`.
- EIP-712 name, version, and nonces stay in their existing repos.
- Position key and salt stay in `UniswapV4SinglePositionAware`.
- The seven architecture addresses stay in `UniswapV4ProtocolAwareRepo`.

`decimals()` returns 18. That is metadata. It is not a scale and not an input to mint or burn. Do not multiply the stored share balance, or the floor, by a constant to match `decimals()`.

### 7. Selector cut

Recount the manifest from this package when it is built. Cite that package's `_expectedSelectors`. Do not use the old 61-selector count. `linkedComponents()` is facet metadata, not an installed proxy selector. Do not invent selector hex beyond the values already named below.

Installed:

| Home | Selectors |
| --- | --- |
| `erc20Facet` | The nine canonical ERC-20 and metadata selectors. `decimals()` returns 18. |
| `erc2612Facet` | `permit`, `nonces`, `DOMAIN_SEPARATOR`. |
| `erc5267Facet` | `eip712Domain`. |
| `multiAssetBasicVaultFacet` | `vaultTokens` only. Do not install the other selectors of that facet. They read slot `indexedex.vaults.basic`. |
| `standardVaultFacet` | `vaultFeeTypeIds`, `contentsId`, `vaultTypes`, `vaultConfig`. |
| `moneyFacet` | `exchangeIn` `0xd02d3063`, `exchangeBundleInForSingleOut` `0xe7886166`, `exchangeBundleOut` `0x11993461`, `donate(address,uint256,bool)`, `compound()`. |
| `quoteFacet` | `previewExchangeIn` `0x89d61912`, `previewExchangeBundleInForSingleOut` `0xc2fe8c7c`, `previewExchangeBundleOut` `0xa5952fc2`. The preview tuple is `(uint256 amountOut, uint256 amountRefunded)`. |
| `outFacet` | `previewExchangeOut` `0xdb149bc5`, `exchangeOut` `0x612d4427`. No refund word on either. |
| `queryFacet` | `reserveOfToken`, `reserves`. Nothing else. |
| `callbackFacet` | `unlockCallback`. |
| `operableFacet` | `setOperator` `0x558a7297`, `setOperatorFor` `0x755dbe7c`, `isOperator` `0x6d70f7ae`, `isOperatorFor` `0xea562a25`. The hex is the comment in `IOperable.sol`, not a new selector. |
| Protocol Aware facet | `poolManager`, `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, `universalRouter`. These are Crane getters. They are not family query selectors. |
| Single-position facet | `poolKey`, `tickLower`, `tickUpper`, `positionSalt`, `positionLiquidity`. `positionSalt` is an implementation name for the stored salt getter. |

`positionLiquidity()` wraps `StateLibrary.getPositionInfo` for this diamond, the stored ticks, and the stored salt. It returns that position's liquidity. It does not call `StateView` and it does not call `PositionManager`.

`vaultTokens()` is PoolKey `currency0`, then `currency1`, with the `WETHAwareRepo` address substituted for native. `reserveOfToken` returns zero for an address that is not in that list. `reserves()` is that same deployed read for both tokens: the amount implied by this position's liquidity, the current pool price, and the stored ticks, plus unpaid fees owed to this position. Use the existing position-amount and fee-owed reads. Do not add a formula that calls the stored Reserves Lens. A booked remainder is not in that read.

Factory-owned surfaces are absent from `PkgInit`, `facetCuts`, and the package interface aggregation:

- ERC-165
- ERC-8109
- Diamond loupe
- `PostDeployAccountHookFacet`

ERC-165, ERC-8109, and the loupe stay callable on the finished factory-built proxy, because the factory installs them and does not remove them. `PostDeployAccountHookFacet` is installed for the init window and removed by `DiamondPackageCallBackFactory.postDeploy`. The finished proxy must not keep its selectors. Absence from the package cut is not removal of the three surfaces the factory keeps.

Advertise `IStandardExchangeIn` as `0x59fb2971`. Do not advertise `0x8c8035da` or `0x676ec907`. Recheck the bundle interface ids with `type(I).interfaceId` before registration. The accepted report's computed ids are `0x2576ed1a` and `0xb40c1ba3`. Do not register a different invented hex. Recheck `IOperable`'s commented id `0xa7f11160` the same way.

Absent, and asserted absent:

- `depositPair`, `previewDepositPair`, `redeemPair`, `previewRedeemPair`
- `getRate`, `rateAsset`, `basket`, `wrappedNative`, `localReserves`, `asset`
- `deposit`, `redeem`, `exchangeRate`, and every other Standardized Yield selector
- `previewZapCredit`, `previewWithdrawalMode`, `maxZapBps`, `maxZapTickMove`
- a family `poolManager()` and a family-only `poolKey()`
- `previewExchangeInWithRefund`, `exchangeInWithRefund`
- `IStandardExchangeTransitionQuote`, `IStandardExchangeUnlockContextQuote`, `IStandardExchangeExactOutputQuantityQuote`
- a Donation interface

Do not install `StandardExchangeRateProviderFacet` on this vault.

### 8. Check order for each public mutator

Shared ERC-20, `permit`, and EIP-712 mutators keep their current shared-facet checks. This plan does not reorder them. A share `transfer` does not book, withdraw, or mint.

The deadline check, on every route that takes `deadline`, is first. It is `IStandardExchangeErrors.DeadlineExceeded(deadline, block.timestamp)` when `block.timestamp > deadline`. No pull, no disable read, no route reject, and no manager call runs before it. `donate` and `compound` have no deadline argument. Do not add one.

Disable, when it applies, is immediately after the deadline check and before every other reject. The predicate is the V2 test widened to every execution route: a route whose input is not this vault's share is blocked. The error is `IVaultRegistryDisableQuery.VaultDisabled(address(this))`, read from the bound `PkgInit.oracle`. Do not use Wings' zero-argument `VaultDisabled()`.

`exchangeIn`:

1. Deadline.
2. If `address(tokenIn) != address(this)` and the vault is disabled, `VaultDisabled`. Share in is a withdrawal and is not blocked. A pass-through is not a withdrawal and is blocked.
3. If `tokenIn == tokenOut`, family `InvalidRoute()`.
4. If `amountIn == 0`, `EmptyExchange()`.
5. If `tokenIn` or `tokenOut` is `address(0)`, or is neither the share nor a `vaultTokens()` entry, `TokenNotExchangeable`.
6. If `recipient` is `address(0)` or `address(this)`, `InvalidRecipient()`.
7. The only success routes are one-sided deposit, one-token exit, and pass-through.
8. Read `TransientStateLibrary.isUnlocked` on the bound manager. It selects the path. It is not authorization.
9. If unlocked, run the borrowed checks in heading 11 before any pull. If locked, skip those checks.
10. Secure input under heading 9. Then run the route body.

A value-bearing call fails at the nonpayable ABI boundary. Do not add an internal `msg.value` check. Do not specify `InvalidUnlockedContext` for `msg.value != 0`.

`exchangeBundleInForSingleOut`:

1. Deadline.
2. `VaultDisabled` if disabled. This route is never a withdrawal.
3. `ManagerAlreadyUnlocked()` if the manager is unlocked.
4. `AmountsLengthMismatch` if `amountsIn.length != vaultTokens().length`.
5. `ExchangeBundleInForSingleOutNotAvailable` if `tokenOut` is not the share.
6. `InvalidRoute()` if a nonzero `amountsIn[i]` has `vaultTokens()[i] == tokenOut`.
7. `EmptyExchange()` if every amount is zero.
8. `InvalidRecipient()` for a zero recipient or this vault.
9. `EOAPretransferNotAllowed()` if `pretransferred` and the caller has no bytecode. Use the existing error. Do not redeclare it.
10. If `pretransferred` and any declared maximum exceeds that token's unbooked balance, bare `revert()` before any leg. Spend nothing. Mint nothing. Do not declare an error. The test does not pin a selector.
11. One `modifyLiquidity`. No balancing swap.

`exchangeBundleOut`:

1. Deadline.
2. The withdrawal shape is `tokenIn == address(this)`, `tokensOut.length == 2`, `tokensOut[0] == vaultTokens()[0]`, `tokensOut[1] == vaultTokens()[1]`, no duplicate, and `tokenIn` not in `tokensOut`.
3. If disabled and the call is not that shape, `VaultDisabled`.
4. If enabled and the call is not that shape, `ExchangeBundleOutNotAvailable`.
5. If the shape matches and `minAmountsOut.length != tokensOut.length`, `TokenAmountsLengthMismatch`.
6. `ManagerAlreadyUnlocked()` if the manager is unlocked. A disabled mapped withdrawal still hits this error, not `VaultDisabled`.
7. Secure the caller's shares. Then the both-token exit body.

`exchangeOut`:

1. Deadline.
2. If disabled, `VaultDisabled`. Do not continue to `ExchangeOutNotAvailable`.
3. If enabled, `ExchangeOutNotAvailable()`. Move no tokens. Do not add a refund return.

`previewExchangeOut` has no deadline and no disable check. It returns zero.

`donate`:

1. Maintenance auth for the `donate` selector. Failure is the existing `IOperable.NotOperator(msg.sender)`. That is the error used, not a new error.
2. `ManagerAlreadyUnlocked()` if unlocked.
3. If `totalSupply == 0`, bare `revert()` before any swap. Do not declare an error.
4. `TokenNotExchangeable` if `token` is not a `vaultTokens()` entry and not the share.
5. Disable does not apply. There is no deadline check.
6. A zero `amount` is not an `EmptyExchange` reject. The call still compounds and, on success, emits `Donation()`.

`compound`:

1. Maintenance auth for the `compound` selector. Same `NotOperator` failure.
2. `ManagerAlreadyUnlocked()` if unlocked.
3. If the unpaid fee-owed read and every booked balance are zero, return. No manager call. No event.
4. Disable does not apply. There is no deadline check.

`setOperator` and `setOperatorFor`:

1. Live `feeTo()` owner only. A global operator does not pass. A function operator does not pass. `MultiStepOwnableRepo._onlyOwner` is not called.
2. Write `OperableRepo` and emit the existing operable events.
3. Appointment is not an execution route. `VaultDisabled` does not apply.

`unlockCallback`:

1. If `msg.sender` is not the bound PoolManager, bare `revert()` and move no tokens. Do not declare a new error. The test does not pin a selector.
2. If `guardHeld` is false, the payload hash does not match `callbackHash`, or that hash was already consumed, revert. Replay reverts. An external unlock does not satisfy a committed hash.
3. Settle that one action. Do not call `compound`.

Views do not revert by a vault error. An unsupported view route returns zero. A busy or unlocked manager is not a view revert. Economic views return the computed value. A refund preview does not transfer and does not read a balance.

### 9. One-sided deposit, bundle deposit, one-token exit, both-token exit, and pass-through

Unbooked balance of an underlying token is `balanceOf(vault) - booked[token]`. A booked remainder is not that balance. Unbooked shares for a share pretransfer are the vault's own share balance. Shares owned by a user are not that balance. Shares parked on the vault are not caller credit beyond the declared maximum. A burn uses the caller's shares.

Pull path, `pretransferred == false`: pull the declared amount from `msg.sender`, then refund the unkept amount of that same token to `msg.sender`. Declared amount equals amount consumed plus amount refunded. Pulling only the consumed amount is not the rule. A zero refund transfers nothing. Output goes to `recipient`. Refunded wei are not share credit.

One-token pretransfer: if the maximum is within the unbooked balance, the refund is the maximum minus the amount used, in the token the caller provided. Do not refund the rest of the unbooked balance. If the maximum is larger than the unbooked balance, refund that unbooked balance, spend none of it, and do not pull the shortfall. That comparison is not a revert. Continue the route with zero consumed. A later `minAmountOut`, `MinAmountNotMetAt`, or `MinLiquidityNotMet` may still revert. The caller may declare any maximum.

Bundle pretransfer shortfall is the bare revert in heading 8. It is not the one-token overstatement rule.

An address without bytecode cannot pretransfer. Use `EOAPretransferNotAllowed()`. A non-atomic pretransfer is the caller's risk. Do not ask where the tokens came from.

A positive PoolManager token credit on entry settlement is returned to the payer. It is not booked. `feesAccrued` is not that credit. Share credit goes to `recipient`, who need not be the payer.

Usage fee, on a share-minting deposit only:

- Read `usageFeeOfVault(address(this))`. If the resolved fee is above `3e17`, use `3e17`. Otherwise use the resolved fee. Do not write the oracle. Do not preview the raw fee and execute the clamp.
- If `feeTo` is `address(0)`, fee shares are zero. Otherwise `feeShares = mulDiv(grossShares, clampedFee, 1e18)`, rounding down.
- Mint `feeShares` to `feeTo` and `grossShares - feeShares` to `recipient`. Skip a zero mint. Do not mint beyond `grossShares`. Do not mint a fee on the fee shares.
- `1e13` is 0.001% in the WAD unit. The existing `mulDiv` against `1e18` is the required precision. Do not round the fee to three digits. A configured zero stays zero. A configured fee above 30% does not give the depositor zero shares by itself.
- A pass-through does not take this fee.

First deposit, before any mint: if added liquidity is less than or equal to `1_000`, revert `MinLiquidityNotMet()`. The whole call reverts.

Floor mint, only on a successful first deposit: `ERC20Repo._mint(ERC20Repo._layoutStruct(), address(0), 1_000)`. That writes `balanceOf[address(0)]` and `totalSupply`, and it emits `Transfer(address(0), address(0), 1_000)`. Do not suppress that event. Do not use `_increaseBalanceOf`. The floor is part of `totalSupply`. It is not part of `grossShares` and it is not a fee mint.

First-deposit `grossShares = added liquidity - 1_000`. Supply grows by `grossShares` plus the floor.

Later deposit: `grossShares = floor(added liquidity * totalSupply / existing liquidity)`. `totalSupply` and existing liquidity are the values before this mint and before this add. Idle balances, booked remainders, and `feesAccrued` are not in the denominator. Supply grows only by `grossShares`. Use rounding-down division. Do not use a rounding-up helper.

On every share-minting deposit, book the `feesAccrued` returned by `modifyLiquidity`. Do not include those fees in the deposit, the share credit, or a swap. A mint preview does not credit them to the new depositor.

One-sided deposit:

1. Secure `tokenIn`. `tokenOut` is the share.
2. `FullSpreadOperationQuote` chooses the FS-OWN-33 amounts from the consumed input. The greatest liquidity the following add can take is `L`. The swap output is the other token that `L` consumes. The unswapped input is the processed token that `L` consumes. Rounding leaves the remainder in the input token. The swap input is not the processed-token amount the add itself consumes. Do not require a 48% swap. Do not require the swap to consume the declared input. There is no `IncompleteConversion` check.
3. Planned action 1: one exact-input `swap` of that swap input at `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`, chosen by direction. On the locked path this is one unlock. Settle that action before the next action. No other external call runs between them.
4. Planned action 2: one `modifyLiquidity` that adds `L` to the full-range salt-zero position. The diamond is the position owner. The first deposit creates that position.
5. Book `feesAccrued`. Refund unused declared `tokenIn` to `msg.sender`. Do not book that refund. Do not mint it.
6. Mint the floor if this is the first deposit, then mint the net shares and the fee shares.
7. Return the depositor's net shares as `amountOut`, and the refund as `amountRefunded`. `minAmountOut` binds on the net shares.

The quote walk uses the pool's own swap equation across initialized ticks and selects that greatest `L`. It does not stop at 64 steps. It does not revert `QuoteWorkLimit`. It does not call the stored Quoter. If the consumed input can add only zero liquidity, add nothing and refund the unused declared input. Execution then performs the same swap input and the same `L`.

Bundle deposit:

1. Secure both declared amounts. The shortfall revert already ran.
2. One planned action: `modifyLiquidity` of the declared amounts in proportion to the pool. No balancing swap.
3. Book `feesAccrued`. Refund each token's unused declared amount. Do not book that refund.
4. Mint by the same first-deposit or later-deposit formula. The fee is taken from `grossShares`.
5. Emit `PairDeposited(address indexed caller)` and no other arguments.
6. Return net shares and `amountsRefunded` in `vaultTokens()` order.

One-token exit. `tokenIn` is the share. `tokenOut` is one underlying.

1. Measure before the burn and before `modifyLiquidity`: `supplyBeforeBurn` including the floor, position liquidity, the unpaid fee-owed read, and each booked balance.
2. `principalLiquidity = floor(liquidity * sharesBurned / supplyBeforeBurn)`.
3. For each token, the fee claim is `floor(feesAccrued * sharesBurned / supplyBeforeBurn)`. The booked claim is `floor(booked * sharesBurned / supplyBeforeBurn)`. Do not divide the share fraction before multiplying.
4. Planned action 1: `modifyLiquidity` removes `principalLiquidity` and collects the unpaid fees. Pay the caller's requested-token principal, requested fee claim, and requested booked claim toward `recipient`. Book the staying holders' portion of the collected fees and of the previous booked balance. Do not count a booked token again as unpaid fees.
5. The unwanted side is the unwanted withdrawn principal plus the caller's opposing fee claim plus the caller's opposing booked claim. Planned action 2 swaps that entire amount as an exact-input swap at the same unbounded price limit. The swap input is that exiting claim only. It does not include other holders' booked fees and it does not sell the staying holders' inventory.
6. If the swap does not consume that entire unwanted amount, revert `AmountOutNotMet(uint256 amountOut, uint256 actualOut)` and do not leave a burn committed. Do not pay, book, or keep that residual.
7. `amountOut` is the selected-token proceeds: requested principal, requested claims, and swap output. `minAmountOut` binds on that total. The same revert applies when the minimum is missed.
8. There is no sleeve top-up and no `UnderlyingUnavailable`.

Both-token exit:

1. Use the same pre-burn apportioning.
2. One planned action: `modifyLiquidity` removes `principalLiquidity`. Do not swap. Do not sell one leg to pay the other.
3. Pay each token's principal plus that token's fee claim plus that token's booked claim to `recipient`. Book the rest.
4. A caller minimum uses `MinAmountNotMetAt(uint256 index, uint256 minAmount, uint256 actualAmount)`, with `index` as the `tokensOut` index. Do not declare `MinAmountNotMet`.
5. Emit `PairRedeemed(address indexed caller)` and no other arguments.
6. Return `amountsOut` in the caller's `tokensOut` order, and the share refund.

Pass-through:

1. `tokenIn` and `tokenOut` are the two different `vaultTokens()` entries.
2. One planned action: an exact-input pool swap at the unbounded price limit. Do not run the FS-OWN-33 sizing. Do not call `modifyLiquidity`. Do not collect or book fees in this call. Fees the swap accrues to the position stay unpaid until a later `modifyLiquidity`.
3. Mint no shares. Take no usage fee.
4. Refund unused declared input. If the pool consumes the declared input, the refund is zero.
5. Return the swap output as `amountOut`. Emit no new vault event.

A deposit, a withdrawal, and `exchangeIn` do not call `compound()` and do not deploy the staying holders' booked balance. A withdrawal does pay, and a one-token exit does convert, the caller's own booked claim.

Callers send and receive the WETH face only. The vault does not accept or produce native ETH. Native wrap or unwrap happens only at the pool boundary.

### 10. `donate` and `compound`

Both are authorized only by the three-arm modifier. A deposit, a withdrawal, and `exchangeIn` do not call either. Neither swaps the deployed position. There is no price check, tick bound, or fee cap beyond the unbounded entry limit. A sandwich of the owner or operator's own call can sell the fees or the booked remainder at a moved price. That exposure is accepted. Do not claim it is absent. Do not add a disclosure function.

`donate(address token, uint256 amount, bool pretransferred)` takes those three arguments. No recipient. No deadline. No selector hex is added. `compound()` takes no arguments.

Collected fees are the trading fees returned by `modifyLiquidity` as `feesAccrued`. A user deposit or withdrawal books them and does not compound them. `donate()` also compounds. Both maintenance calls process the combined balance of just-collected fees, the booked remainder, and, for an underlying `donate`, the directed amount.

Share donation: burn the directed shares from the caller. Do not withdraw. Do not swap the shares. Do not pay the burned shares' fee or booked claim out. Those claims stay for the remaining holders. No shares are minted for an underlying donation. The one-token pretransfer overstatement rule applies to a share donation and is not a revert. The call still emits `Donation()` on success.

Underlying donation and `compound` then use one process:

- If the unpaid read and the booked balances are zero and `compound` has no other input, `compound` has already returned.
- Otherwise collect unpaid fees with one zero-liquidity `modifyLiquidity` on the salt-zero position when that unpaid read is nonzero. That collect is one planned action.
- If the combined balance is one token, run the FS-OWN-33 swap toward the position ratio, then add the resulting liquidity. The swap uses the same unbounded price limit. It spends the combined one-token maintenance balance. It does not take an opposing token that is not part of that balance.
- If the combined balance holds both tokens, do not swap. Deposit the matched pair. The scarcer token is the proportionally smaller amount relative to the position ratio, not the smaller raw balance. That token is fully used. Book the excess of the other token.
- After the deposit, set `booked[token]` to the actual held balance of that token. Do not store a calculated leftover. That books a stray transfer. A non-atomic pretransfer can be booked too. A donation or compound remainder is booked, not refunded.
- Best-effort means that one process. A failed step reverts. Do not add a second attempt, a fallback, or a swallowed failure. A remainder does not revert the call. Its size does not matter. Call `compound()` again to process it.
- The maintenance deposit does not mint shares and does not take the usage fee.

`compound()` with no fees and no booked remainder returns with no state change and no event. A successful `donate()` emits `Donation()` even when it deposits nothing. Emit `Compounded()` only when a deposit is made from collected fees or booked tokens. A `donate()` that deposits also emits `Compounded()`. Booked tokens are treated as fees. There is no fee-origin store. A call that deposits nothing does not emit `Compounded()`. A reverting call emits neither event.

The vault does not emit its own swap or liquidity-add event. The PoolManager emits `Swap` and `ModifyLiquidity` with the vault as `sender`.

### 11. Locked and borrowed unlock paths

After the heading 8 checks, `exchangeIn` reads `isUnlocked`.

Locked path:

- For each planned action, `ExecutionPreparation` commits `callbackHash = keccak256(abi.encode(operation, payload))`, then the vault calls `unlock` once for that action.
- `unlockCallback` is accepted only from the bound manager, only while `guardHeld` is true, and only once for that payload.
- Settle that action and require the manager to have relocked before the next action.
- A one-sided deposit is two unlocks. A pass-through is one. A one-token exit is two. A bundle deposit is one. A both-token exit is one.
- Nested unlock and replay are forbidden.
- `guardHeld` stays true across the plan, the token calls, and the final payout. The callback does not call `compound()`.
- `unlockCallback` is not a deposit. An external unlock does not satisfy a committed hash.
- If this vault calls `unlock` while the manager is already unlocked, the PoolManager reverts `AlreadyUnlocked`. That is not `ManagerAlreadyUnlocked`.

Borrowed path, only for `exchangeIn`:

1. If `guardHeld` is true, revert `ReentrantOperation()`.
2. If `initialized` is false, bare `revert()`.
3. If `operation != None`, bare `revert()`. This idle failure is not `ReentrantOperation` and not `SettlementMismatch`.
4. If `callbackHash != bytes32(0)`, bare `revert()`.
5. If either reservation word is nonzero, bare `revert()`.
6. If this diamond's own backing-currency deltas on the bound manager are nonzero, bare `revert()`. That is not `SettlementMismatch`.
7. `pretransferred` must be false. Otherwise `InvalidUnlockedContext()`.
8. The caller has code, pays the input, and is the share owner burned on an exit. A failed funding or route check uses the inherited funding error. The unlocked flag is not authority. An unlocked caller who does not hold the input or the shares does not mint.
9. Do not call `unlock`. Do not call `unlockCallback`. Do not copy the locked callback's final `getNonzeroDeltaCount` check. That count is global. The hook and router may hold open deltas.
10. Dispatch each selected action to the same internal action, account, and settlement code as the locked path. A one-sided borrowed deposit is still two manager actions and zero unlocks.
11. `modifyLiquidity` and `swap` run only on this diamond's hookless pool key. The position owner, ticks, and salt stay. A one-token exit pulls the caller's deployed fraction and swaps only the FS-OWN-30 exiting claim.
12. Before return, this diamond's touched currency deltas are zero. Assert that per address. Do not require the global nonzero-delta count to be zero. Do not settle the hook's or the router's deltas.

`exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` revert `ManagerAlreadyUnlocked()` on this path. They never take another caller's lock. There is no sleeve payment. The unpullable borrowed exit does not occur. `required` and `available` have no case to measure. `AmountOutNotMet`, a funding failure, and `SettlementMismatch` remain. The call is not a sleeve case if this vault's own code calls `unlock()` again, or if the hook never calls the vault.

Settlement of a debt is atomic for that currency: sync, transfer or value, settle, then take credits. Do not `settleFor` a foreign address. Do not assume an outer actor's sync checkpoint remains valid. Do not clear another address's sync to hide a clobber. If the sequence cannot close this diamond's own touched deltas without taking a foreign credit, revert `SettlementMismatch()`.

Native borrowed settlement syncs native currency immediately before value settle. It does not double-count wrapped and native backing. It does not spend another actor's sync credit. Caller-facing amounts stay on the WETH face.

A failure reverts the vault call and its descendant effects. If the outer caller catches it, the vault state is restored and the caller still owes its own settlement. The catch does not relock the manager. There is no sleeve fallback.

Inclusion in a batch swap with other Uniswap V4 pools is not a revert. A funded non-hook contract that meets the borrowed checks succeeds. Do not add an allowlist.

### 12. Quotes and previews

The one quote engine is `FullSpreadOperationQuote`, an implementation name for the function in `UniswapV4FullSpreadStandardExchangeVaultProjection` that both preview and execution call. Execution does not keep a second formula. Neither calls the stored Quoter. Storing the Quoter address does not make it the product quote.

The engine returns the mathematical result of the operation: liquidity delta, swap input, swap output, direction, net shares, refund amounts, and exit claims. It does not transfer. It does not read a balance. It assumes the declaration is available. It does not apply an impact check. It does not stop at a fixed step count. It does not revert `QuoteWorkLimit`. Do not declare that error. Do not add a 64-step cap, a minimum tick spacing, or a partial-fill quote.

Preview and execution may differ in the refund word. Bit-exact refund equality is not required. The exit quote uses the same apportioning and the same swap as execution, so the quoted `amountOut` matches execution from the same economic state. That match is not waived by the refund sentence. A both-token quote does not swap. A mint preview uses the depositor's net shares under the clamped fee and does not credit existing fees to the new depositor.

`previewExchangeOut` returns zero and does not gain a refund word. A zero preview is not a promise that `exchangeOut` succeeds.

`previewExchangeIn`, `previewExchangeBundleInForSingleOut`, and `minAmountOut` use net shares. Unsupported view routes return zero, including while the manager is busy or unlocked.

Do not implement `getRate`, `rateAsset`, `exchangeRate`, `previewZapCredit`, or `previewWithdrawalMode`. Do not declare `InsufficientRateSupply`, `RateNormalizationOverflow`, or `RateUnavailable`. Do not bind `StandardExchangeRateProviderFacet` and call its result this family's rate.

Dust-tick liveness is inventory 041. Seed dust ticks and show that a normal deposit and redeem are not frozen. That test does not add a spacing rule.

### 13. Events and errors

Events this family emits:

- `PairDeposited(address indexed caller)` on a bundle deposit. No other arguments.
- `PairRedeemed(address indexed caller)` on a bundle redeem. No other arguments.
- `Donation()` on a successful `donate()`. No fields. Not an interface.
- `Compounded()` when a maintenance call deposits collected fees or booked tokens. No arguments.
- The existing `NewGlobalOperatorStatus` and `NewFunctionOperatorStatus` from `OperableRepo`.
- `Transfer` from `ERC20Repo._mint`, including the floor mint's `Transfer(address(0), address(0), 1_000)`.

Do not emit a vault swap event or a vault liquidity-add event. Do not add arguments to `Donation()` or `Compounded()`. A reverting call emits neither maintenance event.

Family errors, declared on the family interface. Compute their selectors at build. Do not invent the hex in this plan:

- `InvalidUnlockedContext()`
- `SettlementMismatch()`
- `ManagerAlreadyUnlocked()`
- `ReentrantOperation()`
- `InvalidRoute()`
- `MinLiquidityNotMet()`
- `InvalidRecipient()`

Use the family zero-argument `InvalidRoute()` for `tokenIn == tokenOut`. Do not call the existing `IStandardExchangeErrors.InvalidRoute(address,address)` for that guard. Do not delete that Crane error. Other vaults use it.

Use these existing errors. Do not redeclare them:

- `DeadlineExceeded(uint256,uint256)`
- `AmountOutNotMet(uint256,uint256)`
- `EOAPretransferNotAllowed()`
- `IVaultRegistryDisableQuery.VaultDisabled(address)`
- `IPoolManager.AlreadyUnlocked()`
- `IOperable.NotOperator(address)` for a failed maintenance check
- The accepted interface errors: `EmptyExchange`, `TokenNotExchangeable`, `ExchangeInNotAvailable`, `AmountsLengthMismatch`, `ExchangeBundleInForSingleOutNotAvailable`, `TokenAmountsLengthMismatch`, `DuplicateOutput`, `MinAmountNotMetAt`, `ExchangeBundleOutNotAvailable`

Do not declare `MinAmountNotMet`, `IncompleteConversion`, `QuoteWorkLimit`, `ExchangeInWithRefundNotAvailable`, `UnderlyingUnavailable`, `InsufficientRateSupply`, `RateNormalizationOverflow`, or `RateUnavailable`.

Bare `revert()`, with no error and no selector for the test to pin, is the failure for:

- a bundle pretransfer shortfall
- borrowed-path not initialized, not idle, nonempty callback hash, and nonzero reservation
- a nonzero own delta at borrowed entry
- `donate` when `totalSupply` is zero
- `unlockCallback` from any caller but the bound manager

The borrowed-path bare reverts are not `ReentrantOperation` and not `SettlementMismatch`. `SettlementMismatch` is only the close that cannot settle this diamond's own touched deltas without taking a foreign credit.

### 14. Operators

The owner address is `address(VaultFeeOracleQueryFacet(oracle).feeTo())`. The read returns `IFeeCollectorProxy`. The owner is that proxy's address. This vault does not expose `feeTo()`. The read is live on every appointment and every maintenance check. Do not cache it in the family slot.

`UniswapV4FullSpreadStandardExchangeVaultFeeToOwnerModifiers.onlyLiveFeeToOwner` gates `setOperator` and `setOperatorFor`. The caller must be the live owner. The guard function is `UniswapV4FullSpreadStandardExchangeVaultRepo._onlyLiveFeeToOwner`. It does not call `MultiStepOwnableRepo._onlyOwner`.

`UniswapV4FullSpreadStandardExchangeVaultMaintenanceModifiers.onlyLiveFeeToOwnerOrOperator` gates `donate` and `compound`. The three arms are:

1. `msg.sender` is the live `feeTo()` address.
2. `OperableRepo._isOperator(msg.sender)` is true.
3. `OperableRepo._isFunctionOperator(msg.sig, msg.sender)` is true.

A function operator for another selector fails. A global operator may call both maintenance functions. Any other caller reverts `NotOperator(msg.sender)`.

Only the live owner may appoint. A global operator cannot appoint. Initialization does not store `feeTo()` and does not appoint an operator. Do not install `OperableTarget`. Do not use `OperableModifiers.onlyOwnerOrOperator`.

### 15. Disable

The predicate is the live V2 call site, widened from `exchangeIn` to every execution route. Block a route whose input is not this vault's share. A withdrawal is share in and underlying out: `exchangeIn` with the share as `tokenIn`, and `exchangeBundleOut` with the share as `tokenIn` and the two ERC-20 faces as `tokensOut`. A pass-through `exchangeIn` reverts `VaultDisabled`. A bundle deposit reverts `VaultDisabled`. `donate` and `compound` are not in this block. Views do not revert `VaultDisabled`.

A missed deadline reverts `DeadlineExceeded` before this check. On an enabled vault, `exchangeOut` reverts `ExchangeOutNotAvailable()`. A disabled `exchangeOut` reverts `VaultDisabled`. The same predicate applies on a borrowed unlock. A buffered withdrawal still succeeds. A buffered non-withdrawal reverts `VaultDisabled` while the manager is unlocked. `exchangeBundleOut` while unlocked reverts `ManagerAlreadyUnlocked` even when it is a mapped withdrawal and the vault is disabled, because the unlocked check follows the disable exception.

Read `isDisabled(address(this))` on the bound oracle. Revert `IVaultRegistryDisableQuery.VaultDisabled(address(this))`. Do not copy the V2 file's deadline-after-disable order.

### 16. Hook integration, matrix rows, and 32-byte preview migration

Do not redesign a hook package. Do not add a hook-package field. Do not add `asset()`. A hook change is FS-HOOK-04, raised only with a cited rejecting function. The preview migration is not that redesign.

The hook configures an already supported `IStandardExchangeRateProviderDFPkg` instance per Standard Exchange liquidity leg. `PkgArgs` on that provider carries `reserveVault`, `rateSubject`, and `rateTarget`. This vault stores no rate-provider address and exposes no rate-provider getter. Do not add a cap on the number of instances. The required rows use the configured instance. They do not derive a provider from this vault. A missing provider on one of those rows is not closed by installing `getRate`, and it is not an FS-HOOK-04 incompatibility record.

Required rate rows: one for each underlying token, so the integrated token can be token0 or token1, and two pools that hold the same vault at different `rateTarget` values. The provider reads the tuple.

Families and what a pass proves:

| Family | Bind | Pass |
| --- | --- | --- |
| `single/` | One `standardExchange` and one `pairToken`. | One-vault borrowed `exchangeIn` through `beforeSwap`, both exact-input directions. Not a two-vault proof. |
| `constantProduct/single/` | One buffered SE, one pair token, one raw token. | FullSpread as the buffered leg. Name which leg converted. |
| `dual/` | Two SE arguments and two tokens. | The canonical cross-vault proof. |
| `orbital/` | `se0`, `se1`, `se2` and `rp0`, `rp1`, `rp2`. | A valid three-leg bind with FullSpread buffered on one leg and another SE share on another. Name the roles. |
| `weighted/` | Arrays, `n` in 2 through 8. | A 2-leg setup and one larger supported setup. |
| `stable/quad/curve/` | Fixed four-leg arrays. | Four valid legs. Do not treat a volatile share as a peg. |
| `stable/quad/balancer/` | Dynamic arrays, 2 through 5 legs. | A 2-leg setup and a 5-leg setup. Do not copy a fixed-four constructor. |

Canonical cross-vault fixture:

1. FullSpread is the buffered leg. The hook is configured with one external rate-provider instance for this vault and one rate target.
2. The other SE is not asked to mint or redeem inside the outer unlock. Its share may be an identity leg only if the current package accepts `token == se` without `asset()`. If it rejects, record that reject under FS-HOOK-04 and do not pass the identity bind. The other leg can still be a raw token or a share transfer the hook accepts without calling that vault.
3. The two backing pool keys differ. One direction mints FullSpread shares while the manager is unlocked. The reverse burns them. Assert balances, position owner, ticks, salt, and per-address deltas.
4. An identity-only share trade does not prove underlying entry or exit.
5. A both-buffered composition is optional and is not the required proof.

Two buffered legs that share one pair token and overwrite `standardExchangeOf[pair]` are not a required fixture. If the package cannot represent that bind, record it. Do not edit the hook to create it. Same-backing-pool sequential composition is not passed by the disjoint-pool fixture.

`exchangeOut` fails closed on this vault. A hook path that calls it pays neither token. Exact-input both directions means `zeroForOne` and `oneForZero`. Exact-out is not one of those directions.

If a required route cannot run: fix a full-spread money, preview, or context defect in this family; keep an intentional exact-output or budget rejection as a rejection; record a missing quote interface, an `asset()` requirement, a `SameToken` or pair-overlap reject, or an incompatible denomination other than the FS-OWN-29 rows under FS-HOOK-04. Name the consumer, selector, arguments, and revert. Do not implement that change here. Do not stub a transition quote. A cited reject does not close the canonical proof. It may close a family row only when that family's topology cannot express the fixture, and the record says so.

The seven behavior files exist. A row is a concrete contract beside the behavior. It extends that behavior and overrides `_newFixture()` to return a `SeMatrixFixture` for this vault. Add these files. Do not edit the behavior contracts' assertions for other families.

- `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`

Exact-output success rows cannot pass here. On an enabled vault, `exchangeOut` reverts `ExchangeOutNotAvailable()` and `previewExchangeOut` returns zero. A user's unused input is refunded. A donation or compound remainder is booked, so those rows stay. These are adaptations of this family's expected results, not permission to weaken the other families.

`docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json` has historical V4 FullSpread rows. Their cited tests are not current proof. Preserve the V3 rows. Replace the stale V4 FullSpread rows in `hook-se-matrix.json`, `hook-se-matrix-findings.json`, `hook-se-matrix-finding-descriptions.json`, `docs/audits/apex-2026-09-17-evidence.md`, and `docs/audits/apex-2026-09-17-evidence/acceptance.json` item R10.3. Do not treat those files as passed.

32-byte migration. Cite `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md`. It lists 1626 textual occurrences in 618 files. Do not paste it. It includes comments and names, so it is wider than the decoder list. Migrate every one-word reader and every typed call. A call that ignores the returned word still migrates. A comment-only hit is not a decoder.

These six gates reject a non-32-byte success. A 64-byte success is failure until each is migrated:

- `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol` lines 103-106 and 121-125
- `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderTarget.sol` lines 65-68
- `contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolHookTarget.sol` lines 437-444
- `contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolHookTarget.sol` lines 463-470
- `contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolHookTarget.sol` lines 474-481

These bindings still declare one word and migrate with the readers:

- `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` lines 45-48
- `frontend/apps/indexedex/app/insights/lib/insightsAbi.ts` lines 69-76
- `frontend/packages/protocol/src/protocolDetfAbi.ts` lines 33-40
- `contracts/test/bases/FundedThresholdAssertions.sol` lines 60-63

`exchangeIn` keeps `0xd02d3063` and returns the same tuple. Callers that decode one word from `exchangeIn` must read the tuple. Do not adopt the comment selector `0x05562cc8`. The ordinary exact-input hook path must show the existing ERC-165-gated fallback to standard previews. Do not stub a projected-state quote.

### 17. Test plan

Harness. The TestBase extends `IndexedexTest` and the canonical native-wrapper base, calls parent setups in the current order, and deploys the PoolManager through the existing artifact-backed CREATE3 helper. Facets and the package go through the current factory and manager paths. The hook and this vault bind that same manager. Bootstrap shares only through the accepted public entry routes. Reuse the current non-SUT mintable funding tokens. Do not mock, etch, `vm.mockCall`, or inject storage into this vault or the PoolManager.

Hermetic tests use the default Foundry profile, `viaIR=false`, and the current runtime and initcode limits. `recordLogs` is not a receipt. A snapshot restore asserts pre-state and post-state equality before restore. Compare supply, holder balances, both positions, booked and reserved custody, wrapper balances, and per-address deltas. Do not assert only that no tokens moved.

Crane tests for the Protocol Aware facet and `UniswapV4SinglePositionAware` are part of this directive. They assert the seven getters, the position getters, `positionLiquidity()` against `StateLibrary.getPositionInfo`, and that the family repo does not hold a second copy of those addresses.

Gas measurement:

- For each supported public money and maintenance call, measure a local cold call body. Reserve 100,000 gas for intrinsic transaction cost and the fixed money-method calldata. The measured body must not exceed 11,900,000. The release ceiling is 12,000,000 including that overhead, on Ethereum, Base, and Robinhood. This is not a gasprice constraint and not permission to raise a chain limit.
- Preview calls must not exceed 5,000,000 local gas. There is no `getRate` read in the measurement.
- A composed hook fixture is judged on the whole transaction. It must not exceed 12,000,000. Do not subtract the 100,000 from that composed measurement. If it exceeds 12,000,000, record the route unresolved. Do not mark it passed and do not waive it.
- The ceiling is a test measurement. Do not add a vault gas-reject error. Do not import the stage-one preflight work-error reject or its collection-only fallback. An out-of-gas revert is an EVM error. Views do not revert by a vault error.
- Deployment code and initcode limits stay separate. A multi-transaction deployment is not one money-operation budget.
- `Money.t.sol` records the non-composed body meter. `QuotesAndRate.t.sol` records the preview ceiling. `BufferHookIntegration.t.sol` records the composed-transaction meter.

FS-A map:

| Row | File |
| --- | --- |
| FS-A01 | `UniswapV4FullSpreadStandardExchangeVaultPackage.t.sol` |
| FS-A02 | `UniswapV4FullSpreadStandardExchangeVaultPackage.t.sol` |
| FS-A03 | `UniswapV4FullSpreadStandardExchangeVaultPackage.t.sol` |
| FS-A04 | `UniswapV4FullSpreadStandardExchangeVaultPackage.t.sol` |
| FS-A05 | `UniswapV4FullSpreadStandardExchangeVaultMoney.t.sol` |
| FS-A06 | `UniswapV4FullSpreadStandardExchangeVaultMoney.t.sol` |
| FS-A07 | `UniswapV4FullSpreadStandardExchangeVaultMoney.t.sol` |
| FS-A08 | `UniswapV4FullSpreadStandardExchangeVaultMoney.t.sol` |
| FS-A09 | `UniswapV4FullSpreadStandardExchangeVaultQuotesAndRate.t.sol` |
| FS-A10 | `UniswapV4FullSpreadStandardExchangeVaultNative.t.sol` |
| FS-A11 | `UniswapV4FullSpreadStandardExchangeVaultMoney.t.sol` |
| FS-A12 | `UniswapV4FullSpreadStandardExchangeVaultQuotesAndRate.t.sol` |
| FS-A13 | `UniswapV4FullSpreadStandardExchangeVaultQuotesAndRate.t.sol` |
| FS-A14 | `UniswapV4FullSpreadStandardExchangeVaultQuotesAndRate.t.sol` |
| FS-A15 | `UniswapV4FullSpreadStandardExchangeVaultQuotesAndRate.t.sol` |
| FS-A16 | `UniswapV4FullSpreadStandardExchangeVaultMoney.t.sol` |
| FS-A17 | `UniswapV4FullSpreadStandardExchangeVaultCallbacks.t.sol` |
| FS-A18 | `UniswapV4FullSpreadStandardExchangeVaultCallbacks.t.sol` |
| FS-A19 | `UniswapV4FullSpreadStandardExchangeVaultAlreadyUnlocked.t.sol` |
| FS-A20 | `UniswapV4FullSpreadStandardExchangeVaultAlreadyUnlocked.t.sol` |
| FS-A21 | `UniswapV4FullSpreadStandardExchangeVaultAlreadyUnlocked.t.sol` |
| FS-A22 | `UniswapV4FullSpreadStandardExchangeVaultAlreadyUnlocked.t.sol` |
| FS-A23 | `UniswapV4FullSpreadStandardExchangeVaultAlreadyUnlocked.t.sol` |
| FS-A24 | `UniswapV4FullSpreadStandardExchangeVaultBufferHookIntegration.t.sol` |
| FS-A25 | `UniswapV4FullSpreadStandardExchangeVaultBufferHookIntegration.t.sol` |
| FS-A26 | `UniswapV4FullSpreadStandardExchangeVaultBufferHookIntegration.t.sol` |
| FS-A27 | `UniswapV4FullSpreadStandardExchangeVaultBufferHookIntegration.t.sol` |
| FS-A28 | `UniswapV4FullSpreadStandardExchangeVaultBufferHookIntegration.t.sol` |
| FS-A29 | `UniswapV4FullSpreadStandardExchangeVaultBufferHookIntegration.t.sol` |
| FS-A30 | `UniswapV4FullSpreadStandardExchangeVaultBufferHookIntegration.t.sol` |
| FS-A31 | `UniswapV4FullSpreadStandardExchangeVaultBufferHookIntegration.t.sol` |
| FS-A32 | `UniswapV4FullSpreadStandardExchangeVaultQuotesAndRate.t.sol` |
| FS-A33 | `UniswapV4FullSpreadStandardExchangeVaultAlreadyUnlocked.t.sol` |
| FS-A34 | `UniswapV4FullSpreadStandardExchangeVaultAlreadyUnlocked.t.sol` |
| FS-A35 | `UniswapV4FullSpreadStandardExchangeVaultNative.t.sol` |
| FS-A36 | `UniswapV4FullSpreadStandardExchangeVaultAlreadyUnlocked.t.sol` |
| FS-A37 | `UniswapV4FullSpreadStandardExchangeVaultAlreadyUnlocked.t.sol` |
| FS-A38 | `UniswapV4FullSpreadStandardExchangeVaultMoney.t.sol` |
| FS-A39 | `UniswapV4FullSpreadStandardExchangeVaultPackage.t.sol` |

FS-A09 runs on an enabled vault. FS-A38 owns the disabled `exchangeOut` revert. FS-A38 also contains the buffered withdrawal and buffered non-withdrawal cases, with the manager unlocked inside that file. FS-A12 through FS-A15 assert the withdrawn selectors and errors are absent. They do not assert a vault rate. FS-A24 records an FS-HOOK-04 reject if the current package rejects `token == this vault` without `asset()`. It does not pass by adding `asset()`.

Inventory 010-054. Marks are the PRD marks. Expected results are the PRD rows, including the replaced 023, 024, 039, 044, 045, and 048 results. A "no" row has no test. It is not reopened.

| ID | Mark | File and result |
| --- | --- | --- |
| 010 | yes | `Money.t.sol`. A direct transfer is not redeemable idle and not caller credit. Disabling a retired vault is not this test. |
| 011 | yes | `Money.t.sol` for the own-unlock path and `AlreadyUnlocked.t.sol` for the borrowed path. Neither over-mints. Deletion of the old family is not evidence. |
| 012 | no | No test. Wings liquidation-quote pricing is absent. Not reopened. |
| 013 | yes | `Package.t.sol`. The generic ERC-4626 `deposit` selector is absent. A pre-existing balance does not mint shares. |
| 014 | integration only | `BufferHookIntegration.t.sol`. The rated-versus-face drain is hook code. The weighted, Curve, Balancer, and orbital rows must not treat this share as an unrated raw leg. |
| 015 | integration only | `BufferHookIntegration.t.sol`. Curve quad join and exit accounting is hook code. The matrix row is not a vault fix. |
| 016 | no | No test. Not reopened. |
| 017 | no | No test. Not reopened. |
| 018 | no | No test. Not reopened. |
| 019 | yes, as a negative | `QuotesAndRate.t.sol`. Enabled vault. `ExchangeOutNotAvailable`. Do not use a disabled vault as this fixture. |
| 020 | no | No test. Not reopened. |
| 021 | no | No test. Not reopened. |
| 022 | yes | `AlreadyUnlocked.t.sol`. The same borrowed-path loop as 011, named against both IDs. |
| 023 | yes | `Money.t.sol`. Permissionless sleeve placement is absent. Do not claim the authorized sandwich is gone. The authorized callers are the current `feeTo()` and an operator that owner appointed, global or function-level for that selector. A stranger reverts. |
| 024 | yes | `Money.t.sol`. A one-token exit swaps the FS-OWN-30 exiting claim only. It does not sell the staying holders' inventory. The unbounded limit stays. The absence test is the quantity, not a price check. |
| 025 | no | No test. Not reopened. |
| 026 | no separate Wings test | No Wings test. Dust-tick liveness is 041. Do not reopen a spacing rule. |
| 027 | no | No test. Not reopened. |
| 028 | yes | `BufferHookIntegration.t.sol`. A dual identity-leg attempt must not burn the caller's position and pay zero. |
| 029 | yes, as a negative | `QuotesAndRate.t.sol`. No `getRate()`. Not bound to the full-book provider. A pumped external provider is not a vault rate. |
| 030 | integration only | `BufferHookIntegration.t.sol`. Balancer quad phantom fee LP is pool code. The quad row is not a vault fix. |
| 031 | no | No test. Not reopened. |
| 032 | yes | `Package.t.sol`. Deployment through the shared factory leaves no unprivileged post-deploy selector. The temporary hook is removed. |
| 033 | no | No test. Not reopened. |
| 034 | yes | `Money.t.sol`. Direct transfers and the 1,000-share floor prevent first-deposit inflation. |
| 035 | no | No test. Not reopened. |
| 036 | yes | `BufferHookIntegration.t.sol`. Hook integration must not credit a staged pretransfer to a later caller. |
| 037 | no | No test. Not reopened. |
| 038 | no | No test. Not reopened. |
| 039 | yes | `Money.t.sol`. A pretransfer uses the unbooked balance up to the caller's maximum. It does not take parked shares or the whole sitting balance. A bundle whose declared maximum exceeds that token's unbooked balance reverts before any leg, spends nothing, and mints nothing. `expectRevert()` with no selector. Do not pin a new error. |
| 040 | yes | `Money.t.sol`. A pool donation followed by `compound` must not round a later deposit to dust shares. |
| 041 | yes | `QuotesAndRate.t.sol`. Seed dust ticks. A normal deposit and redeem are not frozen by an undocumented step cap. Do not add a cap or a minimum spacing. |
| 042 | yes | `Package.t.sol`. Deployment succeeds for a token whose `approve` returns no bool. No typed Permit2 approval is required. |
| 043 | integration only | `BufferHookIntegration.t.sol`. Orbital radius pinning is hook code. The orbital row is not a vault fix. |
| 044 | yes | `Money.t.sol`. Fee shares come out of the new shares. There is no extra mint. The vault clamps the fee at 30%. A round trip does not move existing holders' value to `feeTo`. Previews and `minAmountOut` use the net shares. |
| 045 | yes | `Money.t.sol`, the same cases as FS-A38. A disabled `exchangeOut` is this revert, not the 019 fixture. |
| 046 | no | No test. Not reopened. |
| 047 | no | No test. Not reopened. The nearest vault case is 040. |
| 048 | yes | `Money.t.sol`. `compound()` with no fees and no booked remainder returns unchanged and emits nothing. A deposit from collected fees or booked tokens emits `Compounded()` with no arguments. A successful `donate()` emits `Donation()` with no arguments. Pin both empty topics. A booked remainder does not freeze a later route. |
| 049 | yes, as a negative | `QuotesAndRate.t.sol`. Exact-out is absent. Enabled vault. The locked revert, not a Camelot equality check. |
| 050 | no | No test. Do not add a TWAP oracle. Not reopened. |
| 051 | yes | `QuotesAndRate.t.sol`. A preview that returns an amount is not rejected by an impact check that does not run. The shared engine is `FullSpreadOperationQuote`. That name is not a new audit ID and not a step cap. |
| 052 | yes | `Package.t.sol`. `permit` works for a standard signer after initialization. The EIP-712 name is `PkgArgs.name`. The version is `"1"`. That statement is not a new token. |
| 053 | no | No test. This plan does not change the manager. Not reopened. |
| 054 | yes | `BufferHookIntegration.t.sol`. Each required hook that unwraps this share approves the vault and completes the exit. A missing approval must not freeze the user. |

Operator appointment is FS-A39. It is not a new audit ID. The second-review tracker closes APEX-2026-011, 041, 042, and 051 by deleting the old FullSpread code. That deletion does not certify this vault. The yes rows above are the tests. The accepted sandwich of an owner or operator `compound()` or `donate()` is not tested as absent.

### 18. Traceability

| ID | Plan section |
| --- | --- |
| FS-X01 | 11 |
| FS-X02 | 12 |
| FS-X03 | 16 |
| FS-X04 | 9 |
| FS-OWN-01 | 4, 5, 7 |
| FS-OWN-02 | 4, 5, 6, 7 |
| FS-OWN-03 | 5, 7, 12 |
| FS-OWN-04 | 6, 9, 10 |
| FS-OWN-05 | 4, 7 |
| FS-OWN-06 | 5, 6, 7 |
| FS-OWN-07 | 7, 12 |
| FS-OWN-08 | 7, 12, 16 |
| FS-OWN-09 | 7, 9, 10, 13 |
| FS-OWN-10 | 5, 7, 12 |
| FS-OWN-11 | 6, 9 |
| FS-OWN-12 | 9, 10 |
| FS-OWN-13 | 8, 11 |
| FS-OWN-14 | 8, 10, 13, 14 |
| FS-OWN-15 | 9 |
| FS-OWN-16 | 5, 6 |
| FS-OWN-17 | 5, 6, 9 |
| FS-OWN-18 | 5, 6, 12 |
| FS-OWN-19 | 8, 12 |
| FS-OWN-20 | 6, 8, 9 |
| FS-OWN-21 | 8, 10 |
| FS-OWN-22 | 5, 7 |
| FS-OWN-23 | 7 |
| FS-OWN-24 | 9, 12 |
| FS-OWN-25 | 9 |
| FS-OWN-26 | 8, 15 |
| FS-OWN-27 | 6, 9 |
| FS-OWN-28 | 8, 15 |
| FS-OWN-29 | 12, 16 |
| FS-OWN-30 | 9, 12 |
| FS-OWN-31 | 11 |
| FS-OWN-32 | 8, 9 |
| FS-OWN-33 | 9, 10, 19 |
| FS-FACET-01 | 5, 7 |
| FS-FACET-02 | 4, 5, 7, 19 |
| FS-ARCH-01 | 4 |
| FS-PKG-01 | 5 |
| FS-PKG-02 | 5 |
| FS-MONEY-01 | 9, 17 |
| FS-UNLOCK-01 | 11 |
| FS-UNLOCK-02 | 8, 11 |
| FS-UNLOCK-03 | 11 |
| FS-RATE-01 | 12 |
| FS-HOOK-01 | 16 |
| FS-HOOK-02 | 16 |
| FS-HOOK-03 | 16 |
| FS-HOOK-04 | 16 |
| FS-TEST-01 | 17 |
| FS-TEST-02 | 4, 17 |
| FS-TEST-03 | 17 |
| FS-TEST-04 | 16, 17 |
| FS-A01 through FS-A39 | 17 |

### 19. Implementation names the PRD left open

Each item is a name. It is not a new requirement.

- Six architecture-address `PkgInit` fields, after the already named `poolManager`: `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, `universalRouter`.
- Two Crane facet input fields: `uniswapV4ProtocolAwareFacet`, `uniswapV4SinglePositionAwareFacet`.
- `multiAssetBasicVaultFacet` is the field name that replaces a single `basicVaultFacet`.
- `operableFacet` is the field name for the home of the locked `IOperable` selectors. The stock `OperableFacet` is not used.
- Modifier filenames: `UniswapV4FullSpreadStandardExchangeVaultFeeToOwnerModifiers.sol` with `onlyLiveFeeToOwner`, and `UniswapV4FullSpreadStandardExchangeVaultMaintenanceModifiers.sol` with `onlyLiveFeeToOwnerOrOperator`.
- Storage namespace: `indexedex.vaults.standard.exchange.uniswap.v4.fullSpread`, slotted as `keccak256(abi.encode(namespace)) - 1`.
- `SwapProjection` holds the already specified exact-input pool swap at `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`. It does not choose the FS-OWN-33 amounts. Those amounts are inputs.
- `ExecutionPreparation` holds the already specified per-action callback commitment and that action's own-delta settlement preparation. It does not choose amounts and it does not call `compound`.
- The temporary-hook facet filename is `PostDeployAccountHookFacet`, cited from `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol` line 31.
- The one quote engine shared by preview and execution is `FullSpreadOperationQuote`.
- `positionSalt()` is the getter name for the stored salt.
- The EIP-712 version initialized with `PkgArgs.name` is `"1"`.
- A failed maintenance check uses the existing `IOperable.NotOperator(address)`. That is not a new error.
- The FS-OWN-33 amount selection sits in `UniswapV4FullSpreadStandardExchangeVaultMath`. That placement keeps it out of the pass-through swap library.

## Limits

This response does not authorize implementation, a PRD edit, a test run, a deployment, or a Git change. No Forge run was performed. No selector hex was computed in this pass. Accepted hex and source-comment hex are cited, and interface ids are rechecked at build. The preview index was cited and not pasted. Peer responses were not read. Runtime identity and task ID were not exposed. The accepted sandwich of an owner or operator maintenance call remains. Disjoint-pool hook tests do not prove same-pool sequential safety.
