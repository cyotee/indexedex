// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    IBalancerV3StandardExchangeRouterExactInSwap
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactInSwap.sol";
import {
    IBalancerV3StandardExchangeRouterExactInSwapQuery
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactInSwapQuery.sol";
import {
    IBalancerV3StandardExchangeBatchRouterExactIn
} from "contracts/protocols/dexes/balancer/v3/routers/batch/IBalancerV3StandardExchangeBatchRouterExactIn.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";

/// @title IndexedExSERouterAdapter
/// @dev Stack-safe assembly field reads for single-route encodings.
library IndexedExSERouterAdapter {
    function execute(address router, uint256 amountIn, uint256 deadline, bytes memory data) public {
        uint8 mode = _mode(data);
        if (mode == uint8(IBalancerV3UniswapV4CoordinatorRouter.StepCallMode.SingleExactIn)) {
            _executeSingle(router, amountIn, deadline, data);
            return;
        }
        if (mode == uint8(IBalancerV3UniswapV4CoordinatorRouter.StepCallMode.BatchExactIn)) {
            _executeBatch(router, amountIn, deadline, data);
            return;
        }
        revert IBalancerV3UniswapV4CoordinatorRouter.InvalidStepData();
    }

    function query(address router, uint256 amountIn, bytes memory data) public returns (uint256 amountOut) {
        uint8 mode = _mode(data);
        if (mode == uint8(IBalancerV3UniswapV4CoordinatorRouter.StepCallMode.SingleExactIn)) {
            return _querySingle(router, amountIn, data);
        }
        if (mode == uint8(IBalancerV3UniswapV4CoordinatorRouter.StepCallMode.BatchExactIn)) {
            return _queryBatch(router, amountIn, data);
        }
        revert IBalancerV3UniswapV4CoordinatorRouter.InvalidStepData();
    }

    function _mode(bytes memory data) private pure returns (uint8 mode) {
        assembly {
            mode := mload(add(data, 0x20))
        }
    }

    function _word(bytes memory data, uint256 index) private pure returns (uint256 v) {
        assembly {
            v := mload(add(add(data, 0x20), mul(index, 0x20)))
        }
    }

    function _tailBytes(bytes memory data, uint256 index) private pure returns (bytes memory out) {
        uint256 rel = _word(data, index);
        assembly {
            let ptr := add(add(data, 0x20), rel)
            let len := mload(ptr)
            out := mload(0x40)
            mstore(out, len)
            let dst := add(out, 0x20)
            let src := add(ptr, 0x20)
            // word-wise copy (overcopy OK into free memory)
            let end := add(src, len)
            for {} lt(src, end) {
                src := add(src, 0x20)
                dst := add(dst, 0x20)
            } {
                mstore(dst, mload(src))
            }
            mstore(0x40, and(add(add(out, add(0x20, len)), 0x1f), not(0x1f)))
        }
    }

    function _executeSingle(address router, uint256 amountIn, uint256 deadline, bytes memory data) private {
        // Build args in memory struct to avoid 11-local stack pressure at call site.
        _swapSingle(
            router,
            amountIn,
            deadline,
            [
                address(uint160(_word(data, 1))),
                address(uint160(_word(data, 2))),
                address(uint160(_word(data, 3))),
                address(uint160(_word(data, 4))),
                address(uint160(_word(data, 5)))
            ],
            _word(data, 6),
            _word(data, 7) != 0,
            _tailBytes(data, 8)
        );
    }

    function _swapSingle(
        address router,
        uint256 amountIn,
        uint256 deadline,
        address[5] memory addrs,
        uint256 minAmountOut,
        bool wethIsEth,
        bytes memory userData
    ) private {
        // addrs: pool, tokenIn, tokenInVault, tokenOut, tokenOutVault
        IBalancerV3StandardExchangeRouterExactInSwap(router)
            .swapSingleTokenExactIn(
                addrs[0],
                IERC20(addrs[1]),
                IStandardExchangeProxy(addrs[2]),
                IERC20(addrs[3]),
                IStandardExchangeProxy(addrs[4]),
                amountIn,
                minAmountOut,
                deadline,
                wethIsEth,
                userData
            );
    }

    function _querySingle(address router, uint256 amountIn, bytes memory data) private returns (uint256) {
        return IBalancerV3StandardExchangeRouterExactInSwapQuery(router)
            .querySwapSingleTokenExactIn(
                address(uint160(_word(data, 1))),
                IERC20(address(uint160(_word(data, 2)))),
                IStandardExchangeProxy(address(uint160(_word(data, 3)))),
                IERC20(address(uint160(_word(data, 4)))),
                IStandardExchangeProxy(address(uint160(_word(data, 5)))),
                amountIn,
                address(this),
                _tailBytes(data, 8)
            );
    }

    function _executeBatch(address router, uint256 amountIn, uint256 deadline, bytes memory data) private {
        (
            ,
            IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] memory paths,
            bool wethIsEth,
            bytes memory userData
        ) = abi.decode(
            data, (uint8, IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[], bool, bytes)
        );
        if (paths.length != 1) revert IBalancerV3UniswapV4CoordinatorRouter.InvalidStepData();
        paths[0].exactAmountIn = amountIn;
        IBalancerV3StandardExchangeBatchRouterExactIn(router).swapExactIn(paths, deadline, wethIsEth, userData);
    }

    function _queryBatch(address router, uint256 amountIn, bytes memory data) private returns (uint256 amountOut) {
        (
            ,
            IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] memory paths,,
            bytes memory userData
        ) = abi.decode(
            data, (uint8, IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[], bool, bytes)
        );
        if (paths.length != 1) revert IBalancerV3UniswapV4CoordinatorRouter.InvalidStepData();
        paths[0].exactAmountIn = amountIn;
        (uint256[] memory pathAmountsOut,,) =
            IBalancerV3StandardExchangeBatchRouterExactIn(router).querySwapExactIn(paths, address(this), userData);
        amountOut = pathAmountsOut[0];
    }
}
