// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {
    SingleStandardExchangeDETFCommon
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFCommon.sol";
import {
    SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFRepo.sol";

/// @title SingleStandardExchangeDETFExchangeInQueryTarget
abstract contract SingleStandardExchangeDETFExchangeInQueryTarget is SingleStandardExchangeDETFCommon {
    function previewExchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        public
        view
        virtual
        returns (uint256 amountOut_)
    {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();

        if (address(tokenOut_) != address(this) && address(tokenIn_) != address(this)) {
            if (!_isAllowlistedTokenIn(tokenIn_) || !_isAllowlistedTokenIn(tokenOut_)) {
                revert SingleStandardExchangeDETFRepo.UnsupportedRoute(tokenIn_, tokenOut_);
            }
            return s.standardExchangeVault.previewExchangeIn(tokenIn_, amountIn_, tokenOut_);
        }

        if (address(tokenOut_) == address(this)) {
            uint256 vaultShares_;
            if (address(tokenIn_) == address(s.standardExchangeVaultShare)) {
                vaultShares_ = amountIn_;
            } else if (_isAllowlistedTokenIn(tokenIn_)) {
                vaultShares_ =
                    s.standardExchangeVault.previewExchangeIn(tokenIn_, amountIn_, s.standardExchangeVaultShare);
            } else {
                revert SingleStandardExchangeDETFRepo.UnsupportedRoute(tokenIn_, tokenOut_);
            }
            MintSplit memory split_ = _splitMintedDetf(_quoteDetfOutForVaultShares(vaultShares_));
            return split_.userDetf;
        }

        if (address(tokenIn_) == address(this)) {
            uint256 bptIn_ = _bptForDetfShares(amountIn_);
            uint256 bptSupply_ = IERC20(s.reservePool).totalSupply();
            if (bptSupply_ == 0) return 0;
            IVault bal_ = _reserveVault();
            (,, uint256[] memory balancesRaw_,) = bal_.getPoolTokenInfo(s.reservePool);
            uint256 vaultSharesOut_ = balancesRaw_[s.vaultShareIndex] * bptIn_ / bptSupply_;
            if (address(tokenOut_) == address(s.standardExchangeVaultShare)) {
                return vaultSharesOut_;
            }
            if (_isAllowlistedTokenIn(tokenOut_)) {
                return s.standardExchangeVault.previewExchangeIn(
                    s.standardExchangeVaultShare, vaultSharesOut_, tokenOut_
                );
            }
            revert SingleStandardExchangeDETFRepo.UnsupportedRoute(tokenIn_, tokenOut_);
        }

        revert SingleStandardExchangeDETFRepo.UnsupportedRoute(tokenIn_, tokenOut_);
    }
}
