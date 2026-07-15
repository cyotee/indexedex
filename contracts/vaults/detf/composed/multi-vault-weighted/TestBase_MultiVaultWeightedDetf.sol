// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {WeightedPoolFactory} from
    "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";
import {
    IStandardExchangeRateProviderDFPkg,
    StandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {
    StandardExchangeRateProviderFacet
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/reusable/DetfComponentFactoryService.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/reusable/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/reusable/DetfPkgFactoryService.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/reusable/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/protocol/DETFNFTVaultDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/protocol/RebasingClaimTokenDFPkg.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {
    IMultiVaultWeightedDetfDFPkg
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol";
import {
    MultiVaultWeightedDetf_Component_FactoryService
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetf_Component_FactoryService.sol";
import {
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";

/// @title TestBase_MultiVaultWeightedDetf
/// @notice Deploys production MultiVaultWeightedDetf against production SE vaults (Aerodrome).
abstract contract TestBase_MultiVaultWeightedDetf is TestBase_BalancerV3StandardExchangeRouter {
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;
    using MultiVaultWeightedDetf_Component_FactoryService for ICreate3FactoryProxy;
    using MultiVaultWeightedDetf_Component_FactoryService for IVaultRegistryDeployment;

    uint256 internal constant DEFAULT_MIN_LOCK = 30 days;
    uint256 internal constant DEFAULT_MAX_LOCK = 180 days;

    IFacet internal multiAssetBasicVaultFacetDetf;
    IFacet internal multiAssetStandardVaultFacetDetf;
    IFacet internal multiVaultWeightedDetfExchangeInFacet;
    IFacet internal detfNFTVaultFacet;
    IFacet internal erc721Facet;

    IStandardExchangeRateProviderDFPkg internal rateProviderPkg;
    IDetfSelfNftInventoryDFPkg internal bondNftVaultPkg;
    IRebasingClaimTokenDFPkg internal rebasingClaimTokenPkg;
    IMultiVaultWeightedDetfDFPkg internal multiVaultWeightedDetfPkg;

    IStandardExchangeProxy internal seVault0;
    IStandardExchangeProxy internal seVault1;
    IERC20 internal seShare0;
    IERC20 internal seShare1;
    IERC20 internal rateAsset0;
    IERC20 internal rateAsset1;

    address internal detf;
    IMultiVaultWeightedDetfInfo internal detfInfo;
    IMultiVaultWeightedDetfBonding internal detfBonding;
    IStandardExchangeIn internal detfExchangeIn;

    function setUp() public virtual override {
        super.setUp();

        seVault0 = daiUsdcVault;
        seShare0 = IERC20(address(daiUsdcVault));
        rateAsset0 = IERC20(address(dai));

        // Second production SE vault: another Aerodrome pool (weth/usdc-style via dai/weth if available).
        // Deploy a second pool using same factory with dai/weth for distinct underlying liquidity.
        _deploySecondSeVault();

        multiAssetBasicVaultFacetDetf = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacetDetf = create3Factory.deployMultiAssetStandardVaultFacet();
        multiVaultWeightedDetfExchangeInFacet = create3Factory.deployExchangeInFacet();

        _deployRateProviderPkg();
        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployMultiVaultWeightedDetfPkg();
        detf = _deployDetfN1();

        detfInfo = IMultiVaultWeightedDetfInfo(detf);
        detfBonding = IMultiVaultWeightedDetfBonding(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
    }

    function _deploySecondSeVault() internal {
        // Create dai-weth volatile pool + SE vault for multi-leg tests.
        address poolAddr = aerodromePoolFactory.createPool(address(dai), address(weth), false);
        address vaultAddr = aerodromeStandardExchangeDFPkg.deployVault(IPool(poolAddr));
        seVault1 = IStandardExchangeProxy(vaultAddr);
        seShare1 = IERC20(vaultAddr);
        rateAsset1 = IERC20(address(weth));
        vm.label(vaultAddr, "DaiWethSeVault");
    }

    function _deployRateProviderPkg() internal {
        IFacet rateProviderFacet = IFacet(
            create3Factory.deployFacet(
                type(StandardExchangeRateProviderFacet).creationCode,
                keccak256("MultiVaultWeightedDetf_RateProviderFacet")
            )
        );
        rateProviderPkg = IStandardExchangeRateProviderDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(StandardExchangeRateProviderDFPkg).creationCode,
                    abi.encode(
                        IStandardExchangeRateProviderDFPkg.PkgInit({
                            rateProviderFacet: rateProviderFacet,
                            diamondFactory: diamondPackageFactory
                        })
                    ),
                    keccak256("MultiVaultWeightedDetf_RateProviderDFPkg")
                )
            )
        );
    }

    function _deployBondNftVaultPkg() internal {
        detfNFTVaultFacet = create3Factory.deployDETFNFTVaultFacet();
        erc721Facet = IFacet(
            create3Factory.deployFacet(
                type(ERC721Facet).creationCode, keccak256("MultiVaultWeightedDetf_ERC721Facet")
            )
        );

        IDETFNFTVaultDFPkg.PkgInit memory nftPkgInit = DetfComponentFactoryService.buildDETFNFTVaultPkgInit(
            erc721Facet,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            detfNFTVaultFacet,
            IVaultFeeOracleQuery(address(indexedexManager)),
            IVaultRegistryDeployment(address(indexedexManager))
        );

        vm.startPrank(owner);
        bondNftVaultPkg =
            IVaultRegistryDeployment(address(indexedexManager)).deployDETFNFTVaultDFPkg(nftPkgInit);
        vm.stopPrank();
    }

    function _deployRebasingClaimTokenPkg() internal {
        IFacet claimFacet_ = create3Factory.deployRebasingClaimTokenFacet();
        rebasingClaimTokenPkg = create3Factory.deployRebasingClaimTokenDFPkg(
            DetfComponentFactoryService.buildRICHIRPkgInit(
                erc20Facet, erc5267Facet, erc2612Facet, claimFacet_, diamondPackageFactory
            )
        );
        vm.label(address(rebasingClaimTokenPkg), "MultiVaultWeightedDetf_ClaimTokenPkg");
    }

    function _deployMultiVaultWeightedDetfPkg() internal {
        IMultiVaultWeightedDetfDFPkg.PkgInit memory pkgInit = IMultiVaultWeightedDetfDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacetDetf,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacetDetf,
            exchangeInFacet: multiVaultWeightedDetfExchangeInFacet,
            feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            balancerV3Router: IBalancerV3StandardExchangeRouterProxy(address(seRouter)),
            balancerV3Vault: IVault(address(vault)),
            weightedPoolFactory: WeightedPoolFactory(testPoolFactory),
            rateProviderPkg: rateProviderPkg,
            bondNftVaultPkg: bondNftVaultPkg,
            rebasingClaimTokenPkg: rebasingClaimTokenPkg,
            diamondFactory: diamondPackageFactory
        });

        vm.startPrank(owner);
        multiVaultWeightedDetfPkg =
            IVaultRegistryDeployment(address(indexedexManager)).deployPkg(pkgInit);
        vm.stopPrank();
        vm.label(address(multiVaultWeightedDetfPkg), "MultiVaultWeightedDetfDFPkg");
    }

    function _deployDetfN1() internal returns (address detf_) {
        IStandardExchangeProxy[] memory vaults_ = new IStandardExchangeProxy[](1);
        IERC20[] memory shares_ = new IERC20[](1);
        IRateProvider[] memory rps_ = new IRateProvider[](1);
        IERC20[] memory ras_ = new IERC20[](1);
        uint256[] memory weights_ = new uint256[](1);
        vaults_[0] = seVault0;
        shares_[0] = IERC20(address(0));
        rps_[0] = IRateProvider(address(0));
        ras_[0] = rateAsset0;
        weights_[0] = 20e16;

        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args = IMultiVaultWeightedDetfDFPkg.PkgArgs({
            name: "Multi Vault Weighted DETF",
            symbol: "mvwDETF",
            vaults: vaults_,
            vaultShares: shares_,
            rateProviders: rps_,
            rateAssets: ras_,
            weightDetf: 80e16,
            vaultWeights: weights_,
            mintThreshold: 0,
            burnThreshold: 0
        });

        vm.startPrank(owner);
        detf_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(multiVaultWeightedDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
        vm.label(detf_, "MultiVaultWeightedDetf");
    }

    function _deployDetfN2(
        uint256 mintThreshold_,
        uint256 burnThreshold_
    ) internal returns (address detf_) {
        IStandardExchangeProxy[] memory vaults_ = new IStandardExchangeProxy[](2);
        IERC20[] memory shares_ = new IERC20[](2);
        IRateProvider[] memory rps_ = new IRateProvider[](2);
        IERC20[] memory ras_ = new IERC20[](2);
        uint256[] memory weights_ = new uint256[](2);
        vaults_[0] = seVault0;
        vaults_[1] = seVault1;
        shares_[0] = IERC20(address(0));
        shares_[1] = IERC20(address(0));
        rps_[0] = IRateProvider(address(0));
        rps_[1] = IRateProvider(address(0));
        ras_[0] = rateAsset0;
        ras_[1] = rateAsset1;
        weights_[0] = 15e16;
        weights_[1] = 15e16;

        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args = IMultiVaultWeightedDetfDFPkg.PkgArgs({
            name: "Multi Vault Weighted DETF N2",
            symbol: "mvw2",
            vaults: vaults_,
            vaultShares: shares_,
            rateProviders: rps_,
            rateAssets: ras_,
            weightDetf: 70e16,
            vaultWeights: weights_,
            mintThreshold: mintThreshold_,
            burnThreshold: burnThreshold_
        });

        vm.startPrank(owner);
        detf_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(multiVaultWeightedDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }

    function _deployOpenThresholdDetf() internal returns (address detf_) {
        IStandardExchangeProxy[] memory vaults_ = new IStandardExchangeProxy[](1);
        IERC20[] memory shares_ = new IERC20[](1);
        IRateProvider[] memory rps_ = new IRateProvider[](1);
        IERC20[] memory ras_ = new IERC20[](1);
        uint256[] memory weights_ = new uint256[](1);
        vaults_[0] = seVault0;
        shares_[0] = IERC20(address(0));
        rps_[0] = IRateProvider(address(0));
        ras_[0] = rateAsset0;
        weights_[0] = 20e16;

        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args = IMultiVaultWeightedDetfDFPkg.PkgArgs({
            name: "Open MVW DETF",
            symbol: "omvw",
            vaults: vaults_,
            vaultShares: shares_,
            rateProviders: rps_,
            rateAssets: ras_,
            weightDetf: 80e16,
            vaultWeights: weights_,
            mintThreshold: 1,
            burnThreshold: type(uint256).max
        });

        vm.startPrank(owner);
        detf_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(multiVaultWeightedDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }

    function _fundSeShares0(address to, uint256 lpAmount) internal returns (uint256 shares_) {
        shares_ = _depositToVault(to, lpAmount);
    }

    function _fundSeShares1(address to, uint256 amount) internal returns (uint256 shares_) {
        dai.mint(to, amount);
        vm.deal(to, amount + 1 ether);
        vm.startPrank(to);
        weth.deposit{value: amount}();
        dai.approve(address(aerodromeRouter), amount);
        weth.approve(address(aerodromeRouter), amount);
        (,, uint256 liquidity) = aerodromeRouter.addLiquidity(
            address(dai), address(weth), false, amount, amount, 1, 1, to, block.timestamp + 1 hours
        );
        address asset_ = seVault1.asset();
        IERC20(asset_).approve(address(seVault1), liquidity);
        shares_ = seVault1.deposit(liquidity, to);
        vm.stopPrank();
    }

    /// @dev Initialize reserve with vault shares and bond BPT to go live.
    function _goLiveViaBptBond(address instance_, address user, uint256 lpAmount)
        internal
        returns (uint256 tokenId_, uint256 bpt_)
    {
        uint256 seShares_ = _fundSeShares0(user, lpAmount);
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = seShares_;

        vm.startPrank(user);
        IERC20(address(seVault0)).approve(instance_, seShares_);
        bpt_ = IMultiVaultWeightedDetfBonding(instance_).initializeReserve(
            amounts_, block.timestamp + 1 hours
        );
        IERC20(IMultiVaultWeightedDetfInfo(instance_).reservePool()).approve(instance_, bpt_);
        (tokenId_,) = IMultiVaultWeightedDetfBonding(instance_).bond(
            IERC20(IMultiVaultWeightedDetfInfo(instance_).reservePool()),
            bpt_,
            DEFAULT_MIN_LOCK,
            user,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _assertInert(address instance_) internal view {
        assertFalse(IMultiVaultWeightedDetfInfo(instance_).isReserveLive(), "expected inert");
    }

    function _assertLive(address instance_) internal view {
        assertTrue(IMultiVaultWeightedDetfInfo(instance_).isReserveLive(), "expected live");
        assertTrue(IMultiVaultWeightedDetfInfo(instance_).reservePool() != address(0), "pool");
    }

    function _assertNoFreeInventory(address instance_) internal view {
        assertEq(seShare0.balanceOf(instance_), 0, "residual se0 shares");
        assertEq(IERC20(instance_).balanceOf(instance_), 0, "residual free detf");
    }
}
