// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {
    IUniswapV3SwapCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3SwapCallback.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {
    IUniswapV3StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3StandardExchangeLiquidReserve.sol";
import {
    IUniswapV3StandardExchangePositionImport
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangePositionImportTarget.sol";
import {
    INonfungiblePositionManager
} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/INonfungiblePositionManager.sol";

/**
 * @title UniswapV3BoundPoolLockSeCaller
 * @notice Starts a bound-pool swap so `slot0.unlocked == false`, then calls this vault from the swap callback.
 */
contract UniswapV3BoundPoolLockSeCaller is IUniswapV3SwapCallback {
    IUniswapV3Pool public immutable pool;

    enum Op {
        ExchangeIn,
        ExchangeOut,
        ExchangeInMany,
        ExchangeOutMany,
        Rebalance,
        Import
    }

    struct CallData {
        Op op;
        address se;
        address tokenIn;
        address tokenOut;
        uint256 amountInOrMax;
        uint256 minOrExactOut;
        address recipient;
        bool pretransferred;
        uint256 deadline;
        address[] tokens;
        uint256[] amounts;
        address positionManager;
        uint256 positionTokenId;
        address importOwner;
    }

    CallData internal pending;
    uint256 internal lastResult;

    constructor(IUniswapV3Pool pool_) {
        pool = pool_;
    }

    function runExchangeIn(
        address se,
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        pending = CallData({
            op: Op.ExchangeIn,
            se: se,
            tokenIn: address(tokenIn),
            tokenOut: address(tokenOut),
            amountInOrMax: amountIn,
            minOrExactOut: minAmountOut,
            recipient: recipient,
            pretransferred: pretransferred,
            deadline: deadline,
            tokens: new address[](0),
            amounts: new uint256[](0),
            positionManager: address(0),
            positionTokenId: 0,
            importOwner: address(0)
        });
        _lockWithTinySwap();
        return lastResult;
    }

    function runExchangeOut(
        address se,
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountIn) {
        pending = CallData({
            op: Op.ExchangeOut,
            se: se,
            tokenIn: address(tokenIn),
            tokenOut: address(tokenOut),
            amountInOrMax: maxAmountIn,
            minOrExactOut: amountOut,
            recipient: recipient,
            pretransferred: pretransferred,
            deadline: deadline,
            tokens: new address[](0),
            amounts: new uint256[](0),
            positionManager: address(0),
            positionTokenId: 0,
            importOwner: address(0)
        });
        _lockWithTinySwap();
        return lastResult;
    }

    function runExchangeInManyToOne(
        address se,
        address[] memory tokenIn,
        uint256[] memory amountsIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        pending = CallData({
            op: Op.ExchangeInMany,
            se: se,
            tokenIn: address(0),
            tokenOut: address(tokenOut),
            amountInOrMax: 0,
            minOrExactOut: minAmountOut,
            recipient: recipient,
            pretransferred: pretransferred,
            deadline: deadline,
            tokens: tokenIn,
            amounts: amountsIn,
            positionManager: address(0),
            positionTokenId: 0,
            importOwner: address(0)
        });
        _lockWithTinySwap();
        return lastResult;
    }

    function runExchangeOutOneToMany(
        address se,
        IERC20 tokenIn,
        uint256 maxAmountIn,
        address[] memory tokensOut,
        uint256[] memory amountsOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountIn) {
        pending = CallData({
            op: Op.ExchangeOutMany,
            se: se,
            tokenIn: address(tokenIn),
            tokenOut: address(0),
            amountInOrMax: maxAmountIn,
            minOrExactOut: 0,
            recipient: recipient,
            pretransferred: pretransferred,
            deadline: deadline,
            tokens: tokensOut,
            amounts: amountsOut,
            positionManager: address(0),
            positionTokenId: 0,
            importOwner: address(0)
        });
        _lockWithTinySwap();
        return lastResult;
    }

    function runRebalance(address se) external {
        pending = CallData({
            op: Op.Rebalance,
            se: se,
            tokenIn: address(0),
            tokenOut: address(0),
            amountInOrMax: 0,
            minOrExactOut: 0,
            recipient: address(0),
            pretransferred: false,
            deadline: 0,
            tokens: new address[](0),
            amounts: new uint256[](0),
            positionManager: address(0),
            positionTokenId: 0,
            importOwner: address(0)
        });
        _lockWithTinySwap();
    }

    function runImport(
        address se,
        address positionManager,
        uint256 positionTokenId,
        uint256 minSharesOut,
        address owner,
        address recipient,
        uint256 deadline
    ) external returns (uint256 sharesOut) {
        pending = CallData({
            op: Op.Import,
            se: se,
            tokenIn: address(0),
            tokenOut: address(0),
            amountInOrMax: minSharesOut,
            minOrExactOut: 0,
            recipient: recipient,
            pretransferred: false,
            deadline: deadline,
            tokens: new address[](0),
            amounts: new uint256[](0),
            positionManager: positionManager,
            positionTokenId: positionTokenId,
            importOwner: owner
        });
        _lockWithTinySwap();
        return lastResult;
    }

    function _lockWithTinySwap() internal {
        // 1 wei is enough to set `slot0.unlocked = false` without moving mid-test quotes.
        pool.swap(address(this), true, int256(1), TickMath.MIN_SQRT_RATIO + 1, bytes(""));
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external override {
        require(msg.sender == address(pool), "not pool");
        CallData memory c = pending;
        if (c.op == Op.ExchangeIn) {
            lastResult = IStandardExchangeIn(c.se)
                .exchangeIn(
                    IERC20(c.tokenIn),
                    c.amountInOrMax,
                    IERC20(c.tokenOut),
                    c.minOrExactOut,
                    c.recipient,
                    c.pretransferred,
                    c.deadline
                );
        } else if (c.op == Op.ExchangeOut) {
            lastResult = IStandardExchangeOut(c.se)
                .exchangeOut(
                    IERC20(c.tokenIn),
                    c.amountInOrMax,
                    IERC20(c.tokenOut),
                    c.minOrExactOut,
                    c.recipient,
                    c.pretransferred,
                    c.deadline
                );
        } else if (c.op == Op.ExchangeInMany) {
            lastResult = IStandardExchangeInMulti(c.se)
                .exchangeInManyToOne(
                    c.tokens, c.amounts, IERC20(c.tokenOut), c.minOrExactOut, c.recipient, c.pretransferred, c.deadline
                );
        } else if (c.op == Op.ExchangeOutMany) {
            lastResult = IStandardExchangeOutMulti(c.se)
                .exchangeOutOneToMany(
                    IERC20(c.tokenIn), c.amountInOrMax, c.tokens, c.amounts, c.recipient, c.pretransferred, c.deadline
                );
        } else if (c.op == Op.Rebalance) {
            IUniswapV3StandardExchangeLiquidReserve(c.se).rebalanceLiquidReserve();
        } else if (c.op == Op.Import) {
            lastResult = IUniswapV3StandardExchangePositionImport(c.se)
                .importPosition(
                    INonfungiblePositionManager(c.positionManager),
                    c.positionTokenId,
                    c.amountInOrMax,
                    c.importOwner,
                    c.recipient,
                    c.deadline
                );
        }

        if (amount0Delta > 0) {
            IERC20(pool.token0()).transfer(msg.sender, uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            IERC20(pool.token1()).transfer(msg.sender, uint256(amount1Delta));
        }
    }
}
