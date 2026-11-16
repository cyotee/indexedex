// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {InitDevService} from "@crane/contracts/InitDevService.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IIndexedexManagerDFPkg} from "contracts/manager/IIndexedexManagerDFPkg.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IndexedexManagerFactoryService as ManagerFactory} from "contracts/manager/IndexedexManagerFactoryService.sol";
import {FeeCollectorFactoryService as CollectorFactory} from "contracts/fee/collector/FeeCollectorFactoryService.sol";
import {IFeeCollectorDFPkg} from "contracts/fee/collector/IFeeCollectorDFPkg.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultDFPkg as V3Pkg} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/IUniswapV3FullSpreadStandardExchangeVaultDFPkg.sol";
import {UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService as V3Factory} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";
import {Univ3LiquiditySeeder} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";
import {IUniswapV4HookDiamondPackageCallBackFactory as HookFactory} from
    "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService} from
    "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookPackage as HookPkg} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {UniswapV4StandardExchangeWeightedBufferHook_FactoryService as WeightedFactory} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol";
import {IUniswapV4HookStagedPairInit} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {IUniswapV4Detf, IUniswapV4DetfDFPkg} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4Detf_Facet_FactoryService as DetfFacets} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Facet_FactoryService.sol";
import {DetfPkgFactoryService as DetfPackages} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {DetfComponentFactoryService as DetfComponents} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {IDETFSYDFPkg} from "contracts/vaults/detf/common/sy/IDETFSYDFPkg.sol";
import {IUniswapV4DetfBondNFTVaultDFPkg} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/IUniswapV4DetfBondNFTVaultDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/IRebasingClaimTokenDFPkg.sol";
import {MigrationSnapshotConsumer, IMigrationPairPreview} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigrationSnapshot.sol";
import {IUniswapV4DetfMigrationSnapshot as Snapshot} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationSnapshot.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {DETFMintSplitLib} from "contracts/vaults/detf/common/core/DETFMintSplitLib.sol";

