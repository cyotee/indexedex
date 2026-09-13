// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IMultiVaultWeightedDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfInfo.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDETFStandardizedYield, IDETFStakingPreview} from "contracts/interfaces/IDETFStandardizedYield.sol";
import {DETFChildSYRepo} from "contracts/vaults/detf/common/sy/DETFChildSYRepo.sol";
import {MultiVaultWeightedDetfCommon} from "./MultiVaultWeightedDetfCommon.sol";
import {MultiVaultWeightedDetfRepo as Repo} from "./MultiVaultWeightedDetfRepo.sol";



abstract contract MultiVaultWeightedDetfInfoTarget is MultiVaultWeightedDetfCommon, IMultiVaultWeightedDetfInfo {
    function previewJoinDonatedCapital(IERC20 token_, uint256 amount_) external view returns (uint256) {
        return _previewJoinDonatedCapital(token_, amount_);
    }

    function vaultCount() external view returns (uint256) {
        return Repo._layoutStruct().vaultCount;
    }

    function underlyingVaults() external view returns (address[] memory out_) {
        Repo.Storage storage s = Repo._layoutStruct();
        out_ = new address[](s.vaultCount);
        for (uint256 i; i < s.vaultCount; ++i) {
            out_[i] = address(s.underlyingVaults[i]);
        }
    }

    function vaultShares() external view returns (address[] memory out_) {
        Repo.Storage storage s = Repo._layoutStruct();
        out_ = new address[](s.vaultCount);
        for (uint256 i; i < s.vaultCount; ++i) {
            out_[i] = address(s.vaultShares[i]);
        }
    }

    function weights() external view returns (uint256 weightDetf_, uint256[] memory vaultWeights_) {
        Repo.Storage storage s = Repo._layoutStruct();
        weightDetf_ = s.weightDetf;
        vaultWeights_ = new uint256[](s.vaultCount);
        for (uint256 i; i < s.vaultCount; ++i) {
            vaultWeights_[i] = s.vaultWeights[i];
        }
    }

    function rateProvider(uint256 i) external view returns (address) {
        return address(Repo._layoutStruct().rateProviders[i]);
    }

    function rateAsset(uint256 i) external view returns (address) {
        return address(Repo._layoutStruct().rateAssets[i]);
    }

    function rateAssets() external view returns (address[] memory out_) {
        Repo.Storage storage s = Repo._layoutStruct();
        out_ = new address[](s.vaultCount);
        for (uint256 i; i < s.vaultCount; ++i) {
            out_[i] = address(s.rateAssets[i]);
        }
    }

    function isReserveLive() external view returns (bool) { return Repo._layoutStruct().isReserveLive; }
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
            (bool found_, uint256 leg_) = Repo._findVaultShareIndex(in_);
            if (!found_) revert Repo.InvalidRoute(address(in_), address(this));
            rewards_[1] = _splitMintedDetf(_quoteDetfOutForVaultShares(leg_, amount_)).inventoryDetf;
        }
        return IStakedDETF(address(s_.rebasingClaimToken)).previewDistributions(rewards_).gonsPerUnit;
    }
}
