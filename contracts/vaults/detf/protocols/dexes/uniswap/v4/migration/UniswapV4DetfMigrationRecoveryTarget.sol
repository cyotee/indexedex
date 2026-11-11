// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IUniswapV4DetfMigration as Migration} from "./interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from "./interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {UniswapV4DetfMigrationRecoveryRepo as Repo} from "./UniswapV4DetfMigrationRecoveryRepo.sol";
import {UniswapV4DetfMigrationRepo as MigrationRepo} from "./UniswapV4DetfMigrationRepo.sol";
import {UniswapV4DetfRepo as ParentRepo} from "../detf/UniswapV4DetfRepo.sol";
import {UniswapV4DetfMigrationPolicy} from "./UniswapV4DetfMigrationPolicy.sol";
import {MigrationLegacyNftLib as NftLib} from "./legacy/MigrationLegacyNftLib.sol";
import {MigrationLegacyRecoveryLib as Legacy} from "./legacy/MigrationLegacyRecoveryLib.sol";

/// @notice Selected recovery remains available after activation and follows actual Crane ownership.
contract UniswapV4DetfMigrationRecoveryTarget is UniswapV4DetfMigrationPolicy, Recovery {
    using AddressSetRepo for AddressSet;

    function migrationRecoveryInventory(address token_) external view returns (uint256) {
        return Repo._layoutStruct().inventory[token_];
    }

    function migrationRecoveryGons() external view returns (uint256) {
        return Repo._layoutStruct().weightedGons;
    }

    function migrationNftRecovery(address collection_, uint256 tokenId_) external view returns (NftRecovery memory) {
        return Repo._layoutStruct().positions[collection_][tokenId_];
    }

    function recoverMigrationNfts(Step[] calldata steps_, uint256 deadline_) external nonReentrant {
        MultiStepOwnableRepo._onlyOwner();
        _requireIdleChildren();
        NftLib.requireSource(NftLib.WEIGHTED);
        _requireActive(deadline_, steps_.length);
        for (uint256 i_; i_ < steps_.length; ++i_) {
            Step calldata step_ = steps_[i_];
            if (step_.stage <= Stage.WeightedRewards) {
                if (step_.amount != 0 || step_.minimum != 0) revert InvalidRecoveryStep();
                Legacy.claimWeighted(step_.tokenId, step_.stage);
            } else if (step_.stage == Stage.EarlierClaim || step_.stage == Stage.EarlierSale) {
                if (step_.amount != 0) revert InvalidRecoveryStep();
                if (step_.stage == Stage.EarlierClaim) {
                    if (step_.minimum != 0) revert InvalidRecoveryStep();
                    Legacy.claimEarlier(step_.tokenId);
                } else Legacy.sellEarlier(step_.tokenId, step_.minimum);
            } else {
                if (step_.tokenId != 0) revert InvalidRecoveryStep();
                if (step_.stage == Stage.WeightedUnstake) {
                    if (step_.minimum != 0) revert InvalidRecoveryStep();
                    Legacy.unstakeWeighted(step_.amount, deadline_);
                } else if (step_.stage == Stage.WeightedConvert) {
                    Legacy.convertWeighted(step_.amount, step_.minimum, deadline_);
                } else _donateRecovery(step_.amount, step_.minimum);
            }
        }
        _syncAllExpectedHoldReserves();
    }

    function _donateRecovery(uint256 amount_, uint256 minimum_) private {
        _requireNotDisabled();
        _requireReserveLive();
        ParentRepo.Storage storage s_ = ParentRepo._layoutStruct();
        address token_ = Legacy.DTF;
        if (token_ == address(this) || !s_.donateTable.tokens._contains(token_)
            || (!s_.hookPairTokens._contains(token_) && !s_.hookStandardExchanges._contains(token_))) {
            revert Migration.InvalidGenesisLeg(token_);
        }
        Repo._debit(token_, amount_);
        uint256 lpBefore_ = IERC20(s_.hook).balanceOf(_bondLpHolder());
        _beginBudget();
        // This transfers only selected recovered capital into the existing reserve residual domain.
        // All other recovery inventory, older donation budgets and unsolicited balances stay floors.
        MigrationRepo._layoutStruct().operationFloor[token_] -= amount_;
        _sweepDustBody();
        _endBudget();
        uint256 lpOut_ = IERC20(s_.hook).balanceOf(_bondLpHolder()) - lpBefore_;
        if (lpOut_ == 0 || lpOut_ < minimum_) revert IStandardExchangeErrors.MinAmountNotMet(minimum_, lpOut_);
        emit MigrationRecoveryDonated(token_, amount_, lpOut_);
    }
}
