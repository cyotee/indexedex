// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {
    StablePoolDynamicData,
    IStablePool
} from '@crane/contracts/external/balancer/v3/interfaces/contracts/pool-stable/IStablePool.sol';
import {
    WeightedPoolDynamicData,
    IWeightedPool
} from '@crane/contracts/external/balancer/v3/interfaces/contracts/pool-weighted/IWeightedPool.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IPermit2} from '@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol';
import {IBalancerV3StandardExchangeRouterProxy} from 'contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol';

import {IDETFNFTVault} from 'contracts/interfaces/IDETFNFTVault.sol';
import {IRebasingClaimToken} from 'contracts/interfaces/IRebasingClaimToken.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {IDetfErrors} from 'contracts/interfaces/IDetfErrors.sol';
import {IVaultFeeOracleQuery} from 'contracts/interfaces/IVaultFeeOracleQuery.sol';
import {ComposedStableCommonDetfRepo} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfRepo.sol';
import {ComposedStableCommonDetfExchangeIn} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfExchangeIn.sol';
import {BalancerV3WeightedPoolQuote} from '@crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol';
import {ThresholdMode} from 'contracts/vaults/detf/core/DETFThresholdPolicy.sol';

contract MockMintableToken is IERC20 {
    string public name;
    string public symbol;
    uint8 public immutable decimals;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
    }

    function mint(address to, uint256 amount) external returns (bool) {
        balanceOf[to] += amount;
        totalSupply += amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MockStandardExchange is IStandardExchangeIn {
    MockMintableToken public immutable outputToken;
    uint256 public immutable num;
    uint256 public immutable den;

    IERC20 public lastTokenIn;
    IERC20 public lastTokenOut;
    uint256 public lastAmountIn;
    address public lastRecipient;

    constructor(MockMintableToken outputToken_, uint256 num_, uint256 den_) {
        outputToken = outputToken_;
        num = num_;
        den = den_;
    }

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        tokenIn;
        require(address(tokenOut) == address(outputToken), 'unexpected tokenOut');
        amountOut = amountIn * num / den;
    }

    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256,
        address recipient,
        bool,
        uint256
    ) external returns (uint256 amountOut) {
        require(address(tokenOut) == address(outputToken), 'unexpected tokenOut');
        lastTokenIn = tokenIn;
        lastTokenOut = tokenOut;
        lastAmountIn = amountIn;
        lastRecipient = recipient;
        amountOut = amountIn * num / den;
        outputToken.mint(recipient, amountOut);
    }
}

contract MockMintBondNFTVault {
    uint256 public constant protocolTokenId = 7;
    uint256 public lastProtocolTokenId;
    uint256 public lastProtocolShares;

    function detfNFTId() external pure returns (uint256) {
        return protocolTokenId;
    }

    function addToDETFNFT(uint256 tokenId, uint256 shares) external {
        lastProtocolTokenId = tokenId;
        lastProtocolShares = shares;
    }
}

