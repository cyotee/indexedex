// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4FullSpreadPonsFamilyHookFeeService as PonsFees} from "./UniswapV4FullSpreadPonsFamilyHookFeeService.sol";

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SwapMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SwapMath.sol";
import {ProtocolFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/ProtocolFeeLibrary.sol";
import {BitMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/BitMath.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {UniswapV4Quoter} from "@crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Quoter.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "../hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath as Protection} from "../hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath.sol";

// tag::UniswapV4FullSpreadPonsFamilyHookQuoteService[]
/// @notice Pons-specific forward simulation and strict one-step exact-output debt.
library UniswapV4FullSpreadPonsFamilyHookQuoteService {
    using PoolIdLibrary for PoolKey;
    error QuoteWorkLimit();
    error AccountingMismatch();
    error ExecutionShortfall();

    uint32 internal constant MAX_CORE_STEPS = 64;

    struct Params {
        IPoolManager manager;
        PoolKey key;
        Types.PositionState position;
        bool zeroForOne;
        uint256 amount;
        address nativeFace;
    }

    function _forward(Params memory params_) public view returns (Types.Swap memory result_) {
        bool filled;
        (result_, filled) = _tryForward(params_);
        if (!filled) revert QuoteWorkLimit();
    }

    /// @notice F6 alone retains input left at the directional price limit.
    /// @dev A 64-step truncation away from that limit is still a work-limit failure.
    function _redemptionForward(Params memory params_) public view returns (Types.Swap memory result_) {
        bool filled;
        (result_, filled) = _tryForwardBounded(params_, true);
        if (!filled) revert QuoteWorkLimit();
    }

    /// @notice Verify the actual F6 fill; kept in the linked family library for facet headroom.
    function _verifyRedemption(Params memory params_, Types.Swap memory swap_, BalanceDelta delta_) public view {
        int128 input = params_.zeroForOne ? BalanceDeltaLibrary.amount0(delta_) : BalanceDeltaLibrary.amount1(delta_);
        int128 output = params_.zeroForOne ? BalanceDeltaLibrary.amount1(delta_) : BalanceDeltaLibrary.amount0(delta_);
        if (input > 0 || output < 0) revert AccountingMismatch();
        uint256 received = uint256(int256(output));
        if (!Protection._shortfallWithin(swap_.amountOut, received)) revert ExecutionShortfall();
        (uint160 price, int24 tick,,) = StateLibrary.getSlot0(params_.manager, params_.key.toId());
        if (uint256(-int256(input)) != swap_.amountIn || received != swap_.amountOut
            || price != swap_.sqrtPriceAfterX96 || tick != swap_.tickAfter
            || StateLibrary.getLiquidity(params_.manager, params_.key.toId()) != swap_.liquidityAfter)
            revert AccountingMismatch();
    }

    function _tryForward(Params memory params_) public view returns (Types.Swap memory result_, bool filled_) {
        return _tryForwardBounded(params_, false);
    }

    function _tryForwardBounded(Params memory params_, bool redemption_) private view returns (Types.Swap memory result_, bool filled_) {
        (bool valid,,) = PonsFees._terms(params_.manager, params_.key);
        if (!valid) _invalid(params_);
        if (params_.amount > uint256(uint128(type(int128).max))) return (result_, false);
        if (redemption_ && params_.position.sqrtPriceX96 == _limit(params_.zeroForOne)) {
            result_.zeroForOne = params_.zeroForOne;
            result_.sqrtPriceAfterX96 = params_.position.sqrtPriceX96;
            result_.tickAfter = params_.position.tick;
            result_.liquidityAfter = params_.position.activeLiquidity;
            return (result_, true);
        }
        if (params_.amount != 0 && (params_.zeroForOne
            ? params_.position.sqrtPriceX96 <= _limit(true)
            : params_.position.sqrtPriceX96 >= _limit(false))) return (result_, false);
        (UniswapV4Quoter.SwapQuoteResult memory quote, uint256 growth) = UniswapV4Quoter.quoteFromState(
            UniswapV4Quoter.SwapQuoteParams({
                manager: params_.manager,
                key: params_.key,
                zeroForOne: params_.zeroForOne,
                amount: params_.amount,
                sqrtPriceLimitX96: _limit(params_.zeroForOne),
                maxSteps: MAX_CORE_STEPS
            }),
            true,
            UniswapV4Quoter.LiquidityChange(params_.position.lower, params_.position.upper, params_.position.liquidityChange),
            UniswapV4Quoter.PoolState(params_.position.sqrtPriceX96, params_.position.tick, params_.position.activeLiquidity),
            true
        );
        filled_ = (quote.fullyFilled || (redemption_ && quote.sqrtPriceAfterX96 == _limit(params_.zeroForOne)))
            && quote.amountOut <= uint256(uint128(type(int128).max));
        result_ = Types.Swap({
            zeroForOne: params_.zeroForOne,
            amountIn: quote.amountIn,
            amountOut: quote.amountOut - _hookCharge(params_, quote.amountOut),
            feeAmount: quote.feeAmount,
            feeGrowthInsideX128: growth,
            steps: quote.steps,
            sqrtPriceAfterX96: quote.sqrtPriceAfterX96,
            tickAfter: quote.tickAfter,
            liquidityAfter: quote.liquidityAfter
        });
    }

    function _exactOutput(Params memory params_) public view returns (Types.Swap memory result_) {
        // Exact-output never invokes the traversing quoter or an input search.
        (bool valid,,) = PonsFees._terms(params_.manager, params_.key);
        if (!valid || params_.position.liquidityChange != 0
            || params_.position.activeLiquidity == 0 || params_.amount > uint256(uint128(type(int128).max))) _invalid(params_);
        (, , uint24 protocolFees, uint24 lpFee) = StateLibrary.getSlot0(params_.manager, params_.key.toId());
        uint16 protocolFee = params_.zeroForOne
            ? ProtocolFeeLibrary.getZeroForOneFee(protocolFees) : ProtocolFeeLibrary.getOneForZeroFee(protocolFees);
        uint24 fee = ProtocolFeeLibrary.calculateSwapFee(protocolFee, lpFee);
        if (fee >= 1_000_000) _invalid(params_);
        uint160 target = _firstTarget(params_);
        uint256 netInput;
        (result_.sqrtPriceAfterX96, netInput, result_.amountOut, result_.feeAmount) = SwapMath.computeSwapStep(
            params_.position.sqrtPriceX96, target, params_.position.activeLiquidity, int256(params_.amount), fee
        );
        if (result_.amountOut != params_.amount || result_.sqrtPriceAfterX96 == target) _invalid(params_);
        result_.amountIn = netInput + result_.feeAmount;
        if (result_.amountIn > uint256(uint128(type(int128).max))) _invalid(params_);
        result_.zeroForOne = params_.zeroForOne;
        result_.steps = params_.amount == 0 ? 0 : 1;
        result_.tickAfter = TickMath.getTickAtSqrtPrice(result_.sqrtPriceAfterX96);
        result_.liquidityAfter = params_.position.activeLiquidity;
        if (params_.position.tick >= params_.position.lower && params_.position.tick < params_.position.upper) {
            uint256 ownLpFee = result_.feeAmount;
            if (protocolFee != 0) {
                ownLpFee -= fee == protocolFee ? ownLpFee : Math.mulDiv(result_.amountIn, protocolFee, 1_000_000);
            }
            result_.feeGrowthInsideX128 = Math.mulDiv(ownLpFee, uint256(1) << 128, result_.liquidityAfter);
        }
        result_.amountIn += _hookCharge(params_, result_.amountIn);
        if (result_.amountIn > uint256(uint128(type(int128).max))) _invalid(params_);
    }

    function _hookCharge(Params memory params_, uint256 amount_) private view returns (uint256) {
        (, uint16 hookFee, uint16 creatorTax) = PonsFees._terms(params_.manager, params_.key);
        return PonsFees._charge(amount_, hookFee, creatorTax);
    }

    function _firstTarget(Params memory params_) internal view returns (uint160) {
        int24 spacing = params_.key.tickSpacing;
        int24 compressed = params_.position.tick / spacing;
        if (params_.position.tick < 0 && params_.position.tick % spacing != 0) --compressed;
        if (!params_.zeroForOne) ++compressed;
        uint8 bit = uint8(uint24(compressed));
        uint256 word = StateLibrary.getTickBitmap(params_.manager, params_.key.toId(), int16(compressed >> 8));
        int24 next;
        if (params_.zeroForOne) {
            word &= type(uint256).max >> (255 - bit);
            next = (compressed - int24(uint24(bit)) + (word == 0 ? int24(0) : int24(uint24(BitMath.mostSignificantBit(word))))) * spacing;
        } else {
            word &= type(uint256).max << bit;
            next = (compressed - int24(uint24(bit)) + (word == 0 ? int24(255) : int24(uint24(BitMath.leastSignificantBit(word))))) * spacing;
        }
        if (next < TickMath.MIN_TICK) next = TickMath.MIN_TICK;
        if (next > TickMath.MAX_TICK) next = TickMath.MAX_TICK;
        return SwapMath.getSqrtPriceTarget(params_.zeroForOne, TickMath.getSqrtPriceAtTick(next), _limit(params_.zeroForOne));
    }

    function _limit(bool zeroForOne_) private pure returns (uint160) {
        return zeroForOne_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
    }

    function _invalid(Params memory params_) private pure {
        address token0 = Currency.unwrap(params_.key.currency0);
        address token1 = Currency.unwrap(params_.key.currency1);
        if (token0 == address(0)) token0 = params_.nativeFace;
        if (token1 == address(0)) token1 = params_.nativeFace;
        revert IStandardExchangeErrors.InvalidRoute(
            params_.zeroForOne ? token0 : token1,
            params_.zeroForOne ? token1 : token0
        );
    }
}
// end::UniswapV4FullSpreadPonsFamilyHookQuoteService[]
