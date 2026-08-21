// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";

/// @title UniswapV4StandardExchangeOrbitalDETFRepo
/// @notice Diamond storage for Uni V4 Orbital SE Buffer DETF. Role names only.
library UniswapV4StandardExchangeOrbitalDETFRepo {
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
    error FirstBondRequiresBothPairs();
    error BondNotMature(uint256 unlockTime);
    error NotZapEligible();
    error SlippageExceeded(uint256 minOut, uint256 actual);
    error ClaimTokenNotConfigured();
    error NotAuthorized(address caller);
    error RedepositFailed();
    error ReserveNotWired();
    error ReserveHookNotFinalized();
    error ReserveBondNftNotWired();
    error ReserveBondNftAlreadyWired();
    error ReserveClaimAlreadyWired();
    error ZeroAddress();

    bytes32 internal constant STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256("vault.detf.uniswap.v4.se.orbital.repo")) - 1)
    ) & ~bytes32(uint256(0xff));

    struct CapitalMeta {
        IUniswapV4StandardExchangeOrbitalDETF.CapitalMode mode;
        address capitalToken0;
        address capitalToken1;
    }

    struct Storage {
        bool isReserveLive;
        IERC20 pairToken0;
        IERC20 pairToken1;
        IStandardExchangeProxy standardExchange0;
        IStandardExchangeProxy standardExchange1;
        IERC20 vaultShare0;
        IERC20 vaultShare1;
        address rateProvider0;
        address rateProvider1;
        IERC20 rateAsset;
        uint8 detfBindingIndex;
        uint8 pair0BindingIndex;
        uint8 pair1BindingIndex;
        address reserveHook;
        IPoolManager poolManager;
        IVaultFeeOracleQuery feeOracle;
        IDETFNFTVault bondNftVault;
        IRebasingClaimToken rebasingClaimToken;
        uint256 detfNftId;
        uint256 feeRecipientNftId;
        uint256 creationPair0PerDetfWad;
        uint256 creationPair1PerDetfWad;
        uint256 openingPair0PerDetfWad;
        uint256 openingPair1PerDetfWad;
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
        uint256 expansionEpochLength;
        uint256 expansionClosureRatePerYearWad;
        uint256 expansionMaxCatchUpEpochs;
        uint256 lastExpansionTimestamp;
        uint256 userBondedLp;
        mapping(uint256 tokenId => CapitalMeta) capitalOf;
        address bondNftVaultPkg;
        address rebasingClaimTokenPkg;
        address creator;
        string claimName;
        string claimSymbol;
        string bondName;
        string bondSymbol;
    }

    struct CoreInit {
        IERC20 pairToken0;
        IERC20 pairToken1;
        IStandardExchangeProxy standardExchange0;
        IStandardExchangeProxy standardExchange1;
        IERC20 vaultShare0;
        IERC20 vaultShare1;
        address rateProvider0;
        address rateProvider1;
        IERC20 rateAsset;
        uint8 detfBindingIndex;
        uint8 pair0BindingIndex;
        uint8 pair1BindingIndex;
        address reserveHook;
        IPoolManager poolManager;
        IVaultFeeOracleQuery feeOracle;
        IDETFNFTVault bondNftVault;
        IRebasingClaimToken rebasingClaimToken;
        uint256 detfNftId;
        uint256 feeRecipientNftId;
        uint256 creationPair0PerDetfWad;
        uint256 creationPair1PerDetfWad;
        uint256 openingPair0PerDetfWad;
        uint256 openingPair1PerDetfWad;
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
        if (address(s.pairToken0) != address(0)) revert AlreadyInitialized();
        s.isReserveLive = false;
        s.pairToken0 = p_.pairToken0;
        s.pairToken1 = p_.pairToken1;
        s.standardExchange0 = p_.standardExchange0;
        s.standardExchange1 = p_.standardExchange1;
        s.vaultShare0 = p_.vaultShare0;
        s.vaultShare1 = p_.vaultShare1;
        s.rateProvider0 = p_.rateProvider0;
        s.rateProvider1 = p_.rateProvider1;
        s.rateAsset = p_.rateAsset;
        s.detfBindingIndex = p_.detfBindingIndex;
        s.pair0BindingIndex = p_.pair0BindingIndex;
        s.pair1BindingIndex = p_.pair1BindingIndex;
        s.reserveHook = p_.reserveHook;
        s.poolManager = p_.poolManager;
        s.feeOracle = p_.feeOracle;
        s.bondNftVault = p_.bondNftVault;
        s.rebasingClaimToken = p_.rebasingClaimToken;
        s.detfNftId = p_.detfNftId;
        s.feeRecipientNftId = p_.feeRecipientNftId;
        s.creationPair0PerDetfWad = p_.creationPair0PerDetfWad;
        s.creationPair1PerDetfWad = p_.creationPair1PerDetfWad;
        s.openingPair0PerDetfWad = p_.openingPair0PerDetfWad;
        s.openingPair1PerDetfWad = p_.openingPair1PerDetfWad;
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

    function _setCapital(
        uint256 tokenId_,
        IUniswapV4StandardExchangeOrbitalDETF.CapitalMode mode_,
        address capitalToken0_,
        address capitalToken1_
    ) internal {
        _layoutStruct().capitalOf[tokenId_] = CapitalMeta({
            mode: mode_,
            capitalToken0: capitalToken0_,
            capitalToken1: capitalToken1_
        });
    }

    function _clearCapital(uint256 tokenId_) internal {
        delete _layoutStruct().capitalOf[tokenId_];
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

    function _setChildTokenMetadata(
        string memory claimName_,
        string memory claimSymbol_,
        string memory bondName_,
        string memory bondSymbol_
    ) internal {
        Storage storage s = _layoutStruct();
        s.claimName = claimName_;
        s.claimSymbol = claimSymbol_;
        s.bondName = bondName_;
        s.bondSymbol = bondSymbol_;
    }
}
