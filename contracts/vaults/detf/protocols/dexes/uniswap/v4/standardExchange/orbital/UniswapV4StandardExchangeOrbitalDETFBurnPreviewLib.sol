// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookMath as HookMath
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookMath.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookClaimLib as ClaimLib
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol";

/// @notice External library: burn residual sphere on **post-remove** book (matches remove-then-consolidate).
/// @dev Lives outside DETF facet bytecode (EIP-170 / via-IR tag space).
///      Stack-safe packing for default `via_ir = false` monorepo builds.
library UniswapV4StandardExchangeOrbitalDETFBurnPreviewLib {
    /// @dev Hook binding + post-remove effective natives.
    struct PostRemoveBook {
        address hookAddr;
        address t0;
        address t1;
        address t2;
        uint256 e0;
        uint256 e1;
        uint256 e2;
        uint256 R;
    }

    /// @dev Mapped sphere legs for tokenIn → tokenOut.
    struct MappedLegs {
        uint256 eIn;
        uint256 eOut;
        uint256 eZ;
        address tokenZ;
        uint8 dIn;
        uint8 dOut;
        uint8 dZ;
    }

    /// @dev Sphere domain in WAD.
    struct SphereWad {
        uint256 R;
        uint256 L2;
        uint256 xWad;
        uint256 yWad;
        uint256 zWad;
    }

    function previewSphereExactInPostRemove(
        address hookAddr_,
        uint256 lpOut_,
        address tokenIn_,
        address tokenOut_,
        uint256 amountIn_
    ) external view returns (uint256 amountOut_) {
        if (amountIn_ == 0 || tokenIn_ == tokenOut_) return 0;
        PostRemoveBook memory book = _loadPostRemoveBook(hookAddr_, lpOut_);
        if (book.R == 0) return 0;

        MappedLegs memory legs = _mapLegs(tokenIn_, tokenOut_, book);
        if (legs.eIn == 0 || legs.eOut == 0 || legs.tokenZ == address(0)) return 0;

        SphereWad memory sphere = _sphereWad(book.R, legs);
        if (sphere.xWad >= sphere.R || sphere.yWad >= sphere.R || sphere.zWad >= sphere.R) return 0;

        uint256 dInNative = _faceInToEffective(book, tokenIn_, amountIn_);
        if (dInNative == 0) return 0;

        uint256 feeWad = IHook(hookAddr_).dexSwapFee();
        if (feeWad >= HookMath.WAD) return 0;
        uint256 dxNet = HookMath.applyTradingFeeNet(HookMath.toWad(dInNative, legs.dIn), feeWad);
        if (dxNet == 0 || sphere.xWad + dxNet >= sphere.R) return 0;

        uint256 dyWad = HookMath.sphereExactInOutWad(
            sphere.R, sphere.L2, sphere.xWad, sphere.yWad, sphere.zWad, dxNet
        );
        amountOut_ = _effectiveOutToFace(book, tokenOut_, HookMath.fromWadFloor(dyWad, legs.dOut));
        if (amountOut_ == 0 || amountOut_ >= legs.eOut) return 0;
    }

    function _loadPostRemoveBook(address hookAddr_, uint256 lpOut_)
        private
        view
        returns (PostRemoveBook memory book)
    {
        uint256 supply = IERC20(hookAddr_).totalSupply();
        if (supply == 0 || lpOut_ >= supply) return book;
        uint256 remain = supply - lpOut_;

        IHook hook = IHook(hookAddr_);
        book.hookAddr = hookAddr_;
        (book.e0, book.e1, book.e2) = hook.effectiveReserves();
        book.e0 = (book.e0 * remain) / supply;
        book.e1 = (book.e1 * remain) / supply;
        book.e2 = (book.e2 * remain) / supply;
        book.t0 = hook.token0();
        book.t1 = hook.token1();
        book.t2 = hook.token2();
        book.R = hook.radius();
    }

    function _mapLegs(address tokenIn_, address tokenOut_, PostRemoveBook memory book)
        private
        view
        returns (MappedLegs memory legs)
    {
        (legs.eIn, legs.eOut, legs.eZ, legs.tokenZ) =
            _mapLegValues(tokenIn_, tokenOut_, book);
        if (legs.tokenZ == address(0)) return legs;
        legs.dIn = IERC20Metadata(tokenIn_).decimals();
        legs.dOut = IERC20Metadata(tokenOut_).decimals();
        legs.dZ = IERC20Metadata(legs.tokenZ).decimals();
    }

    function _mapLegValues(address tokenIn_, address tokenOut_, PostRemoveBook memory book)
        private
        pure
        returns (uint256 eIn_, uint256 eOut_, uint256 eZ_, address tokenZ_)
    {
        if (tokenIn_ == book.t0) {
            if (tokenOut_ == book.t1) return (book.e0, book.e1, book.e2, book.t2);
            if (tokenOut_ == book.t2) return (book.e0, book.e2, book.e1, book.t1);
        } else if (tokenIn_ == book.t1) {
            if (tokenOut_ == book.t0) return (book.e1, book.e0, book.e2, book.t2);
            if (tokenOut_ == book.t2) return (book.e1, book.e2, book.e0, book.t0);
        } else if (tokenIn_ == book.t2) {
            if (tokenOut_ == book.t0) return (book.e2, book.e0, book.e1, book.t1);
            if (tokenOut_ == book.t1) return (book.e2, book.e1, book.e0, book.t0);
        }
        return (0, 0, 0, address(0));
    }

    function _sphereWad(uint256 R_, MappedLegs memory legs)
        private
        pure
        returns (SphereWad memory s)
    {
        s.R = R_;
        s.xWad = HookMath.toWad(legs.eIn, legs.dIn);
        s.yWad = HookMath.toWad(legs.eOut, legs.dOut);
        s.zWad = HookMath.toWad(legs.eZ, legs.dZ);
        s.L2 = HookMath.recomputeL2(s.R, s.xWad, s.yWad, s.zWad);
    }

    function _faceInToEffective(PostRemoveBook memory book, address tokenIn_, uint256 amountIn_)
        private
        view
        returns (uint256 dInNative_)
    {
        dInNative_ = amountIn_;
        address seIn = _seOf(book, tokenIn_);
        if (seIn != address(0)) {
            dInNative_ = ClaimLib.previewBufferClaimIn(
                seIn, _rpOf(book, tokenIn_), tokenIn_, amountIn_, book.hookAddr
            );
        }
    }

    function _effectiveOutToFace(
        PostRemoveBook memory book,
        address tokenOut_,
        uint256 dOutNative_
    ) private view returns (uint256 amountOut_) {
        address seOut = _seOf(book, tokenOut_);
        if (seOut != address(0)) {
            (amountOut_,) = ClaimLib.previewUnwrapForEffectiveOut(
                seOut, _rpOf(book, tokenOut_), tokenOut_, dOutNative_
            );
        } else {
            amountOut_ = dOutNative_;
        }
    }

    function _seOf(PostRemoveBook memory book, address token_) private view returns (address) {
        IHook hook = IHook(book.hookAddr);
        if (token_ == book.t0) return hook.standardExchange(0);
        if (token_ == book.t1) return hook.standardExchange(1);
        if (token_ == book.t2) return hook.standardExchange(2);
        return address(0);
    }

    function _rpOf(PostRemoveBook memory book, address token_) private view returns (address) {
        IHook hook = IHook(book.hookAddr);
        if (token_ == book.t0) return hook.rateProvider(0);
        if (token_ == book.t1) return hook.rateProvider(1);
        if (token_ == book.t2) return hook.rateProvider(2);
        return address(0);
    }
}
