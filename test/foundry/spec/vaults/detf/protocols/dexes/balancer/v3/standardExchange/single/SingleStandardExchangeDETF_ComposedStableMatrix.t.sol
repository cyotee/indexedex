// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IWeightedPoolFactory} from "contracts/interfaces/IWeightedPoolFactory.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {IStandardExchangeRateProviderDFPkg} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProviderDFPkg.sol";
import {StandardExchangeRateProviderDFPkg} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {
    StandardExchangeRateProviderFacet
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/IRebasingClaimTokenDFPkg.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {ISingleStandardExchangeDETDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETDFPkg.sol";
import {
    SingleStandardExchangeDETF_Component_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_Component_FactoryService.sol";
import {ISingleStandardExchangeDETFBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFBonding.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {ISingleStandardExchangeDETFInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFInfo.sol";
import {
    ComposedStableCommonDetf_IntegratedDeploy_Test
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol";

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
        ISingleStandardExchangeDETDFPkg.PkgInit memory init_ = _outerPkgInit();
        vm.prank(owner);
        ISingleStandardExchangeDETDFPkg outerPkg_ = SingleStandardExchangeDETF_Component_FactoryService.deployPkg(
            IVaultRegistryDeployment(address(indexedexManager)), init_
        );
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args_;
        args_.name = "Outer DETF over ComposedStable";
        args_.symbol = "oCSDETF";
        args_.standardExchangeVault = IStandardExchangeProxy(deployedDetfVault);
        args_.standardExchangeVaultShare = detfToken;
        vm.prank(owner);
        outerDetf_ = indexedexManager.deployVault(IStandardVaultPkg(address(outerPkg_)), abi.encode(args_));
        outerInfo_ = ISingleStandardExchangeDETFInfo(outerDetf_);
        outerBonding_ = ISingleStandardExchangeDETFBonding(outerDetf_);
    }

    function _outerPkgInit() private returns (ISingleStandardExchangeDETDFPkg.PkgInit memory pkgInit_) {
        pkgInit_.erc20Facet = erc20Facet;
        pkgInit_.erc5267Facet = erc5267Facet;
        pkgInit_.erc2612Facet = erc2612Facet;
        pkgInit_.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        pkgInit_.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        pkgInit_.exchangeInFacet =
            SingleStandardExchangeDETF_Component_FactoryService.deployExchangeInFacet(create3Factory);
        pkgInit_.bondingFacet = SingleStandardExchangeDETF_Component_FactoryService.deployBondingFacet(create3Factory);
        pkgInit_.feeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        pkgInit_.vaultRegistryDeployment = IVaultRegistryDeployment(address(indexedexManager));
        pkgInit_.balancerV3Router = IBalancerV3StandardExchangeRouterProxy(address(seRouter));
        pkgInit_.balancerV3Vault = IVault(address(vault));
        pkgInit_.weightedPoolFactory = IWeightedPoolFactory(testPoolFactory);
        pkgInit_.rateProviderPkg = rateProviderPkg;
        pkgInit_.bondNftVaultPkg = bondNftVaultPkg;
        pkgInit_.rebasingClaimTokenPkg = rebasingClaimTokenPkg;
        pkgInit_.syPkg = syPkg;
        pkgInit_.diamondFactory = diamondPackageFactory;
    }

    function test_matrix_composedStable_outerFirstBondAndInnerStillServes() public {
        uint256 raw_ = _buyFixtureRaw(address(this));
        (address outer_, ISingleStandardExchangeDETFInfo info_, ISingleStandardExchangeDETFBonding bonds_) =
            _deployOuterOverComposed();
        assertFalse(info_.isReserveLive());
        assertEq(info_.standardExchangeVault(), deployedDetfVault);
        assertEq(info_.standardExchangeVaultShare(), address(detfToken));
        uint256 input_ = raw_ / 4;
        assertGt(input_, 0);
        detfToken.approve(outer_, input_);
        (uint256 id_,) = bonds_.bond(detfToken, input_, MIN_LOCK, address(this), false, block.timestamp);
        assertTrue(info_.isReserveLive());
        _assertBondPrincipalIsFunded(outer_, id_, address(this));
        uint256 mintIn_ = _reserveTokenBudget(info_.reservePool(), detfToken);
        assertGt(mintIn_, 0);
        assertLe(mintIn_, detfToken.balanceOf(address(this)));
        detfToken.approve(outer_, mintIn_);
        uint256 minted_ = IStandardExchangeIn(outer_)
            .exchangeIn(detfToken, mintIn_, IERC20(outer_), 0, address(this), false, block.timestamp);
        assertGt(minted_, 1);
        uint256 burned_ = minted_ / 2;
        IERC20(outer_).approve(outer_, burned_);
        uint256 returned_ = IStandardExchangeIn(outer_)
            .exchangeIn(IERC20(outer_), burned_, detfToken, 0, address(this), false, block.timestamp);
        assertGt(returned_, 0);
        assertEq(IERC20(outer_).balanceOf(address(this)), minted_ - burned_);
        assertEq(detfToken.balanceOf(outer_), 0);
        assertEq(IERC20(outer_).balanceOf(outer_), 0);
        assertGt(_buyFixtureRaw(alice), 0, "inner still serves direct users");
    }
}
