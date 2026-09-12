// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDETFStandardizedYield, IDETFStakingPreview} from "contracts/interfaces/IDETFStandardizedYield.sol";
import {DETFChildSYRepo} from "contracts/vaults/detf/common/sy/DETFChildSYRepo.sol";
import {SingleStandardExchangeDETFCommon} from "./SingleStandardExchangeDETFCommon.sol";
import {SingleStandardExchangeDETFRepo as Repo} from "./SingleStandardExchangeDETFRepo.sol";

interface ISingleStandardExchangeDETFInfo is IDETFFundedRewards, IDETFStandardizedYield, IDETFStakingPreview {
    event ThresholdsSet(uint256 mintThreshold, uint256 burnThreshold);
    function isReserveLive() external view returns (bool);
    function standardExchangeVault() external view returns (address);
    function standardExchangeVaultShare() external view returns (address);
    function rateTarget() external view returns (address);
    function reservePool() external view returns (address);
    function syntheticPrice() external view returns (uint256);
    function mintThreshold() external view returns (uint256);
    function burnThreshold() external view returns (uint256);
    function isMintingAllowed() external view returns (bool);
    function isBurningAllowed() external view returns (bool);
    function bondNftVault() external view returns (address);
    function rebasingClaimToken() external view returns (address);
    function lastExpansionTimestamp() external view returns (uint256);
    function epochAnchor() external view returns (uint256);
    function expansionClosureRatePerSecond() external view returns (uint256);
    function pendingExpansionDetf() external view returns (uint256);
}

abstract contract SingleStandardExchangeDETFInfoTarget is SingleStandardExchangeDETFCommon, ISingleStandardExchangeDETFInfo {
    function isReserveLive() external view returns (bool) { return Repo._layoutStruct().isReserveLive; }
    function standardExchangeVault() external view returns (address) { return address(Repo._layoutStruct().standardExchangeVault); }
    function standardExchangeVaultShare() external view returns (address) { return address(Repo._layoutStruct().standardExchangeVaultShare); }
    function rateTarget() external view returns (address) { return address(Repo._layoutStruct().rateTarget); }
    function reservePool() external view returns (address) { return Repo._layoutStruct().reservePool; }
    function syntheticPrice() external view returns (uint256) { return _syntheticPrice(); }
    function mintThreshold() external view returns (uint256) { return Repo._layoutStruct().mintThreshold; }
    function burnThreshold() external view returns (uint256) { return Repo._layoutStruct().burnThreshold; }
    function isMintingAllowed() external view returns (bool) { return _isMintingAllowed(); }
    function isBurningAllowed() external view returns (bool) { return _isBurningAllowed(); }
    function bondNftVault() external view returns (address) { return address(Repo._layoutStruct().bondNftVault); }
    function rebasingClaimToken() external view returns (address) { return address(Repo._layoutStruct().rebasingClaimToken); }
    function lastExpansionTimestamp() external view returns (uint256) { return Repo._layoutStruct().lastExpansionTimestamp; }
    function epochAnchor() external view returns (uint256) { return Repo._layoutStruct().epochAnchor; }
    function expansionClosureRatePerSecond() external view returns (uint256) { return Repo._layoutStruct().expansionClosureRatePerSecond; }
    function pendingExpansionDetf() external view returns (uint256) { return _pendingExpansionDetf(); }
    function rawSY() external view returns (address) { return DETFChildSYRepo._layoutStruct().rawSY; }
    function stakingSY() external view returns (address) { return DETFChildSYRepo._layoutStruct().stakingSY; }

    /// @dev Only wired children may compose an already-settled outer operation.
    function synchronizeRewards() external returns (uint256 minted_) {
        if (ReentrancyLockRepo._isLocked()) {
            Repo.Storage storage s_ = Repo._layoutStruct();
            if (msg.sender != address(s_.rebasingClaimToken) && msg.sender != address(s_.bondNftVault)) {
                revert Repo.NotAuthorized(msg.sender);
            }
            return 0;
        }
        ReentrancyLockRepo._lock();
        minted_ = _updateExpansionMintOnRewards();
        ReentrancyLockRepo._unlock();
    }

    function previewStakingGonsPerUnit(IERC20 in_, uint256 amount_) external view returns (uint256) {
        uint256[] memory rewards_ = new uint256[](2);
        rewards_[0] = _pendingExpansionDetf();
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (
            amount_ != 0 && address(in_) != address(this) && address(in_) != address(s_.rebasingClaimToken)
                && _previewPrimaryMint()
        ) {
            rewards_[1] = _splitMintedDetf(_quoteDetfOutForVaultShares(_previewVaultSharesIn(in_, amount_))).inventoryDetf;
        }
        return IStakedDETF(address(s_.rebasingClaimToken)).previewDistributions(rewards_).gonsPerUnit;
    }
}
