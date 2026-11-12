// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4DetfMigrationRecovery as Recovery} from "./interfaces/IUniswapV4DetfMigrationRecovery.sol";

/// @notice Recovery attribution is separate from balances, donation budgets and surrender credit.
library UniswapV4DetfMigrationRecoveryRepo {
    bytes32 internal constant DEFAULT_SLOT =
        bytes32(uint256(keccak256(abi.encode("indexedex.detf.uniswap.v4.migration.recovery"))) - 1);

    struct Storage {
        mapping(address => uint256) inventory;
        uint256 weightedGons;
        mapping(address => mapping(uint256 => Recovery.NftRecovery)) positions;
        uint256 earlierReceiptInternalShares;
    }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage s_) {
        assembly { s_.slot := slot_ }
    }

    function _layoutStruct() internal pure returns (Storage storage) {
        return _layoutStruct(DEFAULT_SLOT);
    }

    /// @dev Revalue only already attributed gons at the source operation's synchronized
    /// divisor. This is neither a new receipt transfer nor another NFT claim.
    function _reconcileWeighted(Storage storage s_, address token_, uint256 divisor_) internal {
        uint256 before_ = s_.inventory[token_];
        uint256 after_ = s_.weightedGons / divisor_;
        if (after_ != before_) {
            s_.inventory[token_] = after_;
            emit Recovery.MigrationRecoveryRevalued(token_, before_, after_, s_.weightedGons, divisor_);
        }
    }

    function _debit(Storage storage s_, address token_, uint256 amount_) internal {
        uint256 available_ = s_.inventory[token_];
        if (amount_ == 0 || amount_ > available_) {
            revert Recovery.RecoveryInventoryInsufficient(token_, amount_, available_);
        }
        s_.inventory[token_] = available_ - amount_;
    }

    function _debit(address token_, uint256 amount_) internal {
        _debit(_layoutStruct(), token_, amount_);
    }
}
