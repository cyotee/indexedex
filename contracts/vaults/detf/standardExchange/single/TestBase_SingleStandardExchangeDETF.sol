// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {WeightedPoolFactory} from
    "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

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
import {DetfFacetFactoryService} from "contracts/vaults/detf/reusable/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/reusable/DetfPkgFactoryService.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/reusable/DetfComponentFactoryService.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/reusable/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/protocol/DETFNFTVaultDFPkg.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {
    ISingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETDFPkg.sol";
import {
    SingleStandardExchangeDETF_Component_FactoryService
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETF_Component_FactoryService.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";

/// @title TestBase_SingleStandardExchangeDETF
/// @notice Deploys production SingleStandardExchangeDETF against a production SE vault.
/// @dev Default provider: Aerodrome Standard Exchange vault from Balancer SE router TestBase
///      (local production packages — no MockStandardExchange).
abstract contract TestBase_SingleStandardExchangeDETF is TestBase_BalancerV3StandardExchangeRouter {
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using SingleStandardExchangeDETF_Component_FactoryService for ICreate3FactoryProxy;
    using SingleStandardExchangeDETF_Component_FactoryService for IVaultRegistryDeployment;

    uint256 internal constant DEFAULT_MIN_LOCK = 30 days;
    uint256 internal constant DEFAULT_MAX_LOCK = 180 days;

    IFacet internal multiAssetBasicVaultFacetDetf;
    IFacet internal multiAssetStandardVaultFacetDetf;
    IFacet internal singleStandardExchangeDetfExchangeInFacet;
    IFacet internal detfNFTVaultFacet;
    IFacet internal erc721Facet;

    IStandardExchangeRateProviderDFPkg internal rateProviderPkg;
    IDetfSelfNftInventoryDFPkg internal bondNftVaultPkg;
    ISingleStandardExchangeDETDFPkg internal singleStandardExchangeDetfPkg;

    IStandardExchangeProxy internal seVault;
    IERC20 internal seShare;
    IERC20 internal rateTargetToken;

    address internal detf;
    ISingleStandardExchangeDETFInfo internal detfInfo;
    ISingleStandardExchangeDETFBonding internal detfBonding;
    IStandardExchangeIn internal detfExchangeIn;

    function setUp() public virtual override {
        super.setUp();

        // Production SE attachment from router base (Aerodrome dai/usdc vault).
        seVault = daiUsdcVault;
        seShare = IERC20(address(daiUsdcVault));
        rateTargetToken = IERC20(address(dai));

        multiAssetBasicVaultFacetDetf = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacetDetf = create3Factory.deployMultiAssetStandardVaultFacet();
        singleStandardExchangeDetfExchangeInFacet = create3Factory.deployExchangeInFacet();

        _deployRateProviderPkg();
        _deployBondNftVaultPkg();
        _deploySingleStandardExchangeDetfPkg();
        detf = _deployDetfInstance();

        detfInfo = ISingleStandardExchangeDETFInfo(detf);
        detfBonding = ISingleStandardExchangeDETFBonding(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
    }

    function _deployRateProviderPkg() internal {
        IFacet rateProviderFacet = IFacet(
            create3Factory.deployFacet(
                type(StandardExchangeRateProviderFacet).creationCode,
                keccak256("SingleStandardExchangeDETF_RateProviderFacet")
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
                    keccak256("SingleStandardExchangeDETF_RateProviderDFPkg")
                )
            )
        );
        vm.label(address(rateProviderPkg), "SingleStandardExchangeDETF_RateProviderDFPkg");
    }

    function _deployBondNftVaultPkg() internal {
        detfNFTVaultFacet = create3Factory.deployDETFNFTVaultFacet();
        erc721Facet = IFacet(
            create3Factory.deployFacet(
                type(ERC721Facet).creationCode, keccak256("SingleStandardExchangeDETF_ERC721Facet")
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
        vm.label(address(bondNftVaultPkg), "SingleStandardExchangeDETF_BondNftVaultPkg");
    }

    function _deploySingleStandardExchangeDetfPkg() internal {
        ISingleStandardExchangeDETDFPkg.PkgInit memory pkgInit = ISingleStandardExchangeDETDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacetDetf,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacetDetf,
            exchangeInFacet: singleStandardExchangeDetfExchangeInFacet,
            feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            balancerV3Router: IBalancerV3StandardExchangeRouterProxy(address(seRouter)),
            balancerV3Vault: IVault(address(vault)),
            weightedPoolFactory: WeightedPoolFactory(testPoolFactory),
            rateProviderPkg: rateProviderPkg,
            bondNftVaultPkg: bondNftVaultPkg,
            diamondFactory: diamondPackageFactory
        });

        vm.startPrank(owner);
        singleStandardExchangeDetfPkg =
            IVaultRegistryDeployment(address(indexedexManager)).deployPkg(pkgInit);
        vm.stopPrank();
        vm.label(address(singleStandardExchangeDetfPkg), "SingleStandardExchangeDETDFPkg");
    }

    function _deployDetfInstance() internal returns (address detf_) {
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args = ISingleStandardExchangeDETDFPkg.PkgArgs({
            name: "Single Standard Exchange DETF",
            symbol: "ssxDETF",
            standardExchangeVault: seVault,
            standardExchangeVaultShare: IERC20(address(0)),
            rateTarget: rateTargetToken,
            detfWeight: 0,
            vaultShareWeight: 0,
            mintThreshold: 0,
            burnThreshold: 0
        });

        vm.startPrank(owner);
        detf_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(singleStandardExchangeDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
        vm.label(detf_, "SingleStandardExchangeDETF");
    }

    /// @dev Fund `to` with production SE vault shares via deposit path.
    function _fundSeShares(address to, uint256 lpAmount) internal returns (uint256 shares_) {
        shares_ = _depositToVault(to, lpAmount);
    }

    /// @dev First-bond bootstrap: fund shares, approve, bond with default min lock.
    function _bootstrapViaFirstBond(address bonder, uint256 lpAmount)
        internal
        returns (uint256 tokenId_, uint256 shares_)
    {
        uint256 seShares_ = _fundSeShares(bonder, lpAmount);
        vm.startPrank(bonder);
        seShare.approve(detf, seShares_);
        (tokenId_, shares_) = detfBonding.bond(
            seShare, seShares_, DEFAULT_MIN_LOCK, bonder, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _assertInert() internal view {
        assertFalse(detfInfo.isReserveLive(), "expected inert (not live)");
    }

    function _assertLive() internal view {
        assertTrue(detfInfo.isReserveLive(), "expected reserve live");
        assertTrue(detfInfo.reservePool() != address(0), "reserve pool missing");
        assertTrue(detfInfo.bondNftVault() != address(0), "bond nft vault missing");
    }

    /// @dev Open mintThreshold=1 and high burnThreshold for mint/burn math tests.
    function _deployOpenThresholdDetf(string memory name_, string memory symbol_)
        internal
        returns (address detf_)
    {
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args = ISingleStandardExchangeDETDFPkg.PkgArgs({
            name: name_,
            symbol: symbol_,
            standardExchangeVault: seVault,
            standardExchangeVaultShare: IERC20(address(0)),
            rateTarget: rateTargetToken,
            detfWeight: 0,
            vaultShareWeight: 0,
            mintThreshold: 1,
            burnThreshold: type(uint256).max
        });
        vm.startPrank(owner);
        detf_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(singleStandardExchangeDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
        vm.label(detf_, name_);
    }

    function _bootstrapDetf(address instance_, address bonder, uint256 lpAmount)
        internal
        returns (uint256 tokenId_)
    {
        uint256 seShares_ = _fundSeShares(bonder, lpAmount);
        vm.startPrank(bonder);
        seShare.approve(instance_, seShares_);
        (tokenId_,) = ISingleStandardExchangeDETFBonding(instance_).bond(
            seShare, seShares_, DEFAULT_MIN_LOCK, bonder, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /// @dev Free inventory of role tokens on the DETF diamond must be zero after success paths.
    ///      BPT held on the diamond is intentional reserve principal.
    function _assertNoFreeInventory(address instance_) internal view {
        assertEq(seShare.balanceOf(instance_), 0, "residual se vault shares");
        assertEq(IERC20(instance_).balanceOf(instance_), 0, "residual free detf");
        assertEq(IERC20(address(dai)).balanceOf(instance_), 0, "residual dai");
        assertEq(IERC20(address(usdc)).balanceOf(instance_), 0, "residual usdc");
    }
}
