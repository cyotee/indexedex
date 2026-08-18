// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @title UniswapV4SingleStandardExchangeDETFRepo
/// @notice Diamond storage for Uni V4 Single SE CP-buffer DETF. Role names only.
library UniswapV4SingleStandardExchangeDETFRepo {
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
    error SlippageExceeded(uint256 minOut, uint256 actual);
    error ClaimTokenNotConfigured();
    error NotAuthorized(address caller);
    error ReserveNotWired();
    error ReserveHookNotFinalized();
    error ReserveBondNftNotWired();
    error ReserveBondNftAlreadyWired();
    error ReserveClaimAlreadyWired();
    error ZeroAddress();

    bytes32 internal constant STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256("vault.detf.uniswap.v4.se.cp.single.repo")) - 1)
    ) & ~bytes32(uint256(0xff));

    struct Storage {
        bool isReserveLive;
        IStandardExchangeProxy standardExchangeVault;
        IERC20 standardExchangeVaultShare;
        IERC20 pairToken;
        address reserveHook;
        IPoolManager poolManager;
        IVaultFeeOracleQuery feeOracle;
        IDETFNFTVault bondNftVault;
        IRebasingClaimToken rebasingClaimToken;
        uint256 detfNftId;
        uint256 feeRecipientNftId;
        uint256 creationPairPerDetfWad;
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
        uint256 expansionEpochLength;
        uint256 expansionClosureRatePerYearWad;
        uint256 expansionMaxCatchUpEpochs;
        uint256 lastExpansionTimestamp;
        uint256 userBondedLp;
        address bondNftVaultPkg;
        address rebasingClaimTokenPkg;
    }

    /// @dev Core bindings only — thresholds/expansion set via `_initPolicy`.
    struct CoreInit {
        IStandardExchangeProxy standardExchangeVault;
        IERC20 standardExchangeVaultShare;
        IERC20 pairToken;
        address reserveHook;
        IPoolManager poolManager;
        IVaultFeeOracleQuery feeOracle;
        IDETFNFTVault bondNftVault;
        IRebasingClaimToken rebasingClaimToken;
        uint256 detfNftId;
        uint256 feeRecipientNftId;
        uint256 creationPairPerDetfWad;
        address bondNftVaultPkg;
        address rebasingClaimTokenPkg;
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
        if (address(s.standardExchangeVault) != address(0)) revert AlreadyInitialized();
        s.isReserveLive = false;
        s.standardExchangeVault = p_.standardExchangeVault;
        s.standardExchangeVaultShare = p_.standardExchangeVaultShare;
        s.pairToken = p_.pairToken;
        s.reserveHook = p_.reserveHook;
        s.poolManager = p_.poolManager;
        s.feeOracle = p_.feeOracle;
        s.bondNftVault = p_.bondNftVault;
        s.rebasingClaimToken = p_.rebasingClaimToken;
        s.detfNftId = p_.detfNftId;
        s.feeRecipientNftId = p_.feeRecipientNftId;
        s.creationPairPerDetfWad = p_.creationPairPerDetfWad;
        s.lastExpansionTimestamp = 0;
        s.userBondedLp = 0;
        s.bondNftVaultPkg = p_.bondNftVaultPkg;
        s.rebasingClaimTokenPkg = p_.rebasingClaimTokenPkg;
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
