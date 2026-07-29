// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {
    MixedBufferMultiVaultStableDetfExchangeInTarget
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfExchangeInTarget.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";

/// @title MixedBufferMultiVaultStableDetfExchangeQueryTarget
/// @notice Closed-form previews for buffer/share → DETF and DETF → buffer. Exact-out reverts InvalidRoute.
abstract contract MixedBufferMultiVaultStableDetfExchangeQueryTarget is MixedBufferMultiVaultStableDetfExchangeInTarget {
    using FixedPoint for uint256;

    function previewExchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        public
        view
        virtual
        returns (uint256 amountOut_)
    {
        if (amountIn_ == 0) return 0;

        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();

        // View-only: reserve BPT → bufferToken (rebasing claim rate calc on mintFromNFTSale).
        if (address(tokenIn_) == address(s.reserveBpt)) {
            if (address(tokenOut_) != address(s.bufferToken)) {
                revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(tokenIn_), address(tokenOut_));
            }
            return _previewBptToBuffer(amountIn_);
        }

        // Burn DETF → buffer
        if (address(tokenIn_) == address(this)) {
            if (address(tokenOut_) != address(s.bufferToken)) {
                revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(tokenIn_), address(tokenOut_));
            }
            return _previewBurnDetfToBuffer(amountIn_);
        }

        // Mint buffer or vault share → DETF
        if (address(tokenOut_) == address(this)) {
            if (MixedBufferMultiVaultStableDetfRepo._isBufferToken(tokenIn_)) {
                MintSplit memory split_ = _splitMintedDetf(_quoteDetfOutForBuffer(amountIn_));
                return split_.userDetf;
            }
            (bool found_, uint256 legIndex_) = MixedBufferMultiVaultStableDetfRepo._findVaultShareIndex(tokenIn_);
            if (!found_) {
                revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(tokenIn_), address(tokenOut_));
            }
            MintSplit memory split2_ = _splitMintedDetf(_quoteDetfOutForVaultShares(legIndex_, amountIn_));
            return split2_.userDetf;
        }

        revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(tokenIn_), address(tokenOut_));
    }

    /// @dev Proportional BPT claim on math/physical legs, valued into buffer units.
    function _previewBptToBuffer(uint256 bptIn_) internal view returns (uint256 bufferOut_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 bptSupply_ = IERC20(s.reservePool).totalSupply();
        if (bptSupply_ == 0 || bptIn_ == 0) return 0;
        (,, uint256[] memory balancesRaw_,) = _reserveVault().getPoolTokenInfo(s.reservePool);
        // Buffer physical proportional claim.
        bufferOut_ = balancesRaw_[s.bufferIndex] * bptIn_ / bptSupply_;
        // Plus vault share legs converted at 1:1 rate-scaled into buffer units (STANDARD = 1e18).
        for (uint256 i; i < s.vaultCount; ++i) {
            uint256 shareAmt_ = balancesRaw_[s.shareIndexes[i]] * bptIn_ / bptSupply_;
            if (shareAmt_ == 0) continue;
            uint256 rate_ = _shareRate(i);
            bufferOut_ += shareAmt_.mulDown(rate_);
        }
        // DETF leg proportional claim is self-token — treat as buffer-unit notional at peg.
        bufferOut_ += balancesRaw_[s.detfIndex] * bptIn_ / bptSupply_;
    }

    function previewExchangeOut(IERC20 tokenIn_, IERC20 tokenOut_, uint256 /* amountOut_ */ )
        public
        pure
        virtual
        returns (uint256)
    {
        revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(tokenIn_), address(tokenOut_));
    }

    function exchangeOut(
        IERC20 tokenIn_,
        IERC20 tokenOut_,
        uint256 /* amountOut_ */,
        uint256 /* maxAmountIn_ */,
        address /* recipient_ */,
        bool /* pretransferred_ */,
        uint256 /* deadline_ */
    ) public pure virtual returns (uint256) {
        revert MixedBufferMultiVaultStableDetfRepo.InvalidRoute(address(tokenIn_), address(tokenOut_));
    }
}
