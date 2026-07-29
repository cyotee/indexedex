// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/**
 * @title IDetfErrors
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Error definitions for the shared DETF surface.
 */
interface IDetfErrors {
    /* ---------------------------------------------------------------------- */
    /*                          Price Gate Errors                             */
    /* ---------------------------------------------------------------------- */

    /// @notice Seigniorage mint blocked: inert, or Policy synthetic at/below mint threshold.
    /// @dev Under Open + live, threshold helpers do not emit this for deadband reasons.
    ///      Args still report the synthetic price and stored mint threshold for diagnostics.
    error MintingNotAllowed(uint256 syntheticPrice, uint256 mintThreshold);

    /// @notice Seigniorage burn blocked: inert, or Policy synthetic at/above burn threshold.
    /// @dev Under Open + live, threshold helpers do not emit this for deadband reasons.
    ///      Claim-path redemption uses `RedemptionNotAllowed` (independent of Open).
    error BurningNotAllowed(uint256 syntheticPrice, uint256 burnThreshold);

    /* ---------------------------------------------------------------------- */
    /*                          Token Errors                                  */
    /* ---------------------------------------------------------------------- */

    /// @notice Invalid token for the operation
    error InvalidToken(IERC20 token);

    /// @notice Token is not the rate asset
    error NotRateAsset(IERC20 token);

    /// @notice Token is not the pair token
    error NotPairToken(IERC20 token);

    /// @notice Token is not an accepted bond token
    error BondTokenNotSupported(IERC20 token);

    /// @notice Token is not the DETF token
    error NotDetfToken(IERC20 token);

    /// @notice Token is not the rebasing claim token
    error NotRebasingClaimToken(IERC20 token);

    /// @notice Only rateAsset or the DETF token allowed for donation
    error InvalidDonationToken(IERC20 token);

    /* ---------------------------------------------------------------------- */
    /*                          Amount Errors                                 */
    /* ---------------------------------------------------------------------- */

    /// @notice Zero amount provided
    error ZeroAmount();

    /// @notice Native ETH bonding is only valid for the WETH route
    error InvalidEthBondRoute(IERC20 token);

    /// @notice The provided msg.value does not match the expected amount
    error IncorrectEthValue(uint256 expected, uint256 actual);

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
    error DETFNFTRestricted(uint256 tokenId);

    /// @notice Lock duration out of bounds
    error InvalidLockDuration(uint256 duration, uint256 minDuration, uint256 maxDuration);

    /* ---------------------------------------------------------------------- */
    /*                          Access Errors                                 */
    /* ---------------------------------------------------------------------- */

    /// @notice Caller is not the DETF diamond
    error NotDetf(address caller);

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
    /// @param syntheticRateAssetValue The synthetic rateAsset value from zap-out calculation (0 if failed)
    /// @param syntheticPairValue The synthetic pair-token value from zap-out calculation (0 if failed)
    error PoolImbalanced(uint256 syntheticRateAssetValue, uint256 syntheticPairValue);

    /// @notice Invalid reserve pool vault indices
    /// @dev Both indices must be 0 or 1, and they must be different
    /// @param detfIndex The reserve-pool index of the DETF token
    /// @param vaultTokenIndex The reserve-pool index of the vault share token
    error InvalidReservePoolIndices(uint256 detfIndex, uint256 vaultTokenIndex);

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
    /*                     Rebasing claim token Errors                        */
    /* ---------------------------------------------------------------------- */

    /// @notice Rebasing claim redemption not allowed (claim-path synthetic gate).
    /// @dev Independent of primary-market `ThresholdMode` / Open — claim redeem is not
    ///      opened merely because the instance is Open. Do not couple to Open short-circuit.
    error RedemptionNotAllowed(uint256 syntheticPrice, uint256 burnThreshold);

    /// @notice Cannot transfer rebasing claim tokens to AMM pools or lending protocols
    error RebasingClaimTransferRestricted(address to);
}
