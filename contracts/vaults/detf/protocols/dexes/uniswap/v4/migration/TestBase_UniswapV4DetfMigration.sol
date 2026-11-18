// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardExchangeBundleIn} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {TestBase_UniswapV4Detf_Weighted_ProdSe} from "../detf/TestBase_UniswapV4Detf_Weighted_ProdSe.sol";
import {UniswapV4DetfProductionSeDeployLib as SeLib, Univ3LiquiditySeeder}
    from "../detf/UniswapV4DetfProductionSeDeployLib.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {IUniswapV4HookStagedPairInit} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {IUniswapV4HookDiamondPackageCallBackFactory} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService}
    from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookPackage as HookPackage}
    from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {UniswapV4StandardExchangeWeightedBufferHook_FactoryService as HookFactory}
    from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultDFPkg as V3Package}
    from "contracts/vaults/standard/exchange/protocols/uniswap/v3/IUniswapV3FullSpreadStandardExchangeVaultDFPkg.sol";
import {UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService as V3Factory}
    from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve as V3Reserve}
    from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/IDETFNFTVaultDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/IRebasingClaimTokenDFPkg.sol";
import {IUniswapV4DetfMigrationSYDFPkg as MigrationSYPackage} from "./sy/IUniswapV4DetfMigrationSYDFPkg.sol";
import {IDETFSYDFPkg} from "contracts/vaults/detf/common/sy/IDETFSYDFPkg.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {IUniswapV4Detf, IUniswapV4DetfDFPkg} from "../detf/interfaces/IUniswapV4Detf.sol";
import {IUniswapV4DetfBondNFTVaultDFPkg} from "../bondNft/IUniswapV4DetfBondNFTVaultDFPkg.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation}
    from "./interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationDFPkg as MigrationPackage} from "./interfaces/IUniswapV4DetfMigrationDFPkg.sol";
import {IUniswapV4DetfMigrationRewardTokenDFPkg as RewardPackage} from "./sy/rewards/IUniswapV4DetfMigrationRewardToken.sol";
import {IUniswapV4DetfMigrationStakedDETF} from "./claimToken/IUniswapV4DetfMigrationStakedDETF.sol";
import {IUniswapV4DetfMigrationBondNFTVault} from "./bondNft/IUniswapV4DetfMigrationBondNFTVault.sol";
import {IUniswapV4DetfMigrationSY} from "./sy/IUniswapV4DetfMigrationSY.sol";
import {UniswapV4DetfMigration_Component_FactoryService as Components} from "./UniswapV4DetfMigration_Component_FactoryService.sol";
import {UniswapV4DetfMigration_Pkg_FactoryService as Packages} from "./UniswapV4DetfMigration_Pkg_FactoryService.sol";

import {IUniswapV4DetfMigrationWeightedPricing as Pricing} from "./interfaces/IUniswapV4DetfMigrationWeightedPricing.sol";
import {MigrationWeightedPricingFixture} from "./TestBase_UniswapV4DetfMigrationSnapshot.sol";
import {UniswapV3FrozenQuoteFixture as V3Capture} from "./UniswapV3FrozenQuoteFixture.sol";
import {IUniswapV4DetfMigrationWeightedPricingAllocationV3 as PricingAllocationV3}
    from "./interfaces/IUniswapV4DetfMigrationWeightedPricingV3.sol";