contract ComposedStableCommonDetfExchangeInHarness is ComposedStableCommonDetfExchangeIn {
    struct StablePoolState {
        uint256[] balances;
        bool isInitialized;
    }

    struct WeightedPoolState {
        uint256[] balances;
        uint256[] weights;
        uint256 fee;
        uint256 totalSupply;
        bool isInitialized;
    }

    mapping(address => StablePoolState) internal stablePoolStates;
    mapping(address => WeightedPoolState) internal weightedPoolStates;

    uint256 internal syntheticPrice;
    uint256 internal seignioragePercentage;

    function initializeHarness(
        IWeightedPool reservePool_,
        IDETFNFTVault bondNftVault_,
        IERC20 detfToken_,
        IERC20 stablePoolBpt_,
        IERC20 commonPoolBpt_,
        IERC20 rateAsset_,
        IStablePool stablePool_,
        IStablePool commonPool_,
        IStandardExchangeIn reservePoolEntryRouter_,
        uint256 mintThreshold_,
        ComposedStableCommonDetfRepo.RouteConfig[] memory routes_
    ) external {
        ComposedStableCommonDetfRepo._initializePricing(
            reservePool_,
            bondNftVault_,
            IRebasingClaimToken(address(0)),
            detfToken_,
            stablePoolBpt_,
            commonPoolBpt_,
            rateAsset_,
            IStandardExchangeIn(address(0)),
            IStandardExchangeIn(address(0)),
            0,
            1,
            2
        );
        ComposedStableCommonDetfRepo._initializeExchangeIn(
            IPermit2(address(0)),
            IBalancerV3StandardExchangeRouterProxy(address(0)),
            stablePool_,
            commonPool_,
            reservePoolEntryRouter_,
            IVaultFeeOracleQuery(address(0)),
            mintThreshold_,
            0,
            ThresholdMode.Policy,
            routes_
        );
    }

    function setSyntheticPrice(uint256 syntheticPrice_) external {
        syntheticPrice = syntheticPrice_;
    }

    function setSeignioragePercentage(uint256 seignioragePercentage_) external {
        seignioragePercentage = seignioragePercentage_;
    }

    function setStablePoolState(address pool_, uint256[] memory balances_, bool isInitialized_) external {
        stablePoolStates[pool_].balances = balances_;
        stablePoolStates[pool_].isInitialized = isInitialized_;
    }

    function setWeightedPoolState(
        address pool_,
        uint256[] memory balances_,
        uint256[] memory weights_,
        uint256 fee_,
        uint256 totalSupply_,
        bool isInitialized_
    ) external {
        weightedPoolStates[pool_].balances = balances_;
        weightedPoolStates[pool_].weights = weights_;
        weightedPoolStates[pool_].fee = fee_;
        weightedPoolStates[pool_].totalSupply = totalSupply_;
        weightedPoolStates[pool_].isInitialized = isInitialized_;
    }

    function _syntheticDetfEthPrice() internal view override returns (uint256 syntheticPrice_) {
        syntheticPrice_ = syntheticPrice;
    }

    function _seigniorageIncentivePercentage() internal view override returns (uint256 percentage_) {
        percentage_ = seignioragePercentage;
    }

    function _stablePoolDynamicData(IStablePool pool_)
        internal
        view
        override
        returns (StablePoolDynamicData memory data_)
    {
        StablePoolState storage state = stablePoolStates[address(pool_)];
        data_.balancesLiveScaled18 = state.balances;
        data_.tokenRates = new uint256[](state.balances.length);
        data_.totalSupply = 1e18;
        data_.isPoolInitialized = state.isInitialized;
    }

    function _weightedPoolDynamicData(IWeightedPool pool_)
        internal
        view
        override
        returns (WeightedPoolDynamicData memory data_)
    {
        WeightedPoolState storage state = weightedPoolStates[address(pool_)];
        data_.balancesLiveScaled18 = state.balances;
        data_.tokenRates = new uint256[](state.balances.length);
        data_.staticSwapFeePercentage = state.fee;
        data_.totalSupply = state.totalSupply;
        data_.isPoolInitialized = state.isInitialized;
    }

    function _weightedPoolWeights(IWeightedPool pool_) internal view override returns (uint256[] memory weights_) {
        weights_ = weightedPoolStates[address(pool_)].weights;
    }
}

