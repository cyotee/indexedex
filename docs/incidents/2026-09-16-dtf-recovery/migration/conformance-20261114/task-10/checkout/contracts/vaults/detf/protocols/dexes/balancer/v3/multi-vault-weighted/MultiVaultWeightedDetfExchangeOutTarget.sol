// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {MultiVaultWeightedDetfCommon} from "./MultiVaultWeightedDetfCommon.sol";
import {MultiVaultWeightedDetfRepo as Repo} from "./MultiVaultWeightedDetfRepo.sol";

/// @notice Primary owned-LP redemption or a supply-neutral reserve swap into the chosen share.
abstract contract MultiVaultWeightedDetfExchangeOutTarget is MultiVaultWeightedDetfCommon {
    using BetterSafeERC20 for IERC20;

    function _burnHeldDetf(uint256 amount_, IERC20 out_, uint256 minimum_, address to_)
        internal returns (uint256 received_)
    {
        _requireReserveLive();
        (bool found_, uint256 leg_) = Repo._findVaultShareIndex(out_);
        if (!found_) revert Repo.InvalidRoute(address(this), address(out_));
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (!_isBurningAllowed()) {
            received_ = _reserveSwap(s_.reservePool, IERC20(address(this)), out_, amount_, minimum_);
        } else {
            uint256 lp_ = _bptForDetfShares(amount_, false);
            _burnDetf(address(this), amount_);
            (uint256 detfLeg_, uint256[] memory shares_) = _exitReserveProportional(lp_);
            received_ = shares_[leg_];
            shares_[leg_] = 0;
            _custodyBptOnNft(_joinReserveDetfAndShares(detfLeg_, shares_));
        }
        if (received_ < minimum_) revert IStandardExchangeErrors.MinAmountNotMet(minimum_, received_);
        out_.safeTransfer(to_, received_);
    }
}
