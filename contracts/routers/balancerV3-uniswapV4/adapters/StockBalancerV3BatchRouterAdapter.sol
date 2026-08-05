// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    SwapPathExactAmountIn
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/BatchRouterTypes.sol";
import {IBatchRouter} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IBatchRouter.sol";
import {
    IBatchRouterQueries
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IBatchRouterQueries.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";

/// @title StockBalancerV3BatchRouterAdapter
/// @dev Single-root only (paths.length == 1).
///      Decodes `abi.encode(paths[], bool, bytes)` without nested multi-dynamic `abi.decode`
///      (stack-too-deep / `headStart` under via_ir=false).
library StockBalancerV3BatchRouterAdapter {
    struct BatchLocals {
        address router;
        uint256 amountIn;
        uint256 deadline;
        SwapPathExactAmountIn[] paths;
        bool wethIsEth;
        bytes userData;
    }

    function execute(address router, uint256 amountIn, uint256 deadline, bytes memory data) public {
        BatchLocals memory b = _decode(router, amountIn, deadline, data);
        if (b.paths.length != 1) {
            revert IBalancerV3UniswapV4CoordinatorRouter.InvalidStepData();
        }
        b.paths[0].exactAmountIn = b.amountIn;
        _callSwap(b);
    }

    function query(address router, uint256 amountIn, bytes memory data) public returns (uint256 amountOut) {
        BatchLocals memory b = _decode(router, amountIn, 0, data);
        if (b.paths.length != 1) {
            revert IBalancerV3UniswapV4CoordinatorRouter.InvalidStepData();
        }
        b.paths[0].exactAmountIn = b.amountIn;
        amountOut = _callQuery(b);
    }

    /// @dev Wire: `abi.encode(SwapPathExactAmountIn[] paths, bool wethIsEth, bytes userData)`.
    function _decode(address router, uint256 amountIn, uint256 deadline, bytes memory data)
        private
        pure
        returns (BatchLocals memory b)
    {
        b.router = router;
        b.amountIn = amountIn;
        b.deadline = deadline;

        uint256 pathsRel;
        uint256 userRel;
        bool wethIsEth;
        assembly {
            let p := add(data, 0x20)
            // word0 = paths offset, word1 = wethIsEth, word2 = userData offset
            pathsRel := mload(p)
            wethIsEth := mload(add(p, 0x20))
            userRel := mload(add(p, 0x40))
        }
        b.wethIsEth = wethIsEth;
        b.paths = _decodePathsSlice(data, pathsRel, userRel);
        b.userData = _decodeUserDataSlice(data, userRel);
    }

    /// @dev In-tuple `T[]` body is `length || elems`. Standalone `abi.encode(T[])` is `offset || body`.
    function _decodePathsSlice(bytes memory data, uint256 pathsRel, uint256 userRel)
        private
        pure
        returns (SwapPathExactAmountIn[] memory paths)
    {
        uint256 pathsLen = userRel - pathsRel;
        bytes memory wrapped = new bytes(32 + pathsLen);
        assembly {
            let w := add(wrapped, 0x20)
            mstore(w, 0x20)
            let src := add(add(data, 0x20), pathsRel)
            let dst := add(w, 0x20)
            let end := add(src, pathsLen)
            for {} lt(src, end) {
                src := add(src, 0x20)
                dst := add(dst, 0x20)
            } {
                mstore(dst, mload(src))
            }
        }
        paths = abi.decode(wrapped, (SwapPathExactAmountIn[]));
    }

    function _decodeUserDataSlice(bytes memory data, uint256 userRel) private pure returns (bytes memory userData) {
        assembly {
            let src := add(add(data, 0x20), userRel)
            let len := mload(src)
            userData := mload(0x40)
            mstore(userData, len)
            let d := add(userData, 0x20)
            let s := add(src, 0x20)
            let end := add(s, len)
            for {} lt(s, end) {
                s := add(s, 0x20)
                d := add(d, 0x20)
            } {
                mstore(d, mload(s))
            }
            mstore(0x40, and(add(add(userData, add(0x20, len)), 0x1f), not(0x1f)))
        }
    }

    function _callSwap(BatchLocals memory b) private {
        IBatchRouter(b.router).swapExactIn(b.paths, b.deadline, b.wethIsEth, b.userData);
    }

    function _callQuery(BatchLocals memory b) private returns (uint256 amountOut) {
        (uint256[] memory pathAmountsOut,,) =
            IBatchRouterQueries(b.router).querySwapExactIn(b.paths, address(this), b.userData);
        amountOut = pathAmountsOut[0];
    }
}
