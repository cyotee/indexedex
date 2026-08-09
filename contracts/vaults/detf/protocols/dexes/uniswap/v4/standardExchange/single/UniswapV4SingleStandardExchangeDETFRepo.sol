// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @title UniswapV4SingleStandardExchangeDETFRepo
/// @notice Diamond storage for Uni V4–listed Single Standard Exchange DETF.
library UniswapV4SingleStandardExchangeDETFRepo {
    error AlreadyInitialized();
    error NotLive();
    error AlreadyLive();
    error UnsupportedRoute(IERC20 tokenIn, IERC20 tokenOut);
    error ZeroAmount();
    error DeadlineExpired(uint256 deadline);
    error MintingNotAllowed(uint256 syntheticPrice, uint256 mintThreshold);
    error BurningNotAllowed(uint256 syntheticPrice, uint256 burnThreshold);
    error LockDurationTooShort(uint256 lockDuration, uint256 minLockDuration);
    error EmptyInventory();
    error PairTokenNotInBackingTokens();
    error HooksNotAllowed();
    error InvalidCreationPrice();
    error InvalidWidthMultiplier();
    error BondNotMature();
    error PartialCloseNotSupported();
    error InvalidBondToken();
    error SlippageExceeded(uint256 minOut, uint256 actual);
    error NotAuthorized(address caller);

    bytes32 internal constant STORAGE_SLOT =
        keccak256("vault.detf.uniswap.v4.standardExchange.single.repo");

    struct Storage {
        bool isReserveLive;
        IStandardExchangeProxy standardExchangeVault;
        IERC20 standardExchangeVaultShare;
        IERC20 pairToken;
        IPoolManager poolManager;
        PoolKey poolKey;
        PoolId poolId;
        uint160 creationSqrtPriceX96;
        bool pairIsCurrency0;
        uint32 twapSeconds;
        uint24 widthMultiplier;
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
        IVaultFeeOracleQuery feeOracle;
        address bondNft;
        address rebasingClaimToken;
        // Natural expansion (deploy-time resolve only).
        uint256 expansionClosureRatePerSecond;
        uint256 expansionCatchUpMaxSeconds;
        uint256 expansionCatchUpCapBps;
        uint256 lastExpansionTimestamp;
    }

    struct InitParams {
        IStandardExchangeProxy standardExchangeVault;
        IERC20 standardExchangeVaultShare;
        IERC20 pairToken;
        IPoolManager poolManager;
        PoolKey poolKey;
        PoolId poolId;
        uint160 creationSqrtPriceX96;
        bool pairIsCurrency0;
        uint32 twapSeconds;
        uint24 widthMultiplier;
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
        IVaultFeeOracleQuery feeOracle;
        address bondNft;
        address rebasingClaimToken;
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

    function _initialize(InitParams memory p_) internal {
        Storage storage s = _layoutStruct();
        if (address(s.standardExchangeVault) != address(0)) revert AlreadyInitialized();

        s.isReserveLive = false;
        s.standardExchangeVault = p_.standardExchangeVault;
        s.standardExchangeVaultShare = p_.standardExchangeVaultShare;
        s.pairToken = p_.pairToken;
        s.poolManager = p_.poolManager;
        s.poolKey = p_.poolKey;
        s.poolId = p_.poolId;
        s.creationSqrtPriceX96 = p_.creationSqrtPriceX96;
        s.pairIsCurrency0 = p_.pairIsCurrency0;
        s.twapSeconds = p_.twapSeconds;
        s.widthMultiplier = p_.widthMultiplier;
        s.mintThreshold = p_.mintThreshold;
        s.burnThreshold = p_.burnThreshold;
        s.thresholdMode = p_.thresholdMode;
        s.feeOracle = p_.feeOracle;
        s.bondNft = p_.bondNft;
        s.rebasingClaimToken = p_.rebasingClaimToken;
        s.expansionClosureRatePerSecond = p_.expansionClosureRatePerSecond;
        s.expansionCatchUpMaxSeconds = p_.expansionCatchUpMaxSeconds;
        s.expansionCatchUpCapBps = p_.expansionCatchUpCapBps;
        s.lastExpansionTimestamp = 0;
    }

    function _setReserveLive() internal {
        Storage storage s = _layoutStruct();
        s.isReserveLive = true;
        if (s.lastExpansionTimestamp == 0) {
            s.lastExpansionTimestamp = block.timestamp;
        }
    }
}
