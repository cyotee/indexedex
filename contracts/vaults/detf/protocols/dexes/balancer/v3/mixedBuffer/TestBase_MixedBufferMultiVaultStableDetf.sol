// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
// IVault used in _fundReserveBpt for live balances length
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {IRouter as IAerodromeRouter} from "@crane/contracts/protocols/dexes/aerodrome/v1/interfaces/IRouter.sol";
import {Pool} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Pool.sol";
import {MockERC20} from "@crane/contracts/test/mocks/MockERC20.sol";

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {IMixedBufferMultiVaultStablePoolPkg} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/IMixedBufferMultiVaultStablePoolPkg.sol";
import {
    MixedBufferMultiVaultStablePool_FactoryService
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePool_FactoryService.sol";
import {
    BalancerV3ConstantProductPool_FactoryService
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPool_FactoryService.sol";

import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {IMixedBufferMultiVaultStableDetfDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfDFPkg.sol";
import {
    MixedBufferMultiVaultStableDetf_Component_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetf_Component_FactoryService.sol";
import {IMixedBufferMultiVaultStableDetfBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfBonding.sol";
import {IMixedBufferMultiVaultStableDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfInfo.sol";
import {TestBase_FundedBalancerDETF} from "contracts/test/bases/TestBase_FundedBalancerDETF.sol";
/// @notice Actual Mixed Buffer pool, DETF and Aerodrome SE legs with shared funded child packages.
abstract contract TestBase_MixedBufferMultiVaultStableDetf is TestBase_FundedBalancerDETF {
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using MixedBufferMultiVaultStableDetf_Component_FactoryService for ICreate3FactoryProxy;
    using MixedBufferMultiVaultStableDetf_Component_FactoryService for IVaultRegistryDeployment;
    using MixedBufferMultiVaultStablePool_FactoryService for IVaultRegistryDeployment;
    uint256 internal constant BOOTSTRAP_BUFFER = 1_000e18;
    uint256 internal constant BOOTSTRAP_SHARE_FUND = 1_000e18;
    uint256 internal constant MBMVS_AMP = 200;
    IFacet internal mixedBufferDetfExchangeInFacet;
    IFacet internal mixedBufferDetfBondingFacet;
    IFacet internal mixedBufferDetfInfoFacet;
    // MixedBuffer pool package facets
    IFacet internal mbmvsBufferPoolFacet;
    IFacet internal mbmvsPoolLiquidityFacet;
    IFacet internal mbmvsHookFacet;
    IFacet internal balancerV3VaultAwareFacet;
    IFacet internal betterBalancerV3PoolTokenFacet;
    IFacet internal defaultPoolInfoFacet;
    IFacet internal standardSwapFeePercentageBoundsFacet;
    IFacet internal unbalancedLiquidityInvariantRatioBoundsFacet;
    IFacet internal balancerV3AuthenticationFacet;
    IFacet internal multiAssetBasicVaultFacetPool;
    IFacet internal multiAssetStandardVaultFacetPool;

    IMixedBufferMultiVaultStablePoolPkg internal mbmvsPkg;
    IMixedBufferMultiVaultStableDetfDFPkg internal mixedBufferDetfPkg;
    // SE vault legs sharing DAI buffer
    IStandardExchangeProxy[3] internal seVaults;
    IERC20[3] internal seShares;
    address[3] internal legTokenA;
    address[3] internal legTokenB;
    uint8 internal seVaultReady;
    uint8 internal fixtureBufferDecimals = 18;
    bool private mixedInfrastructureReady;

    address internal detf;
    IMixedBufferMultiVaultStableDetfInfo internal detfInfo;
    IMixedBufferMultiVaultStableDetfBonding internal detfBonding;
    IStandardExchangeIn internal detfExchangeIn;

    function setUp() public virtual override {
        _initializeMixedInfrastructure();
        _initializeMixedFixtureLegs();

        detf = _deployDetfN(1, 0, 0);
        detfInfo = IMixedBufferMultiVaultStableDetfInfo(detf);
        detfBonding = IMixedBufferMultiVaultStableDetfBonding(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
    }

    /// @dev Deploy actual protocols, manager and packages once per isolated test. Decimal
    /// matrices snapshot this common infrastructure, then deploy a fresh token/SE/DETF book
    /// for every assertion. All touched balances and protocol state roll back between books.
    function _initializeMixedInfrastructure() internal {
        if (mixedInfrastructureReady) return;
        super.setUp();

        mixedBufferDetfExchangeInFacet =
            MixedBufferMultiVaultStableDetf_Component_FactoryService.deployExchangeInFacet(create3Factory);
        mixedBufferDetfBondingFacet =
            MixedBufferMultiVaultStableDetf_Component_FactoryService.deployBondingFacet(create3Factory);
        mixedBufferDetfInfoFacet =
            MixedBufferMultiVaultStableDetf_Component_FactoryService.deployInfoFacet(create3Factory);

        _deployMixedBufferPoolPkg();
        _deployMixedBufferDetfPkg();

        mixedInfrastructureReady = true;
    }

    /// @dev Decimal fixtures customize token books while sharing all funded deployments.
    function _initializeMixedFixtureLegs() internal virtual {
        fixtureBufferDecimals = 18;
        // Seed N=1 SE vault from router TestBase daiUsdcVault
        seVaults[0] = daiUsdcVault;
        seShares[0] = IERC20(address(daiUsdcVault));
        legTokenA[0] = address(dai);
        legTokenB[0] = address(usdc);
        seVaultReady = 1;
    }

    function _fixtureBufferToken() internal view virtual returns (IERC20) {
        return IERC20(address(dai));
    }

    function _deployMixedBufferPoolPkg() internal {
        multiAssetBasicVaultFacetPool = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacetPool = create3Factory.deployMultiAssetStandardVaultFacet();
        balancerV3VaultAwareFacet =
            BalancerV3ConstantProductPool_FactoryService.deployBalancerV3VaultAwareFacet(create3Factory);
        betterBalancerV3PoolTokenFacet =
            BalancerV3ConstantProductPool_FactoryService.deployBalancerV3PoolTokenFacet(create3Factory);
        balancerV3AuthenticationFacet =
            BalancerV3ConstantProductPool_FactoryService.deployBalancerV3AuthenticationFacet(create3Factory);

        defaultPoolInfoFacet = IFacet(create3Factory.deployFacet(ArtifactCreationCode.creationCode(create3Factory, "DefaultPoolInfoFacet.sol:DefaultPoolInfoFacet"), keccak256("FundedMixed_DefaultPoolInfoFacet")));
        standardSwapFeePercentageBoundsFacet = IFacet(create3Factory.deployFacet(ArtifactCreationCode.creationCode(create3Factory, "StandardSwapFeePercentageBoundsFacet.sol:StandardSwapFeePercentageBoundsFacet"), keccak256("FundedMixed_StandardSwapFeePercentageBoundsFacet")));
        unbalancedLiquidityInvariantRatioBoundsFacet =
            IFacet(create3Factory.deployFacet(ArtifactCreationCode.creationCode(create3Factory, "StandardUnbalancedLiquidityInvariantRatioBoundsFacet.sol:StandardUnbalancedLiquidityInvariantRatioBoundsFacet"), keccak256("FundedMixed_StandardUnbalancedLiquidityInvariantRatioBoundsFacet")));

        mbmvsBufferPoolFacet =
            MixedBufferMultiVaultStablePool_FactoryService.deployMixedBufferMultiVaultStablePoolFacet(create3Factory);
        mbmvsPoolLiquidityFacet = MixedBufferMultiVaultStablePool_FactoryService
            .deployMixedBufferMultiVaultStableLiquidityFacet(create3Factory);
        mbmvsHookFacet =
            MixedBufferMultiVaultStablePool_FactoryService.deployMixedBufferMultiVaultStableHookFacet(create3Factory);

        IMixedBufferMultiVaultStablePoolPkg.PkgInit memory pkgInit;
        pkgInit.basicVaultFacet = multiAssetBasicVaultFacetPool;
        pkgInit.standardVaultFacet = multiAssetStandardVaultFacetPool;
        pkgInit.balancerV3VaultAwareFacet = balancerV3VaultAwareFacet;
        pkgInit.betterBalancerV3PoolTokenFacet = betterBalancerV3PoolTokenFacet;
        pkgInit.defaultPoolInfoFacet = defaultPoolInfoFacet;
        pkgInit.standardSwapFeePercentageBoundsFacet = standardSwapFeePercentageBoundsFacet;
        pkgInit.unbalancedLiquidityInvariantRatioBoundsFacet = unbalancedLiquidityInvariantRatioBoundsFacet;
        pkgInit.balancerV3AuthenticationFacet = balancerV3AuthenticationFacet;
        pkgInit.bufferPoolFacet = mbmvsBufferPoolFacet;
        pkgInit.poolLiquidityFacet = mbmvsPoolLiquidityFacet;
        pkgInit.hookFacet = mbmvsHookFacet;
        pkgInit.vaultRegistry = IVaultRegistryDeployment(address(indexedexManager));
        pkgInit.vaultFeeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        pkgInit.balancerV3Vault = IVault(address(vault));
        pkgInit.diamondFactory = diamondPackageFactory;
        pkgInit.rateProviderPkg = rateProviderPkg;

        vm.startPrank(owner);
        mbmvsPkg = MixedBufferMultiVaultStablePool_FactoryService.deployMixedBufferMultiVaultStablePoolPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
        vm.stopPrank();
        vm.label(address(mbmvsPkg), "MixedBufferMultiVaultStablePkg");
    }

    function _deployMixedBufferDetfPkg() internal {
        IMixedBufferMultiVaultStableDetfDFPkg.PkgInit memory pkgInit = IMixedBufferMultiVaultStableDetfDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacetDetf,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacetDetf,
            exchangeInFacet: mixedBufferDetfExchangeInFacet,
            bondingFacet: mixedBufferDetfBondingFacet,
            infoFacet: mixedBufferDetfInfoFacet,
            feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            balancerV3Router: IBalancerV3StandardExchangeRouterProxy(address(seRouter)),
            balancerV3Vault: IVault(address(vault)),
            mixedBufferPoolPkg: mbmvsPkg,
            bondNftVaultPkg: bondNftVaultPkg,
            rebasingClaimTokenPkg: rebasingClaimTokenPkg,
            syPkg: syPkg,
            diamondFactory: diamondPackageFactory
        });

        vm.startPrank(owner);
        mixedBufferDetfPkg = MixedBufferMultiVaultStableDetf_Component_FactoryService.deployPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
        vm.stopPrank();
        vm.label(address(mixedBufferDetfPkg), "MixedBufferMultiVaultStableDetfDFPkg");
    }

    function _ensureSeVaults(uint8 n) internal {
        require(n >= 1 && n <= 3, "n out of range");
        while (seVaultReady < n) {
            _deployExtraDaiSeVault(seVaultReady);
            unchecked {
                ++seVaultReady;
            }
        }
    }

    function _deployExtraDaiSeVault(uint8 idx) internal virtual {
        if (idx == 0) return; // already set from daiUsdcVault
        address tokenA = address(dai);
        address tokenB = idx == 1 ? address(weth) : address(usdc);
        // For idx 2 use a fresh MockERC20 pair with DAI to avoid PoolAlreadyExists if usdc already used.
        if (idx == 2) {
            MockERC20 extra = new MockERC20("ExtraB", "EXB", 18);
            tokenB = address(extra);
        }
        address poolAddr = aerodromePoolFactory.createPool(tokenA, tokenB, false);
        Pool(poolAddr);
        vm.label(poolAddr, string.concat("AeroDaiPair_", vm.toString(uint256(idx))));

        uint256 amt = AERODROME_POOL_INIT_AMOUNT;
        _mintToken(tokenA, address(this), amt);
        _mintToken(tokenB, address(this), amt);
        IERC20(tokenA).approve(address(aerodromeRouter), amt);
        IERC20(tokenB).approve(address(aerodromeRouter), amt);
        aerodromeRouter.addLiquidity(tokenA, tokenB, false, amt, amt, 1, 1, address(this), block.timestamp + 1 hours);

        address vaultAddr = aerodromeStandardExchangeDFPkg.deployVault(IPool(poolAddr));
        seVaults[idx] = IStandardExchangeProxy(vaultAddr);
        seShares[idx] = IERC20(vaultAddr);
        legTokenA[idx] = tokenA;
        legTokenB[idx] = tokenB;
        vm.label(vaultAddr, string.concat("SeVault_dai_", vm.toString(uint256(idx))));
    }

    function _mintToken(address token_, address to_, uint256 amount_) internal {
        if (token_ == address(weth)) {
            vm.deal(to_, amount_ + 1 ether);
            vm.prank(to_);
            weth.deposit{value: amount_}();
            return;
        }
        (bool ok,) = token_.call(abi.encodeWithSignature("mint(address,uint256)", to_, amount_));
        if (!ok) {
            MockERC20(token_).mint(to_, amount_);
        }
    }

    function _deployDetfN(uint8 n, uint256 mintThreshold_, uint256 burnThreshold_)
        internal
        returns (address detf_)
    {
        _ensureSeVaults(n);
        IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args =
            _buildPkgArgs(n, mintThreshold_, burnThreshold_);
        detf_ = _deployWithArgs(args);
        vm.label(detf_, string.concat("MixedBufferDetf_N", vm.toString(uint256(n))));
    }

    function _buildPkgArgs(uint8 n, uint256 mintTh_, uint256 burnTh_)
        internal
        view
        returns (IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args)
    {
        args.name = string.concat("MBMV Detf N", vm.toString(uint256(n)));
        args.symbol = string.concat("mbmvd", vm.toString(uint256(n)));
        args.bufferToken = _fixtureBufferToken();
        args.standardExchangeVaults = new IStandardExchange[](n);
        args.vaultShareRateProviders = new IRateProvider[](n);
        for (uint8 i; i < n; ++i) {
            args.standardExchangeVaults[i] = IStandardExchange(address(seVaults[i]));
            args.vaultShareRateProviders[i] = IRateProvider(address(0));
        }
        args.amplificationParameter = MBMVS_AMP;
        args.mintThreshold = mintTh_;
        args.burnThreshold = burnTh_;
        args.creator = address(0);
    }

    function _deployWithArgs(IMixedBufferMultiVaultStableDetfDFPkg.PkgArgs memory args)
        internal
        returns (address detf_)
    {
        vm.startPrank(owner);
        detf_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(mixedBufferDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }

    /// @dev Test payment amounts use the selected buffer's native units; WAD prices stay WAD.
    function _fixtureAmount(uint256 wad_) internal view returns (uint256) {
        uint8 decimals_ = fixtureBufferDecimals;
        return decimals_ >= 18 ? wad_ * 10 ** (decimals_ - 18) : wad_ / 10 ** (18 - decimals_);
    }

    function _fundBuffer(address to, uint256 amount) internal {
        _mintToken(address(_fixtureBufferToken()), to, amount);
    }

    function _fundVaultShares(uint8 leg, address to, uint256 tokenAmount)
        internal
        returns (uint256 shares_)
    {
        require(leg < seVaultReady, "leg");
        address tokenA = legTokenA[leg];
        address tokenB = legTokenB[leg];
        _mintToken(tokenA, to, tokenAmount);
        _mintToken(tokenB, to, tokenAmount);
        vm.startPrank(to);
        IERC20(tokenA).approve(address(aerodromeRouter), tokenAmount);
        IERC20(tokenB).approve(address(aerodromeRouter), tokenAmount);
        (,, uint256 liquidity) = aerodromeRouter.addLiquidity(
            tokenA, tokenB, false, tokenAmount, tokenAmount, 1, 1, to, block.timestamp + 1 hours
        );
        address asset_ = seVaults[leg].asset();
        IERC20(asset_).approve(address(seVaults[leg]), liquidity);
        shares_ = seVaults[leg].deposit(liquidity, to);
        vm.stopPrank();
    }

    function _bootstrapFirstBond(address instance_, address user, uint256 bufferAmt, uint256 shareFundWad)
        internal
        returns (uint256 tokenId_, uint256 bptPrincipal_, uint256 freeDetf_)
    {
        uint256 n_ = IMixedBufferMultiVaultStableDetfInfo(instance_).vaultCount();
        uint256[] memory shareAmts_ = new uint256[](n_);
        for (uint8 i; i < n_; ++i) {
            // Unrated SE shares retain their 18-decimal book. Rated legs are valued
            // in the native buffer unit by their actual SE rate provider.
            uint256 funding_ = IMixedBufferMultiVaultStableDetfInfo(instance_).rateProvider(i) == address(0)
                ? shareFundWad : _fixtureAmount(shareFundWad);
            shareAmts_[i] = _fundVaultShares(i, user, funding_);
        }
        _fundBuffer(user, bufferAmt);

        address[] memory shareTokens_ = IMixedBufferMultiVaultStableDetfInfo(instance_).vaultShares();
        IERC20 buffer_ = IERC20(IMixedBufferMultiVaultStableDetfInfo(instance_).bufferToken());

        vm.startPrank(user);
        buffer_.approve(instance_, bufferAmt);
        for (uint256 i; i < n_; ++i) {
            IERC20(shareTokens_[i]).approve(instance_, shareAmts_[i]);
        }
        (tokenId_, bptPrincipal_, freeDetf_) = IMixedBufferMultiVaultStableDetfBonding(instance_).bootstrapFirstBond(
            bufferAmt, shareAmts_, DEFAULT_MIN_LOCK, user, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _bootstrapDefault(address instance_, address user)
        internal
        returns (uint256 tokenId_, uint256 bpt_, uint256 freeDetf_)
    {
        return _bootstrapFirstBond(instance_, user, _fixtureAmount(BOOTSTRAP_BUFFER), BOOTSTRAP_SHARE_FUND);
    }

    function _mintDetfFromBuffer(address instance_, address user, uint256 bufferAmt)
        internal
        returns (uint256 out_)
    {
        IERC20 buffer_ = IERC20(IMixedBufferMultiVaultStableDetfInfo(instance_).bufferToken());
        _fundBuffer(user, bufferAmt);
        uint256 preview_ =
            IStandardExchangeIn(instance_).previewExchangeIn(buffer_, bufferAmt, IERC20(instance_));
        vm.startPrank(user);
        buffer_.approve(instance_, bufferAmt);
        out_ = IStandardExchangeIn(instance_).exchangeIn(
            buffer_, bufferAmt, IERC20(instance_), 0, user, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(preview_, out_, "mint buffer preview==exec");
    }

    function _mintDetfFromVaultShare(address instance_, uint8 leg, address user, uint256 fundAmt)
        internal
        returns (uint256 out_)
    {
        uint256 shares_ = _fundVaultShares(leg, user, fundAmt);
        address shareToken_ = IMixedBufferMultiVaultStableDetfInfo(instance_).vaultShares()[leg];
        uint256 preview_ =
            IStandardExchangeIn(instance_).previewExchangeIn(IERC20(shareToken_), shares_, IERC20(instance_));
        vm.startPrank(user);
        IERC20(shareToken_).approve(instance_, shares_);
        out_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(shareToken_), shares_, IERC20(instance_), 0, user, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(preview_, out_, "mint share preview==exec");
    }

    function _burnDetfToBuffer(address instance_, address user, uint256 detfAmount_)
        internal
        returns (uint256 out_)
    {
        IERC20 buffer_ = IERC20(IMixedBufferMultiVaultStableDetfInfo(instance_).bufferToken());
        uint256 preview_ =
            IStandardExchangeIn(instance_).previewExchangeIn(IERC20(instance_), detfAmount_, buffer_);
        vm.startPrank(user);
        IERC20(instance_).approve(instance_, detfAmount_);
        out_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), detfAmount_, buffer_, 0, user, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        // Proportional multi-leg exit + rejoin: same closed-form order as MultiVault (≤10 wei preferred).
        assertApproxEqAbs(preview_, out_, 10, "burn buffer preview==exec (le 10 wei)");
    }

    function _shiftUnderlyingPrice(uint8 leg_, bool buyTokenB_, uint256 amountIn_) internal {
        address tokenIn_ = buyTokenB_ ? legTokenA[leg_] : legTokenB[leg_];
        address tokenOut_ = buyTokenB_ ? legTokenB[leg_] : legTokenA[leg_];
        _mintToken(tokenIn_, bob, amountIn_);
        IAerodromeRouter.Route[] memory routes_ = new IAerodromeRouter.Route[](1);
        routes_[0] = IAerodromeRouter.Route({
            from: tokenIn_, to: tokenOut_, stable: false, factory: address(aerodromePoolFactory)
        });
        vm.startPrank(bob);
        IERC20(tokenIn_).approve(address(aerodromeRouter), amountIn_);
        aerodromeRouter.swapExactTokensForTokens(amountIn_, 0, routes_, bob, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function _assertInert(address instance_) internal view {
        assertFalse(IMixedBufferMultiVaultStableDetfInfo(instance_).isReserveLive(), "expected inert");
        assertEq(IERC20(instance_).totalSupply(), 0, "first bond starts issuance");
        assertEq(IMixedBufferMultiVaultStableDetfInfo(instance_).epochAnchor(), 0, "clock has not started");
    }

    function _assertLive(address instance_) internal view {
        IMixedBufferMultiVaultStableDetfInfo info_ = IMixedBufferMultiVaultStableDetfInfo(instance_);
        assertTrue(info_.isReserveLive(), "expected live");
        assertGt(IERC20(instance_).totalSupply(), 0);
        assertGt(IERC20(info_.reservePool()).balanceOf(info_.bondNftVault()), 0, "funded protocol liquidity");
        assertGt(info_.epochAnchor(), 0, "first bond anchored the clock");
    }

    function _assertNoFreeInventory(address instance_) internal view {
        assertLe(IERC20(instance_).balanceOf(instance_), 1, "residual free detf");
        IMixedBufferMultiVaultStableDetfInfo info_ = IMixedBufferMultiVaultStableDetfInfo(instance_);
        assertLe(IERC20(info_.bufferToken()).balanceOf(instance_), 1, "residual free buffer");
        address[] memory shares_ = info_.vaultShares();
        for (uint256 i_; i_ < shares_.length; ++i_) {
            assertLe(IERC20(shares_[i_]).balanceOf(instance_), 1, "residual vault share");
        }
    }

    function _useDetf(address instance_) internal {
        detf = instance_;
        detfInfo = IMixedBufferMultiVaultStableDetfInfo(instance_);
        detfBonding = IMixedBufferMultiVaultStableDetfBonding(instance_);
        detfExchangeIn = IStandardExchangeIn(instance_);
    }
}
