// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SingleStandardExchangeDETFCommon} from "./SingleStandardExchangeDETFCommon.sol";
import {SingleStandardExchangeDETFRepo as Repo} from "./SingleStandardExchangeDETFRepo.sol";

/// @notice Standard route previews simulate due expansion before selecting primary issuance or swap.
abstract contract SingleStandardExchangeDETFExchangeInQueryTarget is SingleStandardExchangeDETFCommon {
    function previewExchangeIn(IERC20 in_, uint256 amount_, IERC20 out_)
        public view virtual returns (uint256)
    {
        if (address(in_) == address(out_)) revert Repo.UnsupportedRoute(in_, out_);
        Repo.Storage storage s_ = Repo._layoutStruct();
        IERC20 staking_ = IERC20(address(s_.rebasingClaimToken));
        bool inputPrincipal_ = address(in_) == address(this) || address(in_) == address(staking_);
        bool outputPrincipal_ = address(out_) == address(this) || address(out_) == address(staking_);
        if (inputPrincipal_ && outputPrincipal_) return amount_;
        if (inputPrincipal_) {
            _requireReserveLive();
            uint256 shares_ = _previewPrimaryBurn()
                ? _previewBptUnwind(_bptForDetfShares(amount_, true))
                : _quoteReserveSwap(true, amount_);
            return _previewVaultSharesOut(shares_, out_);
        }
        if (outputPrincipal_) {
            _requireReserveLive();
            uint256 shares_ = _previewVaultSharesIn(in_, amount_);
            return _previewPrimaryMint()
                ? _splitMintedDetf(_quoteDetfOutForVaultShares(shares_)).userDetf
                : _quoteReserveSwap(false, shares_);
        }
        if (!_isAllowlistedTokenIn(in_) || !_isAllowlistedTokenIn(out_)) revert Repo.UnsupportedRoute(in_, out_);
        return s_.standardExchangeVault.previewExchangeIn(in_, amount_, out_);
    }
}
