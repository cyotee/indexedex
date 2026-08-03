// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {UniswapV4SingleStandardExchangeBufferPricingHookRepo} from
    "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferPricingHookRepo.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferPricingHookCommon
 * @notice SE preview/execute helpers + pattern-copied take/settle utilities (no Crane hook inheritance).
 */
abstract contract UniswapV4SingleStandardExchangeBufferPricingHookCommon {
    using SafeERC20 for IERC20;

    error ZeroAmount();
    error NotPoolManager();

    IPoolManager internal immutable _poolManager;
    address internal immutable _standardExchange;
    address internal immutable _underlying;

    constructor(IPoolManager poolManager_, address standardExchange_, address underlying_) {
        _poolManager = poolManager_;
        _standardExchange = standardExchange_;
        _underlying = underlying_;
    }

    function poolManager() public view virtual returns (IPoolManager) {
        return _poolManager;
    }

    function standardExchange() public view virtual returns (address) {
        return _standardExchange;
    }

    function underlying() public view virtual returns (address) {
        return _underlying;
    }

    function wrapper() public view virtual returns (address) {
        return _standardExchange;
    }

    function _requireNonZero(uint256 amount) internal pure {
        if (amount == 0) revert ZeroAmount();
    }

    function _wrapZeroForOne() internal view returns (bool) {
        return UniswapV4SingleStandardExchangeBufferPricingHookRepo._wrapZeroForOne();
    }

    /* ---------------------------------------------------------------------- */
    /*                              SE previews                               */
    /* ---------------------------------------------------------------------- */

    function _previewWrap(uint256 underlyingIn) internal view returns (uint256 seOut) {
        _requireNonZero(underlyingIn);
        return IStandardExchangeIn(_standardExchange).previewExchangeIn(
            IERC20(_underlying), underlyingIn, IERC20(_standardExchange)
        );
    }

    function _previewWrapExactOut(uint256 seOut) internal view returns (uint256 underlyingIn) {
        _requireNonZero(seOut);
        return IStandardExchangeOut(_standardExchange).previewExchangeOut(
            IERC20(_underlying), IERC20(_standardExchange), seOut
        );
    }

    function _previewUnwrap(uint256 seIn) internal view returns (uint256 underlyingOut) {
        _requireNonZero(seIn);
        return IStandardExchangeIn(_standardExchange).previewExchangeIn(
            IERC20(_standardExchange), seIn, IERC20(_underlying)
        );
    }

    function _previewUnwrapExactOut(uint256 underlyingOut) internal view returns (uint256 seIn) {
        _requireNonZero(underlyingOut);
        return IStandardExchangeOut(_standardExchange).previewExchangeOut(
            IERC20(_standardExchange), IERC20(_underlying), underlyingOut
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                         SE execute (tight bounds)                      */
    /* ---------------------------------------------------------------------- */

    function _seExchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minOut,
        bool pretransferred
    ) internal returns (uint256 amountOut) {
        return IStandardExchangeIn(_standardExchange).exchangeIn(
            tokenIn, amountIn, tokenOut, minOut, address(this), pretransferred, block.timestamp
        );
    }

    function _seExchangeOut(
        IERC20 tokenIn,
        uint256 maxIn,
        IERC20 tokenOut,
        uint256 amountOut,
        bool pretransferred
    ) internal returns (uint256 amountIn) {
        return IStandardExchangeOut(_standardExchange).exchangeOut(
            tokenIn, maxIn, tokenOut, amountOut, address(this), pretransferred, block.timestamp
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                    Pattern-copy take / settle / pay                    */
    /* ---------------------------------------------------------------------- */

    function _onlyPoolManager() internal view {
        if (msg.sender != address(_poolManager)) revert NotPoolManager();
    }

    function _take(Currency currency, address recipient, uint256 amount) internal {
        if (amount == 0) return;
        _poolManager.take(currency, recipient, amount);
    }

    function _settle(Currency currency, uint256 amount) internal {
        if (amount == 0) return;
        _poolManager.sync(currency);
        _pay(currency, amount);
        _poolManager.settle();
    }

    function _pay(Currency currency, uint256 amount) internal {
        IERC20(Currency.unwrap(currency)).safeTransfer(address(_poolManager), amount);
    }
}
