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
        uint256 protocolNftId;
        uint256 feeRecipientNftId;
    }

    /// @dev Packed trailing threshold + fee/NFT wiring to avoid stack-too-deep in `_initialize`.
    struct ThresholdAndFeeInit {
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
        IVaultFeeOracleQuery feeOracle;
        IDETFNFTVault bondNftVault;
        uint256 protocolNftId;
        uint256 feeRecipientNftId;
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
        s.protocolNftId = thresholdsAndFee_.protocolNftId;
        s.feeRecipientNftId = thresholdsAndFee_.feeRecipientNftId;
    }

    function _setReserveLive() internal {
        _layoutStruct().isReserveLive = true;
    }
}
