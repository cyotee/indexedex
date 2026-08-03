// SPDX-License-Identifier: BUSL-1.1
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
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {UniswapV4BufferAndPricingHookCommon} from
    "contracts/hooks/uniswap/v4/standardExchange/UniswapV4BufferAndPricingHookCommon.sol";

/**
 * @title UniswapV4BufferAndPricingHookTarget
 * @notice IHooks logic — full pattern-copy of BaseTokenWrapperHook settle order (D51/D67).
 * @dev No Solidity inheritance of BaseTokenWrapperHook / BaseHook / DeltaResolver.
 */
abstract contract UniswapV4BufferAndPricingHookTarget is UniswapV4BufferAndPricingHookCommon, IHooks {
    using SafeERC20 for IERC20;

    error LiquidityNotAllowed();
    error InvalidPoolToken();
    error InvalidPoolFee();
    error HookNotImplemented();

    constructor(IPoolManager poolManager_, address standardExchange_, address underlying_)
        UniswapV4BufferAndPricingHookCommon(poolManager_, standardExchange_, underlying_)
    {}

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
        _onlyPoolManager();
        Currency underlyingC = Currency.wrap(_underlying);
        Currency wrapperC = Currency.wrap(_standardExchange);
        bool wrapZFO = _wrapZeroForOne();
        bool isValidPair = wrapZFO
            ? (poolKey.currency0 == underlyingC && poolKey.currency1 == wrapperC)
            : (poolKey.currency0 == wrapperC && poolKey.currency1 == underlyingC);
        if (!isValidPair) revert InvalidPoolToken();
        if (poolKey.fee != 0) revert InvalidPoolFee();
        return IHooks.beforeInitialize.selector;
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

        Currency underlyingC = Currency.wrap(_underlying);
        Currency wrapperC = Currency.wrap(_standardExchange);

        // Match BaseTokenWrapperHook delta convention exactly (pattern-copy).
        // deltaSpecified = -amountSpecified; unspecified is -output (exact-in) or +input (exact-out).
        if (isWrap) {
            if (isExactInput) {
                uint256 amountIn = uint256(-params.amountSpecified);
                uint256 seOut = _wrapExactIn(amountIn, underlyingC, wrapperC);
                swapDelta = toBeforeSwapDelta(
                    int128(-params.amountSpecified), int128(-int256(seOut))
                );
            } else {
                uint256 seOut = uint256(params.amountSpecified);
                uint256 amountIn = _wrapExactOut(seOut, underlyingC, wrapperC);
                swapDelta = toBeforeSwapDelta(
                    int128(-params.amountSpecified), int128(int256(amountIn))
                );
            }
        } else {
            if (isExactInput) {
                uint256 seIn = uint256(-params.amountSpecified);
                uint256 uOut = _unwrapExactIn(seIn, underlyingC, wrapperC);
                swapDelta = toBeforeSwapDelta(
                    int128(-params.amountSpecified), int128(-int256(uOut))
                );
            } else {
                uint256 uOut = uint256(params.amountSpecified);
                uint256 seIn = _unwrapExactOut(uOut, underlyingC, wrapperC);
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

    function _wrapExactIn(uint256 underlyingIn, Currency underlyingC, Currency wrapperC)
        internal
        returns (uint256 seOut)
    {
        seOut = _previewWrap(underlyingIn);
        _take(underlyingC, address(this), underlyingIn);
        // SE pulls via transferFrom (Rocket balance-delta); do not pretransfer+true free-mint path.
        IERC20(_underlying).forceApprove(_standardExchange, underlyingIn);
        uint256 got = _seExchangeIn(
            IERC20(_underlying), underlyingIn, IERC20(_standardExchange), seOut, false
        );
        require(got == seOut || got >= seOut, "wrap seOut");
        seOut = got;
        _settle(wrapperC, seOut);
    }

    function _wrapExactOut(uint256 seOut, Currency underlyingC, Currency wrapperC)
        internal
        returns (uint256 amountIn)
    {
        // D43: take exactly previewed amountIn
        amountIn = _previewWrapExactOut(seOut);
        _take(underlyingC, address(this), amountIn);
        IERC20(_underlying).forceApprove(_standardExchange, amountIn);
        uint256 spent = _seExchangeOut(
            IERC20(_underlying), amountIn, IERC20(_standardExchange), seOut, false
        );
        require(spent == amountIn, "wrap exact-out spend");
        _settle(wrapperC, seOut);
    }

    function _unwrapExactIn(uint256 seIn, Currency underlyingC, Currency wrapperC)
        internal
        returns (uint256 uOut)
    {
        uOut = _previewUnwrap(seIn);
        _take(wrapperC, address(this), seIn);
        // SE burn from msg.sender = hook; hook holds SE
        uint256 got = _seExchangeIn(
            IERC20(_standardExchange), seIn, IERC20(_underlying), uOut, false
        );
        require(got >= uOut, "unwrap uOut");
        uOut = got;
        _settle(underlyingC, uOut);
    }

    function _unwrapExactOut(uint256 uOut, Currency underlyingC, Currency wrapperC)
        internal
        returns (uint256 seIn)
    {
        seIn = _previewUnwrapExactOut(uOut);
        _take(wrapperC, address(this), seIn);
        uint256 spent = _seExchangeOut(
            IERC20(_standardExchange), seIn, IERC20(_underlying), uOut, false
        );
        require(spent == seIn, "unwrap exact-out spend");
        // Settle **actual** underlying received (may exceed uOut on ceil/floor redeem);
        // do not leave free inventory on the hook (D38/D50).
        uint256 got = IERC20(_underlying).balanceOf(address(this));
        require(got >= uOut, "unwrap exact-out short");
        _settle(underlyingC, got);
    }
}

