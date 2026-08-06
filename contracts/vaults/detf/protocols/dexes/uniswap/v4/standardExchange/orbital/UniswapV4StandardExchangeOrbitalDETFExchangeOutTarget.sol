// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {DETFUsageFeeLib} from "contracts/vaults/detf/common/core/DETFUsageFeeLib.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFCommon
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFCommon.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFBurnPreviewLib as BurnPreviewLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFBurnPreviewLib.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFRepo.sol";

/// @title UniswapV4StandardExchangeOrbitalDETFExchangeOutTarget
/// @notice Primary burn: free DETF only → multipath remove → redeposit DETF → residual → pair.
/// @dev Uses effectiveSupply; does NOT realize expansion. Burn usage fee YES.
abstract contract UniswapV4StandardExchangeOrbitalDETFExchangeOutTarget is
    UniswapV4StandardExchangeOrbitalDETFCommon
{
    using BetterSafeERC20 for IERC20;

    /// @dev Atomic burn order freeze (plan §4.8): pull+burn → usage fee already in seigniorage path for mint;
    ///      for burn: apply usage fee on DETF burned (fee DETF to feeTo), then remove, redeposit, consolidate, pay.
    function _burnDetfExactIn(
        uint256 detfIn_,
        IERC20 tokenOut_,
        uint256 minOut_,
        address recipient_,
        bool pretransferred_,
        uint256 /* deadline_ */
    ) internal returns (uint256 amountOut_) {
        _requireReserveLive();
        if (!_isBurningAllowed()) {
            revert Repo.BurningNotAllowed(_syntheticPrice(), Repo._layoutStruct().burnThreshold);
        }
        if (recipient_ == address(0)) recipient_ = msg.sender;

        Repo.Storage storage s = Repo._layoutStruct();
        address p0_ = address(s.pairToken0);
        address p1_ = address(s.pairToken1);
        if (address(tokenOut_) != p0_ && address(tokenOut_) != p1_) {
            // Optional SE unwrap matrix: tokenOut = vaultShare via pair residual + SE exchangeIn.
            if (!_isShareOrSeTokenOut(tokenOut_)) {
                revert Repo.InvalidRoute(IERC20(address(this)), tokenOut_);
            }
        }

        if (!pretransferred_) {
            IERC20(address(this)).safeTransferFrom(msg.sender, address(this), detfIn_);
        }

        // Burn usage fee: split DETF burned → feeTo keeps fee DETF; principal burn amount after fee.
        (uint256 afterFee_, uint256 feeTo_) = _splitBurnUsageFee(detfIn_);
        if (feeTo_ > 0) {
            IERC20(address(this)).safeTransfer(_feeTo(), feeTo_);
        }
        uint256 burnPrincipal_ = afterFee_;
        if (burnPrincipal_ == 0) revert Repo.ZeroAmount();

        // Does NOT call _realizeExpansionIfNeeded.
        uint256 pending_ = _previewPendingExpansionMint();
        uint256 supply_ = ERC20Repo._totalSupply();
        uint256 effectiveSupply_ = supply_ + pending_;
        uint256 protocolLp_ = _protocolLp();
        if (protocolLp_ == 0 || effectiveSupply_ == 0) revert Repo.EmptyProtocolLp();

        uint256 lpOut_ = burnPrincipal_ * protocolLp_ / effectiveSupply_;
        if (lpOut_ == 0) revert Repo.EmptyProtocolLp();

        _burnDetf(address(this), burnPrincipal_);
        _ensureProtocolLpOnDiamond(lpOut_);

        (uint256 aDetf_, uint256 a0_, uint256 a1_) = _removeLiquidity(lpOut_, address(this));

        // Preview freeze: residual consolidate uses pre-redeposit book (previewRemove + sphere).
        // Consolidate residual pairs BEFORE redeposit so preview == execution bit-exact (few-wei only).
        address outToken_ = address(tokenOut_);
        if (outToken_ == p0_ || outToken_ == p1_) {
            amountOut_ = _consolidateTo(outToken_, a0_, a1_);
        } else {
            address midPair_ = _pairForShareOut(tokenOut_);
            uint256 mid_ = _consolidateTo(midPair_, a0_, a1_);
            amountOut_ = _seWrap(midPair_, mid_, tokenOut_, recipient_);
            // seWrap already sent to recipient when tokenOut is share/SE
            if (amountOut_ < minOut_) {
                revert IStandardExchangeErrors.MinAmountNotMet(minOut_, amountOut_);
            }
            // Redeposit DETF after residual settle (do not burn; do not pay to burner).
            _redepositDetfSelfLeg(aDetf_);
            return amountOut_;
        }

        // Redeposit returned DETF after residual FX (preview does not pay DETF out).
        _redepositDetfSelfLeg(aDetf_);

        if (amountOut_ > 0) IERC20(outToken_).safeTransfer(recipient_, amountOut_);
        if (amountOut_ < minOut_) {
            revert IStandardExchangeErrors.MinAmountNotMet(minOut_, amountOut_);
        }
    }

    function _splitBurnUsageFee(uint256 detfIn_)
        internal
        view
        returns (uint256 afterFee_, uint256 feeTo_)
    {
        return DETFUsageFeeLib._splitUsageFee(detfIn_, _usageFeeWad());
    }

    function _isShareOrSeTokenOut(IERC20 tokenOut_) internal view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(tokenOut_) == address(s.vaultShare0) || address(tokenOut_) == address(s.vaultShare1)) {
            return true;
        }
        if (address(s.standardExchange0) != address(0) && _tokenInSeTokens(tokenOut_, address(s.standardExchange0))) {
            return true;
        }
        if (address(s.standardExchange1) != address(0) && _tokenInSeTokens(tokenOut_, address(s.standardExchange1))) {
            return true;
        }
        return false;
    }

    function _pairForShareOut(IERC20 tokenOut_) internal view returns (address) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (
            address(tokenOut_) == address(s.vaultShare0)
                || (address(s.standardExchange0) != address(0)
                    && _tokenInSeTokens(tokenOut_, address(s.standardExchange0)))
        ) {
            return address(s.pairToken0);
        }
        return address(s.pairToken1);
    }

    function _seWrap(address pair_, uint256 pairAmt_, IERC20 tokenOut_, address recipient_)
        internal
        returns (uint256 out_)
    {
        if (pairAmt_ == 0) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        address se_;
        if (pair_ == address(s.pairToken0)) {
            se_ = address(s.standardExchange0);
        } else {
            se_ = address(s.standardExchange1);
        }
        if (se_ == address(0)) revert Repo.InvalidRoute(IERC20(pair_), tokenOut_);
        IERC20(pair_).forceApprove(se_, pairAmt_);
        out_ = IStandardExchangeIn(se_).exchangeIn(
            IERC20(pair_), pairAmt_, tokenOut_, 0, recipient_, false, block.timestamp + 1
        );
    }

    function _previewBurnDetfExactIn(uint256 detfIn_, IERC20 tokenOut_)
        internal
        view
        returns (uint256 amountOut_)
    {
        if (!Repo._layoutStruct().isReserveLive) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        address p0_ = address(s.pairToken0);
        address p1_ = address(s.pairToken1);
        if (address(tokenOut_) != p0_ && address(tokenOut_) != p1_ && !_isShareOrSeTokenOut(tokenOut_)) {
            return 0;
        }

        (uint256 afterFee_,) = _splitBurnUsageFee(detfIn_);
        if (afterFee_ == 0) return 0;

        uint256 pending_ = _previewPendingExpansionMint();
        uint256 supply_ = ERC20Repo._totalSupply();
        uint256 effectiveSupply_ = supply_ + pending_;
        uint256 protocolLp_ = _protocolLp();
        if (protocolLp_ == 0 || effectiveSupply_ == 0) return 0;
        uint256 lpOut_ = afterFee_ * protocolLp_ / effectiveSupply_;
        if (lpOut_ == 0) return 0;

        IHook hook_ = IHook(s.reserveHook);
        (uint256 a0_, uint256 a1_, uint256 a2_) = hook_.previewRemoveLiquidity(lpOut_);
        (uint256 aDetf_, uint256 ap0_, uint256 ap1_) = _unpackBinding(a0_, a1_, a2_);
        // Preview assumes redeposit succeeds (no DETF paid out).
        aDetf_; // silence — redeposited

        // Residual sphere on post-remove book (external lib — matches remove-then-consolidate).
        address hookAddr_ = address(hook_);
        if (address(tokenOut_) == p0_ || address(tokenOut_) == p1_) {
            if (address(tokenOut_) == p0_) {
                amountOut_ = ap0_;
                if (ap1_ > RESIDUAL_DUST) {
                    amountOut_ += BurnPreviewLib.previewSphereExactInPostRemove(
                        hookAddr_, lpOut_, p1_, p0_, ap1_
                    );
                }
            } else {
                amountOut_ = ap1_;
                if (ap0_ > RESIDUAL_DUST) {
                    amountOut_ += BurnPreviewLib.previewSphereExactInPostRemove(
                        hookAddr_, lpOut_, p0_, p1_, ap0_
                    );
                }
            }
            return amountOut_;
        }

        address mid_ = _pairForShareOut(tokenOut_);
        uint256 midAmt_;
        if (mid_ == p0_) {
            midAmt_ = ap0_;
            if (ap1_ > RESIDUAL_DUST) {
                midAmt_ += BurnPreviewLib.previewSphereExactInPostRemove(
                    hookAddr_, lpOut_, p1_, p0_, ap1_
                );
            }
        } else {
            midAmt_ = ap1_;
            if (ap0_ > RESIDUAL_DUST) {
                midAmt_ += BurnPreviewLib.previewSphereExactInPostRemove(
                    hookAddr_, lpOut_, p0_, p1_, ap0_
                );
            }
        }
        address se_ = mid_ == p0_ ? address(s.standardExchange0) : address(s.standardExchange1);
        if (se_ == address(0)) return 0;
        try IStandardExchangeIn(se_).previewExchangeIn(IERC20(mid_), midAmt_, tokenOut_) returns (uint256 o_) {
            return o_;
        } catch {
            return 0;
        }
    }
}
