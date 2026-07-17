// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {Actions} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Actions.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {UniswapV4PositionRepo} from "contracts/protocols/dexes/uniswap/v4/UniswapV4PositionRepo.sol";
import {UniswapV4StandardExchangeCommon} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol";

contract UniswapV4StandardExchangeOutTarget is UniswapV4StandardExchangeCommon, ReentrancyLockModifiers, IStandardExchangeOut {
    struct ZapOutState {
        uint256 totalShares;
        address token0;
        address token1;
        uint256 balance0Before;
        uint256 balance1Before;
        uint256 amount0;
        uint256 amount1;
        uint256 actualOut;
    }

    error UniswapV4ExchangeOut_DeadlineExceeded();
    error UniswapV4ExchangeOut_SlippageExceeded();
    error UniswapV4ExchangeOut_InsufficientInput();

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        override
        returns (uint256 amountIn)
    {
        address token0 = _token0();
        address token1 = _token1();

        if ((address(tokenIn) == token0 && address(tokenOut) == token1)
            || (address(tokenIn) == token1 && address(tokenOut) == token0)) {
            return _quoteSwapOut(amountOut, address(tokenIn) == token0);
        }

        if (address(tokenIn) == address(this) && (address(tokenOut) == token0 || address(tokenOut) == token1)) {
            return _previewZapOutWithdrawal(address(tokenOut), amountOut);
        }

        revert ExchangeOutNotAvailable();
    }

    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    )
        external
        override
        nonReentrant
        returns (uint256 amountIn)
    {
        _requireNotDisabled();
        if (deadline < block.timestamp) revert UniswapV4ExchangeOut_DeadlineExceeded();

        address token0 = _token0();
        address token1 = _token1();

        if ((address(tokenIn) == token0 && address(tokenOut) == token1)
            || (address(tokenIn) == token1 && address(tokenOut) == token0)) {
            uint256 estimatedAmountIn = _quoteSwapOut(amountOut, address(tokenIn) == token0);
            if (estimatedAmountIn > maxAmountIn) revert UniswapV4ExchangeOut_InsufficientInput();

            uint256 providedAmountIn = _secureTokenTransfer(tokenIn, maxAmountIn, pretransferred);
            uint256 actualOut;
            (amountIn, actualOut) = _executeDirectSwapOut(address(tokenIn), amountOut, recipient);
            if (amountIn > providedAmountIn) revert UniswapV4ExchangeOut_InsufficientInput();
            if (actualOut < amountOut) revert UniswapV4ExchangeOut_SlippageExceeded();

            _refundExcess(tokenIn, providedAmountIn, amountIn, msg.sender);
            return amountIn;
        }

        if (address(tokenIn) == address(this) && (address(tokenOut) == token0 || address(tokenOut) == token1)) {
            amountIn = _executeZapOutWithdrawal(address(tokenOut), maxAmountIn, amountOut, recipient, pretransferred);
            return amountIn;
        }

        revert ExchangeOutNotAvailable();
    }

    function _executeDirectSwapOut(address tokenIn, uint256 amountOut, address recipient)
        internal
        returns (uint256 actualIn, uint256 actualOut)
    {
        bool zeroForOne = tokenIn == _token0();
        address outputToken = zeroForOne ? _token1() : _token0();
        uint256 inputBalanceBefore = IERC20(tokenIn).balanceOf(address(this));
        uint256 balanceBefore = IERC20(outputToken).balanceOf(address(this));

        _executeUnlock(
            OperationParams({
                op: Operation.SwapExactOut,
                zeroForOne: zeroForOne,
                amountSpecified: amountOut,
                tickLower: 0,
                tickUpper: 0,
                liquidity: 0,
                salt: bytes32(0)
            })
        );

        actualIn = inputBalanceBefore - IERC20(tokenIn).balanceOf(address(this));
        actualOut = IERC20(outputToken).balanceOf(address(this)) - balanceBefore;
        _transferCurrency(outputToken, recipient, actualOut);
    }

    function _previewZapOutWithdrawal(address tokenOut, uint256 desiredAmountOut) internal view returns (uint256 sharesRequired) {
        if (desiredAmountOut == 0) {
            return 0;
        }

        uint256 totalShares = IERC20(address(this)).totalSupply();
        if (totalShares == 0 || !UniswapV4PositionRepo._isPositionCreated()) {
            return 0;
        }

        uint256 low = 1;
        uint256 high = totalShares;

        while (low < high) {
            uint256 mid = low + (high - low) / 2;
            uint256 amountOut = _quoteZapOutAmount(tokenOut, mid, totalShares);

            if (amountOut >= desiredAmountOut) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        if (high < totalShares) {
            uint256 buffer = high / 100;
            if (buffer == 0) {
                buffer = 1;
            }
            uint256 buffered = high + buffer;
            return buffered > totalShares ? totalShares : buffered;
        }
        return high;
    }

    function _quoteZapOutAmount(address tokenOut, uint256 sharesBurned, uint256 totalShares)
        internal
        view
        returns (uint256 amountOut)
    {
        (uint256 amount0, uint256 amount1) = _quoteManagedWithdrawal(sharesBurned, totalShares);
        if (tokenOut == _token0()) {
            return amount0 + _quoteSwapIn(amount1, false);
        }
        return amount1 + _quoteSwapIn(amount0, true);
    }

    function _executeZapOutWithdrawal(
        address tokenOut,
        uint256 maxSharesToBurn,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred
    )
        internal
        returns (uint256 sharesBurned)
    {
        ZapOutState memory state;
        state.totalShares = IERC20(address(this)).totalSupply();
        sharesBurned = _previewZapOutWithdrawal(tokenOut, minAmountOut);

        if (sharesBurned == 0 || sharesBurned > maxSharesToBurn) {
            revert UniswapV4ExchangeOut_InsufficientInput();
        }

        state.token0 = _token0();
        state.token1 = _token1();
        state.balance0Before = IERC20(state.token0).balanceOf(address(this));
        state.balance1Before = IERC20(state.token1).balanceOf(address(this));

        _burnPositionLiquidity(UniswapV4PositionRepo.PositionKind.Center, sharesBurned, state.totalShares);
        _burnPositionLiquidity(UniswapV4PositionRepo.PositionKind.LowerWing, sharesBurned, state.totalShares);
        _burnPositionLiquidity(UniswapV4PositionRepo.PositionKind.UpperWing, sharesBurned, state.totalShares);

        state.amount0 = IERC20(state.token0).balanceOf(address(this)) - state.balance0Before;
        state.amount1 = IERC20(state.token1).balanceOf(address(this)) - state.balance1Before;

        if (tokenOut == state.token0 && state.amount1 > 0) {
            _executeUnlock(
                OperationParams({
                    op: Operation.SwapExactIn,
                    zeroForOne: false,
                    amountSpecified: state.amount1,
                    tickLower: 0,
                    tickUpper: 0,
                    liquidity: 0,
                    salt: bytes32(0)
                })
            );
        } else if (tokenOut == state.token1 && state.amount0 > 0) {
            _executeUnlock(
                OperationParams({
                    op: Operation.SwapExactIn,
                    zeroForOne: true,
                    amountSpecified: state.amount0,
                    tickLower: 0,
                    tickUpper: 0,
                    liquidity: 0,
                    salt: bytes32(0)
                })
            );
        }

        _refreshStoredLiquidity();
        _syncVaultReserves();

        state.actualOut = IERC20(tokenOut).balanceOf(address(this));
        if (state.actualOut < minAmountOut) revert UniswapV4ExchangeOut_SlippageExceeded();

        if (pretransferred) {
            ERC20Repo._burn(address(this), sharesBurned);
            if (maxSharesToBurn > sharesBurned) {
                ERC20Repo._transfer(address(this), msg.sender, maxSharesToBurn - sharesBurned);
            }
        } else {
            ERC20Repo._burn(msg.sender, sharesBurned);
        }
        _transferCurrency(tokenOut, recipient, state.actualOut);
    }

    function _burnPositionLiquidity(UniswapV4PositionRepo.PositionKind kind, uint256 sharesBurned, uint256 totalShares)
        internal
    {
        uint128 currentLiquidity = _currentLiquidity(kind);
        if (currentLiquidity == 0) {
            return;
        }

        uint128 liquidityToBurn = uint128((sharesBurned * currentLiquidity) / totalShares);
        if (liquidityToBurn == 0) {
            return;
        }

        if (UniswapV4PositionRepo._isImportedPosition()) {
            if (kind != UniswapV4PositionRepo.PositionKind.Center) {
                return;
            }

            bytes memory actions = abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR));
            bytes[] memory params = new bytes[](2);
            params[0] = abi.encode(
                UniswapV4PositionRepo._importedPositionTokenId(), uint256(liquidityToBurn), uint128(0), uint128(0), bytes("")
            );
            params[1] = abi.encode(_currency0(), _currency1(), address(this));
            UniswapV4PositionRepo._importedPositionManager().modifyLiquidities(abi.encode(actions, params), block.timestamp);
            return;
        }

        (int24 tickLower, int24 tickUpper) = UniswapV4PositionRepo._positionTicks(kind);
        _executeUnlock(
            OperationParams({
                op: Operation.RemoveLiquidity,
                zeroForOne: false,
                amountSpecified: 0,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidity: liquidityToBurn,
                salt: UniswapV4PositionRepo._salt(kind)
            })
        );
    }

    function _refundExcess(IERC20 token, uint256 providedAmount, uint256 usedAmount, address recipient) internal {
        if (providedAmount > usedAmount) {
            _transferCurrency(address(token), recipient, providedAmount - usedAmount);
        }
    }
}