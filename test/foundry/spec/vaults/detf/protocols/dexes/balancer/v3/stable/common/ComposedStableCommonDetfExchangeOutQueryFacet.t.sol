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

import {IDETFNFTVault} from 'contracts/interfaces/IDETFNFTVault.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {IStandardExchangeErrors} from 'contracts/interfaces/IStandardExchangeErrors.sol';
import {IStandardExchangeOut} from 'contracts/interfaces/IStandardExchangeOut.sol';
import {IDetfErrors} from 'contracts/interfaces/IDetfErrors.sol';
import {IRebasingClaimToken} from 'contracts/interfaces/IRebasingClaimToken.sol';
import {IVaultFeeOracleQuery} from 'contracts/interfaces/IVaultFeeOracleQuery.sol';
import {IBalancerV3StandardExchangeRouterProxy} from 'contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol';
import {ComposedStableCommonDetfRepo} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol';
import {
    ComposedStableCommonDetfExchangeOutQueryFacet
} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeOutQueryFacet.sol';
import {BalancerV3WeightedPoolQuote} from '@crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol';
import {ThresholdMode} from 'contracts/vaults/detf/common/core/DETFThresholdPolicy.sol';

contract MockQueryToken is IERC20 {
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

contract MockPermit2 {
    function approve(address, address, uint160, uint48) external pure {}
}

contract MockBalancerRouter {
    uint256 internal nextAmountIn;
    uint256 internal nextAmountOut;
    uint256[] internal nextRemoveLiquidityAmountsOut;

    function setNextAmountIn(uint256 nextAmountIn_) external {
        nextAmountIn = nextAmountIn_;
    }

    function setNextAmountOut(uint256 nextAmountOut_) external {
        nextAmountOut = nextAmountOut_;
    }

    function setNextRemoveLiquidityAmountsOut(uint256[] calldata nextRemoveLiquidityAmountsOut_) external {
        delete nextRemoveLiquidityAmountsOut;
        for (uint256 i = 0; i < nextRemoveLiquidityAmountsOut_.length; i++) {
            nextRemoveLiquidityAmountsOut.push(nextRemoveLiquidityAmountsOut_[i]);
        }
    }

    function swapSingleTokenExactOut(
        address,
        IERC20,
        address,
        IERC20 tokenOut,
        address,
        uint256 exactAmountOut,
        uint256 maxAmountIn,
        uint256,
        bool,
        bytes calldata
    ) external returns (uint256 amountIn) {
        MockQueryToken(address(tokenOut)).mint(msg.sender, exactAmountOut);
        amountIn = nextAmountIn == 0 ? maxAmountIn : nextAmountIn;
        nextAmountIn = 0;
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
        MockQueryToken(address(tokenOut)).mint(msg.sender, amountOut);
        nextAmountOut = 0;
    }

    function prepayRemoveLiquidityProportional(address pool, uint256 exactBptIn, uint256[] calldata, bytes calldata)
        external
        returns (uint256[] memory amountsOut)
    {
        if (nextRemoveLiquidityAmountsOut.length == 0) {
            revert('missing remove-liquidity amounts');
        }

        MockQueryToken(pool).burn(msg.sender, exactBptIn);

        amountsOut = new uint256[](nextRemoveLiquidityAmountsOut.length);
        for (uint256 i = 0; i < nextRemoveLiquidityAmountsOut.length; i++) {
            amountsOut[i] = nextRemoveLiquidityAmountsOut[i];
        }
    }
}

contract MockRateExchange is IStandardExchangeIn, IStandardExchangeOut {
    struct Rate {
        uint256 num;
        uint256 den;
    }

    mapping(bytes32 => Rate) internal rates;
    bool internal consumeTokenIn = true;

    function setRate(IERC20 tokenIn, IERC20 tokenOut, uint256 num, uint256 den) external {
        rates[keccak256(abi.encode(address(tokenIn), address(tokenOut)))] = Rate({num: num, den: den});
    }

    function setConsumeTokenIn(bool consumeTokenIn_) external {
        consumeTokenIn = consumeTokenIn_;
    }

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        Rate memory rate = rates[keccak256(abi.encode(address(tokenIn), address(tokenOut)))];
        require(rate.den != 0, 'missing rate');
        amountOut = amountIn * rate.num / rate.den;
    }

    function exchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256, address recipient, bool, uint256)
        external
        returns (uint256 amountOut)
    {
        Rate memory rate = rates[keccak256(abi.encode(address(tokenIn), address(tokenOut)))];
        require(rate.den != 0, 'missing rate');
        amountOut = amountIn * rate.num / rate.den;
        if (consumeTokenIn && MockQueryToken(address(tokenIn)).balanceOf(msg.sender) >= amountIn) {
            MockQueryToken(address(tokenIn)).burn(msg.sender, amountIn);
        }
        MockQueryToken(address(tokenOut)).mint(recipient, amountOut);
    }

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        Rate memory rate = rates[keccak256(abi.encode(address(tokenIn), address(tokenOut)))];
        require(rate.den != 0, 'missing rate');
        amountIn = amountOut * rate.num / rate.den;
    }

    function exchangeOut(IERC20 tokenIn, uint256, IERC20 tokenOut, uint256 amountOut, address recipient, bool, uint256)
        external
        returns (uint256 amountIn)
    {
        Rate memory rate = rates[keccak256(abi.encode(address(tokenIn), address(tokenOut)))];
        require(rate.den != 0, 'missing rate');
        amountIn = amountOut * rate.num / rate.den;
        if (consumeTokenIn && MockQueryToken(address(tokenIn)).balanceOf(msg.sender) >= amountIn) {
            MockQueryToken(address(tokenIn)).burn(msg.sender, amountIn);
        }
        MockQueryToken(address(tokenOut)).mint(recipient, amountOut);
    }
}

