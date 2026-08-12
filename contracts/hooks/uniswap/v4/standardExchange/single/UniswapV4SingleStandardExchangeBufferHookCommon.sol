// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {
    UniswapV4SingleStandardExchangeBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookRepo.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferHookCommon
 * @notice SE preview/execute helpers + pattern-copied take/settle (no Crane hook inheritance).
 */
abstract contract UniswapV4SingleStandardExchangeBufferHookCommon {
    using SafeERC20 for IERC20;

    // Closed error set (O14) — Crane BaseTokenWrapperHook / package names.
    error ZeroAmount();
    error NotPoolManager();
    error LiquidityNotAllowed();
    error InvalidPoolToken();
    error InvalidPoolFee();
    error HookNotImplemented();
    // Declare only — never throw in v1.
    error ExactInputNotSupported();
    error ExactOutputNotSupported();

    uint24 internal constant POOL_FEE = 0;
    int24 internal constant TICK_SPACING_HINT = 60;
    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    function poolManager() public view virtual returns (IPoolManager) {
        return IPoolManager(Repo._poolManager());
    }

    function standardExchange() public view virtual returns (address) {
        return Repo._standardExchange();
    }

    function pairToken() public view virtual returns (address) {
        return Repo._pairToken();
    }

    function wrapper() public view virtual returns (address) {
        return Repo._standardExchange();
    }

    function currency0() public view virtual returns (address) {
        return Repo._currency0();
    }

    function currency1() public view virtual returns (address) {
        return Repo._currency1();
    }

    function poolFee() public pure virtual returns (uint24) {
        return POOL_FEE;
    }

    function tickSpacingHint() public pure virtual returns (int24) {
        return TICK_SPACING_HINT;
    }

    function sqrtPriceX96Hint() public pure virtual returns (uint160) {
        return SQRT_PRICE_1_1;
    }

    function _requireNonZero(uint256 amount) internal pure {
        if (amount == 0) revert ZeroAmount();
    }

    function _wrapZeroForOne() internal view returns (bool) {
        return Repo._wrapZeroForOne();
    }

    function _se() internal view returns (address) {
        return Repo._standardExchange();
    }

    function _pair() internal view returns (address) {
        return Repo._pairToken();
    }

    /* ---------------------------------------------------------------------- */
    /*                              SE previews                               */
    /* ---------------------------------------------------------------------- */

    function _previewWrap(uint256 pairIn) internal view returns (uint256 seOut) {
        _requireNonZero(pairIn);
        address se = _se();
        address pair = _pair();
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(pair), pairIn, IERC20(se));
    }

    function _previewWrapExactOut(uint256 seOut) internal view returns (uint256 pairIn) {
        _requireNonZero(seOut);
        address se = _se();
        address pair = _pair();
        return IStandardExchangeOut(se).previewExchangeOut(IERC20(pair), IERC20(se), seOut);
    }

    function _previewUnwrap(uint256 seIn) internal view returns (uint256 pairOut) {
        _requireNonZero(seIn);
        address se = _se();
        address pair = _pair();
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seIn, IERC20(pair));
    }

    function _previewUnwrapExactOut(uint256 pairOut) internal view returns (uint256 seIn) {
        _requireNonZero(pairOut);
        address se = _se();
        address pair = _pair();
        return IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(pair), pairOut);
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
        address se = _se();
        return IStandardExchangeIn(se).exchangeIn(
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
        address se = _se();
        return IStandardExchangeOut(se).exchangeOut(
            tokenIn, maxIn, tokenOut, amountOut, address(this), pretransferred, block.timestamp
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                    Pattern-copy take / settle / pay                    */
    /* ---------------------------------------------------------------------- */

    function _onlyPoolManager() internal view {
        if (msg.sender != Repo._poolManager()) revert NotPoolManager();
    }

    function _take(Currency currency, address recipient, uint256 amount) internal {
        if (amount == 0) return;
        IPoolManager(Repo._poolManager()).take(currency, recipient, amount);
    }

    function _settle(Currency currency, uint256 amount) internal {
        if (amount == 0) return;
        IPoolManager pm = IPoolManager(Repo._poolManager());
        pm.sync(currency);
        _pay(currency, amount);
        pm.settle();
    }

    function _pay(Currency currency, uint256 amount) internal {
        IERC20(Currency.unwrap(currency)).safeTransfer(Repo._poolManager(), amount);
    }
}
