// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath as Inventory} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner as Planner} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService as Quotes} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol";


import {StandardExchangeConstantProduct} from "../../../StandardExchangeConstantProduct.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {Actions} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Actions.sol";
import {PositionInfo} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/PositionInfoLibrary.sol";

import {UniswapV4FullSpreadHooklessStandardExchangeVaultPositionRepo} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultPositionRepo.sol";
import {
    UniswapV4FullSpreadHooklessStandardExchangeVaultCommon
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol";
import {
    IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/interfaces/IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.sol";

abstract contract UniswapV4FullSpreadHooklessStandardExchangeVaultInBase is UniswapV4FullSpreadHooklessStandardExchangeVaultCommon, ReentrancyLockModifiers {
    error UniswapV4ExchangeIn_DeadlineExceeded();
    error UniswapV4ExchangeIn_SlippageExceeded();
    error UniswapV4ExchangeIn_PositionImportUnavailable();
    error UniswapV4ExchangeIn_InvalidImportedPool();
    error UniswapV4ExchangeIn_UntrustedPositionManager();
    error UniswapV4ExchangeIn_UntrustedImportOwner();

    function _swapExactIn(bool zeroForOne, uint256 amountSpecified) internal {
        Types.Snapshot memory state = _snapshot(0, 0);
        Types.Swap memory swap = Quotes._forward(_quoteParams(state, zeroForOne, amountSpecified));
        _commitExecutionPlan(keccak256(abi.encode(swap)), 0, 0);
        _executePlannedSwap(swap, false, 0);
    }

    function _swapRedemptionExactIn(bool zeroForOne, uint256 entitlement) private {
        Quotes.Params memory params = _quoteParams(_snapshot(0, 0), zeroForOne, entitlement);
        Types.Swap memory swap = Quotes._redemptionForward(params);
        if (swap.amountIn == 0 && swap.sqrtPriceAfterX96 == params.position.sqrtPriceX96) return;
        _commitExecutionPlan(keccak256(abi.encode(swap)), 0, 0);
        // Keep the original budget: zero-liquidity travel after the last paid step
        // must reach the same price limit as the partial-fill quote.
        Quotes._verifyRedemption(params, swap, _executeUnlock(OperationParams({
            op: Operation.SwapExactIn, zeroForOne: zeroForOne, amountSpecified: entitlement,
            tickLower: 0, tickUpper: 0, liquidity: 0, salt: bytes32(0)
        })));
    }

    function _addLiquidity(int24 tickLower, int24 tickUpper, uint128 liquidity, bytes32 salt) internal {
        _executeUnlock(
            OperationParams({
                op: Operation.AddLiquidity,
                zeroForOne: false,
                amountSpecified: 0,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidity: liquidity,
                salt: salt
            })
        );
    }

    function _removeLiquidity(int24 tickLower, int24 tickUpper, uint128 liquidity, bytes32 salt) internal {
        _executeUnlock(
            OperationParams({
                op: Operation.RemoveLiquidity,
                zeroForOne: false,
                amountSpecified: 0,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidity: liquidity,
                salt: salt
            })
        );
    }

    function _createManagedPositionsIfNeeded(ManagedTicks memory managedTicks) internal {
        _createManagedPositionsIfNeededCommon(managedTicks);
    }

    function _executeDirectSwapIn(address tokenIn, uint256 amountIn, address recipient)
        internal
        returns (uint256 amountOut)
    {
        _commitExecutionPlan(keccak256(abi.encode(Types.Workflow.DirectExactInput, tokenIn, amountIn, recipient, _snapshot(0, 0))), 0, 0);
        _collectManagedFeesIfIdle();
        // Direct swaps use only caller credit; holder repair follows payout.
        bool zeroForOne = tokenIn == _token0();
        address tokenOut = zeroForOne ? _token1() : _token0();
        uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));

        _swapExactIn(zeroForOne, amountIn);

        amountOut = IERC20(tokenOut).balanceOf(address(this)) - balanceBefore;
        _transferCurrency(tokenOut, recipient, amountOut);
        _syncVaultReserves();
        _rebalanceLiquidReserveBestEffort();
    }

    function _previewZapOutExactIn(address tokenOut, uint256 sharesBurned) internal view returns (uint256 amountOut) {
        if (sharesBurned == 0) {
            return 0;
        }

        uint256 totalShares = IERC20(address(this)).totalSupply();
        if (totalShares == 0) revert IStandardExchangeErrors.InvalidRoute(address(this), tokenOut);

        // D24: blocked preview models sleeve cover only; free models PM path.
        if (!canOpenPoolManagerUnlock()) {
            uint256 output = _quoteSleeveZapOutAmount(tokenOut, sharesBurned, totalShares);
            uint256 available = _localBalance(tokenOut);
            if (output > available) revert UniswapV4Exchange_InsufficientLocalReserve(tokenOut, output, available);
            if (output == 0) revert IStandardExchangeErrors.InvalidRoute(address(this), tokenOut);
            return output;
        }

        return _quoteZapOutAmount(tokenOut, sharesBurned, totalShares);
    }

    function _quoteZapOutAmount(address tokenOut, uint256 sharesBurned, uint256 totalShares)
        internal
        view
        returns (uint256 amountOut)
    {
        (uint256 amount0, uint256 amount1) = _quoteManagedWithdrawal(sharesBurned, totalShares);
        // Also credit pro-rata free sleeve on burn (totals include free).
        (uint256 free0, uint256 free1) = _freeBalancesForShareMath();
        amount0 += Math.mulDiv(free0, sharesBurned, totalShares);
        amount1 += Math.mulDiv(free1, sharesBurned, totalShares);
        if (tokenOut == _token0()) {
            return amount0 + (amount1 > 0 ? _quoteSwapAfterWithdrawal(amount1, false, sharesBurned, totalShares) : 0);
        }
        return amount1 + (amount0 > 0 ? _quoteSwapAfterWithdrawal(amount0, true, sharesBurned, totalShares) : 0);
    }

    /// @dev Proportional burn plus fee-free conversion against the remaining complete book.
    function _quoteSleeveZapOutAmount(address tokenOut, uint256 sharesBurned, uint256 totalShares)
        internal
        view
        returns (uint256 amountOut)
    {
        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
        return tokenOut == _token0()
            ? StandardExchangeConstantProduct._singleExit(reserve0, reserve1, sharesBurned, totalShares)
            : StandardExchangeConstantProduct._singleExit(reserve1, reserve0, sharesBurned, totalShares);
    }

    function _executeZapOutExactIn(address tokenOut, uint256 sharesBurned, uint256 minAmountOut, address recipient)
        internal
        returns (uint256 amountOut)
    {
        if (sharesBurned == 0) {
            revert UniswapV4Exchange_ZeroAmount();
        }

        uint256 totalShares = IERC20(address(this)).totalSupply();
        if (totalShares == 0) revert IStandardExchangeErrors.InvalidRoute(address(this), tokenOut);

        if (!canOpenPoolManagerUnlock()) {
            // D18: blocked — pay from free inventory of tokenOut or revert InsufficientLocalReserve.
            amountOut = _quoteSleeveZapOutAmount(tokenOut, sharesBurned, totalShares);
            uint256 freeOut = _localBalance(tokenOut);
            if (amountOut == 0 || freeOut < amountOut) {
                revert UniswapV4Exchange_InsufficientLocalReserve(
                    tokenOut, amountOut == 0 ? minAmountOut : amountOut, freeOut
                );
            }
            if (amountOut < minAmountOut) revert UniswapV4ExchangeIn_SlippageExceeded();
            ERC20Repo._burn(address(this), sharesBurned);
            _transferCurrency(tokenOut, recipient, amountOut);
            _syncVaultReserves();
            return amountOut;
        }

        // D3: free path always uses PoolManager even if sleeve would cover; then rebalance.
        amountOut = _executeFreeZapOutExactIn(tokenOut, sharesBurned, totalShares, minAmountOut, recipient);
    }

    function _executeFreeZapOutExactIn(
        address tokenOut,
        uint256 sharesBurned,
        uint256 totalShares,
        uint256 minAmountOut,
        address recipient
    ) internal returns (uint256 amountOut) {
        _commitExecutionPlan(keccak256(abi.encode(Types.Workflow.Redeem, tokenOut, sharesBurned, totalShares, _snapshot(0, 0))), 0, 0);
        _collectManagedFeesIfIdle();
        bool outIsToken0 = tokenOut == _token0();
        address otherToken = outIsToken0 ? _token1() : _token0();

        (uint256 free0, uint256 free1) = _freeBalances();
        uint256 freePortionOther =
            outIsToken0 ? Math.mulDiv(free1, sharesBurned, totalShares) : Math.mulDiv(free0, sharesBurned, totalShares);
        uint256 freeOutShare = outIsToken0 ? Math.mulDiv(free0, sharesBurned, totalShares) : Math.mulDiv(free1, sharesBurned, totalShares);

        uint256 otherBefore = IERC20(otherToken).balanceOf(address(this));
        uint256 outBefore = IERC20(tokenOut).balanceOf(address(this));

        _burnPositionLiquidity(sharesBurned, totalShares);

        {
            uint256 removedOther = IERC20(otherToken).balanceOf(address(this)) - otherBefore;
            uint256 otherForUser = removedOther + freePortionOther;
            uint256 otherBal = IERC20(otherToken).balanceOf(address(this));
            if (otherForUser > otherBal) revert AccountingMismatch();
            if (otherForUser > 0) {
                _swapRedemptionExactIn(!outIsToken0, otherForUser);
            }
        }

        amountOut = (IERC20(tokenOut).balanceOf(address(this)) - outBefore) + freeOutShare;
        {
            uint256 bal = _localBalance(tokenOut);
            if (amountOut > bal) revert AccountingMismatch();
        }
        if (amountOut < minAmountOut) revert UniswapV4ExchangeIn_SlippageExceeded();

        ERC20Repo._burn(address(this), sharesBurned);
        _transferCurrency(tokenOut, recipient, amountOut);
        _syncVaultReserves();
        _rebalanceLiquidReserveBestEffort();
    }

    function _burnPositionLiquidity(uint256 sharesBurned, uint256 totalShares)
        internal
    {
        uint128 currentLiquidity = _currentLiquidity();
        if (currentLiquidity == 0) {
            return;
        }

        uint128 liquidityToBurn = uint128(Math.mulDiv(sharesBurned, currentLiquidity, totalShares));
        if (liquidityToBurn == 0) {
            return;
        }

        if (UniswapV4FullSpreadHooklessStandardExchangeVaultPositionRepo._isImportedPosition()) {

            bytes memory actions = abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR));
            bytes[] memory params = new bytes[](2);
            params[0] = abi.encode(
                UniswapV4FullSpreadHooklessStandardExchangeVaultPositionRepo._importedPositionTokenId(),
                uint256(liquidityToBurn),
                uint128(0),
                uint128(0),
                bytes("")
            );
            params[1] = abi.encode(_currency0(), _currency1(), address(this));
            UniswapV4FullSpreadHooklessStandardExchangeVaultPositionRepo._importedPositionManager()
                .modifyLiquidities(abi.encode(actions, params), block.timestamp);
            return;
        }

        (int24 tickLower, int24 tickUpper) = UniswapV4FullSpreadHooklessStandardExchangeVaultPositionRepo._positionTicks();
        _removeLiquidity(tickLower, tickUpper, liquidityToBurn, UniswapV4FullSpreadHooklessStandardExchangeVaultPositionRepo._salt());
    }

    
    function _previewZapInDeposit(address tokenIn, uint256 amountIn) internal view returns (uint256 sharesOut) {
        if (amountIn == 0) return 0;
        Types.Snapshot memory state = _snapshot(0, 0);
        if (state.book.supply == 0) revert IStandardExchangeErrors.InvalidRoute(tokenIn, address(this));
        if (state.idle) return Planner._composition(state, _quoteParams(state, tokenIn == _token0(), 0), amountIn).shares;
        uint256[2] memory backing = Inventory._totals(state.book);
        sharesOut = _sharesOutForDeposit(tokenIn == _token0() ? amountIn : 0, tokenIn == _token1() ? amountIn : 0,
            state.book.supply, backing[0], backing[1]);
        if (sharesOut == 0) revert IStandardExchangeErrors.InvalidRoute(tokenIn, address(this));
    }

    
    function _executeZapInDeposit(address tokenIn, uint256 amountIn, uint256 minSharesOut, address recipient)
        internal returns (uint256 sharesOut)
    {
        if (amountIn == 0) revert UniswapV4Exchange_ZeroAmount();
        bool token0 = tokenIn == _token0();
        Types.Snapshot memory state = _snapshot(token0 ? amountIn : 0, token0 ? 0 : amountIn);
        if (state.idle) {
            Types.Plan memory plan = Planner._composition(state, _quoteParams(state, token0, 0), amountIn);
            sharesOut = plan.shares;
            if (sharesOut < minSharesOut) revert UniswapV4ExchangeIn_SlippageExceeded();
            _commitExecutionPlan(keccak256(abi.encode(plan)), 0, 0);
            _collectManagedFeesIfIdle();
            if (plan.swap.amountIn != 0) _executePlannedSwap(plan.swap, false, COMPOSITION_IMPACT_BPS);
            _collectManagedFeesIfIdle();
            _executePlacement(plan.placement);
            ERC20Repo._mint(recipient, sharesOut);
            _verifyState(plan.placement.afterState);
        } else {
            uint256[2] memory backing = Inventory._totals(state.book);
            sharesOut = _sharesOutForDeposit(token0 ? amountIn : 0, token0 ? 0 : amountIn,
                state.book.supply, backing[0], backing[1]);
            if (sharesOut == 0) revert IStandardExchangeErrors.InvalidRoute(tokenIn, address(this));
            if (sharesOut < minSharesOut) revert UniswapV4ExchangeIn_SlippageExceeded();
            ERC20Repo._mint(recipient, sharesOut);
            emit IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.LocalDepositWhileBlocked(tokenIn, amountIn, sharesOut);
        }
        _syncVaultReserves();
    }

    
    function _previewZapInDualDeposit(uint256 amount0Added, uint256 amount1Added)
        internal
        view
        returns (uint256 sharesOut)
    {
        if (amount0Added == 0 || amount1Added == 0) {
            return 0;
        }
        uint256 totalShares = IERC20(address(this)).totalSupply();
        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
        sharesOut = _sharesOutForDeposit(amount0Added, amount1Added, totalShares, reserve0, reserve1);
        if (sharesOut == 0) revert IStandardExchangeErrors.InvalidRoute(_token0(), address(this));
    }

    
    function _executeZapInDualDeposit(
        uint256 amount0Added,
        uint256 amount1Added,
        uint256 minSharesOut,
        address recipient
    ) internal returns (uint256 sharesOut) {
        if (amount0Added == 0 || amount1Added == 0) {
            revert UniswapV4Exchange_ZeroAmount();
        }

        _commitExecutionPlan(keccak256(abi.encode(Types.Workflow.DualJoin, amount0Added, amount1Added,
            _snapshot(amount0Added, amount1Added))), 0, 0);
        _collectManagedFeesIfIdle();

        uint256 totalSharesBefore = IERC20(address(this)).totalSupply();
        (uint256 total0, uint256 total1) = _totalVaultReserves();
        uint256 reserve0Before = total0 - amount0Added;
        uint256 reserve1Before = total1 - amount1Added;

        sharesOut = _sharesOutForDeposit(amount0Added, amount1Added, totalSharesBefore, reserve0Before, reserve1Before);
        if (sharesOut == 0) revert IStandardExchangeErrors.InvalidRoute(_token0(), address(this));
        if (sharesOut < minSharesOut) revert UniswapV4ExchangeIn_SlippageExceeded();

        if (totalSharesBefore == 0) {
            ERC20Repo._mint(DEAD_SHARES_SINK, _minimumLiquidity());
            uint256 residual = _initialResidualShares(amount0Added, amount1Added, reserve0Before, reserve1Before, sharesOut);
            if (residual > 0) {
                ERC20Repo._mint(DEAD_SHARES_SINK, residual);
            }
        }

        if (canOpenPoolManagerUnlock()) {
            Types.Snapshot memory state = _snapshot(0, 0);
            Types.Placement memory placement = Planner._safePlacement(state);
            _executePlacement(placement);
        }
        ERC20Repo._mint(recipient, sharesOut);
        _syncVaultReserves();

        if (canOpenPoolManagerUnlock()) {
            _rebalanceLiquidReserveBestEffort();
        } else {
            emit IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.LocalDepositWhileBlocked(_token0(), amount0Added, sharesOut);
            emit IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.LocalDepositWhileBlocked(_token1(), amount1Added, sharesOut);
        }
    }


}
