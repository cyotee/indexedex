// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {
    MultiVaultWeightedDetfBondingFacet
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfBondingFacet.sol";
import {
    MultiVaultWeightedDetfInfoFacet
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoFacet.sol";
import {
    MultiVaultWeightedDetfExchangeInFacet
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfExchangeInFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {
    WeightedPoolFactory
} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {MockERC20} from "@crane/contracts/test/mocks/MockERC20.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {IMultiVaultWeightedDetfDFPkg} from "./MultiVaultWeightedDetfDFPkg.sol";
import {MultiVaultWeightedDetf_Component_FactoryService} from "./MultiVaultWeightedDetf_Component_FactoryService.sol";
import {IMultiVaultWeightedDetfBonding} from "./MultiVaultWeightedDetfBondingTarget.sol";
import {IMultiVaultWeightedDetfInfo} from "./MultiVaultWeightedDetfInfoTarget.sol";
import {TestBase_FundedBalancerDETF} from "contracts/test/bases/TestBase_FundedBalancerDETF.sol";

import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    ISingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETDFPkg.sol";
import {
    SingleStandardExchangeDETF_Component_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_Component_FactoryService.sol";
import {
    SingleStandardExchangeDETF_Pkg_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_Pkg_FactoryService.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @dev Historical test ABI only; these declarations do not install retired selectors.
interface ILegacyMultiVaultWeightedDetfBonding is IMultiVaultWeightedDetfBonding {
    function sellPositionToDetfNft(uint256 tokenId, uint256 minClaimOut, address recipient)
        external
        returns (uint256 claimMinted);
    function buyClaim(uint256 detfAmount, uint256 minClaimOut, address recipient, bool pretransferred, uint256 deadline)
        external
        returns (uint256 claimMinted);
    function previewBuyClaim(uint256 detfAmount) external view returns (uint256 claimMinted);
    function closeBondMature(uint256 tokenId, uint256[] calldata minAmountsOut, address recipient, uint256 deadline)
        external
        returns (uint256[] memory amountsOut);
    function previewCloseBondMature(uint256 tokenId) external view returns (uint256[] memory amountsOut);
    function redeemClaim(uint256 claimAmount, IERC20 tokenOut, uint256 minOut, address recipient, uint256 deadline)
        external
        returns (uint256 amountOut);
    function previewRedeemClaim(uint256 claimAmount, IERC20 tokenOut) external view returns (uint256 amountOut);
    function claimLiquidity(uint256 lpAmount, address recipient) external returns (uint256 amountOut);
    function protocolBondOriginalShares() external view returns (uint256);
}

/// @dev Historical test ABI only; these declarations do not install retired selectors.
interface ILegacyMultiVaultWeightedDetfInfo is IMultiVaultWeightedDetfInfo {
    function thresholdMode() external view returns (ThresholdMode);
    function expansionCatchUpMaxSeconds() external view returns (uint256);
    function expansionCatchUpCapBps() external view returns (uint256);
    function compoundProtocolRewards() external returns (uint256 detfIn, uint256 bptOut);
}

/// @notice Real one-to-seven-leg weighted reserves with shared funded child-package deployment.
abstract contract TestBase_MultiVaultWeightedDetf is TestBase_FundedBalancerDETF {
    using MultiVaultWeightedDetf_Component_FactoryService for ICreate3FactoryProxy;
    using MultiVaultWeightedDetf_Component_FactoryService for IVaultRegistryDeployment;
    uint8 internal constant MAX_LEGS = 7;
    IFacet internal multiVaultWeightedDetfExchangeInFacet;
    IFacet internal multiVaultWeightedDetfBondingFacet;
    IFacet internal multiVaultWeightedDetfInfoFacet;
    IMultiVaultWeightedDetfDFPkg internal multiVaultWeightedDetfPkg;
    IStandardExchangeProxy[MAX_LEGS] internal seVaults;
    IERC20[MAX_LEGS] internal seShares;
    IERC20[MAX_LEGS] internal rateAssets;
    address[MAX_LEGS] internal legTokenA;
    address[MAX_LEGS] internal legTokenB;
    bool[MAX_LEGS] internal legStable;
    uint8 internal seVaultReady;
    MockERC20 internal extraToken0;
    MockERC20 internal extraToken1;
    // D60: aliases retained only for compilation of the excluded legacy test corpus.
    IStandardExchangeProxy internal seVault0;
    IStandardExchangeProxy internal seVault1;
    IERC20 internal seShare0;
    IERC20 internal seShare1;
    IERC20 internal rateAsset0;
    IERC20 internal rateAsset1;
    IFacet internal singleSeDetfExchangeInFacet;
    ISingleStandardExchangeDETDFPkg internal singleSeDetfPkg;
    address internal detf;
    ILegacyMultiVaultWeightedDetfInfo internal detfInfo;
    ILegacyMultiVaultWeightedDetfBonding internal detfBonding;
    IStandardExchangeIn internal detfExchangeIn;

    function setUp() public virtual override {
        super.setUp();
        multiVaultWeightedDetfExchangeInFacet =
            MultiVaultWeightedDetf_Component_FactoryService.deployExchangeInFacet(create3Factory);
        multiVaultWeightedDetfBondingFacet =
            MultiVaultWeightedDetf_Component_FactoryService.deployBondingFacet(create3Factory);
        multiVaultWeightedDetfInfoFacet =
            MultiVaultWeightedDetf_Component_FactoryService.deployInfoFacet(create3Factory);
        _deployMultiVaultWeightedDetfPkg();
        _ensureSeVaults(2);
        seVault0 = seVaults[0];
        seVault1 = seVaults[1];
        seShare0 = seShares[0];
        seShare1 = seShares[1];
        rateAsset0 = rateAssets[0];
        rateAsset1 = rateAssets[1];
        _useDetf(_deployDetfN(1, 0, 0, true));
    }

    function _useDetf(address instance_) internal {
        detf = instance_;
        detfInfo = ILegacyMultiVaultWeightedDetfInfo(instance_);
        detfBonding = ILegacyMultiVaultWeightedDetfBonding(instance_);
        detfExchangeIn = IStandardExchangeIn(instance_);
    }

    function _deployMultiVaultWeightedDetfPkg() internal {
        IMultiVaultWeightedDetfDFPkg.PkgInit memory pkgInit = IMultiVaultWeightedDetfDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacetDetf,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacetDetf,
            exchangeInFacet: multiVaultWeightedDetfExchangeInFacet,
            bondingFacet: multiVaultWeightedDetfBondingFacet,
            infoFacet: multiVaultWeightedDetfInfoFacet,
            feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            balancerV3Router: IBalancerV3StandardExchangeRouterProxy(address(seRouter)),
            balancerV3Vault: IVault(address(vault)),
            weightedPoolFactory: WeightedPoolFactory(testPoolFactory),
            rateProviderPkg: rateProviderPkg,
            bondNftVaultPkg: bondNftVaultPkg,
            rebasingClaimTokenPkg: rebasingClaimTokenPkg,
            syPkg: syPkg,
            diamondFactory: diamondPackageFactory
        });

        vm.startPrank(owner);
        multiVaultWeightedDetfPkg = IVaultRegistryDeployment(address(indexedexManager)).deployPkg(pkgInit);
        vm.stopPrank();
        vm.label(address(multiVaultWeightedDetfPkg), "MultiVaultWeightedDetfDFPkg");
    }

    function _ensureSeVaults(uint8 n) internal {
        require(n >= 1 && n <= MAX_LEGS, "n out of range");
        while (seVaultReady < n) {
            _deploySeVaultAt(seVaultReady);
            unchecked {
                ++seVaultReady;
            }
        }
    }

    function _deploySeVaultAt(uint8 index) internal {
        // All volatile — Aerodrome SE package reverts PoolMustNotBeStable.
        // 0 dai/usdc (router TestBase vault)
        // 1 dai/weth
        // 2 usdc/weth
        // 3 extra0/dai
        // 4 extra0/usdc
        // 5 extra0/weth
        // 6 extra1/dai
        if (index == 0) {
            seVaults[0] = daiUsdcVault;
            seShares[0] = IERC20(address(daiUsdcVault));
            rateAssets[0] = IERC20(address(dai));
            legTokenA[0] = address(dai);
            legTokenB[0] = address(usdc);
            legStable[0] = false;
            vm.label(address(seVaults[0]), "SeVault0_DaiUsdc");
            return;
        }

        if (address(extraToken0) == address(0)) {
            extraToken0 = new MockERC20("Extra0", "EX0", 18);
            extraToken1 = new MockERC20("Extra1", "EX1", 18);
        }

        address tokenA_;
        address tokenB_;
        IERC20 rate_;
        if (index == 1) {
            tokenA_ = address(dai);
            tokenB_ = address(weth);
            rate_ = IERC20(address(weth));
        } else if (index == 2) {
            tokenA_ = address(usdc);
            tokenB_ = address(weth);
            rate_ = IERC20(address(usdc));
        } else if (index == 3) {
            tokenA_ = address(extraToken0);
            tokenB_ = address(dai);
            rate_ = IERC20(address(dai));
        } else if (index == 4) {
            tokenA_ = address(extraToken0);
            tokenB_ = address(usdc);
            rate_ = IERC20(address(usdc));
        } else if (index == 5) {
            tokenA_ = address(extraToken0);
            tokenB_ = address(weth);
            rate_ = IERC20(address(weth));
        } else {
            tokenA_ = address(extraToken1);
            tokenB_ = address(dai);
            rate_ = IERC20(address(dai));
        }

        address poolAddr = aerodromePoolFactory.createPool(tokenA_, tokenB_, false);
        _seedPoolLiquidity(tokenA_, tokenB_, false, 1_000e18);

        address vaultAddr = aerodromeStandardExchangeDFPkg.deployVault(IPool(poolAddr));
        seVaults[index] = IStandardExchangeProxy(vaultAddr);
        seShares[index] = IERC20(vaultAddr);
        rateAssets[index] = rate_;
        legTokenA[index] = tokenA_;
        legTokenB[index] = tokenB_;
        legStable[index] = false;
        vm.label(vaultAddr, string(abi.encodePacked("SeVault", _u(index))));
    }

    function _seedPoolLiquidity(address tokenA_, address tokenB_, bool stable_, uint256 amount_) internal {
        _mintToken(tokenA_, address(this), amount_);
        _mintToken(tokenB_, address(this), amount_);
        IERC20(tokenA_).approve(address(aerodromeRouter), amount_);
        IERC20(tokenB_).approve(address(aerodromeRouter), amount_);
        aerodromeRouter.addLiquidity(
            tokenA_, tokenB_, stable_, amount_, amount_, 1, 1, address(this), block.timestamp + 1 hours
        );
    }

    function _mintToken(address token_, address to_, uint256 amount_) internal {
        if (token_ == address(weth)) {
            vm.deal(to_, amount_ + 1 ether);
            vm.prank(to_);
            weth.deposit{value: amount_}();
            if (to_ != address(this)) {
                // already on to_
            }
            return;
        }
        // dai/usdc and MockERC20 expose mint in this test stack
        (bool ok,) = token_.call(abi.encodeWithSignature("mint(address,uint256)", to_, amount_));
        if (!ok) {
            // fallback: some tokens mint to msg.sender
            MockERC20(token_).mint(to_, amount_);
        }
    }

    function _u(uint8 i) internal pure returns (string memory) {
        if (i == 0) return "0";
        if (i == 1) return "1";
        if (i == 2) return "2";
        if (i == 3) return "3";
        if (i == 4) return "4";
        if (i == 5) return "5";
        return "6";
    }

    function _fillLegsAndWeights(
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args,
        uint8 n,
        bool rated_,
        uint256 vaultWeightBudget_
    ) internal view {
        uint256 remaining_ = vaultWeightBudget_;
        for (uint256 i; i < n; ++i) {
            args.vaults[i] = seVaults[i];
            args.vaultShares[i] = seShares[i];
            args.rateProviders[i] = IRateProvider(address(0));
            args.rateAssets[i] = rated_ ? rateAssets[i] : IERC20(address(0));
            if (i + 1 == n) {
                args.vaultWeights[i] = remaining_;
            } else {
                args.vaultWeights[i] = remaining_ / (n - i);
                remaining_ -= args.vaultWeights[i];
            }
            if (args.vaultWeights[i] == 0) args.vaultWeights[i] = 1;
        }
        uint256 sumW_;
        for (uint256 i; i < n; ++i) {
            sumW_ += args.vaultWeights[i];
        }
        args.weightDetf = 1e18 - sumW_;
        if (args.weightDetf == 0) {
            args.vaultWeights[n - 1] -= 1;
            args.weightDetf = 1;
        }
    }

    function _deployWithArgs(IMultiVaultWeightedDetfDFPkg.PkgArgs memory args) internal returns (address detf_) {
        vm.startPrank(owner);
        detf_ = indexedexManager.deployVault(IStandardVaultPkg(address(multiVaultWeightedDetfPkg)), abi.encode(args));
        vm.stopPrank();
    }

    function _fundSeSharesLeg(uint8 leg, address to, uint256 amount) internal returns (uint256 shares_) {
        require(leg < seVaultReady, "leg not ready");
        address tokenA_ = legTokenA[leg];
        address tokenB_ = legTokenB[leg];
        bool stable_ = legStable[leg];

        _mintToken(tokenA_, to, amount);
        _mintToken(tokenB_, to, amount);

        vm.startPrank(to);
        IERC20(tokenA_).approve(address(aerodromeRouter), amount);
        IERC20(tokenB_).approve(address(aerodromeRouter), amount);
        (,, uint256 liquidity) =
            aerodromeRouter.addLiquidity(tokenA_, tokenB_, stable_, amount, amount, 1, 1, to, block.timestamp + 1 hours);
        address asset_ = seVaults[leg].asset();
        IERC20(asset_).approve(address(seVaults[leg]), liquidity);
        shares_ = seVaults[leg].deposit(liquidity, to);
        vm.stopPrank();
    }

    function _buildPkgArgs(uint8 n_, uint256 mint_, uint256 burn_, bool rated_)
        internal
        view
        returns (IMultiVaultWeightedDetfDFPkg.PkgArgs memory args_)
    {
        args_.vaults = new IStandardExchangeProxy[](n_);
        args_.vaultShares = new IERC20[](n_);
        args_.rateProviders = new IRateProvider[](n_);
        args_.rateAssets = new IERC20[](n_);
        args_.vaultWeights = new uint256[](n_);
        args_.name = string(abi.encodePacked("Multi weighted ", vm.toString(n_)));
        args_.symbol = "mwDETF";
        args_.mintThreshold = mint_;
        args_.burnThreshold = burn_;
        _fillLegsAndWeights(args_, n_, rated_, 0.5e18);
    }

    function _deployDetfN(uint8 n_, uint256 mint_, uint256 burn_, bool rated_) internal returns (address) {
        _ensureSeVaults(n_);
        return _deployWithArgs(_buildPkgArgs(n_, mint_, burn_, rated_));
    }

    function _fundBootstrapAmounts(address instance_, address buyer_, uint256 amount_)
        internal
        returns (uint256[] memory shares_)
    {
        uint256 n_ = IMultiVaultWeightedDetfInfo(instance_).vaultCount();
        shares_ = new uint256[](n_);
        for (uint256 i; i < n_; ++i) {
            shares_[i] = _fundSeSharesLeg(uint8(i), buyer_, amount_);
            vm.prank(buyer_);
            seShares[i].approve(instance_, shares_[i]);
        }
    }

    function _bootstrapDetf(address instance_, address buyer_, uint256 amount_)
        internal
        returns (uint256 id_, uint256 lp_)
    {
        uint256[] memory shares_ = _fundBootstrapAmounts(instance_, buyer_, amount_);
        vm.prank(buyer_);
        return
            IMultiVaultWeightedDetfBonding(instance_)
                .initializeReserve(shares_, DEFAULT_MIN_LOCK, buyer_, block.timestamp);
    }

    function _bootstrapViaFirstBond(address buyer_, uint256 amount_) internal returns (uint256, uint256) {
        return _bootstrapDetf(detf, buyer_, amount_);
    }

    function _assertInert(address instance_) internal view {
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);
        assertFalse(info_.isReserveLive(), "reserve inert until first bond");
        assertEq(IERC20(instance_).totalSupply(), 0, "unfunded DETF cannot be issued");
        assertEq(info_.epochAnchor(), 0, "epoch clock has not started");
    }

    function _assertLive(address instance_) internal view {
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);
        assertTrue(info_.isReserveLive(), "reserve live after first bond");
        assertGt(IERC20(instance_).totalSupply(), 0, "funded DETF issued");
        assertGt(IERC20(info_.reservePool()).balanceOf(info_.bondNftVault()), 0, "protocol owns reserve LP");
        assertGt(info_.epochAnchor(), 0, "first bond starts fixed clock");
    }

    // D60 compilation maintenance: original setup helpers, no production API restoration.
    /// @dev Legacy caller signature only; the current package has no configurable mode.
    function _buildPkgArgs(uint8 n, uint256 mint, uint256 burn, bool rated, ThresholdMode)
        internal
        view
        returns (IMultiVaultWeightedDetfDFPkg.PkgArgs memory)
    {
        return _buildPkgArgs(n, mint, burn, rated);
    }

    function _deployDetfN(uint8 n, uint256 mint, uint256 burn, bool rated, ThresholdMode) internal returns (address) {
        return _deployDetfN(n, mint, burn, rated);
    }

    function _warpPastUnlock(address instance_, uint256 tokenId_) internal {
        address nft_ = IMultiVaultWeightedDetfInfo(instance_).bondNftVault();
        uint256 unlock_ = IDetfBondNFT(nft_).positionOf(tokenId_).startTimestamp
            + IDetfBondNFT(nft_).positionOf(tokenId_).vestingDuration;
        if (block.timestamp <= unlock_) {
            vm.warp(unlock_ + 1);
        }
    }

    function _deploySingleSeDetfPkg() internal {
        singleSeDetfExchangeInFacet =
            SingleStandardExchangeDETF_Component_FactoryService.deployExchangeInFacet(create3Factory);
        ISingleStandardExchangeDETDFPkg.PkgInit memory pkgInit = ISingleStandardExchangeDETDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacetDetf,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacetDetf,
            exchangeInFacet: singleSeDetfExchangeInFacet,
            bondingFacet: SingleStandardExchangeDETF_Component_FactoryService.deployBondingFacet(create3Factory),
            feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            balancerV3Router: IBalancerV3StandardExchangeRouterProxy(address(seRouter)),
            balancerV3Vault: IVault(address(vault)),
            weightedPoolFactory: WeightedPoolFactory(testPoolFactory),
            rateProviderPkg: rateProviderPkg,
            bondNftVaultPkg: bondNftVaultPkg,
            rebasingClaimTokenPkg: rebasingClaimTokenPkg,
            syPkg: syPkg,
            diamondFactory: diamondPackageFactory
        });
        vm.startPrank(owner);
        singleSeDetfPkg = SingleStandardExchangeDETF_Pkg_FactoryService.deploySingleStandardExchangeDETDFPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
        vm.stopPrank();
    }

    function _deployDetfNMixedRated(uint8 n, uint256 mintThreshold_, uint256 burnThreshold_)
        internal
        returns (address detf_)
    {
        return _deployDetfNMixedRated(n, mintThreshold_, burnThreshold_, ThresholdMode.Policy);
    }

    function _deployDetfNMixedRated(uint8 n, uint256 mintThreshold_, uint256 burnThreshold_, ThresholdMode mode_)
        internal
        returns (address detf_)
    {
        _ensureSeVaults(n);
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args = _buildPkgArgs(n, mintThreshold_, burnThreshold_, true, mode_);
        args.name = "MVW Mixed";
        args.symbol = "mvwM";
        for (uint256 i = 1; i < n; ++i) {
            args.rateAssets[i] = IERC20(address(0));
        }
        detf_ = _deployWithArgs(args);
    }

    function _deployDetfN2SameRateAsset(uint256 mintThreshold_, uint256 burnThreshold_)
        internal
        returns (address detf_)
    {
        return _deployDetfN2SameRateAsset(mintThreshold_, burnThreshold_, ThresholdMode.Policy);
    }

    function _deployDetfN2SameRateAsset(uint256 mintThreshold_, uint256 burnThreshold_, ThresholdMode mode_)
        internal
        returns (address detf_)
    {
        // Legs 0 (dai/usdc) and 3 (extra0/dai) both rate as dai — distinct vaults.
        _ensureSeVaults(4);
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args;
        args.vaults = new IStandardExchangeProxy[](2);
        args.vaultShares = new IERC20[](2);
        args.rateProviders = new IRateProvider[](2);
        args.rateAssets = new IERC20[](2);
        args.vaultWeights = new uint256[](2);
        args.vaults[0] = seVaults[0];
        args.vaults[1] = seVaults[3];
        args.vaultShares[0] = IERC20(address(seVaults[0]));
        args.vaultShares[1] = IERC20(address(seVaults[3]));
        args.rateAssets[0] = IERC20(address(dai));
        args.rateAssets[1] = IERC20(address(dai));
        args.vaultWeights[0] = 20e16;
        args.vaultWeights[1] = 20e16;
        args.weightDetf = 60e16;
        args.mintThreshold = mintThreshold_;
        args.burnThreshold = burnThreshold_;

        args.expansionClosureRatePerSecond = 0;

        args.name = "MVW SameRate";
        args.symbol = "mvwSR";
        detf_ = _deployWithArgs(args);
    }

    function _deployOpenThresholdDetf() internal returns (address) {
        return _deployOpenModeDetfN(1);
    }

    function _deployOpenThresholdDetfN(uint8 n) internal returns (address) {
        return _deployOpenModeDetfN(n);
    }

    function _deployOpenModeDetfN(uint8 n) internal returns (address) {
        return _deployDetfN(n, 0, 0, true, ThresholdMode.Open);
    }

    function _deployNestedSingleSeDetfLive(address bonder, uint256 lpAmount) internal returns (address nested_) {
        return _deployNestedSingleSeDetfLive(bonder, lpAmount, ThresholdMode.Open);
    }

    function _deployNestedSingleSeDetfLive(address bonder, uint256 lpAmount, ThresholdMode mode_)
        internal
        returns (address nested_)
    {
        if (address(singleSeDetfPkg) == address(0)) _deploySingleSeDetfPkg();
        _ensureSeVaults(1);
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args = ISingleStandardExchangeDETDFPkg.PkgArgs({
            name: "Nested Single SE DETF",
            symbol: "nSSE",
            standardExchangeVault: seVaults[0],
            standardExchangeVaultShare: IERC20(address(0)),
            rateTarget: rateAssets[0],
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
        nested_ = indexedexManager.deployVault(IStandardVaultPkg(address(singleSeDetfPkg)), abi.encode(args));
        vm.stopPrank();

        uint256 seShares_ = _fundSeSharesLeg(0, bonder, lpAmount);
        vm.startPrank(bonder);
        seShares[0].approve(nested_, seShares_);
        ISingleStandardExchangeDETFBonding(nested_)
            .bond(seShares[0], seShares_, DEFAULT_MIN_LOCK, bonder, false, block.timestamp + 1 hours);
        vm.stopPrank();
        require(ISingleStandardExchangeDETFInfo(nested_).isReserveLive(), "nested not live");
    }

    function _deployOuterOverNested(address nestedDetf_, uint256 mintTh_, uint256 burnTh_)
        internal
        returns (address outer_)
    {
        // mint=1 burn=max was dual-path always-allow; map to Open under §16.3.
        if (mintTh_ == 1 && burnTh_ == type(uint256).max) {
            return _deployOuterOverNested(nestedDetf_, 0, 0, ThresholdMode.Open);
        }
        return _deployOuterOverNested(nestedDetf_, mintTh_, burnTh_, ThresholdMode.Policy);
    }

    function _deployOuterOverNested(address nestedDetf_, uint256 mintTh_, uint256 burnTh_, ThresholdMode mode_)
        internal
        returns (address outer_)
    {
        _ensureSeVaults(2);
        IStandardExchangeProxy[] memory vaults_ = new IStandardExchangeProxy[](2);
        IERC20[] memory shares_ = new IERC20[](2);
        IRateProvider[] memory rps_ = new IRateProvider[](2);
        IERC20[] memory ras_ = new IERC20[](2);
        uint256[] memory weights_ = new uint256[](2);
        vaults_[0] = IStandardExchangeProxy(nestedDetf_);
        vaults_[1] = seVaults[1];
        shares_[0] = IERC20(nestedDetf_);
        shares_[1] = seShares[1];
        ras_[0] = IERC20(address(0)); // abstract 1:1 for nested DETF share
        ras_[1] = rateAssets[1];
        weights_[0] = 20e16;
        weights_[1] = 20e16;

        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args = IMultiVaultWeightedDetfDFPkg.PkgArgs({
            name: "Outer MVW Nested",
            symbol: "omvwN",
            vaults: vaults_,
            vaultShares: shares_,
            rateProviders: rps_,
            rateAssets: ras_,
            weightDetf: 60e16,
            vaultWeights: weights_,
            mintThreshold: mintTh_,
            burnThreshold: burnTh_,
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
        outer_ = indexedexManager.deployVault(IStandardVaultPkg(address(multiVaultWeightedDetfPkg)), abi.encode(args));
        vm.stopPrank();
    }

    function _fundSeShares0(address to, uint256 lpAmount) internal returns (uint256 shares_) {
        shares_ = _fundSeSharesLeg(0, to, lpAmount);
    }

    function _fundSeShares1(address to, uint256 amount) internal returns (uint256 shares_) {
        shares_ = _fundSeSharesLeg(1, to, amount);
    }

    function _fundNestedDetfShares(address nested_, address to, uint256 lpAmount)
        internal
        returns (uint256 nestedShares_)
    {
        uint256 seShares_ = _fundSeSharesLeg(0, to, lpAmount);
        vm.startPrank(to);
        seShares[0].approve(nested_, seShares_);
        nestedShares_ = IStandardExchangeIn(nested_)
            .exchangeIn(seShares[0], seShares_, IERC20(nested_), 0, to, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function _goLiveViaBptBond(address instance_, address user, uint256 lpAmount)
        internal
        returns (uint256 tokenId_, uint256 bpt_)
    {
        uint256 n_ = IMultiVaultWeightedDetfInfo(instance_).vaultCount();
        uint256[] memory amounts_ = new uint256[](n_);
        address[] memory shareTokens_ = IMultiVaultWeightedDetfInfo(instance_).vaultShares();

        for (uint256 i; i < n_; ++i) {
            amounts_[i] = _fundSharesForInstanceLeg(instance_, i, user, lpAmount);
        }

        vm.startPrank(user);
        for (uint256 i; i < n_; ++i) {
            IERC20(shareTokens_[i]).approve(instance_, amounts_[i]);
        }
        (tokenId_, bpt_) = IMultiVaultWeightedDetfBonding(instance_)
            .initializeReserve(amounts_, DEFAULT_MIN_LOCK, user, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function _closeMinOut(address instance_) internal view returns (uint256[] memory minOut_) {
        minOut_ = new uint256[](IMultiVaultWeightedDetfInfo(instance_).vaultCount() + 1);
    }

    function _fundSharesForInstanceLeg(address instance_, uint256 legIndex_, address user, uint256 lpAmount)
        internal
        returns (uint256 shares_)
    {
        address share_ = IMultiVaultWeightedDetfInfo(instance_).vaultShares()[legIndex_];
        address vault_ = IMultiVaultWeightedDetfInfo(instance_).underlyingVaults()[legIndex_];

        // Nested DETF: share is the nested diamond address.
        if (share_ == vault_ && !_isKnownSeVault(vault_)) {
            return _fundNestedDetfShares(vault_, user, lpAmount);
        }

        // Find matching seVaults slot
        for (uint8 i; i < seVaultReady; ++i) {
            if (address(seVaults[i]) == vault_ || address(seShares[i]) == share_) {
                return _fundSeSharesLeg(i, user, lpAmount);
            }
        }
        // Fallback: deposit into vault via asset()
        return _fundSeSharesLeg(0, user, lpAmount);
    }

    function _isKnownSeVault(address vault_) internal view returns (bool) {
        for (uint8 i; i < seVaultReady; ++i) {
            if (address(seVaults[i]) == vault_) return true;
        }
        return false;
    }

    function _mintOnLeg(address instance_, uint8 legIndex_, address user, uint256 lpAmount)
        internal
        returns (uint256 out_)
    {
        uint256 shares_ = _fundSharesForInstanceLeg(instance_, legIndex_, user, lpAmount);
        address shareToken_ = IMultiVaultWeightedDetfInfo(instance_).vaultShares()[legIndex_];
        uint256 preview_ =
            IStandardExchangeIn(instance_).previewExchangeIn(IERC20(shareToken_), shares_, IERC20(instance_));
        vm.startPrank(user);
        IERC20(shareToken_).approve(instance_, shares_);
        out_ = IStandardExchangeIn(instance_)
            .exchangeIn(IERC20(shareToken_), shares_, IERC20(instance_), 0, user, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(preview_, out_, "mint preview==exec");
    }

    function _burnToLeg(address instance_, uint8 legIndex_, address user, uint256 detfAmount_)
        internal
        returns (uint256 out_)
    {
        address shareToken_ = IMultiVaultWeightedDetfInfo(instance_).vaultShares()[legIndex_];
        uint256 preview_ =
            IStandardExchangeIn(instance_).previewExchangeIn(IERC20(instance_), detfAmount_, IERC20(shareToken_));
        vm.startPrank(user);
        IERC20(instance_).approve(instance_, detfAmount_);
        out_ = IStandardExchangeIn(instance_)
            .exchangeIn(IERC20(instance_), detfAmount_, IERC20(shareToken_), 0, user, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertApproxEqAbs(preview_, out_, 10, "burn preview~=exec");
    }

    function _assertNoFreeInventory(address instance_) internal view {
        assertEq(IERC20(instance_).balanceOf(instance_), 0, "residual free detf");
        address[] memory shares_ = IMultiVaultWeightedDetfInfo(instance_).vaultShares();
        for (uint256 i; i < shares_.length; ++i) {
            assertEq(IERC20(shares_[i]).balanceOf(instance_), 0, "residual vault share");
        }
    }

    function _feeTo() internal view returns (address) {
        return address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
    }

    function _deployOpenModeDetf(string memory name_, string memory symbol_) internal returns (address detf_) {
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args = _buildPkgArgs(1, 0, 0, true, ThresholdMode.Open);
        args.name = name_;
        args.symbol = symbol_;
        args.creator = address(0);
        detf_ = _deployWithArgs(args);
        vm.label(detf_, name_);
    }

    function _bondNftVault(address instance_) internal view returns (IDETFNFTVault) {
        return IDETFNFTVault(IMultiVaultWeightedDetfInfo(instance_).bondNftVault());
    }
}