/// @notice Fresh local chain only. Every state change is a broadcast by the unlocked dev EOA.
/// No prank, etch, state override, private key, or code-size-limit override is used.
contract MigrationSnapshotLocalQA is Script {
    address constant DEV = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    ICreate3FactoryProxy factory;
    IDiamondPackageCallBackFactory diamonds;
    IIndexedexManagerProxy manager;
    IFacet erc20;
    IFacet domain;
    IFacet permit;
    IFacet basic;
    IFacet standard;
    IFacet ownable;
    IUniswapV3Factory v3Factory;
    address pairA;
    address pairB;
    address seA;
    address seB;
    address detf;
    address hook;
    IUniswapV4DetfDFPkg detfPackage;

    function run() external {
        require(block.chainid == 31337 && msg.sender == DEV, "local unlocked dev account only");
        // Inspect the actual Forge argv, not an environment assertion or another RPC.
        string[] memory guard = new string[](2);
        guard[0] = "bash";
        guard[1] = "scripts/recovery/dtf-migration/pricing-local-qa.sh";
        require(keccak256(vm.ffi(guard)) == keccak256(hex"01"), "local CLI guard failed");
        vm.rpc("anvil_nodeInfo", "[]");
        vm.startBroadcast(DEV);
        (factory, diamonds) = InitDevService.initEnv(DEV);
        _manager();
        erc20 = _facet("ERC20Facet");
        domain = _facet("ERC5267Facet");
        permit = _facet("ERC2612Facet");
        basic = _facet("MultiAssetBasicVaultFacet");
        standard = _facet("MultiAssetStandardVaultFacet");
        _exchanges();
        _detfPackage();
        _reserveAndDetf();
        SimpleMintableERC20(pairA).mint(DEV, 10000 ether);
        SimpleMintableERC20(pairB).mint(DEV, 10000 ether);
        IERC20(pairA).approve(detf, type(uint256).max);
        IERC20(pairB).approve(detf, type(uint256).max);
        IUniswapV4Detf(detf).bond(IERC20(pairA), 100 ether, 30 days, DEV, false, block.timestamp + 1 hours);
        MigrationSnapshotConsumer consumer = MigrationSnapshotConsumer(factory.create3WithArgs(
            ArtifactCreationCode.creationCode(factory, "TestBase_UniswapV4DetfMigrationSnapshot.sol:MigrationSnapshotConsumer"),
            abi.encode(Snapshot.Source(detf, address(manager), pairA, pairB)), keccak256("local.snapshot")
        ));
        consumer.capture();
        uint256 ethBefore = consumer.evaluate(address(0), 2 ether).user;
        uint256 dtfBefore = consumer.evaluate(pairB, 3 ether).user;
        bytes32 bytesBefore = keccak256(consumer.snapshotBytes());
        require(ethBefore == _live(pairA, seA, 2 ether) && dtfBefore == _live(pairB, seB, 3 ether), "primary oracle parity");
        IStandardExchangeIn(detf).exchangeIn(IERC20(pairA), 5 ether, IERC20(detf), 0, DEV, false, block.timestamp + 1 hours);
        require(_live(pairA, seA, 2 ether) != ethBefore, "trade ineffective");
        IVaultFeeOracleManager(address(manager)).setVaultDexSwapFee(hook, 1e17);
        IVaultFeeOracleManager(address(manager)).setSeigniorageIncentivePercentageOfVault(detf, 2e17);
        IERC20(pairA).transfer(seA, 10 ether);
        IERC20(pairA).approve(seA, type(uint256).max);
        IStandardExchangeIn(seA).exchangeIn(IERC20(pairA), 10 ether, IERC20(seA), 0, DEV, false, block.timestamp + 1 hours);
        IVaultRegistryDisableManager(address(manager)).setVaultAddressDisabled(seA, true);
        require(consumer.evaluate(address(0), 2 ether).user == ethBefore, "frozen ETH changed");
        require(consumer.evaluate(pairB, 3 ether).user == dtfBefore, "frozen DTF changed");
        require(keccak256(consumer.snapshotBytes()) == bytesBefore, "frozen bytes changed");
        vm.stopBroadcast();
        console2.log("QA_CONSUMER", address(consumer));
        console2.log("QA_DETF", detf);
        console2.log("QA_HOOK", hook);
        console2.log("QA_MANAGER", address(manager));
        console2.log("QA_PAIR_A", pairA);
        console2.log("QA_PAIR_B", pairB);
        console2.log("QA_SE_A", seA);
        console2.log("QA_SE_B", seB);
        console2.log("QA_ETH_FROZEN", ethBefore);
        console2.log("QA_DTF_FROZEN", dtfBefore);
        console2.log("QA_ETH_LIVE_AFTER", _live(pairA, seA, 2 ether));
        console2.log("QA_DTF_LIVE_AFTER", _live(pairB, seB, 3 ether));
    }

    function _facet(string memory name) private returns (IFacet) {
        return factory.deployFacet(ArtifactCreationCode.creationCode(factory, string.concat(name, ".sol:", name)), keccak256(abi.encode(name)));
    }

    function _manager() private {
        ownable = _facet("MultiStepOwnableFacet");
        IFacet cut = _facet("DiamondCutFacet");
        IFeeCollectorDFPkg collectorPackage = CollectorFactory.deployFeeCollectorDFPkg(
            factory, cut, ownable, _facet("FeeCollectorSingleTokenPushFacet"), _facet("FeeCollectorManagerFacet")
        );
        IFeeCollectorProxy collector = CollectorFactory.deployFeeCollector(diamonds, collectorPackage, DEV);
        IIndexedexManagerDFPkg pkg = ManagerFactory.deployIndexedexManagerDFPkg(factory, IIndexedexManagerDFPkg.PkgInit({
            diamondCutFacet: cut, multiStepOwnableFacet: ownable,
            vaultFeeQueryFacet: _facet("VaultFeeOracleQueryFacet"),
            vaultFeeManagerFacet: _facet("VaultFeeOracleManagerFacet"),
            operableFacet: _facet("OperableFacet"),
            vaultRegistryDeploymentFacet: _facet("VaultRegistryDeploymentFacet"),
            vaultRegistryVaultManagerFacet: _facet("VaultRegistryVaultManagerFacet"),
            vaultRegistryVaultPackageManagerFacet: _facet("VaultRegistryVaultPackageManagerFacet"),
            vaultRegistryVaultPackageQueryFacet: _facet("VaultRegistryVaultPackageQueryFacet"),
            vaultRegistryVaultQueryFacet: _facet("VaultRegistryVaultQueryFacet"),
            vaultRegistryDisableQueryFacet: _facet("VaultRegistryDisableQueryFacet"),
            vaultRegistryDisableManagerFacet: _facet("VaultRegistryDisableManagerFacet")
        }));
        manager = ManagerFactory.deployIndexedexManager(diamonds, factory, pkg, DEV, collector);
        IOperable(address(factory)).setOperator(address(manager), true);
        IVaultFeeOracleManager fees = IVaultFeeOracleManager(address(manager));
        fees.setDefaultDexSwapFee(5e16);
        fees.setDefaultSeigniorageIncentivePercentage(5e16);
        fees.setDefaultBondTerms(BondTerms(30 days, 180 days, 0, 5e17));
        fees.setDefaultLiquidReservePercentageOfTypeId(
            type(IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve).interfaceId, 5e16
        );
    }

    function _token(string memory name, bytes32 salt) private returns (address) {
        return factory.create3WithArgs(
            ArtifactCreationCode.creationCode("SimpleMintableERC20.sol:SimpleMintableERC20"), abi.encode(name, name), salt
        );
    }

    function _exchanges() private {
        v3Factory = IUniswapV3Factory(factory.create3(
            ArtifactCreationCode.creationCode("lib/crane/contracts/protocols/dexes/uniswap/v3/UniswapV3Factory.sol:UniswapV3Factory"), keccak256("local.v3")
        ));
        address localPermit2 = factory.create3(
            ArtifactCreationCode.creationCode("BetterPermit2.sol:BetterPermit2"), keccak256("local.permit2")
        );
        V3Pkg.PkgInit memory init;
        init.erc20Facet = erc20;
        init.erc5267Facet = domain;
        init.erc2612Facet = permit;
        init.multiAssetBasicVaultFacet = basic;
        init.multiAssetStandardVaultFacet = standard;
        init.uniswapV3StandardExchangeInFacet = V3Factory.deployUniswapV3FullSpreadStandardExchangeVaultInFacet(factory);
        init.uniswapV3StandardExchangeInQueryFacet = V3Factory.deployUniswapV3FullSpreadStandardExchangeVaultInQueryFacet(factory);
        init.uniswapV3StandardExchangeOutFacet = V3Factory.deployUniswapV3FullSpreadStandardExchangeVaultOutFacet(factory);
        init.uniswapV3StandardExchangeOutQueryFacet = V3Factory.deployUniswapV3FullSpreadStandardExchangeVaultOutQueryFacet(factory);
        init.uniswapV3StandardExchangePositionImportFacet = V3Factory.deployUniswapV3FullSpreadStandardExchangeVaultPositionImportFacet(factory);
        init.uniswapV3StandardExchangeLiquidReserveFacet = V3Factory.deployUniswapV3FullSpreadStandardExchangeVaultLiquidReserveFacet(factory);
        init.uniswapV3StandardExchangeInMultiFacet = V3Factory.deployUniswapV3FullSpreadStandardExchangeVaultInMultiFacet(factory);
        init.uniswapV3StandardExchangeInMultiQueryFacet = V3Factory.deployUniswapV3FullSpreadStandardExchangeVaultInMultiQueryFacet(factory);
        init.uniswapV3StandardExchangeOutMultiFacet = V3Factory.deployUniswapV3FullSpreadStandardExchangeVaultOutMultiFacet(factory);
        init.uniswapV3StandardExchangeOutMultiQueryFacet = V3Factory.deployUniswapV3FullSpreadStandardExchangeVaultOutMultiQueryFacet(factory);
        init.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(manager));
        init.vaultRegistryDeployment = IVaultRegistryDeployment(address(manager));
        init.permit2 = IPermit2(localPermit2);
        init.uniswapV3Factory = v3Factory;
        V3Pkg pkg = V3Factory.deployUniswapV3FullSpreadStandardExchangeVaultDFPkg(manager, init);
        pairA = _token("Original ETH quote pair", keccak256("local.pairA"));
        pairB = _token("Original DTF quote pair", keccak256("local.pairB"));
        seA = _exchange(pkg, pairA, _token("Rate A", keccak256("local.rateA")));
        seB = _exchange(pkg, pairB, _token("Rate B", keccak256("local.rateB")));
    }

    function _exchange(V3Pkg pkg, address a, address b) private returns (address exchange) {
        IUniswapV3Pool pool = IUniswapV3Pool(v3Factory.createPool(a, b, 3000));
        pool.initialize(uint160(1 << 96));
        Univ3LiquiditySeeder seeder = Univ3LiquiditySeeder(factory.create3(
            ArtifactCreationCode.creationCode("UniswapV4DetfProductionSeDeployLib.sol:Univ3LiquiditySeeder"), keccak256(abi.encode(a,b))
        ));
        SimpleMintableERC20(a).mint(address(seeder), 100000000 ether);
        SimpleMintableERC20(b).mint(address(seeder), 100000000 ether);
        seeder.seedFullRange(pool, uint128(50000000 ether));
        exchange = pkg.deployVault(pool);
        SimpleMintableERC20(a).mint(DEV, 1000 ether);
        SimpleMintableERC20(b).mint(DEV, 1000 ether);
        IERC20(a).approve(exchange, type(uint256).max);
        IERC20(b).approve(exchange, type(uint256).max);
        address[] memory tokens = new address[](2);
        tokens[0] = pool.token0();
        tokens[1] = pool.token1();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100 ether;
        amounts[1] = 100 ether;
        IStandardExchangeInMulti(exchange).exchangeInManyToOne(tokens, amounts, IERC20(exchange), 0, DEV, false, block.timestamp + 1 hours);
    }

    function _detfPackage() private {
        IVaultRegistryDeployment registry = IVaultRegistryDeployment(address(manager));
        IVaultFeeOracleQuery oracle = IVaultFeeOracleQuery(address(manager));
        IUniswapV4DetfBondNFTVaultDFPkg bond = DetfPackages.deployUniswapV4DetfBondNFTVaultDFPkg(registry,
            DetfComponents.buildUniswapV4DetfBondNFTVaultPkgInit(
                _facet("ERC721Facet"), _facet("DETFFundedBondMetadataFacet"), _facet("UniswapV4DetfBondNFTVaultFacet"), oracle, registry
            )
        );
        IRebasingClaimTokenDFPkg claim = DetfPackages.deployRebasingClaimTokenDFPkg(factory,
            DetfComponents.buildRebasingClaimTokenPkgInit(erc20, domain, permit, _facet("RebasingClaimTokenFacet"), diamonds)
        );
        IDETFSYDFPkg sy = DetfPackages.deployDETFSYComponents(factory, registry, oracle, domain, permit);
        detfPackage = DetfPackages.deployUniswapV4DetfDFPkg(registry, IUniswapV4DetfDFPkg.PkgInit({
            erc20Facet: erc20, erc5267Facet: domain, erc2612Facet: permit,
            multiAssetBasicVaultFacet: basic, multiAssetStandardVaultFacet: standard,
            productFacets: DetfFacets.deployUniswapV4DetfFacets(factory),
            feeOracle: oracle, vaultRegistryDeployment: registry, bondNftVaultPkg: bond,
            rebasingClaimTokenPkg: claim, syPkg: sy
        }));
    }

    function _reserveAndDetf() private {
        IFacetRegistry facets = IFacetRegistry(address(factory));
        HookFactory hookFactory = HookFactoryService.deployUniswapV4HookDiamondPackageCallBackFactory(factory, HookFactory.InitArgs({
            erc165Facet: facets.canonicalFacet(type(IERC165).interfaceId),
            diamondLoupeFacet: facets.canonicalFacet(type(IDiamondLoupe).interfaceId),
            erc8109IntrospectionFacet: facets.canonicalFacet(type(IERC8109Introspection).interfaceId),
            postDeployHookFacet: facets.canonicalFacet(type(IPostDeployAccountHook).interfaceId),
            hookFlagsFacet: HookFactoryService.deployUniswapV4HookFlagsFacet(factory)
        }));
        IVaultRegistryDeployment registry = IVaultRegistryDeployment(address(manager));
        registry.setHookDiamondPackageFactory(address(hookFactory));
        HookPkg.PkgInit memory init = HookPkg.PkgInit({
            joinQueryFacet: WeightedFactory.deployLiquidityFacetExt(factory),
            joinFlexibleFacet: WeightedFactory.deployJoinFlexibleFacet(factory),
            exitQueryFacet: WeightedFactory.deployExitQueryFacet(factory),
            vaultRegistryDeployment: registry, vaultFeeOracleQuery: IVaultFeeOracleQuery(address(manager)),
            joinFacet: WeightedFactory.deployLiquidityFacet(factory), exitFacet: WeightedFactory.deployExitFacet(factory),
            seFacet: WeightedFactory.deploySeFacet(factory), hooksFacet: WeightedFactory.deployHooksFacet(factory),
            erc20Facet: erc20, erc5267Facet: domain, erc2612Facet: permit,
            multiAssetBasicVaultFacet: basic, multiAssetStandardVaultFacet: standard, multiStepOwnableFacet: ownable
        });
        HookPkg pkg = HookPkg(registry.deployPkg(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol:UniswapV4StandardExchangeWeightedBufferHookDFPkg"),
            abi.encode(init), keccak256(abi.encode("UniswapV4StandardExchangeWeightedBufferHookDFPkg"))
        ));
        IUniswapV4Detf.PkgArgs memory args;
        args.name = "UniV4 DETF";
        args.symbol = "DETF";
        args.ownerOnlyLiquidity = true;
        args.creationPairPerDetfWad = new uint256[](2);
        args.creationPairPerDetfWad[0] = 1e18;
        args.creationPairPerDetfWad[1] = 1e18;
        detf = diamonds.calcAddress(IDiamondFactoryPackage(address(detfPackage)), abi.encode(args));
        address[] memory tokens = new address[](3);
        tokens[0] = detf; tokens[1] = pairA; tokens[2] = pairB;
        for (uint256 i; i < 3; ++i) for (uint256 j = i + 1; j < 3; ++j) {
            if (tokens[i] > tokens[j]) (tokens[i], tokens[j]) = (tokens[j], tokens[i]);
        }
        uint256[] memory weights = new uint256[](3);
        address[] memory exchanges = new address[](3);
        for (uint256 i; i < 3; ++i) {
            weights[i] = tokens[i] == detf ? 4e17 : 3e17;
            exchanges[i] = tokens[i] == detf ? address(0) : tokens[i] == pairA ? seA : seB;
        }
        address poolManager = factory.create3WithArgs(
            ArtifactCreationCode.creationCode(factory, "PoolManager.sol:PoolManager"), abi.encode(DEV), keccak256("local.v4")
        );
        HookPkg.PkgArgs memory h = HookPkg.PkgArgs({
            poolManager: poolManager, feeOracle: address(manager), n: 3, tokens: tokens, weights: weights,
            standardExchanges: exchanges,
            rateProviders: RateProviderFixtureLib.providersFor(factory, diamonds, tokens, exchanges),
            tokenDecimals: HookPkgArgsDecimalsLib.tokenDecimals(tokens, detf),
            seDecimals: HookPkgArgsDecimalsLib.seDecimals(exchanges), ownerOnlyLiquidity: true, owner: detf
        });
        hook = pkg.deployVault(h, WeightedFactory.findMineNonce(hookFactory, pkg, h));
        IUniswapV4HookStagedPairInit(hook).deployPair(tokens[0], tokens[1]);
        IUniswapV4HookStagedPairInit(hook).deployPair(tokens[0], tokens[2]);
        IUniswapV4HookStagedPairInit(hook).deployPair(tokens[1], tokens[2]);
        require(IUniswapV4HookStagedPairInit(hook).finalizeInitialization(), "hook initialization");
        args.hook = hook;
        require(detfPackage.deployVault(args) == detf, "predicted DETF");
    }

    function _live(address pair, address exchange, uint256 amount) private view returns (uint256 user) {
        uint256 pairEq = IMigrationPairPreview(detf).peekPairEq(exchange, pair, amount);
        uint256 p = IVaultFeeOracleQuery(address(manager)).seigniorageIncentivePercentageOfVault(detf);
        (uint256 gross,) = IStandardExchangeIn(hook).previewExchangeIn(IERC20(pair), Math.mulDiv(pairEq, 1e18 + p, 1e18), IERC20(detf));
        (user,) = DETFMintSplitLib._splitLiveGross(gross, p);
    }
}
