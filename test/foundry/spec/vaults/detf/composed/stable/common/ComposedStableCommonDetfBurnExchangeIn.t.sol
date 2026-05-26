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

import {IProtocolNFTVault} from 'contracts/interfaces/IProtocolNFTVault.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {IRICHIR} from 'contracts/interfaces/IRICHIR.sol';
import {IVaultFeeOracleQuery} from 'contracts/interfaces/IVaultFeeOracleQuery.sol';
import {IBalancerV3StandardExchangeRouterProxy} from 'contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol';
import {ComposedStableCommonDetfRepo} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfRepo.sol';
import {ComposedStableCommonDetfExchangeIn} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfExchangeIn.sol';
import {BalancerV3WeightedPoolQuote} from '@crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol';

contract BurnInMockToken is IERC20 {
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

    function mint(address to, uint256 amount) external returns (bool) {
        balanceOf[to] += amount;
        totalSupply += amount;
        return true;
    }

    function burn(address from, uint256 amount) external returns (bool) {
        balanceOf[from] -= amount;
        totalSupply -= amount;
        return true;
    }
}

contract BurnInMockPermit2 {
    function approve(address, address, uint160, uint48) external pure {}
}

contract BurnInMockBalancerRouter {
    uint256 internal nextAmountOut;

    function setNextAmountOut(uint256 nextAmountOut_) external {
        nextAmountOut = nextAmountOut_;
    }

    function swapSingleTokenExactIn(
        address,
        IERC20,
        address,
        IERC20 tokenOut,
        address,
        uint256 exactAmountIn,
        uint256,
        uint256,
        bool,
        bytes calldata
    ) external returns (uint256 amountOut) {
        amountOut = nextAmountOut == 0 ? exactAmountIn : nextAmountOut;
        BurnInMockToken(address(tokenOut)).mint(msg.sender, amountOut);
        nextAmountOut = 0;
    }
}

contract BurnInMockRateExchange is IStandardExchangeIn {
    struct Rate {
        uint256 num;
        uint256 den;
    }

    mapping(bytes32 => Rate) internal rates;

    function setRate(IERC20 tokenIn, IERC20 tokenOut, uint256 num, uint256 den) external {
        rates[keccak256(abi.encode(address(tokenIn), address(tokenOut)))] = Rate({num: num, den: den});
    }

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        Rate memory rate = rates[keccak256(abi.encode(address(tokenIn), address(tokenOut)))];
        require(rate.den != 0, 'missing rate');
        tokenIn;
        amountOut = amountIn * rate.num / rate.den;
    }

    function exchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256, address recipient, bool, uint256)
        external
        returns (uint256 amountOut)
    {
        Rate memory rate = rates[keccak256(abi.encode(address(tokenIn), address(tokenOut)))];
        require(rate.den != 0, 'missing rate');
        tokenIn;
        amountOut = amountIn * rate.num / rate.den;
        BurnInMockToken(address(tokenOut)).mint(recipient, amountOut);
    }
}

