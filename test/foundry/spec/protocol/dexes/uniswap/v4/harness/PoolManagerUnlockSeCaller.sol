// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";

/**
 * @title PoolManagerUnlockSeCaller
 * @notice Outer unlock harness: while PM is unlocked, call SE exchangeIn / exchangeOut (H1/H3).
 */
contract PoolManagerUnlockSeCaller is IUnlockCallback {
    using TransientStateLibrary for IPoolManager;

    IPoolManager public immutable poolManager;

    enum Op {
        ExchangeIn,
        ExchangeOut,
        ExchangeInMany,
        ExchangeOutMany
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
    }

    constructor(IPoolManager poolManager_) {
        poolManager = poolManager_;
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
        bytes memory result = poolManager.unlock(
            abi.encode(
                CallData({
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
                    amounts: new uint256[](0)
                })
            )
        );
        return abi.decode(result, (uint256));
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
        bytes memory result = poolManager.unlock(
            abi.encode(
                CallData({
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
                    amounts: new uint256[](0)
                })
            )
        );
        return abi.decode(result, (uint256));
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
        bytes memory result = poolManager.unlock(
            abi.encode(
                CallData({
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
                    amounts: amountsIn
                })
            )
        );
        return abi.decode(result, (uint256));
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
        bytes memory result = poolManager.unlock(
            abi.encode(
                CallData({
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
                    amounts: amountsOut
                })
            )
        );
        return abi.decode(result, (uint256));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "not pool manager");
        require(TransientStateLibrary.isUnlocked(poolManager), "expected unlocked");

        CallData memory c = abi.decode(data, (CallData));
        if (c.op == Op.ExchangeIn) {
            uint256 amountOut = IStandardExchangeIn(c.se)
                .exchangeIn(
                    IERC20(c.tokenIn),
                    c.amountInOrMax,
                    IERC20(c.tokenOut),
                    c.minOrExactOut,
                    c.recipient,
                    c.pretransferred,
                    c.deadline
                );
            return abi.encode(amountOut);
        }
        if (c.op == Op.ExchangeInMany) {
            uint256 sharesOut = IStandardExchangeInMulti(c.se)
                .exchangeInManyToOne(
                    c.tokens,
                    c.amounts,
                    IERC20(c.tokenOut),
                    c.minOrExactOut,
                    c.recipient,
                    c.pretransferred,
                    c.deadline
                );
            return abi.encode(sharesOut);
        }
        if (c.op == Op.ExchangeOutMany) {
            uint256 sharesIn = IStandardExchangeOutMulti(c.se)
                .exchangeOutOneToMany(
                    IERC20(c.tokenIn),
                    c.amountInOrMax,
                    c.tokens,
                    c.amounts,
                    c.recipient,
                    c.pretransferred,
                    c.deadline
                );
            return abi.encode(sharesIn);
        }

        uint256 amountIn = IStandardExchangeOut(c.se)
            .exchangeOut(
                IERC20(c.tokenIn),
                c.amountInOrMax,
                IERC20(c.tokenOut),
                c.minOrExactOut,
                c.recipient,
                c.pretransferred,
                c.deadline
            );
        return abi.encode(amountIn);
    }
}
