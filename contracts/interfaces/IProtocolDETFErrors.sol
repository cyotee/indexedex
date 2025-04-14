// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/**
 * @title IProtocolDETFErrors
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Error definitions for Protocol DETF system.
 */
interface IProtocolDETFErrors {
    /* ---------------------------------------------------------------------- */
    /*                          Price Gate Errors                             */
    /* ---------------------------------------------------------------------- */

    /// @notice Minting is not allowed when synthetic price is at or below mint threshold
    error MintingNotAllowed(uint256 syntheticPrice, uint256 mintThreshold);

    /// @notice Burning/redemption is not allowed when synthetic price is at or above burn threshold
    error BurningNotAllowed(uint256 syntheticPrice, uint256 burnThreshold);

    /* ---------------------------------------------------------------------- */
    /*                          Token Errors                                  */
    /* ---------------------------------------------------------------------- */

    /// @notice Invalid token for the operation
    error InvalidToken(IERC20 token);

    /// @notice Token is not WETH
    error NotWethToken(IERC20 token);

    /// @notice Token is not RICH
    error NotRichToken(IERC20 token);

    /// @notice Token is not CHIR
    error NotChirToken(IERC20 token);

    /// @notice Token is not RICHIR
    error NotRichirToken(IERC20 token);

    /// @notice Only WETH or CHIR allowed for donation
    error InvalidDonationToken(IERC20 token);

    /* ---------------------------------------------------------------------- */
    /*                          Amount Errors                                 */
    /* ---------------------------------------------------------------------- */

    /// @notice Zero amount provided
    error ZeroAmount();

    /// @notice Insufficient balance for operation
    error InsufficientBalance(uint256 required, uint256 available);

    /// @notice Slippage exceeded
    error SlippageExceeded(uint256 expected, uint256 actual);

    /* ---------------------------------------------------------------------- */
    /*                          NFT Errors                                    */
    /* ---------------------------------------------------------------------- */

    /// @notice Position is still locked
    error PositionLocked(uint256 tokenId, uint256 unlockTime, uint256 currentTime);

    /// @notice Position does not exist
    error PositionNotFound(uint256 tokenId);

    /// @notice Caller is not the owner of the NFT
    error NotNFTOwner(uint256 tokenId, address caller, address owner);

    /// @notice Cannot modify protocol-owned NFT
    error ProtocolNFTRestricted(uint256 tokenId);

    /// @notice Lock duration out of bounds
    error InvalidLockDuration(uint256 duration, uint256 minDuration, uint256 maxDuration);

    /* ---------------------------------------------------------------------- */
    /*                          Access Errors                                 */
    /* ---------------------------------------------------------------------- */

    /// @notice Caller is not the Protocol DETF contract
    error NotProtocolDETF(address caller);

    /// @notice Caller is not the NFT vault
    error NotNFTVault(address caller);

    /// @notice Caller is not authorized (feeTo address)
    error NotAuthorized(address caller);

    /* ---------------------------------------------------------------------- */
    /*                          State Errors                                  */
    /* ---------------------------------------------------------------------- */

    /// @notice Reserve pool is not initialized
    error ReservePoolNotInitialized();

    /// @notice Reserve pool is already initialized
    error ReservePoolAlreadyInitialized();

    /// @notice No seigniorage to capture
    error NoSeigniorageToCapture();

    /// @notice Pool is extremely imbalanced, synthetic price cannot be calculated
    /// @param syntheticWethValue The synthetic WETH value from zap-out calculation (0 if failed)
    /// @param syntheticRichValue The synthetic RICH value from zap-out calculation (0 if failed)
    error PoolImbalanced(uint256 syntheticWethValue, uint256 syntheticRichValue);

    /// @notice Invalid reserve pool vault indices
    /// @dev Both indices must be 0 or 1, and they must be different
    /// @param chirWethVaultIndex The index for CHIR/WETH vault in the reserve pool
    /// @param richChirVaultIndex The index for RICH/CHIR vault in the reserve pool
    error InvalidReservePoolIndices(uint256 chirWethVaultIndex, uint256 richChirVaultIndex);

    /// @notice The requested bridge peer is not configured.
    error BridgePeerNotConfigured(uint256 targetChainId);

    /// @notice The bridge token registry did not return a remote token.
    error BridgeRemoteTokenNotConfigured(uint256 targetChainId, IERC20 localToken);

    /// @notice The DETF bridge stack is not configured.
    error BridgeConfigNotSet();

    /// @notice The DETF bridge stack has already been configured.
    error BridgeConfigAlreadySet();

    /// @notice The caller is not the configured local bridge relayer.
    error NotBridgeRelayer(address caller, address expectedRelayer);

    /* ---------------------------------------------------------------------- */
    /*                          RICHIR Errors                                 */
    /* ---------------------------------------------------------------------- */

    /// @notice RICHIR redemption not allowed (synthetic price too high)
    error RedemptionNotAllowed(uint256 syntheticPrice, uint256 burnThreshold);

    /// @notice Cannot transfer RICHIR to AMM pools or lending protocols
    error RICHIRTransferRestricted(address to);
}