contract ComposedStableCommonDetfBurnExchangeInHarness is ComposedStableCommonDetfExchangeIn {
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

    ComposedStableCommonDetfRepo.RouteConfig internal route0;
    ComposedStableCommonDetfRepo.RouteConfig internal route1;

    function initializePricingHarness(
        IWeightedPool reservePool_,
        IERC20 detfToken_,
        IERC20 stablePoolBpt_,
        IERC20 commonPoolBpt_,
        IERC20 wethToken_,
        IStandardExchangeIn stablePoolExitPricer_,
        IStandardExchangeIn commonPoolExitPricer_
    ) external {
        ComposedStableCommonDetfRepo._initializePricing(
            reservePool_,
            IProtocolNFTVault(address(0)),
            IRICHIR(address(0)),
            detfToken_,
            stablePoolBpt_,
            commonPoolBpt_,
            wethToken_,
            stablePoolExitPricer_,
            commonPoolExitPricer_,
            0,
            1,
            2
        );
    }

    function configureRoute(
        uint256 index_,
        IERC20 baseToken_,
        IERC20 vaultToken_,
        IStandardExchangeIn underlyingVault_,
        uint256 stablePoolTokenIndex_,
        uint256 commonPoolTokenIndex_
    ) external {
        ComposedStableCommonDetfRepo.RouteConfig storage route = index_ == 0 ? route0 : route1;
        route.baseToken = baseToken_;
        route.vaultToken = vaultToken_;
        route.underlyingVault = underlyingVault_;
        route.stablePoolRouter = IStandardExchangeIn(address(0));
        route.commonPoolRouter = IStandardExchangeIn(address(0));
        route.stablePoolTokenIndex = stablePoolTokenIndex_;
        route.commonPoolTokenIndex = commonPoolTokenIndex_;
    }

    function initializeExchangeHarness(
        IStablePool stablePool_,
        IStablePool commonPool_,
        IPermit2 permit2_,
        IBalancerV3StandardExchangeRouterProxy balancerV3Router_,
        uint256 burnThreshold_
    ) external {
        ComposedStableCommonDetfRepo.RouteConfig[] memory routes_ = new ComposedStableCommonDetfRepo.RouteConfig[](2);
        routes_[0] = route0;
        routes_[1] = route1;
        ComposedStableCommonDetfRepo._initializeExchangeIn(
            permit2_,
            balancerV3Router_,
            stablePool_,
            commonPool_,
            IStandardExchangeIn(address(0)),
            IVaultFeeOracleQuery(address(0)),
            0,
            burnThreshold_,
            routes_
        );
    }

    function setSyntheticPrice(uint256 syntheticPrice_) external {
        syntheticPrice = syntheticPrice_;
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

contract ComposedStableCommonDetfBurnExchangeIn_Test is Test {
    BurnInMockToken internal detfToken;
    BurnInMockToken internal wethToken;
    BurnInMockToken internal commonToken;
    BurnInMockToken internal routeAVaultToken;
    BurnInMockToken internal routeBVaultToken;
    BurnInMockToken internal stablePoolBpt;
    BurnInMockToken internal commonPoolBpt;
    BurnInMockToken internal reservePoolToken;

    BurnInMockRateExchange internal routeAUnderlying;
    BurnInMockRateExchange internal routeBUnderlying;
    BurnInMockRateExchange internal stablePoolExitPricer;
    BurnInMockRateExchange internal commonPoolExitPricer;
    BurnInMockPermit2 internal permit2;
    BurnInMockBalancerRouter internal balancerRouter;

    ComposedStableCommonDetfBurnExchangeInHarness internal harness;
    IStablePool internal stablePool;
    IStablePool internal commonPool;

    function setUp() public {
        detfToken = new BurnInMockToken('DETF', 'DETF', 18);
        wethToken = new BurnInMockToken('WETH', 'WETH', 18);
        commonToken = new BurnInMockToken('COMMON', 'COMMON', 18);
        routeAVaultToken = new BurnInMockToken('Vault A', 'vA', 18);
        routeBVaultToken = new BurnInMockToken('Vault B', 'vB', 18);
        stablePoolBpt = new BurnInMockToken('Stable Pool BPT', 'sBPT', 18);
        commonPoolBpt = new BurnInMockToken('Common Pool BPT', 'cBPT', 18);
        reservePoolToken = new BurnInMockToken('Reserve Pool', 'rBPT', 18);

        routeAUnderlying = new BurnInMockRateExchange();
        routeBUnderlying = new BurnInMockRateExchange();
        stablePoolExitPricer = new BurnInMockRateExchange();
        commonPoolExitPricer = new BurnInMockRateExchange();
        permit2 = new BurnInMockPermit2();
        balancerRouter = new BurnInMockBalancerRouter();
        stablePool = IStablePool(makeAddr('stablePool'));
        commonPool = IStablePool(makeAddr('commonPool'));

        harness = new ComposedStableCommonDetfBurnExchangeInHarness();
        harness.initializePricingHarness(
            IWeightedPool(address(reservePoolToken)),
            detfToken,
            stablePoolBpt,
            commonPoolBpt,
            wethToken,
            stablePoolExitPricer,
            commonPoolExitPricer
        );
        harness.configureRoute(0, commonToken, routeAVaultToken, routeAUnderlying, 0, 0);
        harness.configureRoute(1, commonToken, routeBVaultToken, routeBUnderlying, 1, 1);
        harness.initializeExchangeHarness(
            stablePool,
            commonPool,
            IPermit2(address(permit2)),
            IBalancerV3StandardExchangeRouterProxy(address(balancerRouter)),
            1e18
        );

        uint256[] memory reserveBalances = new uint256[](3);
        reserveBalances[0] = 600e18;
        reserveBalances[1] = 200e18;
        reserveBalances[2] = 200e18;

        uint256[] memory reserveWeights = new uint256[](3);
        reserveWeights[0] = 60e16;
        reserveWeights[1] = 20e16;
        reserveWeights[2] = 20e16;

        harness.setWeightedPoolState(address(reservePoolToken), reserveBalances, reserveWeights, 0, 1000e18, true);
        harness.setSyntheticPrice(999e15);

        uint256[] memory stableBalances = new uint256[](2);
        stableBalances[0] = 10e18;
        stableBalances[1] = 50e18;
        harness.setStablePoolState(address(stablePool), stableBalances, true);

        uint256[] memory commonBalances = new uint256[](2);
        commonBalances[0] = 100e18;
        commonBalances[1] = 20e18;
        harness.setStablePoolState(address(commonPool), commonBalances, true);

        routeAUnderlying.setRate(routeAVaultToken, commonToken, 3, 1);
        routeBUnderlying.setRate(routeBVaultToken, commonToken, 2, 1);

        stablePoolExitPricer.setRate(stablePoolBpt, routeAVaultToken, 5, 3);
        stablePoolExitPricer.setRate(stablePoolBpt, routeBVaultToken, 3, 1);

        commonPoolExitPricer.setRate(commonPoolBpt, routeAVaultToken, 4, 3);
        commonPoolExitPricer.setRate(commonPoolBpt, routeBVaultToken, 1, 1);
    }

    function test_previewExchangeIn_selectsMostLiquidEligibleRouteAndPoolLeg() public view {
        uint256 detfAmountIn = 1e18;
        uint256 commonPoolBptAmountOut = BalancerV3WeightedPoolQuote.computeOutGivenExactInAfterFee(
            600e18,
            60e16,
            200e18,
            20e16,
            detfAmountIn,
            0
        );
        uint256 vaultTokenAmountOut = commonPoolExitPricer.previewExchangeIn(commonPoolBpt, commonPoolBptAmountOut, routeAVaultToken);
        uint256 expected = routeAUnderlying.previewExchangeIn(routeAVaultToken, vaultTokenAmountOut, commonToken);

        uint256 previewAmountOut = harness.previewExchangeIn(detfToken, detfAmountIn, commonToken);

        assertEq(previewAmountOut, expected);
    }

    function test_exchangeIn_executesMostLiquidRoute() public {
        uint256 detfAmountIn = 1e18;
        uint256 commonPoolBptAmountOut = BalancerV3WeightedPoolQuote.computeOutGivenExactInAfterFee(
            600e18,
            60e16,
            200e18,
            20e16,
            detfAmountIn,
            0
        );
        uint256 expectedAmountOut = harness.previewExchangeIn(detfToken, detfAmountIn, commonToken);

        balancerRouter.setNextAmountOut(commonPoolBptAmountOut);

        detfToken.mint(address(this), detfAmountIn);
        detfToken.approve(address(harness), detfAmountIn);

        uint256 amountOut = harness.exchangeIn(
            detfToken,
            detfAmountIn,
            commonToken,
            0,
            address(this),
            false,
            block.timestamp + 1
        );

        assertEq(amountOut, expectedAmountOut);
        assertEq(commonToken.balanceOf(address(this)), expectedAmountOut);
    }
}