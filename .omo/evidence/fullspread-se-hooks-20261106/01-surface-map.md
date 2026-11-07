# Task 1 - deployed route inventory

Date: 2026-11-06. Static source discovery only. No build, test discovery command, test execution, RPC, deployment, Git command, or production/test edit was performed. "Installed" below means prescribed by the current package and facet source, not an observed live-chain loupe result. Parent owns baseline/source identity and the FS-A01-A48 ledger. This evidence does not close runtime or gas gates. The shared checkout may change concurrently; citations describe the source read for this inventory.

Authority: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`, revision `fullspread-se-prd-hook-fees-bootstrap-20261106`, especially FS-OWN-34-37, FS-HOOK-05-10 and FS-A40-48. Execution scope is `docs/research/se-fullspread-remediation-plan-20261106/IMPLEMENTATION_AND_TEST_PLAN.md`, task 1. The historical removal sentence in `CLAUDE.md:28` does not override the explicit execution request or current PRD.

## How to read this inventory

Each family defines a production directory and exact filename prefix P. `PDepositTarget.sol:50`, for example, expands to that directory plus the exact prefix plus `DepositTarget.sol:50`; `facets/` and `interfaces/` remain explicit. Other paths are repository-relative. HT = `test/foundry/spec/hooks/uniswap/v4/standardExchange/`; VT = `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`. Test destinations are places to extend/run, not asserted passing coverage. A selector signature retains Solidity interface type names (`IERC20`, `PoolKey`, `DetfQuoteCtx`) rather than fabricated hexadecimal selectors.

The independent expected surface comes from each product interface, inherited `IUniswapV4SeBufferHook`, `IDetfReserveQuote`, `IStandardExchangeIn/Out`, the Pendle `IStandardizedYield`, staged-init and H7 units interfaces. Actual installation is separately read from `facetFuncs`, appended selector helpers and initial/production/finalization cuts. Target-derived control is used for `ownerOnlyLiquidity`, which has no separate product-interface declaration. Optional sibling `IUniswapV4SeBufferHookClaimQuote/ClaimExitQuote` declarations are not incorrectly treated as inheritance of the main interface.

Route classes apply to every row:

| Code | Current behavior / remediation owner | Required test destination contract |
| --- | --- | --- |
| S | Retain selector, access checks, trading fee and family curve; supersede custody/reserve settlement with local + rated shares, local-first output, actual deficit redemption and disabled input local booking (FS-A41/42/45). H1 has conversion custody, not an LP curve. | Family Swap/owner/SE matrix cases, both exact-input directions, exact-output local-only versus actual unsupported SE call, refund/minimum/rollback. |
| J/E | Retain public ABI and guards; supersede joins with ceil component backing and caller-only conversions; exits with floor component allocation. Mint fees split gross accepted LP and previews/minima use net. T=0 rejects pair-funded SE legs and uses actual share-funded 5% redemption. SE/SY facade dispatch must reach the same installed join/exit routes (FS-A43-48). | Family Liquidity/Flexible/B6/SeBufferAbi/Native SY and matrix; fees/exact-net/bootstrap cases plus VT BufferHookIntegration. |
| E | Retain ABI and minima; allocate local + share claims before conversion, no growth mint or disabled cleanup deposit, share-requested conversion atomic failure when required disabled mint is unavailable (FS-A44/45/47). | Family exits/flexible/single/exact-output and VT unwrap cases; remaining-holder assertions. |
| Q | Retain installed view selector; replace retired growth-supply forecast. Publish reserves in their specified units while never using rated views as LP ownership. Invariant/radius/amp/weights needed by swap math are not automatically retired (FS-A41-48). | Family views/quote/dependent-rate/fee suites, integer oracle and preview-execution parity. |
| R | Retain discovery, config, guard callbacks, rewards and access-policy surfaces; no new LP product/fee for H1. Ownership/getter changes only if needed by the same accounting contract. | Family declaration, package, surface, lifecycle and negative guard cases. |

Every family route row inherits its family owner, code-specific accounting contract, and concrete test-destination list below. First implementation hop and direct internal/library calls are source observations, not a promise of successful execution.

## H1 - Task 6

Directory: `contracts/hooks/uniswap/v4/standardExchange/single/`. P = `UniswapV4SingleStandardExchangeBufferHook`. Product control: `contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHook.sol`.

Package installation: `PDFPkg.sol:118`. facets[0] = address(MULTI_ASSET_BASIC_VAULT_FACET); facets[1] = address(MULTI_ASSET_STANDARD_VAULT_FACET); facets[2] = address(SELF); facets[3] = address(PRODUCT_FACET);

Initial cuts and production replacement: `PDFPkg.sol:136` facetCuts; `PDFPkg.sol:155` productionFacetCuts; `PDFPkg.sol:230` postDeploy.

| Accounting class | Concrete test destinations under HT |
| --- | --- |
| S | single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol |
| J/E | single/UniswapV4SingleSEBufferHook_LiquidityBan.t.sol; single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol |
| E | single/UniswapV4SingleSEBufferHook_LiquidityBan.t.sol; single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol |
| Q | single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol; single/UniswapV4SingleSEBufferHook_VaultViews.t.sol |
| R | single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol; single/UniswapV4SingleSEBufferHook_VaultViews.t.sol |

| Selector control | Independent declaration | Installed facet / append site | Implementation path; direct helpers | Class |
| --- | --- | --- | --- | --- |
| `beforeInitialize(address,PoolKey,uint160)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:22` | `facets/PFacet.sol:34` | `PTarget.sol:59` (direct getter/guard) | R |
| `afterInitialize(address,PoolKey,uint160,int24)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:30` | `facets/PFacet.sol:35` | `PTarget.sol:68` (direct getter/guard) | R |
| `beforeAddLiquidity(address,PoolKey,ModifyLiquidityParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:40` | `facets/PFacet.sol:36` | `PTarget.sol:77` `_onlyPoolManager` | R |
| `afterAddLiquidity(address,PoolKey,ModifyLiquidityParams,BalanceDelta,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:56` | `facets/PFacet.sol:37` | `PTarget.sol:87` (direct getter/guard) | R |
| `beforeRemoveLiquidity(address,PoolKey,ModifyLiquidityParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:71` | `facets/PFacet.sol:38` | `PTarget.sol:98` (direct getter/guard) | R |
| `afterRemoveLiquidity(address,PoolKey,ModifyLiquidityParams,BalanceDelta,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:87` | `facets/PFacet.sol:39` | `PTarget.sol:107` (direct getter/guard) | R |
| `beforeSwap(address,PoolKey,SwapParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:104` | `facets/PFacet.sol:40` | `PTarget.sol:118` `_onlyPoolManager`, `_wrapZeroForOne`, `_pair`, `_se`, `_wrapExactIn`, `_wrapExactOut`, `_unwrapExactIn`, `_unwrapExactOut` | S |
| `afterSwap(address,PoolKey,SwapParams,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:116` | `facets/PFacet.sol:41` | `PTarget.sol:164` (direct getter/guard) | R |
| `beforeDonate(address,PoolKey,uint256,uint256,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:131` | `facets/PFacet.sol:42` | `PTarget.sol:173` (direct getter/guard) | R |
| `afterDonate(address,PoolKey,uint256,uint256,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:146` | `facets/PFacet.sol:43` | `PTarget.sol:182` (direct getter/guard) | R |
| `poolManager()` | `interfaces/IP.sol:15` | `facets/PFacet.sol:45` | `PCommon.sol:36` (direct getter/guard) | R |
| `standardExchange()` | `interfaces/IP.sol:16` | `facets/PFacet.sol:46` | `PCommon.sol:40` (direct getter/guard) | R |
| `pairToken()` | `interfaces/IP.sol:17` | `facets/PFacet.sol:47` | `PCommon.sol:44` (direct getter/guard) | R |
| `wrapper()` | `interfaces/IP.sol:19` | `facets/PFacet.sol:48` | `PCommon.sol:48` (direct getter/guard) | R |
| `currency0()` | `interfaces/IP.sol:22` | `facets/PFacet.sol:49` | `PCommon.sol:52` (direct getter/guard) | R |
| `currency1()` | `interfaces/IP.sol:23` | `facets/PFacet.sol:50` | `PCommon.sol:56` (direct getter/guard) | R |
| `poolFee()` | `interfaces/IP.sol:24` | `facets/PFacet.sol:51` | `PCommon.sol:60` (direct getter/guard) | R |
| `tickSpacingHint()` | `interfaces/IP.sol:25` | `facets/PFacet.sol:52` | `PCommon.sol:64` (direct getter/guard) | R |
| `sqrtPriceX96Hint()` | `interfaces/IP.sol:26` | `facets/PFacet.sol:53` | `PCommon.sol:68` (direct getter/guard) | R |
| `previewWrap(uint256)` | `interfaces/IP.sol:30` | `facets/PFacet.sol:55` | `PTarget.sol:263` `_requireNonZero`, `_se`, `_pair` | S |
| `previewWrapExactOut(uint256)` | `interfaces/IP.sol:33` | `facets/PFacet.sol:56` | `PTarget.sol:268` `_requireNonZero`, `_se`, `_pair` | S |
| `previewUnwrap(uint256)` | `interfaces/IP.sol:36` | `facets/PFacet.sol:57` | `PTarget.sol:273` `_requireNonZero`, `_se`, `_pair` | S |
| `previewUnwrapExactOut(uint256)` | `interfaces/IP.sol:39` | `facets/PFacet.sol:58` | `PTarget.sol:278` `_requireNonZero`, `_se`, `_pair` | S |
| `getHookPermissions()` | `interfaces/IP.sol:42` | `facets/PFacet.sol:59` | `PTarget.sol:36` (direct getter/guard) | R |


## H2 - Task 7

Directory: `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/`. P = `UniswapV4SingleStandardExchangeBufferConstantProductHook`. Product control: `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol`.

Package installation: `PDFPkg.sol:162`. facets[0] = address(MULTI_STEP_OWNABLE_FACET); facets[1] = address(MULTI_ASSET_BASIC_VAULT_FACET); facets[2] = address(MULTI_ASSET_STANDARD_VAULT_FACET); facets[3] = address(SELF); facets[4] = address(SE_FACET); facets[5] = address(DEPOSIT_FACET); facets[6] = address(WITHDRAW_FACET); facets[7] = address(ERC20_FACET); facets[8] = address(ERC5267_FACET); facets[9] = address(ERC2612_FACET); facets[10] = address(DEPOSIT_SINGLE_FACET); facets[11] = address(DEPOSIT_PREVIEW_FACET);

Initial cuts and production replacement: `PDFPkg.sol:188` facetCuts; `PDFPkg.sol:212` productionFacetCuts; `PDFPkg.sol:359` postDeploy.

| Accounting class | Concrete test destinations under HT |
| --- | --- |
| S | constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerOnlyLiquidity.t.sol; constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol; constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerDuringLock.t.sol |
| J/E | constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_Liquidity.t.sol; constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol; constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeBufferAbi.t.sol |
| E | constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_Liquidity.t.sol; constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol; constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeBufferAbi.t.sol |
| Q | constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol; constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeBufferAbi.t.sol; constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_Surface.t.sol |
| R | constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol; constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeBufferAbi.t.sol; constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_Surface.t.sol |

| Selector control | Independent declaration | Installed facet / append site | Implementation path; direct helpers | Class |
| --- | --- | --- | --- | --- |
| `deposit(uint256,uint256,address,uint256,uint256)` | `interfaces/IP.sol:103` | `facets/PDepositFacet.sol:35` | `PDepositTarget.sol:65` `PullLib.pullErc20Dual`, `_deposit` | J/E |
| `depositWithPermit2Signature(uint256,uint256,address,uint256,uint256,bytes)` | `interfaces/IP.sol:111` | `facets/PDepositFacet.sol:36` | `PDepositTarget.sol:77` `PullLib.pullPermit2SignatureDual`, `_deposit` | J/E |
| `depositWithPermit2Allowance(uint256,uint256,address,uint256,uint256)` | `interfaces/IP.sol:120` | `facets/PDepositFacet.sol:37` | `PDepositTarget.sol:96` `PullLib.pullPermit2AllowanceDual`, `_deposit` | J/E |
| `depositWithSeShares(uint256,uint256,address,uint256,uint256)` | `interfaces/IP.sol:155` | `facets/PDepositFacet.sol:38` | `PDepositTarget.sol:128` `PullLib.pullErc20Single`, `_depositWithSeShares` | J/E |
| `joinProportional(uint256[],address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:73` | `facets/PDepositFacet.sol:39` | `PDepositTarget.sol:21` `PullLib.pullErc20Dual`, `_deposit` | J/E |
| `joinUnbalanced(address[],uint256[],address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:85` | `facets/PDepositFacet.sol:40` | `PDepositTarget.sol:42` `_accumulateJoin`, `_requireFirstJoinFullBook`, `PullLib.pullErc20Single`, `_depositWithSeShares`, `PullLib.pullErc20Dual`, `_deposit` | J/E |
| `rateProviders()` | `interfaces/IP.sol:204` | `facets/PDepositFacet.sol:41` | `PDepositTarget.sol:114` (direct getter/guard) | R |
| `rateProvider(address)` | `interfaces/IP.sol:207` | `facets/PDepositFacet.sol:42` | `PDepositTarget.sol:121` (direct getter/guard) | R |
| `previewDepositWithSeShares(uint256,uint256)` | `interfaces/IP.sol:189` | `facets/PDepositFacet.sol:43` | `PDepositProjectionTarget.sol:110` `_previewSeClaimOfBal`, `ERC20Repo._totalSupply`, `_previewFirstMintSeShares`, `_previewLaterMintSeShares` | J/E |
| `previewJoinAfterDeposit(address,address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:24` | `facets/PDepositFacet.sol:44` | `PDepositProjectionTarget.sol:95` `ClaimLib.ratedClaimOfState`, `_supplyAfterProtocolMintForPairClaim`, `_singleShareZapState`, `_singleFinishDeposit` | J/E |
| `previewSwapAfterExchange(address,address,address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:19` | `facets/PDepositFacet.sol:45` | `PDepositProjectionTarget.sol:61` `_swapAtExternalState` | S |
| `previewBondAfterDeposit(address,address,address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:30` | `facets/PDepositFacet.sol:46` | `PDepositProjectionTarget.sol:70` `_isLive`, `ClaimLib.projectedClaimIn`, `_supplyAfterProtocolMintForPairClaim`, `_swapAtExternalState` | J/E |
| `previewDeposit(uint256,uint256)` | `interfaces/IP.sol:173` | `facets/PDepositFacet.sol:47` | `PDepositProjectionTarget.sol:42` `ERC20Repo._totalSupply`, `Math.mintSharesFirst`, `Math.toWad`, `_previewReserveAfterIntake`, `_clampToReserveRatio`, `Math.mintSharesLater`, `_previewRawDelta`, `_rawReserveCurrency0`, `_rawReserveCurrency1`, `_supplyAfterProtocolMint` | J/E |
| `previewJoinProportional(uint256[])` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:68` | `facets/PDepositFacet.sol:48` | `PDepositProjectionTarget.sol:17` (direct getter/guard) | J/E |
| `previewJoinUnbalanced(address[],uint256[])` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:80` | `facets/PDepositFacet.sol:49` | `PDepositProjectionTarget.sol:29` `_accumulateJoin`, `_isLive` | J/E |
| `previewDepositSingle(address,uint256)` | `interfaces/IP.sol:178` | `facets/PDepositPreviewFacet.sol:35` | `PDepositPreviewTarget.sol:77` `_singlePreviewDeposit` | J/E |
| `previewZapSplit(address,uint256)` | `interfaces/IP.sol:180` | `facets/PDepositPreviewFacet.sol:36` | `PDepositPreviewTarget.sol:127` `_previewZapSplit`, `ClaimLib.supportsTransitionQuote`, `_singleZapState` | R |
| `previewExchangeIn(IERC20,uint256,IERC20)` | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:46` | `facets/PDepositPreviewFacet.sol:37` | `PDepositPreviewTarget.sol:36` `_previewExchangeIn` | J/E |
| `previewJoinSingleAssetExactIn(address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:89` | `facets/PDepositPreviewFacet.sol:38` | `PDepositPreviewTarget.sol:50` `_singlePreviewJoin` | J/E |
| `previewJoinSingleAssetExactOut(address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:102` | `facets/PDepositPreviewFacet.sol:39` | `PDepositPreviewTarget.sol:55` `_isLive` | J/E |
| `previewClaimAfterJoin(uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:153` | `facets/PDepositPreviewFacet.sol:40` | `PDepositPreviewTarget.sol:81` `_singleZapState`, `_singleFinishDeposit`, `_supplyAfterProtocolMint`, `_quoteClaimSupplyAfterDust`, `_quotePairToRawAfterJoin` | J/E |
| `joinSingleAssetExactOut(address,uint256,address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:107` | `facets/PDepositPreviewFacet.sol:41` | `PDepositPreviewTarget.sol:64` `_isLive`, `_singlePreviewDeposit`, `_mintProtocolFeeIfNeeded`, `PullLib.pullErc20Single`, `_depositSingle` | J/E |
| `previewDeposit(address,uint256)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:148` | `facets/PDepositPreviewFacet.sol:42` | `contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol:10` `_previewExchangeIn` | J/E |
| `previewRedeem(address,uint256)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:153` | `facets/PDepositPreviewFacet.sol:43` | `contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol:15` `_previewExchangeIn` | E |
| `depositSingle(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:107` | `facets/PDepositSingleFacet.sol:34` | `PDepositSingleTarget.sol:64` `PullLib.pullErc20Single`, `_depositSingle` | J/E |
| `depositSingleWithPermit2Signature(address,uint256,address,uint256,uint256,bytes)` | `interfaces/IP.sol:128` | `facets/PDepositSingleFacet.sol:35` | `PDepositSingleTarget.sol:76` `PullLib.pullPermit2SignatureSingle`, `_depositSingle` | J/E |
| `depositSingleWithPermit2Allowance(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:137` | `facets/PDepositSingleFacet.sol:36` | `PDepositSingleTarget.sol:89` `PullLib.pullPermit2AllowanceSingle`, `_depositSingle` | J/E |
| `joinSingleAssetExactIn(address,uint256,address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:94` | `facets/PDepositSingleFacet.sol:37` | `PDepositSingleTarget.sol:55` `_joinLiquidityExactIn` | J/E |
| `exchangeIn(IERC20,uint256,IERC20,uint256,address,bool,uint256)` | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:62` | `facets/PDepositSingleFacet.sol:38` | `PDepositSingleTarget.sol:47` `LiquidityRoute.isLiquidityRoute`, `_exchangeIn`, `_swapExchangeIn` | J/E |
| `withdraw(uint256,address,uint256,uint256,uint256)` | `interfaces/IP.sol:145` | `facets/PWithdrawFacet.sol:33` | `PWithdrawTarget.sol:477` `_withdraw` | E |
| `withdrawSingle(uint256,address,address,uint256,uint256)` | `interfaces/IP.sol:149` | `facets/PWithdrawFacet.sol:34` | `PWithdrawTarget.sol:486` `_withdrawSingle` | E |
| `previewWithdraw(uint256)` | `interfaces/IP.sol:185` | `facets/PWithdrawFacet.sol:35` | `PWithdrawTarget.sol:640` `_supplyAfterProtocolMint`, `ERC20Repo._totalSupply`, `_orderAmounts`, `_previewUnwrapSe` | E |
| `previewWithdrawSingle(uint256,address)` | `interfaces/IP.sol:187` | `facets/PWithdrawFacet.sol:36` | `PWithdrawTarget.sol:681` `_singlePreviewExit` | E |
| `withdrawSeShares(uint256,address,uint256,uint256,uint256)` | `interfaces/IP.sol:164` | `facets/PWithdrawFacet.sol:37` | `PWithdrawTarget.sol:497` `_withdrawSeShares` | E |
| `previewWithdrawSeShares(uint256)` | `interfaces/IP.sol:194` | `facets/PWithdrawFacet.sol:38` | `PWithdrawTarget.sol:662` `_supplyAfterProtocolMint`, `ERC20Repo._totalSupply` | E |
| `exitProportional(uint256,address,uint256[],uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:117` | `facets/PWithdrawFacet.sol:39` | `PWithdrawTarget.sol:400` `_withdraw` | E |
| `previewExitProportional(uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:115` | `facets/PWithdrawFacet.sol:40` | `PWithdrawTarget.sol:417` (direct getter/guard) | E |
| `exitSingleAssetExactBptIn(address,uint256,address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:129` | `facets/PWithdrawFacet.sol:41` | `PWithdrawTarget.sol:425` `_withdrawSingle` | E |
| `previewExitSingleAssetExactBptIn(address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:124` | `facets/PWithdrawFacet.sol:42` | `PWithdrawTarget.sol:435` `_singlePreviewExit` | E |
| `exitSingleAssetExactTokenOut(address,uint256,address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:142` | `facets/PWithdrawFacet.sol:43` | `PWithdrawTarget.sol:443` `_withdrawSingle` | E |
| `previewExitSingleAssetExactTokenOut(address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:137` | `facets/PWithdrawFacet.sol:44` | `PWithdrawTarget.sol:457` (direct getter/guard) | E |
| `previewBurnToToken(uint256,address)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:38` | `facets/PWithdrawFacet.sol:45` | `PWithdrawTarget.sol:467` `ERC20Repo._totalSupply` | E |
| `beforeInitialize(address,PoolKey,uint160)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:22` | `facets/PSeFacet.sol:49` | `PSeTarget.sol:506` (direct getter/guard) | R |
| `afterInitialize(address,PoolKey,uint160,int24)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:30` | `facets/PSeFacet.sol:50` | `PSeTarget.sol:514` (direct getter/guard) | R |
| `beforeAddLiquidity(address,PoolKey,ModifyLiquidityParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:40` | `facets/PSeFacet.sol:51` | `PSeTarget.sol:523` `_onlyPoolManager` | R |
| `afterAddLiquidity(address,PoolKey,ModifyLiquidityParams,BalanceDelta,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:56` | `facets/PSeFacet.sol:52` | `PSeTarget.sol:533` (direct getter/guard) | R |
| `beforeRemoveLiquidity(address,PoolKey,ModifyLiquidityParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:71` | `facets/PSeFacet.sol:53` | `PSeTarget.sol:544` (direct getter/guard) | R |
| `afterRemoveLiquidity(address,PoolKey,ModifyLiquidityParams,BalanceDelta,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:87` | `facets/PSeFacet.sol:54` | `PSeTarget.sol:553` (direct getter/guard) | R |
| `beforeSwap(address,PoolKey,SwapParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:104` | `facets/PSeFacet.sol:55` | `PSeTarget.sol:564` `_onlyPoolManager`, `_requireLive`, `_swapExactInPm`, `_swapExactOutPm` | S |
| `afterSwap(address,PoolKey,SwapParams,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:116` | `facets/PSeFacet.sol:56` | `PSeTarget.sol:580` (direct getter/guard) | R |
| `beforeDonate(address,PoolKey,uint256,uint256,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:131` | `facets/PSeFacet.sol:57` | `PSeTarget.sol:589` (direct getter/guard) | R |
| `afterDonate(address,PoolKey,uint256,uint256,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:146` | `facets/PSeFacet.sol:58` | `PSeTarget.sol:598` (direct getter/guard) | R |
| `poolManager()` | `interfaces/IP.sol:80` | `facets/PSeFacet.sol:59` | `PSeTarget.sol:106` (direct getter/guard) | R |
| `feeOracle()` | `interfaces/IP.sol:81` | `facets/PSeFacet.sol:60` | `PSeTarget.sol:110` (direct getter/guard) | R |
| `permit2()` | `interfaces/IP.sol:82` | `facets/PSeFacet.sol:61` | `PSeTarget.sol:114` (direct getter/guard) | R |
| `standardExchange()` | `interfaces/IP.sol:83` | `facets/PSeFacet.sol:62` | `PSeTarget.sol:118` (direct getter/guard) | R |
| `pairToken()` | `interfaces/IP.sol:84` | `facets/PSeFacet.sol:63` | `PSeTarget.sol:122` (direct getter/guard) | R |
| `rawToken()` | `interfaces/IP.sol:85` | `facets/PSeFacet.sol:64` | `PSeTarget.sol:126` (direct getter/guard) | R |
| `currency0()` | `interfaces/IP.sol:86` | `facets/PSeFacet.sol:65` | `PSeTarget.sol:130` (direct getter/guard) | R |
| `currency1()` | `interfaces/IP.sol:87` | `facets/PSeFacet.sol:66` | `PSeTarget.sol:134` (direct getter/guard) | R |
| `rawReserve()` | `interfaces/IP.sol:90` | `facets/PSeFacet.sol:67` | `PSeTarget.sol:138` (direct getter/guard) | Q |
| `seClaimSupply()` | `interfaces/IP.sol:91` | `facets/PSeFacet.sol:68` | `PSeTarget.sol:142` `_seClaim` | Q |
| `reserveCurrency0()` | `interfaces/IP.sol:92` | `facets/PSeFacet.sol:73` | `PSeTarget.sol:146` `_reserveOfCurrency` | Q |
| `reserveCurrency1()` | `interfaces/IP.sol:93` | `facets/PSeFacet.sol:74` | `PSeTarget.sol:150` `_reserveOfCurrency` | Q |
| `isLive()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:30` | `facets/PSeFacet.sol:75` | `PSeTarget.sol:154` `_isLive` | R |
| `isZapEligible()` | `interfaces/IP.sol:94` | `facets/PSeFacet.sol:76` | `PSeTarget.sol:158` `_isZapEligible` | R |
| `tradingFeePercent()` | `interfaces/IP.sol:97` | `facets/PSeFacet.sol:77` | `PSeTarget.sol:162` (direct getter/guard) | R |
| `tradingFeeDenominator()` | `interfaces/IP.sol:98` | `facets/PSeFacet.sol:78` | `PSeTarget.sol:166` (direct getter/guard) | R |
| `dexSwapFeeAndFeeTo()` | `interfaces/IP.sol:99` | `facets/PSeFacet.sol:79` | `PSeTarget.sol:170` (direct getter/guard) | R |
| `kLast()` | `interfaces/IP.sol:100` | `facets/PSeFacet.sol:80` | `PSeTarget.sol:176` (direct getter/guard) | Q |
| `previewSwapExactIn(bool,uint256)` | `interfaces/IP.sol:199` | `facets/PSeFacet.sol:81` | `PSeTarget.sol:712` `_quoteExactInContext` | S |
| `previewSwapExactOut(bool,uint256)` | `interfaces/IP.sol:201` | `facets/PSeFacet.sol:82` | `PSeTarget.sol:720` `ClaimLib.quoteExactOutContext` | S |
| `ownerOnlyLiquidity()` | `PSeTarget.sol:102` (Target-derived) | `facets/PSeFacet.sol:83` | `PSeTarget.sol:102` (direct getter/guard) | R |
| `previewSynthetic(DetfQuoteCtx,address)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:33` | `facets/PSeFacet.sol:84` | `PSeTarget.sol:238` `_isLive` | Q |
| `previewExchangeOut(IERC20,IERC20,uint256)` | `lib/crane/contracts/interfaces/IStandardExchangeOut.sol:51` | `facets/PSeFacet.sol:85` | `PSeTarget.sol:732` `LiquidityRoute.isLiquidityRoute`, `LiquidityRoute.previewOut`, `_routeZeroForOne`, `_quoteExactOut` | J/E |
| `exchangeOut(IERC20,uint256,IERC20,uint256,address,bool,uint256)` | `lib/crane/contracts/interfaces/IStandardExchangeOut.sol:67` | `facets/PSeFacet.sol:86` | `PSeTarget.sol:742` `LiquidityRoute.isLiquidityRoute`, `LiquidityRoute.exchangeOut`, `_swapExchangeOut` | J/E |
| `getHookPermissions()` | `contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHook.sol:42` | `facets/PSeFacet.sol:87` | `PSeTarget.sol:487` (direct getter/guard) | R |
| `ownerSwapExactIn(address,address,uint256,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:48` | `facets/PSeFacet.sol:88` | `PSeTarget.sol:787` `_onlyHookOwner`, `_requireDeadline`, `_requireLive`, `_routeZeroForOne`, `_quoteExactInPlan`, `_securePull`, `_zeroForOneIsRawIn`, `ClaimLib.unwrapQuoted`, `_syncReserves`, `_payOwnerSwap` | S |
| `ownerSwapExactOut(address,address,uint256,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:56` | `facets/PSeFacet.sol:89` | `PSeTarget.sol:814` `_onlyHookOwner`, `_requireDeadline`, `_requireLive`, `_routeZeroForOne`, `_quoteExactOut`, `_securePull`, `_payOwnerSwap` | S |
| `tokens()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:14` | `facets/PSeFacet.sol:90` | `PSeTarget.sol:180` (direct getter/guard) | R |
| `standardExchangeOf(address)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:16` | `facets/PSeFacet.sol:91` | `PSeTarget.sol:186` (direct getter/guard) | R |
| `syntheticNumeraires()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:24` | `facets/PSeFacet.sol:92` | `PSeTarget.sol:190` (direct getter/guard) | R |
| `requiredFirstBondTokens()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:26` | `facets/PSeFacet.sol:93` | `PSeTarget.sol:195` (direct getter/guard) | R |
| `firstJoinMustBeFullBook()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:28` | `facets/PSeFacet.sol:94` | `PSeTarget.sol:199` (direct getter/guard) | J/E |
| `tradingFeeWad()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:32` | `facets/PSeFacet.sol:95` | `PSeTarget.sol:203` (direct getter/guard) | R |
| `previewSwapExactIn(address,address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:38` | `facets/PSeFacet.sol:96` | `PSeTarget.sol:207` `_isLive`, `_tryRouteZeroForOne`, `_quoteExactInContext` | S |
| `previewSwapExactOut(address,address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:43` | `facets/PSeFacet.sol:97` | `PSeTarget.sol:218` `_isLive`, `_tryRouteZeroForOne`, `ClaimLib.quoteExactOutContext` | S |
| `deposit(address,address,uint256,uint256)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:68` | `facets/PDepositSingleFacet.sol:39` via `_appendMoney` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:18` `_standardRoute` | J/E |
| `redeem(address,uint256,address,uint256,bool)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:86` | `facets/PDepositSingleFacet.sol:39` via `_appendMoney` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:30` `_requireVaultHeldShares`, `_redeemVaultHeld`, `_standardRoute` | E |
| `exchangeRate()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:101` | `facets/PWithdrawFacet.sol:46` via `_appendDiscovery` | `PWithdrawTarget.sol:741` `_supplyAfterProtocolMint`, `Math.sqrt`, `_wadProduct` | Q |
| `yieldToken()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:132` | `facets/PWithdrawFacet.sol:46` via `_appendDiscovery` | `PWithdrawTarget.sol:737` (direct getter/guard) | R |
| `assetInfo()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:165` | `facets/PWithdrawFacet.sol:46` via `_appendDiscovery` | `PWithdrawTarget.sol:738` (direct getter/guard) | R |
| `getTokensIn()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:137` | `facets/PWithdrawFacet.sol:46` via `_appendDiscovery` | `PWithdrawTarget.sol:745` (direct getter/guard) | R |
| `getTokensOut()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:142` | `facets/PWithdrawFacet.sol:46` via `_appendDiscovery` | `PWithdrawTarget.sol:752` (direct getter/guard) | R |
| `isValidTokenIn(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:144` | `facets/PWithdrawFacet.sol:46` via `_appendDiscovery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:7` (direct getter/guard) | R |
| `isValidTokenOut(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:146` | `facets/PWithdrawFacet.sol:46` via `_appendDiscovery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:8` (direct getter/guard) | R |
| `getRewardTokens()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:127` | `facets/PWithdrawFacet.sol:46` via `_appendDiscovery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:27` (direct getter/guard) | R |
| `accruedRewards(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:118` | `facets/PWithdrawFacet.sol:46` via `_appendDiscovery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:28` (direct getter/guard) | R |
| `rewardIndexesStored()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:122` | `facets/PWithdrawFacet.sol:46` via `_appendDiscovery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:29` (direct getter/guard) | R |
| `rewardIndexesCurrent()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:120` | `facets/PWithdrawFacet.sol:47` via `_appendRewards` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:78` (direct getter/guard) | R |
| `claimRewards(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:111` | `facets/PWithdrawFacet.sol:47` via `_appendRewards` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:79` (direct getter/guard) | R |


## H3 - Task 8

Directory: `contracts/hooks/uniswap/v4/standardExchange/dual/`. P = `UniswapV4DualStandardExchangeBufferConstantProductHook`. Product control: `contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol`.

Package installation: `PDFPkg.sol:156`. facets[0] = address(MULTI_ASSET_BASIC_VAULT_FACET); facets[1] = address(MULTI_ASSET_STANDARD_VAULT_FACET); facets[2] = address(SELF); facets[3] = address(HOOKS_FACET); facets[4] = address(DEPOSIT_FACET); facets[5] = address(WITHDRAW_FACET); facets[6] = address(SE_FACET); facets[7] = address(ERC20_FACET); facets[8] = address(ERC5267_FACET); facets[9] = address(ERC2612_FACET);

Initial cuts and production replacement: `PDFPkg.sol:180` facetCuts; `PDFPkg.sol:199` productionFacetCuts; `PDFPkg.sol:345` postDeploy.

| Accounting class | Concrete test destinations under HT |
| --- | --- |
| S | dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol; dual/UniswapV4DualSEBCPHook_Swap.t.sol; dual/decimals/UniswapV4DualSEBCPHook_Swap_D_U18_U6.t.sol |
| J/E | dual/UniswapV4DualSEBCPHook_SeBufferAbi.t.sol; dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol; dual/UniswapV4DualSEBCPHook_B6M3.t.sol |
| E | dual/UniswapV4DualSEBCPHook_SeBufferAbi.t.sol; dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol; dual/UniswapV4DualSEBCPHook_B6M3.t.sol |
| Q | dual/UniswapV4DualSEBCPHook_SeBufferAbi.t.sol; dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol; dual/UniswapV4DualSEBCPHook_Surface.t.sol |
| R | dual/UniswapV4DualSEBCPHook_SeBufferAbi.t.sol; dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol; dual/UniswapV4DualSEBCPHook_Surface.t.sol |

| Selector control | Independent declaration | Installed facet / append site | Implementation path; direct helpers | Class |
| --- | --- | --- | --- | --- |
| `deposit(uint256,uint256,address,uint256,uint256)` | `interfaces/IP.sol:104` | `facets/PDepositFacet.sol:27` | `PDepositTarget.sol:50` `_pullErc20Dual`, `_deposit` | J/E |
| `depositSingle(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:112` | `facets/PDepositFacet.sol:28` | `PDepositTarget.sol:62` `_pullErc20Single`, `_depositSingle` | J/E |
| `depositWithPermit2Signature(uint256,uint256,address,uint256,uint256,bytes)` | `interfaces/IP.sol:120` | `facets/PDepositFacet.sol:29` | `PDepositTarget.sol:74` `_pullPermit2SignatureDual`, `_deposit` | J/E |
| `depositWithPermit2Allowance(uint256,uint256,address,uint256,uint256)` | `interfaces/IP.sol:129` | `facets/PDepositFacet.sol:30` | `PDepositTarget.sol:87` `_pullPermit2AllowanceDual`, `_deposit` | J/E |
| `depositSingleWithPermit2Signature(address,uint256,address,uint256,uint256,bytes)` | `interfaces/IP.sol:137` | `facets/PDepositFacet.sol:31` | `PDepositTarget.sol:99` `_pullPermit2SignatureSingle`, `_depositSingle` | J/E |
| `depositSingleWithPermit2Allowance(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:146` | `facets/PDepositFacet.sol:32` | `PDepositTarget.sol:112` `_pullPermit2AllowanceSingle`, `_depositSingle` | J/E |
| `previewDeposit(uint256,uint256)` | `interfaces/IP.sol:186` | `facets/PDepositFacet.sol:33` | `PDepositTarget.sol:157` `_previewDeposit` | J/E |
| `previewDepositSingle(address,uint256)` | `interfaces/IP.sol:191` | `facets/PDepositFacet.sol:34` | `PDepositTarget.sol:166` `_previewDepositSingle` | J/E |
| `previewZapSplit(address,uint256)` | `interfaces/IP.sol:196` | `facets/PDepositFacet.sol:35` | `PDepositTarget.sol:175` `_previewZapSplit` | R |
| `depositFlexible(uint256,bool,uint256,bool,address,uint256,uint256)` | `interfaces/IP.sol:164` | `facets/PDepositFacet.sol:36` | `PDepositTarget.sol:124` `_pullFlexible`, `_deposit`, `_requireDeadline`, `_requireNonZero`, `_mintProtocolFeeIfNeeded`, `_depositFlexibleSe` | J/E |
| `previewDepositFlexible(uint256,bool,uint256,bool)` | `interfaces/IP.sol:206` | `facets/PDepositFacet.sol:37` | `PDepositTarget.sol:184` `_previewDepositFlexible` | J/E |
| `joinProportional(uint256[],address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:73` | `facets/PDepositFacet.sol:38` | `PDepositTarget.sol:202` `_isLive`, `_pullErc20Dual`, `_deposit` | J/E |
| `previewJoinProportional(uint256[])` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:68` | `facets/PDepositFacet.sol:39` | `PDepositTarget.sol:222` `_previewDeposit` | J/E |
| `joinUnbalanced(address[],uint256[],address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:85` | `facets/PDepositFacet.sol:40` | `PDepositTarget.sol:237` `_accumulateJoin`, `_requireFirstJoinFullBook`, `_joinAcc` | J/E |
| `previewJoinUnbalanced(address[],uint256[])` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:80` | `facets/PDepositFacet.sol:41` | `PDepositTarget.sol:249` `_accumulateJoin`, `_isLive`, `_previewDeposit`, `_previewDepositFlexible`, `_previewJoinOneLeg` | J/E |
| `joinSingleAssetExactIn(address,uint256,address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:94` | `facets/PDepositFacet.sol:42` | `PDepositTarget.sol:267` `_joinLiquidityExactIn` | J/E |
| `previewJoinSingleAssetExactIn(address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:89` | `facets/PDepositFacet.sol:43` | `PDepositTarget.sol:277` `_previewLiquidityJoin` | J/E |
| `joinSingleAssetExactOut(address,uint256,address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:107` | `facets/PDepositFacet.sol:44` | `PDepositTarget.sol:285` (direct getter/guard) | J/E |
| `previewJoinSingleAssetExactOut(address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:102` | `facets/PDepositFacet.sol:45` | `PDepositTarget.sol:300` (direct getter/guard) | J/E |
| `beforeInitialize(address,PoolKey,uint160)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:22` | `facets/PHooksFacet.sol:45` | `PHooksTarget.sol:160` (direct getter/guard) | R |
| `afterInitialize(address,PoolKey,uint160,int24)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:30` | `facets/PHooksFacet.sol:46` | `PHooksTarget.sol:169` (direct getter/guard) | R |
| `beforeAddLiquidity(address,PoolKey,ModifyLiquidityParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:40` | `facets/PHooksFacet.sol:47` | `PHooksTarget.sol:179` `_onlyPoolManager` | R |
| `afterAddLiquidity(address,PoolKey,ModifyLiquidityParams,BalanceDelta,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:56` | `facets/PHooksFacet.sol:48` | `PHooksTarget.sol:190` (direct getter/guard) | R |
| `beforeRemoveLiquidity(address,PoolKey,ModifyLiquidityParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:71` | `facets/PHooksFacet.sol:49` | `PHooksTarget.sol:202` (direct getter/guard) | R |
| `afterRemoveLiquidity(address,PoolKey,ModifyLiquidityParams,BalanceDelta,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:87` | `facets/PHooksFacet.sol:50` | `PHooksTarget.sol:212` (direct getter/guard) | R |
| `beforeSwap(address,PoolKey,SwapParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:104` | `facets/PHooksFacet.sol:51` | `PHooksTarget.sol:224` `_onlyPoolManager`, `_requireLive`, `_swapExactIn`, `_swapExactOut`, `_syncReserves` | S |
| `afterSwap(address,PoolKey,SwapParams,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:116` | `facets/PHooksFacet.sol:52` | `PHooksTarget.sol:241` (direct getter/guard) | R |
| `beforeDonate(address,PoolKey,uint256,uint256,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:131` | `facets/PHooksFacet.sol:53` | `PHooksTarget.sol:251` (direct getter/guard) | R |
| `afterDonate(address,PoolKey,uint256,uint256,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:146` | `facets/PHooksFacet.sol:54` | `PHooksTarget.sol:261` (direct getter/guard) | R |
| `poolManager()` | `interfaces/IP.sol:76` | `facets/PHooksFacet.sol:55` | `PHooksTarget.sol:53` (direct getter/guard) | R |
| `feeOracle()` | `interfaces/IP.sol:77` | `facets/PHooksFacet.sol:56` | `PHooksTarget.sol:58` (direct getter/guard) | R |
| `permit2()` | `interfaces/IP.sol:78` | `facets/PHooksFacet.sol:57` | `PHooksTarget.sol:63` (direct getter/guard) | R |
| `standardExchange0()` | `interfaces/IP.sol:79` | `facets/PHooksFacet.sol:58` | `PHooksTarget.sol:68` (direct getter/guard) | R |
| `standardExchange1()` | `interfaces/IP.sol:80` | `facets/PHooksFacet.sol:59` | `PHooksTarget.sol:73` (direct getter/guard) | R |
| `token0()` | `interfaces/IP.sol:81` | `facets/PHooksFacet.sol:60` | `PHooksTarget.sol:78` (direct getter/guard) | R |
| `token1()` | `interfaces/IP.sol:82` | `facets/PHooksFacet.sol:61` | `PHooksTarget.sol:83` (direct getter/guard) | R |
| `currency0()` | `interfaces/IP.sol:83` | `facets/PHooksFacet.sol:62` | `PHooksTarget.sol:88` (direct getter/guard) | R |
| `currency1()` | `interfaces/IP.sol:84` | `facets/PHooksFacet.sol:63` | `PHooksTarget.sol:93` (direct getter/guard) | R |
| `claimSupply0()` | `interfaces/IP.sol:91` | `facets/PHooksFacet.sol:64` | `PCommon.sol:130` `_claimSupply` | Q |
| `claimSupply1()` | `interfaces/IP.sol:92` | `facets/PHooksFacet.sol:69` | `PCommon.sol:135` `_claimSupply` | Q |
| `claimSupplyCurrency0()` | `interfaces/IP.sol:93` | `facets/PHooksFacet.sol:70` | `PCommon.sol:140` `_claimSupply`, `_seFor` | Q |
| `claimSupplyCurrency1()` | `interfaces/IP.sol:94` | `facets/PHooksFacet.sol:71` | `PCommon.sol:145` `_claimSupply`, `_seFor` | Q |
| `tradingFeePercent()` | `interfaces/IP.sol:97` | `facets/PHooksFacet.sol:72` | `PHooksTarget.sol:111` (direct getter/guard) | R |
| `tradingFeeDenominator()` | `interfaces/IP.sol:98` | `facets/PHooksFacet.sol:73` | `PHooksTarget.sol:116` (direct getter/guard) | R |
| `dexSwapFee()` | `interfaces/IP.sol:99` | `facets/PHooksFacet.sol:74` | `PHooksTarget.sol:121` (direct getter/guard) | R |
| `feeTo()` | `interfaces/IP.sol:100` | `facets/PHooksFacet.sol:75` | `PHooksTarget.sol:128` (direct getter/guard) | R |
| `kLast()` | `interfaces/IP.sol:101` | `facets/PHooksFacet.sol:76` | `PHooksTarget.sol:135` (direct getter/guard) | Q |
| `previewSwapExactIn(bool,uint256)` | `interfaces/IP.sol:218` | `facets/PHooksFacet.sol:77` | `PHooksTarget.sol:271` `_previewSwapExactIn` | S |
| `previewSwapExactOut(bool,uint256)` | `interfaces/IP.sol:223` | `facets/PHooksFacet.sol:78` | `PHooksTarget.sol:280` `_requireNonZero`, `_requireLive`, `ClaimLib.quoteExactOutContext` | S |
| `getHookPermissions()` | `contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHook.sol:42` | `facets/PHooksFacet.sol:79` | `PHooksTarget.sol:140` (direct getter/guard) | R |
| `tokens()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:14` | `facets/PHooksFacet.sol:80` | `PHooksTarget.sol:290` (direct getter/guard) | R |
| `standardExchangeOf(address)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:16` | `facets/PHooksFacet.sol:81` | `PHooksTarget.sol:296` (direct getter/guard) | R |
| `syntheticNumeraires()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:24` | `facets/PHooksFacet.sol:82` | `PHooksTarget.sol:300` (direct getter/guard) | R |
| `requiredFirstBondTokens()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:26` | `facets/PHooksFacet.sol:83` | `PHooksTarget.sol:306` (direct getter/guard) | R |
| `firstJoinMustBeFullBook()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:28` | `facets/PHooksFacet.sol:84` | `PHooksTarget.sol:310` (direct getter/guard) | J/E |
| `isLive()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:30` | `facets/PHooksFacet.sol:85` | `PHooksTarget.sol:314` `_isLive` | R |
| `tradingFeeWad()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:32` | `facets/PHooksFacet.sol:86` | `PHooksTarget.sol:318` (direct getter/guard) | R |
| `previewSwapExactIn(address,address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:38` | `facets/PHooksFacet.sol:87` | `PHooksTarget.sol:322` `_isLive`, `_tryRouteZeroForOne`, `_previewSwapExactIn` | S |
| `previewSwapExactOut(address,address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:43` | `facets/PHooksFacet.sol:88` | `PHooksTarget.sol:333` `_isLive`, `_tryRouteZeroForOne`, `ClaimLib.quoteExactOutContext` | S |
| `previewSynthetic(DetfQuoteCtx,address)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:33` | `facets/PHooksFacet.sol:89` | `PHooksTarget.sol:345` `_classify` | Q |
| `rateProviders()` | `interfaces/IP.sol:86` | `facets/PHooksFacet.sol:90` | `PHooksTarget.sol:98` (direct getter/guard) | R |
| `rateProvider(address)` | `interfaces/IP.sol:88` | `facets/PHooksFacet.sol:91` | `PHooksTarget.sol:106` `ClaimLib.rateProviderOf` | R |
| `ownerSwapExactOut(address,address,uint256,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:56` | `facets/PSeFacet.sol:35` | `PSeTarget.sol:156` `_requireDeadline`, `_requireNonZero`, `_requireLive`, `_tryRouteZeroForOne`, `_classify`, `_planExactOut`, `_securePull`, `_executePlannedSwap` | S |
| `exchangeIn(IERC20,uint256,IERC20,uint256,address,bool,uint256)` | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:62` | `facets/PSeFacet.sol:36` | `PSeTarget.sol:65` `LiquidityRoute.isLiquidityRoute`, `_exchangeIn`, `_swapExchangeIn` | J/E |
| `previewExchangeOut(IERC20,IERC20,uint256)` | `lib/crane/contracts/interfaces/IStandardExchangeOut.sol:51` | `facets/PSeFacet.sol:37` | `PSeTarget.sol:96` `LiquidityRoute.isLiquidityRoute`, `LiquidityRoute.previewOut`, `_routeZeroForOne`, `_previewSwapExactOut` | J/E |
| `exchangeOut(IERC20,uint256,IERC20,uint256,address,bool,uint256)` | `lib/crane/contracts/interfaces/IStandardExchangeOut.sol:67` | `facets/PSeFacet.sol:38` | `PSeTarget.sol:107` `LiquidityRoute.isLiquidityRoute`, `LiquidityRoute.exchangeOut`, `_swapExchangeOut` | J/E |
| `ownerSwapExactIn(address,address,uint256,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:48` | `facets/PSeFacet.sol:39` | `PSeTarget.sol:134` `_requireDeadline`, `_requireNonZero`, `_requireLive`, `_tryRouteZeroForOne`, `_classify`, `_planExactIn`, `_securePull`, `_executePlannedSwap` | S |
| `withdraw(uint256,address,uint256,uint256,uint256)` | `interfaces/IP.sol:154` | `facets/PWithdrawFacet.sol:30` | `PWithdrawTarget.sol:76` `_withdraw` | E |
| `previewWithdraw(uint256)` | `interfaces/IP.sol:201` | `facets/PWithdrawFacet.sol:31` | `PWithdrawTarget.sol:102` `_previewWithdraw` | E |
| `withdrawFlexible(uint256,address,bool,bool,uint256,uint256,uint256)` | `interfaces/IP.sol:175` | `facets/PWithdrawFacet.sol:32` | `PWithdrawTarget.sol:87` `_withdrawFlexible` | E |
| `previewWithdrawFlexible(uint256,bool,bool)` | `interfaces/IP.sol:213` | `facets/PWithdrawFacet.sol:33` | `PWithdrawTarget.sol:111` `_previewWithdrawFlexible` | E |
| `exitProportional(uint256,address,uint256[],uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:117` | `facets/PWithdrawFacet.sol:34` | `PWithdrawTarget.sol:119` `_withdraw` | E |
| `previewExitProportional(uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:115` | `facets/PWithdrawFacet.sol:35` | `PWithdrawTarget.sol:133` `_previewWithdraw` | E |
| `exitSingleAssetExactBptIn(address,uint256,address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:129` | `facets/PWithdrawFacet.sol:36` | `PWithdrawTarget.sol:140` `_exitLiquidityExactIn` | E |
| `previewExitSingleAssetExactBptIn(address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:124` | `facets/PWithdrawFacet.sol:37` | `PWithdrawTarget.sol:150` `_previewLiquidityExit` | E |
| `exitSingleAssetExactTokenOut(address,uint256,address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:142` | `facets/PWithdrawFacet.sol:38` | `PWithdrawTarget.sol:158` (direct getter/guard) | E |
| `previewExitSingleAssetExactTokenOut(address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:137` | `facets/PWithdrawFacet.sol:39` | `PWithdrawTarget.sol:173` (direct getter/guard) | E |
| `previewBurnToToken(uint256,address)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:38` | `facets/PWithdrawFacet.sol:40` | `PWithdrawTarget.sol:184` `_isLive`, `_classify`, `_previewWithdraw` | E |
| `previewExchangeIn(IERC20,uint256,IERC20)` | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:46` | `facets/PWithdrawFacet.sol:41` | `PWithdrawTarget.sol:70` `_previewExchangeIn` | J/E |
| `deposit(address,address,uint256,uint256)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:68` | `facets/PSeFacet.sol:40` via `_appendExecution` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:18` `_standardRoute` | J/E |
| `redeem(address,uint256,address,uint256,bool)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:86` | `facets/PSeFacet.sol:40` via `_appendExecution` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:30` `_requireVaultHeldShares`, `_redeemVaultHeld`, `_standardRoute` | E |
| `rewardIndexesCurrent()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:120` | `facets/PSeFacet.sol:40` via `_appendExecution` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:78` (direct getter/guard) | R |
| `claimRewards(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:111` | `facets/PSeFacet.sol:40` via `_appendExecution` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:79` (direct getter/guard) | R |
| `exchangeRate()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:101` | `facets/PWithdrawFacet.sol:42` via `_appendQuery` | `PWithdrawTarget.sol:66` `_supplyAfterProtocolMint`, `Math.sqrt`, `_wadProduct` | Q |
| `yieldToken()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:132` | `facets/PWithdrawFacet.sol:42` via `_appendQuery` | `PWithdrawTarget.sol:62` (direct getter/guard) | R |
| `assetInfo()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:165` | `facets/PWithdrawFacet.sol:42` via `_appendQuery` | `PWithdrawTarget.sol:63` (direct getter/guard) | R |
| `getTokensIn()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:137` | `facets/PWithdrawFacet.sol:42` via `_appendQuery` | `PWithdrawTarget.sol:53` (direct getter/guard) | R |
| `getTokensOut()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:142` | `facets/PWithdrawFacet.sol:42` via `_appendQuery` | `PWithdrawTarget.sol:61` (direct getter/guard) | R |
| `isValidTokenIn(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:144` | `facets/PWithdrawFacet.sol:42` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:7` (direct getter/guard) | R |
| `isValidTokenOut(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:146` | `facets/PWithdrawFacet.sol:42` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:8` (direct getter/guard) | R |
| `previewDeposit(address,uint256)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:148` | `facets/PWithdrawFacet.sol:42` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol:10` `_previewExchangeIn` | J/E |
| `previewRedeem(address,uint256)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:153` | `facets/PWithdrawFacet.sol:42` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol:15` `_previewExchangeIn` | E |
| `getRewardTokens()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:127` | `facets/PWithdrawFacet.sol:42` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:27` (direct getter/guard) | R |
| `accruedRewards(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:118` | `facets/PWithdrawFacet.sol:42` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:28` (direct getter/guard) | R |
| `rewardIndexesStored()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:122` | `facets/PWithdrawFacet.sol:42` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:29` (direct getter/guard) | R |


## H4 - Task 9

Directory: `contracts/hooks/uniswap/v4/standardExchange/orbital/`. P = `UniswapV4StandardExchangeOrbitalBufferHook`. Product control: `contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol`.

Package installation: `PDFPkg.sol:158`. facets[0] = address(MULTI_STEP_OWNABLE_FACET); facets[1] = address(MULTI_ASSET_BASIC_VAULT_FACET); facets[2] = address(MULTI_ASSET_STANDARD_VAULT_FACET); facets[3] = address(SELF); facets[4] = address(HOOKS_FACET); facets[5] = address(DEPOSIT_FACET); facets[6] = address(WITHDRAW_FACET); facets[7] = address(SE_FACET); facets[8] = address(ERC20_FACET); facets[9] = address(ERC5267_FACET); facets[10] = address(ERC2612_FACET); facets[11] = address(DEPOSIT_QUERY_FACET); facets[12] = address(DEPOSIT_ZAP_FACET);

Initial cuts and production replacement: `PDFPkg.sol:185` facetCuts; `PDFPkg.sol:189` productionFacetCuts; `PDFPkg.sol:193` _facetCuts; `PDFPkg.sol:336` postDeploy.

| Accounting class | Concrete test destinations under HT |
| --- | --- |
| S | orbital/UniswapV4StandardExchangeOrbitalBufferHook_OwnerOnlyLiquidity.t.sol; orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol; orbital/UniswapV4StandardExchangeOrbitalBufferHook_OwnerDuringLock.t.sol |
| J/E | orbital/UniswapV4StandardExchangeOrbitalBufferHook_Liquidity.t.sol; orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeBufferAbi.t.sol; orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol |
| E | orbital/UniswapV4StandardExchangeOrbitalBufferHook_Liquidity.t.sol; orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeBufferAbi.t.sol; orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol |
| Q | orbital/UniswapV4StandardExchangeOrbitalBufferHook_PackageDecl.t.sol; orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeBufferAbi.t.sol; orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol |
| R | orbital/UniswapV4StandardExchangeOrbitalBufferHook_PackageDecl.t.sol; orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeBufferAbi.t.sol; orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol |

| Selector control | Independent declaration | Installed facet / append site | Implementation path; direct helpers | Class |
| --- | --- | --- | --- | --- |
| `addLiquidity(uint256,uint256,uint256,address,uint256,uint256,bytes)` | `interfaces/IP.sol:152` | `facets/PDepositFacet.sol:31` | `PDepositTarget.sol:10` `_entryAddLiquidity` | R |
| `depositFlexible(uint256,bool,uint256,bool,uint256,bool,address,uint256,uint256)` | `interfaces/IP.sol:196` | `facets/PDepositFacet.sol:32` | `PDepositTarget.sol:24` `_entryDepositFlexible` | J/E |
| `joinProportional(uint256[],address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:73` | `facets/PDepositFacet.sol:33` | `PDepositTarget.sol:38` `_entryJoinProportional` | J/E |
| `joinUnbalanced(address[],uint256[],address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:85` | `facets/PDepositFacet.sol:34` | `PDepositTarget.sol:47` `_entryJoinUnbalanced` | J/E |
| `previewAddLiquidity(uint256,uint256,uint256)` | `interfaces/IP.sol:125` | `facets/PDepositQueryFacet.sol:35` | `PDepositQueryTarget.sol:61` `_entryPreviewAddLiquidity` | R |
| `previewDepositSingle(address,uint256)` | `interfaces/IP.sol:135` | `facets/PDepositQueryFacet.sol:36` | `PDepositQueryTarget.sol:69` `_entryPreviewDepositSingle` | J/E |
| `previewZapSplit(address,uint256)` | `interfaces/IP.sol:140` | `facets/PDepositQueryFacet.sol:37` | `PDepositQueryTarget.sol:77` `_entryPreviewZapSplit` | R |
| `previewDepositFlexible(uint256,bool,uint256,bool,uint256,bool)` | `interfaces/IP.sol:226` | `facets/PDepositQueryFacet.sol:38` | `PDepositQueryTarget.sol:85` `_entryPreviewDepositFlexible` | J/E |
| `previewJoinProportional(uint256[])` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:68` | `facets/PDepositQueryFacet.sol:39` | `PDepositQueryTarget.sol:96` `_entryPreviewJoinProportional` | J/E |
| `previewJoinUnbalanced(address[],uint256[])` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:80` | `facets/PDepositQueryFacet.sol:40` | `PDepositQueryTarget.sol:104` `_entryPreviewJoinUnbalanced` | J/E |
| `previewJoinSingleAssetExactIn(address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:89` | `facets/PDepositQueryFacet.sol:41` | `PDepositQueryTarget.sol:112` `_entryPreviewJoinSingleAssetExactIn` | J/E |
| `previewJoinSingleAssetExactOut(address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:102` | `facets/PDepositQueryFacet.sol:42` | `PDepositQueryTarget.sol:120` `_entryPreviewJoinSingleAssetExactOut` | J/E |
| `radius()` | `interfaces/IP.sol:112` | `facets/PDepositQueryFacet.sol:43` | `PDepositQueryTarget.sol:57` (direct getter/guard) | Q |
| `previewJoinAfterDeposit(address,address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:24` | `facets/PDepositQueryFacet.sol:44` | `PDepositQueryTarget.sol:43` `_isLive`, `_requireZapEligibleOrOwnerMin` | J/E |
| `previewBondAfterDeposit(address,address,address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:30` | `facets/PDepositQueryFacet.sol:45` | `PDepositQueryTarget.sol:51` (direct getter/guard) | J/E |
| `previewExchangeIn(IERC20,uint256,IERC20)` | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:46` | `facets/PDepositQueryFacet.sol:46` | `PDepositQueryTarget.sol:39` `_previewExchangeIn` | J/E |
| `depositSingle(address,uint256,address,uint256,uint256,bytes)` | `interfaces/IP.sol:167` | `facets/PDepositZapFacet.sol:34` | `PDepositZapTarget.sol:10` `_entryDepositSingle` | J/E |
| `joinSingleAssetExactIn(address,uint256,address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:94` | `facets/PDepositZapFacet.sol:35` | `PDepositZapTarget.sol:21` `_entryJoinSingleAssetExactIn` | J/E |
| `joinSingleAssetExactOut(address,uint256,address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:107` | `facets/PDepositZapFacet.sol:36` | `PDepositZapTarget.sol:31` `_entryJoinSingleAssetExactOut` | J/E |
| `previewExchangeOut(IERC20,IERC20,uint256)` | `lib/crane/contracts/interfaces/IStandardExchangeOut.sol:51` | `facets/PDepositZapFacet.sol:37` | `PSeTarget.sol:260` `_entryPreviewExchangeOut` | J/E |
| `exchangeOut(IERC20,uint256,IERC20,uint256,address,bool,uint256)` | `lib/crane/contracts/interfaces/IStandardExchangeOut.sol:67` | `facets/PDepositZapFacet.sol:38` | `PSeTarget.sol:261` `_entryExchangeOut` | J/E |
| `beforeInitialize(address,PoolKey,uint160)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:22` | `facets/PHooksFacet.sol:39` | `PHooksTarget.sol:212` (direct getter/guard) | R |
| `afterInitialize(address,PoolKey,uint160,int24)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:30` | `facets/PHooksFacet.sol:40` | `PHooksTarget.sol:222` (direct getter/guard) | R |
| `beforeAddLiquidity(address,PoolKey,ModifyLiquidityParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:40` | `facets/PHooksFacet.sol:41` | `PHooksTarget.sol:232` `_onlyPoolManager` | R |
| `afterAddLiquidity(address,PoolKey,ModifyLiquidityParams,BalanceDelta,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:56` | `facets/PHooksFacet.sol:42` | `PHooksTarget.sol:243` (direct getter/guard) | R |
| `beforeRemoveLiquidity(address,PoolKey,ModifyLiquidityParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:71` | `facets/PHooksFacet.sol:43` | `PHooksTarget.sol:255` `_onlyPoolManager` | R |
| `afterRemoveLiquidity(address,PoolKey,ModifyLiquidityParams,BalanceDelta,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:87` | `facets/PHooksFacet.sol:44` | `PHooksTarget.sol:266` (direct getter/guard) | R |
| `beforeSwap(address,PoolKey,SwapParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:104` | `facets/PHooksFacet.sol:45` | `PHooksTarget.sol:278` `_onlyPoolManager`, `_lock`, `_isBound`, `_unlock`, `_feeOracle`, `Math.MathDomain`, `_swapExactInExecute`, `_swapExactOutExecute`, `_take`, `_seOf` | S |
| `afterSwap(address,PoolKey,SwapParams,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:116` | `facets/PHooksFacet.sol:46` | `PHooksTarget.sol:329` (direct getter/guard) | R |
| `beforeDonate(address,PoolKey,uint256,uint256,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:131` | `facets/PHooksFacet.sol:47` | `PHooksTarget.sol:339` (direct getter/guard) | R |
| `afterDonate(address,PoolKey,uint256,uint256,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:146` | `facets/PHooksFacet.sol:48` | `PHooksTarget.sol:349` (direct getter/guard) | R |
| `poolManager()` | `interfaces/IP.sol:92` | `facets/PHooksFacet.sol:49` | `PHooksTarget.sol:66` (direct getter/guard) | R |
| `feeOracle()` | `interfaces/IP.sol:93` | `facets/PHooksFacet.sol:50` | `PHooksTarget.sol:71` (direct getter/guard) | R |
| `token0()` | `interfaces/IP.sol:94` | `facets/PHooksFacet.sol:51` | `PHooksTarget.sol:53` `_bindingToken0` | R |
| `token1()` | `interfaces/IP.sol:95` | `facets/PHooksFacet.sol:52` | `PHooksTarget.sol:54` `_bindingToken1` | R |
| `token2()` | `interfaces/IP.sol:96` | `facets/PHooksFacet.sol:53` | `PHooksTarget.sol:55` `_bindingToken2` | R |
| `standardExchange(uint8)` | `interfaces/IP.sol:97` | `facets/PHooksFacet.sol:54` | `PHooksTarget.sol:76` (direct getter/guard) | R |
| `rateProvider(uint8)` | `interfaces/IP.sol:98` | `facets/PHooksFacet.sol:55` | `PHooksTarget.sol:81` (direct getter/guard) | R |
| `isBuffered(uint8)` | `interfaces/IP.sol:103` | `facets/PHooksFacet.sol:56` | `PHooksTarget.sol:102` (direct getter/guard) | R |
| `lSquared()` | `interfaces/IP.sol:113` | `facets/PHooksFacet.sol:57` | `PHooksTarget.sol:152` (direct getter/guard) | Q |
| `previewSwapAfterExchange(address,address,address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:19` | `facets/PHooksFacet.sol:58` | `PHooksTarget.sol:417` `_previewSwapAfterExchange` | S |
| `rawReserve(uint8)` | `interfaces/IP.sol:106` | `facets/PHooksFacet.sol:59` | `PHooksTarget.sol:112` (direct getter/guard) | Q |
| `seBalance(uint8)` | `interfaces/IP.sol:107` | `facets/PHooksFacet.sol:60` | `PHooksTarget.sol:120` (direct getter/guard) | R |
| `seClaim(uint8)` | `interfaces/IP.sol:108` | `facets/PHooksFacet.sol:61` | `PHooksTarget.sol:128` `ClaimLib.effectiveNative` | Q |
| `effectiveReserve(uint8)` | `interfaces/IP.sol:109` | `facets/PHooksFacet.sol:62` | `PHooksTarget.sol:137` `_effectiveNativeAt` | Q |
| `effectiveReserves()` | `interfaces/IP.sol:110` | `facets/PHooksFacet.sol:63` | `PHooksTarget.sol:142` `_effectiveNativeAt` | Q |
| `dexSwapFee()` | `interfaces/IP.sol:114` | `facets/PHooksFacet.sol:64` | `PHooksTarget.sol:157` (direct getter/guard) | R |
| `usageFee()` | `interfaces/IP.sol:115` | `facets/PHooksFacet.sol:65` | `PHooksTarget.sol:162` (direct getter/guard) | R |
| `feeTo()` | `interfaces/IP.sol:116` | `facets/PHooksFacet.sol:66` | `PHooksTarget.sol:167` (direct getter/guard) | R |
| `kLast()` | `interfaces/IP.sol:117` | `facets/PHooksFacet.sol:67` | `PHooksTarget.sol:172` (direct getter/guard) | Q |
| `kLastMode()` | `interfaces/IP.sol:118` | `facets/PHooksFacet.sol:68` | `PHooksTarget.sol:177` (direct getter/guard) | Q |
| `permit2()` | `interfaces/IP.sol:104` | `facets/PHooksFacet.sol:69` | `PHooksTarget.sol:107` (direct getter/guard) | R |
| `pairPoolTickSpacing()` | `interfaces/IP.sol:120` | `facets/PHooksFacet.sol:70` | `PHooksTarget.sol:182` (direct getter/guard) | R |
| `pairPoolSqrtPriceX96()` | `interfaces/IP.sol:121` | `facets/PHooksFacet.sol:71` | `PHooksTarget.sol:187` (direct getter/guard) | R |
| `isZapEligible()` | `interfaces/IP.sol:123` | `facets/PHooksFacet.sol:72` | `PHooksTarget.sol:56` `_bindingIsZapEligible` | R |
| `previewSwapExactIn(address,address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:38` | `facets/PHooksFacet.sol:73` | `PHooksTarget.sol:359` `_isLive`, `_previewSwapExactInContext`, `_feeOracle` | S |
| `previewSwapExactOut(address,address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:43` | `facets/PHooksFacet.sol:74` | `PHooksTarget.sol:370` `_isLive`, `ClaimLib.previewSwapExactOutContext`, `_feeOracle` | S |
| `getHookPermissions()` | `contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHook.sol:42` | `facets/PHooksFacet.sol:75` | `PHooksTarget.sol:192` (direct getter/guard) | R |
| `tokens()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:14` | `facets/PHooksFacet.sol:76` | `PHooksTarget.sol:380` (direct getter/guard) | R |
| `standardExchangeOf(address)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:16` | `facets/PHooksFacet.sol:77` | `PHooksTarget.sol:388` (direct getter/guard) | R |
| `syntheticNumeraires()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:24` | `facets/PHooksFacet.sol:78` | `PHooksTarget.sol:392` (direct getter/guard) | R |
| `requiredFirstBondTokens()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:26` | `facets/PHooksFacet.sol:79` | `PHooksTarget.sol:405` (direct getter/guard) | R |
| `firstJoinMustBeFullBook()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:28` | `facets/PHooksFacet.sol:80` | `PHooksTarget.sol:409` (direct getter/guard) | J/E |
| `isLive()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:30` | `facets/PHooksFacet.sol:81` | `PHooksTarget.sol:57` `_bindingIsLive` | R |
| `tradingFeeWad()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:32` | `facets/PHooksFacet.sol:82` | `PHooksTarget.sol:413` (direct getter/guard) | R |
| `previewSynthetic(DetfQuoteCtx,address)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:33` | `facets/PHooksFacet.sol:83` | `PHooksTarget.sol:423` `_isLive`, `_resolveNumeraire`, `ClaimLib.previewSyntheticBook` | Q |
| `ownerOnlyLiquidity()` | `PHooksTarget.sol:62` (Target-derived) | `facets/PHooksFacet.sol:84` | `PHooksTarget.sol:62` (direct getter/guard) | R |
| `rateProviders()` | `interfaces/IP.sol:100` | `facets/PHooksFacet.sol:85` | `PHooksTarget.sol:86` (direct getter/guard) | R |
| `rateProvider(address)` | `interfaces/IP.sol:102` | `facets/PHooksFacet.sol:86` | `PHooksTarget.sol:93` (direct getter/guard) | R |
| `ownerSwapExactIn(address,address,uint256,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:48` | `facets/PHooksFacet.sol:87` | `PSeTarget.sol:267` `_entryOwnerSwapExactIn` | S |
| `ownerSwapExactOut(address,address,uint256,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:56` | `facets/PHooksFacet.sol:88` | `PSeTarget.sol:268` `_entryOwnerSwapExactOut` | S |
| `exchangeIn(IERC20,uint256,IERC20,uint256,address,bool,uint256)` | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:62` | `facets/PSeFacet.sol:35` | `PSeTarget.sol:254` `_entryExchangeIn` | J/E |
| `deposit(address,address,uint256,uint256)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:68` | `facets/PSeFacet.sol:36` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:18` `_standardRoute` | J/E |
| `redeem(address,uint256,address,uint256,bool)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:86` | `facets/PSeFacet.sol:37` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:30` `_requireVaultHeldShares`, `_redeemVaultHeld`, `_standardRoute` | E |
| `removeLiquidity(uint256,address,uint256,uint256,uint256,uint256)` | `interfaces/IP.sol:181` | `facets/PWithdrawFacet.sol:47` | `PWithdrawTarget.sol:54` `_removeLiquidity` | R |
| `previewRemoveLiquidity(uint256)` | `interfaces/IP.sol:130` | `facets/PWithdrawFacet.sol:48` | `PWithdrawTarget.sol:66` `_previewRemoveLiquidity` | R |
| `withdrawFlexible(uint256,address,bool,bool,bool,uint256,uint256,uint256,uint256)` | `interfaces/IP.sol:214` | `facets/PWithdrawFacet.sol:49` | `PWithdrawTarget.sol:75` `_withdrawFlexible` | E |
| `previewWithdrawFlexible(uint256,bool,bool,bool)` | `interfaces/IP.sol:235` | `facets/PWithdrawFacet.sol:50` | `PWithdrawTarget.sol:99` `_previewWithdrawFlexible` | E |
| `exitProportional(uint256,address,uint256[],uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:117` | `facets/PWithdrawFacet.sol:51` | `PWithdrawTarget.sol:108` `_removeLiquidity` | E |
| `previewExitProportional(uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:115` | `facets/PWithdrawFacet.sol:52` | `PWithdrawTarget.sol:125` `ERC20Repo._totalSupply`, `_previewRemoveLiquidity` | E |
| `exitSingleAssetExactBptIn(address,uint256,address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:129` | `facets/PWithdrawFacet.sol:53` | `PWithdrawTarget.sol:137` `_exitLiquidityExactIn` | E |
| `previewExitSingleAssetExactBptIn(address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:124` | `facets/PWithdrawFacet.sol:54` | `PWithdrawTarget.sol:147` `_previewLiquidityExit` | E |
| `exitSingleAssetExactTokenOut(address,uint256,address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:142` | `facets/PWithdrawFacet.sol:55` | `PWithdrawTarget.sol:157` (direct getter/guard) | E |
| `previewExitSingleAssetExactTokenOut(address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:137` | `facets/PWithdrawFacet.sol:56` | `PWithdrawTarget.sol:171` (direct getter/guard) | E |
| `previewBurnToToken(uint256,address)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:38` | `facets/PWithdrawFacet.sol:57` | `PWithdrawTarget.sol:176` `ERC20Repo._totalSupply`, `_isLive`, `_resolveBurnTokenOut`, `_previewRemoveLiquidity`, `_tryPreviewSwap` | E |
| `exchangeRate()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:101` | `facets/PDepositQueryFacet.sol:47` via `_appendQuery` | `PDepositQueryTarget.sol:32` `_previewProtocolMintShares`, `_effectiveWad`, `_measureK` | Q |
| `yieldToken()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:132` | `facets/PDepositQueryFacet.sol:47` via `_appendQuery` | `PDepositQueryTarget.sol:28` (direct getter/guard) | R |
| `assetInfo()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:165` | `facets/PDepositQueryFacet.sol:47` via `_appendQuery` | `PDepositQueryTarget.sol:29` (direct getter/guard) | R |
| `getTokensIn()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:137` | `facets/PDepositQueryFacet.sol:47` via `_appendQuery` | `PDepositQueryTarget.sol:15` (direct getter/guard) | R |
| `getTokensOut()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:142` | `facets/PDepositQueryFacet.sol:47` via `_appendQuery` | `PDepositQueryTarget.sol:27` (direct getter/guard) | R |
| `isValidTokenIn(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:144` | `facets/PDepositQueryFacet.sol:47` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:7` (direct getter/guard) | R |
| `isValidTokenOut(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:146` | `facets/PDepositQueryFacet.sol:47` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:8` (direct getter/guard) | R |
| `previewDeposit(address,uint256)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:148` | `facets/PDepositQueryFacet.sol:47` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol:10` `_previewExchangeIn` | J/E |
| `previewRedeem(address,uint256)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:153` | `facets/PDepositQueryFacet.sol:47` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol:15` `_previewExchangeIn` | E |
| `getRewardTokens()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:127` | `facets/PDepositQueryFacet.sol:47` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:27` (direct getter/guard) | R |
| `accruedRewards(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:118` | `facets/PDepositQueryFacet.sol:47` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:28` (direct getter/guard) | R |
| `rewardIndexesStored()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:122` | `facets/PDepositQueryFacet.sol:47` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:29` (direct getter/guard) | R |
| `rewardIndexesCurrent()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:120` | `facets/PDepositQueryFacet.sol:48` via `_appendRewards` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:78` (direct getter/guard) | R |
| `claimRewards(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:111` | `facets/PDepositQueryFacet.sol:48` via `_appendRewards` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:79` (direct getter/guard) | R |


## H5 - Task 10

Directory: `contracts/hooks/uniswap/v4/standardExchange/weighted/`. P = `UniswapV4StandardExchangeWeightedBufferHook`. Product control: `contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol`.

Package installation: `PDFPkg.sol:168`. facets[0] = address(MULTI_STEP_OWNABLE_FACET); facets[1] = address(MULTI_ASSET_BASIC_VAULT_FACET); facets[2] = address(MULTI_ASSET_STANDARD_VAULT_FACET); facets[3] = address(SELF); facets[4] = address(HOOKS_FACET); facets[5] = address(JOIN_FACET); facets[6] = address(EXIT_FACET); facets[7] = address(SE_FACET); facets[8] = address(ERC20_FACET); facets[9] = address(ERC5267_FACET); facets[10] = address(ERC2612_FACET); facets[11] = address(JOIN_QUERY_FACET); facets[12] = address(EXIT_QUERY_FACET); facets[13] = address(JOIN_FLEXIBLE_FACET);

Initial cuts and production replacement: `PDFPkg.sol:196` facetCuts; `PDFPkg.sol:200` productionFacetCuts; `PDFPkg.sol:205` _facetCuts; `PDFPkg.sol:345` postDeploy.

| Accounting class | Concrete test destinations under HT |
| --- | --- |
| S | weighted/UniswapV4StandardExchangeWeightedBufferHook_OwnerOnlyLiquidity.t.sol; weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol; weighted/UniswapV4StandardExchangeWeightedBufferHook_OwnerDuringLock.t.sol |
| J/E | weighted/UniswapV4StandardExchangeWeightedBufferHook_Liquidity.t.sol; weighted/UniswapV4StandardExchangeWeightedBufferHook_SeBufferAbi.t.sol; weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol |
| E | weighted/UniswapV4StandardExchangeWeightedBufferHook_Liquidity.t.sol; weighted/UniswapV4StandardExchangeWeightedBufferHook_SeBufferAbi.t.sol; weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol |
| Q | weighted/UniswapV4StandardExchangeWeightedBufferHook_SeBufferAbi.t.sol; weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol; weighted/UniswapV4StandardExchangeWeightedBufferHook_VaultViews.t.sol |
| R | weighted/UniswapV4StandardExchangeWeightedBufferHook_SeBufferAbi.t.sol; weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol; weighted/UniswapV4StandardExchangeWeightedBufferHook_VaultViews.t.sol |

| Selector control | Independent declaration | Installed facet / append site | Implementation path; direct helpers | Class |
| --- | --- | --- | --- | --- |
| `exitProportional(uint256,address,uint256[],uint256)` | `interfaces/IP.sol:281` | `facets/PExitFacet.sol:31` | `PExitTarget.sol:12` `_entryExitProportional` | E |
| `exitSingleAssetExactBptIn(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:285` | `facets/PExitFacet.sol:32` | `PExitTarget.sol:21` `_entryExitSingleAssetExactBptIn` | E |
| `exitSingleAssetExactTokenOut(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:293` | `facets/PExitFacet.sol:33` | `PExitTarget.sol:41` `_entryExitSingleAssetExactTokenOut` | E |
| `withdrawSingle(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:309` | `facets/PExitFacet.sol:34` | `PExitTarget.sol:31` `_entryWithdrawSingle` | E |
| `withdrawSingleExactOut(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:317` | `facets/PExitFacet.sol:35` | `PExitTarget.sol:51` `_entryWithdrawSingleExactOut` | E |
| `exitProportionalFlexible(uint256,address,bool[],uint256[],uint256)` | `interfaces/IP.sol:337` | `facets/PExitFacet.sol:36` | `PExitTarget.sol:61` `_entryExitProportionalFlexible` | E |
| `exitSingleAssetExactBptInFlexible(address,uint256,bool,address,uint256,uint256)` | `interfaces/IP.sol:363` | `facets/PExitFacet.sol:37` | `PExitTarget.sol:71` `_entryExitSingleAssetExactBptInFlexible` | E |
| `withdrawSingleFlexible(address,uint256,bool,address,uint256,uint256)` | `interfaces/IP.sol:372` | `facets/PExitFacet.sol:38` | `PExitTarget.sol:82` `_entryWithdrawSingleFlexible` | E |
| `ownerSwapExactIn(address,address,uint256,uint256,uint256)` | `interfaces/IP.sol:160` | `facets/PExitFacet.sol:39` | `PSeTarget.sol:307` `_entryOwnerSwapExactIn` | S |
| `ownerSwapExactOut(address,address,uint256,uint256,uint256)` | `interfaces/IP.sol:169` | `facets/PExitFacet.sol:40` | `PSeTarget.sol:310` `_entryOwnerSwapExactOut` | S |
| `previewExitProportional(uint256)` | `interfaces/IP.sol:194` | `facets/PExitQueryFacet.sol:37` | `PExitQueryTarget.sol:31` `_entryPreviewExitProportional` | E |
| `previewExitSingleAssetExactBptIn(address,uint256)` | `interfaces/IP.sol:196` | `facets/PExitQueryFacet.sol:38` | `PExitQueryTarget.sol:39` `_entryPreviewExitSingleAssetExactBptIn` | E |
| `previewExitSingleAssetExactTokenOut(address,uint256)` | `interfaces/IP.sol:201` | `facets/PExitQueryFacet.sol:39` | `PExitQueryTarget.sol:55` `_entryPreviewExitSingleAssetExactTokenOut` | E |
| `previewWithdrawSingle(address,uint256)` | `interfaces/IP.sol:211` | `facets/PExitQueryFacet.sol:40` | `PExitQueryTarget.sol:47` `_entryPreviewWithdrawSingle` | E |
| `previewWithdrawSingleExactOut(address,uint256)` | `interfaces/IP.sol:216` | `facets/PExitQueryFacet.sol:41` | `PExitQueryTarget.sol:63` `_entryPreviewWithdrawSingleExactOut` | E |
| `previewExitProportionalFlexible(uint256,bool[])` | `interfaces/IP.sol:227` | `facets/PExitQueryFacet.sol:42` | `PExitQueryTarget.sol:71` `_entryPreviewExitProportionalFlexible` | E |
| `previewExitSingleAssetExactBptInFlexible(address,uint256,bool)` | `interfaces/IP.sol:242` | `facets/PExitQueryFacet.sol:43` | `PExitQueryTarget.sol:79` `_entryPreviewExitSingleAssetExactBptInFlexible` | E |
| `previewWithdrawSingleFlexible(address,uint256,bool)` | `interfaces/IP.sol:247` | `facets/PExitQueryFacet.sol:44` | `PExitQueryTarget.sol:87` `_entryPreviewWithdrawSingleFlexible` | E |
| `previewBurnToToken(uint256,address)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:38` | `facets/PExitQueryFacet.sol:45` | `PExitQueryTarget.sol:23` `_entryPreviewBurnToToken` | E |
| `previewSynthetic(DetfQuoteCtx,address)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:33` | `facets/PExitQueryFacet.sol:46` | `PExitQueryTarget.sol:95` `_isLive`, `_tokenIndex`, `_ratedWadAll`, `_previewSupplyAfterProtocolMint` | Q |
| `rateProviders()` | `interfaces/IP.sol:117` | `facets/PExitQueryFacet.sol:47` | `PExitQueryTarget.sol:180` (direct getter/guard) | R |
| `rateProvider(address)` | `interfaces/IP.sol:119` | `facets/PExitQueryFacet.sol:48` | `PExitQueryTarget.sol:185` (direct getter/guard) | R |
| `previewExchangeIn(IERC20,uint256,IERC20)` | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:46` | `facets/PExitQueryFacet.sol:49` | `PExitQueryTarget.sol:19` `_previewExchangeIn` | J/E |
| `previewExchangeOut(IERC20,IERC20,uint256)` | `lib/crane/contracts/interfaces/IStandardExchangeOut.sol:51` | `facets/PExitQueryFacet.sol:50` | `PSeTarget.sol:295` `_entryPreviewExchangeOut` | J/E |
| `beforeInitialize(address,PoolKey,uint160)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:22` | `facets/PHooksFacet.sol:31` | `PHooksTarget.sol:355` `_hookBeforeInitialize` | R |
| `afterInitialize(address,PoolKey,uint160,int24)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:30` | `facets/PHooksFacet.sol:32` | `PHooksTarget.sol:356` `_hookAfterInitialize` | R |
| `beforeAddLiquidity(address,PoolKey,ModifyLiquidityParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:40` | `facets/PHooksFacet.sol:33` | `PHooksTarget.sol:357` `_hookBeforeAddLiquidity` | R |
| `afterAddLiquidity(address,PoolKey,ModifyLiquidityParams,BalanceDelta,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:56` | `facets/PHooksFacet.sol:34` | `PHooksTarget.sol:358` `_hookAfterAddLiquidity` | R |
| `beforeRemoveLiquidity(address,PoolKey,ModifyLiquidityParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:71` | `facets/PHooksFacet.sol:35` | `PHooksTarget.sol:359` `_hookBeforeRemoveLiquidity` | R |
| `afterRemoveLiquidity(address,PoolKey,ModifyLiquidityParams,BalanceDelta,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:87` | `facets/PHooksFacet.sol:36` | `PHooksTarget.sol:360` `_hookAfterRemoveLiquidity` | R |
| `beforeSwap(address,PoolKey,SwapParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:104` | `facets/PHooksFacet.sol:37` | `PHooksTarget.sol:361` `_hookBeforeSwap` | S |
| `afterSwap(address,PoolKey,SwapParams,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:116` | `facets/PHooksFacet.sol:38` | `PHooksTarget.sol:362` `_hookAfterSwap` | R |
| `beforeDonate(address,PoolKey,uint256,uint256,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:131` | `facets/PHooksFacet.sol:39` | `PHooksTarget.sol:363` `_hookBeforeDonate` | R |
| `afterDonate(address,PoolKey,uint256,uint256,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:146` | `facets/PHooksFacet.sol:40` | `PHooksTarget.sol:364` `_hookAfterDonate` | R |
| `poolManager()` | `interfaces/IP.sol:106` | `facets/PHooksFacet.sol:41` | `PHooksTarget.sol:336` `_bindingPoolManager` | R |
| `feeOracle()` | `interfaces/IP.sol:107` | `facets/PHooksFacet.sol:42` | `PTarget.sol:128` (direct getter/guard) | R |
| `permit2()` | `interfaces/IP.sol:108` | `facets/PHooksFacet.sol:43` | `PHooksTarget.sol:337` `_bindingPermit2` | R |
| `numTokens()` | `interfaces/IP.sol:109` | `facets/PHooksFacet.sol:44` | `PHooksTarget.sol:338` `_bindingNumTokens` | R |
| `tokens()` | `interfaces/IP.sol:110` | `facets/PHooksFacet.sol:45` | `PTarget.sol:140` (direct getter/guard) | R |
| `token(uint256)` | `interfaces/IP.sol:111` | `facets/PHooksFacet.sol:46` | `PHooksTarget.sol:339` `_bindingToken` | R |
| `getNormalizedWeights()` | `interfaces/IP.sol:112` | `facets/PHooksFacet.sol:47` | `PHooksTarget.sol:340` `_bindingWeights` | R |
| `weight(uint256)` | `interfaces/IP.sol:113` | `facets/PHooksFacet.sol:48` | `PHooksTarget.sol:341` `_bindingWeight` | R |
| `standardExchange(uint256)` | `interfaces/IP.sol:114` | `facets/PHooksFacet.sol:49` | `PHooksTarget.sol:342` `_bindingStandardExchange` | R |
| `rateProvider(uint256)` | `interfaces/IP.sol:115` | `facets/PHooksFacet.sol:50` | `PHooksTarget.sol:343` `_bindingRateProvider` | R |
| `isBuffered(uint256)` | `interfaces/IP.sol:120` | `facets/PHooksFacet.sol:51` | `PHooksTarget.sol:344` `_bindingIsBuffered` | R |
| `nativeReserve(uint256)` | `interfaces/IP.sol:124` | `facets/PHooksFacet.sol:52` | `PHooksTarget.sol:347` `_bindingNativeReserve` | Q |
| `nativeReserves()` | `interfaces/IP.sol:125` | `facets/PHooksFacet.sol:53` | `PHooksTarget.sol:348` `_bindingNativeReserves` | Q |
| `ratedBalance(uint256)` | `interfaces/IP.sol:126` | `facets/PHooksFacet.sol:54` | `PHooksTarget.sol:351` `_bindingRatedBalance` | Q |
| `ratedBalances()` | `interfaces/IP.sol:127` | `facets/PHooksFacet.sol:55` | `PHooksTarget.sol:352` `_bindingRatedBalances` | Q |
| `seBalance(uint256)` | `interfaces/IP.sol:128` | `facets/PHooksFacet.sol:56` | `PHooksTarget.sol:349` `_bindingSeBalance` | R |
| `seClaim(uint256)` | `interfaces/IP.sol:129` | `facets/PHooksFacet.sol:57` | `PHooksTarget.sol:350` `_bindingSeClaim` | Q |
| `invScale(uint256)` | `interfaces/IP.sol:130` | `facets/PHooksFacet.sol:58` | `PHooksTarget.sol:345` `_bindingInvScale` | R |
| `ratedScale(uint256)` | `interfaces/IP.sol:131` | `facets/PHooksFacet.sol:59` | `PHooksTarget.sol:346` `_bindingRatedScale` | Q |
| `dexSwapFee()` | `interfaces/IP.sol:135` | `facets/PHooksFacet.sol:60` | `PTarget.sol:216` (direct getter/guard) | R |
| `usageFee()` | `interfaces/IP.sol:136` | `facets/PHooksFacet.sol:61` | `PTarget.sol:220` (direct getter/guard) | R |
| `feeTo()` | `interfaces/IP.sol:137` | `facets/PHooksFacet.sol:62` | `PTarget.sol:224` (direct getter/guard) | R |
| `kLast()` | `interfaces/IP.sol:138` | `facets/PHooksFacet.sol:63` | `PHooksTarget.sol:353` `_bindingKLast` | Q |
| `kLastMode()` | `interfaces/IP.sol:139` | `facets/PHooksFacet.sol:64` | `PTarget.sol:232` (direct getter/guard) | Q |
| `isFullBook()` | `interfaces/IP.sol:140` | `facets/PHooksFacet.sol:65` | `PTarget.sol:236` `Math.isFullBookReserves`, `_nativeAll` | R |
| `ensurePairPools()` | `interfaces/IP.sol:144` | `facets/PHooksFacet.sol:66` | `PHooksTarget.sol:354` `_ensurePairPools` | R |
| `pairDoorCount()` | `interfaces/IP.sol:145` | `facets/PHooksFacet.sol:67` | `PTarget.sol:275` `PairPoolLib.pairDoorCount` | R |
| `previewSwapExactIn(address,address,uint256)` | `interfaces/IP.sol:149` | `facets/PHooksFacet.sol:68` | `PHooksTarget.sol:365` `_hookPreviewSwapExactIn` | S |
| `previewSwapExactOut(address,address,uint256)` | `interfaces/IP.sol:154` | `facets/PHooksFacet.sol:69` | `PHooksTarget.sol:366` `_hookPreviewSwapExactOut` | S |
| `isLive()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:30` | `facets/PHooksFacet.sol:70` | `PTarget.sol:240` `_isLive` | R |
| `firstJoinMustBeFullBook()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:28` | `facets/PHooksFacet.sol:71` | `PTarget.sol:244` (direct getter/guard) | J/E |
| `requiredFirstBondTokens()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:26` | `facets/PHooksFacet.sol:72` | `PTarget.sol:248` (direct getter/guard) | R |
| `standardExchangeOf(address)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:16` | `facets/PHooksFacet.sol:73` | `PTarget.sol:252` (direct getter/guard) | R |
| `syntheticNumeraires()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:24` | `facets/PHooksFacet.sol:74` | `PTarget.sol:256` (direct getter/guard) | R |
| `tradingFeeWad()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:32` | `facets/PHooksFacet.sol:75` | `PTarget.sol:271` (direct getter/guard) | R |
| `ownerOnlyLiquidity()` | `PTarget.sol:120` (Target-derived) | `facets/PHooksFacet.sol:76` | `PTarget.sol:120` (direct getter/guard) | R |
| `previewSwapAfterExchange(address,address,address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:19` | `facets/PHooksFacet.sol:77` | `PHooksTarget.sol:371` `_tokenIndex`, `_swapAtExternalState` | S |
| `previewBondAfterDeposit(address,address,address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:30` | `facets/PHooksFacet.sol:78` | `PHooksTarget.sol:382` `_tokenIndex`, `_bondAtExternalState` | J/E |
| `joinProportionalFlexible(uint256[],bool[],address,uint256,uint256)` | `interfaces/IP.sol:328` | `facets/PJoinFlexibleFacet.sol:30` | `PJoinFlexibleTarget.sol:18` `_entryJoinProportionalFlexible` | J/E |
| `joinSingleAssetExactInFlexible(address,uint256,bool,address,uint256,uint256)` | `interfaces/IP.sol:345` | `facets/PJoinFlexibleFacet.sol:31` | `PJoinFlexibleTarget.sol:28` `_entryJoinSingleAssetExactInFlexible` | J/E |
| `depositSingleFlexible(address,uint256,bool,address,uint256,uint256)` | `interfaces/IP.sol:354` | `facets/PJoinFlexibleFacet.sol:32` | `PJoinFlexibleTarget.sol:39` `_entryDepositSingleFlexible` | J/E |
| `joinUnbalanced(address[],uint256[],address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:85` | `facets/PJoinFlexibleFacet.sol:33` | `PJoinFlexibleTarget.sol:8` `_entryJoinUnbalanced` | J/E |
| `joinProportional(uint256[],address,uint256,uint256)` | `interfaces/IP.sol:254` | `facets/PLiquidityFacet.sol:27` | `PJoinTarget.sol:8` `_entryJoinProportional` | J/E |
| `joinUnbalanced(uint256[],address,uint256,uint256)` | `interfaces/IP.sol:277` | `facets/PLiquidityFacet.sol:28` | `PJoinTarget.sol:17` `_entryJoinUnbalanced` | J/E |
| `joinSingleAssetExactIn(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:261` | `facets/PLiquidityFacet.sol:29` | `PJoinTarget.sol:26` `_entryJoinSingleAssetExactIn` | J/E |
| `joinSingleAssetExactOut(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:269` | `facets/PLiquidityFacet.sol:30` | `PJoinTarget.sol:46` `_entryJoinSingleAssetExactOut` | J/E |
| `depositSingle(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:301` | `facets/PLiquidityFacet.sol:31` | `PJoinTarget.sol:36` `_entryDepositSingle` | J/E |
| `previewJoinProportional(uint256[])` | `interfaces/IP.sol:177` | `facets/PLiquidityFacetExt.sol:31` | `PJoinQueryTarget.sol:25` `_entryPreviewJoinProportional` | J/E |
| `previewJoinUnbalanced(uint256[])` | `interfaces/IP.sol:192` | `facets/PLiquidityFacetExt.sol:32` | `PJoinQueryTarget.sol:33` `_entryPreviewJoinUnbalanced` | J/E |
| `previewJoinSingleAssetExactIn(address,uint256)` | `interfaces/IP.sol:182` | `facets/PLiquidityFacetExt.sol:33` | `PJoinQueryTarget.sol:45` `_entryPreviewJoinSingleAssetExactIn` | J/E |
| `previewJoinSingleAssetExactOut(address,uint256)` | `interfaces/IP.sol:187` | `facets/PLiquidityFacetExt.sol:34` | `PJoinQueryTarget.sol:61` `_entryPreviewJoinSingleAssetExactOut` | J/E |
| `previewDepositSingle(address,uint256)` | `interfaces/IP.sol:206` | `facets/PLiquidityFacetExt.sol:35` | `PJoinQueryTarget.sol:53` `_entryPreviewDepositSingle` | J/E |
| `previewJoinProportionalFlexible(uint256[],bool[])` | `interfaces/IP.sol:222` | `facets/PLiquidityFacetExt.sol:36` | `PJoinQueryTarget.sol:69` `_entryPreviewJoinProportionalFlexible` | J/E |
| `previewJoinSingleAssetExactInFlexible(address,uint256,bool)` | `interfaces/IP.sol:232` | `facets/PLiquidityFacetExt.sol:37` | `PJoinQueryTarget.sol:77` `_entryPreviewJoinSingleAssetExactInFlexible` | J/E |
| `previewDepositSingleFlexible(address,uint256,bool)` | `interfaces/IP.sol:237` | `facets/PLiquidityFacetExt.sol:38` | `PJoinQueryTarget.sol:85` `_entryPreviewDepositSingleFlexible` | J/E |
| `previewJoinUnbalanced(address[],uint256[])` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:80` | `facets/PLiquidityFacetExt.sol:39` | `PJoinQueryTarget.sol:37` `_entryPreviewJoinUnbalanced` | J/E |
| `previewJoinAfterDeposit(address,address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:24` | `facets/PLiquidityFacetExt.sol:40` | `PJoinQueryTarget.sol:11` `_tokenIndex`, `_invWadAll`, `Math.scaleTo`, `_previewSupplyAfterProtocolMint`, `_feeOracle`, `_singleJoinExactInSharesOwnerAware` | J/E |
| `exchangeOut(IERC20,uint256,IERC20,uint256,address,bool,uint256)` | `lib/crane/contracts/interfaces/IStandardExchangeOut.sol:67` | `facets/PLiquidityFacetExt.sol:41` | `PSeTarget.sol:301` `_entryExchangeOut` | J/E |
| `exchangeIn(IERC20,uint256,IERC20,uint256,address,bool,uint256)` | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:62` | `facets/PSeFacet.sol:37` | `PSeTarget.sol:289` `_entryExchangeIn` | J/E |
| `exchangeRate()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:101` | `facets/PExitQueryFacet.sol:51` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:17` (direct getter/guard) | Q |
| `yieldToken()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:132` | `facets/PExitQueryFacet.sol:51` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:15` (direct getter/guard) | R |
| `assetInfo()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:165` | `facets/PExitQueryFacet.sol:51` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:16` (direct getter/guard) | R |
| `getTokensIn()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:137` | `facets/PExitQueryFacet.sol:51` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:13` (direct getter/guard) | R |
| `getTokensOut()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:142` | `facets/PExitQueryFacet.sol:51` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:14` (direct getter/guard) | R |
| `isValidTokenIn(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:144` | `facets/PExitQueryFacet.sol:51` via `_appendQuery` | `PSeTarget.sol:284` `_validNativeToken` | R |
| `isValidTokenOut(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:146` | `facets/PExitQueryFacet.sol:51` via `_appendQuery` | `PSeTarget.sol:285` `_validNativeToken` | R |
| `previewDeposit(address,uint256)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:148` | `facets/PExitQueryFacet.sol:51` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol:10` `_previewExchangeIn` | J/E |
| `previewRedeem(address,uint256)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:153` | `facets/PExitQueryFacet.sol:51` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol:15` `_previewExchangeIn` | E |
| `getRewardTokens()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:127` | `facets/PExitQueryFacet.sol:51` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:27` (direct getter/guard) | R |
| `accruedRewards(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:118` | `facets/PExitQueryFacet.sol:51` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:28` (direct getter/guard) | R |
| `rewardIndexesStored()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:122` | `facets/PExitQueryFacet.sol:51` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:29` (direct getter/guard) | R |
| `deposit(address,address,uint256,uint256)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:68` | `facets/PSeFacet.sol:38` via `_appendExecution` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:18` `_standardRoute` | J/E |
| `redeem(address,uint256,address,uint256,bool)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:86` | `facets/PSeFacet.sol:38` via `_appendExecution` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:30` `_requireVaultHeldShares`, `_redeemVaultHeld`, `_standardRoute` | E |
| `rewardIndexesCurrent()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:120` | `facets/PSeFacet.sol:38` via `_appendExecution` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:78` (direct getter/guard) | R |
| `claimRewards(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:111` | `facets/PSeFacet.sol:38` via `_appendExecution` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:79` (direct getter/guard) | R |


## H6 - Task 11

Directory: `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/`. P = `UniswapV4StandardExchangeCurveQuadStableBufferHook`. Product control: `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol`.

Package installation: `PDFPkg.sol:160`. facets[0] = address(MULTI_STEP_OWNABLE_FACET); facets[1] = address(MULTI_ASSET_BASIC_VAULT_FACET); facets[2] = address(MULTI_ASSET_STANDARD_VAULT_FACET); facets[3] = address(SELF); facets[4] = address(HOOKS_FACET); facets[5] = address(LIQUIDITY_FACET); facets[6] = address(EXIT_FACET); facets[7] = address(SE_FACET); facets[8] = address(ERC20_FACET); facets[9] = address(ERC5267_FACET); facets[10] = address(ERC2612_FACET); facets[11] = address(JOIN_QUERY_FACET);

Initial cuts and production replacement: `PDFPkg.sol:186` facetCuts; `PDFPkg.sol:190` productionFacetCuts; `PDFPkg.sol:194` _facetCuts; `PDFPkg.sol:330` postDeploy.

| Accounting class | Concrete test destinations under HT |
| --- | --- |
| S | stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_OwnerOnlyLiquidity.t.sol; stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol; stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_OwnerDuringLock.t.sol |
| J/E | stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_Liquidity.t.sol; stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeBufferAbi.t.sol; stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol |
| E | stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_Liquidity.t.sol; stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeBufferAbi.t.sol; stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol |
| Q | stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeBufferAbi.t.sol; stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol; stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_VaultViews.t.sol |
| R | stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeBufferAbi.t.sol; stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol; stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_VaultViews.t.sol |

| Selector control | Independent declaration | Installed facet / append site | Implementation path; direct helpers | Class |
| --- | --- | --- | --- | --- |
| `previewExitProportional(uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:115` | `facets/PExitFacet.sol:39` | `PExitTarget.sol:160` `_nativeAll`, `Math.proportionalExitAmounts`, `_previewSupplyAfterProtocolMint`, `_invToPairOutPreview`, `Math.toDynamic` | E |
| `exitProportional(uint256,address,uint256[],uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:117` | `facets/PExitFacet.sol:40` | `PExitTarget.sol:172` `_requireDeadline`, `_requireAmountsLen4`, `_maybeMintProtocolFee`, `_nativeAll`, `Math.proportionalExitAmounts`, `_totalSupply`, `_invToPairOutPreview`, `_burnLp`, `_unwrapSeShares`, `_debitRawIntentional` | E |
| `previewExitSingleAssetExactBptIn(address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:124` | `facets/PExitFacet.sol:41` | `PExitTarget.sol:223` `_quoteExitSingleExactBptIn` | E |
| `exitSingleAssetExactBptIn(address,uint256,address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:129` | `facets/PExitFacet.sol:42` | `PExitTarget.sol:231` `_exitSingleAssetExactBptIn` | E |
| `previewExitSingleAssetExactTokenOut(address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:137` | `facets/PExitFacet.sol:43` | `PExitTarget.sol:38` `_quoteExitSingleExactTokenOut`, `_previewSupplyAfterProtocolMint` | E |
| `exitSingleAssetExactTokenOut(address,uint256,address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:142` | `facets/PExitFacet.sol:44` | `PExitTarget.sol:46` `_exitSingleAssetExactTokenOut` | E |
| `previewWithdrawSingle(address,uint256)` | `interfaces/IP.sol:155` | `facets/PExitFacet.sol:45` | `PExitTarget.sol:251` (direct getter/guard) | E |
| `withdrawSingle(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:211` | `facets/PExitFacet.sol:46` | `PExitTarget.sol:241` `_exitSingleAssetExactBptIn` | E |
| `previewWithdrawSingleExactOut(address,uint256)` | `interfaces/IP.sol:160` | `facets/PExitFacet.sol:47` | `PExitTarget.sol:56` (direct getter/guard) | E |
| `withdrawSingleExactOut(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:219` | `facets/PExitFacet.sol:48` | `PExitTarget.sol:64` `_exitSingleAssetExactTokenOut` | E |
| `previewExitProportionalFlexible(uint256,bool[])` | `interfaces/IP.sol:171` | `facets/PExitFacet.sol:49` | `PExitTarget.sol:259` `_validateSeShareFlags`, `_nativeAll`, `Math.proportionalExitAmounts`, `_previewSupplyAfterProtocolMint`, `Math.toDynamic`, `_invToEdgeOutPreview` | E |
| `exitProportionalFlexible(uint256,address,bool[],uint256[],uint256)` | `interfaces/IP.sol:237` | `facets/PExitFacet.sol:50` | `PExitTarget.sol:271` `_requireDeadline`, `_validateSeShareFlags`, `_requireAmountsLen4`, `_maybeMintProtocolFee`, `Math.proportionalExitAmounts`, `_nativeAll`, `_totalSupply`, `_requireExitFloors`, `_invToEdgeOutPreview`, `_requireEdgeMins` | E |
| `previewExitSingleAssetExactBptInFlexible(address,uint256,bool)` | `interfaces/IP.sol:186` | `facets/PExitFacet.sol:51` | `PExitTarget.sol:358` `_quoteExitSingleExactBptInFlexible` | E |
| `exitSingleAssetExactBptInFlexible(address,uint256,bool,address,uint256,uint256)` | `interfaces/IP.sol:263` | `facets/PExitFacet.sol:52` | `PExitTarget.sol:366` `_exitSingleAssetExactBptInFlexible` | E |
| `previewWithdrawSingleFlexible(address,uint256,bool)` | `interfaces/IP.sol:191` | `facets/PExitFacet.sol:53` | `PExitTarget.sol:392` (direct getter/guard) | E |
| `withdrawSingleFlexible(address,uint256,bool,address,uint256,uint256)` | `interfaces/IP.sol:272` | `facets/PExitFacet.sol:54` | `PExitTarget.sol:379` `_exitSingleAssetExactBptInFlexible` | E |
| `previewBurnToToken(uint256,address)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:38` | `facets/PExitFacet.sol:55` | `PExitTarget.sol:145` `_totalSupply`, `_isLive`, `_tryResolveJoinToken`, `Math.proportionalExitAmounts`, `_nativeAll`, `_previewSupplyAfterProtocolMint`, `_invToPairOutPreview` | E |
| `rateProviders()` | `interfaces/IP.sol:116` | `facets/PExitFacet.sol:56` | `PExitTarget.sol:401` (direct getter/guard) | R |
| `rateProvider(address)` | `interfaces/IP.sol:118` | `facets/PExitFacet.sol:57` | `PExitTarget.sol:408` (direct getter/guard) | R |
| `beforeInitialize(address,PoolKey,uint160)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:22` | `facets/PHooksFacet.sol:31` | `PHooksTarget.sol:383` `_hookBeforeInitialize` | R |
| `afterInitialize(address,PoolKey,uint160,int24)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:30` | `facets/PHooksFacet.sol:32` | `PHooksTarget.sol:384` `_hookAfterInitialize` | R |
| `beforeAddLiquidity(address,PoolKey,ModifyLiquidityParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:40` | `facets/PHooksFacet.sol:33` | `PHooksTarget.sol:385` `_hookBeforeAddLiquidity` | R |
| `afterAddLiquidity(address,PoolKey,ModifyLiquidityParams,BalanceDelta,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:56` | `facets/PHooksFacet.sol:34` | `PHooksTarget.sol:386` `_hookAfterAddLiquidity` | R |
| `beforeRemoveLiquidity(address,PoolKey,ModifyLiquidityParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:71` | `facets/PHooksFacet.sol:35` | `PHooksTarget.sol:387` `_hookBeforeRemoveLiquidity` | R |
| `afterRemoveLiquidity(address,PoolKey,ModifyLiquidityParams,BalanceDelta,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:87` | `facets/PHooksFacet.sol:36` | `PHooksTarget.sol:388` `_hookAfterRemoveLiquidity` | R |
| `beforeSwap(address,PoolKey,SwapParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:104` | `facets/PHooksFacet.sol:37` | `PHooksTarget.sol:389` `_hookBeforeSwap` | S |
| `afterSwap(address,PoolKey,SwapParams,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:116` | `facets/PHooksFacet.sol:38` | `PHooksTarget.sol:390` `_hookAfterSwap` | R |
| `beforeDonate(address,PoolKey,uint256,uint256,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:131` | `facets/PHooksFacet.sol:39` | `PHooksTarget.sol:391` `_hookBeforeDonate` | R |
| `afterDonate(address,PoolKey,uint256,uint256,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:146` | `facets/PHooksFacet.sol:40` | `PHooksTarget.sol:392` `_hookAfterDonate` | R |
| `poolManager()` | `interfaces/IP.sol:106` | `facets/PHooksFacet.sol:41` | `PHooksTarget.sol:364` `_bindingPoolManager` | R |
| `feeOracle()` | `interfaces/IP.sol:107` | `facets/PHooksFacet.sol:42` | `PHooksTarget.sol:351` `_bindingFeeOracle` | R |
| `permit2()` | `interfaces/IP.sol:108` | `facets/PHooksFacet.sol:43` | `PHooksTarget.sol:365` `_bindingPermit2` | R |
| `numTokens()` | `interfaces/IP.sol:109` | `facets/PHooksFacet.sol:44` | `PHooksTarget.sol:366` `_bindingNumTokens` | R |
| `tokens()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:14` | `facets/PHooksFacet.sol:45` | `PHooksTarget.sol:352` `_bindingTokens` | R |
| `token(uint256)` | `interfaces/IP.sol:110` | `facets/PHooksFacet.sol:46` | `PHooksTarget.sol:367` `_bindingToken` | R |
| `baseAmp()` | `interfaces/IP.sol:111` | `facets/PHooksFacet.sol:47` | `PHooksTarget.sol:368` `_bindingBaseAmp` | R |
| `getCurrentAmp()` | `interfaces/IP.sol:112` | `facets/PHooksFacet.sol:48` | `PHooksTarget.sol:369` `_bindingCurrentAmp` | R |
| `standardExchange(uint256)` | `interfaces/IP.sol:113` | `facets/PHooksFacet.sol:49` | `PHooksTarget.sol:370` `_bindingStandardExchange` | R |
| `rateProvider(uint256)` | `interfaces/IP.sol:114` | `facets/PHooksFacet.sol:50` | `PHooksTarget.sol:371` `_bindingRateProvider` | R |
| `isBuffered(uint256)` | `interfaces/IP.sol:119` | `facets/PHooksFacet.sol:51` | `PHooksTarget.sol:372` `_bindingIsBuffered` | R |
| `nativeReserve(uint256)` | `interfaces/IP.sol:123` | `facets/PHooksFacet.sol:52` | `PHooksTarget.sol:375` `_bindingNativeReserve` | Q |
| `nativeReserves()` | `interfaces/IP.sol:124` | `facets/PHooksFacet.sol:53` | `PHooksTarget.sol:376` `_bindingNativeReserves` | Q |
| `ratedBalance(uint256)` | `interfaces/IP.sol:125` | `facets/PHooksFacet.sol:54` | `PHooksTarget.sol:379` `_bindingRatedBalance` | Q |
| `ratedBalances()` | `interfaces/IP.sol:126` | `facets/PHooksFacet.sol:55` | `PHooksTarget.sol:380` `_bindingRatedBalances` | Q |
| `seBalance(uint256)` | `interfaces/IP.sol:127` | `facets/PHooksFacet.sol:56` | `PHooksTarget.sol:377` `_bindingSeBalance` | R |
| `seClaim(uint256)` | `interfaces/IP.sol:128` | `facets/PHooksFacet.sol:57` | `PHooksTarget.sol:378` `_bindingSeClaim` | Q |
| `invScale(uint256)` | `interfaces/IP.sol:129` | `facets/PHooksFacet.sol:58` | `PHooksTarget.sol:373` `_bindingInvScale` | R |
| `ratedScale(uint256)` | `interfaces/IP.sol:130` | `facets/PHooksFacet.sol:59` | `PHooksTarget.sol:374` `_bindingRatedScale` | Q |
| `dexSwapFee()` | `interfaces/IP.sol:134` | `facets/PHooksFacet.sol:60` | `PHooksTarget.sol:353` `_bindingDexSwapFee` | R |
| `usageFee()` | `interfaces/IP.sol:135` | `facets/PHooksFacet.sol:61` | `PHooksTarget.sol:354` `_bindingUsageFee` | R |
| `feeTo()` | `interfaces/IP.sol:136` | `facets/PHooksFacet.sol:62` | `PHooksTarget.sol:355` `_bindingFeeTo` | R |
| `kLast()` | `interfaces/IP.sol:137` | `facets/PHooksFacet.sol:63` | `PHooksTarget.sol:381` `_bindingKLast` | Q |
| `isFullBook()` | `interfaces/IP.sol:138` | `facets/PHooksFacet.sol:64` | `PHooksTarget.sol:356` `_bindingIsFullBook` | R |
| `ensurePairPools()` | `interfaces/IP.sol:142` | `facets/PHooksFacet.sol:65` | `PHooksTarget.sol:382` `_ensurePairPools` | R |
| `pairDoorCount()` | `interfaces/IP.sol:143` | `facets/PHooksFacet.sol:66` | `PHooksTarget.sol:363` `_bindingPairDoorCount` | R |
| `previewSwapExactIn(address,address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:38` | `facets/PHooksFacet.sol:67` | `PHooksTarget.sol:393` `_hookPreviewSwapExactIn` | S |
| `previewSwapExactOut(address,address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:43` | `facets/PHooksFacet.sol:68` | `PHooksTarget.sol:394` `_hookPreviewSwapExactOut` | S |
| `standardExchangeOf(address)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:16` | `facets/PHooksFacet.sol:69` | `PHooksTarget.sol:360` `_bindingStandardExchangeOf` | R |
| `syntheticNumeraires()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:24` | `facets/PHooksFacet.sol:70` | `PHooksTarget.sol:361` `_bindingSyntheticNumeraires` | R |
| `requiredFirstBondTokens()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:26` | `facets/PHooksFacet.sol:71` | `PHooksTarget.sol:359` `_bindingRequiredFirstBondTokens` | R |
| `firstJoinMustBeFullBook()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:28` | `facets/PHooksFacet.sol:72` | `PHooksTarget.sol:358` `_bindingFirstJoinMustBeFullBook` | J/E |
| `isLive()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:30` | `facets/PHooksFacet.sol:73` | `PHooksTarget.sol:357` `_bindingIsLive` | R |
| `tradingFeeWad()` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:32` | `facets/PHooksFacet.sol:74` | `PHooksTarget.sol:362` `_bindingTradingFeeWad` | R |
| `ownerOnlyLiquidity()` | `PHooksTarget.sol:350` (Target-derived) | `facets/PHooksFacet.sol:75` | `PHooksTarget.sol:350` `_bindingOwnerOnlyLiquidity` | R |
| `previewSwapAfterExchange(address,address,address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:19` | `facets/PHooksFacet.sol:76` | `PHooksTarget.sol:398` `_tokenIndex`, `_swapAtExternalState` | S |
| `previewBondAfterDeposit(address,address,address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:30` | `facets/PHooksFacet.sol:77` | `PHooksTarget.sol:409` `_tokenIndex`, `_bondAtExternalState` | J/E |
| `joinProportional(uint256[],address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:73` | `facets/PLiquidityFacet.sol:31` | `PJoinTarget.sol:8` `_entryJoinProportional` | J/E |
| `joinUnbalanced(uint256[],address,uint256,uint256)` | `contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol:37` | `facets/PLiquidityFacet.sol:32` | `PJoinTarget.sol:17` `_entryJoinUnbalanced` | J/E |
| `joinSingleAssetExactIn(address,uint256,address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:94` | `facets/PLiquidityFacet.sol:33` | `PJoinTarget.sol:44` `_entryJoinSingleAssetExactIn` | J/E |
| `joinSingleAssetExactOut(address,uint256,address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:107` | `facets/PLiquidityFacet.sol:34` | `PJoinTarget.sol:34` `_entryJoinSingleAssetExactOut` | J/E |
| `depositSingle(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:203` | `facets/PLiquidityFacet.sol:35` | `PJoinTarget.sol:54` `_entryDepositSingle` | J/E |
| `joinProportionalFlexible(uint256[],bool[],address,uint256,uint256)` | `interfaces/IP.sol:229` | `facets/PLiquidityFacet.sol:36` | `PJoinTarget.sol:64` `_entryJoinProportionalFlexible` | J/E |
| `joinSingleAssetExactInFlexible(address,uint256,bool,address,uint256,uint256)` | `interfaces/IP.sol:245` | `facets/PLiquidityFacet.sol:37` | `PJoinTarget.sol:74` `_entryJoinSingleAssetExactInFlexible` | J/E |
| `depositSingleFlexible(address,uint256,bool,address,uint256,uint256)` | `interfaces/IP.sol:254` | `facets/PLiquidityFacet.sol:38` | `PJoinTarget.sol:85` `_entryDepositSingleFlexible` | J/E |
| `joinUnbalanced(address[],uint256[],address,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:85` | `facets/PLiquidityFacet.sol:39` | `PJoinTarget.sol:24` `_entryJoinUnbalanced` | J/E |
| `previewJoinProportional(uint256[])` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:68` | `facets/PLiquidityFacetExt.sol:39` | `PJoinQueryTarget.sol:39` `_entryPreviewJoinProportional` | J/E |
| `previewJoinUnbalanced(uint256[])` | `contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol:35` | `facets/PLiquidityFacetExt.sol:40` | `PJoinQueryTarget.sol:47` `_entryPreviewJoinUnbalanced` | J/E |
| `previewJoinSingleAssetExactIn(address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:89` | `facets/PLiquidityFacetExt.sol:41` | `PJoinQueryTarget.sol:67` `_entryPreviewJoinSingleAssetExactIn` | J/E |
| `previewJoinSingleAssetExactOut(address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:102` | `facets/PLiquidityFacetExt.sol:42` | `PJoinQueryTarget.sol:59` `_entryPreviewJoinSingleAssetExactOut` | J/E |
| `previewDepositSingle(address,uint256)` | `interfaces/IP.sol:150` | `facets/PLiquidityFacetExt.sol:43` | `PJoinQueryTarget.sol:75` `_entryPreviewDepositSingle` | J/E |
| `previewJoinProportionalFlexible(uint256[],bool[])` | `interfaces/IP.sol:166` | `facets/PLiquidityFacetExt.sol:44` | `PJoinQueryTarget.sol:83` `_entryPreviewJoinProportionalFlexible` | J/E |
| `previewJoinSingleAssetExactInFlexible(address,uint256,bool)` | `interfaces/IP.sol:176` | `facets/PLiquidityFacetExt.sol:45` | `PJoinQueryTarget.sol:91` `_entryPreviewJoinSingleAssetExactInFlexible` | J/E |
| `previewDepositSingleFlexible(address,uint256,bool)` | `interfaces/IP.sol:181` | `facets/PLiquidityFacetExt.sol:46` | `PJoinQueryTarget.sol:99` `_entryPreviewDepositSingleFlexible` | J/E |
| `previewJoinUnbalanced(address[],uint256[])` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:80` | `facets/PLiquidityFacetExt.sol:47` | `PJoinQueryTarget.sol:51` `_entryPreviewJoinUnbalanced` | J/E |
| `previewSynthetic(DetfQuoteCtx,address)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:33` | `facets/PLiquidityFacetExt.sol:48` | `PJoinQueryTarget.sol:107` `_isLive`, `_bindingSyntheticNumeraires`, `ClaimLib.syntheticValue` | Q |
| `previewJoinAfterDeposit(address,address,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:24` | `facets/PLiquidityFacetExt.sol:49` | `PJoinQueryTarget.sol:25` `_tokenIndex`, `_invWadAll`, `Math.scaleTo`, `_previewSupplyAfterProtocolMint`, `_feeOracle`, `Math.singleJoinExactInShares`, `_amp` | J/E |
| `previewExchangeIn(IERC20,uint256,IERC20)` | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:46` | `facets/PLiquidityFacetExt.sol:50` | `PJoinQueryTarget.sol:21` `_previewExchangeIn` | J/E |
| `ownerSwapExactOut(address,address,uint256,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:56` | `facets/PSeFacet.sol:38` | `PSeTarget.sol:197` `_onlyHookOwner`, `_requireDeadline`, `_previewSwapExactOut`, `_securePull`, `_payOwnerSwap` | S |
| `exchangeIn(IERC20,uint256,IERC20,uint256,address,bool,uint256)` | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:62` | `facets/PSeFacet.sol:39` | `PSeTarget.sol:54` `LiquidityRoute.isLiquidityRoute`, `_exchangeIn`, `_swapExchangeIn` | J/E |
| `previewExchangeOut(IERC20,IERC20,uint256)` | `lib/crane/contracts/interfaces/IStandardExchangeOut.sol:51` | `facets/PSeFacet.sol:40` | `PSeTarget.sol:107` `LiquidityRoute.isLiquidityRoute`, `_liquiditySePair`, `LiquidityRoute.previewOut`, `_previewSwapExactOut` | J/E |
| `exchangeOut(IERC20,uint256,IERC20,uint256,address,bool,uint256)` | `lib/crane/contracts/interfaces/IStandardExchangeOut.sol:67` | `facets/PSeFacet.sol:41` | `PSeTarget.sol:119` `LiquidityRoute.isLiquidityRoute`, `_liquiditySePair`, `LiquidityRoute.exchangeOut`, `_swapExchangeOut` | J/E |
| `ownerSwapExactIn(address,address,uint256,uint256,uint256)` | `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol:48` | `facets/PSeFacet.sol:42` | `PSeTarget.sol:174` `_onlyHookOwner`, `_requireDeadline`, `_tokenIndex`, `_previewSwapExactInPlan`, `_securePull`, `_payExactInOutput`, `_bufferOwnerSwapInput` | S |
| `exchangeRate()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:101` | `facets/PLiquidityFacetExt.sol:51` via `_appendQuery` | `PJoinQueryTarget.sol:126` `_previewSupplyAfterProtocolMint`, `_rootKNow` | Q |
| `yieldToken()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:132` | `facets/PLiquidityFacetExt.sol:51` via `_appendQuery` | `PJoinQueryTarget.sol:132` (direct getter/guard) | R |
| `assetInfo()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:165` | `facets/PLiquidityFacetExt.sol:51` via `_appendQuery` | `PJoinQueryTarget.sol:134` (direct getter/guard) | R |
| `getTokensIn()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:137` | `facets/PLiquidityFacetExt.sol:51` via `_appendQuery` | `PJoinQueryTarget.sol:138` `ClaimLib.nativeSyTokens` | R |
| `getTokensOut()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:142` | `facets/PLiquidityFacetExt.sol:51` via `_appendQuery` | `PJoinQueryTarget.sol:142` (direct getter/guard) | R |
| `isValidTokenIn(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:144` | `facets/PLiquidityFacetExt.sol:51` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:7` (direct getter/guard) | R |
| `isValidTokenOut(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:146` | `facets/PLiquidityFacetExt.sol:51` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:8` (direct getter/guard) | R |
| `previewDeposit(address,uint256)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:148` | `facets/PLiquidityFacetExt.sol:51` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol:10` `_previewExchangeIn` | J/E |
| `previewRedeem(address,uint256)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:153` | `facets/PLiquidityFacetExt.sol:51` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol:15` `_previewExchangeIn` | E |
| `getRewardTokens()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:127` | `facets/PLiquidityFacetExt.sol:51` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:27` (direct getter/guard) | R |
| `accruedRewards(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:118` | `facets/PLiquidityFacetExt.sol:51` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:28` (direct getter/guard) | R |
| `rewardIndexesStored()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:122` | `facets/PLiquidityFacetExt.sol:51` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:29` (direct getter/guard) | R |
| `rewardIndexesCurrent()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:120` | `facets/PLiquidityFacetExt.sol:52` via `_appendRewards` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:78` (direct getter/guard) | R |
| `claimRewards(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:111` | `facets/PLiquidityFacetExt.sol:52` via `_appendRewards` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:79` (direct getter/guard) | R |
| `deposit(address,address,uint256,uint256)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:68` | `facets/PSeFacet.sol:43` via `_appendMoney` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:18` `_standardRoute` | J/E |
| `redeem(address,uint256,address,uint256,bool)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:86` | `facets/PSeFacet.sol:43` via `_appendMoney` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:30` `_requireVaultHeldShares`, `_redeemVaultHeld`, `_standardRoute` | E |


## H7 - Task 12

Directory: `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/`. P = `UniswapV4StandardExchangeBalancerQuadStableBufferHook`. Product control: `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHook.sol`.

Package installation: `PDFPkg.sol:155`. facets[0] = address(MULTI_ASSET_BASIC_VAULT_FACET); facets[1] = address(MULTI_ASSET_STANDARD_VAULT_FACET); facets[2] = address(SELF); facets[3] = address(HOOKS_FACET); facets[4] = address(LIQUIDITY_FACET); facets[5] = address(SE_FACET); facets[6] = address(ERC20_FACET); facets[7] = address(ERC5267_FACET); facets[8] = address(ERC2612_FACET); facets[9] = address(EXIT_FACET); facets[10] = address(QUERY_FACET);

Initial cuts and production replacement: `PDFPkg.sol:180` facetCuts; `PDFPkg.sol:199` productionFacetCuts; `PDFPkg.sol:323` postDeploy.

| Accounting class | Concrete test destinations under HT |
| --- | --- |
| S | stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol; stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_Swap.t.sol |
| J/E | stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_Liquidity.t.sol; stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol |
| E | stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_Liquidity.t.sol; stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol |
| Q | stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol; stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_VaultViews.t.sol |
| R | stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol; stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_VaultViews.t.sol |

| Selector control | Independent declaration | Installed facet / append site | Implementation path; direct helpers | Class |
| --- | --- | --- | --- | --- |
| `exitSingleAssetExactTokenOut(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:188` | `facets/PExitFacet.sol:26` | `PExitTarget.sol:9` `_entryExitSingleAssetExactTokenOut` | E |
| `withdrawSingleExactOut(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:212` | `facets/PExitFacet.sol:27` | `PExitTarget.sol:14` `_entryWithdrawSingleExactOut` | E |
| `exitProportional(uint256,address,uint256[],uint256)` | `interfaces/IP.sol:176` | `facets/PExitFacet.sol:28` | `PExitTarget.sol:19` `_entryExitProportional` | E |
| `exitSingleAssetExactBptIn(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:180` | `facets/PExitFacet.sol:29` | `PExitTarget.sol:28` `_entryExitSingleAssetExactBptIn` | E |
| `withdrawSingle(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:204` | `facets/PExitFacet.sol:30` | `PExitTarget.sol:38` `_entryWithdrawSingle` | E |
| `exitProportionalFlexible(uint256,address,bool[],uint256[],uint256)` | `interfaces/IUniswapV4BalancerStableLiquidityUnits.sol:15` | `facets/PExitFacet.sol:31` | `PExitTarget.sol:48` `_entryExitProportionalFlexible` | E |
| `previewExitSingleAssetExactTokenOut(address,uint256)` | `interfaces/IP.sol:127` | `facets/PExitFacet.sol:32` | `PExitTarget.sol:52` `_entryPreviewExitSingleAssetExactTokenOut` | E |
| `previewWithdrawSingleExactOut(address,uint256)` | `interfaces/IP.sol:142` | `facets/PExitFacet.sol:33` | `PExitTarget.sol:55` `_entryPreviewWithdrawSingleExactOut` | E |
| `previewExitProportional(uint256)` | `interfaces/IP.sol:120` | `facets/PExitFacet.sol:34` | `PExitTarget.sol:58` `_entryPreviewExitProportional` | E |
| `previewExitSingleAssetExactBptIn(address,uint256)` | `interfaces/IP.sol:122` | `facets/PExitFacet.sol:35` | `PExitTarget.sol:64` `_entryPreviewExitSingleAssetExactBptIn` | E |
| `previewWithdrawSingle(address,uint256)` | `interfaces/IP.sol:137` | `facets/PExitFacet.sol:36` | `PExitTarget.sol:70` `_entryPreviewWithdrawSingle` | E |
| `previewExitProportionalFlexible(uint256,bool[])` | `interfaces/IUniswapV4BalancerStableLiquidityUnits.sol:13` | `facets/PExitFacet.sol:37` | `PExitTarget.sol:76` `_entryPreviewExitProportionalFlexible` | E |
| `beforeInitialize(address,PoolKey,uint160)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:22` | `facets/PHooksFacet.sol:32` | `PHooksTarget.sol:331` `_hookBeforeInitialize` | R |
| `afterInitialize(address,PoolKey,uint160,int24)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:30` | `facets/PHooksFacet.sol:33` | `PHooksTarget.sol:332` `_hookAfterInitialize` | R |
| `beforeAddLiquidity(address,PoolKey,ModifyLiquidityParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:40` | `facets/PHooksFacet.sol:34` | `PHooksTarget.sol:333` `_hookBeforeAddLiquidity` | R |
| `afterAddLiquidity(address,PoolKey,ModifyLiquidityParams,BalanceDelta,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:56` | `facets/PHooksFacet.sol:35` | `PHooksTarget.sol:334` `_hookAfterAddLiquidity` | R |
| `beforeRemoveLiquidity(address,PoolKey,ModifyLiquidityParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:71` | `facets/PHooksFacet.sol:36` | `PHooksTarget.sol:335` `_hookBeforeRemoveLiquidity` | R |
| `afterRemoveLiquidity(address,PoolKey,ModifyLiquidityParams,BalanceDelta,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:87` | `facets/PHooksFacet.sol:37` | `PHooksTarget.sol:336` `_hookAfterRemoveLiquidity` | R |
| `beforeSwap(address,PoolKey,SwapParams,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:104` | `facets/PHooksFacet.sol:38` | `PHooksTarget.sol:337` `_hookBeforeSwap` | S |
| `afterSwap(address,PoolKey,SwapParams,BalanceDelta,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:116` | `facets/PHooksFacet.sol:39` | `PHooksTarget.sol:338` `_hookAfterSwap` | R |
| `beforeDonate(address,PoolKey,uint256,uint256,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:131` | `facets/PHooksFacet.sol:40` | `PHooksTarget.sol:339` `_hookBeforeDonate` | R |
| `afterDonate(address,PoolKey,uint256,uint256,bytes)` | `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol:146` | `facets/PHooksFacet.sol:41` | `PHooksTarget.sol:340` `_hookAfterDonate` | R |
| `poolManager()` | `interfaces/IP.sol:52` | `facets/PHooksFacet.sol:42` | `PHooksTarget.sol:311` `_bindingPoolManager` | R |
| `feeOracle()` | `interfaces/IP.sol:53` | `facets/PHooksFacet.sol:43` | `PHooksTarget.sol:304` `_bindingFeeOracle` | R |
| `permit2()` | `interfaces/IP.sol:54` | `facets/PHooksFacet.sol:44` | `PHooksTarget.sol:312` `_bindingPermit2` | R |
| `numTokens()` | `interfaces/IP.sol:55` | `facets/PHooksFacet.sol:45` | `PHooksTarget.sol:313` `_bindingNumTokens` | R |
| `tokens()` | `interfaces/IP.sol:56` | `facets/PHooksFacet.sol:46` | `PHooksTarget.sol:305` `_bindingTokens` | R |
| `token(uint256)` | `interfaces/IP.sol:57` | `facets/PHooksFacet.sol:47` | `PHooksTarget.sol:314` `_bindingToken` | R |
| `baseAmp()` | `interfaces/IP.sol:58` | `facets/PHooksFacet.sol:48` | `PHooksTarget.sol:315` `_bindingBaseAmp` | R |
| `getCurrentAmp()` | `interfaces/IP.sol:59` | `facets/PHooksFacet.sol:49` | `PHooksTarget.sol:316` `_bindingCurrentAmp` | R |
| `standardExchange(uint256)` | `interfaces/IP.sol:60` | `facets/PHooksFacet.sol:50` | `PHooksTarget.sol:317` `_bindingStandardExchange` | R |
| `rateProvider(uint256)` | `interfaces/IP.sol:61` | `facets/PHooksFacet.sol:51` | `PHooksTarget.sol:318` `_bindingRateProvider` | R |
| `isBuffered(uint256)` | `interfaces/IP.sol:66` | `facets/PHooksFacet.sol:52` | `PHooksTarget.sol:319` `_bindingIsBuffered` | R |
| `nativeReserve(uint256)` | `interfaces/IP.sol:70` | `facets/PHooksFacet.sol:53` | `PHooksTarget.sol:322` `_bindingNativeReserve` | Q |
| `nativeReserves()` | `interfaces/IP.sol:71` | `facets/PHooksFacet.sol:54` | `PHooksTarget.sol:323` `_bindingNativeReserves` | Q |
| `ratedBalance(uint256)` | `interfaces/IP.sol:72` | `facets/PHooksFacet.sol:55` | `PHooksTarget.sol:326` `_bindingRatedBalance` | Q |
| `ratedBalances()` | `interfaces/IP.sol:73` | `facets/PHooksFacet.sol:56` | `PHooksTarget.sol:327` `_bindingRatedBalances` | Q |
| `seBalance(uint256)` | `interfaces/IP.sol:74` | `facets/PHooksFacet.sol:57` | `PHooksTarget.sol:324` `_bindingSeBalance` | R |
| `seClaim(uint256)` | `interfaces/IP.sol:75` | `facets/PHooksFacet.sol:58` | `PHooksTarget.sol:325` `_bindingSeClaim` | Q |
| `invScale(uint256)` | `interfaces/IP.sol:76` | `facets/PHooksFacet.sol:59` | `PHooksTarget.sol:320` `_bindingInvScale` | R |
| `ratedScale(uint256)` | `interfaces/IP.sol:77` | `facets/PHooksFacet.sol:60` | `PHooksTarget.sol:321` `_bindingRatedScale` | Q |
| `dexSwapFee()` | `interfaces/IP.sol:81` | `facets/PHooksFacet.sol:61` | `PHooksTarget.sol:306` `_bindingDexSwapFee` | R |
| `usageFee()` | `interfaces/IP.sol:82` | `facets/PHooksFacet.sol:62` | `PHooksTarget.sol:307` `_bindingUsageFee` | R |
| `feeTo()` | `interfaces/IP.sol:83` | `facets/PHooksFacet.sol:63` | `PHooksTarget.sol:308` `_bindingFeeTo` | R |
| `kLast()` | `interfaces/IP.sol:84` | `facets/PHooksFacet.sol:64` | `PHooksTarget.sol:328` `_bindingKLast` | Q |
| `isFullBook()` | `interfaces/IP.sol:85` | `facets/PHooksFacet.sol:65` | `PHooksTarget.sol:309` `_bindingIsFullBook` | R |
| `pairDoorCount()` | `interfaces/IP.sol:89` | `facets/PHooksFacet.sol:66` | `PHooksTarget.sol:310` `_bindingPairDoorCount` | R |
| `previewSwapExactIn(address,address,uint256)` | `interfaces/IP.sol:93` | `facets/PHooksFacet.sol:67` | `PHooksTarget.sol:341` `_hookPreviewSwapExactIn` | S |
| `previewSwapExactOut(address,address,uint256)` | `interfaces/IP.sol:98` | `facets/PHooksFacet.sol:68` | `PHooksTarget.sol:342` `_hookPreviewSwapExactOut` | S |
| `rateProviders()` | `interfaces/IP.sol:63` | `facets/PHooksFacet.sol:69` | `PHooksTarget.sol:329` `_bindingRateProviders` | R |
| `rateProvider(address)` | `interfaces/IP.sol:65` | `facets/PHooksFacet.sol:70` | `PHooksTarget.sol:330` `_bindingRateProviderOfAddress` | R |
| `previewExchangeOut(IERC20,IERC20,uint256)` | `lib/crane/contracts/interfaces/IStandardExchangeOut.sol:51` | `facets/PHooksFacet.sol:71` | `PSeTarget.sol:166` `_entryPreviewExchangeOut` | J/E |
| `exchangeOut(IERC20,uint256,IERC20,uint256,address,bool,uint256)` | `lib/crane/contracts/interfaces/IStandardExchangeOut.sol:67` | `facets/PHooksFacet.sol:72` | `PSeTarget.sol:169` `_entryExchangeOut` | J/E |
| `joinProportional(uint256[],address,uint256,uint256)` | `interfaces/IP.sol:149` | `facets/PLiquidityFacet.sol:12` | `PLiquidityTarget.sol:8` `_entryJoinProportional` | J/E |
| `joinUnbalanced(uint256[],address,uint256,uint256)` | `interfaces/IP.sol:172` | `facets/PLiquidityFacet.sol:13` | `PLiquidityTarget.sol:17` `_entryJoinUnbalanced` | J/E |
| `joinSingleAssetExactOut(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:164` | `facets/PLiquidityFacet.sol:14` | `PLiquidityTarget.sol:22` `_entryJoinSingleAssetExactOut` | J/E |
| `joinSingleAssetExactIn(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:156` | `facets/PLiquidityFacet.sol:15` | `PLiquidityTarget.sol:27` `_entryJoinSingleAssetExactIn` | J/E |
| `depositSingle(address,uint256,address,uint256,uint256)` | `interfaces/IP.sol:196` | `facets/PLiquidityFacet.sol:16` | `PLiquidityTarget.sol:37` `_entryDepositSingle` | J/E |
| `joinProportionalFlexible(uint256[],bool[],address,uint256,uint256)` | `interfaces/IUniswapV4BalancerStableLiquidityUnits.sol:11` | `facets/PLiquidityFacet.sol:17` | `PLiquidityTarget.sol:47` `_entryJoinProportionalFlexible` | J/E |
| `joinUnbalanced(address[],uint256[],address,uint256,uint256)` | `interfaces/IUniswapV4BalancerStableLiquidityUnits.sol:18` | `facets/PLiquidityFacet.sol:18` | `PLiquidityTarget.sol:52` `_entryJoinUnbalanced` | J/E |
| `previewJoinProportional(uint256[])` | `interfaces/IP.sol:103` | `facets/PQueryFacet.sol:16` | `PQueryTarget.sol:20` `_entryPreviewJoinProportional` | J/E |
| `previewJoinUnbalanced(uint256[])` | `interfaces/IP.sol:118` | `facets/PQueryFacet.sol:17` | `PQueryTarget.sol:27` `_entryPreviewJoinUnbalanced` | J/E |
| `previewJoinSingleAssetExactOut(address,uint256)` | `interfaces/IP.sol:113` | `facets/PQueryFacet.sol:18` | `PQueryTarget.sol:31` `_entryPreviewJoinSingleAssetExactOut` | J/E |
| `previewJoinSingleAssetExactIn(address,uint256)` | `interfaces/IP.sol:108` | `facets/PQueryFacet.sol:19` | `PQueryTarget.sol:39` `_entryPreviewJoinSingleAssetExactIn` | J/E |
| `previewDepositSingle(address,uint256)` | `interfaces/IP.sol:132` | `facets/PQueryFacet.sol:20` | `PQueryTarget.sol:46` `_entryPreviewDepositSingle` | J/E |
| `previewJoinProportionalFlexible(uint256[],bool[])` | `interfaces/IUniswapV4BalancerStableLiquidityUnits.sol:9` | `facets/PQueryFacet.sol:21` | `PQueryTarget.sol:59` `_entryPreviewJoinProportionalFlexible` | J/E |
| `previewJoinUnbalanced(address[],uint256[])` | `interfaces/IUniswapV4BalancerStableLiquidityUnits.sol:17` | `facets/PQueryFacet.sol:22` | `PQueryTarget.sol:66` `_entryPreviewJoinUnbalanced` | J/E |
| `previewExchangeIn(IERC20,uint256,IERC20)` | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:46` | `facets/PQueryFacet.sol:23` | `PQueryTarget.sol:16` `_previewExchangeIn` | J/E |
| `exchangeIn(IERC20,uint256,IERC20,uint256,address,bool,uint256)` | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:62` | `facets/PSeFacet.sol:32` | `PSeTarget.sol:48` `LiquidityRoute.isLiquidityRoute`, `_exchangeIn`, `_swapExchangeIn` | J/E |
| `exchangeRate()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:101` | `facets/PQueryFacet.sol:24` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:17` (direct getter/guard) | Q |
| `yieldToken()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:132` | `facets/PQueryFacet.sol:24` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:15` (direct getter/guard) | R |
| `assetInfo()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:165` | `facets/PQueryFacet.sol:24` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:16` (direct getter/guard) | R |
| `getTokensIn()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:137` | `facets/PQueryFacet.sol:24` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:13` (direct getter/guard) | R |
| `getTokensOut()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:142` | `facets/PQueryFacet.sol:24` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:14` (direct getter/guard) | R |
| `isValidTokenIn(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:144` | `facets/PQueryFacet.sol:24` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:7` (direct getter/guard) | R |
| `isValidTokenOut(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:146` | `facets/PQueryFacet.sol:24` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:8` (direct getter/guard) | R |
| `previewDeposit(address,uint256)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:148` | `facets/PQueryFacet.sol:24` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol:10` `_previewExchangeIn` | J/E |
| `previewRedeem(address,uint256)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:153` | `facets/PQueryFacet.sol:24` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol:15` `_previewExchangeIn` | E |
| `getRewardTokens()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:127` | `facets/PQueryFacet.sol:24` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:27` (direct getter/guard) | R |
| `accruedRewards(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:118` | `facets/PQueryFacet.sol:24` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:28` (direct getter/guard) | R |
| `rewardIndexesStored()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:122` | `facets/PQueryFacet.sol:24` via `_appendQuery` | `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol:29` (direct getter/guard) | R |
| `rewardIndexesCurrent()` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:120` | `facets/PQueryFacet.sol:25` via `_appendRewards` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:78` (direct getter/guard) | R |
| `claimRewards(address)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:111` | `facets/PQueryFacet.sol:25` via `_appendRewards` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:79` (direct getter/guard) | R |
| `deposit(address,address,uint256,uint256)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:68` | `facets/PSeFacet.sol:33` via `_appendMoney` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:18` `_standardRoute` | J/E |
| `redeem(address,uint256,address,uint256,bool)` | `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:86` | `facets/PSeFacet.sol:33` via `_appendMoney` | `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:30` `_requireVaultHeldShares`, `_redeemVaultHeld`, `_standardRoute` | E |


## Shared, factory and lifecycle surfaces

`NativeStandardYieldSelectors.sol:8-104` under `contracts/vaults/standard/sy/` appends selectors; these are expanded individually above, not omitted because they are absent from literal `funcs[i]` assignments. H2 splits money into DepositSingleFacet, explicit previews into DepositPreviewFacet and discovery/rewards into WithdrawFacet. H3 appends query to WithdrawFacet and execution to SeFacet. H4 puts SY deposit/redeem on SeFacet and queries/rewards on DepositQueryFacet. H5-H7 append execution to SeFacet and query/reward surfaces to their query role. Hook SY is not the FullSpread vault: the vault itself must still have no SY selectors.

| Installed shared facet | Families | Exact named surface | Accounting/test obligation |
| --- | --- | --- | --- |
| `contracts/vaults/basic/MultiAssetBasicVaultFacet.sol:35` | H1-H7 | `IBasicVault.vaultTokens`, `IBasicVault.reserveOfToken`, `IBasicVault.reserves` | Retain discovery; family reserve synchronization must expose local-plus-rated swap book with correct units, not LP entitlement. Family VaultViews/SeBufferAbi/Package and matrix. |
| `contracts/vaults/standard/MultiAssetStandardVaultFacet.sol:32` | H1-H7 | `IStandardVault.vaultFeeTypeIds`, `IStandardVault.contentsId`, `IStandardVault.vaultTypes`, `IStandardVault.vaultConfig` | Retain registered vault metadata/fee type IDs; family Package/VaultViews. |
| `lib/crane/contracts/access/ERC8023/MultiStepOwnableFacet.sol:57` | H2/H4/H5/H6 | `IMultiStepOwnable.initiateOwnershipTransfer`, `IMultiStepOwnable.confirmOwnershipTransfer`, `IMultiStepOwnable.cancelPendingOwnershipTransfer`, `IMultiStepOwnable.acceptOwnershipTransfer`, `IMultiStepOwnable.owner`, `IMultiStepOwnable.pendingOwner`, `IMultiStepOwnable.preConfirmedOwner`, `IMultiStepOwnable.getOwnershipTransferBuffer` | Preserve owner-only-liquidity and owner-swap ACL, including stateful ownership transfer; family ownership/surface tests. |
| `lib/crane/contracts/tokens/ERC20/ERC20Facet.sol:67` | H2-H7 | `IERC20Metadata.name`, `IERC20Metadata.symbol`, `IERC20Metadata.decimals`, `IERC20.totalSupply`, `IERC20.balanceOf`, `IERC20.allowance`, `IERC20.approve`, `IERC20.transfer`, `IERC20.transferFrom` | Retain shared LP token/permit/domain implementation; no fee on transfer/approve/permit. Supply includes locked floor and protocol LP; family token/permit/package tests. |
| `lib/crane/contracts/tokens/ERC2612/ERC2612Facet.sol:44` | H2-H7 | `IERC20Permit.permit`, `IERC20Permit.nonces`, `IERC20Permit.DOMAIN_SEPARATOR` | Retain shared LP token/permit/domain implementation; no fee on transfer/approve/permit. Supply includes locked floor and protocol LP; family token/permit/package tests. |
| `lib/crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol:45` | H2-H7 | `IERC5267.eip712Domain` | Retain shared LP token/permit/domain implementation; no fee on transfer/approve/permit. Supply includes locked floor and protocol LP; family token/permit/package tests. |

Factory base cuts: `contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory.sol:184-205` installs ERC165, DiamondLoupe, ERC8109 `functionFacetPairs`, temporary postDeployHook and HookFlags. `:242-247` removes the temporary post-deploy facet. Product packages do not install arbitrary factory selectors. No diamondCut upgrade is inferred. These are retained metadata surfaces; runtime destinations are factory tests plus family Package/StagedInit/Surface tests.

Each H1-H7 `facets/PInitFacet.sol:33-40` independently installs `IHooks.beforeInitialize` plus `IUniswapV4HookStagedPairInit.deployPair`, `finalizeInitialization`, `isPairPoolLive`, `pairPoolKey`, `isInitializationFinalized` (`contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol`). SELF is a temporary bootstrap implementation; the package production cuts install final facets when finalization replaces SELF. The final beforeInitialize belongs to the product/hooks facet. Do not confuse staged pool creation/initialization (no LP seed by itself) with a T=0 money route. Each family StagedInit suite is the destination. Orbital DepositFlexibleFacet exists in source but is not in `P...DFPkg.facetAddresses`; its two selectors are actually installed through DepositFacet and DepositQueryFacet, so it is not counted twice. H2 legacy aggregate Target and H5/H6 aggregate LiquidityTarget are not independent installed entrypoints merely because they contain public functions.

## Missing interface selectors and limits

- H3: `previewSwapAfterExchange(address,address,address,uint256)` is declared at `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:19` and inherited by `interfaces/IP.sol:17`, but absent from every installed product facet list. Owner: Task 8 / facade integration Task 13. Destination: HT `dual/UniswapV4DualSEBCPHook_Surface.t.sol` and the dual FullSpread matrix. This is a source installation gap, not an observed unknown-selector revert.
- H3: `previewJoinAfterDeposit(address,address,uint256)` is declared at `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:24` and inherited by `interfaces/IP.sol:17`, but absent from every installed product facet list. Owner: Task 8 / facade integration Task 13. Destination: HT `dual/UniswapV4DualSEBCPHook_Surface.t.sol` and the dual FullSpread matrix. This is a source installation gap, not an observed unknown-selector revert.
- H3: `previewBondAfterDeposit(address,address,address,uint256,uint256)` is declared at `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol:30` and inherited by `interfaces/IP.sol:17`, but absent from every installed product facet list. Owner: Task 8 / facade integration Task 13. Destination: HT `dual/UniswapV4DualSEBCPHook_Surface.t.sol` and the dual FullSpread matrix. This is a source installation gap, not an observed unknown-selector revert.

No primary H1/H2/H4/H5/H6/H7 product-interface selector was missing in this source comparison, and no H3 primary product selector other than those three inherited projections was missing. Optional claim-quote siblings are not universally inherited requirements. H7 units-interface selectors (proportional flexible pair/share flags, named unbalanced inputs and corresponding previews/exits) are installed through LiquidityFacet, QueryFacet and ExitFacet, although the main H7 product interface does not redeclare them. Generic flexible single-asset selectors are supported only on hosts that actually install them; do not infer them for H1/H2/H3/H4/H7 from the shared interface file.

## Cross-family component and facade paths

| Family | Join/exit implementation spine | Swap/custody spine |
| --- | --- | --- |
| H1 | No LP mint/burn, locked LP floor or supply-based genesis. | Common + Target, four wrap/unwrap previews and beforeSwap. Keep actual pending/retained pair/share custody, tuple refund, disabled deposit reject and permitted redemption. |
| H2 | DepositTarget/DepositSingleTarget -> DepositCommon; projection and single quote targets; WithdrawTarget -> WithdrawalLib/ClaimLib; InExecutionBase/InQuoteBase for SE and Native SY. | SeTarget and ClaimLib, pool-settlement callbacks and owner swaps; legacy aggregate Target is not the sole fix site. |
| H3 | DepositTarget -> Common, DepositQuoteLib and InQuoteBase; WithdrawTarget -> Common/ClaimLib. Flexible flags and named unbalanced SE-share inputs converge here. | HooksTarget/SeTarget -> Common/ClaimLib; separate two-vault contexts, sequential/fallback quoting and ordering. |
| H4 | DepositTarget/DepositFlexibleTarget/DepositZapTarget -> DepositCore/Common; DepositQueryTarget and ExitQuoteLib; WithdrawTarget; InExecutionBase. | HooksTarget/SeTarget -> Common/ClaimLib, exactly three leg records. R/lSquared still serve sphere math. |
| H5 | JoinTarget/JoinFlexibleTarget/JoinQueryTarget -> JoinCore -> LiquidityLib/Target; ExitTarget/ExitQueryTarget -> ExitCore/InQuoteBase; PullLib and InExecutionBase. | HooksTarget/SeTarget -> Target/ClaimLib; preserve weights, n=2..8 and supported partial-book topology. |
| H6 | JoinTarget/JoinQueryTarget -> JoinCore; ExitTarget -> ExitExecutionBase/ExitQuoteBase; InExecutionBase. Aggregate LiquidityTarget alone is insufficient. | HooksTarget/SeTarget -> Target/ClaimLib, four-element arrays and amp-specific curve. |
| H7 | LiquidityTarget/ExitTarget/QueryTarget -> LiquidityCore and UniswapV4BalancerStableLiquidityUnitsCore/Target; InExecutionBase/InQuoteBase. | HooksTarget/SeTarget -> Target/ClaimLib, n=2..5 and amp-specific StableMath. |

The per-selector rows give exact source anchors for these spines. Shared `contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol:30-118` calls the installed exact-in/exact-net join or exit aliases and delegates on the host; maxima/minima and pretransfer rejection remain. Its share-aware routes use the already installed flexible selectors only. `UniswapV4BufferHookLiquidityExecutionBase.sol` provides the corresponding family adapters. Native SY money methods in `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol` enter the same money hooks; previews enter its quote base. Fee gross-up therefore cannot be patched only into the family-named deposit.

Shared classification: `UniswapV4SeBufferHookLegLib.sol:157-205` still has own-address/wrapper classification, `pairInVaultTokens`, `isWrapperShareInventory` and the raw `asset()` selector probe. H2/H4/H5/H6/H7 DFPkg validators also call the wrapper shortcut. These need FS-OWN-35 paired membership plus implicit own-share handling, not a fake share-as-pair binding. `UniswapV4SeBufferHookContextQuoteLib.sol` retains optional ERC165 context gating/fallback; `contracts/utils/ExchangeInAmount.sol` one-word consumers and `LocalCreditLib.sol` must receive correct actual tuple/custody information rather than rated claims. No unavailable context interface is assumed.

## Fee configuration and replacement contract

H2/H3 resolve `(feeTo, WAD percentage)` through `IVaultFeeOracleQuery.dexSwapFeeAndFeeToOfVault(address(this))`; current activation requires nonzero recipient and nonzero resolved percentage. H4-H7 use `feeTo()` and `usageFeeOfVault(address(this))`; the old helper also checks percentage < WAD and a nonzero denominator-scaled owner-share intermediate. Preserve configured sources and activation policy under the plan; apply the resolved WAD percentage to backed gross LP, not that legacy scaled intermediate. The source-specific function locations are enumerated below. H1 has no Hook LP fee source and its zero feeOracle is not trusted disable authority.

Oracle fallback is concrete: `contracts/oracles/fee/VaultFeeOracleQueryFacet.sol:105-115` resolves usage override -> type default -> global default; `:147-168` does the same for dex swap fee and returns live feeTo. Stored zero is unset. `VaultFeeOracleRepo.sol:184-202,335-349` stores those overrides. Do not impose FullSpread vault 30% clamping on hooks or create an explicit-zero override.

Replacement: feeLP=floor(g*f/1e18), netLP=g-feeLP, total newly minted LP=g, recipient zero/inactive gives no fee. Floor is allocated separately once on genesis. Views/minima use net LP. Exact net n>0 requires minimal gross floor((n-1)*W/(W-f))+1 for active f<W, with forward and predecessor checks; infeasible requests fail before funding. There is no growth/withdrawal/rate-only mint. Preserve trading-fee math and swap invariants, append books without shifting storage, and leave retired fee-only slots reserved.

### All growth-fee, forecast and checkpoint consumers

This is a file-by-file static occurrence inventory, including definitions, direct callers, projected post-fee supply and fee checkpoints. It includes noninstalled aggregate implementations so stale duplicated logic is not mistaken for a finished change. `live closure` means an ancestor of an installed facet by source imports, not proven runtime reachability of every internal function. Swap invariants must be reviewed by actual consumers before removing fee-only state.

| Family | Source file | Source lines: growth/forecast/checkpoint references | Installation scope |
| --- | --- | --- | --- |
| H2 | `PDepositPreviewTarget.sol` | 70, 85, 110 | live closure |
| H2 | `PDepositCommon.sol` | 101, 836, 840, 845, 851, 854, 855, 858, 863, 866, 867, 923 | live closure |
| H2 | `PDepositProjectionTarget.sol` | 57, 82, 105 | live closure |
| H2 | `PInQuoteBase.sol` | 62, 74, 90, 192, 194, 198, 201, 202 | live closure |
| H2 | `PMath.sol` | 132, 138 | linked helper or aggregate; see selector path |
| H2 | `PTarget.sol` | 820, 957, 1113, 1183, 1243, 1247, 1253, 1259, 1262, 1267, 1301, 1350, 1398, 1419 | linked helper or aggregate; see selector path |
| H2 | `PSeTarget.sol` | 919, 923, 929, 935, 938, 943 | live closure |
| H2 | `PWithdrawTarget.sol` | 516, 553, 622, 630, 635, 645, 667, 742 | live closure |
| H2 | `PWithdrawalLib.sol` | 115, 116, 117, 123 | linked helper or aggregate; see selector path |
| H3 | `PCommon.sol` | 550, 606, 739, 962, 1093, 1098, 1105, 1115, 1119, 1124, 1142, 1204, 1217, 1278, 1292 | live closure |
| H3 | `PDepositQuoteLib.sol` | 53, 170, 179 | linked helper or aggregate; see selector path |
| H3 | `PDepositTarget.sol` | 147, 370 | live closure |
| H3 | `PInQuoteBase.sol` | 91 | live closure |
| H3 | `PMath.sol` | 78, 84 | linked helper or aggregate; see selector path |
| H3 | `PWithdrawTarget.sol` | 67 | live closure |
| H4 | `PDepositCore.sol` | 66 | live closure |
| H4 | `PCommon.sol` | 957, 960, 964, 966, 967, 970, 976, 980, 985, 986, 990, 998, 1002, 1004, 1005, 1261, 1330, 1361, 1479, 1509, 1560, 1592, 1609, 1844, 1882, 1893, 1933, 1961, 2135 | live closure |
| H4 | `PDepositQueryTarget.sol` | 33 | live closure |
| H4 | `PExitQuoteLib.sol` | 419, 424, 427 | linked helper or aggregate; see selector path |
| H4 | `PHooksTarget.sol` | 177, 178 | live closure |
| H4 | `PMath.sol` | 254, 257, 260, 263, 264 | linked helper or aggregate; see selector path |
| H4 | `PRepo.sol` | 55 | linked helper or aggregate; see selector path |
| H4 | `facets/PHooksFacet.sol` | 68 | live closure |
| H5 | `PExitCore.sol` | 77, 108, 122, 146, 198, 215, 234, 296, 320, 357, 370, 386, 416, 493, 513 | live closure |
| H5 | `PExitQueryTarget.sol` | 138, 156 | live closure |
| H5 | `PHooksTarget.sol` | 401 | live closure |
| H5 | `PJoinCore.sol` | 193, 209, 316, 352, 359, 362, 396, 403, 421, 428, 502, 568, 604, 630, 650, 697, 719, 724, 726, 756, 820, 855 | live closure |
| H5 | `PJoinQueryTarget.sol` | 19 | live closure |
| H5 | `PLiquidityTarget.sol` | 88, 103, 206, 239, 246, 249, 276, 312, 319, 337, 344, 417, 460, 494, 518, 537, 571, 584, 608, 674, 691, 708, 765, 789, 824, 851, 872, 877, 879, 939, 951, 966, 996, 1077, 1111, 1174, 1194 | linked helper or aggregate; see selector path |
| H5 | `PMath.sol` | 165, 167, 170, 173, 176, 177 | linked helper or aggregate; see selector path |
| H5 | `PRepo.sol` | 41 | linked helper or aggregate; see selector path |
| H5 | `PTarget.sol` | 232, 233, 417, 418, 421, 425, 427, 430, 433, 435, 436, 439, 444, 448, 452, 453 | live closure |
| H5 | `facets/PHooksFacet.sol` | 64 | live closure |
| H6 | `PExitExecutionBase.sol` | 20, 37 | live closure |
| H6 | `PExitQuoteBase.sol` | 14 | live closure |
| H6 | `PExitTarget.sol` | 43, 85, 109, 154, 167, 182, 209, 267, 283, 291 | live closure |
| H6 | `PHooksTarget.sol` | 428 | live closure |
| H6 | `PJoinCore.sol` | 75, 86, 181, 230, 267, 343, 357, 366, 412, 415, 447, 468, 478, 536, 549, 633, 645, 694 | live closure |
| H6 | `PJoinQueryTarget.sol` | 33, 127 | live closure |
| H6 | `PLiquidityTarget.sol` | 44, 55, 150, 208, 227, 281, 295, 304, 345, 387, 411, 457, 460, 509, 517, 557, 570, 585, 612, 673, 690, 702, 729, 742, 826, 841, 857, 865, 937, 986, 1084, 1104 | linked helper or aggregate; see selector path |
| H6 | `PMath.sol` | 140, 143, 146, 149, 150 | linked helper or aggregate; see selector path |
| H6 | `PRepo.sol` | 18 | linked helper or aggregate; see selector path |
| H6 | `PTarget.sol` | 47, 62, 79, 90, 628, 631, 634, 642, 643, 646, 650, 653, 657, 661, 664 | live closure |
| H7 | `UniswapV4BalancerStableLiquidityUnitsCore.sol` | 21, 29, 37, 105, 124, 130, 168, 185, 194 | live closure |
| H7 | `PLiquidityCore.sol` | 43, 54, 116, 130, 138, 156, 164, 172, 194, 223, 236, 260, 288, 302, 319, 388, 403, 430, 497, 519, 531 | live closure |
| H7 | `PMath.sol` | 228 | linked helper or aggregate; see selector path |
| H7 | `PQueryTarget.sol` | 75 | live closure |
| H7 | `PRepo.sol` | 13, 54, 56, 57 | linked helper or aggregate; see selector path |
| H7 | `PTarget.sol` | 441, 442, 445, 450, 451, 457, 458, 459, 460, 461, 466, 470, 473, 477, 480, 483, 488, 491, 496, 501, 503, 505, 508, 509 | live closure |

Fee resolution and activation definitions:

- H2 `PDepositCommon.sol:178` `dexSwapFeeAndFeeTo`.
- H2 `PDepositCommon.sol:268` `_feeOnAndShare`.
- H2 `PInQuoteBase.sol:205` `_singleFeeShare`.
- H2 `PTarget.sol:172` `dexSwapFeeAndFeeTo`.
- H2 `PTarget.sol:259` `_feeOnAndShare`.
- H2 `PSeTarget.sol:170` `dexSwapFeeAndFeeTo`.
- H2 `PSeTarget.sol:349` `_feeOnAndShare`.
- H2 `PWithdrawTarget.sol:176` `dexSwapFeeAndFeeTo`.
- H2 `PWithdrawTarget.sol:258` `_feeOnAndShare`.
- H3 `PCommon.sol:331` `_feeOnAndShare`.
- H3 `PHooksTarget.sol:128` `feeTo`.
- H4 `PCommon.sol:484` `_feeOnAndShare`.
- H4 `PHooksTarget.sol:162` `usageFee`.
- H4 `PHooksTarget.sol:167` `feeTo`.
- H5 `PTarget.sol:220` `usageFee`.
- H5 `PTarget.sol:224` `feeTo`.
- H5 `PTarget.sol:388` `_feeOnAndShare`.
- H6 `PHooksTarget.sol:354` `usageFee`.
- H6 `PHooksTarget.sol:355` `feeTo`.
- H6 `PTarget.sol:609` `_feeOnAndShare`.
- H7 `PHooksTarget.sol:307` `usageFee`.
- H7 `PHooksTarget.sol:308` `feeTo`.
- H7 `PTarget.sol:418` `_feeOnAndShare`.

## T=0 funding and share-input routing

The following existing selectors already carry SE shares; no new public selector is proposed. Every ordinary/pair-input, Permit2, flexible, SE, SY and exact-net alias remains represented in the selector tables and must either reach the share-only bootstrap kernel or reject its unsupported initial topology atomically. A pair-funded alias cannot call the SE deposit internally and claim compliance. Single-asset routes that currently require a live/full book keep that guard, rather than inventing new one-leg genesis.

| Family | Existing share-funded routes | Existing pair/raw genesis and seed shape to adapt | Destination |
| --- | --- | --- | --- |
| H1 | Wrap/unwrap are conversions, not LP funding. | No supply or LP bootstrap; retained custody/refund/disable behavior only. | HT single matrix/Swap and VT SingleUnwrap. |
| H2 | depositWithSeShares(raw,SE shares), previewDepositWithSeShares; named joinUnbalanced accepts SE address plus raw. | Ordinary deposit and Permit2 dual input currently buffer pair input; share route currently seeds on rated claim. Keep geometric shape, feed normalized retained SE shares plus normalized raw after actual 5% redemption. | H2 Liquidity, FeeCapital, SeBufferAbi, decimal variants and FullSpread _seed. |
| H3 | depositFlexible with both SE flags on funded SE legs; named joinUnbalanced can accumulate each SE-share input. | Ordinary/Permit2 dual deposit buffers pair tokens; flexible first mint uses claimSupply. Keep geometric two-leg shape, not rated reserve inputs. | H3 Core/B6M3/SeBufferAbi/decimals and FullSpread dual _seed. |
| H4 | depositFlexible flags per funded SE leg and named joinUnbalanced; unused/raw legs retain their raw mode. | addLiquidity and Permit2-data intake, plus flexible first mint, currently compute offered effective quantities. Keep >=2 positive legs and supported 3-leg sphere seed-function shape/floor; retained-share/raw coordinates replace rated ones. | H4 Liquidity/B6/ZapIn/decimals, _seedMixed and shared _seed. |
| H5 | joinProportionalFlexible(amounts, flags), named joinUnbalanced with SE token addresses; existing flexible single aliases only when their topology permits. | Proportional and unbalanced ordered pair inputs, full/partial first mint branches, SE/SY facade routes. n=2 needs two positive legs; larger n permits supported >=2-positive partial topology. Keep weighted full/interim shape on retained shares/raw. | H5 Liquidity/Flexible/TokenCount/SeBufferAbi and _seedWeighted/_seedThree/_seedFullBook. |
| H6 | joinProportionalFlexible with SE flags and named joinUnbalanced; flexible single routes preserve pre-live guards. | Proportional/unbalanced ordered inputs require four positive inventory legs; fixed-four geometric seed shape and existing floor remain, rate-free. | H6 Liquidity/Flexible/SeBufferAbi/decimals and _seedCurve/_joinAll/_seedFullBook. |
| H7 | IUniswapV4BalancerStableLiquidityUnits.joinProportionalFlexible, named joinUnbalanced; same selectors installed by final facets. | LiquidityCore and UnitsCore both have first branches; all n=2..5 active legs positive. Preserve current stable invariant/active-count shape after normalized retained-share/raw inputs, no separate mint for local proceeds. | H7 Liquidity/Units/TokenCount/SeBufferAbi/decimals and _seedBalancer/_joinAll/_seedFullBook. |

For every funded SE leg receive actual caller A, redeem floor(A*5/100) through exact-input share-in/member-pair-out, verify exact consumption and positive actual local receipt, retain the rest. No ambient balance, rate, exchangeOut, assumed refund or 1:1 conversion is a seed. Allocate the locked floor once, then split backed gross LP into protocol and net LP. Existing helpers which return floor-subtracted seed amounts must not subtract it twice. Disabled permitted redemption can work without an SE mint/cleanup deposit. Subsequent joins use actual current component ratios, never the initial 5% rule.

### Explicit zero-supply/first-mint branches and guards

Line lists include all observed first/zero-supply branches, seed helper definitions and live-book guards in production family sources, including preview/aggregate duplicates. A zero-supply return in an exit view is a guard, not another funding route.

| Family | Source file | Branch/seed/guard lines |
| --- | --- | --- |
| H2 | `PDepositPreviewTarget.sol` | 87 |
| H2 | `PDepositCommon.sol` | 208, 240, 242, 465, 519, 525, 526, 527, 561, 576, 582, 583, 584, 896, 902, 903 |
| H2 | `PDepositProjectionTarget.sol` | 44, 51, 52, 116 |
| H2 | `PInQuoteBase.sol` | 79, 95 |
| H2 | `PRepo.sol` | 18 |
| H2 | `PTarget.sol` | 202, 826, 895, 901, 902, 903, 1281, 1288, 1289, 1399, 1401, 1420 |
| H2 | `PSeTarget.sol` | 292 |
| H2 | `PWithdrawTarget.sol` | 206, 468, 646, 648, 668, 669, 743 |
| H2 | `PWithdrawalLib.sol` | 33 |
| H3 | `PCommon.sol` | 277, 553, 577, 588, 589, 590, 825, 874, 880, 881, 882, 1135, 1146, 1156, 1157, 1255, 1267, 1268 |
| H3 | `PRepo.sol` | 20 |
| H3 | `PWithdrawTarget.sol` | 68 |
| H4 | `PCommon.sol` | 160, 179, 182, 447, 1015, 1029, 1042, 1288, 1303, 1320, 1474, 1647, 1675, 1688, 1742, 1839 |
| H4 | `PDepositQueryTarget.sol` | 34 |
| H4 | `PExitQuoteLib.sol` | 31, 217, 282 |
| H4 | `PMath.sol` | 129, 130, 131, 134, 155, 182, 192, 203, 260, 420, 434 |
| H4 | `PRepo.sol` | 23 |
| H4 | `PWithdrawTarget.sol` | 126, 181 |
| H5 | `PExitQueryTarget.sol` | 157 |
| H5 | `PJoinCore.sol` | 194, 212, 223, 242, 244, 313, 394, 418, 420, 629, 698, 753, 815 |
| H5 | `PLiquidityTarget.sol` | 89, 106, 116, 135, 137, 203, 310, 334, 336, 459, 517, 852, 936, 1072 |
| H5 | `PMath.sol` | 33, 173, 234, 235, 241, 242, 246, 252, 253, 266, 292, 319, 386, 448, 481, 525 |
| H5 | `PRepo.sol` | 23 |
| H6 | `PExitTarget.sol` | 150 |
| H6 | `PJoinCore.sol` | 87, 103, 111, 121, 178, 233, 239, 268, 272, 282, 356, 550, 569, 630, 689 |
| H6 | `PJoinQueryTarget.sol` | 128 |
| H6 | `PLiquidityTarget.sol` | 56, 72, 80, 90, 147, 209, 228, 230, 294, 553, 743, 762, 823, 981 |
| H6 | `PMath.sol` | 27, 146, 385, 387, 388, 396, 421, 439, 477, 517, 557, 600, 641 |
| H6 | `PRepo.sol` | 28 |
| H7 | `UniswapV4BalancerStableLiquidityUnitsCore.sol` | 30, 34, 66, 68, 173, 175, 187, 191 |
| H7 | `PLiquidityCore.sol` | 55, 71, 79, 89, 112, 139, 148, 301 |
| H7 | `PMath.sol` | 39, 221, 223, 224, 231, 241, 259, 298, 309, 330, 344, 358 |
| H7 | `PQueryTarget.sol` | 76 |
| H7 | `PRepo.sol` | 22 |

## Required future proof, not performed here

Interface-derived selector lists must be checked against the deployed proxy with loupe and a meaningful success/exact-guard call on every route; declaration equality alone is insufficient (`lib/crane/.claude/skills/crane-testing/SKILL.md:160-179`). All 621 product selector-installation rows above are statically resolved to a concrete inherited implementation, including overloaded signatures and appended SY methods; shared and staged selectors are inventoried separately. This is not 621 executed tests or 621 unique selectors across products.

Family owners must run local/share/mixed zero components, address/package disable and re-enable, refunds 0/partial/all, two holders, ceil joins/floor exits, unbooked/staged negatives, exact-net rounding and infeasible fee branches, share-requested conversions, limits/deadlines/reentrancy/outer rollback, real same-manager settlements and mixed decimals. H4 exactly 3, H5 n=2/3/8 and partial, H6 exactly 4, H7 n=2/5 plus interior validation. H1 LP assertions are structurally inapplicable, not early-returning passes. The parent owns the 48-row PRD ledger and runtime baseline; see 01-superseded-tests.md for the 36-instance migration inventory. Cold route <=12m and preview <=5m measurements, both underlying targets, and same-backing-pool sequential proof remain unexecuted. Disjoint keys do not prove same-key composition. No runtime result is inferred from source discovery.

