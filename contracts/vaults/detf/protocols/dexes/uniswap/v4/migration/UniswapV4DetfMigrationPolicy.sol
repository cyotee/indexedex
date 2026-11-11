// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {DETFChildSYRepo} from "contracts/vaults/detf/common/sy/DETFChildSYRepo.sol";
import {UniswapV4DetfRepo as ParentRepo} from "../detf/UniswapV4DetfRepo.sol";
import {UniswapV4DetfCommon} from "../detf/UniswapV4DetfCommon.sol";
import {IUniswapV4DetfMigrationAccounting as Accounting} from "./interfaces/IUniswapV4DetfMigration.sol";
import {UniswapV4DetfMigrationRepo as Repo} from "./UniswapV4DetfMigrationRepo.sol";

/// @notice Shared Migration policy for every parent role; ordinary facets retain their defaults.
abstract contract UniswapV4DetfMigrationPolicy is UniswapV4DetfCommon {
    using AddressSetRepo for AddressSet;

    /// @dev Fixed hook inventory only. Donation budgets and unsolicited inventory are floors,
    /// never inferred as this operation's unused payment.
    function _budgetTokens() internal view returns (address[] memory tokens_) {
        address[] memory pairs_ = _hook().tokens();
        address[] memory exchanges_ = ParentRepo._layoutStruct().hookStandardExchanges._values();
        tokens_ = new address[](pairs_.length + exchanges_.length + 1);
        for (uint256 i_; i_ < pairs_.length; ++i_) tokens_[i_] = pairs_[i_];
        for (uint256 i_; i_ < exchanges_.length; ++i_) tokens_[pairs_.length + i_] = exchanges_[i_];
        tokens_[tokens_.length - 1] = ParentRepo._layoutStruct().hook;
    }

    function _beginBudget() internal {
        Repo.Storage storage m_ = Repo._layoutStruct();
        if (m_.budgetOpen) revert ParentRepo.NotAuthorized(msg.sender);
        address[] memory tokens_ = _budgetTokens();
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            address token_ = tokens_[i_];
            m_.operationFloor[token_] = IERC20(token_).balanceOf(address(this)) - m_.residualInventory[token_];
        }
        m_.budgetOpen = true;
    }

    function _endBudget() internal {
        Repo.Storage storage m_ = Repo._layoutStruct();
        address[] memory tokens_ = _budgetTokens();
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            address token_ = tokens_[i_];
            m_.residualInventory[token_] = IERC20(token_).balanceOf(address(this)) - m_.operationFloor[token_];
            delete m_.operationFloor[token_];
        }
        m_.budgetOpen = false;
    }

    function _residualBalance(address token_) internal view virtual override returns (uint256) {
        Repo.Storage storage m_ = Repo._layoutStruct();
        if (!m_.budgetOpen) return m_.residualInventory[token_];
        uint256 held_ = IERC20(token_).balanceOf(address(this));
        uint256 floor_ = m_.operationFloor[token_];
        return held_ > floor_ ? held_ - floor_ : 0;
    }

    function _sweepDustBody() internal virtual override {
        bool standalone_ = !Repo._layoutStruct().budgetOpen;
        if (standalone_) _beginBudget();
        super._sweepDustBody();
        if (standalone_) _endBudget();
    }
    function _children() internal view returns (address[5] memory children_) {
        ParentRepo.Storage storage s_ = ParentRepo._layoutStruct();
        DETFChildSYRepo.Storage storage sy_ = DETFChildSYRepo._layoutStruct();
        return [address(s_.bondNftVault), address(s_.rebasingClaimToken), sy_.rawSY, sy_.stakingSY,
            Repo._layoutStruct().rewardToken];
    }

    /// @dev Only the fixed caller may account for a busy child. Receipt synchronization may
    /// originate in the fixed SY acquisition/payment or RT redemption graph.
    function _admit(bool synchronizing_, bool bondDonation_) internal view {
        address[5] memory children_ = _children();
        for (uint256 i_; i_ < children_.length; ++i_) {
            address child_ = children_[i_];
            if (child_ == address(0)) continue;
            uint8 phase_ = Accounting(child_).migrationAccountingPhase();
            if (phase_ == uint8(Accounting.AccountingPhase.Idle)) continue;
            if (child_ == msg.sender) {
                if (synchronizing_ && phase_ == uint8(Accounting.AccountingPhase.Synchronizing)) continue;
                if (bondDonation_ && i_ == 0 && phase_ == uint8(Accounting.AccountingPhase.Accounting)) continue;
                if (!synchronizing_ && (i_ == 2 || i_ == 3)
                    && (phase_ == uint8(Accounting.AccountingPhase.Acquiring)
                        || phase_ == uint8(Accounting.AccountingPhase.Paying))) continue;
            }
            if (synchronizing_ && msg.sender == children_[1]) {
                if ((i_ == 2 || i_ == 3) && (phase_ == uint8(Accounting.AccountingPhase.Acquiring)
                    || phase_ == uint8(Accounting.AccountingPhase.Paying))) continue;
                if (i_ == 4 && phase_ == uint8(Accounting.AccountingPhase.Accounting)) continue;
            }
            revert Accounting.MigrationAccountingBusy(child_, phase_);
        }
    }

    function _requireIdleChildren() internal view {
        address[5] memory children_ = _children();
        for (uint256 i_; i_ < children_.length; ++i_) {
            uint8 phase_ = Accounting(children_[i_]).migrationAccountingPhase();
            if (phase_ != 0) revert Accounting.MigrationAccountingBusy(children_[i_], phase_);
        }
    }

    function _emptyParticipation() internal view returns (bool) {
        address receipt_ = address(ParentRepo._layoutStruct().rebasingClaimToken);
        if (receipt_ == address(0)) return true;
        IStakedDETF.StakingState memory state_ = IStakedDETF(receipt_).stakingState();
        return state_.totalGons == 0 && state_.feeWeight == 0 && state_.creatorWeight == 0;
    }

    function _pendingExpansionDetf() internal view virtual override returns (uint256) {
        return _emptyParticipation() ? 0 : super._pendingExpansionDetf();
    }

    function _realizeExpansionIfNeeded() internal virtual override returns (uint256) {
        if (_emptyParticipation()) {
            ParentRepo.Storage storage s_ = ParentRepo._layoutStruct();
            if (s_.isReserveLive) s_.lastExpansionTimestamp = block.timestamp;
            return 0;
        }
        return super._realizeExpansionIfNeeded();
    }

    function _isMintingAllowedToken(IERC20 token_) internal view virtual override returns (bool) {
        return Repo._layoutStruct().activated && super._isMintingAllowedToken(token_);
    }
}
