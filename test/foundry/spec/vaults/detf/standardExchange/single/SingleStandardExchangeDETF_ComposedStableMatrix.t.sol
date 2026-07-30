// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
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
import {ThresholdMode} from "contracts/vaults/detf/core/DETFThresholdPolicy.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";
import {
    ComposedStableCommonDetf_IntegratedDeploy_Test
} from "test/foundry/spec/vaults/detf/composed/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol";

/// @notice Phase 5 matrix: outer SingleStandardExchangeDETF over production ComposedStable DETF.
/// @dev Inherits IntegratedDeploy fixtures (parent tests still run on composed alone).
///      Outer deploy happens only inside matrix tests after `_bootstrapReserveGraph`.
contract SingleStandardExchangeDETF_ComposedStableMatrix_Test is ComposedStableCommonDetf_IntegratedDeploy_Test {
    uint256 internal constant MIN_LOCK = 30 days;

    /// @dev Product Open so rate-provider quotes work at near-peg (mint=1/burn=max illegal after pair validation).
    function _composedThresholdMode() internal pure override returns (ThresholdMode) {
        return ThresholdMode.Open;
    }

    function _composedMintThreshold() internal pure override returns (uint256) {
        return 0;
    }

    function _composedBurnThreshold() internal pure override returns (uint256) {
        return 0;
    }

    function _deployOuterOverComposed()
        internal
        returns (
            address outerDetf_,
            ISingleStandardExchangeDETFInfo outerInfo_,
            ISingleStandardExchangeDETFBonding outerBonding_
        )
    {
        IFacet multiBasic_ = VaultComponentFactoryService.deployMultiAssetBasicVaultFacet(create3Factory);
        IFacet multiStd_ = VaultComponentFactoryService.deployMultiAssetStandardVaultFacet(create3Factory);
        IFacet exchangeInFacet_ =
            SingleStandardExchangeDETF_Component_FactoryService.deployExchangeInFacet(create3Factory);
        IFacet rateFacet_ = IFacet(
            create3Factory.deployFacet(
                type(StandardExchangeRateProviderFacet).creationCode, keccak256("SSE_DETF_CS_RP")
            )
        );
        IStandardExchangeRateProviderDFPkg ratePkg_ = IStandardExchangeRateProviderDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(StandardExchangeRateProviderDFPkg).creationCode,
                    abi.encode(
                        IStandardExchangeRateProviderDFPkg.PkgInit({
                            rateProviderFacet: rateFacet_, diamondFactory: diamondPackageFactory
                        })
                    ),
                    keccak256("SSE_DETF_CS_RP_PKG")
                )
            )
        );
        IFacet nftFacet_ = DetfFacetFactoryService.deployDETFNFTVaultFacet(create3Factory);
        IFacet erc721_ =
            IFacet(create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("SSE_DETF_CS_721")));
        IFacet erc4626Basic_ = VaultComponentFactoryService.deployERC4626BasedBasicVaultFacet(create3Factory);
        IFacet erc4626Std_ = VaultComponentFactoryService.deployERC4626StandardVaultFacet(create3Factory);

        vm.startPrank(owner);
        IDetfSelfNftInventoryDFPkg bondPkg_ = DetfPkgFactoryService.deployDETFNFTVaultDFPkg(
            IVaultRegistryDeployment(address(indexedexManager)),
            DetfComponentFactoryService.buildDETFNFTVaultPkgInit(
                erc721_,
                erc4626Basic_,
                erc4626Std_,
                nftFacet_,
                IVaultFeeOracleQuery(address(indexedexManager)),
                IVaultRegistryDeployment(address(indexedexManager))
            )
        );
        ISingleStandardExchangeDETDFPkg outerPkg_ = SingleStandardExchangeDETF_Component_FactoryService.deployPkg(
            IVaultRegistryDeployment(address(indexedexManager)),
            ISingleStandardExchangeDETDFPkg.PkgInit({
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiBasic_,
                multiAssetStandardVaultFacet: multiStd_,
                exchangeInFacet: exchangeInFacet_,
                feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                balancerV3Router: IBalancerV3StandardExchangeRouterProxy(address(seRouter)),
                balancerV3Vault: IVault(address(vault)),
                weightedPoolFactory: WeightedPoolFactory(testPoolFactory),
                rateProviderPkg: ratePkg_,
                bondNftVaultPkg: bondPkg_,
                diamondFactory: diamondPackageFactory
            })
        );

        outerDetf_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(outerPkg_)),
            abi.encode(
                ISingleStandardExchangeDETDFPkg.PkgArgs({
                    name: "Outer DETF over ComposedStable",
                    symbol: "oCSDETF",
                    standardExchangeVault: IStandardExchangeProxy(deployedDetfVault),
                    standardExchangeVaultShare: detfToken,
                    // Nested composed burn path is not SE-rate-provider-quotable; abstract 1:1 reserve.
                    rateTarget: IERC20(address(0)),
                    detfWeight: 0,
                    vaultShareWeight: 0,
                    mintThreshold: 0,
                    burnThreshold: 0,
                    thresholdMode: ThresholdMode.Open,
                expansionClosureRatePerSecond: 0,
                expansionCatchUpMaxSeconds: 0,
                expansionCatchUpCapBps: 0
                })
            )
        );
        vm.stopPrank();

        outerInfo_ = ISingleStandardExchangeDETFInfo(outerDetf_);
        outerBonding_ = ISingleStandardExchangeDETFBonding(outerDetf_);
    }

    function test_matrix_composedStable_outerFirstBondAndInnerStillServes() public {
        _bootstrapReserveGraph();

        // Mint composed detf shares via production SE entry.
        uint256 amountIn = 2_000e18;
        deal(address(dai), address(this), amountIn, true);
        dai.approve(deployedDetfVault, amountIn);
        uint256 composedShares = IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, amountIn, detfToken, 0, address(this), false, block.timestamp + 1
        );
        assertTrue(composedShares > 0, "composed shares");

        (address outerDetf_, ISingleStandardExchangeDETFInfo outerInfo_, ISingleStandardExchangeDETFBonding outerBonding_)
        = _deployOuterOverComposed();

        assertFalse(outerInfo_.isReserveLive(), "outer starts inert");
        assertEq(outerInfo_.standardExchangeVault(), deployedDetfVault);
        assertEq(outerInfo_.standardExchangeVaultShare(), address(detfToken));

        // Use a substantial share of minted composed DETF so both outer reserve legs clear Balancer mins.
        uint256 bondIn_ = composedShares / 4;
        if (bondIn_ < 1e18) bondIn_ = composedShares;
        require(bondIn_ > 0, "bond amount");

        // Sanity: rate provider must return non-zero before first bond join.
        address rateSubject_ = outerInfo_.standardExchangeVaultShare();
        assertTrue(IERC20(rateSubject_).totalSupply() > 0, "composed share supply");

        detfToken.approve(outerDetf_, bondIn_);
        (uint256 tokenId_,) =
            outerBonding_.bond(detfToken, bondIn_, MIN_LOCK, address(this), false, block.timestamp + 1 hours);
        assertTrue(tokenId_ > 0);
        assertTrue(outerInfo_.isReserveLive(), "outer live after first bond");
        assertEq(detfToken.balanceOf(outerDetf_), 0, "residual composed shares after bond");
        assertEq(IERC20(outerDetf_).balanceOf(outerDetf_), 0, "residual free outer detf after bond");

        // Acquire more composed shares for outer mint (bond may have spent first batch).
        IStandardExchangeIn outerEx_ = IStandardExchangeIn(outerDetf_);
        assertTrue(outerInfo_.isMintingAllowed(), "outer mint gate open");
        // Keep outer single-sided join small vs reserve (avoid Balancer MaxInRatio).
        uint256 moreCompose = 200e18;
        deal(address(dai), address(this), moreCompose, true);
        dai.approve(deployedDetfVault, moreCompose);
        uint256 mintIn_ = IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, moreCompose, detfToken, 0, address(this), false, block.timestamp + 1
        );
        if (mintIn_ > 5e17) mintIn_ = 5e17;
        require(mintIn_ > 0, "need composed shares for mint");
        detfToken.approve(outerDetf_, mintIn_);
        uint256 mintOut_ = outerEx_.exchangeIn(
            detfToken, mintIn_, IERC20(outerDetf_), 0, address(this), false, block.timestamp + 1 hours
        );
        assertTrue(mintOut_ > 0, "outer mint");
        assertEq(detfToken.balanceOf(outerDetf_), 0, "residual composed shares after mint");
        assertEq(IERC20(outerDetf_).balanceOf(outerDetf_), 0, "residual free outer detf after mint");

        // Outer burn back to composed shares (burnThreshold=max).
        assertTrue(outerInfo_.isBurningAllowed(), "outer burn gate open");
        uint256 burnIn_ = mintOut_ / 2;
        require(burnIn_ > 0, "burn amount");
        IERC20(outerDetf_).approve(outerDetf_, burnIn_);
        uint256 burnOut_ = outerEx_.exchangeIn(
            IERC20(outerDetf_), burnIn_, detfToken, 0, address(this), false, block.timestamp + 1 hours
        );
        assertTrue(burnOut_ > 0, "outer burn to composed shares");
        assertEq(detfToken.balanceOf(outerDetf_), 0, "residual composed shares after burn");
        assertEq(IERC20(outerDetf_).balanceOf(outerDetf_), 0, "residual free outer detf after burn");

        // Double composition: inner still serves direct users.
        uint256 moreIn = 100e18;
        deal(address(dai), alice, moreIn, true);
        vm.startPrank(alice);
        dai.approve(deployedDetfVault, moreIn);
        uint256 innerOut = IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, moreIn, detfToken, 0, alice, false, block.timestamp + 1
        );
        vm.stopPrank();
        assertTrue(innerOut > 0, "inner still serves");
    }
}
