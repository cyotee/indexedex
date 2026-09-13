// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {TestBase_FundedBalancerDETF} from "contracts/test/bases/TestBase_FundedBalancerDETF.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IWeightedPoolFactory} from "contracts/interfaces/IWeightedPoolFactory.sol";

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";

import {IStandardExchangeRateProviderDFPkg} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProviderDFPkg.sol";

import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/IDETFNFTVaultDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/IRebasingClaimTokenDFPkg.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {ISingleStandardExchangeDETDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETDFPkg.sol";
import {
    SingleStandardExchangeDETF_Component_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_Component_FactoryService.sol";
import {ISingleStandardExchangeDETFBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFBonding.sol";
import {ISingleStandardExchangeDETFInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFInfo.sol";
import {IDETFSYDFPkg} from "contracts/vaults/detf/common/sy/IDETFSYDFPkg.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {DETFNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol";

import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @dev Historical test ABI only; no retired selector is installed on production proxies.
interface ILegacySingleStandardExchangeDETFInfo is ISingleStandardExchangeDETFInfo {
    function thresholdMode() external view returns (ThresholdMode);
    function expansionCatchUpMaxSeconds() external view returns (uint256);
    function expansionCatchUpCapBps() external view returns (uint256);
    function compoundProtocolRewards() external returns (uint256 detfIn, uint256 bptOut);
}

/// @dev Historical test ABI only; no retired selector is installed on production proxies.
interface ILegacySingleStandardExchangeDETFBonding is ISingleStandardExchangeDETFBonding {
    function sellPositionToDetfNft(uint256 tokenId, uint256 minClaimOut, address recipient)
        external
        returns (uint256 claimMinted);
    function buyClaim(
        uint256 detfAmount,
        uint256 minClaimOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 claimMinted);
    function previewBuyClaim(uint256 detfAmount) external view returns (uint256 claimMinted);
    function closeBondMature(
        uint256 tokenId,
        uint256[] calldata minAmountsOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256[] memory amountsOut);
    function previewCloseBondMature(uint256 tokenId) external view returns (uint256[] memory amountsOut);
    function redeemClaim(
        uint256 claimAmount,
        IERC20 tokenOut,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountOut);
    function previewRedeemClaim(uint256 claimAmount, IERC20 tokenOut) external view returns (uint256 amountOut);
    function claimLiquidity(uint256 lpAmount, address recipient) external returns (uint256 amountOut);
    function protocolBondOriginalShares() external view returns (uint256);
}

/// @title TestBase_SingleStandardExchangeDETF
/// @notice Deploys production SingleStandardExchangeDETF against a production SE vault.
/// @dev Default provider: Aerodrome Standard Exchange vault from Balancer SE router TestBase
///      (local production packages — no MockStandardExchange).
abstract contract TestBase_SingleStandardExchangeDETF is TestBase_FundedBalancerDETF {
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using SingleStandardExchangeDETF_Component_FactoryService for ICreate3FactoryProxy;
    using SingleStandardExchangeDETF_Component_FactoryService for IVaultRegistryDeployment;

    function _warpPastUnlock(address instance_, uint256 tokenId_) internal {
        address nft_ = ISingleStandardExchangeDETFInfo(instance_).bondNftVault();
        uint256 unlock_ = IDetfBondNFT(nft_).positionOf(tokenId_).startTimestamp
            + IDetfBondNFT(nft_).positionOf(tokenId_).vestingDuration;
        if (block.timestamp <= unlock_) {
            vm.warp(unlock_ + 1);
        }
    }

    IFacet internal singleStandardExchangeDetfExchangeInFacet;
    IFacet internal singleStandardExchangeDetfBondingFacet;

    ISingleStandardExchangeDETDFPkg internal singleStandardExchangeDetfPkg;

    IStandardExchangeProxy internal seVault;
    IERC20 internal seShare;
    IERC20 internal rateTargetToken;

    address internal detf;
    ILegacySingleStandardExchangeDETFInfo internal detfInfo;
    ILegacySingleStandardExchangeDETFBonding internal detfBonding;
    IStandardExchangeIn internal detfExchangeIn;

    function setUp() public virtual override {
        super.setUp();

        // Production SE attachment from router base (Aerodrome dai/usdc vault).
        seVault = daiUsdcVault;
        seShare = IERC20(address(daiUsdcVault));
        rateTargetToken = IERC20(address(dai));

        singleStandardExchangeDetfExchangeInFacet = create3Factory.deployExchangeInFacet();
        singleStandardExchangeDetfBondingFacet = create3Factory.deployBondingFacet();

        _deploySingleStandardExchangeDetfPkg();
        detf = _deployDetfInstance();

        detfInfo = ILegacySingleStandardExchangeDETFInfo(detf);
        detfBonding = ILegacySingleStandardExchangeDETFBonding(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
    }

    function _singleSePkgInit(IRebasingClaimTokenDFPkg claimPkg_)
        internal
        view
        returns (ISingleStandardExchangeDETDFPkg.PkgInit memory pkgInit)
    {
        pkgInit = ISingleStandardExchangeDETDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacetDetf,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacetDetf,
            exchangeInFacet: singleStandardExchangeDetfExchangeInFacet,
            bondingFacet: singleStandardExchangeDetfBondingFacet,
            feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            balancerV3Router: IBalancerV3StandardExchangeRouterProxy(address(seRouter)),
            balancerV3Vault: IVault(address(vault)),
            weightedPoolFactory: IWeightedPoolFactory(testPoolFactory),
            rateProviderPkg: rateProviderPkg,
            bondNftVaultPkg: bondNftVaultPkg,
            rebasingClaimTokenPkg: claimPkg_,
            syPkg: syPkg,
            diamondFactory: diamondPackageFactory
        });
    }

    /// @dev M12: manager deploy of this family's DFPkg with claim pkg = 0 must revert.
    function _expectRevertDeployPkgWithZeroClaim() internal {
        ISingleStandardExchangeDETDFPkg.PkgInit memory pkgInit =
            _singleSePkgInit(IRebasingClaimTokenDFPkg(address(0)));
        vm.startPrank(owner);
        vm.expectRevert();
        IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
            ArtifactCreationCode.creationCode(create3Factory, "SingleStandardExchangeDETDFPkg.sol:SingleStandardExchangeDETDFPkg"),
            abi.encode(pkgInit),
            keccak256("SingleSE_M12_zero_claim")
        );
        vm.stopPrank();
    }

    function _deploySingleStandardExchangeDetfPkg() internal {
        ISingleStandardExchangeDETDFPkg.PkgInit memory pkgInit = _singleSePkgInit(rebasingClaimTokenPkg);

        vm.startPrank(owner);
        singleStandardExchangeDetfPkg =
            IVaultRegistryDeployment(address(indexedexManager)).deployPkg(pkgInit);
        vm.stopPrank();
        vm.label(address(singleStandardExchangeDetfPkg), "SingleStandardExchangeDETDFPkg");
    }

    function _defaultArgs() internal view returns (ISingleStandardExchangeDETDFPkg.PkgArgs memory args_) {
        args_.name = "Single Standard Exchange DETF";
        args_.symbol = "ssxDETF";
        args_.standardExchangeVault = seVault;
        args_.rateTarget = rateTargetToken;
    }

    function _deployDetfInstance() internal returns (address) { return _deployWithArgs(_defaultArgs()); }

    function _deployWithArgs(ISingleStandardExchangeDETDFPkg.PkgArgs memory args_) internal returns (address instance_) {
        vm.startPrank(owner);
        instance_ = indexedexManager.deployVault(IStandardVaultPkg(address(singleStandardExchangeDetfPkg)), abi.encode(args_));
        vm.stopPrank();
        vm.label(instance_, args_.name);
    }

    function _deployPolicyThresholds(uint256 mint_, uint256 burn_) internal returns (address) {
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args_ = _defaultArgs();
        args_.mintThreshold = mint_;
        args_.burnThreshold = burn_;
        return _deployWithArgs(args_);
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

    function _bootstrapDetf(address instance_, address bonder_, uint256 amount_) internal returns (uint256 id_) {
        uint256 shares_ = _fundSeShares(bonder_, amount_);
        vm.startPrank(bonder_);
        seShare.approve(instance_, shares_);
        (id_,) = ISingleStandardExchangeDETFBonding(instance_).bond(
            seShare, shares_, DEFAULT_MIN_LOCK, bonder_, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _enableSeigniorageIncentive(address instance_, uint256 incentive_) internal {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setSeigniorageIncentivePercentageOfVault(instance_, incentive_);
    }

    // D60: retain legacy test setup signatures only; current packages have mandatory gating.
    function _deployOpenThresholdDetf(string memory name_, string memory symbol_)
        internal
        returns (address detf_)
    {
        return _deployOpenModeDetf(name_, symbol_);
    }

    function _deployOpenModeDetf(string memory name_, string memory symbol_)
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
            mintThreshold: 0,
            burnThreshold: 0,

        expansionClosureRatePerSecond: 0,

            creator: address(0),
            claimName: "",
            claimSymbol: "",
            bondName: "",
            bondSymbol: "",
            reserveName: "",
            reserveSymbol: ""
        });
        vm.startPrank(owner);
        detf_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(singleStandardExchangeDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
        vm.label(detf_, name_);
    }

    function _assertNoFreeInventory(address instance_) internal view {
        assertEq(seShare.balanceOf(instance_), 0, "residual se vault shares");
        assertEq(IERC20(instance_).balanceOf(instance_), 0, "residual free detf");
        assertEq(IERC20(address(dai)).balanceOf(instance_), 0, "residual dai");
        assertEq(IERC20(address(usdc)).balanceOf(instance_), 0, "residual usdc");
    }

    function _bondNftVault(address instance_) internal view returns (IDETFNFTVault) {
        return IDETFNFTVault(ISingleStandardExchangeDETFInfo(instance_).bondNftVault());
    }

    function _feeTo() internal view returns (address) {
        return address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
    }
}
