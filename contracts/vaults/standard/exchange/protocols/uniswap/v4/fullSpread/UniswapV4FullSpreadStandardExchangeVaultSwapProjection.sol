// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {TickBitmap} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickBitmap.sol";
import {SwapMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SwapMath.sol";
import {LiquidityMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityMath.sol";
import {ProtocolFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/ProtocolFeeLibrary.sol";
import {BitMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/BitMath.sol";
import {UniswapV4FullSpreadStandardExchangeVaultTypes as Types} from "./UniswapV4FullSpreadStandardExchangeVaultTypes.sol";

/// @notice Unbounded exact-input projection of the bound hookless pool. No step cap.
library UniswapV4FullSpreadStandardExchangeVaultSwapProjection {
    using ProtocolFeeLibrary for uint24;
    using ProtocolFeeLibrary for uint16;

    function exactInput(IPoolManager manager_, PoolKey memory key_, bool zeroForOne_, uint256 amountIn_)
        internal
        view
        returns (Types.SwapQuote memory quote_)
    {
        return exactInput(manager_, key_, zeroForOne_, amountIn_, 0);
    }

    function exactInput(
        IPoolManager manager_,
        PoolKey memory key_,
        bool zeroForOne_,
        uint256 amountIn_,
        int128 liquidityAdjust_
    ) internal view returns (Types.SwapQuote memory quote_) {
        uint160 limit_ = zeroForOne_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
        uint24 protocolFee_;
        uint24 lpFee_;
        (quote_.sqrtPriceX96, quote_.tick, protocolFee_, lpFee_) = StateLibrary.getSlot0(manager_, key_.toId());
        quote_.liquidity = StateLibrary.getLiquidity(manager_, key_.toId());
        if (liquidityAdjust_ != 0) quote_.liquidity = LiquidityMath.addDelta(quote_.liquidity, liquidityAdjust_);
        if (amountIn_ == 0 || quote_.sqrtPriceX96 == 0) return quote_;
        uint16 protocol_ = zeroForOne_ ? protocolFee_.getZeroForOneFee() : protocolFee_.getOneForZeroFee();
        uint24 swapFee_ = protocol_ == 0 ? lpFee_ : protocol_.calculateSwapFee(lpFee_);
        uint256 remaining_ = amountIn_;
        while (remaining_ != 0 && quote_.sqrtPriceX96 != limit_) {
            uint160 before_ = quote_.sqrtPriceX96;
            int24 beforeTick_ = quote_.tick;
            uint256 beforeRemaining_ = remaining_;
            (int24 tickNext_, bool initialized_) = _nextTick(manager_, key_, quote_.tick, zeroForOne_);
            if (tickNext_ < TickMath.MIN_TICK) tickNext_ = TickMath.MIN_TICK;
            if (tickNext_ > TickMath.MAX_TICK) tickNext_ = TickMath.MAX_TICK;
            uint160 sqrtNext_ = TickMath.getSqrtPriceAtTick(tickNext_);
            (uint160 sqrtNextPrice_, uint256 amountInStep_, uint256 amountOutStep_, uint256 feeAmount_) = SwapMath
                .computeSwapStep(
                quote_.sqrtPriceX96,
                SwapMath.getSqrtPriceTarget(zeroForOne_, sqrtNext_, limit_),
                quote_.liquidity,
                -int256(remaining_),
                swapFee_
            );
            uint256 paid_ = amountInStep_ + feeAmount_;
            if (paid_ > remaining_) paid_ = remaining_;
            remaining_ -= paid_;
            quote_.spent += paid_;
            quote_.received += amountOutStep_;
            quote_.sqrtPriceX96 = sqrtNextPrice_;
            if (quote_.sqrtPriceX96 == sqrtNext_) {
                if (initialized_) {
                    int128 liquidityNet_ = _liquidityNet(manager_, key_, tickNext_);
                    int128 net_ = zeroForOne_ ? -liquidityNet_ : liquidityNet_;
                    quote_.liquidity = LiquidityMath.addDelta(quote_.liquidity, net_);
                }
                quote_.tick = zeroForOne_ ? tickNext_ - 1 : tickNext_;
            } else if (quote_.sqrtPriceX96 != before_) {
                quote_.tick = TickMath.getTickAtSqrtPrice(quote_.sqrtPriceX96);
            }
            if (quote_.sqrtPriceX96 == before_ && quote_.tick == beforeTick_ && remaining_ == beforeRemaining_) break;
        }
    }

    function _nextTick(IPoolManager manager_, PoolKey memory key_, int24 tick_, bool zeroForOne_)
        private
        view
        returns (int24 next_, bool initialized_)
    {
        int24 compressed_ = TickBitmap.compress(tick_, key_.tickSpacing);
        if (!zeroForOne_) ++compressed_;
        (int16 wordPos_, uint8 bitPos_) = TickBitmap.position(compressed_);
        uint256 bits_ = StateLibrary.getTickBitmap(manager_, key_.toId(), wordPos_);
        if (zeroForOne_) {
            uint256 masked_ = bits_ & (type(uint256).max >> (255 - bitPos_));
            initialized_ = masked_ != 0;
            next_ = initialized_
                ? (compressed_ - int24(uint24(bitPos_ - BitMath.mostSignificantBit(masked_)))) * key_.tickSpacing
                : (compressed_ - int24(uint24(bitPos_))) * key_.tickSpacing;
        } else {
            uint256 masked_ = bits_ & ~((uint256(1) << bitPos_) - 1);
            initialized_ = masked_ != 0;
            next_ = initialized_
                ? (compressed_ + int24(uint24(BitMath.leastSignificantBit(masked_) - bitPos_))) * key_.tickSpacing
                : (compressed_ + int24(uint24(type(uint8).max - bitPos_))) * key_.tickSpacing;
        }
    }

    function _liquidityNet(IPoolManager manager_, PoolKey memory key_, int24 tick_)
        private
        view
        returns (int128 liquidityNet_)
    {
        (, liquidityNet_) = StateLibrary.getTickLiquidity(manager_, key_.toId(), tick_);
    }
}
