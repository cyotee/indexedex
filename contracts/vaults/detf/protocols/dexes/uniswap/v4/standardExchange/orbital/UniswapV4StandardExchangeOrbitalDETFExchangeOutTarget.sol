// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
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

    /// @dev Residual after multipath remove, before DETF redeposit (stack packing).
    struct BurnExecResidual {
        uint256 aDetf;
        uint256 a0;
        uint256 a1;
    }

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
        _realizeExpansionIfNeeded();
        if (!_isBurningAllowed()) {
            revert Repo.BurningNotAllowed(_syntheticPrice(), Repo._layoutStruct().burnThreshold);
        }
        if (recipient_ == address(0)) recipient_ = msg.sender;
        _requireBurnTokenOut(tokenOut_);

        uint256 pulled_ = _pullToken(IERC20(address(this)), detfIn_, pretransferred_);
        BurnExecResidual memory res = _burnAndRemoveNftLp(pulled_);
        amountOut_ = _settleBurnResidual(tokenOut_, res, recipient_, minOut_);
        _syncAllExpectedHoldReserves();
    }

    function _requireBurnTokenOut(IERC20 tokenOut_) private view {
        if (!_isBurnTokenOutSupported(tokenOut_)) {
            revert Repo.InvalidRoute(IERC20(address(this)), tokenOut_);
        }
    }

    function _burnAndRemoveNftLp(uint256 burnPrincipal_)
        private
        returns (BurnExecResidual memory res)
    {
        if (burnPrincipal_ == 0) revert Repo.ZeroAmount();
        uint256 supply_ = ERC20Repo._totalSupply();
        uint256 nftLp_ = _nftLp();
        if (nftLp_ == 0 || supply_ == 0) revert Repo.EmptyProtocolLp();

        uint256 lpOut_ = burnPrincipal_ * nftLp_ / supply_;
        if (lpOut_ == 0) revert Repo.EmptyProtocolLp();

        _burnDetf(address(this), burnPrincipal_);
        _pullBondLp(lpOut_);
        (res.aDetf, res.a0, res.a1) = _removeLiquidity(lpOut_, address(this));
    }

    function _settleBurnResidual(
        IERC20 tokenOut_,
        BurnExecResidual memory res,
        address recipient_,
        uint256 minOut_
    ) private returns (uint256 amountOut_) {
        // Consolidate residual pairs BEFORE redeposit so preview == execution bit-exact (few-wei only).
        Repo.Storage storage s = Repo._layoutStruct();
        address outToken_ = address(tokenOut_);
        if (outToken_ == address(s.pairToken0) || outToken_ == address(s.pairToken1)) {
            amountOut_ = _consolidateTo(outToken_, res.a0, res.a1);
            _redepositDetfSelfLeg(res.aDetf);
            if (amountOut_ > 0) IERC20(outToken_).safeTransfer(recipient_, amountOut_);
        } else {
            address midPair_ = _pairForShareOut(tokenOut_);
            uint256 mid_ = _consolidateTo(midPair_, res.a0, res.a1);
            amountOut_ = _seWrap(midPair_, mid_, tokenOut_, recipient_);
            // seWrap already sent to recipient when tokenOut is share/SE
            _redepositDetfSelfLeg(res.aDetf);
        }
        if (amountOut_ < minOut_) {
            revert IStandardExchangeErrors.MinAmountNotMet(minOut_, amountOut_);
        }
    }

    /// @dev Pair residual after preview-remove (DETF leg assumed redeposited).
    struct BurnPreviewResidual {
        address hookAddr;
        address p0;
        address p1;
        uint256 lpOut;
        uint256 ap0;
        uint256 ap1;
    }

    function _previewBurnDetfExactIn(uint256 detfIn_, IERC20 tokenOut_)
        internal
        view
        returns (uint256 amountOut_)
    {
        if (!Repo._layoutStruct().isReserveLive) return 0;
        if (!_isBurnTokenOutSupported(tokenOut_)) return 0;

        BurnPreviewResidual memory r = _loadBurnPreviewResidual(detfIn_);
        if (r.lpOut == 0) return 0;

        address tout = address(tokenOut_);
        if (tout == r.p0 || tout == r.p1) {
            return _previewConsolidatePairOut(r, tout);
        }
        return _previewConsolidateShareOut(r, tokenOut_);
    }

    function _isBurnTokenOutSupported(IERC20 tokenOut_) private view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        address tout = address(tokenOut_);
        return tout == address(s.pairToken0) || tout == address(s.pairToken1)
            || _isShareOrSeTokenOut(tokenOut_);
    }

    function _loadBurnPreviewResidual(uint256 detfIn_)
        private
        view
        returns (BurnPreviewResidual memory r)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        r.p0 = address(s.pairToken0);
        r.p1 = address(s.pairToken1);

        if (detfIn_ == 0) return r;

        uint256 effectiveSupply_ = ERC20Repo._totalSupply() + _previewPendingExpansionMint();
        uint256 nftLp_ = _nftLp();
        if (nftLp_ == 0 || effectiveSupply_ == 0) return r;
        r.lpOut = detfIn_ * nftLp_ / effectiveSupply_;
        if (r.lpOut == 0) return r;

        r.hookAddr = s.reserveHook;
        (uint256 a0_, uint256 a1_, uint256 a2_) = IHook(r.hookAddr).previewRemoveLiquidity(r.lpOut);
        // aDetf_ discarded — preview assumes redeposit succeeds (no DETF paid out).
        (, r.ap0, r.ap1) = _unpackBinding(a0_, a1_, a2_);
    }

    function _previewConsolidatePairOut(BurnPreviewResidual memory r, address tokenOut_)
        private
        view
        returns (uint256 amountOut_)
    {
        if (tokenOut_ == r.p0) {
            amountOut_ = r.ap0;
            if (r.ap1 > RESIDUAL_DUST) {
                amountOut_ += BurnPreviewLib.previewSphereExactInPostRemove(
                    r.hookAddr, r.lpOut, r.p1, r.p0, r.ap1
                );
            }
            return amountOut_;
        }
        amountOut_ = r.ap1;
        if (r.ap0 > RESIDUAL_DUST) {
            amountOut_ += BurnPreviewLib.previewSphereExactInPostRemove(
                r.hookAddr, r.lpOut, r.p0, r.p1, r.ap0
            );
        }
    }

    function _previewConsolidateShareOut(BurnPreviewResidual memory r, IERC20 tokenOut_)
        private
        view
        returns (uint256)
    {
        address mid_ = _pairForShareOut(tokenOut_);
        uint256 midAmt_ = _previewConsolidatePairOut(r, mid_);
        Repo.Storage storage s = Repo._layoutStruct();
        address se_ = mid_ == r.p0 ? address(s.standardExchange0) : address(s.standardExchange1);
        if (se_ == address(0)) return 0;
        try IStandardExchangeIn(se_).previewExchangeIn(IERC20(mid_), midAmt_, tokenOut_) returns (uint256 o_) {
            return o_;
        } catch {
            return 0;
        }
    }
}
