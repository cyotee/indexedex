// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeTransitionQuote as ITransition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {UniswapV3Quoter} from "@crane/contracts/utils/math/UniswapV3Quoter.sol";
import {UniswapV3Utils} from "@crane/contracts/utils/math/UniswapV3Utils.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/SqrtPriceMath.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {LiquidityMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/LiquidityMath.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV3StandardExchangeInBase
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInBase.sol";

/**
 * @title UniswapV3StandardExchangeInQueryTarget
 * @notice Sequential inventory-transition quotes; standard previews reside on InMultiQueryFacet.
 */
abstract contract UniswapV3StandardExchangeInQueryTarget is UniswapV3StandardExchangeInBase {
    struct InventoryQuote {
        address vault;
        bool token0;
        bool idle;
        uint256 supply;
        uint256 shares;
        uint256 free0;
        uint256 free1;
        uint256 fees0;
        uint256 fees1;
        uint128 positionLiquidity;
        int24 lower;
        int24 upper;
        int128 liquidityDelta;
        UniswapV3Quoter.PoolState pool;
    }

    function quoteState(address asset, address holder) external view returns (bytes memory state, uint256 holderAssets) {
        if (asset != _token0() && asset != _token1()) revert ITransition.UnsupportedQuoteAsset(asset);
        InventoryQuote memory q;
        q.vault = address(this);
        q.token0 = asset == _token0();
        q.idle = canOpenBoundPoolOps();
        q.supply = IERC20(address(this)).totalSupply();
        q.shares = IERC20(address(this)).balanceOf(holder);
        (q.free0, q.free1) = _freeBalances();
        (q.fees0, q.fees1) = _collectableCenterFees();
        q.positionLiquidity = _getPositionLiquidityFromPool();
        ManagedTicks memory ticks = _managedTicks();
        q.lower = ticks.centerLower;
        q.upper = ticks.centerUpper;
        (q.pool.sqrtPriceX96, q.pool.tick,,,,,) = _pool().slot0();
        q.pool.liquidity = _pool().liquidity();
        state = abi.encode(q);
        holderAssets = _inventoryAssets(q, q.shares);
    }

    function quoteExternalDeposit(bytes calldata state, address tokenIn, uint256 amountIn)
        external view returns (bytes memory nextState, uint256 sharesOut, uint256 holderAssetsAfter)
    {
        InventoryQuote memory q = _decodeInventory(state);
        if (tokenIn != _token0() && tokenIn != _token1()) revert ITransition.UnsupportedQuoteAsset(tokenIn);
        bool accountingToken0 = q.token0;
        q.token0 = tokenIn == _token0();
        if (amountIn != 0) {
            sharesOut = _inventoryDeposit(q, amountIn);
            // The mint recipient is separate from the buffered holder.
            q.shares -= sharesOut;
            if (q.idle) _inventoryRebalance(q);
        }
        q.token0 = accountingToken0;
        return (abi.encode(q), sharesOut, _inventoryAssets(q, q.shares));
    }

    function quoteExternalExchange(bytes calldata state, address tokenIn, uint256 amountIn)
        external view returns (bytes memory nextState, uint256 amountOut, uint256 holderAssetsAfter)
    {
        InventoryQuote memory q = _decodeInventory(state);
        // The snapshot asset is the output. The separate caller supplies the
        // opposing pool currency; no buffered-holder shares are minted or burned.
        if (tokenIn != (q.token0 ? _token1() : _token0())) {
            revert ITransition.UnsupportedQuoteAsset(tokenIn);
        }
        if (!q.idle) revert ITransition.InvalidQuoteState();
        if (amountIn != 0) {
            amountOut = _inventorySwap(q, amountIn);
            _inventoryRebalance(q);
        }
        return (abi.encode(q), amountOut, _inventoryAssets(q, q.shares));
    }

    function quoteTotalSupply(bytes calldata state) external view returns (uint256) {
        return _decodeInventory(state).supply;
    }

    function quoteShareBalance(bytes calldata state) external view returns (uint256) {
        return _decodeInventory(state).shares;
    }

    function quoteAssets(bytes calldata state, uint256 shares) external view returns (uint256) {
        return _inventoryAssets(_decodeInventory(state), shares);
    }

    function quoteTransition(bytes calldata state, ITransition.Operation operation, uint256 amount)
        external view returns (bytes memory nextState, uint256 amountIn, uint256 amountOut, uint256 holderAssetsAfter)
    {
        InventoryQuote memory q = _decodeInventory(state);
        if (operation == ITransition.Operation.ReceiveShares) {
            q.shares += amount;
            if (q.shares > q.supply) revert ITransition.InvalidQuoteState();
            return (abi.encode(q), amount, amount, _inventoryAssets(q, q.shares));
        }
        if (amount != 0) {
            if (operation == ITransition.Operation.DepositExactIn) {
                amountIn = amount;
                amountOut = _inventoryDeposit(q, amount);
            } else {
                amountIn = operation == ITransition.Operation.RedeemExactIn ? amount : _inventorySharesIn(q, amount);
                if (amountIn == 0 || amountIn > q.shares) {
                    revert ITransition.InsufficientQuoteShares(amountIn, q.shares);
                }
                if (!q.idle) {
                    amountOut = operation == ITransition.Operation.WithdrawExactOut
                        ? amount : _inventoryAssets(q, amountIn);
                    if (amountOut > (q.token0 ? q.free0 : q.free1)) revert ITransition.InvalidQuoteState();
                    if (q.token0) q.free0 -= amountOut;
                    else q.free1 -= amountOut;
                    q.supply -= amountIn;
                    q.shares -= amountIn;
                } else {
                    amountOut = _inventoryRedeem(q, amountIn);
                    if (operation == ITransition.Operation.WithdrawExactOut && amountOut < amount) {
                        revert ITransition.InvalidQuoteState();
                    }
                }
            }
            if (q.idle) _inventoryRebalance(q);
        }
        nextState = abi.encode(q);
        holderAssetsAfter = _inventoryAssets(q, q.shares);
    }

    function _decodeInventory(bytes memory state) private view returns (InventoryQuote memory q) {
        q = abi.decode(state, (InventoryQuote));
        if (q.vault != address(this) || q.shares > q.supply || q.lower >= q.upper) {
            revert ITransition.InvalidQuoteState();
        }
    }

    function _inventoryAssets(InventoryQuote memory q, uint256 shares) private view returns (uint256) {
        if (shares == 0 || q.supply == 0) return 0;
        InventoryQuote memory copy = abi.decode(abi.encode(q), (InventoryQuote));
        copy.shares = shares;
        return _inventoryRedeem(copy, shares);
    }

    function _inventoryTotals(InventoryQuote memory q) private pure returns (uint256 total0, uint256 total1) {
        (total0, total1) = _inventoryPositionAmounts(q, q.positionLiquidity, false);
        total0 += q.free0 + q.fees0;
        total1 += q.free1 + q.fees1;
    }

    function _inventoryCollect(InventoryQuote memory q) private pure {
        q.free0 += q.fees0;
        q.free1 += q.fees1;
        q.fees0 = 0;
        q.fees1 = 0;
    }

    function _inventoryDeposit(InventoryQuote memory q, uint256 amount) private pure returns (uint256 minted) {
        if (q.idle) _inventoryCollect(q);
        (uint256 reserve0, uint256 reserve1) = _inventoryTotals(q);
        uint256 added0 = q.token0 ? amount : 0;
        uint256 added1 = q.token0 ? 0 : amount;
        minted = _sharesOutForDeposit(added0, added1, q.supply, reserve0, reserve1);
        if (minted == 0) revert ITransition.InvalidQuoteState();
        if (q.supply == 0) q.supply = _initialResidualShares(added0, added1, reserve0, reserve1, minted);
        q.free0 += added0;
        q.free1 += added1;
        q.supply += minted;
        q.shares += minted;
    }

    function _inventoryRedeem(InventoryQuote memory q, uint256 shares) private view returns (uint256 assets) {
        if (shares > q.supply) revert ITransition.InvalidQuoteState();
        if (!q.idle) {
            (uint256 total0, uint256 total1) = _inventoryTotals(q);
            assets = Math.mulDiv(q.token0 ? total0 : total1, shares, q.supply);
            // quoteAssets values inventory even when the liquid sleeve cannot pay it yet.
            if (q.token0) q.free0 = assets <= q.free0 ? q.free0 - assets : 0;
            else q.free1 = assets <= q.free1 ? q.free1 - assets : 0;
        } else {
            _inventoryCollect(q);
            uint256 out0 = Math.mulDiv(q.free0, shares, q.supply);
            uint256 out1 = Math.mulDiv(q.free1, shares, q.supply);
            uint128 burned = uint128(Math.mulDiv(q.positionLiquidity, shares, q.supply));
            if (burned > uint128(type(int128).max)) revert ITransition.InvalidQuoteState();
            (uint256 principal0, uint256 principal1) = _inventoryPositionAmounts(q, burned, false);
            _inventoryChangeLiquidity(q, -int128(burned));
            out0 += principal0;
            out1 += principal1;
            q.free0 -= out0;
            q.free1 -= out1;
            assets = q.token0 ? out0 : out1;
            uint256 other = q.token0 ? out1 : out0;
            if (other != 0) assets += _inventorySwap(q, other);
        }
        q.supply -= shares;
        q.shares -= shares;
    }

    function _inventorySharesIn(InventoryQuote memory q, uint256 amount) private view returns (uint256) {
        if (q.supply == 0) return 0;
        if (!q.idle) {
            (uint256 total0, uint256 total1) = _inventoryTotals(q);
            uint256 reserve = q.token0 ? total0 : total1;
            if (reserve == 0) return 0;
            return Math.min(q.supply, Math.mulDiv(amount, q.supply, reserve, Math.Rounding.Ceil));
        }
        if (q.positionLiquidity == 0 && (q.token0 ? q.free1 + q.fees1 : q.free0 + q.fees0) == 0) {
            uint256 reserve = q.token0 ? q.free0 + q.fees0 : q.free1 + q.fees1;
            if (amount >= reserve) return q.supply;
            return _bufferedInventoryShares(Math.mulDiv(amount, q.supply, reserve, Math.Rounding.Ceil), q.supply);
        }
        uint256 low = 1;
        uint256 high = q.supply;
        while (low < high) {
            uint256 mid = low + (high - low) / 2;
            if (_inventoryAssets(q, mid) >= amount) high = mid;
            else low = mid + 1;
        }
        return _bufferedInventoryShares(high, q.supply);
    }

    function _bufferedInventoryShares(uint256 shares, uint256 supply) private pure returns (uint256) {
        if (shares >= supply) return supply;
        uint256 buffer = Math.max(shares / 100, 1);
        return buffer > supply - shares ? supply : shares + buffer;
    }

    function _inventorySwap(InventoryQuote memory q, uint256 amount) private view returns (uint256) {
        bool zeroForOne = !q.token0;
        UniswapV3Quoter.SwapQuoteParams memory p = UniswapV3Quoter.SwapQuoteParams({
            pool: _pool(), zeroForOne: zeroForOne, amount: amount,
            sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            maxSteps: 0
        });
        (UniswapV3Quoter.SwapQuoteResult memory result, uint256 growth) = UniswapV3Quoter.quoteFromState(
            p, true, UniswapV3Quoter.LiquidityChange(q.lower, q.upper, q.liquidityDelta), q.pool, true
        );
        // Price-limit fills leave the unspent input in the vault.
        if (zeroForOne) q.free0 += amount - result.amountIn;
        else q.free1 += amount - result.amountIn;
        q.pool = UniswapV3Quoter.PoolState(result.sqrtPriceAfterX96, result.tickAfter, result.liquidityAfter);
        uint256 fees = Math.mulDiv(growth, q.positionLiquidity, uint256(1) << 128);
        if (zeroForOne) q.fees0 += fees;
        else q.fees1 += fees;
        return result.amountOut;
    }

    function _inventoryPositionAmounts(InventoryQuote memory q, uint128 liquidity, bool roundUp)
        private pure returns (uint256 amount0, uint256 amount1)
    {
        uint160 lower = TickMath.getSqrtRatioAtTick(q.lower);
        uint160 upper = TickMath.getSqrtRatioAtTick(q.upper);
        if (q.pool.tick < q.lower) amount0 = SqrtPriceMath.getAmount0Delta(lower, upper, liquidity, roundUp);
        else if (q.pool.tick < q.upper) {
            amount0 = SqrtPriceMath.getAmount0Delta(q.pool.sqrtPriceX96, upper, liquidity, roundUp);
            amount1 = SqrtPriceMath.getAmount1Delta(lower, q.pool.sqrtPriceX96, liquidity, roundUp);
        } else amount1 = SqrtPriceMath.getAmount1Delta(lower, upper, liquidity, roundUp);
    }

    function _inventoryChangeLiquidity(InventoryQuote memory q, int128 delta) private pure {
        if (delta == 0) return;
        bool adding = delta > 0;
        (uint256 amount0, uint256 amount1) = _inventoryPositionAmounts(q, uint128(adding ? delta : -delta), adding);
        if (adding) {
            q.free0 -= amount0;
            q.free1 -= amount1;
        } else {
            _inventoryCollect(q);
            q.free0 += amount0;
            q.free1 += amount1;
        }
        q.positionLiquidity = LiquidityMath.addDelta(q.positionLiquidity, delta);
        if (q.pool.tick >= q.lower && q.pool.tick < q.upper) {
            q.pool.liquidity = LiquidityMath.addDelta(q.pool.liquidity, delta);
        }
        q.liquidityDelta += delta;
    }

    function _inventoryRebalanceSnap(InventoryQuote memory q) private view returns (RebalanceSnap memory s) {
        s.free0 = q.free0;
        s.free1 = q.free1;
        (s.deployed0, s.deployed1) = _inventoryPositionAmounts(q, q.positionLiquidity, false);
        s.liquidPct = _liveLiquidReservePercentage();
        s.target0 = _targetFree(s.free0 + s.deployed0, s.liquidPct);
        s.target1 = _targetFree(s.free1 + s.deployed1, s.liquidPct);
    }

    function _inventoryDeploy(InventoryQuote memory q, RebalanceSnap memory s) private pure returns (bool) {
        uint256 excess0 = s.free0 > s.target0 ? s.free0 - s.target0 : 0;
        uint256 excess1 = s.free1 > s.target1 ? s.free1 - s.target1 : 0;
        uint128 added = UniswapV3Utils._quoteLiquidityForAmounts(q.pool.sqrtPriceX96, q.lower, q.upper, excess0, excess1);
        if (added == 0) return false;
        if (added > uint128(type(int128).max)) revert ITransition.InvalidQuoteState();
        _inventoryChangeLiquidity(q, int128(added));
        return true;
    }

    function _inventoryRebalance(InventoryQuote memory q) private view {
        RebalanceSnap memory s = _inventoryRebalanceSnap(q);
        uint256 floor0 = _absoluteFloor(_token0());
        uint256 floor1 = _absoluteFloor(_token1());
        if (!_shouldRebalanceToken(s.free0, s.target0, floor0) && !_shouldRebalanceToken(s.free1, s.target1, floor1)) return;
        bool moved = _inventoryDeploy(q, s);
        s = _inventoryRebalanceSnap(q);
        uint256 fraction;
        if (s.free0 < s.target0 && s.deployed0 > 0) fraction = (s.target0 - s.free0) * ONE_WAD / s.deployed0;
        if (s.free1 < s.target1 && s.deployed1 > 0) {
            fraction = Math.max(fraction, (s.target1 - s.free1) * ONE_WAD / s.deployed1);
        }
        uint128 removed = uint128(uint256(q.positionLiquidity) * Math.min(fraction, ONE_WAD) / ONE_WAD);
        if (removed > 0) {
            if (removed > uint128(type(int128).max)) revert ITransition.InvalidQuoteState();
            _inventoryChangeLiquidity(q, -int128(removed));
            moved = true;
        }
        if (moved) {
            s = _inventoryRebalanceSnap(q);
            if ((_shouldRebalanceToken(s.free0, s.target0, floor0) && s.free0 > s.target0)
                || (_shouldRebalanceToken(s.free1, s.target1, floor1) && s.free1 > s.target1)) _inventoryDeploy(q, s);
        }
    }
}
