// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {SingleStandardExchangeDETFCommon} from "./SingleStandardExchangeDETFCommon.sol";
import {SingleStandardExchangeDETFRepo as Repo} from "./SingleStandardExchangeDETFRepo.sol";

/// @notice Exact-input DETF redemption helper shared by standard direct and unstaking routes.
abstract contract SingleStandardExchangeDETFExchangeOutTarget is SingleStandardExchangeDETFCommon {
    using BetterSafeERC20 for IERC20;

    /// @dev Consumes only input already acquired by this operation. Snapshot precedes the burn.
    function _burnHeldDetf(uint256 amount_, IERC20 out_, uint256 min_, address to_, uint256 deadline_)
        internal returns (uint256)
    {
        _requireReserveLive();
        if (!_isAllowlistedTokenIn(out_)) revert Repo.UnsupportedRoute(IERC20(address(this)), out_);
        Repo.Storage storage s_ = Repo._layoutStruct();
        uint256 shares_;
        if (_isBurningAllowed()) {
            uint256 lp_ = _bptForDetfShares(amount_, false);
            _burnDetf(address(this), amount_);
            uint256 detfLeg_;
            (detfLeg_, shares_) = _exitReserveProportional(lp_);
            if (detfLeg_ != 0) _joinReserveDetfOnly(detfLeg_);
        } else {
            shares_ = _reserveSwap(s_.reservePool, IERC20(address(this)), s_.standardExchangeVaultShare, amount_, 0);
        }
        return _sendVaultShares(shares_, out_, min_, to_, deadline_);
    }
}
