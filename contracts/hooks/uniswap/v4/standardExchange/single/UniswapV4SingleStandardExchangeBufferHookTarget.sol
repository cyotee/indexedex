// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    toBeforeSwapDelta,
    BeforeSwapDelta
} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BeforeSwapDelta.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {
    UniswapV4SingleStandardExchangeBufferHookCommon
} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookCommon.sol";
import {
    UniswapV4SingleStandardExchangeBufferHookBeforeInitializeLib as BeforeInitializeLib
} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookBeforeInitializeLib.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferHookTarget
 * @notice IHooks logic — pattern-copy of BaseTokenWrapperHook settle order (no inheritance).
 */
abstract contract UniswapV4SingleStandardExchangeBufferHookTarget is
    UniswapV4SingleStandardExchangeBufferHookCommon,
    IHooks
{
    using SafeERC20 for IERC20;

    function getHookPermissions() public pure returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            beforeAddLiquidity: true,
            beforeSwap: true,
            beforeSwapReturnDelta: true,
            afterSwap: false,
            afterInitialize: false,
            beforeRemoveLiquidity: false,
            afterAddLiquidity: false,
            afterRemoveLiquidity: false,
            beforeDonate: false,
            afterDonate: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /* ---------------------------------------------------------------------- */
    /*                                  IHooks                                */
    /* ---------------------------------------------------------------------- */

    function beforeInitialize(address, PoolKey calldata poolKey, uint160)
        external
        view
        override
        returns (bytes4)
    {
        return BeforeInitializeLib.beforeInitialize(poolKey);
    }

    function afterInitialize(address, PoolKey calldata, uint160, int24)
        external
        pure
        override
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    function beforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        view
        override
        returns (bytes4)
    {
        _onlyPoolManager();
        revert LiquidityNotAllowed();
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure override returns (bytes4, BalanceDelta) {
        revert HookNotImplemented();
    }

    function beforeRemoveLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure override returns (bytes4, BalanceDelta) {
        revert HookNotImplemented();
    }

    function beforeSwap(address, PoolKey calldata, SwapParams calldata params, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta swapDelta, uint24)
    {
        _onlyPoolManager();
        bool isExactInput = params.amountSpecified < 0;
        bool isWrap = (_wrapZeroForOne() == params.zeroForOne);

        Currency pairC = Currency.wrap(_pair());
        Currency seC = Currency.wrap(_se());

        // Match BaseTokenWrapperHook delta convention (pattern-copy).
        if (isWrap) {
            if (isExactInput) {
                uint256 amountIn = uint256(-params.amountSpecified);
                uint256 seOut = _wrapExactIn(amountIn, pairC, seC);
                swapDelta = toBeforeSwapDelta(
                    int128(-params.amountSpecified), int128(-int256(seOut))
                );
            } else {
                uint256 seOut = uint256(params.amountSpecified);
                uint256 amountIn = _wrapExactOut(seOut, pairC, seC);
                swapDelta = toBeforeSwapDelta(
                    int128(-params.amountSpecified), int128(int256(amountIn))
                );
            }
        } else {
            if (isExactInput) {
                uint256 seIn = uint256(-params.amountSpecified);
                uint256 pairOut = _unwrapExactIn(seIn, pairC, seC);
                swapDelta = toBeforeSwapDelta(
                    int128(-params.amountSpecified), int128(-int256(pairOut))
                );
            } else {
                uint256 pairOut = uint256(params.amountSpecified);
                uint256 seIn = _unwrapExactOut(pairOut, pairC, seC);
                swapDelta = toBeforeSwapDelta(
                    int128(-params.amountSpecified), int128(int256(seIn))
                );
            }
        }

        return (IHooks.beforeSwap.selector, swapDelta, 0);
    }

    function afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata)
        external
        pure
        override
        returns (bytes4, int128)
    {
        revert HookNotImplemented();
    }

    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    /* ---------------------------------------------------------------------- */
    /*                         Wrap / unwrap execution                        */
    /* ---------------------------------------------------------------------- */

    function _wrapExactIn(uint256 pairIn, Currency pairC, Currency seC)
        internal
        returns (uint256 seOut)
    {
        seOut = _previewWrap(pairIn);
        _take(pairC, address(this), pairIn);
        // SE pulls via transferFrom; do not pretransfer+true free-mint path.
        IERC20(_pair()).forceApprove(_se(), pairIn);
        uint256 got = _seExchangeIn(IERC20(_pair()), pairIn, IERC20(_se()), seOut, false);
        require(got == seOut || got >= seOut, "wrap seOut");
        seOut = got;
        _settle(seC, seOut);
    }

    function _wrapExactOut(uint256 seOut, Currency pairC, Currency seC)
        internal
        returns (uint256 amountIn)
    {
        amountIn = _previewWrapExactOut(seOut);
        _take(pairC, address(this), amountIn);
        IERC20(_pair()).forceApprove(_se(), amountIn);
        uint256 spent = _seExchangeOut(IERC20(_pair()), amountIn, IERC20(_se()), seOut, false);
        require(spent == amountIn, "wrap exact-out spend");
        _settle(seC, seOut);
    }

    function _unwrapExactIn(uint256 seIn, Currency pairC, Currency seC)
        internal
        returns (uint256 pairOut)
    {
        pairOut = _previewUnwrap(seIn);
        _take(seC, address(this), seIn);
        uint256 got = _seExchangeIn(IERC20(_se()), seIn, IERC20(_pair()), pairOut, false);
        require(got >= pairOut, "unwrap pairOut");
        pairOut = got;
        _settle(pairC, pairOut);
    }

    function _unwrapExactOut(uint256 pairOut, Currency pairC, Currency seC)
        internal
        returns (uint256 seIn)
    {
        seIn = _previewUnwrapExactOut(pairOut);
        _take(seC, address(this), seIn);
        // Delta-only settle: never settle full balanceOf (O11 idle donations must not enter swap accounting).
        uint256 pairBefore = IERC20(_pair()).balanceOf(address(this));
        uint256 spent = _seExchangeOut(IERC20(_se()), seIn, IERC20(_pair()), pairOut, false);
        require(spent == seIn, "unwrap exact-out spend");
        // Settle actual pair received from this exchange (may exceed pairOut on ceil/floor redeem).
        uint256 got = IERC20(_pair()).balanceOf(address(this)) - pairBefore;
        require(got >= pairOut, "unwrap exact-out short");
        _settle(pairC, got);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Public preview surface                         */
    /* ---------------------------------------------------------------------- */

    function previewWrap(uint256 pairIn) external view returns (uint256 seOut) {
        return _previewWrap(pairIn);
    }

    function previewWrapExactOut(uint256 seOut) external view returns (uint256 pairIn) {
        return _previewWrapExactOut(seOut);
    }

    function previewUnwrap(uint256 seIn) external view returns (uint256 pairOut) {
        return _previewUnwrap(seIn);
    }

    function previewUnwrapExactOut(uint256 pairOut) external view returns (uint256 seIn) {
        return _previewUnwrapExactOut(pairOut);
    }
}
