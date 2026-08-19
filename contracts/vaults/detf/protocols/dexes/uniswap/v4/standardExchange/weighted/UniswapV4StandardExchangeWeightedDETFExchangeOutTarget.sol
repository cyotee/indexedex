// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    UniswapV4StandardExchangeWeightedDETFCommon,
    IWeightedDetfCompoundSelf
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFCommon.sol";
import {
    UniswapV4StandardExchangeWeightedDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFRepo.sol";

/// @title UniswapV4StandardExchangeWeightedDETFExchangeOutTarget
/// @notice Primary burn: free DETF only → NFT LP exit (D13) → redeposit DETF → residual → pair.
/// @dev D12/D14/L4: burns DETF; no feeTo transfer; no amountIn bonus.
abstract contract UniswapV4StandardExchangeWeightedDETFExchangeOutTarget is
    UniswapV4StandardExchangeWeightedDETFCommon
{
    using BetterSafeERC20 for IERC20;

    struct BurnExecResidual {
        uint256 aDetf;
        uint256[] pairAmts; // product order
    }

    function _burnDetfExactIn(
        uint256 detfIn_,
        IERC20 tokenOut_,
        uint256 minOut_,
        address recipient_,
        bool pretransferred_,
        uint256 /* deadline_ */
    ) internal returns (uint256 amountOut_) {
        _requireReserveLive();
        if (!_isBurnTokenOutSupported(tokenOut_)) {
            revert Repo.InvalidRoute(IERC20(address(this)), tokenOut_);
        }
        uint8 outIdx_ = _pairProductIndexForBurnOut(tokenOut_);
        if (!_isBurningAllowed(outIdx_)) {
            revert Repo.BurningNotAllowed(_syntheticVs(outIdx_), Repo._layoutStruct().burnThreshold);
        }
        if (recipient_ == address(0)) recipient_ = msg.sender;

        uint256 pulled_ = _pullToken(IERC20(address(this)), detfIn_, pretransferred_);
        BurnExecResidual memory res = _burnAndRemoveNftLp(pulled_);
        amountOut_ = _settleBurnResidual(tokenOut_, res, recipient_, minOut_);
        _syncAllExpectedHoldReserves();
    }

    function _burnAndRemoveNftLp(uint256 burnPrincipal_)
        private
        returns (BurnExecResidual memory res)
    {
        _realizeExpansionIfNeeded();
        uint256 supply_ = ERC20Repo._totalSupply();
        uint256 nftLp_ = _nftLp();
        if (nftLp_ == 0 || supply_ == 0) revert Repo.EmptyProtocolLp();

        uint256 lpOut_ = burnPrincipal_ * nftLp_ / supply_;
        if (lpOut_ == 0) revert Repo.EmptyProtocolLp();

        _burnDetf(address(this), burnPrincipal_);
        _pullBondLp(lpOut_);
        uint256[] memory binding_ = _exitProportional(lpOut_, address(this));
        (res.aDetf, res.pairAmts) = _unpackBinding(binding_);
    }

    function _settleBurnResidual(
        IERC20 tokenOut_,
        BurnExecResidual memory res,
        address recipient_,
        uint256 minOut_
    ) private returns (uint256 amountOut_) {
        address outToken_ = address(tokenOut_);
        if (Repo._isPairToken(outToken_)) {
            amountOut_ = _consolidateToPair(outToken_, res.pairAmts);
            _redepositDetfSelfLeg(res.aDetf);
            if (amountOut_ > 0) IERC20(outToken_).safeTransfer(recipient_, amountOut_);
        } else {
            address midPair_ = _pairForShareOut(tokenOut_);
            uint256 mid_ = _consolidateToPair(midPair_, res.pairAmts);
            amountOut_ = _seWrap(midPair_, mid_, tokenOut_, recipient_);
            _redepositDetfSelfLeg(res.aDetf);
        }
        if (amountOut_ < minOut_) {
            revert IStandardExchangeErrors.MinAmountNotMet(minOut_, amountOut_);
        }
    }

    function _isBurnTokenOutSupported(IERC20 tokenOut_) internal view returns (bool) {
        if (address(tokenOut_) == address(this)) return false; // DETF out InvalidRoute
        if (Repo._isPairToken(address(tokenOut_))) return true;
        return _isShareOrSeTokenOut(tokenOut_);
    }


    function _pairProductIndexForBurnOut(IERC20 tokenOut_) internal view returns (uint8) {
        if (Repo._isPairToken(address(tokenOut_))) {
            return Repo._productIndexOfPair(address(tokenOut_));
        }
        // Share/SE out: gate on the underlying pair of that SE.
        return Repo._productIndexOfPair(_pairForShareOut(tokenOut_));
    }



    function _previewBurnDetfExactIn(uint256 detfIn_, IERC20 tokenOut_)
        internal
        view
        returns (uint256 amountOut_)
    {
        if (!Repo._layoutStruct().isReserveLive) return 0;
        if (!_isBurnTokenOutSupported(tokenOut_)) return 0;

        uint256 lpOut_ = _previewBurnLpOut(detfIn_);
        if (lpOut_ == 0) return 0;

        uint256[] memory residual_;
        try IHook(Repo._layoutStruct().reserveHook).previewExitProportional(lpOut_) returns (
            uint256[] memory amts_
        ) {
            residual_ = amts_;
        } catch {
            return 0;
        }
        (, uint256[] memory pairAmts_) = _unpackBinding(residual_);
        return _previewSettleBurnOut(tokenOut_, pairAmts_);
    }

    function _previewBurnLpOut(uint256 detfIn_) private view returns (uint256 lpOut_) {
        if (detfIn_ == 0) return 0;
        uint256 effectiveSupply_ = ERC20Repo._totalSupply() + _previewPendingExpansionMint();
        uint256 nftLp_ = _nftLp();
        if (nftLp_ == 0 || effectiveSupply_ == 0) return 0;
        lpOut_ = detfIn_ * nftLp_ / effectiveSupply_;
    }

    function _previewSettleBurnOut(IERC20 tokenOut_, uint256[] memory pairAmts_)
        private
        view
        returns (uint256)
    {
        address tout = address(tokenOut_);
        if (Repo._isPairToken(tout)) {
            return _previewConsolidateToPair(tout, pairAmts_);
        }
        return _previewSeWrapOut(tokenOut_, pairAmts_);
    }

    function _previewSeWrapOut(IERC20 tokenOut_, uint256[] memory pairAmts_)
        private
        view
        returns (uint256)
    {
        address mid_ = _pairForShareOut(tokenOut_);
        uint256 midAmt_ = _previewConsolidateToPair(mid_, pairAmts_);
        uint8 idx_ = Repo._productIndexOfPair(mid_);
        address se_ = address(Repo._layoutStruct().standardExchanges[idx_]);
        if (se_ == address(0)) return 0;
        try IStandardExchangeIn(se_).previewExchangeIn(IERC20(mid_), midAmt_, tokenOut_) returns (uint256 o_) {
            return o_;
        } catch {
            return 0;
        }
    }
}
