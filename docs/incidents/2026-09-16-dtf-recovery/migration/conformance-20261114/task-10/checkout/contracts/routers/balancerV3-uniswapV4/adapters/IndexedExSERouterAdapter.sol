// SPDX-License-Identifier: BSL-1.1
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
///      Batch path avoids nested multi-dynamic `abi.decode` (stack-too-deep / `headStart`) by
///      slicing the in-tuple `SESwapPathExactAmountIn[]` body and decoding it alone.
library IndexedExSERouterAdapter {
    /// @dev Locals for a single-route exact-in execute/query (one memory pointer on the EVM stack).
    struct SingleRoute {
        address router;
        uint256 amountIn;
        uint256 deadline;
        address pool;
        address tokenIn;
        address tokenInVault;
        address tokenOut;
        address tokenOutVault;
        uint256 minAmountOut;
        bool wethIsEth;
        bytes userData;
    }

    /// @dev Locals for a batch exact-in execute/query.
    struct BatchRoute {
        address router;
        uint256 amountIn;
        uint256 deadline;
        IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] paths;
        bool wethIsEth;
        bytes userData;
    }

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

    /* --------------------------------- Single -------------------------------- */

    function _executeSingle(address router, uint256 amountIn, uint256 deadline, bytes memory data) private {
        SingleRoute memory s;
        s.router = router;
        s.amountIn = amountIn;
        s.deadline = deadline;
        _fillSingleFromData(s, data);
        _callSwapSingle(s);
    }

    function _querySingle(address router, uint256 amountIn, bytes memory data) private returns (uint256) {
        SingleRoute memory s;
        s.router = router;
        s.amountIn = amountIn;
        _fillSingleFromData(s, data);
        return _callQuerySingle(s);
    }

    /// @dev Populate address/limit/userData fields from packed step data (indices 1..8).
    function _fillSingleFromData(SingleRoute memory s, bytes memory data) private pure {
        s.pool = address(uint160(_word(data, 1)));
        s.tokenIn = address(uint160(_word(data, 2)));
        s.tokenInVault = address(uint160(_word(data, 3)));
        s.tokenOut = address(uint160(_word(data, 4)));
        s.tokenOutVault = address(uint160(_word(data, 5)));
        s.minAmountOut = _word(data, 6);
        s.wethIsEth = _word(data, 7) != 0;
        s.userData = _tailBytes(data, 8);
    }

    /// @dev Isolated call site: only the memory pointer stays live while ABI-encoding args.
    function _callSwapSingle(SingleRoute memory s) private {
        IBalancerV3StandardExchangeRouterExactInSwap(s.router)
            .swapSingleTokenExactIn(
                s.pool,
                IERC20(s.tokenIn),
                IStandardExchangeProxy(s.tokenInVault),
                IERC20(s.tokenOut),
                IStandardExchangeProxy(s.tokenOutVault),
                s.amountIn,
                s.minAmountOut,
                s.deadline,
                s.wethIsEth,
                s.userData
            );
    }

    function _callQuerySingle(SingleRoute memory s) private returns (uint256 amountOut) {
        amountOut = IBalancerV3StandardExchangeRouterExactInSwapQuery(s.router)
            .querySwapSingleTokenExactIn(
                s.pool,
                IERC20(s.tokenIn),
                IStandardExchangeProxy(s.tokenInVault),
                IERC20(s.tokenOut),
                IStandardExchangeProxy(s.tokenOutVault),
                s.amountIn,
                address(this),
                s.userData
            );
    }

    /* --------------------------------- Batch --------------------------------- */

    function _executeBatch(address router, uint256 amountIn, uint256 deadline, bytes memory data) private {
        BatchRoute memory b = _decodeBatch(router, amountIn, deadline, data);
        if (b.paths.length != 1) revert IBalancerV3UniswapV4CoordinatorRouter.InvalidStepData();
        b.paths[0].exactAmountIn = b.amountIn;
        _callSwapBatch(b);
    }

    function _queryBatch(address router, uint256 amountIn, bytes memory data) private returns (uint256 amountOut) {
        BatchRoute memory b = _decodeBatch(router, amountIn, 0, data);
        if (b.paths.length != 1) revert IBalancerV3UniswapV4CoordinatorRouter.InvalidStepData();
        b.paths[0].exactAmountIn = b.amountIn;
        amountOut = _callQueryBatch(b);
    }

    /// @dev Decode `abi.encode(uint8 mode, paths[], bool wethIsEth, bytes userData)` without a nested
    /// multi-dynamic `abi.decode` (that codegen hits stack-too-deep / `headStart` under via_ir=false).
    /// Wire format is preserved: slice the in-tuple array body and decode `paths` alone.
    function _decodeBatch(address router, uint256 amountIn, uint256 deadline, bytes memory data)
        private
        pure
        returns (BatchRoute memory b)
    {
        b.router = router;
        b.amountIn = amountIn;
        b.deadline = deadline;

        // word0 = mode (skipped), word1 = paths offset, word2 = wethIsEth, word3 = userData offset
        uint256 pathsRel;
        uint256 userRel;
        bool wethIsEth;
        assembly {
            let p := add(data, 0x20)
            pathsRel := mload(add(p, 0x20))
            wethIsEth := mload(add(p, 0x40))
            userRel := mload(add(p, 0x60))
        }
        b.wethIsEth = wethIsEth;
        b.paths = _decodePathsSlice(data, pathsRel, userRel);
        b.userData = _decodeUserDataSlice(data, userRel);
    }

    /// @dev In-tuple `T[]` body is `length || elems`. Standalone `abi.encode(T[])` is `offset || body`.
    function _decodePathsSlice(bytes memory data, uint256 pathsRel, uint256 userRel)
        private
        pure
        returns (IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] memory paths)
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
        paths = abi.decode(
            wrapped, (IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[])
        );
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

    function _callSwapBatch(BatchRoute memory b) private {
        IBalancerV3StandardExchangeBatchRouterExactIn(b.router)
            .swapExactIn(b.paths, b.deadline, b.wethIsEth, b.userData);
    }

    function _callQueryBatch(BatchRoute memory b) private returns (uint256 amountOut) {
        (uint256[] memory pathAmountsOut,,) = IBalancerV3StandardExchangeBatchRouterExactIn(b.router)
            .querySwapExactIn(b.paths, address(this), b.userData);
        amountOut = pathAmountsOut[0];
    }
}
