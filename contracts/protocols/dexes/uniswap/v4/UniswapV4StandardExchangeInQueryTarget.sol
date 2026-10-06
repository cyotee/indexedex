// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeTransitionQuote as ITransition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";

import {
    UniswapV4StandardExchangeInBase
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol";

contract UniswapV4StandardExchangeInQueryTarget is UniswapV4StandardExchangeInBase {
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
        uint128 added = LiquidityAmounts.getLiquidityForAmounts(q.pool.sqrtPriceX96, TickMath.getSqrtPriceAtTick(q.lower), TickMath.getSqrtPriceAtTick(q.upper), excess0, excess1);
        if (added == 0) return false;
        if (added > uint128(type(int128).max)) revert ITransition.InvalidQuoteState();
        _inventoryChangeLiquidity(q, int128(added));
        return true;
    }

    function _inventoryRebalance(InventoryQuote memory q) private view {
        _inventoryCollect(q);
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
