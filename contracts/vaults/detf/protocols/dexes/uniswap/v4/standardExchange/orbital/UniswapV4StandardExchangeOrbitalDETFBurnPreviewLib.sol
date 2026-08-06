// SPDX-License-Identifier: BUSL-1.1
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
library UniswapV4StandardExchangeOrbitalDETFBurnPreviewLib {
    function previewSphereExactInPostRemove(
        address hookAddr_,
        uint256 lpOut_,
        address tokenIn_,
        address tokenOut_,
        uint256 amountIn_
    ) external view returns (uint256 amountOut_) {
        if (amountIn_ == 0 || tokenIn_ == tokenOut_) return 0;
        IHook hook_ = IHook(hookAddr_);
        uint256 supply_ = IERC20(hookAddr_).totalSupply();
        if (supply_ == 0 || lpOut_ >= supply_) return 0;
        uint256 remain_ = supply_ - lpOut_;

        (uint256 e0_, uint256 e1_, uint256 e2_) = hook_.effectiveReserves();
        e0_ = (e0_ * remain_) / supply_;
        e1_ = (e1_ * remain_) / supply_;
        e2_ = (e2_ * remain_) / supply_;

        address t0_ = hook_.token0();
        address t1_ = hook_.token1();
        address t2_ = hook_.token2();
        (uint256 eIn_, uint256 eOut_, uint256 eZ_, address tokenZ_) =
            _mapLegs(tokenIn_, tokenOut_, t0_, t1_, t2_, e0_, e1_, e2_);
        if (eIn_ == 0 || eOut_ == 0 || tokenZ_ == address(0)) return 0;

        uint256 R_ = hook_.radius();
        if (R_ == 0) return 0;
        uint8 dIn_ = IERC20Metadata(tokenIn_).decimals();
        uint8 dOut_ = IERC20Metadata(tokenOut_).decimals();
        uint8 dZ_ = IERC20Metadata(tokenZ_).decimals();
        uint256 xWad_ = HookMath.toWad(eIn_, dIn_);
        uint256 yWad_ = HookMath.toWad(eOut_, dOut_);
        uint256 zWad_ = HookMath.toWad(eZ_, dZ_);
        if (xWad_ >= R_ || yWad_ >= R_ || zWad_ >= R_) return 0;
        uint256 L2_ = HookMath.recomputeL2(R_, xWad_, yWad_, zWad_);

        uint256 dInNative_ = amountIn_;
        address seIn_ = _seOf(hook_, tokenIn_, t0_, t1_, t2_);
        if (seIn_ != address(0)) {
            dInNative_ = ClaimLib.previewBufferClaimIn(
                seIn_, _rpOf(hook_, tokenIn_, t0_, t1_, t2_), tokenIn_, amountIn_, hookAddr_
            );
            if (dInNative_ == 0) return 0;
        }
        uint256 feeWad_ = hook_.dexSwapFee();
        if (feeWad_ >= HookMath.WAD) return 0;
        uint256 dxNet_ = HookMath.applyTradingFeeNet(HookMath.toWad(dInNative_, dIn_), feeWad_);
        if (dxNet_ == 0 || xWad_ + dxNet_ >= R_) return 0;

        uint256 dyWad_ = HookMath.sphereExactInOutWad(R_, L2_, xWad_, yWad_, zWad_, dxNet_);
        uint256 dOutNative_ = HookMath.fromWadFloor(dyWad_, dOut_);
        address seOut_ = _seOf(hook_, tokenOut_, t0_, t1_, t2_);
        if (seOut_ != address(0)) {
            (amountOut_,) = ClaimLib.previewUnwrapForEffectiveOut(
                seOut_, _rpOf(hook_, tokenOut_, t0_, t1_, t2_), tokenOut_, dOutNative_
            );
        } else {
            amountOut_ = dOutNative_;
        }
        if (amountOut_ == 0 || amountOut_ >= eOut_) return 0;
    }

    function _mapLegs(
        address tokenIn_,
        address tokenOut_,
        address t0_,
        address t1_,
        address t2_,
        uint256 e0_,
        uint256 e1_,
        uint256 e2_
    ) private pure returns (uint256 eIn_, uint256 eOut_, uint256 eZ_, address tokenZ_) {
        if (tokenIn_ == t0_) {
            if (tokenOut_ == t1_) return (e0_, e1_, e2_, t2_);
            if (tokenOut_ == t2_) return (e0_, e2_, e1_, t1_);
        } else if (tokenIn_ == t1_) {
            if (tokenOut_ == t0_) return (e1_, e0_, e2_, t2_);
            if (tokenOut_ == t2_) return (e1_, e2_, e0_, t0_);
        } else if (tokenIn_ == t2_) {
            if (tokenOut_ == t0_) return (e2_, e0_, e1_, t1_);
            if (tokenOut_ == t1_) return (e2_, e1_, e0_, t0_);
        }
        return (0, 0, 0, address(0));
    }

    function _seOf(IHook hook_, address token_, address t0_, address t1_, address t2_)
        private
        view
        returns (address)
    {
        if (token_ == t0_) return hook_.standardExchange(0);
        if (token_ == t1_) return hook_.standardExchange(1);
        if (token_ == t2_) return hook_.standardExchange(2);
        return address(0);
    }

    function _rpOf(IHook hook_, address token_, address t0_, address t1_, address t2_)
        private
        view
        returns (address)
    {
        if (token_ == t0_) return hook_.rateProvider(0);
        if (token_ == t1_) return hook_.rateProvider(1);
        if (token_ == t2_) return hook_.rateProvider(2);
        return address(0);
    }
}
