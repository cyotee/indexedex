// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {ThresholdMode} from "contracts/vaults/detf/core/DETFThresholdPolicy.sol";

/// @title SingleStandardExchangeDETFRepo
/// @notice Diamond storage for SingleStandardExchangeDETF. Role names only — no product tickers.
library SingleStandardExchangeDETFRepo {
    error AlreadyInitialized();
    error ReservePoolNotInitialized();
    error UnsupportedRoute(IERC20 tokenIn, IERC20 tokenOut);
    error ZeroAmount();
    error DeadlineExpired(uint256 deadline);
    error MintingNotAllowed(uint256 syntheticPrice, uint256 mintThreshold);
    error BurningNotAllowed(uint256 syntheticPrice, uint256 burnThreshold);
    error LockDurationTooShort(uint256 lockDuration, uint256 minLockDuration);
    error ResidualInventory(IERC20 token, uint256 amount);

    bytes32 internal constant STORAGE_SLOT =
        keccak256("vault.detf.standardExchange.single.single-standard-exchange-detf.repo");

    struct Storage {
        bool isReserveLive;
        IStandardExchangeProxy standardExchangeVault;
        IERC20 standardExchangeVaultShare;
        IERC20 rateTarget;
        IRateProvider vaultRateProvider;
        address reservePool;
        IERC20 reserveBpt;
        uint256 detfIndex;
        uint256 vaultShareIndex;
        uint256 detfWeight;
        uint256 vaultShareWeight;
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
        IVaultFeeOracleQuery feeOracle;
        IDETFNFTVault bondNftVault;
        uint256 detfNftId;
        uint256 feeRecipientNftId;
        // Phase 2 natural expansion (resolved deploy-time; no post-deploy setter).
        uint256 expansionClosureRatePerSecond;
        uint256 expansionCatchUpMaxSeconds;
        uint256 expansionCatchUpCapBps;
        uint256 lastExpansionTimestamp; // seeded at live transition or first accrual
    }

    /// @dev Packed trailing threshold + fee/NFT + expansion wiring to avoid stack-too-deep in `_initialize`.
    struct ThresholdAndFeeInit {
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
        IVaultFeeOracleQuery feeOracle;
        IDETFNFTVault bondNftVault;
        uint256 detfNftId;
        uint256 feeRecipientNftId;
        uint256 expansionClosureRatePerSecond;
        uint256 expansionCatchUpMaxSeconds;
        uint256 expansionCatchUpCapBps;
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct_) {
        bytes32 slot_ = STORAGE_SLOT;
        assembly {
            layoutStruct_.slot := slot_
        }
    }

    /// @dev Core wiring args + `ThresholdAndFeeInit` (mint/burn/mode + feeOracle + NFT ids).
    function _initialize(
        IStandardExchangeProxy seVault_,
        IERC20 seShare_,
        IERC20 rateTarget_,
        IRateProvider vaultRateProvider_,
        address reservePool_,
        uint256 detfIndex_,
        uint256 vaultShareIndex_,
        uint256 detfWeight_,
        uint256 vaultShareWeight_,
        ThresholdAndFeeInit memory thresholdsAndFee_
    ) internal {
        Storage storage s = _layoutStruct();
        if (address(s.standardExchangeVault) != address(0)) revert AlreadyInitialized();

        s.isReserveLive = false;
        s.standardExchangeVault = seVault_;
        s.standardExchangeVaultShare = seShare_;
        s.rateTarget = rateTarget_;
        s.vaultRateProvider = vaultRateProvider_;
        s.reservePool = reservePool_;
        s.reserveBpt = IERC20(reservePool_);
        s.detfIndex = detfIndex_;
        s.vaultShareIndex = vaultShareIndex_;
        s.detfWeight = detfWeight_;
        s.vaultShareWeight = vaultShareWeight_;
        s.mintThreshold = thresholdsAndFee_.mintThreshold;
        s.burnThreshold = thresholdsAndFee_.burnThreshold;
        s.thresholdMode = thresholdsAndFee_.thresholdMode;
        s.feeOracle = thresholdsAndFee_.feeOracle;
        s.bondNftVault = thresholdsAndFee_.bondNftVault;
        s.detfNftId = thresholdsAndFee_.detfNftId;
        s.feeRecipientNftId = thresholdsAndFee_.feeRecipientNftId;
        s.expansionClosureRatePerSecond = thresholdsAndFee_.expansionClosureRatePerSecond;
        s.expansionCatchUpMaxSeconds = thresholdsAndFee_.expansionCatchUpMaxSeconds;
        s.expansionCatchUpCapBps = thresholdsAndFee_.expansionCatchUpCapBps;
        s.lastExpansionTimestamp = 0;
    }

    function _setReserveLive() internal {
        Storage storage s = _layoutStruct();
        s.isReserveLive = true;
        // Seed expansion clock at live so accrual window starts from first-bond, not deploy.
        if (s.lastExpansionTimestamp == 0) {
            s.lastExpansionTimestamp = block.timestamp;
        }
    }
}
