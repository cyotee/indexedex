"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgDefaultPoolInfoFacet = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgBetterBalancerV3PoolTokenFacet = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgBasicVaultFacet = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgBalancerV3VaultAwareFacet = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgBalancerV3Vault = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgBalancerV3ConstProdPoolFacet = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgBalancerV3AuthenticationFacet = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkg = exports.weth9Config = exports.weth9Address = exports.weth9Abi = exports.vaultRegistryDeploymentFacetConfig = exports.vaultRegistryDeploymentFacetAddress = exports.vaultRegistryDeploymentFacetAbi = exports.uniswapV2StandardExchangeDfPkgConfig = exports.uniswapV2StandardExchangeDfPkgAddress = exports.uniswapV2StandardExchangeDfPkgAbi = exports.diamondPackageCallBackFactoryConfig = exports.diamondPackageCallBackFactoryAddress = exports.diamondPackageCallBackFactoryAbi = exports.betterPermit2Config = exports.betterPermit2Address = exports.betterPermit2Abi = exports.balancerV3StandardExchangeRouterExactOutSwapTargetConfig = exports.balancerV3StandardExchangeRouterExactOutSwapTargetAddress = exports.balancerV3StandardExchangeRouterExactOutSwapTargetAbi = exports.balancerV3StandardExchangeRouterExactOutSwapFacetConfig = exports.balancerV3StandardExchangeRouterExactOutSwapFacetAddress = exports.balancerV3StandardExchangeRouterExactOutSwapFacetAbi = exports.balancerV3StandardExchangeRouterExactOutQueryFacetConfig = exports.balancerV3StandardExchangeRouterExactOutQueryFacetAddress = exports.balancerV3StandardExchangeRouterExactOutQueryFacetAbi = exports.balancerV3StandardExchangeRouterExactInSwapTargetConfig = exports.balancerV3StandardExchangeRouterExactInSwapTargetAddress = exports.balancerV3StandardExchangeRouterExactInSwapTargetAbi = exports.balancerV3StandardExchangeRouterExactInSwapFacetConfig = exports.balancerV3StandardExchangeRouterExactInSwapFacetAddress = exports.balancerV3StandardExchangeRouterExactInSwapFacetAbi = exports.balancerV3StandardExchangeRouterExactInQueryFacetConfig = exports.balancerV3StandardExchangeRouterExactInQueryFacetAddress = exports.balancerV3StandardExchangeRouterExactInQueryFacetAbi = exports.balancerV3StandardExchangeBatchRouterExactOutFacetConfig = exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress = exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi = exports.balancerV3StandardExchangeBatchRouterExactInFacetConfig = exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress = exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi = exports.balancerV3ConstantProductPoolStandardVaultPkgConfig = exports.balancerV3ConstantProductPoolStandardVaultPkgAddress = exports.balancerV3ConstantProductPoolStandardVaultPkgAbi = void 0;
exports.useReadBalancerV3StandardExchangeBatchRouterExactInFacetFacetMetadata = exports.useReadBalancerV3StandardExchangeBatchRouterExactInFacetFacetInterfaces = exports.useReadBalancerV3StandardExchangeBatchRouterExactInFacetFacetFuncs = exports.useReadBalancerV3StandardExchangeBatchRouterExactInFacet = exports.useWatchBalancerV3ConstantProductPoolStandardVaultPkgPoolCreatedEvent = exports.useWatchBalancerV3ConstantProductPoolStandardVaultPkgFactoryDisabledEvent = exports.useWatchBalancerV3ConstantProductPoolStandardVaultPkgEvent = exports.useSimulateBalancerV3ConstantProductPoolStandardVaultPkgUpdatePkg = exports.useSimulateBalancerV3ConstantProductPoolStandardVaultPkgPostDeploy = exports.useSimulateBalancerV3ConstantProductPoolStandardVaultPkgInitAccount = exports.useSimulateBalancerV3ConstantProductPoolStandardVaultPkgDisable = exports.useSimulateBalancerV3ConstantProductPoolStandardVaultPkgDeployVault = exports.useSimulateBalancerV3ConstantProductPoolStandardVaultPkg = exports.useWriteBalancerV3ConstantProductPoolStandardVaultPkgUpdatePkg = exports.useWriteBalancerV3ConstantProductPoolStandardVaultPkgPostDeploy = exports.useWriteBalancerV3ConstantProductPoolStandardVaultPkgInitAccount = exports.useWriteBalancerV3ConstantProductPoolStandardVaultPkgDisable = exports.useWriteBalancerV3ConstantProductPoolStandardVaultPkgDeployVault = exports.useWriteBalancerV3ConstantProductPoolStandardVaultPkg = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgVaultTypes = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgVaultFeeTypeIds = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgVaultDeclaration = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgTokenConfigs = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgProcessArgs = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgPackageName = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgPackageMetadata = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgName = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgIsPoolFromFactory = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgIsDisabled = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgGetPoolsInRange = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgGetPools = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgGetPoolCount = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgGetPauseWindowDuration = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgGetOriginalPauseWindowEndTime = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgGetNewPoolPauseWindowEndTime = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgGetDeploymentAddress = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgGetActionId = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgFacetInterfaces = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgFacetCuts = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgFacetAddresses = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgDiamondConfig = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgConstantProductMarkerFunction = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgCalcSalt = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgVaultRegistry = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgVaultFeeOracle = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgUnbalancedLiquidityInvariantRatioBoundsFacet = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgStandardVaultFacet = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgStandardSwapFeePercentageBoundsFacet = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgSelf = exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgDiamondPackageFactory = void 0;
exports.useSimulateBalancerV3StandardExchangeRouterExactInQueryFacet = exports.useWriteBalancerV3StandardExchangeRouterExactInQueryFacetQuerySwapSingleTokenExactInHook = exports.useWriteBalancerV3StandardExchangeRouterExactInQueryFacetQuerySwapSingleTokenExactIn = exports.useWriteBalancerV3StandardExchangeRouterExactInQueryFacet = exports.useReadBalancerV3StandardExchangeRouterExactInQueryFacetGetSender = exports.useReadBalancerV3StandardExchangeRouterExactInQueryFacetFacetName = exports.useReadBalancerV3StandardExchangeRouterExactInQueryFacetFacetMetadata = exports.useReadBalancerV3StandardExchangeRouterExactInQueryFacetFacetInterfaces = exports.useReadBalancerV3StandardExchangeRouterExactInQueryFacetFacetFuncs = exports.useReadBalancerV3StandardExchangeRouterExactInQueryFacet = exports.useWatchBalancerV3StandardExchangeBatchRouterExactOutFacetWethSentinelDebugEvent = exports.useWatchBalancerV3StandardExchangeBatchRouterExactOutFacetSwapHookParamsDebugEvent = exports.useWatchBalancerV3StandardExchangeBatchRouterExactOutFacetStrategyVaultExchangeOutEvent = exports.useWatchBalancerV3StandardExchangeBatchRouterExactOutFacetEvent = exports.useSimulateBalancerV3StandardExchangeBatchRouterExactOutFacetSwapExactOutWithPermit = exports.useSimulateBalancerV3StandardExchangeBatchRouterExactOutFacetSwapExactOutHook = exports.useSimulateBalancerV3StandardExchangeBatchRouterExactOutFacetSwapExactOut = exports.useSimulateBalancerV3StandardExchangeBatchRouterExactOutFacetQuerySwapExactOutHook = exports.useSimulateBalancerV3StandardExchangeBatchRouterExactOutFacetQuerySwapExactOut = exports.useSimulateBalancerV3StandardExchangeBatchRouterExactOutFacet = exports.useWriteBalancerV3StandardExchangeBatchRouterExactOutFacetSwapExactOutWithPermit = exports.useWriteBalancerV3StandardExchangeBatchRouterExactOutFacetSwapExactOutHook = exports.useWriteBalancerV3StandardExchangeBatchRouterExactOutFacetSwapExactOut = exports.useWriteBalancerV3StandardExchangeBatchRouterExactOutFacetQuerySwapExactOutHook = exports.useWriteBalancerV3StandardExchangeBatchRouterExactOutFacetQuerySwapExactOut = exports.useWriteBalancerV3StandardExchangeBatchRouterExactOutFacet = exports.useReadBalancerV3StandardExchangeBatchRouterExactOutFacetGetSender = exports.useReadBalancerV3StandardExchangeBatchRouterExactOutFacetFacetName = exports.useReadBalancerV3StandardExchangeBatchRouterExactOutFacetFacetMetadata = exports.useReadBalancerV3StandardExchangeBatchRouterExactOutFacetFacetInterfaces = exports.useReadBalancerV3StandardExchangeBatchRouterExactOutFacetFacetFuncs = exports.useReadBalancerV3StandardExchangeBatchRouterExactOutFacet = exports.useWatchBalancerV3StandardExchangeBatchRouterExactInFacetWethSentinelDebugEvent = exports.useWatchBalancerV3StandardExchangeBatchRouterExactInFacetSwapHookParamsDebugEvent = exports.useWatchBalancerV3StandardExchangeBatchRouterExactInFacetStrategyVaultExchangeInEvent = exports.useWatchBalancerV3StandardExchangeBatchRouterExactInFacetEvent = exports.useSimulateBalancerV3StandardExchangeBatchRouterExactInFacetSwapExactInWithPermit = exports.useSimulateBalancerV3StandardExchangeBatchRouterExactInFacetSwapExactInHook = exports.useSimulateBalancerV3StandardExchangeBatchRouterExactInFacetSwapExactIn = exports.useSimulateBalancerV3StandardExchangeBatchRouterExactInFacetQuerySwapExactInHook = exports.useSimulateBalancerV3StandardExchangeBatchRouterExactInFacetQuerySwapExactIn = exports.useSimulateBalancerV3StandardExchangeBatchRouterExactInFacet = exports.useWriteBalancerV3StandardExchangeBatchRouterExactInFacetSwapExactInWithPermit = exports.useWriteBalancerV3StandardExchangeBatchRouterExactInFacetSwapExactInHook = exports.useWriteBalancerV3StandardExchangeBatchRouterExactInFacetSwapExactIn = exports.useWriteBalancerV3StandardExchangeBatchRouterExactInFacetQuerySwapExactInHook = exports.useWriteBalancerV3StandardExchangeBatchRouterExactInFacetQuerySwapExactIn = exports.useWriteBalancerV3StandardExchangeBatchRouterExactInFacet = exports.useReadBalancerV3StandardExchangeBatchRouterExactInFacetGetSender = exports.useReadBalancerV3StandardExchangeBatchRouterExactInFacetFacetName = void 0;
exports.useWatchBalancerV3StandardExchangeRouterExactOutQueryFacetWethSentinelDebugEvent = exports.useWatchBalancerV3StandardExchangeRouterExactOutQueryFacetSwapHookParamsDebugEvent = exports.useWatchBalancerV3StandardExchangeRouterExactOutQueryFacetEvent = exports.useSimulateBalancerV3StandardExchangeRouterExactOutQueryFacetQuerySwapSingleTokenExactOutHook = exports.useSimulateBalancerV3StandardExchangeRouterExactOutQueryFacetQuerySwapSingleTokenExactOut = exports.useSimulateBalancerV3StandardExchangeRouterExactOutQueryFacet = exports.useWriteBalancerV3StandardExchangeRouterExactOutQueryFacetQuerySwapSingleTokenExactOutHook = exports.useWriteBalancerV3StandardExchangeRouterExactOutQueryFacetQuerySwapSingleTokenExactOut = exports.useWriteBalancerV3StandardExchangeRouterExactOutQueryFacet = exports.useReadBalancerV3StandardExchangeRouterExactOutQueryFacetGetSender = exports.useReadBalancerV3StandardExchangeRouterExactOutQueryFacetFacetName = exports.useReadBalancerV3StandardExchangeRouterExactOutQueryFacetFacetMetadata = exports.useReadBalancerV3StandardExchangeRouterExactOutQueryFacetFacetInterfaces = exports.useReadBalancerV3StandardExchangeRouterExactOutQueryFacetFacetFuncs = exports.useReadBalancerV3StandardExchangeRouterExactOutQueryFacet = exports.useWatchBalancerV3StandardExchangeRouterExactInSwapTargetWethSentinelDebugEvent = exports.useWatchBalancerV3StandardExchangeRouterExactInSwapTargetSwapHookParamsDebugEvent = exports.useWatchBalancerV3StandardExchangeRouterExactInSwapTargetEvent = exports.useSimulateBalancerV3StandardExchangeRouterExactInSwapTargetSwapSingleTokenExactInWithPermit = exports.useSimulateBalancerV3StandardExchangeRouterExactInSwapTargetSwapSingleTokenExactInHook = exports.useSimulateBalancerV3StandardExchangeRouterExactInSwapTargetSwapSingleTokenExactIn = exports.useSimulateBalancerV3StandardExchangeRouterExactInSwapTarget = exports.useWriteBalancerV3StandardExchangeRouterExactInSwapTargetSwapSingleTokenExactInWithPermit = exports.useWriteBalancerV3StandardExchangeRouterExactInSwapTargetSwapSingleTokenExactInHook = exports.useWriteBalancerV3StandardExchangeRouterExactInSwapTargetSwapSingleTokenExactIn = exports.useWriteBalancerV3StandardExchangeRouterExactInSwapTarget = exports.useReadBalancerV3StandardExchangeRouterExactInSwapTargetGetSender = exports.useReadBalancerV3StandardExchangeRouterExactInSwapTarget = exports.useWatchBalancerV3StandardExchangeRouterExactInSwapFacetWethSentinelDebugEvent = exports.useWatchBalancerV3StandardExchangeRouterExactInSwapFacetSwapHookParamsDebugEvent = exports.useWatchBalancerV3StandardExchangeRouterExactInSwapFacetEvent = exports.useSimulateBalancerV3StandardExchangeRouterExactInSwapFacetSwapSingleTokenExactInWithPermit = exports.useSimulateBalancerV3StandardExchangeRouterExactInSwapFacetSwapSingleTokenExactInHook = exports.useSimulateBalancerV3StandardExchangeRouterExactInSwapFacetSwapSingleTokenExactIn = exports.useSimulateBalancerV3StandardExchangeRouterExactInSwapFacet = exports.useWriteBalancerV3StandardExchangeRouterExactInSwapFacetSwapSingleTokenExactInWithPermit = exports.useWriteBalancerV3StandardExchangeRouterExactInSwapFacetSwapSingleTokenExactInHook = exports.useWriteBalancerV3StandardExchangeRouterExactInSwapFacetSwapSingleTokenExactIn = exports.useWriteBalancerV3StandardExchangeRouterExactInSwapFacet = exports.useReadBalancerV3StandardExchangeRouterExactInSwapFacetGetSender = exports.useReadBalancerV3StandardExchangeRouterExactInSwapFacetFacetName = exports.useReadBalancerV3StandardExchangeRouterExactInSwapFacetFacetMetadata = exports.useReadBalancerV3StandardExchangeRouterExactInSwapFacetFacetInterfaces = exports.useReadBalancerV3StandardExchangeRouterExactInSwapFacetFacetFuncs = exports.useReadBalancerV3StandardExchangeRouterExactInSwapFacet = exports.useWatchBalancerV3StandardExchangeRouterExactInQueryFacetWethSentinelDebugEvent = exports.useWatchBalancerV3StandardExchangeRouterExactInQueryFacetSwapHookParamsDebugEvent = exports.useWatchBalancerV3StandardExchangeRouterExactInQueryFacetEvent = exports.useSimulateBalancerV3StandardExchangeRouterExactInQueryFacetQuerySwapSingleTokenExactInHook = exports.useSimulateBalancerV3StandardExchangeRouterExactInQueryFacetQuerySwapSingleTokenExactIn = void 0;
exports.useSimulateBetterPermit2PermitTransferFrom = exports.useSimulateBetterPermit2Permit = exports.useSimulateBetterPermit2Lockdown = exports.useSimulateBetterPermit2InvalidateUnorderedNonces = exports.useSimulateBetterPermit2InvalidateNonces = exports.useSimulateBetterPermit2Approve = exports.useSimulateBetterPermit2 = exports.useWriteBetterPermit2TransferFrom = exports.useWriteBetterPermit2PermitWitnessTransferFrom = exports.useWriteBetterPermit2PermitTransferFrom = exports.useWriteBetterPermit2Permit = exports.useWriteBetterPermit2Lockdown = exports.useWriteBetterPermit2InvalidateUnorderedNonces = exports.useWriteBetterPermit2InvalidateNonces = exports.useWriteBetterPermit2Approve = exports.useWriteBetterPermit2 = exports.useReadBetterPermit2NonceBitmap = exports.useReadBetterPermit2Allowance = exports.useReadBetterPermit2DomainSeparator = exports.useReadBetterPermit2 = exports.useWatchBalancerV3StandardExchangeRouterExactOutSwapTargetWethSentinelDebugEvent = exports.useWatchBalancerV3StandardExchangeRouterExactOutSwapTargetSwapHookParamsDebugEvent = exports.useWatchBalancerV3StandardExchangeRouterExactOutSwapTargetEvent = exports.useSimulateBalancerV3StandardExchangeRouterExactOutSwapTargetSwapSingleTokenExactOutWithPermit = exports.useSimulateBalancerV3StandardExchangeRouterExactOutSwapTargetSwapSingleTokenExactOutHook = exports.useSimulateBalancerV3StandardExchangeRouterExactOutSwapTargetSwapSingleTokenExactOut = exports.useSimulateBalancerV3StandardExchangeRouterExactOutSwapTarget = exports.useWriteBalancerV3StandardExchangeRouterExactOutSwapTargetSwapSingleTokenExactOutWithPermit = exports.useWriteBalancerV3StandardExchangeRouterExactOutSwapTargetSwapSingleTokenExactOutHook = exports.useWriteBalancerV3StandardExchangeRouterExactOutSwapTargetSwapSingleTokenExactOut = exports.useWriteBalancerV3StandardExchangeRouterExactOutSwapTarget = exports.useReadBalancerV3StandardExchangeRouterExactOutSwapTargetGetSender = exports.useReadBalancerV3StandardExchangeRouterExactOutSwapTarget = exports.useWatchBalancerV3StandardExchangeRouterExactOutSwapFacetWethSentinelDebugEvent = exports.useWatchBalancerV3StandardExchangeRouterExactOutSwapFacetSwapHookParamsDebugEvent = exports.useWatchBalancerV3StandardExchangeRouterExactOutSwapFacetEvent = exports.useSimulateBalancerV3StandardExchangeRouterExactOutSwapFacetSwapSingleTokenExactOutWithPermit = exports.useSimulateBalancerV3StandardExchangeRouterExactOutSwapFacetSwapSingleTokenExactOutHook = exports.useSimulateBalancerV3StandardExchangeRouterExactOutSwapFacetSwapSingleTokenExactOut = exports.useSimulateBalancerV3StandardExchangeRouterExactOutSwapFacet = exports.useWriteBalancerV3StandardExchangeRouterExactOutSwapFacetSwapSingleTokenExactOutWithPermit = exports.useWriteBalancerV3StandardExchangeRouterExactOutSwapFacetSwapSingleTokenExactOutHook = exports.useWriteBalancerV3StandardExchangeRouterExactOutSwapFacetSwapSingleTokenExactOut = exports.useWriteBalancerV3StandardExchangeRouterExactOutSwapFacet = exports.useReadBalancerV3StandardExchangeRouterExactOutSwapFacetGetSender = exports.useReadBalancerV3StandardExchangeRouterExactOutSwapFacetFacetName = exports.useReadBalancerV3StandardExchangeRouterExactOutSwapFacetFacetMetadata = exports.useReadBalancerV3StandardExchangeRouterExactOutSwapFacetFacetInterfaces = exports.useReadBalancerV3StandardExchangeRouterExactOutSwapFacetFacetFuncs = exports.useReadBalancerV3StandardExchangeRouterExactOutSwapFacet = void 0;
exports.useWriteUniswapV2StandardExchangeDfPkg = exports.useReadUniswapV2StandardExchangeDfPkgVaultTypes = exports.useReadUniswapV2StandardExchangeDfPkgVaultFeeTypeIds = exports.useReadUniswapV2StandardExchangeDfPkgVaultDeclaration = exports.useReadUniswapV2StandardExchangeDfPkgUpdatePkg = exports.useReadUniswapV2StandardExchangeDfPkgProcessArgs = exports.useReadUniswapV2StandardExchangeDfPkgPreviewDeployVault = exports.useReadUniswapV2StandardExchangeDfPkgPostDeploy = exports.useReadUniswapV2StandardExchangeDfPkgPackageName = exports.useReadUniswapV2StandardExchangeDfPkgPackageMetadata = exports.useReadUniswapV2StandardExchangeDfPkgName = exports.useReadUniswapV2StandardExchangeDfPkgFacetInterfaces = exports.useReadUniswapV2StandardExchangeDfPkgFacetCuts = exports.useReadUniswapV2StandardExchangeDfPkgFacetAddresses = exports.useReadUniswapV2StandardExchangeDfPkgDiamondConfig = exports.useReadUniswapV2StandardExchangeDfPkgCalcSalt = exports.useReadUniswapV2StandardExchangeDfPkg = exports.useWatchDiamondPackageCallBackFactoryDiamondFunctionRemovedEvent = exports.useWatchDiamondPackageCallBackFactoryDiamondCutEvent = exports.useWatchDiamondPackageCallBackFactoryEvent = exports.useSimulateDiamondPackageCallBackFactoryPostDeploy = exports.useSimulateDiamondPackageCallBackFactoryInitAccount = exports.useSimulateDiamondPackageCallBackFactoryDeploy = exports.useSimulateDiamondPackageCallBackFactory = exports.useWriteDiamondPackageCallBackFactoryPostDeploy = exports.useWriteDiamondPackageCallBackFactoryInitAccount = exports.useWriteDiamondPackageCallBackFactoryDeploy = exports.useWriteDiamondPackageCallBackFactory = exports.useReadDiamondPackageCallBackFactoryPostDeployFacetCuts = exports.useReadDiamondPackageCallBackFactoryPkgOfAccount = exports.useReadDiamondPackageCallBackFactoryPkgConfig = exports.useReadDiamondPackageCallBackFactoryPkgArgsOfAccount = exports.useReadDiamondPackageCallBackFactoryFacetInterfaces = exports.useReadDiamondPackageCallBackFactoryFacetCuts = exports.useReadDiamondPackageCallBackFactoryErc8109Funcs = exports.useReadDiamondPackageCallBackFactoryCalcAddress = exports.useReadDiamondPackageCallBackFactoryProxyInitHash = exports.useReadDiamondPackageCallBackFactoryPostDeployHookFacet = exports.useReadDiamondPackageCallBackFactoryErc8109IntrospectionFacet = exports.useReadDiamondPackageCallBackFactoryErc165Facet = exports.useReadDiamondPackageCallBackFactoryDiamondLoupeFacet = exports.useReadDiamondPackageCallBackFactory = exports.useWatchBetterPermit2UnorderedNonceInvalidationEvent = exports.useWatchBetterPermit2PermitEvent = exports.useWatchBetterPermit2NonceInvalidationEvent = exports.useWatchBetterPermit2LockdownEvent = exports.useWatchBetterPermit2ApprovalEvent = exports.useWatchBetterPermit2Event = exports.useSimulateBetterPermit2TransferFrom = exports.useSimulateBetterPermit2PermitWitnessTransferFrom = void 0;
exports.useWatchWeth9WithdrawalEvent = exports.useWatchWeth9TransferEvent = exports.useWatchWeth9DepositEvent = exports.useWatchWeth9ApprovalEvent = exports.useWatchWeth9Event = exports.useSimulateWeth9Withdraw = exports.useSimulateWeth9TransferFrom = exports.useSimulateWeth9Transfer = exports.useSimulateWeth9Deposit = exports.useSimulateWeth9Approve = exports.useSimulateWeth9 = exports.useWriteWeth9Withdraw = exports.useWriteWeth9TransferFrom = exports.useWriteWeth9Transfer = exports.useWriteWeth9Deposit = exports.useWriteWeth9Approve = exports.useWriteWeth9 = exports.useReadWeth9TotalSupply = exports.useReadWeth9Symbol = exports.useReadWeth9Name = exports.useReadWeth9Decimals = exports.useReadWeth9BalanceOf = exports.useReadWeth9Allowance = exports.useReadWeth9 = exports.useWatchVaultRegistryDeploymentFacetVaultRemovedEvent = exports.useWatchVaultRegistryDeploymentFacetPackageRemovedEvent = exports.useWatchVaultRegistryDeploymentFacetNewVaultOfTypeEvent = exports.useWatchVaultRegistryDeploymentFacetNewVaultOfTokenEvent = exports.useWatchVaultRegistryDeploymentFacetNewVaultEvent = exports.useWatchVaultRegistryDeploymentFacetNewPackageOfTypeEvent = exports.useWatchVaultRegistryDeploymentFacetNewPackageEvent = exports.useWatchVaultRegistryDeploymentFacetEvent = exports.useSimulateVaultRegistryDeploymentFacetDeployVault = exports.useSimulateVaultRegistryDeploymentFacetDeployPkg = exports.useSimulateVaultRegistryDeploymentFacet = exports.useWriteVaultRegistryDeploymentFacetDeployVault = exports.useWriteVaultRegistryDeploymentFacetDeployPkg = exports.useWriteVaultRegistryDeploymentFacet = exports.useReadVaultRegistryDeploymentFacetFacetName = exports.useReadVaultRegistryDeploymentFacetFacetMetadata = exports.useReadVaultRegistryDeploymentFacetFacetInterfaces = exports.useReadVaultRegistryDeploymentFacetFacetFuncs = exports.useReadVaultRegistryDeploymentFacet = exports.useSimulateUniswapV2StandardExchangeDfPkgInitAccount = exports.useSimulateUniswapV2StandardExchangeDfPkgDeployVault = exports.useSimulateUniswapV2StandardExchangeDfPkg = exports.useWriteUniswapV2StandardExchangeDfPkgInitAccount = exports.useWriteUniswapV2StandardExchangeDfPkgDeployVault = void 0;
const codegen_1 = require("wagmi/codegen");
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BalancerV3ConstantProductPoolStandardVaultPkg
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.balancerV3ConstantProductPoolStandardVaultPkgAbi = [
    {
        type: 'constructor',
        inputs: [
            {
                name: 'pkgInit',
                internalType: 'struct IBalancerV3ConstantProductPoolStandardVaultPkg.PkgInit',
                type: 'tuple',
                components: [
                    {
                        name: 'basicVaultFacet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                    {
                        name: 'standardVaultFacet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                    {
                        name: 'balancerV3VaultAwareFacet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                    {
                        name: 'betterBalancerV3PoolTokenFacet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                    {
                        name: 'defaultPoolInfoFacet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                    {
                        name: 'standardSwapFeePercentageBoundsFacet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                    {
                        name: 'unbalancedLiquidityInvariantRatioBoundsFacet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                    {
                        name: 'balancerV3AuthenticationFacet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                    {
                        name: 'balancerV3ConstProdPoolFacet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                    {
                        name: 'vaultRegistry',
                        internalType: 'contract IVaultRegistryDeployment',
                        type: 'address',
                    },
                    {
                        name: 'vaultFeeOracle',
                        internalType: 'contract IVaultFeeOracleQuery',
                        type: 'address',
                    },
                    {
                        name: 'balancerV3Vault',
                        internalType: 'contract IVault',
                        type: 'address',
                    },
                    {
                        name: 'diamondFactory',
                        internalType: 'contract IDiamondPackageCallBackFactory',
                        type: 'address',
                    },
                ],
            },
        ],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [],
        name: 'BALANCER_V3_AUTHENTICATION_FACET',
        outputs: [{ name: '', internalType: 'contract IFacet', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'BALANCER_V3_CONST_PROD_POOL_FACET',
        outputs: [{ name: '', internalType: 'contract IFacet', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'BALANCER_V3_VAULT',
        outputs: [{ name: '', internalType: 'contract IVault', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'BALANCER_V3_VAULT_AWARE_FACET',
        outputs: [{ name: '', internalType: 'contract IFacet', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'BASIC_VAULT_FACET',
        outputs: [{ name: '', internalType: 'contract IFacet', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'BETTER_BALANCER_V3_POOL_TOKEN_FACET',
        outputs: [{ name: '', internalType: 'contract IFacet', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'DEFAULT_POOL_INFO_FACET',
        outputs: [{ name: '', internalType: 'contract IFacet', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'DIAMOND_PACKAGE_FACTORY',
        outputs: [
            {
                name: '',
                internalType: 'contract IDiamondPackageCallBackFactory',
                type: 'address',
            },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'SELF',
        outputs: [
            {
                name: '',
                internalType: 'contract BalancerV3ConstantProductPoolStandardVaultPkg',
                type: 'address',
            },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'STANDARD_SWAP_FEE_PERCENTAGE_BOUNDS_FACET',
        outputs: [{ name: '', internalType: 'contract IFacet', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'STANDARD_VAULT_FACET',
        outputs: [{ name: '', internalType: 'contract IFacet', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'UNBALANCED_LIQUIDITY_INVARIANT_RATIO_BOUNDS_FACET',
        outputs: [{ name: '', internalType: 'contract IFacet', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'VAULT_FEE_ORACLE',
        outputs: [
            {
                name: '',
                internalType: 'contract IVaultFeeOracleQuery',
                type: 'address',
            },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'VAULT_REGISTRY',
        outputs: [
            {
                name: '',
                internalType: 'contract IVaultRegistryDeployment',
                type: 'address',
            },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [{ name: 'pkgArgs', internalType: 'bytes', type: 'bytes' }],
        name: 'calcSalt',
        outputs: [{ name: 'salt', internalType: 'bytes32', type: 'bytes32' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'constantProductMarkerFunction',
        outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'tokenConfigs_',
                internalType: 'struct TokenConfig[]',
                type: 'tuple[]',
                components: [
                    { name: 'token', internalType: 'contract IERC20', type: 'address' },
                    { name: 'tokenType', internalType: 'enum TokenType', type: 'uint8' },
                    {
                        name: 'rateProvider',
                        internalType: 'contract IRateProvider',
                        type: 'address',
                    },
                    { name: 'paysYieldFees', internalType: 'bool', type: 'bool' },
                ],
            },
            { name: 'hooksContract', internalType: 'address', type: 'address' },
        ],
        name: 'deployVault',
        outputs: [{ name: 'vault', internalType: 'address', type: 'address' }],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [],
        name: 'diamondConfig',
        outputs: [
            {
                name: 'config',
                internalType: 'struct IDiamondFactoryPackage.DiamondConfig',
                type: 'tuple',
                components: [
                    {
                        name: 'facetCuts',
                        internalType: 'struct IDiamond.FacetCut[]',
                        type: 'tuple[]',
                        components: [
                            {
                                name: 'facetAddress',
                                internalType: 'address',
                                type: 'address',
                            },
                            {
                                name: 'action',
                                internalType: 'enum IDiamond.FacetCutAction',
                                type: 'uint8',
                            },
                            {
                                name: 'functionSelectors',
                                internalType: 'bytes4[]',
                                type: 'bytes4[]',
                            },
                        ],
                    },
                    { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
                ],
            },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'disable',
        outputs: [],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetAddresses',
        outputs: [
            { name: 'facetAddresses_', internalType: 'address[]', type: 'address[]' },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetCuts',
        outputs: [
            {
                name: 'facetCuts_',
                internalType: 'struct IDiamond.FacetCut[]',
                type: 'tuple[]',
                components: [
                    { name: 'facetAddress', internalType: 'address', type: 'address' },
                    {
                        name: 'action',
                        internalType: 'enum IDiamond.FacetCutAction',
                        type: 'uint8',
                    },
                    {
                        name: 'functionSelectors',
                        internalType: 'bytes4[]',
                        type: 'bytes4[]',
                    },
                ],
            },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetInterfaces',
        outputs: [
            { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [{ name: 'selector', internalType: 'bytes4', type: 'bytes4' }],
        name: 'getActionId',
        outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [
            { name: 'constructorArgs', internalType: 'bytes', type: 'bytes' },
            { name: '', internalType: 'bytes32', type: 'bytes32' },
        ],
        name: 'getDeploymentAddress',
        outputs: [{ name: '', internalType: 'address', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'getNewPoolPauseWindowEndTime',
        outputs: [{ name: '', internalType: 'uint32', type: 'uint32' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'getOriginalPauseWindowEndTime',
        outputs: [{ name: '', internalType: 'uint32', type: 'uint32' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'getPauseWindowDuration',
        outputs: [{ name: '', internalType: 'uint32', type: 'uint32' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'getPoolCount',
        outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'getPools',
        outputs: [{ name: '', internalType: 'address[]', type: 'address[]' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [
            { name: 'start', internalType: 'uint256', type: 'uint256' },
            { name: 'count', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'getPoolsInRange',
        outputs: [{ name: '', internalType: 'address[]', type: 'address[]' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [{ name: 'initArgs', internalType: 'bytes', type: 'bytes' }],
        name: 'initAccount',
        outputs: [],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [],
        name: 'isDisabled',
        outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [{ name: 'pool', internalType: 'address', type: 'address' }],
        name: 'isPoolFromFactory',
        outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'name',
        outputs: [{ name: '', internalType: 'string', type: 'string' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'packageMetadata',
        outputs: [
            { name: 'name_', internalType: 'string', type: 'string' },
            { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
            { name: 'facets', internalType: 'address[]', type: 'address[]' },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'packageName',
        outputs: [{ name: 'name_', internalType: 'string', type: 'string' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [{ name: 'proxy', internalType: 'address', type: 'address' }],
        name: 'postDeploy',
        outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [{ name: 'pkgArgs', internalType: 'bytes', type: 'bytes' }],
        name: 'processArgs',
        outputs: [
            { name: 'processedPkgArgs', internalType: 'bytes', type: 'bytes' },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [{ name: 'pool', internalType: 'address', type: 'address' }],
        name: 'tokenConfigs',
        outputs: [
            {
                name: '',
                internalType: 'struct TokenConfig[]',
                type: 'tuple[]',
                components: [
                    { name: 'token', internalType: 'contract IERC20', type: 'address' },
                    { name: 'tokenType', internalType: 'enum TokenType', type: 'uint8' },
                    {
                        name: 'rateProvider',
                        internalType: 'contract IRateProvider',
                        type: 'address',
                    },
                    { name: 'paysYieldFees', internalType: 'bool', type: 'bool' },
                ],
            },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [
            { name: 'expectedProxy', internalType: 'address', type: 'address' },
            { name: 'pkgArgs', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'updatePkg',
        outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [],
        name: 'vaultDeclaration',
        outputs: [
            {
                name: 'declaration',
                internalType: 'struct IStandardVaultPkg.VaultPkgDeclaration',
                type: 'tuple',
                components: [
                    { name: 'name', internalType: 'string', type: 'string' },
                    { name: 'vaultFeeTypeIds', internalType: 'bytes32', type: 'bytes32' },
                    { name: 'vaultTypes', internalType: 'bytes4[]', type: 'bytes4[]' },
                ],
            },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'vaultFeeTypeIds',
        outputs: [
            { name: 'vaultFeeTypeIds_', internalType: 'bytes32', type: 'bytes32' },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'vaultTypes',
        outputs: [{ name: 'typeIDs', internalType: 'bytes4[]', type: 'bytes4[]' }],
        stateMutability: 'pure',
    },
    { type: 'event', anonymous: false, inputs: [], name: 'FactoryDisabled' },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            { name: 'pool', internalType: 'address', type: 'address', indexed: true },
        ],
        name: 'PoolCreated',
    },
    { type: 'error', inputs: [], name: 'Disabled' },
    { type: 'error', inputs: [], name: 'IndexOutOfBounds' },
    {
        type: 'error',
        inputs: [
            { name: 'length', internalType: 'uint256', type: 'uint256' },
            { name: 'invalidIndex', internalType: 'uint256', type: 'uint256' },
            { name: 'errorCode', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'IndexOutOfBounds',
    },
    {
        type: 'error',
        inputs: [
            { name: 'start', internalType: 'uint256', type: 'uint256' },
            { name: 'end', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'InvalidPageSize',
    },
    {
        type: 'error',
        inputs: [
            { name: 'maxLength', internalType: 'uint256', type: 'uint256' },
            { name: 'minLength', internalType: 'uint256', type: 'uint256' },
            { name: 'providedLength', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'InvalidTokensLength',
    },
    {
        type: 'error',
        inputs: [{ name: 'caller', internalType: 'address', type: 'address' }],
        name: 'NotCalledByRegistry',
    },
    { type: 'error', inputs: [], name: 'PoolPauseWindowDurationOverflow' },
    { type: 'error', inputs: [], name: 'SenderNotAllowed' },
    {
        type: 'error',
        inputs: [{ name: 'str', internalType: 'string', type: 'string' }],
        name: 'StringTooLong',
    },
];
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.balancerV3ConstantProductPoolStandardVaultPkgAddress = {
    8453: '0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544',
    31337: '0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544',
    11155111: '0x858253aD4458680E93ee88EFCf520cD7054bC145',
};
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.balancerV3ConstantProductPoolStandardVaultPkgConfig = {
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BalancerV3StandardExchangeBatchRouterExactInFacet
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi = [
    {
        type: 'function',
        inputs: [],
        name: 'facetFuncs',
        outputs: [{ name: 'funcs', internalType: 'bytes4[]', type: 'bytes4[]' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetInterfaces',
        outputs: [
            { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetMetadata',
        outputs: [
            { name: 'name', internalType: 'string', type: 'string' },
            { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
            { name: 'functions', internalType: 'bytes4[]', type: 'bytes4[]' },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetName',
        outputs: [{ name: 'name', internalType: 'string', type: 'string' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'getSender',
        outputs: [{ name: '', internalType: 'address', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'paths',
                internalType: 'struct IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[]',
                type: 'tuple[]',
                components: [
                    { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
                    {
                        name: 'steps',
                        internalType: 'struct IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[]',
                        type: 'tuple[]',
                        components: [
                            { name: 'pool', internalType: 'address', type: 'address' },
                            {
                                name: 'tokenOut',
                                internalType: 'contract IERC20',
                                type: 'address',
                            },
                            { name: 'isBuffer', internalType: 'bool', type: 'bool' },
                            { name: 'isStrategyVault', internalType: 'bool', type: 'bool' },
                        ],
                    },
                    { name: 'exactAmountIn', internalType: 'uint256', type: 'uint256' },
                    { name: 'minAmountOut', internalType: 'uint256', type: 'uint256' },
                ],
            },
            { name: 'sender', internalType: 'address', type: 'address' },
            { name: 'userData', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'querySwapExactIn',
        outputs: [
            { name: 'pathAmountsOut', internalType: 'uint256[]', type: 'uint256[]' },
            { name: 'tokensOut', internalType: 'address[]', type: 'address[]' },
            { name: 'amountsOut', internalType: 'uint256[]', type: 'uint256[]' },
        ],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'params',
                internalType: 'struct IBalancerV3StandardExchangeBatchRouterExactIn.SESwapExactInHookParams',
                type: 'tuple',
                components: [
                    { name: 'sender', internalType: 'address', type: 'address' },
                    {
                        name: 'paths',
                        internalType: 'struct IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[]',
                        type: 'tuple[]',
                        components: [
                            {
                                name: 'tokenIn',
                                internalType: 'contract IERC20',
                                type: 'address',
                            },
                            {
                                name: 'steps',
                                internalType: 'struct IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[]',
                                type: 'tuple[]',
                                components: [
                                    { name: 'pool', internalType: 'address', type: 'address' },
                                    {
                                        name: 'tokenOut',
                                        internalType: 'contract IERC20',
                                        type: 'address',
                                    },
                                    { name: 'isBuffer', internalType: 'bool', type: 'bool' },
                                    {
                                        name: 'isStrategyVault',
                                        internalType: 'bool',
                                        type: 'bool',
                                    },
                                ],
                            },
                            {
                                name: 'exactAmountIn',
                                internalType: 'uint256',
                                type: 'uint256',
                            },
                            {
                                name: 'minAmountOut',
                                internalType: 'uint256',
                                type: 'uint256',
                            },
                        ],
                    },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                    { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
                    { name: 'userData', internalType: 'bytes', type: 'bytes' },
                ],
            },
        ],
        name: 'querySwapExactInHook',
        outputs: [
            { name: 'pathAmountsOut', internalType: 'uint256[]', type: 'uint256[]' },
            { name: 'tokensOut', internalType: 'address[]', type: 'address[]' },
            { name: 'amountsOut', internalType: 'uint256[]', type: 'uint256[]' },
        ],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'paths',
                internalType: 'struct IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[]',
                type: 'tuple[]',
                components: [
                    { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
                    {
                        name: 'steps',
                        internalType: 'struct IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[]',
                        type: 'tuple[]',
                        components: [
                            { name: 'pool', internalType: 'address', type: 'address' },
                            {
                                name: 'tokenOut',
                                internalType: 'contract IERC20',
                                type: 'address',
                            },
                            { name: 'isBuffer', internalType: 'bool', type: 'bool' },
                            { name: 'isStrategyVault', internalType: 'bool', type: 'bool' },
                        ],
                    },
                    { name: 'exactAmountIn', internalType: 'uint256', type: 'uint256' },
                    { name: 'minAmountOut', internalType: 'uint256', type: 'uint256' },
                ],
            },
            { name: 'deadline', internalType: 'uint256', type: 'uint256' },
            { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
            { name: 'userData', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'swapExactIn',
        outputs: [
            { name: 'pathAmountsOut', internalType: 'uint256[]', type: 'uint256[]' },
            { name: 'tokensOut', internalType: 'address[]', type: 'address[]' },
            { name: 'amountsOut', internalType: 'uint256[]', type: 'uint256[]' },
        ],
        stateMutability: 'payable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'params',
                internalType: 'struct IBalancerV3StandardExchangeBatchRouterExactIn.SESwapExactInHookParams',
                type: 'tuple',
                components: [
                    { name: 'sender', internalType: 'address', type: 'address' },
                    {
                        name: 'paths',
                        internalType: 'struct IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[]',
                        type: 'tuple[]',
                        components: [
                            {
                                name: 'tokenIn',
                                internalType: 'contract IERC20',
                                type: 'address',
                            },
                            {
                                name: 'steps',
                                internalType: 'struct IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[]',
                                type: 'tuple[]',
                                components: [
                                    { name: 'pool', internalType: 'address', type: 'address' },
                                    {
                                        name: 'tokenOut',
                                        internalType: 'contract IERC20',
                                        type: 'address',
                                    },
                                    { name: 'isBuffer', internalType: 'bool', type: 'bool' },
                                    {
                                        name: 'isStrategyVault',
                                        internalType: 'bool',
                                        type: 'bool',
                                    },
                                ],
                            },
                            {
                                name: 'exactAmountIn',
                                internalType: 'uint256',
                                type: 'uint256',
                            },
                            {
                                name: 'minAmountOut',
                                internalType: 'uint256',
                                type: 'uint256',
                            },
                        ],
                    },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                    { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
                    { name: 'userData', internalType: 'bytes', type: 'bytes' },
                ],
            },
        ],
        name: 'swapExactInHook',
        outputs: [
            { name: 'pathAmountsOut', internalType: 'uint256[]', type: 'uint256[]' },
            { name: 'tokensOut', internalType: 'address[]', type: 'address[]' },
            { name: 'amountsOut', internalType: 'uint256[]', type: 'uint256[]' },
        ],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'paths',
                internalType: 'struct IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[]',
                type: 'tuple[]',
                components: [
                    { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
                    {
                        name: 'steps',
                        internalType: 'struct IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[]',
                        type: 'tuple[]',
                        components: [
                            { name: 'pool', internalType: 'address', type: 'address' },
                            {
                                name: 'tokenOut',
                                internalType: 'contract IERC20',
                                type: 'address',
                            },
                            { name: 'isBuffer', internalType: 'bool', type: 'bool' },
                            { name: 'isStrategyVault', internalType: 'bool', type: 'bool' },
                        ],
                    },
                    { name: 'exactAmountIn', internalType: 'uint256', type: 'uint256' },
                    { name: 'minAmountOut', internalType: 'uint256', type: 'uint256' },
                ],
            },
            { name: 'deadline', internalType: 'uint256', type: 'uint256' },
            { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
            { name: 'userData', internalType: 'bytes', type: 'bytes' },
            {
                name: 'permits',
                internalType: 'struct ISignatureTransfer.PermitTransferFrom[]',
                type: 'tuple[]',
                components: [
                    {
                        name: 'permitted',
                        internalType: 'struct ISignatureTransfer.TokenPermissions',
                        type: 'tuple',
                        components: [
                            { name: 'token', internalType: 'address', type: 'address' },
                            { name: 'amount', internalType: 'uint256', type: 'uint256' },
                        ],
                    },
                    { name: 'nonce', internalType: 'uint256', type: 'uint256' },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                ],
            },
            { name: 'signatures', internalType: 'bytes[]', type: 'bytes[]' },
        ],
        name: 'swapExactInWithPermit',
        outputs: [
            { name: 'pathAmountsOut', internalType: 'uint256[]', type: 'uint256[]' },
            { name: 'tokensOut', internalType: 'address[]', type: 'address[]' },
            { name: 'amountsOut', internalType: 'uint256[]', type: 'uint256[]' },
        ],
        stateMutability: 'payable',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'vault',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'tokenIn',
                internalType: 'contract IERC20',
                type: 'address',
                indexed: true,
            },
            {
                name: 'tokenOut',
                internalType: 'contract IERC20',
                type: 'address',
                indexed: true,
            },
            {
                name: 'amountIn',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            {
                name: 'amountOut',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
        ],
        name: 'StrategyVaultExchangeIn',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'sender',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            { name: 'kind', internalType: 'uint8', type: 'uint8', indexed: false },
            { name: 'pool', internalType: 'address', type: 'address', indexed: true },
            {
                name: 'tokenIn',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenOut',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenInVault',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenOutVault',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'amountGiven',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            {
                name: 'limit',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            { name: 'wethIsEth', internalType: 'bool', type: 'bool', indexed: false },
        ],
        name: 'SwapHookParamsDebug',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'sender',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            { name: 'kind', internalType: 'uint8', type: 'uint8', indexed: false },
            {
                name: 'amountGiven',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            {
                name: 'limit',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            { name: 'wrap', internalType: 'bool', type: 'bool', indexed: false },
            { name: 'unwrap', internalType: 'bool', type: 'bool', indexed: false },
        ],
        name: 'WethSentinelDebug',
    },
    { type: 'error', inputs: [], name: 'EthTransfer' },
    { type: 'error', inputs: [], name: 'FailedCall' },
    {
        type: 'error',
        inputs: [
            { name: 'balance', internalType: 'uint256', type: 'uint256' },
            { name: 'needed', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'InsufficientBalance',
    },
    { type: 'error', inputs: [], name: 'InsufficientEth' },
    { type: 'error', inputs: [], name: 'InsufficientEth' },
    {
        type: 'error',
        inputs: [
            { name: 'token', internalType: 'contract IERC20', type: 'address' },
        ],
        name: 'InsufficientPayment',
    },
    {
        type: 'error',
        inputs: [
            { name: 'tokenIn', internalType: 'address', type: 'address' },
            { name: 'tokenVault', internalType: 'address', type: 'address' },
            { name: 'tokenOut', internalType: 'address', type: 'address' },
            { name: 'tokenOutVault', internalType: 'address', type: 'address' },
        ],
        name: 'InvalidRoute',
    },
    { type: 'error', inputs: [], name: 'IsLocked' },
    {
        type: 'error',
        inputs: [
            { name: 'limit', internalType: 'uint256', type: 'uint256' },
            { name: 'actual', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'LimitExceeded',
    },
    {
        type: 'error',
        inputs: [
            { name: 'minAmountOut', internalType: 'uint256', type: 'uint256' },
            { name: 'actualAmountOut', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'MinAmountOutNotMet',
    },
    {
        type: 'error',
        inputs: [{ name: 'caller', internalType: 'address', type: 'address' }],
        name: 'NotBalancerV3Vault',
    },
    {
        type: 'error',
        inputs: [
            { name: 'index', internalType: 'uint256', type: 'uint256' },
            { name: 'requiredAmount', internalType: 'uint256', type: 'uint256' },
            { name: 'permitAmount', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'PermitPathAmountInsufficient',
    },
    {
        type: 'error',
        inputs: [
            { name: 'paths', internalType: 'uint256', type: 'uint256' },
            { name: 'permits', internalType: 'uint256', type: 'uint256' },
            { name: 'signatures', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'PermitPathLengthMismatch',
    },
    {
        type: 'error',
        inputs: [
            { name: 'index', internalType: 'uint256', type: 'uint256' },
            { name: 'expectedToken', internalType: 'address', type: 'address' },
            { name: 'permitToken', internalType: 'address', type: 'address' },
        ],
        name: 'PermitPathTokenMismatch',
    },
    {
        type: 'error',
        inputs: [
            { name: 'vault', internalType: 'address', type: 'address' },
            { name: 'amountIn', internalType: 'uint256', type: 'uint256' },
            { name: 'maxAmountIn', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'StrategyVaultMaxAmountExceeded',
    },
    {
        type: 'error',
        inputs: [
            { name: 'vault', internalType: 'address', type: 'address' },
            { name: 'amountOut', internalType: 'uint256', type: 'uint256' },
            { name: 'minAmountOut', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'StrategyVaultSwapFailed',
    },
    { type: 'error', inputs: [], name: 'SwapDeadline' },
    { type: 'error', inputs: [], name: 'TransientIndexOutOfBounds' },
];
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress = {
    8453: '0x1E6bDB824c37C26ED78981b18733bea7C8269aCF',
    31337: '0x1E6bDB824c37C26ED78981b18733bea7C8269aCF',
    11155111: '0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE',
};
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeBatchRouterExactInFacetConfig = {
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BalancerV3StandardExchangeBatchRouterExactOutFacet
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi = [
    {
        type: 'function',
        inputs: [],
        name: 'facetFuncs',
        outputs: [{ name: 'funcs', internalType: 'bytes4[]', type: 'bytes4[]' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetInterfaces',
        outputs: [
            { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetMetadata',
        outputs: [
            { name: 'name', internalType: 'string', type: 'string' },
            { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
            { name: 'functions', internalType: 'bytes4[]', type: 'bytes4[]' },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetName',
        outputs: [{ name: 'name', internalType: 'string', type: 'string' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'getSender',
        outputs: [{ name: '', internalType: 'address', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'paths',
                internalType: 'struct IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[]',
                type: 'tuple[]',
                components: [
                    { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
                    {
                        name: 'steps',
                        internalType: 'struct IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[]',
                        type: 'tuple[]',
                        components: [
                            { name: 'pool', internalType: 'address', type: 'address' },
                            {
                                name: 'tokenOut',
                                internalType: 'contract IERC20',
                                type: 'address',
                            },
                            { name: 'isBuffer', internalType: 'bool', type: 'bool' },
                            { name: 'isStrategyVault', internalType: 'bool', type: 'bool' },
                        ],
                    },
                    { name: 'maxAmountIn', internalType: 'uint256', type: 'uint256' },
                    { name: 'exactAmountOut', internalType: 'uint256', type: 'uint256' },
                ],
            },
            { name: 'sender', internalType: 'address', type: 'address' },
            { name: 'userData', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'querySwapExactOut',
        outputs: [
            { name: 'pathAmountsIn', internalType: 'uint256[]', type: 'uint256[]' },
            { name: 'tokensIn', internalType: 'address[]', type: 'address[]' },
            { name: 'amountsIn', internalType: 'uint256[]', type: 'uint256[]' },
        ],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'params',
                internalType: 'struct IBalancerV3StandardExchangeBatchRouterExactOut.SESwapExactOutHookParams',
                type: 'tuple',
                components: [
                    { name: 'sender', internalType: 'address', type: 'address' },
                    {
                        name: 'paths',
                        internalType: 'struct IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[]',
                        type: 'tuple[]',
                        components: [
                            {
                                name: 'tokenIn',
                                internalType: 'contract IERC20',
                                type: 'address',
                            },
                            {
                                name: 'steps',
                                internalType: 'struct IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[]',
                                type: 'tuple[]',
                                components: [
                                    { name: 'pool', internalType: 'address', type: 'address' },
                                    {
                                        name: 'tokenOut',
                                        internalType: 'contract IERC20',
                                        type: 'address',
                                    },
                                    { name: 'isBuffer', internalType: 'bool', type: 'bool' },
                                    {
                                        name: 'isStrategyVault',
                                        internalType: 'bool',
                                        type: 'bool',
                                    },
                                ],
                            },
                            { name: 'maxAmountIn', internalType: 'uint256', type: 'uint256' },
                            {
                                name: 'exactAmountOut',
                                internalType: 'uint256',
                                type: 'uint256',
                            },
                        ],
                    },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                    { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
                    { name: 'userData', internalType: 'bytes', type: 'bytes' },
                ],
            },
        ],
        name: 'querySwapExactOutHook',
        outputs: [
            { name: 'pathAmountsIn', internalType: 'uint256[]', type: 'uint256[]' },
            { name: 'tokensIn', internalType: 'address[]', type: 'address[]' },
            { name: 'amountsIn', internalType: 'uint256[]', type: 'uint256[]' },
        ],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'paths',
                internalType: 'struct IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[]',
                type: 'tuple[]',
                components: [
                    { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
                    {
                        name: 'steps',
                        internalType: 'struct IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[]',
                        type: 'tuple[]',
                        components: [
                            { name: 'pool', internalType: 'address', type: 'address' },
                            {
                                name: 'tokenOut',
                                internalType: 'contract IERC20',
                                type: 'address',
                            },
                            { name: 'isBuffer', internalType: 'bool', type: 'bool' },
                            { name: 'isStrategyVault', internalType: 'bool', type: 'bool' },
                        ],
                    },
                    { name: 'maxAmountIn', internalType: 'uint256', type: 'uint256' },
                    { name: 'exactAmountOut', internalType: 'uint256', type: 'uint256' },
                ],
            },
            { name: 'deadline', internalType: 'uint256', type: 'uint256' },
            { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
            { name: 'userData', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'swapExactOut',
        outputs: [
            { name: 'pathAmountsIn', internalType: 'uint256[]', type: 'uint256[]' },
            { name: 'tokensIn', internalType: 'address[]', type: 'address[]' },
            { name: 'amountsIn', internalType: 'uint256[]', type: 'uint256[]' },
        ],
        stateMutability: 'payable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'params',
                internalType: 'struct IBalancerV3StandardExchangeBatchRouterExactOut.SESwapExactOutHookParams',
                type: 'tuple',
                components: [
                    { name: 'sender', internalType: 'address', type: 'address' },
                    {
                        name: 'paths',
                        internalType: 'struct IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[]',
                        type: 'tuple[]',
                        components: [
                            {
                                name: 'tokenIn',
                                internalType: 'contract IERC20',
                                type: 'address',
                            },
                            {
                                name: 'steps',
                                internalType: 'struct IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[]',
                                type: 'tuple[]',
                                components: [
                                    { name: 'pool', internalType: 'address', type: 'address' },
                                    {
                                        name: 'tokenOut',
                                        internalType: 'contract IERC20',
                                        type: 'address',
                                    },
                                    { name: 'isBuffer', internalType: 'bool', type: 'bool' },
                                    {
                                        name: 'isStrategyVault',
                                        internalType: 'bool',
                                        type: 'bool',
                                    },
                                ],
                            },
                            { name: 'maxAmountIn', internalType: 'uint256', type: 'uint256' },
                            {
                                name: 'exactAmountOut',
                                internalType: 'uint256',
                                type: 'uint256',
                            },
                        ],
                    },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                    { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
                    { name: 'userData', internalType: 'bytes', type: 'bytes' },
                ],
            },
        ],
        name: 'swapExactOutHook',
        outputs: [
            { name: 'pathAmountsIn', internalType: 'uint256[]', type: 'uint256[]' },
            { name: 'tokensIn', internalType: 'address[]', type: 'address[]' },
            { name: 'amountsIn', internalType: 'uint256[]', type: 'uint256[]' },
        ],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'paths',
                internalType: 'struct IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[]',
                type: 'tuple[]',
                components: [
                    { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
                    {
                        name: 'steps',
                        internalType: 'struct IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[]',
                        type: 'tuple[]',
                        components: [
                            { name: 'pool', internalType: 'address', type: 'address' },
                            {
                                name: 'tokenOut',
                                internalType: 'contract IERC20',
                                type: 'address',
                            },
                            { name: 'isBuffer', internalType: 'bool', type: 'bool' },
                            { name: 'isStrategyVault', internalType: 'bool', type: 'bool' },
                        ],
                    },
                    { name: 'maxAmountIn', internalType: 'uint256', type: 'uint256' },
                    { name: 'exactAmountOut', internalType: 'uint256', type: 'uint256' },
                ],
            },
            { name: 'deadline', internalType: 'uint256', type: 'uint256' },
            { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
            { name: 'userData', internalType: 'bytes', type: 'bytes' },
            {
                name: 'permits',
                internalType: 'struct ISignatureTransfer.PermitTransferFrom[]',
                type: 'tuple[]',
                components: [
                    {
                        name: 'permitted',
                        internalType: 'struct ISignatureTransfer.TokenPermissions',
                        type: 'tuple',
                        components: [
                            { name: 'token', internalType: 'address', type: 'address' },
                            { name: 'amount', internalType: 'uint256', type: 'uint256' },
                        ],
                    },
                    { name: 'nonce', internalType: 'uint256', type: 'uint256' },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                ],
            },
            { name: 'signatures', internalType: 'bytes[]', type: 'bytes[]' },
        ],
        name: 'swapExactOutWithPermit',
        outputs: [
            { name: 'pathAmountsIn', internalType: 'uint256[]', type: 'uint256[]' },
            { name: 'tokensIn', internalType: 'address[]', type: 'address[]' },
            { name: 'amountsIn', internalType: 'uint256[]', type: 'uint256[]' },
        ],
        stateMutability: 'payable',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'vault',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'tokenIn',
                internalType: 'contract IERC20',
                type: 'address',
                indexed: true,
            },
            {
                name: 'tokenOut',
                internalType: 'contract IERC20',
                type: 'address',
                indexed: true,
            },
            {
                name: 'amountIn',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            {
                name: 'amountOut',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
        ],
        name: 'StrategyVaultExchangeOut',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'sender',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            { name: 'kind', internalType: 'uint8', type: 'uint8', indexed: false },
            { name: 'pool', internalType: 'address', type: 'address', indexed: true },
            {
                name: 'tokenIn',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenOut',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenInVault',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenOutVault',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'amountGiven',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            {
                name: 'limit',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            { name: 'wethIsEth', internalType: 'bool', type: 'bool', indexed: false },
        ],
        name: 'SwapHookParamsDebug',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'sender',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            { name: 'kind', internalType: 'uint8', type: 'uint8', indexed: false },
            {
                name: 'amountGiven',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            {
                name: 'limit',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            { name: 'wrap', internalType: 'bool', type: 'bool', indexed: false },
            { name: 'unwrap', internalType: 'bool', type: 'bool', indexed: false },
        ],
        name: 'WethSentinelDebug',
    },
    { type: 'error', inputs: [], name: 'EthTransfer' },
    { type: 'error', inputs: [], name: 'FailedCall' },
    {
        type: 'error',
        inputs: [
            { name: 'balance', internalType: 'uint256', type: 'uint256' },
            { name: 'needed', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'InsufficientBalance',
    },
    { type: 'error', inputs: [], name: 'InsufficientEth' },
    { type: 'error', inputs: [], name: 'InsufficientEth' },
    {
        type: 'error',
        inputs: [
            { name: 'token', internalType: 'contract IERC20', type: 'address' },
        ],
        name: 'InsufficientPayment',
    },
    {
        type: 'error',
        inputs: [
            { name: 'tokenIn', internalType: 'address', type: 'address' },
            { name: 'tokenVault', internalType: 'address', type: 'address' },
            { name: 'tokenOut', internalType: 'address', type: 'address' },
            { name: 'tokenOutVault', internalType: 'address', type: 'address' },
        ],
        name: 'InvalidRoute',
    },
    { type: 'error', inputs: [], name: 'IsLocked' },
    {
        type: 'error',
        inputs: [
            { name: 'limit', internalType: 'uint256', type: 'uint256' },
            { name: 'actual', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'LimitExceeded',
    },
    {
        type: 'error',
        inputs: [
            { name: 'minAmountOut', internalType: 'uint256', type: 'uint256' },
            { name: 'actualAmountOut', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'MinAmountOutNotMet',
    },
    {
        type: 'error',
        inputs: [{ name: 'caller', internalType: 'address', type: 'address' }],
        name: 'NotBalancerV3Vault',
    },
    {
        type: 'error',
        inputs: [
            { name: 'index', internalType: 'uint256', type: 'uint256' },
            { name: 'requiredAmount', internalType: 'uint256', type: 'uint256' },
            { name: 'permitAmount', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'PermitPathAmountInsufficient',
    },
    {
        type: 'error',
        inputs: [
            { name: 'paths', internalType: 'uint256', type: 'uint256' },
            { name: 'permits', internalType: 'uint256', type: 'uint256' },
            { name: 'signatures', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'PermitPathLengthMismatch',
    },
    {
        type: 'error',
        inputs: [
            { name: 'index', internalType: 'uint256', type: 'uint256' },
            { name: 'expectedToken', internalType: 'address', type: 'address' },
            { name: 'permitToken', internalType: 'address', type: 'address' },
        ],
        name: 'PermitPathTokenMismatch',
    },
    {
        type: 'error',
        inputs: [
            { name: 'vault', internalType: 'address', type: 'address' },
            { name: 'amountIn', internalType: 'uint256', type: 'uint256' },
            { name: 'maxAmountIn', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'StrategyVaultMaxAmountExceeded',
    },
    {
        type: 'error',
        inputs: [
            { name: 'vault', internalType: 'address', type: 'address' },
            { name: 'amountOut', internalType: 'uint256', type: 'uint256' },
            { name: 'minAmountOut', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'StrategyVaultSwapFailed',
    },
    { type: 'error', inputs: [], name: 'SwapDeadline' },
    { type: 'error', inputs: [], name: 'TransientIndexOutOfBounds' },
];
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress = {
    8453: '0x1E6bDB824c37C26ED78981b18733bea7C8269aCF',
    31337: '0x1E6bDB824c37C26ED78981b18733bea7C8269aCF',
    11155111: '0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE',
};
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeBatchRouterExactOutFacetConfig = {
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BalancerV3StandardExchangeRouterExactInQueryFacet
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeRouterExactInQueryFacetAbi = [
    {
        type: 'function',
        inputs: [],
        name: 'facetFuncs',
        outputs: [{ name: 'funcs', internalType: 'bytes4[]', type: 'bytes4[]' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetInterfaces',
        outputs: [
            { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetMetadata',
        outputs: [
            { name: 'name', internalType: 'string', type: 'string' },
            { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
            { name: 'functions', internalType: 'bytes4[]', type: 'bytes4[]' },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetName',
        outputs: [{ name: 'name', internalType: 'string', type: 'string' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'getSender',
        outputs: [{ name: '', internalType: 'address', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [
            { name: 'pool', internalType: 'address', type: 'address' },
            { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
            {
                name: 'tokenInVault',
                internalType: 'contract IStandardExchangeProxy',
                type: 'address',
            },
            { name: 'tokenOut', internalType: 'contract IERC20', type: 'address' },
            {
                name: 'tokenOutVault',
                internalType: 'contract IStandardExchangeProxy',
                type: 'address',
            },
            { name: 'exactAmountIn', internalType: 'uint256', type: 'uint256' },
            { name: 'sender', internalType: 'address', type: 'address' },
            { name: 'userData', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'querySwapSingleTokenExactIn',
        outputs: [{ name: 'amountOut', internalType: 'uint256', type: 'uint256' }],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'params',
                internalType: 'struct BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams',
                type: 'tuple',
                components: [
                    { name: 'sender', internalType: 'address', type: 'address' },
                    { name: 'kind', internalType: 'enum SwapKind', type: 'uint8' },
                    { name: 'pool', internalType: 'address', type: 'address' },
                    { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
                    {
                        name: 'tokenInVault',
                        internalType: 'contract IStandardExchangeProxy',
                        type: 'address',
                    },
                    {
                        name: 'tokenOut',
                        internalType: 'contract IERC20',
                        type: 'address',
                    },
                    {
                        name: 'tokenOutVault',
                        internalType: 'contract IStandardExchangeProxy',
                        type: 'address',
                    },
                    { name: 'amountGiven', internalType: 'uint256', type: 'uint256' },
                    { name: 'limit', internalType: 'uint256', type: 'uint256' },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                    { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
                    { name: 'userData', internalType: 'bytes', type: 'bytes' },
                ],
            },
        ],
        name: 'querySwapSingleTokenExactInHook',
        outputs: [
            { name: 'amountCalculated', internalType: 'uint256', type: 'uint256' },
        ],
        stateMutability: 'nonpayable',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'sender',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            { name: 'kind', internalType: 'uint8', type: 'uint8', indexed: false },
            { name: 'pool', internalType: 'address', type: 'address', indexed: true },
            {
                name: 'tokenIn',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenOut',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenInVault',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenOutVault',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'amountGiven',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            {
                name: 'limit',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            { name: 'wethIsEth', internalType: 'bool', type: 'bool', indexed: false },
        ],
        name: 'SwapHookParamsDebug',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'sender',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            { name: 'kind', internalType: 'uint8', type: 'uint8', indexed: false },
            {
                name: 'amountGiven',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            {
                name: 'limit',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            { name: 'wrap', internalType: 'bool', type: 'bool', indexed: false },
            { name: 'unwrap', internalType: 'bool', type: 'bool', indexed: false },
        ],
        name: 'WethSentinelDebug',
    },
    { type: 'error', inputs: [], name: 'EthTransfer' },
    { type: 'error', inputs: [], name: 'InsufficientEth' },
    {
        type: 'error',
        inputs: [
            { name: 'token', internalType: 'contract IERC20', type: 'address' },
        ],
        name: 'InsufficientPayment',
    },
    {
        type: 'error',
        inputs: [
            { name: 'tokenIn', internalType: 'address', type: 'address' },
            { name: 'tokenVault', internalType: 'address', type: 'address' },
            { name: 'tokenOut', internalType: 'address', type: 'address' },
            { name: 'tokenOutVault', internalType: 'address', type: 'address' },
        ],
        name: 'InvalidRoute',
    },
    {
        type: 'error',
        inputs: [
            { name: 'limit', internalType: 'uint256', type: 'uint256' },
            { name: 'actual', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'LimitExceeded',
    },
    {
        type: 'error',
        inputs: [
            { name: 'minAmountOut', internalType: 'uint256', type: 'uint256' },
            { name: 'actualAmountOut', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'MinAmountOutNotMet',
    },
    {
        type: 'error',
        inputs: [{ name: 'caller', internalType: 'address', type: 'address' }],
        name: 'NotBalancerV3Vault',
    },
    { type: 'error', inputs: [], name: 'SwapDeadline' },
];
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeRouterExactInQueryFacetAddress = {
    8453: '0x1E6bDB824c37C26ED78981b18733bea7C8269aCF',
    31337: '0x1E6bDB824c37C26ED78981b18733bea7C8269aCF',
    11155111: '0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE',
};
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeRouterExactInQueryFacetConfig = {
    address: exports.balancerV3StandardExchangeRouterExactInQueryFacetAddress,
    abi: exports.balancerV3StandardExchangeRouterExactInQueryFacetAbi,
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BalancerV3StandardExchangeRouterExactInSwapFacet
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeRouterExactInSwapFacetAbi = [
    {
        type: 'function',
        inputs: [],
        name: 'facetFuncs',
        outputs: [{ name: 'funcs', internalType: 'bytes4[]', type: 'bytes4[]' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetInterfaces',
        outputs: [
            { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetMetadata',
        outputs: [
            { name: 'name', internalType: 'string', type: 'string' },
            { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
            { name: 'functions', internalType: 'bytes4[]', type: 'bytes4[]' },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetName',
        outputs: [{ name: 'name', internalType: 'string', type: 'string' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'getSender',
        outputs: [{ name: '', internalType: 'address', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [
            { name: 'pool', internalType: 'address', type: 'address' },
            { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
            {
                name: 'tokenInVault',
                internalType: 'contract IStandardExchangeProxy',
                type: 'address',
            },
            { name: 'tokenOut', internalType: 'contract IERC20', type: 'address' },
            {
                name: 'tokenOutVault',
                internalType: 'contract IStandardExchangeProxy',
                type: 'address',
            },
            { name: 'exactAmountIn', internalType: 'uint256', type: 'uint256' },
            { name: 'minAmountOut', internalType: 'uint256', type: 'uint256' },
            { name: 'deadline', internalType: 'uint256', type: 'uint256' },
            { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
            { name: 'userData', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'swapSingleTokenExactIn',
        outputs: [{ name: 'amountOut', internalType: 'uint256', type: 'uint256' }],
        stateMutability: 'payable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'params',
                internalType: 'struct BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams',
                type: 'tuple',
                components: [
                    { name: 'sender', internalType: 'address', type: 'address' },
                    { name: 'kind', internalType: 'enum SwapKind', type: 'uint8' },
                    { name: 'pool', internalType: 'address', type: 'address' },
                    { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
                    {
                        name: 'tokenInVault',
                        internalType: 'contract IStandardExchangeProxy',
                        type: 'address',
                    },
                    {
                        name: 'tokenOut',
                        internalType: 'contract IERC20',
                        type: 'address',
                    },
                    {
                        name: 'tokenOutVault',
                        internalType: 'contract IStandardExchangeProxy',
                        type: 'address',
                    },
                    { name: 'amountGiven', internalType: 'uint256', type: 'uint256' },
                    { name: 'limit', internalType: 'uint256', type: 'uint256' },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                    { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
                    { name: 'userData', internalType: 'bytes', type: 'bytes' },
                ],
            },
        ],
        name: 'swapSingleTokenExactInHook',
        outputs: [
            { name: 'amountCalculated', internalType: 'uint256', type: 'uint256' },
        ],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'swapParams',
                internalType: 'struct BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams',
                type: 'tuple',
                components: [
                    { name: 'sender', internalType: 'address', type: 'address' },
                    { name: 'kind', internalType: 'enum SwapKind', type: 'uint8' },
                    { name: 'pool', internalType: 'address', type: 'address' },
                    { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
                    {
                        name: 'tokenInVault',
                        internalType: 'contract IStandardExchangeProxy',
                        type: 'address',
                    },
                    {
                        name: 'tokenOut',
                        internalType: 'contract IERC20',
                        type: 'address',
                    },
                    {
                        name: 'tokenOutVault',
                        internalType: 'contract IStandardExchangeProxy',
                        type: 'address',
                    },
                    { name: 'amountGiven', internalType: 'uint256', type: 'uint256' },
                    { name: 'limit', internalType: 'uint256', type: 'uint256' },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                    { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
                    { name: 'userData', internalType: 'bytes', type: 'bytes' },
                ],
            },
            {
                name: 'permit',
                internalType: 'struct ISignatureTransfer.PermitTransferFrom',
                type: 'tuple',
                components: [
                    {
                        name: 'permitted',
                        internalType: 'struct ISignatureTransfer.TokenPermissions',
                        type: 'tuple',
                        components: [
                            { name: 'token', internalType: 'address', type: 'address' },
                            { name: 'amount', internalType: 'uint256', type: 'uint256' },
                        ],
                    },
                    { name: 'nonce', internalType: 'uint256', type: 'uint256' },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                ],
            },
            { name: 'signature', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'swapSingleTokenExactInWithPermit',
        outputs: [{ name: 'amountOut', internalType: 'uint256', type: 'uint256' }],
        stateMutability: 'payable',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'sender',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            { name: 'kind', internalType: 'uint8', type: 'uint8', indexed: false },
            { name: 'pool', internalType: 'address', type: 'address', indexed: true },
            {
                name: 'tokenIn',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenOut',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenInVault',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenOutVault',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'amountGiven',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            {
                name: 'limit',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            { name: 'wethIsEth', internalType: 'bool', type: 'bool', indexed: false },
        ],
        name: 'SwapHookParamsDebug',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'sender',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            { name: 'kind', internalType: 'uint8', type: 'uint8', indexed: false },
            {
                name: 'amountGiven',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            {
                name: 'limit',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            { name: 'wrap', internalType: 'bool', type: 'bool', indexed: false },
            { name: 'unwrap', internalType: 'bool', type: 'bool', indexed: false },
        ],
        name: 'WethSentinelDebug',
    },
    { type: 'error', inputs: [], name: 'EthTransfer' },
    { type: 'error', inputs: [], name: 'FailedCall' },
    {
        type: 'error',
        inputs: [
            { name: 'balance', internalType: 'uint256', type: 'uint256' },
            { name: 'needed', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'InsufficientBalance',
    },
    { type: 'error', inputs: [], name: 'InsufficientEth' },
    { type: 'error', inputs: [], name: 'InsufficientEth' },
    {
        type: 'error',
        inputs: [
            { name: 'token', internalType: 'contract IERC20', type: 'address' },
        ],
        name: 'InsufficientPayment',
    },
    {
        type: 'error',
        inputs: [
            { name: 'tokenIn', internalType: 'address', type: 'address' },
            { name: 'tokenVault', internalType: 'address', type: 'address' },
            { name: 'tokenOut', internalType: 'address', type: 'address' },
            { name: 'tokenOutVault', internalType: 'address', type: 'address' },
        ],
        name: 'InvalidRoute',
    },
    { type: 'error', inputs: [], name: 'IsLocked' },
    {
        type: 'error',
        inputs: [
            { name: 'limit', internalType: 'uint256', type: 'uint256' },
            { name: 'actual', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'LimitExceeded',
    },
    {
        type: 'error',
        inputs: [
            { name: 'minAmountOut', internalType: 'uint256', type: 'uint256' },
            { name: 'actualAmountOut', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'MinAmountOutNotMet',
    },
    {
        type: 'error',
        inputs: [{ name: 'caller', internalType: 'address', type: 'address' }],
        name: 'NotBalancerV3Vault',
    },
    { type: 'error', inputs: [], name: 'SwapDeadline' },
];
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeRouterExactInSwapFacetAddress = {
    8453: '0x1E6bDB824c37C26ED78981b18733bea7C8269aCF',
    31337: '0x1E6bDB824c37C26ED78981b18733bea7C8269aCF',
    11155111: '0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE',
};
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeRouterExactInSwapFacetConfig = {
    address: exports.balancerV3StandardExchangeRouterExactInSwapFacetAddress,
    abi: exports.balancerV3StandardExchangeRouterExactInSwapFacetAbi,
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BalancerV3StandardExchangeRouterExactInSwapTarget
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeRouterExactInSwapTargetAbi = [
    {
        type: 'function',
        inputs: [],
        name: 'getSender',
        outputs: [{ name: '', internalType: 'address', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [
            { name: 'pool', internalType: 'address', type: 'address' },
            { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
            {
                name: 'tokenInVault',
                internalType: 'contract IStandardExchangeProxy',
                type: 'address',
            },
            { name: 'tokenOut', internalType: 'contract IERC20', type: 'address' },
            {
                name: 'tokenOutVault',
                internalType: 'contract IStandardExchangeProxy',
                type: 'address',
            },
            { name: 'exactAmountIn', internalType: 'uint256', type: 'uint256' },
            { name: 'minAmountOut', internalType: 'uint256', type: 'uint256' },
            { name: 'deadline', internalType: 'uint256', type: 'uint256' },
            { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
            { name: 'userData', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'swapSingleTokenExactIn',
        outputs: [{ name: 'amountOut', internalType: 'uint256', type: 'uint256' }],
        stateMutability: 'payable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'params',
                internalType: 'struct BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams',
                type: 'tuple',
                components: [
                    { name: 'sender', internalType: 'address', type: 'address' },
                    { name: 'kind', internalType: 'enum SwapKind', type: 'uint8' },
                    { name: 'pool', internalType: 'address', type: 'address' },
                    { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
                    {
                        name: 'tokenInVault',
                        internalType: 'contract IStandardExchangeProxy',
                        type: 'address',
                    },
                    {
                        name: 'tokenOut',
                        internalType: 'contract IERC20',
                        type: 'address',
                    },
                    {
                        name: 'tokenOutVault',
                        internalType: 'contract IStandardExchangeProxy',
                        type: 'address',
                    },
                    { name: 'amountGiven', internalType: 'uint256', type: 'uint256' },
                    { name: 'limit', internalType: 'uint256', type: 'uint256' },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                    { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
                    { name: 'userData', internalType: 'bytes', type: 'bytes' },
                ],
            },
        ],
        name: 'swapSingleTokenExactInHook',
        outputs: [
            { name: 'amountCalculated', internalType: 'uint256', type: 'uint256' },
        ],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'swapParams',
                internalType: 'struct BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams',
                type: 'tuple',
                components: [
                    { name: 'sender', internalType: 'address', type: 'address' },
                    { name: 'kind', internalType: 'enum SwapKind', type: 'uint8' },
                    { name: 'pool', internalType: 'address', type: 'address' },
                    { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
                    {
                        name: 'tokenInVault',
                        internalType: 'contract IStandardExchangeProxy',
                        type: 'address',
                    },
                    {
                        name: 'tokenOut',
                        internalType: 'contract IERC20',
                        type: 'address',
                    },
                    {
                        name: 'tokenOutVault',
                        internalType: 'contract IStandardExchangeProxy',
                        type: 'address',
                    },
                    { name: 'amountGiven', internalType: 'uint256', type: 'uint256' },
                    { name: 'limit', internalType: 'uint256', type: 'uint256' },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                    { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
                    { name: 'userData', internalType: 'bytes', type: 'bytes' },
                ],
            },
            {
                name: 'permit',
                internalType: 'struct ISignatureTransfer.PermitTransferFrom',
                type: 'tuple',
                components: [
                    {
                        name: 'permitted',
                        internalType: 'struct ISignatureTransfer.TokenPermissions',
                        type: 'tuple',
                        components: [
                            { name: 'token', internalType: 'address', type: 'address' },
                            { name: 'amount', internalType: 'uint256', type: 'uint256' },
                        ],
                    },
                    { name: 'nonce', internalType: 'uint256', type: 'uint256' },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                ],
            },
            { name: 'signature', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'swapSingleTokenExactInWithPermit',
        outputs: [{ name: 'amountOut', internalType: 'uint256', type: 'uint256' }],
        stateMutability: 'payable',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'sender',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            { name: 'kind', internalType: 'uint8', type: 'uint8', indexed: false },
            { name: 'pool', internalType: 'address', type: 'address', indexed: true },
            {
                name: 'tokenIn',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenOut',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenInVault',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenOutVault',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'amountGiven',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            {
                name: 'limit',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            { name: 'wethIsEth', internalType: 'bool', type: 'bool', indexed: false },
        ],
        name: 'SwapHookParamsDebug',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'sender',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            { name: 'kind', internalType: 'uint8', type: 'uint8', indexed: false },
            {
                name: 'amountGiven',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            {
                name: 'limit',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            { name: 'wrap', internalType: 'bool', type: 'bool', indexed: false },
            { name: 'unwrap', internalType: 'bool', type: 'bool', indexed: false },
        ],
        name: 'WethSentinelDebug',
    },
    { type: 'error', inputs: [], name: 'EthTransfer' },
    { type: 'error', inputs: [], name: 'FailedCall' },
    {
        type: 'error',
        inputs: [
            { name: 'balance', internalType: 'uint256', type: 'uint256' },
            { name: 'needed', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'InsufficientBalance',
    },
    { type: 'error', inputs: [], name: 'InsufficientEth' },
    { type: 'error', inputs: [], name: 'InsufficientEth' },
    {
        type: 'error',
        inputs: [
            { name: 'token', internalType: 'contract IERC20', type: 'address' },
        ],
        name: 'InsufficientPayment',
    },
    {
        type: 'error',
        inputs: [
            { name: 'tokenIn', internalType: 'address', type: 'address' },
            { name: 'tokenVault', internalType: 'address', type: 'address' },
            { name: 'tokenOut', internalType: 'address', type: 'address' },
            { name: 'tokenOutVault', internalType: 'address', type: 'address' },
        ],
        name: 'InvalidRoute',
    },
    { type: 'error', inputs: [], name: 'IsLocked' },
    {
        type: 'error',
        inputs: [
            { name: 'limit', internalType: 'uint256', type: 'uint256' },
            { name: 'actual', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'LimitExceeded',
    },
    {
        type: 'error',
        inputs: [
            { name: 'minAmountOut', internalType: 'uint256', type: 'uint256' },
            { name: 'actualAmountOut', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'MinAmountOutNotMet',
    },
    {
        type: 'error',
        inputs: [{ name: 'caller', internalType: 'address', type: 'address' }],
        name: 'NotBalancerV3Vault',
    },
    { type: 'error', inputs: [], name: 'SwapDeadline' },
];
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeRouterExactInSwapTargetAddress = {
    8453: '0x1E6bDB824c37C26ED78981b18733bea7C8269aCF',
    31337: '0x1E6bDB824c37C26ED78981b18733bea7C8269aCF',
    11155111: '0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE',
};
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeRouterExactInSwapTargetConfig = {
    address: exports.balancerV3StandardExchangeRouterExactInSwapTargetAddress,
    abi: exports.balancerV3StandardExchangeRouterExactInSwapTargetAbi,
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BalancerV3StandardExchangeRouterExactOutQueryFacet
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeRouterExactOutQueryFacetAbi = [
    {
        type: 'function',
        inputs: [],
        name: 'facetFuncs',
        outputs: [{ name: 'funcs', internalType: 'bytes4[]', type: 'bytes4[]' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetInterfaces',
        outputs: [
            { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetMetadata',
        outputs: [
            { name: 'name', internalType: 'string', type: 'string' },
            { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
            { name: 'functions', internalType: 'bytes4[]', type: 'bytes4[]' },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetName',
        outputs: [{ name: 'name', internalType: 'string', type: 'string' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'getSender',
        outputs: [{ name: '', internalType: 'address', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [
            { name: 'pool', internalType: 'address', type: 'address' },
            { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
            {
                name: 'tokenInVault',
                internalType: 'contract IStandardExchangeProxy',
                type: 'address',
            },
            { name: 'tokenOut', internalType: 'contract IERC20', type: 'address' },
            {
                name: 'tokenOutVault',
                internalType: 'contract IStandardExchangeProxy',
                type: 'address',
            },
            { name: 'exactAmountOut', internalType: 'uint256', type: 'uint256' },
            { name: 'sender', internalType: 'address', type: 'address' },
            { name: 'userData', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'querySwapSingleTokenExactOut',
        outputs: [{ name: 'amountIn', internalType: 'uint256', type: 'uint256' }],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'params',
                internalType: 'struct BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams',
                type: 'tuple',
                components: [
                    { name: 'sender', internalType: 'address', type: 'address' },
                    { name: 'kind', internalType: 'enum SwapKind', type: 'uint8' },
                    { name: 'pool', internalType: 'address', type: 'address' },
                    { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
                    {
                        name: 'tokenInVault',
                        internalType: 'contract IStandardExchangeProxy',
                        type: 'address',
                    },
                    {
                        name: 'tokenOut',
                        internalType: 'contract IERC20',
                        type: 'address',
                    },
                    {
                        name: 'tokenOutVault',
                        internalType: 'contract IStandardExchangeProxy',
                        type: 'address',
                    },
                    { name: 'amountGiven', internalType: 'uint256', type: 'uint256' },
                    { name: 'limit', internalType: 'uint256', type: 'uint256' },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                    { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
                    { name: 'userData', internalType: 'bytes', type: 'bytes' },
                ],
            },
        ],
        name: 'querySwapSingleTokenExactOutHook',
        outputs: [
            { name: 'amountCalculated', internalType: 'uint256', type: 'uint256' },
        ],
        stateMutability: 'nonpayable',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'sender',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            { name: 'kind', internalType: 'uint8', type: 'uint8', indexed: false },
            { name: 'pool', internalType: 'address', type: 'address', indexed: true },
            {
                name: 'tokenIn',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenOut',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenInVault',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenOutVault',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'amountGiven',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            {
                name: 'limit',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            { name: 'wethIsEth', internalType: 'bool', type: 'bool', indexed: false },
        ],
        name: 'SwapHookParamsDebug',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'sender',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            { name: 'kind', internalType: 'uint8', type: 'uint8', indexed: false },
            {
                name: 'amountGiven',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            {
                name: 'limit',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            { name: 'wrap', internalType: 'bool', type: 'bool', indexed: false },
            { name: 'unwrap', internalType: 'bool', type: 'bool', indexed: false },
        ],
        name: 'WethSentinelDebug',
    },
    { type: 'error', inputs: [], name: 'EthTransfer' },
    { type: 'error', inputs: [], name: 'InsufficientEth' },
    {
        type: 'error',
        inputs: [
            { name: 'token', internalType: 'contract IERC20', type: 'address' },
        ],
        name: 'InsufficientPayment',
    },
    {
        type: 'error',
        inputs: [
            { name: 'tokenIn', internalType: 'address', type: 'address' },
            { name: 'tokenVault', internalType: 'address', type: 'address' },
            { name: 'tokenOut', internalType: 'address', type: 'address' },
            { name: 'tokenOutVault', internalType: 'address', type: 'address' },
        ],
        name: 'InvalidRoute',
    },
    {
        type: 'error',
        inputs: [
            { name: 'limit', internalType: 'uint256', type: 'uint256' },
            { name: 'actual', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'LimitExceeded',
    },
    {
        type: 'error',
        inputs: [
            { name: 'minAmountOut', internalType: 'uint256', type: 'uint256' },
            { name: 'actualAmountOut', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'MinAmountOutNotMet',
    },
    {
        type: 'error',
        inputs: [{ name: 'caller', internalType: 'address', type: 'address' }],
        name: 'NotBalancerV3Vault',
    },
    { type: 'error', inputs: [], name: 'SwapDeadline' },
];
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeRouterExactOutQueryFacetAddress = {
    8453: '0x1E6bDB824c37C26ED78981b18733bea7C8269aCF',
    31337: '0x1E6bDB824c37C26ED78981b18733bea7C8269aCF',
    11155111: '0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE',
};
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeRouterExactOutQueryFacetConfig = {
    address: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAddress,
    abi: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAbi,
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BalancerV3StandardExchangeRouterExactOutSwapFacet
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeRouterExactOutSwapFacetAbi = [
    {
        type: 'function',
        inputs: [],
        name: 'facetFuncs',
        outputs: [{ name: 'funcs', internalType: 'bytes4[]', type: 'bytes4[]' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetInterfaces',
        outputs: [
            { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetMetadata',
        outputs: [
            { name: 'name', internalType: 'string', type: 'string' },
            { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
            { name: 'functions', internalType: 'bytes4[]', type: 'bytes4[]' },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetName',
        outputs: [{ name: 'name', internalType: 'string', type: 'string' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'getSender',
        outputs: [{ name: '', internalType: 'address', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [
            { name: 'pool', internalType: 'address', type: 'address' },
            { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
            {
                name: 'tokenInVault',
                internalType: 'contract IStandardExchangeProxy',
                type: 'address',
            },
            { name: 'tokenOut', internalType: 'contract IERC20', type: 'address' },
            {
                name: 'tokenOutVault',
                internalType: 'contract IStandardExchangeProxy',
                type: 'address',
            },
            { name: 'exactAmountOut', internalType: 'uint256', type: 'uint256' },
            { name: 'maxAmountIn', internalType: 'uint256', type: 'uint256' },
            { name: 'deadline', internalType: 'uint256', type: 'uint256' },
            { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
            { name: 'userData', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'swapSingleTokenExactOut',
        outputs: [{ name: 'amountIn', internalType: 'uint256', type: 'uint256' }],
        stateMutability: 'payable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'params',
                internalType: 'struct BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams',
                type: 'tuple',
                components: [
                    { name: 'sender', internalType: 'address', type: 'address' },
                    { name: 'kind', internalType: 'enum SwapKind', type: 'uint8' },
                    { name: 'pool', internalType: 'address', type: 'address' },
                    { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
                    {
                        name: 'tokenInVault',
                        internalType: 'contract IStandardExchangeProxy',
                        type: 'address',
                    },
                    {
                        name: 'tokenOut',
                        internalType: 'contract IERC20',
                        type: 'address',
                    },
                    {
                        name: 'tokenOutVault',
                        internalType: 'contract IStandardExchangeProxy',
                        type: 'address',
                    },
                    { name: 'amountGiven', internalType: 'uint256', type: 'uint256' },
                    { name: 'limit', internalType: 'uint256', type: 'uint256' },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                    { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
                    { name: 'userData', internalType: 'bytes', type: 'bytes' },
                ],
            },
        ],
        name: 'swapSingleTokenExactOutHook',
        outputs: [
            { name: 'amountCalculated', internalType: 'uint256', type: 'uint256' },
        ],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'swapParams',
                internalType: 'struct BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams',
                type: 'tuple',
                components: [
                    { name: 'sender', internalType: 'address', type: 'address' },
                    { name: 'kind', internalType: 'enum SwapKind', type: 'uint8' },
                    { name: 'pool', internalType: 'address', type: 'address' },
                    { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
                    {
                        name: 'tokenInVault',
                        internalType: 'contract IStandardExchangeProxy',
                        type: 'address',
                    },
                    {
                        name: 'tokenOut',
                        internalType: 'contract IERC20',
                        type: 'address',
                    },
                    {
                        name: 'tokenOutVault',
                        internalType: 'contract IStandardExchangeProxy',
                        type: 'address',
                    },
                    { name: 'amountGiven', internalType: 'uint256', type: 'uint256' },
                    { name: 'limit', internalType: 'uint256', type: 'uint256' },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                    { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
                    { name: 'userData', internalType: 'bytes', type: 'bytes' },
                ],
            },
            {
                name: 'permit',
                internalType: 'struct ISignatureTransfer.PermitTransferFrom',
                type: 'tuple',
                components: [
                    {
                        name: 'permitted',
                        internalType: 'struct ISignatureTransfer.TokenPermissions',
                        type: 'tuple',
                        components: [
                            { name: 'token', internalType: 'address', type: 'address' },
                            { name: 'amount', internalType: 'uint256', type: 'uint256' },
                        ],
                    },
                    { name: 'nonce', internalType: 'uint256', type: 'uint256' },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                ],
            },
            { name: 'signature', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'swapSingleTokenExactOutWithPermit',
        outputs: [{ name: 'amountIn', internalType: 'uint256', type: 'uint256' }],
        stateMutability: 'payable',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'sender',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            { name: 'kind', internalType: 'uint8', type: 'uint8', indexed: false },
            { name: 'pool', internalType: 'address', type: 'address', indexed: true },
            {
                name: 'tokenIn',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenOut',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenInVault',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenOutVault',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'amountGiven',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            {
                name: 'limit',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            { name: 'wethIsEth', internalType: 'bool', type: 'bool', indexed: false },
        ],
        name: 'SwapHookParamsDebug',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'sender',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            { name: 'kind', internalType: 'uint8', type: 'uint8', indexed: false },
            {
                name: 'amountGiven',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            {
                name: 'limit',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            { name: 'wrap', internalType: 'bool', type: 'bool', indexed: false },
            { name: 'unwrap', internalType: 'bool', type: 'bool', indexed: false },
        ],
        name: 'WethSentinelDebug',
    },
    { type: 'error', inputs: [], name: 'EthTransfer' },
    { type: 'error', inputs: [], name: 'FailedCall' },
    {
        type: 'error',
        inputs: [
            { name: 'balance', internalType: 'uint256', type: 'uint256' },
            { name: 'needed', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'InsufficientBalance',
    },
    { type: 'error', inputs: [], name: 'InsufficientEth' },
    { type: 'error', inputs: [], name: 'InsufficientEth' },
    {
        type: 'error',
        inputs: [
            { name: 'token', internalType: 'contract IERC20', type: 'address' },
        ],
        name: 'InsufficientPayment',
    },
    {
        type: 'error',
        inputs: [
            { name: 'tokenIn', internalType: 'address', type: 'address' },
            { name: 'tokenVault', internalType: 'address', type: 'address' },
            { name: 'tokenOut', internalType: 'address', type: 'address' },
            { name: 'tokenOutVault', internalType: 'address', type: 'address' },
        ],
        name: 'InvalidRoute',
    },
    {
        type: 'error',
        inputs: [
            { name: 'limit', internalType: 'uint256', type: 'uint256' },
            { name: 'actual', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'LimitExceeded',
    },
    {
        type: 'error',
        inputs: [
            { name: 'minAmountOut', internalType: 'uint256', type: 'uint256' },
            { name: 'actualAmountOut', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'MinAmountOutNotMet',
    },
    {
        type: 'error',
        inputs: [{ name: 'caller', internalType: 'address', type: 'address' }],
        name: 'NotBalancerV3Vault',
    },
    { type: 'error', inputs: [], name: 'SwapDeadline' },
];
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeRouterExactOutSwapFacetAddress = {
    8453: '0x1E6bDB824c37C26ED78981b18733bea7C8269aCF',
    31337: '0x1E6bDB824c37C26ED78981b18733bea7C8269aCF',
    11155111: '0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE',
};
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeRouterExactOutSwapFacetConfig = {
    address: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAddress,
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAbi,
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BalancerV3StandardExchangeRouterExactOutSwapTarget
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeRouterExactOutSwapTargetAbi = [
    {
        type: 'function',
        inputs: [],
        name: 'getSender',
        outputs: [{ name: '', internalType: 'address', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [
            { name: 'pool', internalType: 'address', type: 'address' },
            { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
            {
                name: 'tokenInVault',
                internalType: 'contract IStandardExchangeProxy',
                type: 'address',
            },
            { name: 'tokenOut', internalType: 'contract IERC20', type: 'address' },
            {
                name: 'tokenOutVault',
                internalType: 'contract IStandardExchangeProxy',
                type: 'address',
            },
            { name: 'exactAmountOut', internalType: 'uint256', type: 'uint256' },
            { name: 'maxAmountIn', internalType: 'uint256', type: 'uint256' },
            { name: 'deadline', internalType: 'uint256', type: 'uint256' },
            { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
            { name: 'userData', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'swapSingleTokenExactOut',
        outputs: [{ name: 'amountIn', internalType: 'uint256', type: 'uint256' }],
        stateMutability: 'payable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'params',
                internalType: 'struct BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams',
                type: 'tuple',
                components: [
                    { name: 'sender', internalType: 'address', type: 'address' },
                    { name: 'kind', internalType: 'enum SwapKind', type: 'uint8' },
                    { name: 'pool', internalType: 'address', type: 'address' },
                    { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
                    {
                        name: 'tokenInVault',
                        internalType: 'contract IStandardExchangeProxy',
                        type: 'address',
                    },
                    {
                        name: 'tokenOut',
                        internalType: 'contract IERC20',
                        type: 'address',
                    },
                    {
                        name: 'tokenOutVault',
                        internalType: 'contract IStandardExchangeProxy',
                        type: 'address',
                    },
                    { name: 'amountGiven', internalType: 'uint256', type: 'uint256' },
                    { name: 'limit', internalType: 'uint256', type: 'uint256' },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                    { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
                    { name: 'userData', internalType: 'bytes', type: 'bytes' },
                ],
            },
        ],
        name: 'swapSingleTokenExactOutHook',
        outputs: [
            { name: 'amountCalculated', internalType: 'uint256', type: 'uint256' },
        ],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'swapParams',
                internalType: 'struct BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams',
                type: 'tuple',
                components: [
                    { name: 'sender', internalType: 'address', type: 'address' },
                    { name: 'kind', internalType: 'enum SwapKind', type: 'uint8' },
                    { name: 'pool', internalType: 'address', type: 'address' },
                    { name: 'tokenIn', internalType: 'contract IERC20', type: 'address' },
                    {
                        name: 'tokenInVault',
                        internalType: 'contract IStandardExchangeProxy',
                        type: 'address',
                    },
                    {
                        name: 'tokenOut',
                        internalType: 'contract IERC20',
                        type: 'address',
                    },
                    {
                        name: 'tokenOutVault',
                        internalType: 'contract IStandardExchangeProxy',
                        type: 'address',
                    },
                    { name: 'amountGiven', internalType: 'uint256', type: 'uint256' },
                    { name: 'limit', internalType: 'uint256', type: 'uint256' },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                    { name: 'wethIsEth', internalType: 'bool', type: 'bool' },
                    { name: 'userData', internalType: 'bytes', type: 'bytes' },
                ],
            },
            {
                name: 'permit',
                internalType: 'struct ISignatureTransfer.PermitTransferFrom',
                type: 'tuple',
                components: [
                    {
                        name: 'permitted',
                        internalType: 'struct ISignatureTransfer.TokenPermissions',
                        type: 'tuple',
                        components: [
                            { name: 'token', internalType: 'address', type: 'address' },
                            { name: 'amount', internalType: 'uint256', type: 'uint256' },
                        ],
                    },
                    { name: 'nonce', internalType: 'uint256', type: 'uint256' },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                ],
            },
            { name: 'signature', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'swapSingleTokenExactOutWithPermit',
        outputs: [{ name: 'amountIn', internalType: 'uint256', type: 'uint256' }],
        stateMutability: 'payable',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'sender',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            { name: 'kind', internalType: 'uint8', type: 'uint8', indexed: false },
            { name: 'pool', internalType: 'address', type: 'address', indexed: true },
            {
                name: 'tokenIn',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenOut',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenInVault',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'tokenOutVault',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'amountGiven',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            {
                name: 'limit',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            { name: 'wethIsEth', internalType: 'bool', type: 'bool', indexed: false },
        ],
        name: 'SwapHookParamsDebug',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'sender',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            { name: 'kind', internalType: 'uint8', type: 'uint8', indexed: false },
            {
                name: 'amountGiven',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            {
                name: 'limit',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            { name: 'wrap', internalType: 'bool', type: 'bool', indexed: false },
            { name: 'unwrap', internalType: 'bool', type: 'bool', indexed: false },
        ],
        name: 'WethSentinelDebug',
    },
    { type: 'error', inputs: [], name: 'EthTransfer' },
    { type: 'error', inputs: [], name: 'FailedCall' },
    {
        type: 'error',
        inputs: [
            { name: 'balance', internalType: 'uint256', type: 'uint256' },
            { name: 'needed', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'InsufficientBalance',
    },
    { type: 'error', inputs: [], name: 'InsufficientEth' },
    { type: 'error', inputs: [], name: 'InsufficientEth' },
    {
        type: 'error',
        inputs: [
            { name: 'token', internalType: 'contract IERC20', type: 'address' },
        ],
        name: 'InsufficientPayment',
    },
    {
        type: 'error',
        inputs: [
            { name: 'tokenIn', internalType: 'address', type: 'address' },
            { name: 'tokenVault', internalType: 'address', type: 'address' },
            { name: 'tokenOut', internalType: 'address', type: 'address' },
            { name: 'tokenOutVault', internalType: 'address', type: 'address' },
        ],
        name: 'InvalidRoute',
    },
    {
        type: 'error',
        inputs: [
            { name: 'limit', internalType: 'uint256', type: 'uint256' },
            { name: 'actual', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'LimitExceeded',
    },
    {
        type: 'error',
        inputs: [
            { name: 'minAmountOut', internalType: 'uint256', type: 'uint256' },
            { name: 'actualAmountOut', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'MinAmountOutNotMet',
    },
    {
        type: 'error',
        inputs: [{ name: 'caller', internalType: 'address', type: 'address' }],
        name: 'NotBalancerV3Vault',
    },
    { type: 'error', inputs: [], name: 'SwapDeadline' },
];
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeRouterExactOutSwapTargetAddress = {
    8453: '0x1E6bDB824c37C26ED78981b18733bea7C8269aCF',
    31337: '0x1E6bDB824c37C26ED78981b18733bea7C8269aCF',
    11155111: '0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE',
};
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.balancerV3StandardExchangeRouterExactOutSwapTargetConfig = {
    address: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAddress,
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAbi,
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BetterPermit2
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.betterPermit2Abi = [
    {
        type: 'function',
        inputs: [],
        name: 'DOMAIN_SEPARATOR',
        outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [
            { name: '', internalType: 'address', type: 'address' },
            { name: '', internalType: 'address', type: 'address' },
            { name: '', internalType: 'address', type: 'address' },
        ],
        name: 'allowance',
        outputs: [
            { name: 'amount', internalType: 'uint160', type: 'uint160' },
            { name: 'expiration', internalType: 'uint48', type: 'uint48' },
            { name: 'nonce', internalType: 'uint48', type: 'uint48' },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [
            { name: 'token', internalType: 'address', type: 'address' },
            { name: 'spender', internalType: 'address', type: 'address' },
            { name: 'amount', internalType: 'uint160', type: 'uint160' },
            { name: 'expiration', internalType: 'uint48', type: 'uint48' },
        ],
        name: 'approve',
        outputs: [],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            { name: 'token', internalType: 'address', type: 'address' },
            { name: 'spender', internalType: 'address', type: 'address' },
            { name: 'newNonce', internalType: 'uint48', type: 'uint48' },
        ],
        name: 'invalidateNonces',
        outputs: [],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            { name: 'wordPos', internalType: 'uint256', type: 'uint256' },
            { name: 'mask', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'invalidateUnorderedNonces',
        outputs: [],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'approvals',
                internalType: 'struct IAllowanceTransfer.TokenSpenderPair[]',
                type: 'tuple[]',
                components: [
                    { name: 'token', internalType: 'address', type: 'address' },
                    { name: 'spender', internalType: 'address', type: 'address' },
                ],
            },
        ],
        name: 'lockdown',
        outputs: [],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            { name: '', internalType: 'address', type: 'address' },
            { name: '', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'nonceBitmap',
        outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [
            { name: 'owner', internalType: 'address', type: 'address' },
            {
                name: 'permitBatch',
                internalType: 'struct IAllowanceTransfer.PermitBatch',
                type: 'tuple',
                components: [
                    {
                        name: 'details',
                        internalType: 'struct IAllowanceTransfer.PermitDetails[]',
                        type: 'tuple[]',
                        components: [
                            { name: 'token', internalType: 'address', type: 'address' },
                            { name: 'amount', internalType: 'uint160', type: 'uint160' },
                            { name: 'expiration', internalType: 'uint48', type: 'uint48' },
                            { name: 'nonce', internalType: 'uint48', type: 'uint48' },
                        ],
                    },
                    { name: 'spender', internalType: 'address', type: 'address' },
                    { name: 'sigDeadline', internalType: 'uint256', type: 'uint256' },
                ],
            },
            { name: 'signature', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'permit',
        outputs: [],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            { name: 'owner', internalType: 'address', type: 'address' },
            {
                name: 'permitSingle',
                internalType: 'struct IAllowanceTransfer.PermitSingle',
                type: 'tuple',
                components: [
                    {
                        name: 'details',
                        internalType: 'struct IAllowanceTransfer.PermitDetails',
                        type: 'tuple',
                        components: [
                            { name: 'token', internalType: 'address', type: 'address' },
                            { name: 'amount', internalType: 'uint160', type: 'uint160' },
                            { name: 'expiration', internalType: 'uint48', type: 'uint48' },
                            { name: 'nonce', internalType: 'uint48', type: 'uint48' },
                        ],
                    },
                    { name: 'spender', internalType: 'address', type: 'address' },
                    { name: 'sigDeadline', internalType: 'uint256', type: 'uint256' },
                ],
            },
            { name: 'signature', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'permit',
        outputs: [],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'permit',
                internalType: 'struct ISignatureTransfer.PermitTransferFrom',
                type: 'tuple',
                components: [
                    {
                        name: 'permitted',
                        internalType: 'struct ISignatureTransfer.TokenPermissions',
                        type: 'tuple',
                        components: [
                            { name: 'token', internalType: 'address', type: 'address' },
                            { name: 'amount', internalType: 'uint256', type: 'uint256' },
                        ],
                    },
                    { name: 'nonce', internalType: 'uint256', type: 'uint256' },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                ],
            },
            {
                name: 'transferDetails',
                internalType: 'struct ISignatureTransfer.SignatureTransferDetails',
                type: 'tuple',
                components: [
                    { name: 'to', internalType: 'address', type: 'address' },
                    { name: 'requestedAmount', internalType: 'uint256', type: 'uint256' },
                ],
            },
            { name: 'owner', internalType: 'address', type: 'address' },
            { name: 'signature', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'permitTransferFrom',
        outputs: [],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'permit',
                internalType: 'struct ISignatureTransfer.PermitBatchTransferFrom',
                type: 'tuple',
                components: [
                    {
                        name: 'permitted',
                        internalType: 'struct ISignatureTransfer.TokenPermissions[]',
                        type: 'tuple[]',
                        components: [
                            { name: 'token', internalType: 'address', type: 'address' },
                            { name: 'amount', internalType: 'uint256', type: 'uint256' },
                        ],
                    },
                    { name: 'nonce', internalType: 'uint256', type: 'uint256' },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                ],
            },
            {
                name: 'transferDetails',
                internalType: 'struct ISignatureTransfer.SignatureTransferDetails[]',
                type: 'tuple[]',
                components: [
                    { name: 'to', internalType: 'address', type: 'address' },
                    { name: 'requestedAmount', internalType: 'uint256', type: 'uint256' },
                ],
            },
            { name: 'owner', internalType: 'address', type: 'address' },
            { name: 'signature', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'permitTransferFrom',
        outputs: [],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'permit',
                internalType: 'struct ISignatureTransfer.PermitTransferFrom',
                type: 'tuple',
                components: [
                    {
                        name: 'permitted',
                        internalType: 'struct ISignatureTransfer.TokenPermissions',
                        type: 'tuple',
                        components: [
                            { name: 'token', internalType: 'address', type: 'address' },
                            { name: 'amount', internalType: 'uint256', type: 'uint256' },
                        ],
                    },
                    { name: 'nonce', internalType: 'uint256', type: 'uint256' },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                ],
            },
            {
                name: 'transferDetails',
                internalType: 'struct ISignatureTransfer.SignatureTransferDetails',
                type: 'tuple',
                components: [
                    { name: 'to', internalType: 'address', type: 'address' },
                    { name: 'requestedAmount', internalType: 'uint256', type: 'uint256' },
                ],
            },
            { name: 'owner', internalType: 'address', type: 'address' },
            { name: 'witness', internalType: 'bytes32', type: 'bytes32' },
            { name: 'witnessTypeString', internalType: 'string', type: 'string' },
            { name: 'signature', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'permitWitnessTransferFrom',
        outputs: [],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'permit',
                internalType: 'struct ISignatureTransfer.PermitBatchTransferFrom',
                type: 'tuple',
                components: [
                    {
                        name: 'permitted',
                        internalType: 'struct ISignatureTransfer.TokenPermissions[]',
                        type: 'tuple[]',
                        components: [
                            { name: 'token', internalType: 'address', type: 'address' },
                            { name: 'amount', internalType: 'uint256', type: 'uint256' },
                        ],
                    },
                    { name: 'nonce', internalType: 'uint256', type: 'uint256' },
                    { name: 'deadline', internalType: 'uint256', type: 'uint256' },
                ],
            },
            {
                name: 'transferDetails',
                internalType: 'struct ISignatureTransfer.SignatureTransferDetails[]',
                type: 'tuple[]',
                components: [
                    { name: 'to', internalType: 'address', type: 'address' },
                    { name: 'requestedAmount', internalType: 'uint256', type: 'uint256' },
                ],
            },
            { name: 'owner', internalType: 'address', type: 'address' },
            { name: 'witness', internalType: 'bytes32', type: 'bytes32' },
            { name: 'witnessTypeString', internalType: 'string', type: 'string' },
            { name: 'signature', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'permitWitnessTransferFrom',
        outputs: [],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'transferDetails',
                internalType: 'struct IAllowanceTransfer.AllowanceTransferDetails[]',
                type: 'tuple[]',
                components: [
                    { name: 'from', internalType: 'address', type: 'address' },
                    { name: 'to', internalType: 'address', type: 'address' },
                    { name: 'amount', internalType: 'uint160', type: 'uint160' },
                    { name: 'token', internalType: 'address', type: 'address' },
                ],
            },
        ],
        name: 'transferFrom',
        outputs: [],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            { name: 'from', internalType: 'address', type: 'address' },
            { name: 'to', internalType: 'address', type: 'address' },
            { name: 'amount', internalType: 'uint160', type: 'uint160' },
            { name: 'token', internalType: 'address', type: 'address' },
        ],
        name: 'transferFrom',
        outputs: [],
        stateMutability: 'nonpayable',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'owner',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'token',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'spender',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'amount',
                internalType: 'uint160',
                type: 'uint160',
                indexed: false,
            },
            {
                name: 'expiration',
                internalType: 'uint48',
                type: 'uint48',
                indexed: false,
            },
        ],
        name: 'Approval',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'owner',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'token',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: 'spender',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
        ],
        name: 'Lockdown',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'owner',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'token',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'spender',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'newNonce',
                internalType: 'uint48',
                type: 'uint48',
                indexed: false,
            },
            {
                name: 'oldNonce',
                internalType: 'uint48',
                type: 'uint48',
                indexed: false,
            },
        ],
        name: 'NonceInvalidation',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'owner',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'token',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'spender',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'amount',
                internalType: 'uint160',
                type: 'uint160',
                indexed: false,
            },
            {
                name: 'expiration',
                internalType: 'uint48',
                type: 'uint48',
                indexed: false,
            },
            { name: 'nonce', internalType: 'uint48', type: 'uint48', indexed: false },
        ],
        name: 'Permit',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'owner',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'word',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
            {
                name: 'mask',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
        ],
        name: 'UnorderedNonceInvalidation',
    },
    {
        type: 'error',
        inputs: [{ name: 'deadline', internalType: 'uint256', type: 'uint256' }],
        name: 'AllowanceExpired',
    },
    { type: 'error', inputs: [], name: 'ExcessiveInvalidation' },
    {
        type: 'error',
        inputs: [{ name: 'amount', internalType: 'uint256', type: 'uint256' }],
        name: 'InsufficientAllowance',
    },
    {
        type: 'error',
        inputs: [{ name: 'maxAmount', internalType: 'uint256', type: 'uint256' }],
        name: 'InvalidAmount',
    },
    { type: 'error', inputs: [], name: 'InvalidContractSignature' },
    { type: 'error', inputs: [], name: 'InvalidNonce' },
    { type: 'error', inputs: [], name: 'InvalidSignature' },
    { type: 'error', inputs: [], name: 'InvalidSignatureLength' },
    { type: 'error', inputs: [], name: 'InvalidSigner' },
    { type: 'error', inputs: [], name: 'LengthMismatch' },
    {
        type: 'error',
        inputs: [
            { name: 'signatureDeadline', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'SignatureExpired',
    },
];
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.betterPermit2Address = {
    8453: '0x000000000022D473030F116dDEE9F6B43aC78BA3',
    31337: '0x000000000022D473030F116dDEE9F6B43aC78BA3',
    11155111: '0x000000000022D473030F116dDEE9F6B43aC78BA3',
};
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.betterPermit2Config = {
    address: exports.betterPermit2Address,
    abi: exports.betterPermit2Abi,
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// DiamondPackageCallBackFactory
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.diamondPackageCallBackFactoryAbi = [
    {
        type: 'constructor',
        inputs: [
            {
                name: 'init',
                internalType: 'struct IDiamondPackageCallBackFactoryInit.InitArgs',
                type: 'tuple',
                components: [
                    {
                        name: 'erc165Facet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                    {
                        name: 'diamondLoupeFacet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                    {
                        name: 'erc8109IntrospectionFacet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                    {
                        name: 'postDeployHookFacet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                ],
            },
        ],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [],
        name: 'DIAMOND_LOUPE_FACET',
        outputs: [{ name: '', internalType: 'contract IFacet', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'ERC165_FACET',
        outputs: [{ name: '', internalType: 'contract IFacet', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'ERC8109_INTROSPECTION_FACET',
        outputs: [{ name: '', internalType: 'contract IFacet', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'POST_DEPLOY_HOOK_FACET',
        outputs: [{ name: '', internalType: 'contract IFacet', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'PROXY_INIT_HASH',
        outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'pkg',
                internalType: 'contract IDiamondFactoryPackage',
                type: 'address',
            },
            { name: 'pkgArgs', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'calcAddress',
        outputs: [{ name: '', internalType: 'address', type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'pkg',
                internalType: 'contract IDiamondFactoryPackage',
                type: 'address',
            },
            { name: 'pkgArgs', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'deploy',
        outputs: [{ name: 'proxy', internalType: 'address', type: 'address' }],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [],
        name: 'erc8109Funcs',
        outputs: [{ name: 'funcs', internalType: 'bytes4[]', type: 'bytes4[]' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetCuts',
        outputs: [
            {
                name: 'facetCuts_',
                internalType: 'struct IDiamond.FacetCut[]',
                type: 'tuple[]',
                components: [
                    { name: 'facetAddress', internalType: 'address', type: 'address' },
                    {
                        name: 'action',
                        internalType: 'enum IDiamond.FacetCutAction',
                        type: 'uint8',
                    },
                    {
                        name: 'functionSelectors',
                        internalType: 'bytes4[]',
                        type: 'bytes4[]',
                    },
                ],
            },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetInterfaces',
        outputs: [
            { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'initAccount',
        outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'pkg',
                internalType: 'contract IDiamondFactoryPackage',
                type: 'address',
            },
            { name: 'pkgArgs', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'initAccount',
        outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
        name: 'pkgArgsOfAccount',
        outputs: [{ name: 'pkgArgs', internalType: 'bytes', type: 'bytes' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'pkgConfig',
        outputs: [
            {
                name: 'pkg',
                internalType: 'contract IDiamondFactoryPackage',
                type: 'address',
            },
            { name: 'args', internalType: 'bytes', type: 'bytes' },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
        name: 'pkgOfAccount',
        outputs: [
            {
                name: 'pkg',
                internalType: 'contract IDiamondFactoryPackage',
                type: 'address',
            },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [{ name: '', internalType: 'address', type: 'address' }],
        name: 'postDeploy',
        outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [],
        name: 'postDeployFacetCuts',
        outputs: [
            {
                name: 'facetCuts_',
                internalType: 'struct IDiamond.FacetCut[]',
                type: 'tuple[]',
                components: [
                    { name: 'facetAddress', internalType: 'address', type: 'address' },
                    {
                        name: 'action',
                        internalType: 'enum IDiamond.FacetCutAction',
                        type: 'uint8',
                    },
                    {
                        name: 'functionSelectors',
                        internalType: 'bytes4[]',
                        type: 'bytes4[]',
                    },
                ],
            },
        ],
        stateMutability: 'view',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: '_diamondCut',
                internalType: 'struct IDiamond.FacetCut[]',
                type: 'tuple[]',
                components: [
                    { name: 'facetAddress', internalType: 'address', type: 'address' },
                    {
                        name: 'action',
                        internalType: 'enum IDiamond.FacetCutAction',
                        type: 'uint8',
                    },
                    {
                        name: 'functionSelectors',
                        internalType: 'bytes4[]',
                        type: 'bytes4[]',
                    },
                ],
                indexed: false,
            },
            {
                name: '_init',
                internalType: 'address',
                type: 'address',
                indexed: false,
            },
            {
                name: '_calldata',
                internalType: 'bytes',
                type: 'bytes',
                indexed: false,
            },
        ],
        name: 'DiamondCut',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: '_selector',
                internalType: 'bytes4',
                type: 'bytes4',
                indexed: true,
            },
            {
                name: '_oldFacet',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
        ],
        name: 'DiamondFunctionRemoved',
    },
    {
        type: 'error',
        inputs: [{ name: 'target', internalType: 'address', type: 'address' }],
        name: 'AddressEmptyCode',
    },
    {
        type: 'error',
        inputs: [
            { name: 'expected', internalType: 'address', type: 'address' },
            { name: 'actual', internalType: 'address', type: 'address' },
        ],
        name: 'DeploymentAddressMismatch',
    },
    {
        type: 'error',
        inputs: [{ name: 'facet', internalType: 'address', type: 'address' }],
        name: 'FacetAlreadyPresent',
    },
    { type: 'error', inputs: [], name: 'FailedCall' },
    {
        type: 'error',
        inputs: [
            { name: 'functionSelector', internalType: 'bytes4', type: 'bytes4' },
        ],
        name: 'FunctionAlreadyPresent',
    },
    {
        type: 'error',
        inputs: [
            { name: 'functionSelector', internalType: 'bytes4', type: 'bytes4' },
        ],
        name: 'FunctionNotPresent',
    },
    {
        type: 'error',
        inputs: [
            { name: 'functionSelector', internalType: 'bytes4', type: 'bytes4' },
            { name: 'expectedFacet', internalType: 'address', type: 'address' },
            { name: 'actualFacet', internalType: 'address', type: 'address' },
        ],
        name: 'SelectorFacetMismatch',
    },
];
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.diamondPackageCallBackFactoryAddress = {
    8453: '0xC13e24A53912EAc22fA826536f0C1520A248e4E6',
    31337: '0xC13e24A53912EAc22fA826536f0C1520A248e4E6',
    11155111: '0x0000000000000000000000000000000000000000',
};
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.diamondPackageCallBackFactoryConfig = {
    address: exports.diamondPackageCallBackFactoryAddress,
    abi: exports.diamondPackageCallBackFactoryAbi,
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// UniswapV2StandardExchangeDFPkg
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.uniswapV2StandardExchangeDfPkgAbi = [
    {
        type: 'constructor',
        inputs: [
            {
                name: 'pkgInit',
                internalType: 'struct IUniswapV2StandardExchangeDFPkg.PkgInit',
                type: 'tuple',
                components: [
                    {
                        name: 'erc20Facet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                    {
                        name: 'erc5267Facet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                    {
                        name: 'erc2612Facet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                    {
                        name: 'erc4626Facet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                    {
                        name: 'erc4626BasicVaultFacet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                    {
                        name: 'erc4626StandardVaultFacet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                    {
                        name: 'uniswapV2StandardExchangeInFacet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                    {
                        name: 'uniswapV2StandardExchangeOutFacet',
                        internalType: 'contract IFacet',
                        type: 'address',
                    },
                    {
                        name: 'vaultFeeOracleQuery',
                        internalType: 'contract IVaultFeeOracleQuery',
                        type: 'address',
                    },
                    {
                        name: 'vaultRegistryDeployment',
                        internalType: 'contract IVaultRegistryDeployment',
                        type: 'address',
                    },
                    {
                        name: 'permit2',
                        internalType: 'contract IPermit2',
                        type: 'address',
                    },
                    {
                        name: 'uniswapV2Factory',
                        internalType: 'contract IUniswapV2Factory',
                        type: 'address',
                    },
                    {
                        name: 'uniswapV2Router',
                        internalType: 'contract IUniswapV2Router',
                        type: 'address',
                    },
                ],
            },
        ],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [{ name: 'pkgArgs', internalType: 'bytes', type: 'bytes' }],
        name: 'calcSalt',
        outputs: [{ name: 'salt', internalType: 'bytes32', type: 'bytes32' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'pool',
                internalType: 'contract IUniswapV2Pair',
                type: 'address',
            },
        ],
        name: 'deployVault',
        outputs: [{ name: 'vault', internalType: 'address', type: 'address' }],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            { name: 'tokenA', internalType: 'contract IERC20', type: 'address' },
            { name: 'tokenAAmount', internalType: 'uint256', type: 'uint256' },
            { name: 'tokenB', internalType: 'contract IERC20', type: 'address' },
            { name: 'tokenBAmount', internalType: 'uint256', type: 'uint256' },
            { name: 'recipient', internalType: 'address', type: 'address' },
        ],
        name: 'deployVault',
        outputs: [{ name: 'vault', internalType: 'address', type: 'address' }],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [],
        name: 'diamondConfig',
        outputs: [
            {
                name: 'config',
                internalType: 'struct IDiamondFactoryPackage.DiamondConfig',
                type: 'tuple',
                components: [
                    {
                        name: 'facetCuts',
                        internalType: 'struct IDiamond.FacetCut[]',
                        type: 'tuple[]',
                        components: [
                            {
                                name: 'facetAddress',
                                internalType: 'address',
                                type: 'address',
                            },
                            {
                                name: 'action',
                                internalType: 'enum IDiamond.FacetCutAction',
                                type: 'uint8',
                            },
                            {
                                name: 'functionSelectors',
                                internalType: 'bytes4[]',
                                type: 'bytes4[]',
                            },
                        ],
                    },
                    { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
                ],
            },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetAddresses',
        outputs: [
            { name: 'facetAddresses_', internalType: 'address[]', type: 'address[]' },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetCuts',
        outputs: [
            {
                name: 'facetCuts_',
                internalType: 'struct IDiamond.FacetCut[]',
                type: 'tuple[]',
                components: [
                    { name: 'facetAddress', internalType: 'address', type: 'address' },
                    {
                        name: 'action',
                        internalType: 'enum IDiamond.FacetCutAction',
                        type: 'uint8',
                    },
                    {
                        name: 'functionSelectors',
                        internalType: 'bytes4[]',
                        type: 'bytes4[]',
                    },
                ],
            },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetInterfaces',
        outputs: [
            { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [{ name: 'initArgs', internalType: 'bytes', type: 'bytes' }],
        name: 'initAccount',
        outputs: [],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [],
        name: 'name',
        outputs: [{ name: '', internalType: 'string', type: 'string' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'packageMetadata',
        outputs: [
            { name: 'name_', internalType: 'string', type: 'string' },
            { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
            { name: 'facets', internalType: 'address[]', type: 'address[]' },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'packageName',
        outputs: [{ name: 'name_', internalType: 'string', type: 'string' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [{ name: '', internalType: 'address', type: 'address' }],
        name: 'postDeploy',
        outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [
            { name: 'tokenA', internalType: 'contract IERC20', type: 'address' },
            { name: 'tokenAAmount', internalType: 'uint256', type: 'uint256' },
            { name: 'tokenB', internalType: 'contract IERC20', type: 'address' },
            { name: 'tokenBAmount', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'previewDeployVault',
        outputs: [
            {
                name: 'result',
                internalType: 'struct IUniswapV2StandardExchangeDFPkg.DeployWithPoolResult',
                type: 'tuple',
                components: [
                    { name: 'pairExists', internalType: 'bool', type: 'bool' },
                    { name: 'proportionalA', internalType: 'uint256', type: 'uint256' },
                    { name: 'proportionalB', internalType: 'uint256', type: 'uint256' },
                    { name: 'expectedLP', internalType: 'uint256', type: 'uint256' },
                ],
            },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [{ name: 'pkgArgs', internalType: 'bytes', type: 'bytes' }],
        name: 'processArgs',
        outputs: [
            { name: 'processedPkgArgs', internalType: 'bytes', type: 'bytes' },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [
            { name: '', internalType: 'address', type: 'address' },
            { name: '', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'updatePkg',
        outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'vaultDeclaration',
        outputs: [
            {
                name: 'declaration',
                internalType: 'struct IStandardVaultPkg.VaultPkgDeclaration',
                type: 'tuple',
                components: [
                    { name: 'name', internalType: 'string', type: 'string' },
                    { name: 'vaultFeeTypeIds', internalType: 'bytes32', type: 'bytes32' },
                    { name: 'vaultTypes', internalType: 'bytes4[]', type: 'bytes4[]' },
                ],
            },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'vaultFeeTypeIds',
        outputs: [
            { name: 'vaultFeeTypeIds_', internalType: 'bytes32', type: 'bytes32' },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'vaultTypes',
        outputs: [{ name: 'typeIDs', internalType: 'bytes4[]', type: 'bytes4[]' }],
        stateMutability: 'pure',
    },
    {
        type: 'error',
        inputs: [
            { name: 'length', internalType: 'uint256', type: 'uint256' },
            { name: 'invalidIndex', internalType: 'uint256', type: 'uint256' },
            { name: 'errorCode', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'IndexOutOfBounds',
    },
    {
        type: 'error',
        inputs: [{ name: 'caller', internalType: 'address', type: 'address' }],
        name: 'NotCalledByRegistry',
    },
    { type: 'error', inputs: [], name: 'PairCreationFailed' },
    { type: 'error', inputs: [], name: 'RecipientRequiredForDeposit' },
    {
        type: 'error',
        inputs: [{ name: 'str', internalType: 'string', type: 'string' }],
        name: 'StringTooLong',
    },
];
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.uniswapV2StandardExchangeDfPkgAddress = {
    8453: '0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F',
    31337: '0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F',
    11155111: '0x0000000000000000000000000000000000000000',
};
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.uniswapV2StandardExchangeDfPkgConfig = {
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// VaultRegistryDeploymentFacet
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.vaultRegistryDeploymentFacetAbi = [
    {
        type: 'function',
        inputs: [
            { name: 'initCode', internalType: 'bytes', type: 'bytes' },
            { name: 'initArgs', internalType: 'bytes', type: 'bytes' },
            { name: 'salt', internalType: 'bytes32', type: 'bytes32' },
        ],
        name: 'deployPkg',
        outputs: [{ name: 'pkg', internalType: 'address', type: 'address' }],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            {
                name: 'pkg',
                internalType: 'contract IStandardVaultPkg',
                type: 'address',
            },
            { name: 'pkgArgs', internalType: 'bytes', type: 'bytes' },
        ],
        name: 'deployVault',
        outputs: [{ name: 'vault', internalType: 'address', type: 'address' }],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetFuncs',
        outputs: [
            { name: 'selectors', internalType: 'bytes4[]', type: 'bytes4[]' },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetInterfaces',
        outputs: [
            { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetMetadata',
        outputs: [
            { name: 'name', internalType: 'string', type: 'string' },
            { name: 'interfaces', internalType: 'bytes4[]', type: 'bytes4[]' },
            { name: 'functions', internalType: 'bytes4[]', type: 'bytes4[]' },
        ],
        stateMutability: 'pure',
    },
    {
        type: 'function',
        inputs: [],
        name: 'facetName',
        outputs: [{ name: 'name', internalType: 'string', type: 'string' }],
        stateMutability: 'pure',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'package',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            { name: 'name', internalType: 'string', type: 'string', indexed: true },
            {
                name: 'vaultFeeTypeIds',
                internalType: 'bytes32',
                type: 'bytes32',
                indexed: true,
            },
            {
                name: 'vaultTypes',
                internalType: 'bytes4[]',
                type: 'bytes4[]',
                indexed: false,
            },
        ],
        name: 'NewPackage',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'package',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'vaultType',
                internalType: 'bytes4',
                type: 'bytes4',
                indexed: true,
            },
        ],
        name: 'NewPackageOfType',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'vault',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'package',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'vaultFeeIds',
                internalType: 'bytes32',
                type: 'bytes32',
                indexed: false,
            },
            {
                name: 'contentsId',
                internalType: 'bytes32',
                type: 'bytes32',
                indexed: true,
            },
            {
                name: 'vaultTypes',
                internalType: 'bytes4[]',
                type: 'bytes4[]',
                indexed: false,
            },
            {
                name: 'tokens',
                internalType: 'address[]',
                type: 'address[]',
                indexed: false,
            },
        ],
        name: 'NewVault',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'vault',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'package',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'token',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
        ],
        name: 'NewVaultOfToken',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'vault',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'package',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'vaultType',
                internalType: 'bytes4',
                type: 'bytes4',
                indexed: true,
            },
        ],
        name: 'NewVaultOfType',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'package',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
        ],
        name: 'PackageRemoved',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'vault',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
        ],
        name: 'VaultRemoved',
    },
    {
        type: 'error',
        inputs: [
            { name: 'length', internalType: 'uint256', type: 'uint256' },
            { name: 'invalidIndex', internalType: 'uint256', type: 'uint256' },
            { name: 'errorCode', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'IndexOutOfBounds',
    },
    {
        type: 'error',
        inputs: [{ name: 'caller', internalType: 'address', type: 'address' }],
        name: 'NotOperator',
    },
    {
        type: 'error',
        inputs: [{ name: 'pkg', internalType: 'address', type: 'address' }],
        name: 'PkgNotRegistered',
    },
];
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.vaultRegistryDeploymentFacetAddress = {
    8453: '0x37740814F2790936296c9503Ca9750666F950d19',
    31337: '0x37740814F2790936296c9503Ca9750666F950d19',
    11155111: '0xBe3Edd7BD00f3c609e444C7dE7739E7718498426',
};
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.vaultRegistryDeploymentFacetConfig = {
    address: exports.vaultRegistryDeploymentFacetAddress,
    abi: exports.vaultRegistryDeploymentFacetAbi,
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// WETH9
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.weth9Abi = [
    { type: 'fallback', stateMutability: 'payable' },
    { type: 'receive', stateMutability: 'payable' },
    {
        type: 'function',
        inputs: [
            { name: '', internalType: 'address', type: 'address' },
            { name: '', internalType: 'address', type: 'address' },
        ],
        name: 'allowance',
        outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [
            { name: 'guy', internalType: 'address', type: 'address' },
            { name: 'wad', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'approve',
        outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [{ name: '', internalType: 'address', type: 'address' }],
        name: 'balanceOf',
        outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'decimals',
        outputs: [{ name: '', internalType: 'uint8', type: 'uint8' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'deposit',
        outputs: [],
        stateMutability: 'payable',
    },
    {
        type: 'function',
        inputs: [],
        name: 'name',
        outputs: [{ name: '', internalType: 'string', type: 'string' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'symbol',
        outputs: [{ name: '', internalType: 'string', type: 'string' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [],
        name: 'totalSupply',
        outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        inputs: [
            { name: 'dst', internalType: 'address', type: 'address' },
            { name: 'wad', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'transfer',
        outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [
            { name: 'src', internalType: 'address', type: 'address' },
            { name: 'dst', internalType: 'address', type: 'address' },
            { name: 'wad', internalType: 'uint256', type: 'uint256' },
        ],
        name: 'transferFrom',
        outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
        stateMutability: 'nonpayable',
    },
    {
        type: 'function',
        inputs: [{ name: 'wad', internalType: 'uint256', type: 'uint256' }],
        name: 'withdraw',
        outputs: [],
        stateMutability: 'nonpayable',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            {
                name: 'owner',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'spender',
                internalType: 'address',
                type: 'address',
                indexed: true,
            },
            {
                name: 'amount',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
        ],
        name: 'Approval',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            { name: 'dst', internalType: 'address', type: 'address', indexed: true },
            { name: 'wad', internalType: 'uint256', type: 'uint256', indexed: false },
        ],
        name: 'Deposit',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            { name: 'from', internalType: 'address', type: 'address', indexed: true },
            { name: 'to', internalType: 'address', type: 'address', indexed: true },
            {
                name: 'amount',
                internalType: 'uint256',
                type: 'uint256',
                indexed: false,
            },
        ],
        name: 'Transfer',
    },
    {
        type: 'event',
        anonymous: false,
        inputs: [
            { name: 'src', internalType: 'address', type: 'address', indexed: true },
            { name: 'wad', internalType: 'uint256', type: 'uint256', indexed: false },
        ],
        name: 'Withdrawal',
    },
];
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.weth9Address = {
    8453: '0x4200000000000000000000000000000000000006',
    31337: '0x4200000000000000000000000000000000000006',
    11155111: '0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9',
};
/**
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.weth9Config = { address: exports.weth9Address, abi: exports.weth9Abi };
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// React
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkg = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"BALANCER_V3_AUTHENTICATION_FACET"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgBalancerV3AuthenticationFacet = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'BALANCER_V3_AUTHENTICATION_FACET',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"BALANCER_V3_CONST_PROD_POOL_FACET"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgBalancerV3ConstProdPoolFacet = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'BALANCER_V3_CONST_PROD_POOL_FACET',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"BALANCER_V3_VAULT"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgBalancerV3Vault = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'BALANCER_V3_VAULT',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"BALANCER_V3_VAULT_AWARE_FACET"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgBalancerV3VaultAwareFacet = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'BALANCER_V3_VAULT_AWARE_FACET',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"BASIC_VAULT_FACET"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgBasicVaultFacet = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'BASIC_VAULT_FACET',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"BETTER_BALANCER_V3_POOL_TOKEN_FACET"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgBetterBalancerV3PoolTokenFacet = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'BETTER_BALANCER_V3_POOL_TOKEN_FACET',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"DEFAULT_POOL_INFO_FACET"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgDefaultPoolInfoFacet = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'DEFAULT_POOL_INFO_FACET',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"DIAMOND_PACKAGE_FACTORY"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgDiamondPackageFactory = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'DIAMOND_PACKAGE_FACTORY',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"SELF"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgSelf = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'SELF',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"STANDARD_SWAP_FEE_PERCENTAGE_BOUNDS_FACET"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgStandardSwapFeePercentageBoundsFacet = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'STANDARD_SWAP_FEE_PERCENTAGE_BOUNDS_FACET',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"STANDARD_VAULT_FACET"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgStandardVaultFacet = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'STANDARD_VAULT_FACET',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"UNBALANCED_LIQUIDITY_INVARIANT_RATIO_BOUNDS_FACET"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgUnbalancedLiquidityInvariantRatioBoundsFacet = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'UNBALANCED_LIQUIDITY_INVARIANT_RATIO_BOUNDS_FACET',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"VAULT_FEE_ORACLE"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgVaultFeeOracle = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'VAULT_FEE_ORACLE',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"VAULT_REGISTRY"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgVaultRegistry = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'VAULT_REGISTRY',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"calcSalt"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgCalcSalt = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'calcSalt',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"constantProductMarkerFunction"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgConstantProductMarkerFunction = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'constantProductMarkerFunction',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"diamondConfig"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgDiamondConfig = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'diamondConfig',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"facetAddresses"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgFacetAddresses = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'facetAddresses',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"facetCuts"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgFacetCuts = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'facetCuts',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"facetInterfaces"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgFacetInterfaces = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'facetInterfaces',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"getActionId"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgGetActionId = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'getActionId',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"getDeploymentAddress"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgGetDeploymentAddress = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'getDeploymentAddress',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"getNewPoolPauseWindowEndTime"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgGetNewPoolPauseWindowEndTime = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'getNewPoolPauseWindowEndTime',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"getOriginalPauseWindowEndTime"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgGetOriginalPauseWindowEndTime = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'getOriginalPauseWindowEndTime',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"getPauseWindowDuration"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgGetPauseWindowDuration = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'getPauseWindowDuration',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"getPoolCount"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgGetPoolCount = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'getPoolCount',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"getPools"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgGetPools = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'getPools',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"getPoolsInRange"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgGetPoolsInRange = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'getPoolsInRange',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"isDisabled"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgIsDisabled = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'isDisabled',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"isPoolFromFactory"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgIsPoolFromFactory = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'isPoolFromFactory',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"name"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgName = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'name',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"packageMetadata"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgPackageMetadata = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'packageMetadata',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"packageName"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgPackageName = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'packageName',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"processArgs"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgProcessArgs = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'processArgs',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"tokenConfigs"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgTokenConfigs = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'tokenConfigs',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"vaultDeclaration"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgVaultDeclaration = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'vaultDeclaration',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"vaultFeeTypeIds"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgVaultFeeTypeIds = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'vaultFeeTypeIds',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"vaultTypes"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useReadBalancerV3ConstantProductPoolStandardVaultPkgVaultTypes = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'vaultTypes',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useWriteBalancerV3ConstantProductPoolStandardVaultPkg = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"deployVault"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useWriteBalancerV3ConstantProductPoolStandardVaultPkgDeployVault = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'deployVault',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"disable"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useWriteBalancerV3ConstantProductPoolStandardVaultPkgDisable = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'disable',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"initAccount"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useWriteBalancerV3ConstantProductPoolStandardVaultPkgInitAccount = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'initAccount',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"postDeploy"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useWriteBalancerV3ConstantProductPoolStandardVaultPkgPostDeploy = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'postDeploy',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"updatePkg"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useWriteBalancerV3ConstantProductPoolStandardVaultPkgUpdatePkg = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'updatePkg',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useSimulateBalancerV3ConstantProductPoolStandardVaultPkg = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"deployVault"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useSimulateBalancerV3ConstantProductPoolStandardVaultPkgDeployVault = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'deployVault',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"disable"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useSimulateBalancerV3ConstantProductPoolStandardVaultPkgDisable = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'disable',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"initAccount"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useSimulateBalancerV3ConstantProductPoolStandardVaultPkgInitAccount = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'initAccount',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"postDeploy"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useSimulateBalancerV3ConstantProductPoolStandardVaultPkgPostDeploy = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'postDeploy',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `functionName` set to `"updatePkg"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useSimulateBalancerV3ConstantProductPoolStandardVaultPkgUpdatePkg = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    functionName: 'updatePkg',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useWatchBalancerV3ConstantProductPoolStandardVaultPkgEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `eventName` set to `"FactoryDisabled"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useWatchBalancerV3ConstantProductPoolStandardVaultPkgFactoryDisabledEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    eventName: 'FactoryDisabled',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3ConstantProductPoolStandardVaultPkgAbi}__ and `eventName` set to `"PoolCreated"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC7d1faB5B4c7fd19e4Fc9FCd62536d514E757544)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x858253aD4458680E93ee88EFCf520cD7054bC145)
 */
exports.useWatchBalancerV3ConstantProductPoolStandardVaultPkgPoolCreatedEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3ConstantProductPoolStandardVaultPkgAbi,
    address: exports.balancerV3ConstantProductPoolStandardVaultPkgAddress,
    eventName: 'PoolCreated',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeBatchRouterExactInFacet = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__ and `functionName` set to `"facetFuncs"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeBatchRouterExactInFacetFacetFuncs = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
    functionName: 'facetFuncs',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__ and `functionName` set to `"facetInterfaces"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeBatchRouterExactInFacetFacetInterfaces = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
    functionName: 'facetInterfaces',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__ and `functionName` set to `"facetMetadata"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeBatchRouterExactInFacetFacetMetadata = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
    functionName: 'facetMetadata',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__ and `functionName` set to `"facetName"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeBatchRouterExactInFacetFacetName = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
    functionName: 'facetName',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__ and `functionName` set to `"getSender"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeBatchRouterExactInFacetGetSender = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
    functionName: 'getSender',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeBatchRouterExactInFacet = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__ and `functionName` set to `"querySwapExactIn"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeBatchRouterExactInFacetQuerySwapExactIn = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
    functionName: 'querySwapExactIn',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__ and `functionName` set to `"querySwapExactInHook"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeBatchRouterExactInFacetQuerySwapExactInHook = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
    functionName: 'querySwapExactInHook',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__ and `functionName` set to `"swapExactIn"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeBatchRouterExactInFacetSwapExactIn = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
    functionName: 'swapExactIn',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__ and `functionName` set to `"swapExactInHook"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeBatchRouterExactInFacetSwapExactInHook = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
    functionName: 'swapExactInHook',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__ and `functionName` set to `"swapExactInWithPermit"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeBatchRouterExactInFacetSwapExactInWithPermit = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
    functionName: 'swapExactInWithPermit',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeBatchRouterExactInFacet = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__ and `functionName` set to `"querySwapExactIn"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeBatchRouterExactInFacetQuerySwapExactIn = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
    functionName: 'querySwapExactIn',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__ and `functionName` set to `"querySwapExactInHook"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeBatchRouterExactInFacetQuerySwapExactInHook = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
    functionName: 'querySwapExactInHook',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__ and `functionName` set to `"swapExactIn"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeBatchRouterExactInFacetSwapExactIn = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
    functionName: 'swapExactIn',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__ and `functionName` set to `"swapExactInHook"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeBatchRouterExactInFacetSwapExactInHook = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
    functionName: 'swapExactInHook',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__ and `functionName` set to `"swapExactInWithPermit"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeBatchRouterExactInFacetSwapExactInWithPermit = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
    functionName: 'swapExactInWithPermit',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeBatchRouterExactInFacetEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__ and `eventName` set to `"StrategyVaultExchangeIn"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeBatchRouterExactInFacetStrategyVaultExchangeInEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
    eventName: 'StrategyVaultExchangeIn',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__ and `eventName` set to `"SwapHookParamsDebug"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeBatchRouterExactInFacetSwapHookParamsDebugEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
    eventName: 'SwapHookParamsDebug',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactInFacetAbi}__ and `eventName` set to `"WethSentinelDebug"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeBatchRouterExactInFacetWethSentinelDebugEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactInFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactInFacetAddress,
    eventName: 'WethSentinelDebug',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeBatchRouterExactOutFacet = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__ and `functionName` set to `"facetFuncs"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeBatchRouterExactOutFacetFacetFuncs = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
    functionName: 'facetFuncs',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__ and `functionName` set to `"facetInterfaces"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeBatchRouterExactOutFacetFacetInterfaces = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
    functionName: 'facetInterfaces',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__ and `functionName` set to `"facetMetadata"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeBatchRouterExactOutFacetFacetMetadata = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
    functionName: 'facetMetadata',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__ and `functionName` set to `"facetName"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeBatchRouterExactOutFacetFacetName = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
    functionName: 'facetName',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__ and `functionName` set to `"getSender"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeBatchRouterExactOutFacetGetSender = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
    functionName: 'getSender',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeBatchRouterExactOutFacet = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__ and `functionName` set to `"querySwapExactOut"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeBatchRouterExactOutFacetQuerySwapExactOut = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
    functionName: 'querySwapExactOut',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__ and `functionName` set to `"querySwapExactOutHook"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeBatchRouterExactOutFacetQuerySwapExactOutHook = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
    functionName: 'querySwapExactOutHook',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__ and `functionName` set to `"swapExactOut"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeBatchRouterExactOutFacetSwapExactOut = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
    functionName: 'swapExactOut',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__ and `functionName` set to `"swapExactOutHook"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeBatchRouterExactOutFacetSwapExactOutHook = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
    functionName: 'swapExactOutHook',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__ and `functionName` set to `"swapExactOutWithPermit"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeBatchRouterExactOutFacetSwapExactOutWithPermit = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
    functionName: 'swapExactOutWithPermit',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeBatchRouterExactOutFacet = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__ and `functionName` set to `"querySwapExactOut"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeBatchRouterExactOutFacetQuerySwapExactOut = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
    functionName: 'querySwapExactOut',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__ and `functionName` set to `"querySwapExactOutHook"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeBatchRouterExactOutFacetQuerySwapExactOutHook = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
    functionName: 'querySwapExactOutHook',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__ and `functionName` set to `"swapExactOut"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeBatchRouterExactOutFacetSwapExactOut = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
    functionName: 'swapExactOut',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__ and `functionName` set to `"swapExactOutHook"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeBatchRouterExactOutFacetSwapExactOutHook = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
    functionName: 'swapExactOutHook',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__ and `functionName` set to `"swapExactOutWithPermit"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeBatchRouterExactOutFacetSwapExactOutWithPermit = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
    functionName: 'swapExactOutWithPermit',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeBatchRouterExactOutFacetEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__ and `eventName` set to `"StrategyVaultExchangeOut"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeBatchRouterExactOutFacetStrategyVaultExchangeOutEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
    eventName: 'StrategyVaultExchangeOut',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__ and `eventName` set to `"SwapHookParamsDebug"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeBatchRouterExactOutFacetSwapHookParamsDebugEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
    eventName: 'SwapHookParamsDebug',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeBatchRouterExactOutFacetAbi}__ and `eventName` set to `"WethSentinelDebug"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeBatchRouterExactOutFacetWethSentinelDebugEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAbi,
    address: exports.balancerV3StandardExchangeBatchRouterExactOutFacetAddress,
    eventName: 'WethSentinelDebug',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInQueryFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactInQueryFacet = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInQueryFacetAddress,
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInQueryFacetAbi}__ and `functionName` set to `"facetFuncs"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactInQueryFacetFacetFuncs = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInQueryFacetAddress,
    functionName: 'facetFuncs',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInQueryFacetAbi}__ and `functionName` set to `"facetInterfaces"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactInQueryFacetFacetInterfaces = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInQueryFacetAddress,
    functionName: 'facetInterfaces',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInQueryFacetAbi}__ and `functionName` set to `"facetMetadata"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactInQueryFacetFacetMetadata = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInQueryFacetAddress,
    functionName: 'facetMetadata',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInQueryFacetAbi}__ and `functionName` set to `"facetName"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactInQueryFacetFacetName = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInQueryFacetAddress,
    functionName: 'facetName',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInQueryFacetAbi}__ and `functionName` set to `"getSender"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactInQueryFacetGetSender = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInQueryFacetAddress,
    functionName: 'getSender',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInQueryFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactInQueryFacet = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInQueryFacetAddress,
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInQueryFacetAbi}__ and `functionName` set to `"querySwapSingleTokenExactIn"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactInQueryFacetQuerySwapSingleTokenExactIn = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInQueryFacetAddress,
    functionName: 'querySwapSingleTokenExactIn',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInQueryFacetAbi}__ and `functionName` set to `"querySwapSingleTokenExactInHook"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactInQueryFacetQuerySwapSingleTokenExactInHook = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInQueryFacetAddress,
    functionName: 'querySwapSingleTokenExactInHook',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInQueryFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactInQueryFacet = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInQueryFacetAddress,
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInQueryFacetAbi}__ and `functionName` set to `"querySwapSingleTokenExactIn"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactInQueryFacetQuerySwapSingleTokenExactIn = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInQueryFacetAddress,
    functionName: 'querySwapSingleTokenExactIn',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInQueryFacetAbi}__ and `functionName` set to `"querySwapSingleTokenExactInHook"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactInQueryFacetQuerySwapSingleTokenExactInHook = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInQueryFacetAddress,
    functionName: 'querySwapSingleTokenExactInHook',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInQueryFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeRouterExactInQueryFacetEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeRouterExactInQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInQueryFacetAddress,
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInQueryFacetAbi}__ and `eventName` set to `"SwapHookParamsDebug"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeRouterExactInQueryFacetSwapHookParamsDebugEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeRouterExactInQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInQueryFacetAddress,
    eventName: 'SwapHookParamsDebug',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInQueryFacetAbi}__ and `eventName` set to `"WethSentinelDebug"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeRouterExactInQueryFacetWethSentinelDebugEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeRouterExactInQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInQueryFacetAddress,
    eventName: 'WethSentinelDebug',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactInSwapFacet = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapFacetAddress,
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapFacetAbi}__ and `functionName` set to `"facetFuncs"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactInSwapFacetFacetFuncs = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapFacetAddress,
    functionName: 'facetFuncs',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapFacetAbi}__ and `functionName` set to `"facetInterfaces"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactInSwapFacetFacetInterfaces = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapFacetAddress,
    functionName: 'facetInterfaces',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapFacetAbi}__ and `functionName` set to `"facetMetadata"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactInSwapFacetFacetMetadata = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapFacetAddress,
    functionName: 'facetMetadata',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapFacetAbi}__ and `functionName` set to `"facetName"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactInSwapFacetFacetName = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapFacetAddress,
    functionName: 'facetName',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapFacetAbi}__ and `functionName` set to `"getSender"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactInSwapFacetGetSender = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapFacetAddress,
    functionName: 'getSender',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactInSwapFacet = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapFacetAddress,
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapFacetAbi}__ and `functionName` set to `"swapSingleTokenExactIn"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactInSwapFacetSwapSingleTokenExactIn = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapFacetAddress,
    functionName: 'swapSingleTokenExactIn',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapFacetAbi}__ and `functionName` set to `"swapSingleTokenExactInHook"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactInSwapFacetSwapSingleTokenExactInHook = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapFacetAddress,
    functionName: 'swapSingleTokenExactInHook',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapFacetAbi}__ and `functionName` set to `"swapSingleTokenExactInWithPermit"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactInSwapFacetSwapSingleTokenExactInWithPermit = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapFacetAddress,
    functionName: 'swapSingleTokenExactInWithPermit',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactInSwapFacet = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapFacetAddress,
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapFacetAbi}__ and `functionName` set to `"swapSingleTokenExactIn"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactInSwapFacetSwapSingleTokenExactIn = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapFacetAddress,
    functionName: 'swapSingleTokenExactIn',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapFacetAbi}__ and `functionName` set to `"swapSingleTokenExactInHook"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactInSwapFacetSwapSingleTokenExactInHook = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapFacetAddress,
    functionName: 'swapSingleTokenExactInHook',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapFacetAbi}__ and `functionName` set to `"swapSingleTokenExactInWithPermit"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactInSwapFacetSwapSingleTokenExactInWithPermit = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapFacetAddress,
    functionName: 'swapSingleTokenExactInWithPermit',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeRouterExactInSwapFacetEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapFacetAddress,
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapFacetAbi}__ and `eventName` set to `"SwapHookParamsDebug"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeRouterExactInSwapFacetSwapHookParamsDebugEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapFacetAddress,
    eventName: 'SwapHookParamsDebug',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapFacetAbi}__ and `eventName` set to `"WethSentinelDebug"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeRouterExactInSwapFacetWethSentinelDebugEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapFacetAddress,
    eventName: 'WethSentinelDebug',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapTargetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactInSwapTarget = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapTargetAddress,
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapTargetAbi}__ and `functionName` set to `"getSender"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactInSwapTargetGetSender = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapTargetAddress,
    functionName: 'getSender',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapTargetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactInSwapTarget = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapTargetAddress,
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapTargetAbi}__ and `functionName` set to `"swapSingleTokenExactIn"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactInSwapTargetSwapSingleTokenExactIn = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapTargetAddress,
    functionName: 'swapSingleTokenExactIn',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapTargetAbi}__ and `functionName` set to `"swapSingleTokenExactInHook"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactInSwapTargetSwapSingleTokenExactInHook = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapTargetAddress,
    functionName: 'swapSingleTokenExactInHook',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapTargetAbi}__ and `functionName` set to `"swapSingleTokenExactInWithPermit"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactInSwapTargetSwapSingleTokenExactInWithPermit = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapTargetAddress,
    functionName: 'swapSingleTokenExactInWithPermit',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapTargetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactInSwapTarget = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapTargetAddress,
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapTargetAbi}__ and `functionName` set to `"swapSingleTokenExactIn"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactInSwapTargetSwapSingleTokenExactIn = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapTargetAddress,
    functionName: 'swapSingleTokenExactIn',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapTargetAbi}__ and `functionName` set to `"swapSingleTokenExactInHook"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactInSwapTargetSwapSingleTokenExactInHook = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapTargetAddress,
    functionName: 'swapSingleTokenExactInHook',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapTargetAbi}__ and `functionName` set to `"swapSingleTokenExactInWithPermit"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactInSwapTargetSwapSingleTokenExactInWithPermit = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapTargetAddress,
    functionName: 'swapSingleTokenExactInWithPermit',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapTargetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeRouterExactInSwapTargetEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapTargetAddress,
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapTargetAbi}__ and `eventName` set to `"SwapHookParamsDebug"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeRouterExactInSwapTargetSwapHookParamsDebugEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapTargetAddress,
    eventName: 'SwapHookParamsDebug',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactInSwapTargetAbi}__ and `eventName` set to `"WethSentinelDebug"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeRouterExactInSwapTargetWethSentinelDebugEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeRouterExactInSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactInSwapTargetAddress,
    eventName: 'WethSentinelDebug',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutQueryFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactOutQueryFacet = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAddress,
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutQueryFacetAbi}__ and `functionName` set to `"facetFuncs"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactOutQueryFacetFacetFuncs = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAddress,
    functionName: 'facetFuncs',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutQueryFacetAbi}__ and `functionName` set to `"facetInterfaces"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactOutQueryFacetFacetInterfaces = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAddress,
    functionName: 'facetInterfaces',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutQueryFacetAbi}__ and `functionName` set to `"facetMetadata"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactOutQueryFacetFacetMetadata = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAddress,
    functionName: 'facetMetadata',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutQueryFacetAbi}__ and `functionName` set to `"facetName"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactOutQueryFacetFacetName = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAddress,
    functionName: 'facetName',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutQueryFacetAbi}__ and `functionName` set to `"getSender"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactOutQueryFacetGetSender = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAddress,
    functionName: 'getSender',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutQueryFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactOutQueryFacet = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAddress,
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutQueryFacetAbi}__ and `functionName` set to `"querySwapSingleTokenExactOut"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactOutQueryFacetQuerySwapSingleTokenExactOut = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAddress,
    functionName: 'querySwapSingleTokenExactOut',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutQueryFacetAbi}__ and `functionName` set to `"querySwapSingleTokenExactOutHook"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactOutQueryFacetQuerySwapSingleTokenExactOutHook = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAddress,
    functionName: 'querySwapSingleTokenExactOutHook',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutQueryFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactOutQueryFacet = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAddress,
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutQueryFacetAbi}__ and `functionName` set to `"querySwapSingleTokenExactOut"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactOutQueryFacetQuerySwapSingleTokenExactOut = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAddress,
    functionName: 'querySwapSingleTokenExactOut',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutQueryFacetAbi}__ and `functionName` set to `"querySwapSingleTokenExactOutHook"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactOutQueryFacetQuerySwapSingleTokenExactOutHook = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAddress,
    functionName: 'querySwapSingleTokenExactOutHook',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutQueryFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeRouterExactOutQueryFacetEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAddress,
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutQueryFacetAbi}__ and `eventName` set to `"SwapHookParamsDebug"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeRouterExactOutQueryFacetSwapHookParamsDebugEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAddress,
    eventName: 'SwapHookParamsDebug',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutQueryFacetAbi}__ and `eventName` set to `"WethSentinelDebug"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeRouterExactOutQueryFacetWethSentinelDebugEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutQueryFacetAddress,
    eventName: 'WethSentinelDebug',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactOutSwapFacet = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAddress,
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapFacetAbi}__ and `functionName` set to `"facetFuncs"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactOutSwapFacetFacetFuncs = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAddress,
    functionName: 'facetFuncs',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapFacetAbi}__ and `functionName` set to `"facetInterfaces"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactOutSwapFacetFacetInterfaces = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAddress,
    functionName: 'facetInterfaces',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapFacetAbi}__ and `functionName` set to `"facetMetadata"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactOutSwapFacetFacetMetadata = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAddress,
    functionName: 'facetMetadata',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapFacetAbi}__ and `functionName` set to `"facetName"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactOutSwapFacetFacetName = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAddress,
    functionName: 'facetName',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapFacetAbi}__ and `functionName` set to `"getSender"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactOutSwapFacetGetSender = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAddress,
    functionName: 'getSender',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactOutSwapFacet = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAddress,
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapFacetAbi}__ and `functionName` set to `"swapSingleTokenExactOut"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactOutSwapFacetSwapSingleTokenExactOut = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAddress,
    functionName: 'swapSingleTokenExactOut',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapFacetAbi}__ and `functionName` set to `"swapSingleTokenExactOutHook"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactOutSwapFacetSwapSingleTokenExactOutHook = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAddress,
    functionName: 'swapSingleTokenExactOutHook',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapFacetAbi}__ and `functionName` set to `"swapSingleTokenExactOutWithPermit"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactOutSwapFacetSwapSingleTokenExactOutWithPermit = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAddress,
    functionName: 'swapSingleTokenExactOutWithPermit',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactOutSwapFacet = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAddress,
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapFacetAbi}__ and `functionName` set to `"swapSingleTokenExactOut"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactOutSwapFacetSwapSingleTokenExactOut = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAddress,
    functionName: 'swapSingleTokenExactOut',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapFacetAbi}__ and `functionName` set to `"swapSingleTokenExactOutHook"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactOutSwapFacetSwapSingleTokenExactOutHook = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAddress,
    functionName: 'swapSingleTokenExactOutHook',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapFacetAbi}__ and `functionName` set to `"swapSingleTokenExactOutWithPermit"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactOutSwapFacetSwapSingleTokenExactOutWithPermit = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAddress,
    functionName: 'swapSingleTokenExactOutWithPermit',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeRouterExactOutSwapFacetEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAddress,
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapFacetAbi}__ and `eventName` set to `"SwapHookParamsDebug"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeRouterExactOutSwapFacetSwapHookParamsDebugEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAddress,
    eventName: 'SwapHookParamsDebug',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapFacetAbi}__ and `eventName` set to `"WethSentinelDebug"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeRouterExactOutSwapFacetWethSentinelDebugEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapFacetAddress,
    eventName: 'WethSentinelDebug',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapTargetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactOutSwapTarget = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAddress,
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapTargetAbi}__ and `functionName` set to `"getSender"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useReadBalancerV3StandardExchangeRouterExactOutSwapTargetGetSender = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAddress,
    functionName: 'getSender',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapTargetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactOutSwapTarget = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAddress,
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapTargetAbi}__ and `functionName` set to `"swapSingleTokenExactOut"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactOutSwapTargetSwapSingleTokenExactOut = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAddress,
    functionName: 'swapSingleTokenExactOut',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapTargetAbi}__ and `functionName` set to `"swapSingleTokenExactOutHook"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactOutSwapTargetSwapSingleTokenExactOutHook = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAddress,
    functionName: 'swapSingleTokenExactOutHook',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapTargetAbi}__ and `functionName` set to `"swapSingleTokenExactOutWithPermit"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWriteBalancerV3StandardExchangeRouterExactOutSwapTargetSwapSingleTokenExactOutWithPermit = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAddress,
    functionName: 'swapSingleTokenExactOutWithPermit',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapTargetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactOutSwapTarget = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAddress,
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapTargetAbi}__ and `functionName` set to `"swapSingleTokenExactOut"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactOutSwapTargetSwapSingleTokenExactOut = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAddress,
    functionName: 'swapSingleTokenExactOut',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapTargetAbi}__ and `functionName` set to `"swapSingleTokenExactOutHook"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactOutSwapTargetSwapSingleTokenExactOutHook = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAddress,
    functionName: 'swapSingleTokenExactOutHook',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapTargetAbi}__ and `functionName` set to `"swapSingleTokenExactOutWithPermit"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useSimulateBalancerV3StandardExchangeRouterExactOutSwapTargetSwapSingleTokenExactOutWithPermit = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAddress,
    functionName: 'swapSingleTokenExactOutWithPermit',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapTargetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeRouterExactOutSwapTargetEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAddress,
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapTargetAbi}__ and `eventName` set to `"SwapHookParamsDebug"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeRouterExactOutSwapTargetSwapHookParamsDebugEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAddress,
    eventName: 'SwapHookParamsDebug',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link balancerV3StandardExchangeRouterExactOutSwapTargetAbi}__ and `eventName` set to `"WethSentinelDebug"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x1E6bDB824c37C26ED78981b18733bea7C8269aCF)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x676fC93b26010aD1ec48Dd98aAdb4743F34f87fE)
 */
exports.useWatchBalancerV3StandardExchangeRouterExactOutSwapTargetWethSentinelDebugEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAbi,
    address: exports.balancerV3StandardExchangeRouterExactOutSwapTargetAddress,
    eventName: 'WethSentinelDebug',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link betterPermit2Abi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useReadBetterPermit2 = (0, codegen_1.createUseReadContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link betterPermit2Abi}__ and `functionName` set to `"DOMAIN_SEPARATOR"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useReadBetterPermit2DomainSeparator = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    functionName: 'DOMAIN_SEPARATOR',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link betterPermit2Abi}__ and `functionName` set to `"allowance"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useReadBetterPermit2Allowance = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    functionName: 'allowance',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link betterPermit2Abi}__ and `functionName` set to `"nonceBitmap"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useReadBetterPermit2NonceBitmap = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    functionName: 'nonceBitmap',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link betterPermit2Abi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useWriteBetterPermit2 = (0, codegen_1.createUseWriteContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link betterPermit2Abi}__ and `functionName` set to `"approve"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useWriteBetterPermit2Approve = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    functionName: 'approve',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link betterPermit2Abi}__ and `functionName` set to `"invalidateNonces"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useWriteBetterPermit2InvalidateNonces = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    functionName: 'invalidateNonces',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link betterPermit2Abi}__ and `functionName` set to `"invalidateUnorderedNonces"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useWriteBetterPermit2InvalidateUnorderedNonces = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    functionName: 'invalidateUnorderedNonces',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link betterPermit2Abi}__ and `functionName` set to `"lockdown"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useWriteBetterPermit2Lockdown = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    functionName: 'lockdown',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link betterPermit2Abi}__ and `functionName` set to `"permit"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useWriteBetterPermit2Permit = (0, codegen_1.createUseWriteContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    functionName: 'permit',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link betterPermit2Abi}__ and `functionName` set to `"permitTransferFrom"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useWriteBetterPermit2PermitTransferFrom = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    functionName: 'permitTransferFrom',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link betterPermit2Abi}__ and `functionName` set to `"permitWitnessTransferFrom"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useWriteBetterPermit2PermitWitnessTransferFrom = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    functionName: 'permitWitnessTransferFrom',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link betterPermit2Abi}__ and `functionName` set to `"transferFrom"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useWriteBetterPermit2TransferFrom = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    functionName: 'transferFrom',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link betterPermit2Abi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useSimulateBetterPermit2 = (0, codegen_1.createUseSimulateContract)({ abi: exports.betterPermit2Abi, address: exports.betterPermit2Address });
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link betterPermit2Abi}__ and `functionName` set to `"approve"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useSimulateBetterPermit2Approve = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    functionName: 'approve',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link betterPermit2Abi}__ and `functionName` set to `"invalidateNonces"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useSimulateBetterPermit2InvalidateNonces = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    functionName: 'invalidateNonces',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link betterPermit2Abi}__ and `functionName` set to `"invalidateUnorderedNonces"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useSimulateBetterPermit2InvalidateUnorderedNonces = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    functionName: 'invalidateUnorderedNonces',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link betterPermit2Abi}__ and `functionName` set to `"lockdown"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useSimulateBetterPermit2Lockdown = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    functionName: 'lockdown',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link betterPermit2Abi}__ and `functionName` set to `"permit"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useSimulateBetterPermit2Permit = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    functionName: 'permit',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link betterPermit2Abi}__ and `functionName` set to `"permitTransferFrom"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useSimulateBetterPermit2PermitTransferFrom = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    functionName: 'permitTransferFrom',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link betterPermit2Abi}__ and `functionName` set to `"permitWitnessTransferFrom"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useSimulateBetterPermit2PermitWitnessTransferFrom = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    functionName: 'permitWitnessTransferFrom',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link betterPermit2Abi}__ and `functionName` set to `"transferFrom"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useSimulateBetterPermit2TransferFrom = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    functionName: 'transferFrom',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link betterPermit2Abi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useWatchBetterPermit2Event = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link betterPermit2Abi}__ and `eventName` set to `"Approval"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useWatchBetterPermit2ApprovalEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    eventName: 'Approval',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link betterPermit2Abi}__ and `eventName` set to `"Lockdown"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useWatchBetterPermit2LockdownEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    eventName: 'Lockdown',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link betterPermit2Abi}__ and `eventName` set to `"NonceInvalidation"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useWatchBetterPermit2NonceInvalidationEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    eventName: 'NonceInvalidation',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link betterPermit2Abi}__ and `eventName` set to `"Permit"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useWatchBetterPermit2PermitEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    eventName: 'Permit',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link betterPermit2Abi}__ and `eventName` set to `"UnorderedNonceInvalidation"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
 */
exports.useWatchBetterPermit2UnorderedNonceInvalidationEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.betterPermit2Abi,
    address: exports.betterPermit2Address,
    eventName: 'UnorderedNonceInvalidation',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadDiamondPackageCallBackFactory = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `functionName` set to `"DIAMOND_LOUPE_FACET"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadDiamondPackageCallBackFactoryDiamondLoupeFacet = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    functionName: 'DIAMOND_LOUPE_FACET',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `functionName` set to `"ERC165_FACET"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadDiamondPackageCallBackFactoryErc165Facet = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    functionName: 'ERC165_FACET',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `functionName` set to `"ERC8109_INTROSPECTION_FACET"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadDiamondPackageCallBackFactoryErc8109IntrospectionFacet = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    functionName: 'ERC8109_INTROSPECTION_FACET',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `functionName` set to `"POST_DEPLOY_HOOK_FACET"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadDiamondPackageCallBackFactoryPostDeployHookFacet = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    functionName: 'POST_DEPLOY_HOOK_FACET',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `functionName` set to `"PROXY_INIT_HASH"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadDiamondPackageCallBackFactoryProxyInitHash = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    functionName: 'PROXY_INIT_HASH',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `functionName` set to `"calcAddress"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadDiamondPackageCallBackFactoryCalcAddress = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    functionName: 'calcAddress',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `functionName` set to `"erc8109Funcs"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadDiamondPackageCallBackFactoryErc8109Funcs = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    functionName: 'erc8109Funcs',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `functionName` set to `"facetCuts"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadDiamondPackageCallBackFactoryFacetCuts = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    functionName: 'facetCuts',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `functionName` set to `"facetInterfaces"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadDiamondPackageCallBackFactoryFacetInterfaces = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    functionName: 'facetInterfaces',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `functionName` set to `"pkgArgsOfAccount"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadDiamondPackageCallBackFactoryPkgArgsOfAccount = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    functionName: 'pkgArgsOfAccount',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `functionName` set to `"pkgConfig"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadDiamondPackageCallBackFactoryPkgConfig = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    functionName: 'pkgConfig',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `functionName` set to `"pkgOfAccount"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadDiamondPackageCallBackFactoryPkgOfAccount = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    functionName: 'pkgOfAccount',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `functionName` set to `"postDeployFacetCuts"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadDiamondPackageCallBackFactoryPostDeployFacetCuts = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    functionName: 'postDeployFacetCuts',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useWriteDiamondPackageCallBackFactory = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `functionName` set to `"deploy"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useWriteDiamondPackageCallBackFactoryDeploy = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    functionName: 'deploy',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `functionName` set to `"initAccount"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useWriteDiamondPackageCallBackFactoryInitAccount = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    functionName: 'initAccount',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `functionName` set to `"postDeploy"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useWriteDiamondPackageCallBackFactoryPostDeploy = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    functionName: 'postDeploy',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useSimulateDiamondPackageCallBackFactory = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `functionName` set to `"deploy"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useSimulateDiamondPackageCallBackFactoryDeploy = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    functionName: 'deploy',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `functionName` set to `"initAccount"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useSimulateDiamondPackageCallBackFactoryInitAccount = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    functionName: 'initAccount',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `functionName` set to `"postDeploy"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useSimulateDiamondPackageCallBackFactoryPostDeploy = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    functionName: 'postDeploy',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useWatchDiamondPackageCallBackFactoryEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `eventName` set to `"DiamondCut"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useWatchDiamondPackageCallBackFactoryDiamondCutEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    eventName: 'DiamondCut',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link diamondPackageCallBackFactoryAbi}__ and `eventName` set to `"DiamondFunctionRemoved"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xC13e24A53912EAc22fA826536f0C1520A248e4E6)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useWatchDiamondPackageCallBackFactoryDiamondFunctionRemovedEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.diamondPackageCallBackFactoryAbi,
    address: exports.diamondPackageCallBackFactoryAddress,
    eventName: 'DiamondFunctionRemoved',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadUniswapV2StandardExchangeDfPkg = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__ and `functionName` set to `"calcSalt"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadUniswapV2StandardExchangeDfPkgCalcSalt = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
    functionName: 'calcSalt',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__ and `functionName` set to `"diamondConfig"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadUniswapV2StandardExchangeDfPkgDiamondConfig = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
    functionName: 'diamondConfig',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__ and `functionName` set to `"facetAddresses"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadUniswapV2StandardExchangeDfPkgFacetAddresses = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
    functionName: 'facetAddresses',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__ and `functionName` set to `"facetCuts"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadUniswapV2StandardExchangeDfPkgFacetCuts = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
    functionName: 'facetCuts',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__ and `functionName` set to `"facetInterfaces"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadUniswapV2StandardExchangeDfPkgFacetInterfaces = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
    functionName: 'facetInterfaces',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__ and `functionName` set to `"name"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadUniswapV2StandardExchangeDfPkgName = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
    functionName: 'name',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__ and `functionName` set to `"packageMetadata"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadUniswapV2StandardExchangeDfPkgPackageMetadata = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
    functionName: 'packageMetadata',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__ and `functionName` set to `"packageName"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadUniswapV2StandardExchangeDfPkgPackageName = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
    functionName: 'packageName',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__ and `functionName` set to `"postDeploy"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadUniswapV2StandardExchangeDfPkgPostDeploy = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
    functionName: 'postDeploy',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__ and `functionName` set to `"previewDeployVault"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadUniswapV2StandardExchangeDfPkgPreviewDeployVault = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
    functionName: 'previewDeployVault',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__ and `functionName` set to `"processArgs"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadUniswapV2StandardExchangeDfPkgProcessArgs = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
    functionName: 'processArgs',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__ and `functionName` set to `"updatePkg"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadUniswapV2StandardExchangeDfPkgUpdatePkg = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
    functionName: 'updatePkg',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__ and `functionName` set to `"vaultDeclaration"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadUniswapV2StandardExchangeDfPkgVaultDeclaration = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
    functionName: 'vaultDeclaration',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__ and `functionName` set to `"vaultFeeTypeIds"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadUniswapV2StandardExchangeDfPkgVaultFeeTypeIds = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
    functionName: 'vaultFeeTypeIds',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__ and `functionName` set to `"vaultTypes"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useReadUniswapV2StandardExchangeDfPkgVaultTypes = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
    functionName: 'vaultTypes',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useWriteUniswapV2StandardExchangeDfPkg = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__ and `functionName` set to `"deployVault"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useWriteUniswapV2StandardExchangeDfPkgDeployVault = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
    functionName: 'deployVault',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__ and `functionName` set to `"initAccount"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useWriteUniswapV2StandardExchangeDfPkgInitAccount = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
    functionName: 'initAccount',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useSimulateUniswapV2StandardExchangeDfPkg = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__ and `functionName` set to `"deployVault"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useSimulateUniswapV2StandardExchangeDfPkgDeployVault = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
    functionName: 'deployVault',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link uniswapV2StandardExchangeDfPkgAbi}__ and `functionName` set to `"initAccount"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0xb1451d5e9Be225ec537CcFC5a79aF7DdEfD0C97F)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x0000000000000000000000000000000000000000)
 */
exports.useSimulateUniswapV2StandardExchangeDfPkgInitAccount = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.uniswapV2StandardExchangeDfPkgAbi,
    address: exports.uniswapV2StandardExchangeDfPkgAddress,
    functionName: 'initAccount',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link vaultRegistryDeploymentFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.useReadVaultRegistryDeploymentFacet = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.vaultRegistryDeploymentFacetAbi,
    address: exports.vaultRegistryDeploymentFacetAddress,
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link vaultRegistryDeploymentFacetAbi}__ and `functionName` set to `"facetFuncs"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.useReadVaultRegistryDeploymentFacetFacetFuncs = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.vaultRegistryDeploymentFacetAbi,
    address: exports.vaultRegistryDeploymentFacetAddress,
    functionName: 'facetFuncs',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link vaultRegistryDeploymentFacetAbi}__ and `functionName` set to `"facetInterfaces"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.useReadVaultRegistryDeploymentFacetFacetInterfaces = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.vaultRegistryDeploymentFacetAbi,
    address: exports.vaultRegistryDeploymentFacetAddress,
    functionName: 'facetInterfaces',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link vaultRegistryDeploymentFacetAbi}__ and `functionName` set to `"facetMetadata"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.useReadVaultRegistryDeploymentFacetFacetMetadata = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.vaultRegistryDeploymentFacetAbi,
    address: exports.vaultRegistryDeploymentFacetAddress,
    functionName: 'facetMetadata',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link vaultRegistryDeploymentFacetAbi}__ and `functionName` set to `"facetName"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.useReadVaultRegistryDeploymentFacetFacetName = 
/*#__PURE__*/ (0, codegen_1.createUseReadContract)({
    abi: exports.vaultRegistryDeploymentFacetAbi,
    address: exports.vaultRegistryDeploymentFacetAddress,
    functionName: 'facetName',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link vaultRegistryDeploymentFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.useWriteVaultRegistryDeploymentFacet = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.vaultRegistryDeploymentFacetAbi,
    address: exports.vaultRegistryDeploymentFacetAddress,
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link vaultRegistryDeploymentFacetAbi}__ and `functionName` set to `"deployPkg"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.useWriteVaultRegistryDeploymentFacetDeployPkg = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.vaultRegistryDeploymentFacetAbi,
    address: exports.vaultRegistryDeploymentFacetAddress,
    functionName: 'deployPkg',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link vaultRegistryDeploymentFacetAbi}__ and `functionName` set to `"deployVault"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.useWriteVaultRegistryDeploymentFacetDeployVault = 
/*#__PURE__*/ (0, codegen_1.createUseWriteContract)({
    abi: exports.vaultRegistryDeploymentFacetAbi,
    address: exports.vaultRegistryDeploymentFacetAddress,
    functionName: 'deployVault',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link vaultRegistryDeploymentFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.useSimulateVaultRegistryDeploymentFacet = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.vaultRegistryDeploymentFacetAbi,
    address: exports.vaultRegistryDeploymentFacetAddress,
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link vaultRegistryDeploymentFacetAbi}__ and `functionName` set to `"deployPkg"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.useSimulateVaultRegistryDeploymentFacetDeployPkg = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.vaultRegistryDeploymentFacetAbi,
    address: exports.vaultRegistryDeploymentFacetAddress,
    functionName: 'deployPkg',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link vaultRegistryDeploymentFacetAbi}__ and `functionName` set to `"deployVault"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.useSimulateVaultRegistryDeploymentFacetDeployVault = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.vaultRegistryDeploymentFacetAbi,
    address: exports.vaultRegistryDeploymentFacetAddress,
    functionName: 'deployVault',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link vaultRegistryDeploymentFacetAbi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.useWatchVaultRegistryDeploymentFacetEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.vaultRegistryDeploymentFacetAbi,
    address: exports.vaultRegistryDeploymentFacetAddress,
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link vaultRegistryDeploymentFacetAbi}__ and `eventName` set to `"NewPackage"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.useWatchVaultRegistryDeploymentFacetNewPackageEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.vaultRegistryDeploymentFacetAbi,
    address: exports.vaultRegistryDeploymentFacetAddress,
    eventName: 'NewPackage',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link vaultRegistryDeploymentFacetAbi}__ and `eventName` set to `"NewPackageOfType"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.useWatchVaultRegistryDeploymentFacetNewPackageOfTypeEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.vaultRegistryDeploymentFacetAbi,
    address: exports.vaultRegistryDeploymentFacetAddress,
    eventName: 'NewPackageOfType',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link vaultRegistryDeploymentFacetAbi}__ and `eventName` set to `"NewVault"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.useWatchVaultRegistryDeploymentFacetNewVaultEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.vaultRegistryDeploymentFacetAbi,
    address: exports.vaultRegistryDeploymentFacetAddress,
    eventName: 'NewVault',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link vaultRegistryDeploymentFacetAbi}__ and `eventName` set to `"NewVaultOfToken"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.useWatchVaultRegistryDeploymentFacetNewVaultOfTokenEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.vaultRegistryDeploymentFacetAbi,
    address: exports.vaultRegistryDeploymentFacetAddress,
    eventName: 'NewVaultOfToken',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link vaultRegistryDeploymentFacetAbi}__ and `eventName` set to `"NewVaultOfType"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.useWatchVaultRegistryDeploymentFacetNewVaultOfTypeEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.vaultRegistryDeploymentFacetAbi,
    address: exports.vaultRegistryDeploymentFacetAddress,
    eventName: 'NewVaultOfType',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link vaultRegistryDeploymentFacetAbi}__ and `eventName` set to `"PackageRemoved"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.useWatchVaultRegistryDeploymentFacetPackageRemovedEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.vaultRegistryDeploymentFacetAbi,
    address: exports.vaultRegistryDeploymentFacetAddress,
    eventName: 'PackageRemoved',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link vaultRegistryDeploymentFacetAbi}__ and `eventName` set to `"VaultRemoved"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x37740814F2790936296c9503Ca9750666F950d19)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0xBe3Edd7BD00f3c609e444C7dE7739E7718498426)
 */
exports.useWatchVaultRegistryDeploymentFacetVaultRemovedEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.vaultRegistryDeploymentFacetAbi,
    address: exports.vaultRegistryDeploymentFacetAddress,
    eventName: 'VaultRemoved',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link weth9Abi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useReadWeth9 = (0, codegen_1.createUseReadContract)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link weth9Abi}__ and `functionName` set to `"allowance"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useReadWeth9Allowance = (0, codegen_1.createUseReadContract)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
    functionName: 'allowance',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link weth9Abi}__ and `functionName` set to `"balanceOf"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useReadWeth9BalanceOf = (0, codegen_1.createUseReadContract)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
    functionName: 'balanceOf',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link weth9Abi}__ and `functionName` set to `"decimals"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useReadWeth9Decimals = (0, codegen_1.createUseReadContract)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
    functionName: 'decimals',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link weth9Abi}__ and `functionName` set to `"name"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useReadWeth9Name = (0, codegen_1.createUseReadContract)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
    functionName: 'name',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link weth9Abi}__ and `functionName` set to `"symbol"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useReadWeth9Symbol = (0, codegen_1.createUseReadContract)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
    functionName: 'symbol',
});
/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link weth9Abi}__ and `functionName` set to `"totalSupply"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useReadWeth9TotalSupply = (0, codegen_1.createUseReadContract)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
    functionName: 'totalSupply',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link weth9Abi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useWriteWeth9 = (0, codegen_1.createUseWriteContract)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link weth9Abi}__ and `functionName` set to `"approve"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useWriteWeth9Approve = (0, codegen_1.createUseWriteContract)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
    functionName: 'approve',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link weth9Abi}__ and `functionName` set to `"deposit"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useWriteWeth9Deposit = (0, codegen_1.createUseWriteContract)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
    functionName: 'deposit',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link weth9Abi}__ and `functionName` set to `"transfer"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useWriteWeth9Transfer = (0, codegen_1.createUseWriteContract)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
    functionName: 'transfer',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link weth9Abi}__ and `functionName` set to `"transferFrom"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useWriteWeth9TransferFrom = (0, codegen_1.createUseWriteContract)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
    functionName: 'transferFrom',
});
/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link weth9Abi}__ and `functionName` set to `"withdraw"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useWriteWeth9Withdraw = (0, codegen_1.createUseWriteContract)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
    functionName: 'withdraw',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link weth9Abi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useSimulateWeth9 = (0, codegen_1.createUseSimulateContract)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link weth9Abi}__ and `functionName` set to `"approve"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useSimulateWeth9Approve = (0, codegen_1.createUseSimulateContract)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
    functionName: 'approve',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link weth9Abi}__ and `functionName` set to `"deposit"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useSimulateWeth9Deposit = (0, codegen_1.createUseSimulateContract)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
    functionName: 'deposit',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link weth9Abi}__ and `functionName` set to `"transfer"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useSimulateWeth9Transfer = (0, codegen_1.createUseSimulateContract)({ abi: exports.weth9Abi, address: exports.weth9Address, functionName: 'transfer' });
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link weth9Abi}__ and `functionName` set to `"transferFrom"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useSimulateWeth9TransferFrom = 
/*#__PURE__*/ (0, codegen_1.createUseSimulateContract)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
    functionName: 'transferFrom',
});
/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link weth9Abi}__ and `functionName` set to `"withdraw"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useSimulateWeth9Withdraw = (0, codegen_1.createUseSimulateContract)({ abi: exports.weth9Abi, address: exports.weth9Address, functionName: 'withdraw' });
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link weth9Abi}__
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useWatchWeth9Event = (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link weth9Abi}__ and `eventName` set to `"Approval"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useWatchWeth9ApprovalEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
    eventName: 'Approval',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link weth9Abi}__ and `eventName` set to `"Deposit"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useWatchWeth9DepositEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
    eventName: 'Deposit',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link weth9Abi}__ and `eventName` set to `"Transfer"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useWatchWeth9TransferEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
    eventName: 'Transfer',
});
/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link weth9Abi}__ and `eventName` set to `"Withdrawal"`
 *
 * - [__View Contract on Base Basescan__](https://basescan.org/address/0x4200000000000000000000000000000000000006)
 * -
 * - [__View Contract on Sepolia Etherscan__](https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)
 */
exports.useWatchWeth9WithdrawalEvent = 
/*#__PURE__*/ (0, codegen_1.createUseWatchContractEvent)({
    abi: exports.weth9Abi,
    address: exports.weth9Address,
    eventName: 'Withdrawal',
});
