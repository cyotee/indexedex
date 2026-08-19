// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @title UniswapV4StandardExchangeCurveQuadStableDETFRepo
/// @notice Diamond storage for Uni V4 Curve Quad Stable SE Buffer DETF. Role names only. No rateAsset.
library UniswapV4StandardExchangeCurveQuadStableDETFRepo {
    error AlreadyInitialized();
    error ReserveNotLive();
    error AlreadyLive();
    error InvalidRoute(IERC20 tokenIn, IERC20 tokenOut);
    error ZeroAmount();
    error DeadlineExpired(uint256 deadline);
    error MintingNotAllowed(uint256 syntheticPrice, uint256 mintThreshold);
    error BurningNotAllowed(uint256 syntheticPrice, uint256 burnThreshold);
    error LockDurationTooShort(uint256 lockDuration, uint256 minLockDuration);
    error ProtocolLpEmpty();
    error FirstBondBelowMinimumLiquidity();
    error FirstBondRequiresAllExternalPairs();
    error LaterBondSinglePairOnly();
    error BondNotMature(uint256 unlockTime);
    error NotSingleAssetEligible();
    error SlippageExceeded(uint256 minOut, uint256 actual);
    error ClaimTokenNotConfigured();
    error NotAuthorized(address caller);
    error RedepositFailed();
    error InvalidCapitalToken();
    error InvalidPair();
    error ReserveNotWired();
    error ReserveHookNotFinalized();
    error ReserveBondNftNotWired();
    error ReserveBondNftAlreadyWired();
    error ReserveClaimAlreadyWired();
    error ZeroAddress();

    bytes32 internal constant STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256("vault.detf.uniswap.v4.se.curve.quad.stable.repo")) - 1)
    ) & ~bytes32(uint256(0xff));

    uint8 internal constant N = 4;
    uint8 internal constant M = 3;

    struct Storage {
        bool isReserveLive;
        uint8 n; // always 4
        uint8 m; // always 3
        uint8 detfBindingIndex;
        IERC20[M] pairTokens;
        IStandardExchangeProxy[M] standardExchanges;
        IERC20[M] vaultShares;
        address[M] rateProviders;
        uint256[M] creationPairPerDetfWad;
        uint8[M] pairBindingIndex;
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
        mapping(uint256 tokenId => address) capitalTokenOf;
        address bondNftVaultPkg;
        address rebasingClaimTokenPkg;
        address creator;
    }

    struct CoreInit {
        uint8 detfBindingIndex;
        IERC20[] pairTokens;
        IStandardExchangeProxy[] standardExchanges;
        IERC20[] vaultShares;
        address[] rateProviders;
        uint256[] creationPairPerDetfWad;
        uint8[] pairBindingIndex;
        address reserveHook;
        IPoolManager poolManager;
        IVaultFeeOracleQuery feeOracle;
        IDETFNFTVault bondNftVault;
        IRebasingClaimToken rebasingClaimToken;
        uint256 detfNftId;
        uint256 feeRecipientNftId;
        address bondNftVaultPkg;
        address rebasingClaimTokenPkg;
        address creator;
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
        if (p_.pairTokens.length != M) revert InvalidRoute(IERC20(address(0)), IERC20(address(0)));
        s.isReserveLive = false;
        s.n = N;
        s.m = M;
        s.detfBindingIndex = p_.detfBindingIndex;
        for (uint256 i; i < M; ++i) {
            s.pairTokens[i] = p_.pairTokens[i];
            s.standardExchanges[i] = p_.standardExchanges[i];
            s.vaultShares[i] = p_.vaultShares[i];
            s.rateProviders[i] = p_.rateProviders[i];
            s.creationPairPerDetfWad[i] = p_.creationPairPerDetfWad[i];
            s.pairBindingIndex[i] = p_.pairBindingIndex[i];
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
        s.bondNftVaultPkg = p_.bondNftVaultPkg;
        s.rebasingClaimTokenPkg = p_.rebasingClaimTokenPkg;
        s.creator = p_.creator;
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

    function _setBondNft(
        IDETFNFTVault bondNftVault_,
        uint256 detfNftId_,
        uint256 feeRecipientNftId_
    ) internal {
        Storage storage s = _layoutStruct();
        if (address(s.bondNftVault) != address(0)) revert ReserveBondNftAlreadyWired();
        if (address(bondNftVault_) == address(0)) revert ZeroAddress();
        s.bondNftVault = bondNftVault_;
        s.detfNftId = detfNftId_;
        s.feeRecipientNftId = feeRecipientNftId_;
    }

    function _setClaim(IRebasingClaimToken rebasingClaimToken_) internal {
        Storage storage s = _layoutStruct();
        if (address(s.bondNftVault) == address(0)) revert ReserveBondNftNotWired();
        if (address(s.rebasingClaimToken) != address(0)) revert ReserveClaimAlreadyWired();
        if (address(rebasingClaimToken_) == address(0)) revert ZeroAddress();
        s.rebasingClaimToken = rebasingClaimToken_;
    }
}