contract ComposedStableCommonDetfExchangeIn_Test is Test {
    MockMintableToken internal detfToken;
    MockMintableToken internal rateAsset;
    MockMintableToken internal commonToken;
    MockMintableToken internal routeAVaultToken;
    MockMintableToken internal routeBVaultToken;
    MockMintableToken internal stablePoolBpt;
    MockMintableToken internal commonPoolBpt;
    MockMintableToken internal reservePoolBpt;

    MockStandardExchange internal routeAUnderlying;
    MockStandardExchange internal routeBUnderlying;
    MockStandardExchange internal routeAStablePoolRouter;
    MockStandardExchange internal routeACommonPoolRouter;
    MockStandardExchange internal routeBStablePoolRouter;
    MockStandardExchange internal routeBCommonPoolRouter;
    MockStandardExchange internal reservePoolRouter;
    MockMintBondNFTVault internal bondNFTVault;

    ComposedStableCommonDetfExchangeInHarness internal harness;

    address internal user = makeAddr('user');

    function setUp() public {
        detfToken = new MockMintableToken('DETF', 'DETF', 18);
        rateAsset = new MockMintableToken('WETH', 'WETH', 18);
        commonToken = new MockMintableToken('COMMON', 'COMMON', 18);
        routeAVaultToken = new MockMintableToken('Vault A', 'vA', 18);
        routeBVaultToken = new MockMintableToken('Vault B', 'vB', 18);
        stablePoolBpt = new MockMintableToken('Stable Pool BPT', 'sBPT', 18);
        commonPoolBpt = new MockMintableToken('Common Pool BPT', 'cBPT', 18);
        reservePoolBpt = new MockMintableToken('Reserve Pool BPT', 'rBPT', 18);

        routeAUnderlying = new MockStandardExchange(routeAVaultToken, 2, 1);
        routeBUnderlying = new MockStandardExchange(routeBVaultToken, 2, 1);
        routeAStablePoolRouter = new MockStandardExchange(stablePoolBpt, 15, 10);
        routeACommonPoolRouter = new MockStandardExchange(commonPoolBpt, 15, 10);
        routeBStablePoolRouter = new MockStandardExchange(stablePoolBpt, 15, 10);
        routeBCommonPoolRouter = new MockStandardExchange(commonPoolBpt, 2, 1);
        reservePoolRouter = new MockStandardExchange(reservePoolBpt, 1, 1);
        bondNFTVault = new MockMintBondNFTVault();

        harness = new ComposedStableCommonDetfExchangeInHarness();

        ComposedStableCommonDetfRepo.RouteConfig[] memory routes = new ComposedStableCommonDetfRepo.RouteConfig[](2);
        routes[0] = ComposedStableCommonDetfRepo.RouteConfig({
            baseToken: commonToken,
            vaultToken: routeAVaultToken,
            underlyingVault: routeAUnderlying,
            stablePoolRouter: routeAStablePoolRouter,
            commonPoolRouter: routeACommonPoolRouter,
            stablePoolTokenIndex: 0,
            commonPoolTokenIndex: 0
        });
        routes[1] = ComposedStableCommonDetfRepo.RouteConfig({
            baseToken: commonToken,
            vaultToken: routeBVaultToken,
            underlyingVault: routeBUnderlying,
            stablePoolRouter: routeBStablePoolRouter,
            commonPoolRouter: routeBCommonPoolRouter,
            stablePoolTokenIndex: 1,
            commonPoolTokenIndex: 1
        });

        harness.initializeHarness(
            IWeightedPool(address(reservePoolBpt)),
            IDETFNFTVault(address(bondNFTVault)),
            detfToken,
            stablePoolBpt,
            commonPoolBpt,
            rateAsset,
            IStablePool(makeAddr('stablePool')),
            IStablePool(makeAddr('commonPool')),
            reservePoolRouter,
            1e18,
            routes
        );

        uint256[] memory stableBalances = new uint256[](2);
        stableBalances[0] = 10e18;
        stableBalances[1] = 50e18;
        harness.setStablePoolState(address(IStablePool(makeAddr('stablePool'))), stableBalances, true);

        uint256[] memory commonBalances = new uint256[](2);
        commonBalances[0] = 100e18;
        commonBalances[1] = 20e18;
        harness.setStablePoolState(address(IStablePool(makeAddr('commonPool'))), commonBalances, true);

        uint256[] memory reserveBalances = new uint256[](3);
        reserveBalances[0] = 600e18;
        reserveBalances[1] = 200e18;
        reserveBalances[2] = 200e18;

        uint256[] memory reserveWeights = new uint256[](3);
        reserveWeights[0] = 60e16;
        reserveWeights[1] = 20e16;
        reserveWeights[2] = 20e16;

        harness.setWeightedPoolState(address(reservePoolBpt), reserveBalances, reserveWeights, 0, 1000e18, true);
        harness.setSyntheticPrice(1001e15);
        harness.setSeignioragePercentage(10e16);

        commonToken.mint(user, 100e18);
        vm.prank(user);
        commonToken.approve(address(harness), type(uint256).max);
    }

    function test_previewExchangeIn_routesSharedTokenToLowestLiquidityVaultAndAppliesBoost() public {
        uint256 previewAmount = harness.previewExchangeIn(commonToken, 1e18, detfToken);

        uint256 routeBUnderlyingOut = 2e18;
        uint256 commonPoolBptOut = 4e18;
        uint256 boostedPoolBptIn = 44e17;

        uint256 grossExpected = BalancerV3WeightedPoolQuote.computeOutGivenExactInAfterFee(
            200e18,
            20e16,
            600e18,
            60e16,
            boostedPoolBptIn,
            0
        );
        uint256 expected = grossExpected - ((grossExpected * 10e16) / 2e18);

        assertEq(routeBUnderlyingOut, routeBUnderlying.previewExchangeIn(commonToken, 1e18, routeBVaultToken));
        assertEq(commonPoolBptOut, routeBCommonPoolRouter.previewExchangeIn(routeBVaultToken, routeBUnderlyingOut, commonPoolBpt));
        assertEq(previewAmount, expected);
    }

    function test_exchangeIn_mintsDetfAndUsesSelectedRouters() public {
        uint256 previewAmount = harness.previewExchangeIn(commonToken, 1e18, detfToken);
        uint256 grossMintAmount = BalancerV3WeightedPoolQuote.computeOutGivenExactInAfterFee(
            200e18,
            20e16,
            600e18,
            60e16,
            44e17,
            0
        );

        vm.prank(user);
        uint256 amountOut = harness.exchangeIn(commonToken, 1e18, detfToken, 0, user, false, block.timestamp + 1);

        assertEq(amountOut, previewAmount);
        assertEq(detfToken.balanceOf(user), previewAmount);
        assertEq(detfToken.balanceOf(address(bondNFTVault)), grossMintAmount - previewAmount);
        assertEq(bondNFTVault.lastProtocolTokenId(), 7);
        assertEq(bondNFTVault.lastProtocolShares(), 4e18);
        assertEq(address(routeBUnderlying.lastTokenIn()), address(commonToken));
        assertEq(address(routeBCommonPoolRouter.lastTokenIn()), address(routeBVaultToken));
        assertEq(address(reservePoolRouter.lastTokenIn()), address(commonPoolBpt));
    }

    function test_previewExchangeIn_revertsWhenMintingClosed() public {
        harness.setSyntheticPrice(1e18);

        vm.expectRevert(abi.encodeWithSelector(IDetfErrors.MintingNotAllowed.selector, 1e18, 1e18));
        harness.previewExchangeIn(commonToken, 1e18, detfToken);
    }

    function test_previewExchangeIn_revertsWhenReservePoolUninitialized() public {
        uint256[] memory reserveBalances = new uint256[](3);
        reserveBalances[0] = 600e18;
        reserveBalances[1] = 200e18;
        reserveBalances[2] = 200e18;

        uint256[] memory reserveWeights = new uint256[](3);
        reserveWeights[0] = 60e16;
        reserveWeights[1] = 20e16;
        reserveWeights[2] = 20e16;

        harness.setWeightedPoolState(address(reservePoolBpt), reserveBalances, reserveWeights, 0, 0, false);

        // Live-coupled mint gate: inert → MintingNotAllowed (not ReservePoolNotInitialized on mint path).
        vm.expectRevert(abi.encodeWithSelector(IDetfErrors.MintingNotAllowed.selector, 1001e15, 1e18));
        harness.previewExchangeIn(commonToken, 1e18, detfToken);
    }
}