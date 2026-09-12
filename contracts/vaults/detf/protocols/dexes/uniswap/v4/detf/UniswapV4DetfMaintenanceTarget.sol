// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {UniswapV4DetfRepo as Repo} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {UniswapV4DetfTarget} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol";

/// @notice Maintenance entrypoints for the universal DETF diamond.
abstract contract UniswapV4DetfMaintenanceTarget is UniswapV4DetfTarget {
    /// @notice Settle completed epochs before a staking or NFT participation change.
    /// @dev Outer DETF routes settle first. Only their two wired children may compose
    ///      this no-op callback while the DETF transaction lock is held.
    ///      Record remaining custody after settlement so later pretransfer claims
    ///      cannot consume already observed idle inventory. This does not join LP.
    function synchronizeRewards() external returns (uint256 minted_) {
        if (ReentrancyLockRepo._isLocked()) {
            Repo.Storage storage s_ = Repo._layoutStruct();
            if (msg.sender != address(s_.rebasingClaimToken) && msg.sender != address(s_.bondNftVault)) {
                revert Repo.NotAuthorized(msg.sender);
            }
            return 0;
        }
        ReentrancyLockRepo._lock();
        minted_ = _realizeExpansionIfNeeded();
        _syncAllExpectedHoldReserves();
        ReentrancyLockRepo._unlock();
    }

    /// @notice Forwards a reserve donation to the bond NFT's canonical donation entrypoint.
    function donate(IERC20 token, uint256 amount, bool pretransferred) external {
        _entryDonate(token, amount, pretransferred);
    }

    /// @notice Joins donated capital on behalf of the authorized bond NFT vault.
    function joinDonatedCapital(IERC20 token, uint256 amount, uint256 deadline) external returns (uint256 lpOut) {
        return _entryJoinDonatedCapital(token, amount, deadline);
    }

    /// @notice Updates reserve accounting after an authorized bond NFT donation.
    function notifyReserveDonated() external {
        _entryNotifyReserveDonated();
    }

    /// @notice Joins residual diamond inventory into the live reserve under the unassigned-LP policy.
    function sweepDust() external {
        _entrySweepDust();
    }

    /// @notice Executes one atomic dust-sweep attempt; only the diamond itself may call.
    function sweepDustAtomic() external {
        _entrySweepDustAtomic();
    }

    /// @notice Wraps residual pair tokens through their SE vault; only the diamond itself may call.
    function sweepPairToShare(address se_, address pair_, uint256 amount_) external returns (uint256 shares_) {
        return _entrySweepPairToShare(se_, pair_, amount_);
    }
}
