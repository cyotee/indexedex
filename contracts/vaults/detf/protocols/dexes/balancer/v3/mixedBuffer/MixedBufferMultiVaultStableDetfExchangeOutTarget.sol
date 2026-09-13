// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {MixedBufferMultiVaultStableDetfCommon} from "./MixedBufferMultiVaultStableDetfCommon.sol";
import {MixedBufferMultiVaultStableDetfRepo as Repo} from "./MixedBufferMultiVaultStableDetfRepo.sol";

/// @notice Primary LP redemption or the same reserve's native swap, selected after epoch settlement.
abstract contract MixedBufferMultiVaultStableDetfExchangeOutTarget is MixedBufferMultiVaultStableDetfCommon {
    using BetterSafeERC20 for IERC20;

    function _burnHeldDetf(uint256 amount_, IERC20 out_, uint256 minimum_, address to_) internal returns (uint256 received_) {
        _requireReserveLive();
        uint256 index_ = _paymentIndex(out_);
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (!_isBurningAllowed()) {
            received_ = _reserveSwap(s_.reservePool, IERC20(address(this)), out_, amount_, minimum_);
        } else {
            uint256 lp_ = _bptForDetfShares(amount_, false);
            _burnDetf(address(this), amount_);
            (uint256 detf_, uint256 buffer_, uint256[] memory shares_) = _exitReserveProportional(lp_);
            if (index_ == s_.bufferIndex) { received_ = buffer_; buffer_ = 0; }
            else {
                for (uint256 i; i < s_.vaultCount; ++i) {
                    if (s_.shareIndexes[i] == index_) { received_ = shares_[i]; shares_[i] = 0; break; }
                }
            }
            _custodyBptOnNft(_joinReserveLegs(detf_, buffer_, shares_));
        }
        if (received_ < minimum_) revert IStandardExchangeErrors.MinAmountNotMet(minimum_, received_);
        out_.safeTransfer(to_, received_);
    }
}
