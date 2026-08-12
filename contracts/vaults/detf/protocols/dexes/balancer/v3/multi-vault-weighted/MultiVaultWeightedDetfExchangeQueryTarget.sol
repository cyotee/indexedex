// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    MultiVaultWeightedDetfExchangeInTarget
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfExchangeInTarget.sol";
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";

/// @title MultiVaultWeightedDetfExchangeQueryTarget
/// @notice Closed-form previews for vaultShare↔DETF. Exact-out / binary-search routes revert InvalidRoute.
/// @dev Preview for reserve BPT → configured rateAsset is view-only (claim pricing); public exchangeIn of BPT remains InvalidRoute.
abstract contract MultiVaultWeightedDetfExchangeQueryTarget is MultiVaultWeightedDetfExchangeInTarget {
    function previewExchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        public
        view
        virtual
        returns (uint256 amountOut_)
    {
        if (amountIn_ == 0) return 0;

        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();

        // View-only quote: reserve BPT → configured rateAsset (used by rebasing claim rate calc).
        if (address(tokenIn_) == address(s.reserveBpt)) {
            (bool foundRa_, uint256 leg_) = MultiVaultWeightedDetfRepo._findRateAssetLeg(tokenOut_);
            if (!foundRa_) {
                revert MultiVaultWeightedDetfRepo.InvalidRoute(address(tokenIn_), address(tokenOut_));
            }
            return _previewBptToRateAsset(amountIn_, leg_);
        }

        // Burn DETF → vault share
        if (address(tokenIn_) == address(this)) {
            (bool found_, uint256 legIndex_) = MultiVaultWeightedDetfRepo._findVaultShareIndex(tokenOut_);
            if (!found_) {
                revert MultiVaultWeightedDetfRepo.InvalidRoute(address(tokenIn_), address(tokenOut_));
            }
            return _previewBurnDetfToVaultShare(amountIn_, legIndex_);
        }

        // Mint vault share → DETF
        if (address(tokenOut_) == address(this)) {
            (bool found_, uint256 legIndex_) = MultiVaultWeightedDetfRepo._findVaultShareIndex(tokenIn_);
            if (!found_) {
                revert MultiVaultWeightedDetfRepo.InvalidRoute(address(tokenIn_), address(tokenOut_));
            }
            MintSplit memory split_ = _splitMintedDetf(_quoteDetfOutForVaultShares(legIndex_, amountIn_));
            return split_.userDetf;
        }

        revert MultiVaultWeightedDetfRepo.InvalidRoute(address(tokenIn_), address(tokenOut_));
    }

    /// @dev Proportional BPT claim on target vault leg, then SE vault preview to rateAsset.
    function _previewBptToRateAsset(uint256 bptIn_, uint256 legIndex_)
        internal
        view
        returns (uint256 rateAssetOut_)
    {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        uint256 bptSupply_ = IERC20(s.reservePool).totalSupply();
        if (bptSupply_ == 0 || bptIn_ == 0) return 0;
        (,, uint256[] memory balancesRaw_,) = _reserveVault().getPoolTokenInfo(s.reservePool);
        uint256 vaultSharesOut_ = balancesRaw_[s.vaultShareIndexes[legIndex_]] * bptIn_ / bptSupply_;
        if (vaultSharesOut_ == 0) return 0;
        return s.underlyingVaults[legIndex_].previewExchangeIn(
            s.vaultShares[legIndex_], vaultSharesOut_, s.rateAssets[legIndex_]
        );
    }

    /// @dev Exact-out requires inverse curve search — not gas-efficient closed form in v1.
    function previewExchangeOut(IERC20 tokenIn_, IERC20 tokenOut_, uint256 /* amountOut_ */ )
        public
        pure
        virtual
        returns (uint256)
    {
        revert MultiVaultWeightedDetfRepo.InvalidRoute(address(tokenIn_), address(tokenOut_));
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
        revert MultiVaultWeightedDetfRepo.InvalidRoute(address(tokenIn_), address(tokenOut_));
    }
}
