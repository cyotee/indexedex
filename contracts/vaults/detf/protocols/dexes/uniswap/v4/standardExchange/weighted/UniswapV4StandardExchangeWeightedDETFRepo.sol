// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @title UniswapV4StandardExchangeWeightedDETFRepo
/// @notice Diamond storage for Uni V4 Weighted SE Buffer DETF. Role names only. No rateAsset.
library UniswapV4StandardExchangeWeightedDETFRepo {
    error AlreadyInitialized();
    error ReserveNotLive();
    error AlreadyLive();
    error InvalidRoute(IERC20 tokenIn, IERC20 tokenOut);
    error ZeroAmount();
    error DeadlineExpired(uint256 deadline);
    error MintingNotAllowed(uint256 syntheticPrice, uint256 mintThreshold);
    error BurningNotAllowed(uint256 syntheticPrice, uint256 burnThreshold);
    error LockDurationTooShort(uint256 lockDuration, uint256 minLockDuration);
    error EmptyProtocolLp();
    error FirstBondBelowMinimumLiquidity();
    error FirstBondRequiresAllExternalPairs();
    error LaterBondSingleExternalOnly();
    error BondNotMature(uint256 unlockTime);
    error NotSingleAssetEligible();
    error SlippageExceeded(uint256 minOut, uint256 actual);
    error ClaimTokenNotConfigured();
    error NotAuthorized(address caller);
    error RedepositFailed();
    error InvalidCapitalToken();
    error InvalidPair();

    bytes32 internal constant STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256("vault.detf.uniswap.v4.se.weighted.repo")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @dev Max n = 8 (DETF + 7 externals). Fixed arrays avoid dynamic storage pain.
    uint8 internal constant MAX_N = 8;
    uint8 internal constant MAX_M = 7;

    struct Storage {
        bool isReserveLive;
        uint8 n; // = m + 1
        uint8 m; // external pairs
        uint8 detfBindingIndex;
        // Product-order arrays (length m)
        IERC20[MAX_M] pairTokens;
        IStandardExchangeProxy[MAX_M] standardExchanges;
        IERC20[MAX_M] vaultShares;
        address[MAX_M] rateProviders;
        uint256[MAX_M] creationPairPerDetfWad;
        uint8[MAX_M] pairBindingIndex; // product i → binding j
        // Binding-order weights (length n)
        uint256[MAX_N] weights;
        address reserveHook;
        IPoolManager poolManager;
        IVaultFeeOracleQuery feeOracle;
        IDETFNFTVault bondNftVault;
        IRebasingClaimToken rebasingClaimToken;
        uint256 detfNftId;
        uint256 feeRecipientNftId;
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
        uint256 expansionEpochLength;
        uint256 expansionClosureRatePerYearWad;
        uint256 expansionMaxCatchUpEpochs;
        uint256 lastExpansionTimestamp;
        uint256 userBondedLp;
        /// @dev Single capitalToken per bond tokenId (maturity close pays only this).
        mapping(uint256 tokenId => address) capitalTokenOf;
    }

    struct CoreInit {
        uint8 n;
        uint8 m;
        uint8 detfBindingIndex;
        IERC20[] pairTokens; // length m
        IStandardExchangeProxy[] standardExchanges;
        IERC20[] vaultShares;
        address[] rateProviders;
        uint256[] creationPairPerDetfWad;
        uint8[] pairBindingIndex;
        uint256[] weights; // length n binding
        address reserveHook;
        IPoolManager poolManager;
        IVaultFeeOracleQuery feeOracle;
        IDETFNFTVault bondNftVault;
        IRebasingClaimToken rebasingClaimToken;
        uint256 detfNftId;
        uint256 feeRecipientNftId;
    }

    struct PolicyInit {
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
        uint256 expansionEpochLength;
        uint256 expansionClosureRatePerYearWad;
        uint256 expansionMaxCatchUpEpochs;
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct_) {
        bytes32 slot_ = STORAGE_SLOT;
        assembly {
            layoutStruct_.slot := slot_
        }
    }

    function _initializeCore(CoreInit memory p_) internal {
        Storage storage s = _layoutStruct();
        if (s.n != 0) revert AlreadyInitialized();
        if (p_.m == 0 || p_.m > MAX_M || p_.n != p_.m + 1 || p_.n > MAX_N) {
            revert InvalidRoute(IERC20(address(0)), IERC20(address(0)));
        }
        s.isReserveLive = false;
        s.n = p_.n;
        s.m = p_.m;
        s.detfBindingIndex = p_.detfBindingIndex;
        for (uint256 i; i < p_.m; ++i) {
            s.pairTokens[i] = p_.pairTokens[i];
            s.standardExchanges[i] = p_.standardExchanges[i];
            s.vaultShares[i] = p_.vaultShares[i];
            s.rateProviders[i] = p_.rateProviders[i];
            s.creationPairPerDetfWad[i] = p_.creationPairPerDetfWad[i];
            s.pairBindingIndex[i] = p_.pairBindingIndex[i];
        }
        for (uint256 j; j < p_.n; ++j) {
            s.weights[j] = p_.weights[j];
        }
        s.reserveHook = p_.reserveHook;
        s.poolManager = p_.poolManager;
        s.feeOracle = p_.feeOracle;
        s.bondNftVault = p_.bondNftVault;
        s.rebasingClaimToken = p_.rebasingClaimToken;
        s.detfNftId = p_.detfNftId;
        s.feeRecipientNftId = p_.feeRecipientNftId;
        s.lastExpansionTimestamp = 0;
        s.userBondedLp = 0;
    }

    function _initializePolicy(PolicyInit memory p_) internal {
        Storage storage s = _layoutStruct();
        s.mintThreshold = p_.mintThreshold;
        s.burnThreshold = p_.burnThreshold;
        s.thresholdMode = p_.thresholdMode;
        s.expansionEpochLength = p_.expansionEpochLength;
        s.expansionClosureRatePerYearWad = p_.expansionClosureRatePerYearWad;
        s.expansionMaxCatchUpEpochs = p_.expansionMaxCatchUpEpochs;
    }

    function _setReserveLive() internal {
        _layoutStruct().isReserveLive = true;
    }

    function _addUserBondedLp(uint256 amount_) internal {
        _layoutStruct().userBondedLp += amount_;
    }

    function _subUserBondedLp(uint256 amount_) internal {
        Storage storage s = _layoutStruct();
        if (amount_ > s.userBondedLp) {
            s.userBondedLp = 0;
        } else {
            s.userBondedLp -= amount_;
        }
    }

    function _setCapitalToken(uint256 tokenId_, address capitalToken_) internal {
        _layoutStruct().capitalTokenOf[tokenId_] = capitalToken_;
    }

    function _clearCapital(uint256 tokenId_) internal {
        delete _layoutStruct().capitalTokenOf[tokenId_];
    }

    function _productIndexOfPair(address pair_) internal view returns (uint8) {
        Storage storage s = _layoutStruct();
        for (uint8 i; i < s.m; ++i) {
            if (address(s.pairTokens[i]) == pair_) return i;
        }
        revert InvalidPair();
    }

    function _isPairToken(address token_) internal view returns (bool) {
        Storage storage s = _layoutStruct();
        for (uint8 i; i < s.m; ++i) {
            if (address(s.pairTokens[i]) == token_) return true;
        }
        return false;
    }
}
