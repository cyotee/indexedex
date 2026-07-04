// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    IWeightedPool
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/pool-weighted/IWeightedPool.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

/// @title DualLiquidityLinkedCrossVersionUniswapVaultRepo
/// @notice Diamond-storage library for the DualLiquidityLinkedCrossVersionUniswapVault family.
///         Mirrors the slot-binding pattern of ComposedStableCommonDetfRepo.
library DualLiquidityLinkedCrossVersionUniswapVaultRepo {
    /* ---------------------------------------------------------------------- */
    /*                                 Errors                                 */
    /* ---------------------------------------------------------------------- */

    /// @notice Reverted when _initialize is called on an already-initialized storage slot.
    error AlreadyInitialized();

    /* ---------------------------------------------------------------------- */
    /*                            Family Errors                               */
    /* ---------------------------------------------------------------------- */
    // Home for the family's route/guard errors (formerly on the deprecated IDualLiquidityLinkedCrossVersionUniswapVault
    // interface). Config is now read from the standard vault surface (IBasicVault/IStandardVault), so
    // no bespoke family interface remains — only these errors.

    /// @notice A tokenIn/tokenOut pair is not a supported route.
    error UnsupportedRoute(IERC20 tokenIn, IERC20 tokenOut);
    /// @notice A zero input/output amount was supplied.
    error ZeroAmount();
    /// @notice The call's deadline has passed.
    error DeadlineExpired(uint256 deadline);
    /// @notice A route was attempted before the reserve holds any BPT (inert/unbootstrapped vault).
    error ReservePoolNotInitialized();
    /// @notice A route left intermediate inventory stranded on the proxy.
    error ResidualInventory(IERC20 token, uint256 amount);

    /* ---------------------------------------------------------------------- */
    /*                              Storage Slot                              */
    /* ---------------------------------------------------------------------- */

    bytes32 internal constant STORAGE_SLOT = keccak256("vault.protocol.uniswap.crossVersion.dual-liquidity-linked.repo");

    /* ---------------------------------------------------------------------- */
    /*                            Storage Struct                              */
    /* ---------------------------------------------------------------------- */

    struct Storage {
        /// @dev The common base token bridging vaultA and vaultB (e.g. a stablecoin).
        IERC20 commonToken;
        /// @dev Base token for vaultA.
        IERC20 tokenA;
        /// @dev Base token for vaultB.
        IERC20 tokenB;
        /// @dev Standard-exchange vault for tokenA.
        IStandardExchangeProxy vaultA;
        /// @dev Standard-exchange vault for tokenB.
        IStandardExchangeProxy vaultB;
        /// @dev Standard-exchange pair vault (holds both vaultA and vaultB shares).
        IStandardExchangeProxy pairVault;
        /// @dev Share token minted by vaultA.
        IERC20 vaultAShare;
        /// @dev Share token minted by vaultB.
        IERC20 vaultBShare;
        /// @dev Share token minted by pairVault.
        IERC20 pairVaultShare;
        /// @dev Underlying Balancer V3 weighted pool for the reserve.
        IWeightedPool reservePool;
        /// @dev ERC-20 BPT token for the reserve pool (== address(reservePool)).
        IERC20 reserveBpt;
        /// @dev Registration index of vaultAShare in the reserve pool's token ordering.
        uint256 indexA;
        /// @dev Registration index of vaultBShare in the reserve pool's token ordering.
        uint256 indexB;
        /// @dev Registration index of pairVaultShare in the reserve pool's token ordering.
        uint256 indexPair;
        /// @dev Fee oracle queried for usage-fee WAD and feeTo collector.
        IVaultFeeOracleQuery feeOracle;
    }

    /* ---------------------------------------------------------------------- */
    /*                           Layout Accessors                             */
    /* ---------------------------------------------------------------------- */

    /// @notice Binds to an arbitrary storage slot (for custom overrides in tests).
    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct_) {
        assembly {
            layoutStruct_.slot := slot_
        }
    }

    /// @notice Binds to the canonical STORAGE_SLOT.
    function _layoutStruct() internal pure returns (Storage storage layoutStruct_) {
        return _layoutStruct(STORAGE_SLOT);
    }

    /* ---------------------------------------------------------------------- */
    /*                          InitArgs struct                               */
    /* ---------------------------------------------------------------------- */

    /// @notice All configuration values bundled to avoid stack-too-deep on _initialize.
    struct InitArgs {
        IERC20 commonToken;
        IERC20 tokenA;
        IERC20 tokenB;
        IStandardExchangeProxy vaultA;
        IStandardExchangeProxy vaultB;
        IStandardExchangeProxy pairVault;
        IERC20 vaultAShare;
        IERC20 vaultBShare;
        IERC20 pairVaultShare;
        IWeightedPool reservePool;
        IERC20 reserveBpt;
        uint256 indexA;
        uint256 indexB;
        uint256 indexPair;
        IVaultFeeOracleQuery feeOracle;
    }

    /* ---------------------------------------------------------------------- */
    /*                             Initialization                             */
    /* ---------------------------------------------------------------------- */

    /// @notice One-time setter for all configuration fields (direct Storage overload).
    /// @dev Reverts with AlreadyInitialized if address(reserveBpt) != address(0).
    function _initialize(Storage storage layoutStruct_, InitArgs memory args_) internal {
        if (address(layoutStruct_.reserveBpt) != address(0)) revert AlreadyInitialized();
        layoutStruct_.commonToken = args_.commonToken;
        layoutStruct_.tokenA = args_.tokenA;
        layoutStruct_.tokenB = args_.tokenB;
        layoutStruct_.vaultA = args_.vaultA;
        layoutStruct_.vaultB = args_.vaultB;
        layoutStruct_.pairVault = args_.pairVault;
        layoutStruct_.vaultAShare = args_.vaultAShare;
        layoutStruct_.vaultBShare = args_.vaultBShare;
        layoutStruct_.pairVaultShare = args_.pairVaultShare;
        layoutStruct_.reservePool = args_.reservePool;
        layoutStruct_.reserveBpt = args_.reserveBpt;
        layoutStruct_.indexA = args_.indexA;
        layoutStruct_.indexB = args_.indexB;
        layoutStruct_.indexPair = args_.indexPair;
        layoutStruct_.feeOracle = args_.feeOracle;
    }

    /// @notice One-time setter bound to the canonical STORAGE_SLOT.
    function _initialize(InitArgs memory args_) internal {
        _initialize(_layoutStruct(), args_);
    }
}