/// @notice Gold registry fixture with real WETH, V3 pools/SEs, weighted hook, and genuine issuance.
/// @dev Only mintable contribution/rate currencies and the external liquidity seeder are fixtures.
/// No subject is replaced, subclassed, etched, storage-injected, or impersonated.
abstract contract TestBase_UniswapV4DetfMigration is TestBase_UniswapV4Detf_Weighted_ProdSe {
    MigrationPackage internal migrationPkg;
    Migration internal migration;
    Allocation internal allocation;
    IUniswapV4DetfMigrationStakedDETF internal receipt;
    IUniswapV4DetfMigrationBondNFTVault internal bonds;
    IUniswapV4DetfMigrationSY internal stakingSy;
    IUniswapV4DetfMigrationSY internal rawSy;
    address internal migrationOwner;
    address internal payer;
    bool internal localBroadcast;
    bytes32 internal pricingId;
    IUniswapV3Pool internal migrationPoolA;
    IUniswapV3Pool internal migrationPoolB;

    function onERC721Received(address, address, uint256, bytes calldata) external pure virtual returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        payer = address(this);
        migrationOwner = makeAddr("migrationOwner");
        vm.deal(payer, 1_000_000 ether);
        _migrationEnvironment();
    }

    function _ownerStart() internal { if (!localBroadcast) vm.startPrank(owner); }
    function _ownerStop() internal { if (!localBroadcast) vm.stopPrank(); }
    function _migrationStart() internal { if (!localBroadcast) vm.startPrank(migrationOwner); }
    function _migrationStop() internal { if (!localBroadcast) vm.stopPrank(); }

    function _migrationEnvironment() internal {
        pairA = create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "lib/crane/contracts/protocols/tokens/wrappers/weth/v9/WETH9.sol:WETH9"), "", keccak256("migration.weth")
        );
        pairB = _deployContributionFixture();
        address rate_ = _deployRateFixture();
        IWETH(pairA).deposit{value: 10000 ether}();
        _fundContribution(payer, 10000 ether);
        SimpleMintableERC20(rate_).mint(payer, 20000 ether);
        pm = IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(payer), keccak256("migration.poolmanager")
        ));
        IUniswapV3Factory factory_ = IUniswapV3Factory(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "lib/crane/contracts/protocols/dexes/uniswap/v3/UniswapV3Factory.sol:UniswapV3Factory"),
            "", keccak256("migration.v3")
        ));
        V3Package v3_ = _migrationV3Package(factory_);
        IUniswapV3Pool poolA_ = SeLib.createUniv3PoolOneToOne(factory_, pairA, rate_, 3000);
        IUniswapV3Pool poolB_ = SeLib.createUniv3PoolOneToOne(factory_, pairB, rate_, 3000);
        migrationPoolA = poolA_;
        migrationPoolB = poolB_;
        _seedMigrationPool(poolA_, bytes32("A"));
        _seedMigrationPool(poolB_, bytes32("B"));
        se0 = v3_.deployVault(poolA_);
        se1 = v3_.deployVault(poolB_);
        _activateMigrationSe(se0, pairA, rate_);
        _activateMigrationSe(se1, pairB, rate_);
        _migrationHookPackage();
        _migrationPackages();
        detf = _deployMigration(_migrationArgs(migrationOwner));
        migration = Migration(detf);
        allocation = Allocation(detf);
        detfInfo = IUniswapV4Detf(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        receipt = IUniswapV4DetfMigrationStakedDETF(migration.rebasingClaimToken());
        bonds = IUniswapV4DetfMigrationBondNFTVault(migration.bondNftVault());
        rawSy = IUniswapV4DetfMigrationSY(migration.rawSY());
        stakingSy = IUniswapV4DetfMigrationSY(migration.stakingSY());
        IERC20(pairA).approve(detf, type(uint256).max);
        IERC20(pairB).approve(detf, type(uint256).max);
    }

    function _deployContributionFixture() internal virtual returns (address) {
        return create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "SimpleMintableERC20.sol:SimpleMintableERC20"),
            abi.encode("External contribution fixture", "CONTRIB"), keccak256("migration.contribution")
        );
    }

    /// @dev Fork fixtures may supply actual holder-funded contribution tokens instead of minting.
    function _fundContribution(address recipient_, uint256 amount_) internal virtual {
        SimpleMintableERC20(pairB).mint(recipient_, amount_);
    }

    function _deployRateFixture() internal virtual returns (address) {
        return create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "SimpleMintableERC20.sol:SimpleMintableERC20"),
            abi.encode("External rate fixture", "RATE"), keccak256("migration.rate")
        );
    }

    function _migrationV3Package(IUniswapV3Factory factory_) internal returns (V3Package pkg_) {
        SeLib.Univ3SeFacets memory f_ = SeLib._deployUniv3SeFacets(create3Factory);
        V3Package.PkgInit memory p_;
        p_.erc20Facet = erc20Facet;
        p_.erc5267Facet = erc5267Facet;
        p_.erc2612Facet = erc2612Facet;
        p_.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        p_.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        p_.uniswapV3StandardExchangeInFacet = f_.inFacet;
        p_.uniswapV3StandardExchangeInQueryFacet = f_.inQuery;
        p_.uniswapV3StandardExchangeOutFacet = f_.outFacet;
        p_.uniswapV3StandardExchangeOutQueryFacet = f_.outQuery;
        p_.uniswapV3StandardExchangePositionImportFacet = f_.posImport;
        p_.uniswapV3StandardExchangeLiquidReserveFacet = f_.liquidReserve;
        p_ = V3Factory.attachUniswapV3FullSpreadStandardExchangeVaultMultiFacets(
            p_, f_.inMulti, f_.inMultiQuery, f_.outMulti, f_.outMultiQuery
        );
        p_.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(indexedexManager));
        p_.vaultRegistryDeployment = IVaultRegistryDeployment(address(indexedexManager));
        p_.permit2 = permit2;
        p_.uniswapV3Factory = factory_;
        _ownerStart();
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(type(V3Reserve).interfaceId, 0.2e18);
        pkg_ = V3Factory.deployUniswapV3FullSpreadStandardExchangeVaultDFPkg(indexedexManager, p_);
        _ownerStop();
    }

    function _seedMigrationPool(IUniswapV3Pool pool_, bytes32 salt_) internal virtual {
        Univ3LiquiditySeeder seeder_ = Univ3LiquiditySeeder(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4DetfProductionSeDeployLib.sol:Univ3LiquiditySeeder"),
            "", salt_
        ));
        IERC20(pool_.token0()).transfer(address(seeder_), 2000 ether);
        IERC20(pool_.token1()).transfer(address(seeder_), 2000 ether);
        // Genesis converts 100 tokens per leg through the fixed 49% entry swap.
        // Deploy the funded external liquidity so that swap has a formable add.
        seeder_.seedFullRange(pool_, uint128(2000 ether));
    }

    function _activateMigrationSe(address se_, address pair_, address rate_) internal {
        address[] memory tokens_ = IBasicVault(se_).vaultTokens();
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 100 ether; amounts_[1] = 100 ether;
        IERC20(pair_).approve(se_, amounts_[0]);
        IERC20(rate_).approve(se_, amounts_[1]);
        uint256[] memory balances_ = new uint256[](2);
        for (uint256 i_; i_ < tokens_.length; ++i_) balances_[i_] = IERC20(tokens_[i_]).balanceOf(payer);
        (uint256 quote_, uint256[] memory quotedRefunds_) =
            IStandardExchangeBundleIn(se_).previewExchangeBundleInForSingleOut(amounts_, se_);
        (uint256 issued_, uint256[] memory refunds_) = IStandardExchangeBundleIn(se_).exchangeBundleInForSingleOut(
            amounts_, se_, quote_, payer, false, block.timestamp + 1 hours
        );
        assertGt(issued_, 0, "migration V3 activation");
        assertEq(issued_, quote_, "migration V3 activation quote/execution");
        assertEq(refunds_, quotedRefunds_, "migration V3 activation refund quote/execution");
        assertEq(refunds_.length, tokens_.length, "migration V3 activation refund count");
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            assertEq(IERC20(tokens_[i_]).balanceOf(payer), balances_[i_] - amounts_[i_] + refunds_[i_],
                "migration V3 activation net funding");
        }
    }

    function _migrationHookPackage() internal {
        IFacetRegistry registry_ = IFacetRegistry(address(create3Factory));
        hookFactory = HookFactoryService.deployUniswapV4HookDiamondPackageCallBackFactory(
            create3Factory, IUniswapV4HookDiamondPackageCallBackFactory.InitArgs({
                erc165Facet: registry_.canonicalFacet(type(IERC165).interfaceId),
                diamondLoupeFacet: registry_.canonicalFacet(type(IDiamondLoupe).interfaceId),
                erc8109IntrospectionFacet: registry_.canonicalFacet(type(IERC8109Introspection).interfaceId),
                postDeployHookFacet: registry_.canonicalFacet(type(IPostDeployAccountHook).interfaceId),
                hookFlagsFacet: HookFactoryService.deployUniswapV4HookFlagsFacet(create3Factory)
            })
        );
        HookPackage.PkgInit memory p_ = HookPackage.PkgInit({
            joinQueryFacet: HookFactory.deployLiquidityFacetExt(create3Factory),
            joinFlexibleFacet: HookFactory.deployJoinFlexibleFacet(create3Factory),
            exitQueryFacet: HookFactory.deployExitQueryFacet(create3Factory),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
            joinFacet: HookFactory.deployLiquidityFacet(create3Factory),
            exitFacet: HookFactory.deployExitFacet(create3Factory),
            seFacet: HookFactory.deploySeFacet(create3Factory),
            hooksFacet: HookFactory.deployHooksFacet(create3Factory),
            erc20Facet: erc20Facet, erc5267Facet: erc5267Facet, erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
            multiStepOwnableFacet: multiStepOwnableFacet
        });
        _ownerStart();
        IVaultRegistryDeployment(address(indexedexManager)).setHookDiamondPackageFactory(address(hookFactory));
        weightedHookPkg = HookPackage(address(IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
            ArtifactCreationCode.creationCode("UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol:UniswapV4StandardExchangeWeightedBufferHookDFPkg"),
            abi.encode(p_), ArtifactCreationCode.releaseSalt(keccak256(abi.encode("UniswapV4StandardExchangeWeightedBufferHookDFPkg")))
        )));
        _ownerStop();
    }

    function _migrationPackages() internal {
        IFacet bondFacet_ = Components.deployFacet(create3Factory, "UniswapV4DetfMigrationBondNFTVaultFacet");
        IFacet metadata_ = Components.deployFacet(create3Factory, "UniswapV4DetfMigrationBondMetadataFacet");
        IFacet nft_ = Components.deployFacet(create3Factory, "ERC721Facet");
        IFacet receipt_ = Components.deployFacet(create3Factory, "UniswapV4DetfMigrationStakedDETFFacet");
        IFacet sy_ = Components.deployFacet(create3Factory, "UniswapV4DetfMigrationSYFacet");
        IFacet rt_ = Components.deployFacet(create3Factory, "UniswapV4DetfMigrationRewardTokenFacet");
        rebasingClaimTokenPkg = DetfPkgFactoryService.deployRebasingClaimTokenDFPkg(create3Factory,
            IRebasingClaimTokenDFPkg.PkgInit(erc5267Facet, erc2612Facet, receipt_, diamondPackageFactory));
        RewardPackage reward_ = Packages.deployRewardToken(create3Factory, RewardPackage.PkgInit(rt_, diamondPackageFactory));
        IFacet[5] memory products_ = Components.deployParentFacets(create3Factory);
        IFacet permanent_ = Components.deployFacet(create3Factory, "UniswapV4DetfMigrationWeightedHookFacet");
        IFacet admin_ = Components.deployFacet(create3Factory, "UniswapV4DetfMigrationAllocationFacet");
        IFacet recovery_ = Components.deployFacet(create3Factory, "UniswapV4DetfMigrationRecoveryFacet");
        IFacet claimAllocation_ = Components.deployFacet(create3Factory, "UniswapV4DetfMigrationClaimVaultAllocationFacet");
        _ownerStart();
        bondNftVaultPkg = IUniswapV4DetfBondNFTVaultDFPkg(address(Packages.deployBond(
            IVaultRegistryDeployment(address(indexedexManager)), IDETFNFTVaultDFPkg.PkgInit(
                nft_, metadata_, bondFacet_, IVaultFeeOracleQuery(address(indexedexManager)),
                IVaultRegistryDeployment(address(indexedexManager))
            )
        )));
        syPkg = Packages.deploySy(IVaultRegistryDeployment(address(indexedexManager)),
            MigrationSYPackage.MigrationPkgInit(IDETFSYDFPkg.PkgInit(erc5267Facet, erc2612Facet, sy_,
                IVaultFeeOracleQuery(address(indexedexManager)), IVaultRegistryDeployment(address(indexedexManager))),
                diamondPackageFactory));
        migrationPkg = Packages.deployParent(IVaultRegistryDeployment(address(indexedexManager)),
            MigrationPackage.PkgInit(IUniswapV4DetfDFPkg.PkgInit(
                erc20Facet, erc5267Facet, erc2612Facet, multiAssetBasicVaultFacet, multiAssetStandardVaultFacet,
                products_, IVaultFeeOracleQuery(address(indexedexManager)),
                IVaultRegistryDeployment(address(indexedexManager)), bondNftVaultPkg, rebasingClaimTokenPkg, syPkg
            ), multiStepOwnableFacet, permanent_, admin_, recovery_, claimAllocation_, reward_));
        _ownerStop();
    }

    function _migrationArgs(address owner_) internal view returns (MigrationPackage.PkgArgs memory args_) {
        args_.baseArgs = _nLegDetfArgs(2);
        args_.baseArgs.name = "Migration DETF";
        args_.baseArgs.symbol = "DETF";
        args_.owner = owner_;
        args_.ownershipBufferPeriod = 1 days;
        args_.weth = pairA;
        args_.originalDtf = pairB;
    }

    function _deployMigration(MigrationPackage.PkgArgs memory args_) internal returns (address parent_) {
        args_ = _prepareMigrationHook(args_);
        _ownerStart();
        migrationPkg.prepareSyChildren(args_);
        // Native publication uses an explicit envelope below the owned node's
        // 32-million ceiling; other transactions retain Forge's estimation margin.
        parent_ = localBroadcast
            ? migrationPkg.deployVault{gas: 31_900_000}(args_)
            : migrationPkg.deployVault(args_);
        _ownerStop();
        require(parent_ == diamondPackageFactory.calcAddress(IDiamondFactoryPackage(address(migrationPkg)), abi.encode(args_)),
            "owner-aware prediction");
    }

    /// @notice Separate the real hook construction so tests/witnesses can observe the preparation boundary.
    function _prepareMigrationHook(MigrationPackage.PkgArgs memory args_) internal returns (MigrationPackage.PkgArgs memory) {
        return _prepareMigrationHookWithWeight(args_, 4e17);
    }

    /// @notice A different real hook payload can share the historical hook-cleared parent prediction.
    function _prepareMigrationHookWithWeight(MigrationPackage.PkgArgs memory args_, uint256 selfWeight_)
        internal returns (MigrationPackage.PkgArgs memory)
    {
        address predicted_ = diamondPackageFactory.calcAddress(IDiamondFactoryPackage(address(migrationPkg)), abi.encode(args_));
        address[] memory tokens_ = new address[](3);
        tokens_[0] = predicted_; tokens_[1] = pairA; tokens_[2] = pairB;
        _sortInPlace(tokens_);
        uint256[] memory weights_ = new uint256[](3);
        address[] memory exchanges_ = new address[](3);
        for (uint256 i_; i_ < 3; ++i_) {
            weights_[i_] = tokens_[i_] == predicted_ ? selfWeight_ : (1e18 - selfWeight_) / 2;
            exchanges_[i_] = tokens_[i_] == predicted_ ? address(0) : tokens_[i_] == pairA ? se0 : se1;
        }
        HookPackage.PkgArgs memory hookArgs_ = HookPackage.PkgArgs(
            address(pm), address(indexedexManager), 3, tokens_, weights_, exchanges_,
            RateProviderFixtureLib.providersFor(create3Factory, diamondPackageFactory, tokens_, exchanges_),
            HookPkgArgsDecimalsLib.tokenDecimals(tokens_, predicted_), HookPkgArgsDecimalsLib.seDecimals(exchanges_),
            true, predicted_
        );
        uint256 nonce_ = HookFactory.findMineNonce(hookFactory, weightedHookPkg, hookArgs_);
        reserveHook = weightedHookPkg.deployVault(hookArgs_, nonce_);
        IUniswapV4HookStagedPairInit init_ = IUniswapV4HookStagedPairInit(reserveHook);
        init_.deployPair(tokens_[0], tokens_[1]);
        init_.deployPair(tokens_[0], tokens_[2]);
        init_.deployPair(tokens_[1], tokens_[2]);
        require(init_.finalizeInitialization(), "hook initialized");
        args_.baseArgs.hook = reserveHook;
        return args_;
    }

    function _fundAndCapture() internal {
        _fundReserve();
        _setObservedPricing();
    }

    function _fundReserve() internal {
        IERC20[] memory tokens_ = new IERC20[](2);
        tokens_[0] = IERC20(pairA); tokens_[1] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 100 ether; amounts_[1] = 100 ether;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 0, block.timestamp + 1 hours);
        Migration.GenesisLeg[] memory legs_ = new Migration.GenesisLeg[](2);
        legs_[0] = Migration.GenesisLeg(IERC20(pairA), 100 ether, 1);
        legs_[1] = Migration.GenesisLeg(IERC20(pairB), 100 ether, 1);
        _migrationStart();
        allocation.bootstrapMigrationReserve(legs_, 0, 1, block.timestamp + 1 hours);
        _migrationStop();
    }

    function _v3PricingBindings() internal view returns (V3Capture.Binding[] memory bindings_) {
        bindings_ = new V3Capture.Binding[](2);
        bindings_[0] = V3Capture.Binding(se0, address(migrationPoolA), address(indexedexManager));
        bindings_[1] = V3Capture.Binding(se1, address(migrationPoolB), address(indexedexManager));
    }

    function _manualInputs() internal view returns (Pricing.InputsV3 memory) {
        return MigrationWeightedPricingFixture.observed(
            detf, address(indexedexManager), pairA, pairB, _v3PricingBindings()
        );
    }

    function _setObservedPricing() internal {
        Pricing.InputsV3 memory inputs_ = _manualInputs();
        _migrationStart();
        pricingId = PricingAllocationV3(address(allocation)).setMigrationWeightedPricingV3(inputs_);
        _migrationStop();
    }

    function _configure(address recipient_, uint256 original_, bytes32 id_) internal returns (uint256 credit_) {
        Migration.IndependentAllocationInput[] memory inputs_ = new Migration.IndependentAllocationInput[](1);
        inputs_[0].recipient = recipient_;
        inputs_[0].evidenceId = keccak256("external fixture; not historical provenance");
        inputs_[0].entitlements = new Migration.OriginalEntitlement[](1);
        inputs_[0].entitlements[0] = Migration.OriginalEntitlement(id_, original_, original_, bytes32("fixture"));
        _migrationStart();
        allocation.configureIndependentAllocations(inputs_, pricingId);
        _migrationStop();
        return migration.independentAllocation(recipient_).totalCredit;
    }

    /// @dev Explicit synthetic paid capital, separate from compensation and booked donations.
    function _buyOwnerFirstBond() internal returns (uint256 id_) {
        return _buyOwnerFirstBond(1 ether);
    }

    function _buyOwnerFirstBond(uint256 amount_) internal returns (uint256 id_) {
        address buyer_ = migration.owner();
        IERC20(pairA).transfer(buyer_, amount_);
        vm.startPrank(buyer_);
        IERC20(pairA).approve(detf, amount_);
        (id_,) = migration.bond(IERC20(pairA), amount_, 90 days, buyer_, false, block.timestamp);
        vm.stopPrank();
    }

    function _issue(address recipient_) internal returns (uint256) {
        Migration.IndependentIssuanceRequest[] memory requests_ = new Migration.IndependentIssuanceRequest[](1);
        requests_[0] = Migration.IndependentIssuanceRequest(recipient_, migration.independentAllocation(recipient_).configurationId);
        _migrationStart();
        uint256[] memory ids_ = allocation.issueIndependentAllocations(requests_);
        _migrationStop();
        return ids_[0];
    }
}
