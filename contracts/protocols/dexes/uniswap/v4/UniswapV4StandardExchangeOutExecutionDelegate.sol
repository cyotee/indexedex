// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Actions} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Actions.sol";
import {UniswapV4PositionRepo} from "contracts/protocols/dexes/uniswap/v4/UniswapV4PositionRepo.sol";
import {
    UniswapV4StandardExchangeOutBase
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutBase.sol";

/// @notice CREATE3 delegate for heavy Out zap-out only (no rebalance / direct swap).
contract UniswapV4StandardExchangeOutExecutionDelegate is UniswapV4StandardExchangeOutBase {
    function executeZapOutWithdrawal(
        address tokenOut,
        uint256 maxSharesToBurn,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred
    ) external returns (uint256 sharesBurned) {
        ZapOutState memory state;
        state.totalShares = IERC20(address(this)).totalSupply();

        uint256 delivered;
        if (pretransferred) {
            delivered = _secureShareDelivery(maxSharesToBurn, true);
        }

        if (!canOpenPoolManagerUnlock()) {
            sharesBurned = _previewZapOutWithdrawal(tokenOut, minAmountOut);
            if (sharesBurned == 0 || sharesBurned > maxSharesToBurn) {
                revert UniswapV4ExchangeOut_InsufficientInput();
            }
            if (pretransferred && sharesBurned > delivered) {
                revert UniswapV4ExchangeOut_InsufficientInput();
            }
            uint256 freeOut = IERC20(tokenOut).balanceOf(address(this));
            if (freeOut < minAmountOut) {
                revert UniswapV4Exchange_InsufficientLocalReserve(tokenOut, minAmountOut, freeOut);
            }
            state.actualOut = minAmountOut;
            if (pretransferred) {
                ERC20Repo._burn(address(this), sharesBurned);
                _refundUnusedShares(delivered, sharesBurned, msg.sender);
            } else {
                ERC20Repo._burn(msg.sender, sharesBurned);
            }
            _syncVaultReserves();
            _transferCurrency(tokenOut, recipient, state.actualOut);
            return sharesBurned;
        }

        sharesBurned = _previewZapOutWithdrawal(tokenOut, minAmountOut);
        if (sharesBurned == 0 || sharesBurned > maxSharesToBurn) {
            revert UniswapV4ExchangeOut_InsufficientInput();
        }
        if (pretransferred && sharesBurned > delivered) {
            revert UniswapV4ExchangeOut_InsufficientInput();
        }

        state.actualOut = _executeFreeZapOutWithdrawalCore(tokenOut, sharesBurned, state.totalShares);
        if (state.actualOut < minAmountOut) revert UniswapV4ExchangeOut_SlippageExceeded();

        if (pretransferred) {
            ERC20Repo._burn(address(this), sharesBurned);
            _refundUnusedShares(delivered, sharesBurned, msg.sender);
        } else {
            ERC20Repo._burn(msg.sender, sharesBurned);
        }
        _syncVaultReserves();
        _transferCurrency(tokenOut, recipient, state.actualOut);
    }

    function _executeFreeZapOutWithdrawalCore(address tokenOut, uint256 sharesBurned, uint256 totalShares)
        internal
        returns (uint256 actualOut)
    {
        bool outIsToken0 = tokenOut == _token0();
        address otherToken = outIsToken0 ? _token1() : _token0();
        (uint256 free0, uint256 free1) = _freeBalances();
        uint256 freePortionOther =
            outIsToken0 ? (free1 * sharesBurned) / totalShares : (free0 * sharesBurned) / totalShares;
        uint256 freeOutShare = outIsToken0 ? (free0 * sharesBurned) / totalShares : (free1 * sharesBurned) / totalShares;

        uint256 otherBefore = IERC20(otherToken).balanceOf(address(this));
        uint256 outBefore = IERC20(tokenOut).balanceOf(address(this));

        _burnPositionLiquidity(UniswapV4PositionRepo.PositionKind.Center, sharesBurned, totalShares);
        _burnPositionLiquidity(UniswapV4PositionRepo.PositionKind.LowerWing, sharesBurned, totalShares);
        _burnPositionLiquidity(UniswapV4PositionRepo.PositionKind.UpperWing, sharesBurned, totalShares);

        {
            uint256 removedOther = IERC20(otherToken).balanceOf(address(this)) - otherBefore;
            uint256 otherForUser = removedOther + freePortionOther;
            uint256 otherBal = IERC20(otherToken).balanceOf(address(this));
            if (otherForUser > otherBal) otherForUser = otherBal;
            if (otherForUser > 0) {
                _executeUnlock(
                    OperationParams({
                        op: Operation.SwapExactIn,
                        zeroForOne: !outIsToken0,
                        amountSpecified: otherForUser,
                        tickLower: 0,
                        tickUpper: 0,
                        liquidity: 0,
                        salt: bytes32(0)
                    })
                );
            }
        }

        _refreshStoredLiquidity();
        actualOut = (IERC20(tokenOut).balanceOf(address(this)) - outBefore) + freeOutShare;
        uint256 bal = IERC20(tokenOut).balanceOf(address(this));
        if (actualOut > bal) actualOut = bal;
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
                UniswapV4PositionRepo._importedPositionTokenId(),
                uint256(liquidityToBurn),
                uint128(0),
                uint128(0),
                bytes("")
            );
            params[1] = abi.encode(_currency0(), _currency1(), address(this));
            UniswapV4PositionRepo._importedPositionManager()
                .modifyLiquidities(abi.encode(actions, params), block.timestamp);
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
}
