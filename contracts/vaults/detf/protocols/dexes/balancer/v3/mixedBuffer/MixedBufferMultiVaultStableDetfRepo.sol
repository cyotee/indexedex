// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @title MixedBufferMultiVaultStableDetfRepo
/// @notice Diamond storage for MixedBuffer multi-vault stable DETF. Role names only.
library MixedBufferMultiVaultStableDetfRepo {
    error AlreadyInitialized();
    error ReservePoolNotInitialized();
    error InvalidRoute(address tokenIn, address tokenOut);
    error InvalidVaultCount(uint256 n);
    error DuplicateVault(address vault);
    error BufferTokenNotInVault(address bufferToken, address vault);
    error InvalidAmplification(uint256 amp);
    error InvalidRateConfig(uint256 legIndex);
    error VaultShareNotConfigured(address token);
    error ZeroAmount();
    error DeadlineExpired(uint256 deadline);
    error MintingNotAllowed(uint256 syntheticPrice, uint256 mintThreshold);
    error BurningNotAllowed(uint256 syntheticPrice, uint256 burnThreshold);
    error LockDurationTooShort(uint256 lockDuration, uint256 minLockDuration);
    error ResidualInventory(IERC20 token, uint256 amount);
    error NotLive();
    error AlreadyLive();
    error ClaimTokenNotConfigured();
    error InvalidBootstrapAmounts();
    error ZeroBufferToken();
    error BondNotMature(uint256 unlockTime);
    error InsufficientReserveBpt(uint256 needed, uint256 available);
    error NotAuthorized(address caller);

    uint256 internal constant MAX_VAULTS = 3;
    uint256 internal constant MIN_VAULTS = 1;

    bytes32 internal constant STORAGE_SLOT =
        keccak256("vault.detf.composed.stable.mixedBuffer.mixed-buffer-multi-vault-stable-detf.repo");

    struct Storage {
        bool isReserveLive;
        uint8 vaultCount;
        IStandardExchange[3] underlyingVaults;
        IERC20[3] vaultShares;
        IRateProvider[3] vaultShareRateProviders;
        uint256[3] shareIndexes;
        IERC20 bufferToken;
        uint256 bufferIndex;
        uint256 detfIndex;
        address reservePool;
        IERC20 reserveBpt;
        uint256 amplificationParameter;
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
        IVaultFeeOracleQuery feeOracle;
        IDETFNFTVault bondNftVault;
        uint256 detfNftId;
        uint256 feeRecipientNftId;
        IRebasingClaimToken rebasingClaimToken;
        // Phase 2 natural expansion (resolved deploy-time; no post-deploy setter).
        uint256 expansionClosureRatePerSecond;
        uint256 expansionCatchUpMaxSeconds;
        uint256 expansionCatchUpCapBps;
        uint256 lastExpansionTimestamp; // seeded at live transition or first accrual
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct_) {
        bytes32 slot_ = STORAGE_SLOT;
        assembly {
            layoutStruct_.slot := slot_
        }
    }

    struct InitParams {
        uint8 vaultCount;
        IStandardExchange[] vaults;
        IERC20[] shares;
        IRateProvider[] vaultShareRateProviders;
        IERC20 bufferToken;
        uint256 bufferIndex;
        uint256 detfIndex;
        uint256[] shareIndexes;
        address reservePool;
        uint256 amplificationParameter;
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
        IVaultFeeOracleQuery feeOracle;
        IDETFNFTVault bondNftVault;
        uint256 detfNftId;
        IRebasingClaimToken rebasingClaimToken;
        uint256 expansionClosureRatePerSecond;
        uint256 expansionCatchUpMaxSeconds;
        uint256 expansionCatchUpCapBps;
    }

    function _initialize(InitParams memory p) internal {
        Storage storage s = _layoutStruct();
        if (s.vaultCount != 0) revert AlreadyInitialized();
        uint8 vaultCount_ = p.vaultCount;
        if (vaultCount_ < MIN_VAULTS || vaultCount_ > MAX_VAULTS) revert InvalidVaultCount(vaultCount_);
        if (
            p.vaults.length != vaultCount_ || p.shares.length != vaultCount_
                || p.vaultShareRateProviders.length != vaultCount_ || p.shareIndexes.length != vaultCount_
        ) {
            revert InvalidVaultCount(vaultCount_);
        }
        if (address(p.bufferToken) == address(0)) revert ZeroBufferToken();

        s.isReserveLive = false;
        s.vaultCount = vaultCount_;
        s.bufferToken = p.bufferToken;
        s.bufferIndex = p.bufferIndex;
        s.detfIndex = p.detfIndex;
        s.reservePool = p.reservePool;
        s.reserveBpt = IERC20(p.reservePool);
        s.amplificationParameter = p.amplificationParameter;
        s.mintThreshold = p.mintThreshold;
        s.burnThreshold = p.burnThreshold;
        s.thresholdMode = p.thresholdMode;
        s.feeOracle = p.feeOracle;
        s.bondNftVault = p.bondNftVault;
        s.detfNftId = p.detfNftId;
        s.rebasingClaimToken = p.rebasingClaimToken;
        s.expansionClosureRatePerSecond = p.expansionClosureRatePerSecond;
        s.expansionCatchUpMaxSeconds = p.expansionCatchUpMaxSeconds;
        s.expansionCatchUpCapBps = p.expansionCatchUpCapBps;
        s.lastExpansionTimestamp = 0;

        for (uint256 i; i < vaultCount_; ++i) {
            s.underlyingVaults[i] = p.vaults[i];
            s.vaultShares[i] = p.shares[i];
            s.vaultShareRateProviders[i] = p.vaultShareRateProviders[i];
            s.shareIndexes[i] = p.shareIndexes[i];
        }
    }

    function _setReserveLive() internal {
        Storage storage s = _layoutStruct();
        s.isReserveLive = true;
        // Seed expansion clock at live so accrual window starts from bootstrap, not deploy.
        if (s.lastExpansionTimestamp == 0) {
            s.lastExpansionTimestamp = block.timestamp;
        }
    }

    function _setRebasingClaimToken(IRebasingClaimToken token_) internal {
        _layoutStruct().rebasingClaimToken = token_;
    }

    function _findVaultShareIndex(IERC20 token_) internal view returns (bool found_, uint256 legIndex_) {
        Storage storage s = _layoutStruct();
        for (uint256 i; i < s.vaultCount; ++i) {
            if (address(s.vaultShares[i]) == address(token_)) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    function _isBufferToken(IERC20 token_) internal view returns (bool) {
        return address(token_) == address(_layoutStruct().bufferToken);
    }
}
