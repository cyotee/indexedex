// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeUnlockContextQuote} from "contracts/interfaces/IStandardExchangeUnlockContextQuote.sol";
import {IStandardExchangeExactOutputQuantityQuote} from "contracts/interfaces/IStandardExchangeExactOutputQuantityQuote.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "../hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath as Inventory} from "../hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol";
import {UniswapV4FullSpreadPonsFamilyHookTransitionPlanner as Planner} from "./UniswapV4FullSpreadPonsFamilyHookTransitionPlanner.sol";


import {IStandardExchangeTransitionQuote as ITransition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";

import {
    UniswapV4FullSpreadPonsFamilyHookInBase
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookInBase.sol";

contract UniswapV4FullSpreadPonsFamilyHookInQueryTarget is UniswapV4FullSpreadPonsFamilyHookInBase, IStandardExchangeUnlockContextQuote, IStandardExchangeExactOutputQuantityQuote {
    function quoteInputForExactShares(bytes calldata state, uint256 sharesOut)
        external view override returns (uint256 assetsIn)
    {
        InventoryQuote memory q = _decodeInventory(state);
        if (sharesOut == 0) return 0;
        (uint256 total0, uint256 total1) = _inventoryTotals(q);
        uint256 backingIn = q.token0 ? total0 : total1;
        if (q.idle || q.supply == 0 || backingIn == 0) {
            revert IStandardExchangeErrors.InvalidRoute(q.token0 ? _token0() : _token1(), address(this));
        }
        return Inventory._blockedInputForShares(backingIn, q.token0 ? total1 : total0, sharesOut, q.supply);
    }

    function quoteSharesForExactAssets(bytes calldata state, uint256 assetsOut)
        external view override returns (uint256 sharesIn)
    {
        InventoryQuote memory q = _decodeInventory(state);
        if (assetsOut == 0) return 0;
        (uint256 total0, uint256 total1) = _inventoryTotals(q);
        return _linearExitShares(q.token0 ? total0 : total1, q.token0 ? total1 : total0,
            q.supply, assetsOut, q.token0 ? _token0() : _token1());
    }

    function quoteStateWithUnavailableUnlock(bytes calldata state, address manager)
        external view override returns (bytes memory projectedState)
    {
        InventoryQuote memory q = _decodeInventory(state);
        if (manager != address(_poolManager()) || !q.idle) return state;
        q.idle = false;
        return abi.encode(q);
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
        if (!q.idle) revert IStandardExchangeErrors.InvalidRoute(tokenIn, q.token0 ? _token0() : _token1());
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
        if (amount != 0 && operation == ITransition.Operation.WithdrawExactOut) {
            Types.Snapshot memory snapshot = _inventoryState(q);
            Types.Placement memory placement;
            (amountIn, placement) = _linearExitPlan(snapshot, q.token0, amount);
            if (amountIn > q.shares) revert ITransition.InsufficientQuoteShares(amountIn, q.shares);
            if (q.idle) _storeInventory(q, placement.afterState);
            else {
                if (q.token0) q.free0 -= amount; else q.free1 -= amount;
                q.supply -= amountIn;
            }
            q.shares -= amountIn;
            return (abi.encode(q), amountIn, amount, _inventoryAssets(q, q.shares));
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
                    if (operation == ITransition.Operation.WithdrawExactOut) {
                        if (amountOut < amount) revert ITransition.InvalidQuoteState();
                        // D55 (APEX F6): exact-output pays exactly the request; the zap-out surplus stays
                        // in the vault's free inventory, as `executeZapOutWithdrawal` books it.
                        if (q.token0) q.free0 += amountOut - amount;
                        else q.free1 += amountOut - amount;
                        amountOut = amount;
                    }
                }
            }
            if (q.idle && operation == ITransition.Operation.RedeemExactIn) _inventoryRebalance(q);
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

    function _inventoryDeposit(InventoryQuote memory q, uint256 amount) private view returns (uint256 minted) {
        if (q.supply == 0) revert IStandardExchangeErrors.InvalidRoute(q.token0 ? _token0() : _token1(), address(this));
        if (q.idle) {
            Types.Snapshot memory state = _inventoryState(q);
            Types.Plan memory plan = Planner._composition(state, _quoteParams(state, q.token0, 0), amount);
            minted = plan.shares;
            _storeInventory(q, plan.placement.afterState);
        } else {
            (uint256 reserve0, uint256 reserve1) = _inventoryTotals(q);
            minted = _sharesOutForDeposit(q.token0 ? amount : 0, q.token0 ? 0 : amount, q.supply, reserve0, reserve1);
            if (minted == 0) revert IStandardExchangeErrors.InvalidRoute(q.token0 ? _token0() : _token1(), address(this));
            if (q.token0) q.free0 += amount; else q.free1 += amount;
            q.supply += minted;
        }
        q.shares += minted;
    }





    function _inventoryRebalance(InventoryQuote memory q) private view {
        Types.Snapshot memory state = _inventoryState(q);
        Types.Plan memory plan = Planner._maintenance(state, _quoteParams(state, true, 0));
        _storeInventory(q, plan.placement.afterState);
    }
}
