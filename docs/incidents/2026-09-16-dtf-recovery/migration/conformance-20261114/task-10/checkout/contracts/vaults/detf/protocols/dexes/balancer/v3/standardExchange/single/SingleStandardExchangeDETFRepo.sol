// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";

/// @title SingleStandardExchangeDETFRepo
/// @notice Diamond storage for SingleStandardExchangeDETF. Protocol reserve wiring, funded child addresses and fixed epoch clock.
library SingleStandardExchangeDETFRepo {
    error AlreadyInitialized();
    error ReservePoolNotInitialized();
    error UnsupportedRoute(IERC20 tokenIn, IERC20 tokenOut);
    error InvalidRoute(address tokenIn, address tokenOut);
    error ZeroAmount();
    error DeadlineExpired(uint256 deadline);
    error MintingNotAllowed(uint256 syntheticPrice, uint256 mintThreshold);
    error BurningNotAllowed(uint256 syntheticPrice, uint256 burnThreshold);
    error LockDurationTooShort(uint256 lockDuration, uint256 minLockDuration);
    error ResidualInventory(IERC20 token, uint256 amount);
    error ClaimTokenNotConfigured();
    error BondNotMature(uint256 unlockTime);
    error InsufficientReserveBpt(uint256 needed, uint256 available);
    error NotAuthorized(address caller);

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
        IVaultFeeOracleQuery feeOracle;
        IDETFNFTVault bondNftVault;
        IRebasingClaimToken rebasingClaimToken;
        // Phase 2 natural expansion (resolved deploy-time; no post-deploy setter).
        uint256 expansionClosureRatePerSecond;
        uint256 epochAnchor;
        uint256 lastExpansionTimestamp; // last completed eight-hour boundary
    }

    /// @dev Deployment configuration for thresholds, fees and funded rewards.
    struct ThresholdAndFeeInit {
        uint256 mintThreshold;
        uint256 burnThreshold;
        IVaultFeeOracleQuery feeOracle;
        IDETFNFTVault bondNftVault;
        uint256 expansionClosureRatePerSecond;
    }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct_) {
        assembly {
            layoutStruct_.slot := slot_
        }
    }

    function _layoutStruct() internal pure returns (Storage storage) { return _layoutStruct(STORAGE_SLOT); }

    /// @dev Initialize fresh reserve wiring; the first successful bond starts the epoch clock.
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
        s.feeOracle = thresholdsAndFee_.feeOracle;
        s.bondNftVault = thresholdsAndFee_.bondNftVault;
        s.expansionClosureRatePerSecond = thresholdsAndFee_.expansionClosureRatePerSecond;
        s.lastExpansionTimestamp = 0;
    }

    function _setReserveLive() internal {
        Storage storage s = _layoutStruct();
        if (s.isReserveLive) revert AlreadyInitialized();
        s.isReserveLive = true;
        s.epochAnchor = block.timestamp;
        s.lastExpansionTimestamp = block.timestamp;
    }

    function _setRebasingClaimToken(IRebasingClaimToken token_) internal {
        _layoutStruct().rebasingClaimToken = token_;
    }
}
