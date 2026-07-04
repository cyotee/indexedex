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

import {IComposedStableCommonDetfBonding} from 'contracts/interfaces/IComposedStableCommonDetfBonding.sol';
import {IProtocolDETFErrors} from 'contracts/interfaces/IProtocolDETFErrors.sol';
import {IDETFNFTVault} from 'contracts/interfaces/IDETFNFTVault.sol';
import {IRICHIR} from 'contracts/interfaces/IRICHIR.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {IVaultFeeOracleQuery} from 'contracts/interfaces/IVaultFeeOracleQuery.sol';
import {IFeeCollectorProxy} from 'contracts/interfaces/proxies/IFeeCollectorProxy.sol';
import {ComposedStableCommonDetfRepo} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfRepo.sol';
import {
    ComposedStableCommonDetfBondingFacet
} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondingFacet.sol';

contract MockBondToken is IERC20 {
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

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
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

contract MockBondExchange is IStandardExchangeIn {
    MockBondToken public immutable outputToken;
    uint256 public immutable num;
    uint256 public immutable den;

    constructor(MockBondToken outputToken_, uint256 num_, uint256 den_) {
        outputToken = outputToken_;
        num = num_;
        den = den_;
    }

    function previewExchangeIn(IERC20, uint256 amountIn, IERC20 tokenOut) external view returns (uint256 amountOut) {
        require(address(tokenOut) == address(outputToken), 'unexpected tokenOut');
        amountOut = amountIn * num / den;
    }

    function exchangeIn(
        IERC20,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256,
        address recipient,
        bool,
        uint256
    ) external returns (uint256 amountOut) {
        require(address(tokenOut) == address(outputToken), 'unexpected tokenOut');
        amountOut = amountIn * num / den;
        outputToken.mint(recipient, amountOut);
    }
}

contract MockBondNFTVault {
    uint256 public nextTokenId = 1;
    uint256 public lastShares;
    uint256 public lastLockDuration;
    address public lastRecipient;
    uint256 public nextPrincipalShares = 5e18;
    uint256 public lastSoldTokenId;
    address public lastSeller;
    address public lastRewardsRecipient;
    uint256 public feeRecipientTokenId = 99;
    uint256 public lastFeeRecipientTokenId;
    uint256 public lastFeeRecipientShares;

    function createPosition(uint256 shares, uint256 lockDuration, address recipient) external returns (uint256 tokenId) {
        lastShares = shares;
        lastLockDuration = lockDuration;
        lastRecipient = recipient;
        tokenId = nextTokenId++;
    }

    function setNextPrincipalShares(uint256 principalShares_) external {
        nextPrincipalShares = principalShares_;
    }

    function sellPositionToProtocol(uint256 tokenId, address seller, address rewardsRecipient)
        external
        returns (uint256 principalShares, uint256 rewardsClaimed)
    {
        lastSoldTokenId = tokenId;
        lastSeller = seller;
        lastRewardsRecipient = rewardsRecipient;
        principalShares = nextPrincipalShares;
        rewardsClaimed = 0;
    }

    function addToFeeRecipientNFT(uint256 tokenId, uint256 shares) external {
        lastFeeRecipientTokenId = tokenId;
        lastFeeRecipientShares = shares;
    }

    function feeRecipientNFTId() external view returns (uint256) {
        return feeRecipientTokenId;
    }
}

contract MockBondFeeOracle {
    uint256 public usageFee;
    IFeeCollectorProxy public feeCollector;

    constructor(uint256 usageFee_, IFeeCollectorProxy feeCollector_) {
        usageFee = usageFee_;
        feeCollector = feeCollector_;
    }

    function usageFeeOfVault(address) external view returns (uint256 usageFee_) {
        return usageFee;
    }

    function feeTo() external view returns (IFeeCollectorProxy feeTo_) {
        return feeCollector;
    }
}

contract MockRebasingDetfToken {
    uint256 public mintMultiplier = 2;
    uint256 public lastLpShares;
    address public lastRecipient;

    function mintFromNFTSale(uint256 lpShares, address recipient) external returns (uint256 richirMinted) {
        lastLpShares = lpShares;
        lastRecipient = recipient;
        richirMinted = lpShares * mintMultiplier;
    }
}

contract ComposedStableCommonDetfBondingHarness is ComposedStableCommonDetfBondingFacet {
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

    function initializeHarness(
        IWeightedPool reservePool_,
        IDETFNFTVault bondNftVault_,
        IRICHIR rebasingDetfToken_,
        IERC20 detfToken_,
        IERC20 stablePoolBpt_,
        IERC20 commonPoolBpt_,
        IERC20 wethToken_,
        IStablePool stablePool_,
        IStablePool commonPool_,
        IStandardExchangeIn reservePoolEntryRouter_,
        IVaultFeeOracleQuery feeOracle_,
        ComposedStableCommonDetfRepo.RouteConfig[] memory routes_
    ) external {
        ComposedStableCommonDetfRepo._initializePricing(
            reservePool_,
            bondNftVault_,
            rebasingDetfToken_,
            detfToken_,
            stablePoolBpt_,
            commonPoolBpt_,
            wethToken_,
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
            feeOracle_,
            0,
            0,
            routes_
        );
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

contract ComposedStableCommonDetfBondingFacet_Test is Test {
    MockBondToken internal detfToken;
    MockBondToken internal commonToken;
    MockBondToken internal routeAVaultToken;
    MockBondToken internal routeBVaultToken;
    MockBondToken internal stablePoolBpt;
    MockBondToken internal commonPoolBpt;
    MockBondToken internal reservePoolToken;
    MockBondToken internal wethToken;

    MockBondExchange internal routeAUnderlying;
    MockBondExchange internal routeBUnderlying;
    MockBondExchange internal stablePoolRouter;
    MockBondExchange internal commonPoolRouter;
    MockBondExchange internal reservePoolEntryRouter;
    MockBondNFTVault internal bondNFTVault;
    MockRebasingDetfToken internal rebasingDetfToken;
    MockBondFeeOracle internal feeOracle;

    ComposedStableCommonDetfBondingHarness internal harness;
    IStablePool internal stablePool;
    IStablePool internal commonPool;

    function setUp() public {
        detfToken = new MockBondToken('DETF', 'DETF', 18);
        commonToken = new MockBondToken('COMMON', 'COMMON', 18);
        routeAVaultToken = new MockBondToken('Vault A', 'vA', 18);
        routeBVaultToken = new MockBondToken('Vault B', 'vB', 18);
        stablePoolBpt = new MockBondToken('Stable Pool BPT', 'sBPT', 18);
        commonPoolBpt = new MockBondToken('Common Pool BPT', 'cBPT', 18);
        reservePoolToken = new MockBondToken('Reserve Pool', 'rBPT', 18);
        wethToken = new MockBondToken('WETH', 'WETH', 18);

        routeAUnderlying = new MockBondExchange(routeAVaultToken, 2, 1);
        routeBUnderlying = new MockBondExchange(routeBVaultToken, 3, 1);
        stablePoolRouter = new MockBondExchange(stablePoolBpt, 1, 1);
        commonPoolRouter = new MockBondExchange(commonPoolBpt, 1, 1);
        reservePoolEntryRouter = new MockBondExchange(reservePoolToken, 2, 1);
        bondNFTVault = new MockBondNFTVault();
        rebasingDetfToken = new MockRebasingDetfToken();
        feeOracle = new MockBondFeeOracle(25e15, IFeeCollectorProxy(makeAddr('feeCollector')));
        harness = new ComposedStableCommonDetfBondingHarness();
        stablePool = IStablePool(makeAddr('stablePool'));
        commonPool = IStablePool(makeAddr('commonPool'));

        ComposedStableCommonDetfRepo.RouteConfig[] memory routes = new ComposedStableCommonDetfRepo.RouteConfig[](2);
        routes[0] = ComposedStableCommonDetfRepo.RouteConfig({
            baseToken: commonToken,
            vaultToken: routeAVaultToken,
            underlyingVault: routeAUnderlying,
            stablePoolRouter: stablePoolRouter,
            commonPoolRouter: commonPoolRouter,
            stablePoolTokenIndex: 0,
            commonPoolTokenIndex: 0
        });
        routes[1] = ComposedStableCommonDetfRepo.RouteConfig({
            baseToken: commonToken,
            vaultToken: routeBVaultToken,
            underlyingVault: routeBUnderlying,
            stablePoolRouter: stablePoolRouter,
            commonPoolRouter: commonPoolRouter,
            stablePoolTokenIndex: 1,
            commonPoolTokenIndex: 1
        });

        harness.initializeHarness(
            IWeightedPool(address(reservePoolToken)),
            IDETFNFTVault(address(bondNFTVault)),
            IRICHIR(address(rebasingDetfToken)),
            detfToken,
            stablePoolBpt,
            commonPoolBpt,
            wethToken,
            stablePool,
            commonPool,
            reservePoolEntryRouter,
            IVaultFeeOracleQuery(address(feeOracle)),
            routes
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

        uint256[] memory stableBalances = new uint256[](2);
        stableBalances[0] = 10e18;
        stableBalances[1] = 50e18;
        harness.setStablePoolState(address(stablePool), stableBalances, true);

        uint256[] memory commonBalances = new uint256[](2);
        commonBalances[0] = 100e18;
        commonBalances[1] = 20e18;
        harness.setStablePoolState(address(commonPool), commonBalances, true);
    }

    function test_acceptedBondTokens_deduplicatesRouteBaseTokens() public view {
        address[] memory tokens = harness.acceptedBondTokens();
        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(commonToken));
        assertTrue(harness.isAcceptedBondToken(commonToken));
    }

    function test_bond_routesToReserveAndMintsBondPosition() public {
        commonToken.mint(address(this), 2e18);
        commonToken.approve(address(harness), 2e18);

        (uint256 tokenId, uint256 shares) = harness.bond(commonToken, 2e18, 7 days, address(0), false, block.timestamp + 1);

        assertEq(tokenId, 1);
        assertEq(shares, 117e17);
        assertEq(bondNFTVault.lastShares(), 117e17);
        assertEq(bondNFTVault.lastLockDuration(), 7 days);
        assertEq(bondNFTVault.lastRecipient(), address(this));
        assertEq(bondNFTVault.lastFeeRecipientTokenId(), 99);
        assertEq(bondNFTVault.lastFeeRecipientShares(), 3e17);
    }

    function test_bond_revertsForUnsupportedToken() public {
        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.BondTokenNotSupported.selector, detfToken));
        harness.bond(detfToken, 1e18, 7 days, address(this), false, block.timestamp + 1);
    }

    function test_sellNFT_movesPrincipalIntoProtocolAndMintsRebasingDetf() public {
        bondNFTVault.setNextPrincipalShares(7e18);

        uint256 richirMinted = harness.sellNFT(11, address(0));

        assertEq(richirMinted, 14e18);
        assertEq(bondNFTVault.lastSoldTokenId(), 11);
        assertEq(bondNFTVault.lastSeller(), address(this));
        assertEq(bondNFTVault.lastRewardsRecipient(), address(this));
        assertEq(rebasingDetfToken.lastLpShares(), 7e18);
        assertEq(rebasingDetfToken.lastRecipient(), address(this));
    }

    function test_sellNFT_revertsWhenRebasingTokenUnset() public {
        ComposedStableCommonDetfRepo.RouteConfig[] memory routes = new ComposedStableCommonDetfRepo.RouteConfig[](1);
        routes[0] = ComposedStableCommonDetfRepo.RouteConfig({
            baseToken: commonToken,
            vaultToken: routeAVaultToken,
            underlyingVault: routeAUnderlying,
            stablePoolRouter: stablePoolRouter,
            commonPoolRouter: commonPoolRouter,
            stablePoolTokenIndex: 0,
            commonPoolTokenIndex: 0
        });

        ComposedStableCommonDetfBondingHarness unconfiguredHarness = new ComposedStableCommonDetfBondingHarness();
        unconfiguredHarness.initializeHarness(
            IWeightedPool(address(reservePoolToken)),
            IDETFNFTVault(address(bondNFTVault)),
            IRICHIR(address(0)),
            detfToken,
            stablePoolBpt,
            commonPoolBpt,
            wethToken,
            stablePool,
            commonPool,
            reservePoolEntryRouter,
            IVaultFeeOracleQuery(address(feeOracle)),
            routes
        );
        uint256[] memory reserveBalances = new uint256[](3);
        reserveBalances[0] = 600e18;
        reserveBalances[1] = 200e18;
        reserveBalances[2] = 200e18;

        uint256[] memory reserveWeights = new uint256[](3);
        reserveWeights[0] = 60e16;
        reserveWeights[1] = 20e16;
        reserveWeights[2] = 20e16;
        unconfiguredHarness.setWeightedPoolState(address(reservePoolToken), reserveBalances, reserveWeights, 0, 1000e18, true);

        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.InvalidToken.selector, IERC20(address(0))));
        unconfiguredHarness.sellNFT(1, address(this));
    }
}