contract ComposedStableCommonDetfExchangeOutQueryHarness is ComposedStableCommonDetfExchangeOutQueryFacet {
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
        IDETFNFTVault bondNftVault_,
        IRebasingClaimToken rebasingDetfToken_,
        IERC20 detfToken_,
        IERC20 stablePoolBpt_,
        IERC20 commonPoolBpt_,
        IERC20 rateAsset_,
        IStandardExchangeIn stablePoolExitPricer_,
        IStandardExchangeIn commonPoolExitPricer_
    ) external {
        ComposedStableCommonDetfRepo._initializePricing(
            reservePool_,
            bondNftVault_,
            rebasingDetfToken_,
            detfToken_,
            stablePoolBpt_,
            commonPoolBpt_,
            rateAsset_,
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
            ThresholdMode.Policy,
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
        weightedPoolStates[pool_] = WeightedPoolState({
            balances: balances_,
            weights: weights_,
            fee: fee_,
            totalSupply: totalSupply_,
            isInitialized: isInitialized_
        });
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

contract ComposedStableCommonDetfExchangeOutQueryFacet_Test is Test {
    address internal bondVaultCaller;
    address internal rebasingTokenCaller;

    MockQueryToken internal detfToken;
    MockQueryToken internal rateAsset;
    MockQueryToken internal commonToken;
    MockQueryToken internal otherToken;
    MockQueryToken internal routeAVaultToken;
    MockQueryToken internal routeBVaultToken;
    MockQueryToken internal stablePoolBpt;
    MockQueryToken internal commonPoolBpt;
    MockQueryToken internal reservePoolToken;

    MockRateExchange internal routeAUnderlying;
    MockRateExchange internal routeBUnderlying;
    MockRateExchange internal stablePoolExitPricer;
    MockRateExchange internal commonPoolExitPricer;
    MockPermit2 internal permit2;
    MockBalancerRouter internal balancerRouter;

    ComposedStableCommonDetfExchangeOutQueryHarness internal harness;
    IStablePool internal stablePool;
    IStablePool internal commonPool;

    function _initializeHarness(
        ComposedStableCommonDetfExchangeOutQueryHarness harness_,
        IPermit2 permit2_,
        IBalancerV3StandardExchangeRouterProxy balancerV3Router_
    ) internal {
        harness_.initializePricingHarness(
            IWeightedPool(address(reservePoolToken)),
            IDETFNFTVault(bondVaultCaller),
            IRebasingClaimToken(rebasingTokenCaller),
            detfToken,
            stablePoolBpt,
            commonPoolBpt,
            rateAsset,
            stablePoolExitPricer,
            commonPoolExitPricer
        );
        harness_.configureRoute(0, commonToken, routeAVaultToken, routeAUnderlying, 0, 0);
        harness_.configureRoute(1, commonToken, routeBVaultToken, routeBUnderlying, 1, 1);
        harness_.initializeExchangeHarness(stablePool, commonPool, permit2_, balancerV3Router_, 1e18);

        uint256[] memory reserveBalances = new uint256[](3);
        reserveBalances[0] = 600e18;
        reserveBalances[1] = 200e18;
        reserveBalances[2] = 200e18;

        uint256[] memory reserveWeights = new uint256[](3);
        reserveWeights[0] = 60e16;
        reserveWeights[1] = 20e16;
        reserveWeights[2] = 20e16;

        harness_.setWeightedPoolState(address(reservePoolToken), reserveBalances, reserveWeights, 0, 1000e18, true);
        harness_.setSyntheticPrice(999e15);

        uint256[] memory stableBalances = new uint256[](2);
        stableBalances[0] = 10e18;
        stableBalances[1] = 50e18;
        harness_.setStablePoolState(address(stablePool), stableBalances, true);

        uint256[] memory commonBalances = new uint256[](2);
        commonBalances[0] = 100e18;
        commonBalances[1] = 20e18;
        harness_.setStablePoolState(address(commonPool), commonBalances, true);
    }

    function setUp() public {
        bondVaultCaller = makeAddr('bondVaultCaller');
        rebasingTokenCaller = makeAddr('rebasingTokenCaller');

        detfToken = new MockQueryToken('DETF', 'DETF', 18);
        rateAsset = new MockQueryToken('WETH', 'WETH', 18);
        commonToken = new MockQueryToken('COMMON', 'COMMON', 18);
        otherToken = new MockQueryToken('OTHER', 'OTHER', 18);
        routeAVaultToken = new MockQueryToken('Vault A', 'vA', 18);
        routeBVaultToken = new MockQueryToken('Vault B', 'vB', 18);
        stablePoolBpt = new MockQueryToken('Stable Pool BPT', 'sBPT', 18);
        commonPoolBpt = new MockQueryToken('Common Pool BPT', 'cBPT', 18);
        reservePoolToken = new MockQueryToken('Reserve Pool', 'rBPT', 18);

        routeAUnderlying = new MockRateExchange();
        routeBUnderlying = new MockRateExchange();
        stablePoolExitPricer = new MockRateExchange();
        commonPoolExitPricer = new MockRateExchange();
        permit2 = new MockPermit2();
        balancerRouter = new MockBalancerRouter();
        stablePool = IStablePool(makeAddr('stablePool'));
        commonPool = IStablePool(makeAddr('commonPool'));

        harness = new ComposedStableCommonDetfExchangeOutQueryHarness();

        _initializeHarness(
            harness, IPermit2(address(permit2)), IBalancerV3StandardExchangeRouterProxy(address(balancerRouter))
        );

        routeAUnderlying.setRate(routeAVaultToken, commonToken, 3, 1);
        routeBUnderlying.setRate(routeBVaultToken, commonToken, 2, 1);

        stablePoolExitPricer.setRate(stablePoolBpt, routeAVaultToken, 5, 3);
        stablePoolExitPricer.setRate(stablePoolBpt, routeBVaultToken, 3, 1);
        stablePoolExitPricer.setRate(stablePoolBpt, rateAsset, 2, 1);

        commonPoolExitPricer.setRate(commonPoolBpt, routeAVaultToken, 4, 3);
        commonPoolExitPricer.setRate(commonPoolBpt, routeBVaultToken, 1, 1);
        commonPoolExitPricer.setRate(commonPoolBpt, rateAsset, 3, 1);
    }

    function test_claimLiquidity_revertsWhenCallerUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(IDetfErrors.NotAuthorized.selector, address(this)));
        harness.claimLiquidity(1e18, address(this));
    }

    function test_claimLiquidity_revertsWhenReserveInventoryIsInsufficient() public {
        reservePoolToken.mint(address(harness), 1e18);

        vm.prank(bondVaultCaller);
        vm.expectRevert(abi.encodeWithSelector(IDetfErrors.InsufficientBalance.selector, 2e18, 1e18));
        harness.claimLiquidity(2e18, address(this));
    }

    function test_claimLiquidity_executesAuthorizedReserveExit() public {
        reservePoolToken.mint(address(harness), 3e18);
        detfToken.mint(address(harness), 1e18);
        stablePoolBpt.mint(address(harness), 1e18);
        commonPoolBpt.mint(address(harness), 1e18);

        uint256[] memory amountsOut = new uint256[](3);
        amountsOut[0] = 1e18;
        amountsOut[1] = 1e18;
        amountsOut[2] = 1e18;
        balancerRouter.setNextRemoveLiquidityAmountsOut(amountsOut);

        address recipient = makeAddr('claim-liquidity-recipient');

        vm.prank(bondVaultCaller);
        uint256 wethOut = harness.claimLiquidity(3e18, recipient);

        assertEq(wethOut, 5e18);
        assertEq(rateAsset.balanceOf(recipient), 5e18);
        assertEq(detfToken.balanceOf(address(harness)), 0);
        assertEq(stablePoolBpt.balanceOf(address(harness)), 0);
        assertEq(commonPoolBpt.balanceOf(address(harness)), 0);
        assertEq(reservePoolToken.balanceOf(address(harness)), 0);
    }

    function test_previewExchangeOut_selectsMostLiquidEligibleRouteAndPoolLeg() public view {
        uint256 previewAmountIn = harness.previewExchangeOut(detfToken, commonToken, 1e18);

        uint256 expected = BalancerV3WeightedPoolQuote.computeInGivenExactOutBeforeFee(
            600e18,
            60e16,
            200e18,
            20e16,
            4e18,
            0
        );

        assertEq(previewAmountIn, expected);
    }

    function test_previewExchangeOut_revertsWhenBurningClosed() public {
        harness.setSyntheticPrice(1e18);

        vm.expectRevert(abi.encodeWithSelector(IDetfErrors.BurningNotAllowed.selector, 1e18, 1e18));
        harness.previewExchangeOut(detfToken, commonToken, 1e18);
    }

    function test_previewExchangeOut_revertsForUnsupportedTokenIn() public {
        vm.expectRevert(abi.encodeWithSelector(IDetfErrors.InvalidToken.selector, otherToken));
        harness.previewExchangeOut(otherToken, commonToken, 1e18);
    }

    function test_previewExchangeOut_revertsForUnsupportedTokenOut() public {
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        harness.previewExchangeOut(detfToken, otherToken, 1e18);
    }

    function test_previewExchangeOut_revertsWhenReservePoolUninitialized() public {
        uint256[] memory reserveBalances = new uint256[](3);
        uint256[] memory reserveWeights = new uint256[](3);
        reserveWeights[0] = 60e16;
        reserveWeights[1] = 20e16;
        reserveWeights[2] = 20e16;

        harness.setWeightedPoolState(address(reservePoolToken), reserveBalances, reserveWeights, 0, 0, false);

        vm.expectRevert(IDetfErrors.ReservePoolNotInitialized.selector);
        harness.previewExchangeOut(detfToken, commonToken, 1e18);
    }

    function test_exchangeOut_executesSelectedRoute() public {
        uint256 previewAmountIn = harness.previewExchangeOut(detfToken, commonToken, 1e18);
        address recipient = makeAddr('recipient');

        detfToken.mint(address(this), previewAmountIn);
        detfToken.approve(address(harness), previewAmountIn);

        uint256 amountIn = harness.exchangeOut(
            detfToken,
            previewAmountIn,
            commonToken,
            1e18,
            recipient,
            false,
            block.timestamp + 1
        );

        assertEq(amountIn, previewAmountIn);
        assertEq(commonToken.balanceOf(recipient), 1e18);
    }

    function test_exchangeOut_refundsUnusedDetfInput() public {
        uint256 previewAmountIn = harness.previewExchangeOut(detfToken, commonToken, 1e18);
        uint256 actualAmountIn = previewAmountIn - 0.1e18;

        balancerRouter.setNextAmountIn(actualAmountIn);

        detfToken.mint(address(this), previewAmountIn);
        detfToken.approve(address(harness), previewAmountIn);

        uint256 amountIn = harness.exchangeOut(
            detfToken,
            previewAmountIn,
            commonToken,
            1e18,
            address(this),
            false,
            block.timestamp + 1
        );

        assertEq(amountIn, actualAmountIn);
        assertEq(detfToken.balanceOf(address(this)), previewAmountIn - actualAmountIn);
        assertEq(commonToken.balanceOf(address(this)), 1e18);
    }

    function test_exchangeOut_defaultsRecipientToCaller() public {
        uint256 previewAmountIn = harness.previewExchangeOut(detfToken, commonToken, 1e18);

        detfToken.mint(address(this), previewAmountIn);
        detfToken.approve(address(harness), previewAmountIn);

        harness.exchangeOut(detfToken, previewAmountIn, commonToken, 1e18, address(0), false, block.timestamp + 1);

        assertEq(commonToken.balanceOf(address(this)), 1e18);
    }

    function test_exchangeOut_revertsWhenMaxAmountInIsTooLow() public {
        uint256 previewAmountIn = harness.previewExchangeOut(detfToken, commonToken, 1e18);

        detfToken.mint(address(this), previewAmountIn - 1);
        detfToken.approve(address(harness), previewAmountIn - 1);

        vm.expectRevert(
            abi.encodeWithSelector(IDetfErrors.SlippageExceeded.selector, previewAmountIn - 1, previewAmountIn)
        );
        harness.exchangeOut(detfToken, previewAmountIn - 1, commonToken, 1e18, address(this), false, block.timestamp + 1);
    }

    function test_exchangeOut_revertsForUnsupportedTokenOut() public {
        detfToken.mint(address(this), 1e18);
        detfToken.approve(address(harness), 1e18);

        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        harness.exchangeOut(detfToken, 1e18, otherToken, 1e18, address(this), false, block.timestamp + 1);
    }

    function test_exchangeOut_revertsWhenDeadlineExpired() public {
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, block.timestamp - 1, block.timestamp)
        );
        harness.exchangeOut(detfToken, 1e18, commonToken, 1e18, address(this), false, block.timestamp - 1);
    }

    function test_exchangeOut_revertsWhenAmountOutIsZero() public {
        vm.expectRevert(IDetfErrors.ZeroAmount.selector);
        harness.exchangeOut(detfToken, 1e18, commonToken, 0, address(this), false, block.timestamp + 1);
    }

    function test_exchangeOut_revertsWhenBurningClosed() public {
        harness.setSyntheticPrice(1e18);

        vm.expectRevert(abi.encodeWithSelector(IDetfErrors.BurningNotAllowed.selector, 1e18, 1e18));
        harness.exchangeOut(detfToken, 1e18, commonToken, 1e18, address(this), false, block.timestamp + 1);
    }

    function test_exchangeOut_revertsWhenRouterDependencyMissing() public {
        ComposedStableCommonDetfExchangeOutQueryHarness missingRouterHarness = new ComposedStableCommonDetfExchangeOutQueryHarness();
        _initializeHarness(missingRouterHarness, IPermit2(address(0)), IBalancerV3StandardExchangeRouterProxy(address(0)));

        uint256 previewAmountIn = missingRouterHarness.previewExchangeOut(detfToken, commonToken, 1e18);
        detfToken.mint(address(this), previewAmountIn);
        detfToken.approve(address(missingRouterHarness), previewAmountIn);

        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        missingRouterHarness.exchangeOut(
            detfToken,
            previewAmountIn,
            commonToken,
            1e18,
            address(this),
            false,
            block.timestamp + 1
        );
    }

    function test_exchangeOut_revertsWhenReservePoolUninitialized() public {
        uint256[] memory reserveBalances = new uint256[](3);
        uint256[] memory reserveWeights = new uint256[](3);
        reserveWeights[0] = 60e16;
        reserveWeights[1] = 20e16;
        reserveWeights[2] = 20e16;

        harness.setWeightedPoolState(address(reservePoolToken), reserveBalances, reserveWeights, 0, 0, false);

        detfToken.mint(address(this), 1e18);
        detfToken.approve(address(harness), 1e18);

        vm.expectRevert(IDetfErrors.ReservePoolNotInitialized.selector);
        harness.exchangeOut(detfToken, 1e18, commonToken, 1e18, address(this), false, block.timestamp + 1);
    }

    function test_exchangeOut_revertsWhenUnderlyingExitLeavesResidualVaultTokens() public {
        routeAUnderlying.setConsumeTokenIn(false);

        uint256 previewAmountIn = harness.previewExchangeOut(detfToken, commonToken, 1e18);
        detfToken.mint(address(this), previewAmountIn);
        detfToken.approve(address(harness), previewAmountIn);

        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        harness.exchangeOut(detfToken, previewAmountIn, commonToken, 1e18, address(this), false, block.timestamp + 1);
    }

    function test_previewExchangeOut_supportsDirectVaultTokenPayout() public view {
        uint256 previewAmountIn = harness.previewExchangeOut(detfToken, routeAVaultToken, 1e18);
        uint256 expectedPoolBptOut = 4e18;

        uint256 expected = BalancerV3WeightedPoolQuote.computeInGivenExactOutBeforeFee(
            600e18,
            60e16,
            200e18,
            20e16,
            expectedPoolBptOut / 3,
            0
        );

        assertEq(previewAmountIn, expected);
    }

    function test_exchangeOut_supportsDirectVaultTokenPayout() public {
        uint256 previewAmountIn = harness.previewExchangeOut(detfToken, routeAVaultToken, 1e18);
        address recipient = makeAddr('vault-token-recipient');

        detfToken.mint(address(this), previewAmountIn);
        detfToken.approve(address(harness), previewAmountIn);

        uint256 amountIn = harness.exchangeOut(
            detfToken,
            previewAmountIn,
            routeAVaultToken,
            1e18,
            recipient,
            false,
            block.timestamp + 1
        );

        assertEq(amountIn, previewAmountIn);
        assertEq(routeAVaultToken.balanceOf(recipient), 1e18);
        assertEq(commonToken.balanceOf(recipient), 0);
    }
}