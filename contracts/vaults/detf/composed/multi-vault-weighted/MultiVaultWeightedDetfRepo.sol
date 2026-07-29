// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {ThresholdMode} from "contracts/vaults/detf/core/DETFThresholdPolicy.sol";

/// @title MultiVaultWeightedDetfRepo
/// @notice Diamond storage for MultiVaultWeightedDetf. Role names only.
library MultiVaultWeightedDetfRepo {
    error AlreadyInitialized();
    error ReservePoolNotInitialized();
    error InvalidRoute(address tokenIn, address tokenOut);
    error InvalidVaultCount(uint256 n);
    error InvalidWeights();
    error InvalidRateConfig(uint256 legIndex);
    error DuplicateVault(address vault);
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

    uint256 internal constant MAX_VAULTS = 7;

    bytes32 internal constant STORAGE_SLOT =
        keccak256("vault.detf.composed.multi-vault-weighted.multi-vault-weighted-detf.repo");

    struct Storage {
        bool isReserveLive;
        uint8 vaultCount;
        IStandardExchangeProxy[7] underlyingVaults;
        IERC20[7] vaultShares;
        IRateProvider[7] rateProviders;
        IERC20[7] rateAssets;
        uint256[7] vaultWeights;
        uint256[7] vaultShareIndexes;
        uint256 weightDetf;
        uint256 detfIndex;
        address reservePool;
        IERC20 reserveBpt;
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
        IVaultFeeOracleQuery feeOracle;
        IDETFNFTVault bondNftVault;
        uint256 protocolNftId;
        uint256 feeRecipientNftId;
        IRebasingClaimToken rebasingClaimToken;
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct_) {
        bytes32 slot_ = STORAGE_SLOT;
        assembly {
            layoutStruct_.slot := slot_
        }
    }

    struct InitParams {
        uint8 vaultCount;
        IStandardExchangeProxy[] vaults;
        IERC20[] shares;
        IRateProvider[] rateProviders;
        IERC20[] rateAssets;
        uint256 weightDetf;
        uint256[] vaultWeights;
        uint256 detfIndex;
        uint256[] vaultShareIndexes;
        address reservePool;
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
        IVaultFeeOracleQuery feeOracle;
        IDETFNFTVault bondNftVault;
        uint256 protocolNftId;
        IRebasingClaimToken rebasingClaimToken;
    }

    function _initialize(InitParams memory p) internal {
        Storage storage s = _layoutStruct();
        if (s.vaultCount != 0) revert AlreadyInitialized();
        uint8 vaultCount_ = p.vaultCount;
        if (vaultCount_ == 0 || vaultCount_ > MAX_VAULTS) revert InvalidVaultCount(vaultCount_);
        if (p.vaults.length != vaultCount_ || p.shares.length != vaultCount_) revert InvalidVaultCount(vaultCount_);
        if (p.vaultWeights.length != vaultCount_ || p.vaultShareIndexes.length != vaultCount_) {
            revert InvalidWeights();
        }

        s.isReserveLive = false;
        s.vaultCount = vaultCount_;
        s.weightDetf = p.weightDetf;
        s.detfIndex = p.detfIndex;
        s.reservePool = p.reservePool;
        s.reserveBpt = IERC20(p.reservePool);
        s.mintThreshold = p.mintThreshold;
        s.burnThreshold = p.burnThreshold;
        s.thresholdMode = p.thresholdMode;
        s.feeOracle = p.feeOracle;
        s.bondNftVault = p.bondNftVault;
        s.protocolNftId = p.protocolNftId;
        s.rebasingClaimToken = p.rebasingClaimToken;

        for (uint256 i; i < vaultCount_; ++i) {
            s.underlyingVaults[i] = p.vaults[i];
            s.vaultShares[i] = p.shares[i];
            s.rateProviders[i] = p.rateProviders[i];
            s.rateAssets[i] = p.rateAssets[i];
            s.vaultWeights[i] = p.vaultWeights[i];
            s.vaultShareIndexes[i] = p.vaultShareIndexes[i];
        }
    }

    function _setReserveLive() internal {
        _layoutStruct().isReserveLive = true;
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

    function _findRateAssetLeg(IERC20 rateAsset_) internal view returns (bool found_, uint256 legIndex_) {
        Storage storage s = _layoutStruct();
        for (uint256 i; i < s.vaultCount; ++i) {
            if (address(s.rateAssets[i]) != address(0) && address(s.rateAssets[i]) == address(rateAsset_)) {
                return (true, i);
            }
        }
        return (false, 0);
    }
}
