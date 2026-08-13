// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICLPool} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLPool.sol";
import {
    ICLMintCallback
} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/callback/ICLMintCallback.sol";
import {
    ICLSwapCallback
} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/callback/ICLSwapCallback.sol";
import {SwapMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/SwapMath.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {SlipstreamUtils} from "@crane/contracts/utils/math/SlipstreamUtils.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";

/// @notice Non-SUT hermetic CL book: callbacks + recorded positions for Slipstream SE tests.
contract SlipstreamHermeticClBook is ICLPool {
    using BetterSafeERC20 for IERC20;

    address public override token0;
    address public override token1;
    uint24 internal _fee;
    uint24 internal _unstakedFee;
    int24 public override tickSpacing;
    address public override factory;

    uint160 internal _sqrtPriceX96;
    int24 internal _tick;
    uint16 internal _observationIndex;
    uint16 internal _observationCardinality;
    uint16 internal _observationCardinalityNext;
    bool internal _unlocked;

    uint128 internal _liquidity;
    uint128 internal _stakedLiquidity;

    uint256 public override feeGrowthGlobal0X128;
    uint256 public override feeGrowthGlobal1X128;
    uint256 public override rewardGrowthGlobalX128;

    struct TickInfo {
        uint128 liquidityGross;
        int128 liquidityNet;
        int128 stakedLiquidityNet;
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
        uint256 rewardGrowthOutsideX128;
        int56 tickCumulativeOutside;
        uint160 secondsPerLiquidityOutsideX128;
        uint32 secondsOutside;
        bool initialized;
    }

    mapping(int24 => TickInfo) internal _ticks;
    mapping(int16 => uint256) internal _tickBitmap;
    mapping(bytes32 => uint128) internal _liqOf;

    constructor(address token0_, address token1_, uint24 fee_, int24 tickSpacing_, address factory_) {
        token0 = token0_;
        token1 = token1_;
        _fee = fee_;
        tickSpacing = tickSpacing_;
        factory = factory_;
        _unlocked = true;
    }

    function initialize(address, address, address, int24, address, uint160 sqrtPriceX96_) external override {
        _initializeInternal(sqrtPriceX96_);
    }

    function initialize(uint160 sqrtPriceX96_) external {
        _initializeInternal(sqrtPriceX96_);
    }

    function _initializeInternal(uint160 sqrtPriceX96_) internal {
        require(_sqrtPriceX96 == 0, "Already initialized");
        _sqrtPriceX96 = sqrtPriceX96_;
        _tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96_);
        _observationCardinality = 1;
        _observationCardinalityNext = 1;
    }

    function fee() external view override returns (uint24) {
        return _fee;
    }

    function unstakedFee() external view override returns (uint24) {
        return _unstakedFee;
    }

    function maxLiquidityPerTick() external pure override returns (uint128) {
        return type(uint128).max / 2;
    }

    function gauge() external pure override returns (address) {
        return address(0);
    }

    function nft() external pure override returns (address) {
        return address(0);
    }

    function factoryRegistry() external pure override returns (address) {
        return address(0);
    }

    function slot0()
        external
        view
        override
        returns (uint160, int24, uint16, uint16, uint16, bool)
    {
        return (
            _sqrtPriceX96, _tick, _observationIndex, _observationCardinality, _observationCardinalityNext, _unlocked
        );
    }

    function gaugeFees() external pure override returns (uint128, uint128) {
        return (0, 0);
    }

    function rewardRate() external pure override returns (uint256) {
        return 0;
    }

    function rewardReserve() external pure override returns (uint256) {
        return 0;
    }

    function periodFinish() external pure override returns (uint256) {
        return 0;
    }

    function lastUpdated() external pure override returns (uint32) {
        return 0;
    }

    function rollover() external pure override returns (uint256) {
        return 0;
    }

    function liquidity() external view override returns (uint128) {
        return _liquidity;
    }

    function stakedLiquidity() external view override returns (uint128) {
        return _stakedLiquidity;
    }

    function ticks(int24 tick)
        external
        view
        override
        returns (uint128, int128, int128, uint256, uint256, uint256, int56, uint160, uint32, bool)
    {
        TickInfo storage info = _ticks[tick];
        return (
            info.liquidityGross,
            info.liquidityNet,
            info.stakedLiquidityNet,
            info.feeGrowthOutside0X128,
            info.feeGrowthOutside1X128,
            info.rewardGrowthOutsideX128,
            info.tickCumulativeOutside,
            info.secondsPerLiquidityOutsideX128,
            info.secondsOutside,
            info.initialized
        );
    }

    function tickBitmap(int16 wordPosition) external view override returns (uint256) {
        return _tickBitmap[wordPosition];
    }

    function positions(bytes32 key) external view override returns (uint128, uint256, uint256, uint128, uint128) {
        return (_liqOf[key], 0, 0, 0, 0);
    }

    function observations(uint256) external pure override returns (uint32, int56, uint160, bool) {
        return (0, 0, 0, false);
    }

    function getRewardGrowthInside(int24, int24, uint256) external pure override returns (uint256) {
        return 0;
    }

    function observe(uint32[] calldata) external pure override returns (int56[] memory, uint160[] memory) {
        return (new int56[](0), new uint160[](0));
    }

    function snapshotCumulativesInside(int24, int24) external pure override returns (int56, uint160, uint32) {
        return (0, 0, 0);
    }

    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount, bytes calldata data)
        external
        override
        returns (uint256 amount0, uint256 amount1)
    {
        require(amount > 0, "zero liq");
        (amount0, amount1) = SlipstreamUtils._quoteAmountsForLiquidity(_sqrtPriceX96, tickLower, tickUpper, amount);

        uint256 b0 = IERC20(token0).balanceOf(address(this));
        uint256 b1 = IERC20(token1).balanceOf(address(this));
        ICLMintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, data);
        require(IERC20(token0).balanceOf(address(this)) >= b0 + amount0, "M0");
        require(IERC20(token1).balanceOf(address(this)) >= b1 + amount1, "M1");

        bytes32 key = keccak256(abi.encode(recipient, tickLower, tickUpper));
        _liqOf[key] += amount;
        if (_tick >= tickLower && _tick < tickUpper) {
            _liquidity += amount;
        }
    }

    function collect(address, int24, int24, uint128, uint128) external pure override returns (uint128, uint128) {
        return (0, 0);
    }

    function collect(address, int24, int24, uint128, uint128, address)
        external
        pure
        override
        returns (uint128, uint128)
    {
        return (0, 0);
    }

    function burn(int24, int24, uint128) external pure override returns (uint256, uint256) {
        return (0, 0);
    }

    function burn(int24, int24, uint128, address) external pure override returns (uint256, uint256) {
        return (0, 0);
    }

    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata data)
        external
        override
        returns (int256 amount0, int256 amount1)
    {
        require(_sqrtPriceX96 != 0, "Not initialized");
        require(amountSpecified > 0, "exact in");

        (uint160 sqrtRatioNextX96, uint256 amountIn, uint256 amountOut, uint256 feeAmount) =
            SwapMath.computeSwapStep(_sqrtPriceX96, sqrtPriceLimitX96, _liquidity, amountSpecified, _fee);

        _sqrtPriceX96 = sqrtRatioNextX96;
        _tick = TickMath.getTickAtSqrtRatio(sqrtRatioNextX96);

        if (zeroForOne) {
            amount0 = int256(amountIn + feeAmount);
            amount1 = -int256(amountOut);
        } else {
            amount0 = -int256(amountOut);
            amount1 = int256(amountIn + feeAmount);
        }

        ICLSwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
        address tokenOut = zeroForOne ? token1 : token0;
        IERC20(tokenOut).safeTransfer(recipient, amountOut);
    }

    function flash(address, uint256, uint256, bytes calldata) external pure override {
        revert("Not implemented");
    }

    function increaseObservationCardinalityNext(uint16) external pure override {}

    function stake(int128, int24, int24, bool) external pure override {
        revert("Not implemented");
    }

    function updateRewardsGrowthGlobal() external pure override {}

    function syncReward(uint256, uint256, uint256) external pure override {}

    function setGaugeAndPositionManager(address, address) external pure override {}

    function collectFees() external pure override returns (uint128, uint128) {
        return (0, 0);
    }

    function addLiquidity(int24 tickLower, int24 tickUpper, uint128 amount) external {
        require(tickLower < tickUpper, "Invalid range");
        require(tickLower >= TickMath.MIN_TICK && tickUpper <= TickMath.MAX_TICK, "Out of bounds");
        _updateTickWithLiquidity(tickLower, amount, true);
        _updateTickWithLiquidity(tickUpper, amount, false);
        if (_tick >= tickLower && _tick < tickUpper) {
            _liquidity += amount;
        }
    }

    function _updateTickWithLiquidity(int24 tick, uint128 liquidityAmount, bool isLower) internal {
        TickInfo storage info = _ticks[tick];
        info.liquidityGross += liquidityAmount;
        if (isLower) {
            info.liquidityNet += int128(liquidityAmount);
        } else {
            info.liquidityNet -= int128(liquidityAmount);
        }
        if (!info.initialized && info.liquidityGross > 0) {
            info.initialized = true;
            _flipTick(tick);
        } else if (info.initialized && info.liquidityGross == 0) {
            info.initialized = false;
            _flipTick(tick);
        }
    }

    function _flipTick(int24 tick) internal {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        int16 wordPos = int16(compressed >> 8);
        uint8 bitPos = uint8(uint24(compressed % 256));
        _tickBitmap[wordPos] ^= (1 << bitPos);
    }
}
