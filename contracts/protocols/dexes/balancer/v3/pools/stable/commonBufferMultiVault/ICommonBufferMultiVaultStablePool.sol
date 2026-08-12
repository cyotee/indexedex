// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";

/**
 * @title ICommonBufferMultiVaultStablePool
 * @notice One shared bufferToken → N SE vaults under StableMath (T = 1 + N, 1 ≤ N ≤ 3).
 * @dev No unpaired legs. Routing by derived share depth only (no weights).
 */
interface ICommonBufferMultiVaultStablePool {
    enum TokenKind {
        Buffer,
        Share
    }

    /* ----- Errors ----- */
    error NotHookCaller(address caller);
    error PreSeatRedemptionFailed(uint256 sharesAttempted, uint256 bufferExpected);
    error PostSwapDepositFailed(uint256 bufferAttempted);
    error AllVaultsExhausted();
    error VirtualBufferUnderflow(uint256 current, uint256 deduct);
    error PoolShareSideExhausted(uint256 vaultIndex);
    error PoolBufferSideExhausted();
    error RateProviderZero();
    error InitialInvariantTooSmall();
    error InvalidTokenLayout(uint8 vaultCount);
    error ArrayLengthMismatch();
    error DuplicatePoolToken(address token);
    error UnknownPoolToken(address token);
    error BufferTokenNotInVault(address bufferToken, address vault);
    error BufferOnlyRemoveDisallowed();
    error AmplificationFactorTooLow();
    error AmplificationFactorTooHigh();

    /* ----- Views ----- */
    function vaultCount() external view returns (uint8);
    function tokenCount() external view returns (uint256);

    function bufferToken() external view returns (IERC20);
    function bufferIndex() external view returns (uint256);
    function virtualBuffer() external view returns (uint256);

    function shareToken(uint256 vaultIndex) external view returns (IERC20);
    function standardExchangeVault(uint256 vaultIndex) external view returns (IStandardExchange);
    function vaultShareRateProvider(uint256 vaultIndex) external view returns (IRateProvider);
    function shareIndex(uint256 vaultIndex) external view returns (uint256);
    function hookShareDelta(uint256 vaultIndex) external view returns (int256);

    function resolveTokenIndex(uint256 tokenIndex) external view returns (TokenKind kind, uint256 legIndex);

    /// @notice Vault with lowest derived share depth (deposit target / shallowest).
    function shallowestVault() external view returns (uint8 vaultIndex);
    /// @notice Vault with highest derived share depth (redeem source / deepest).
    function deepestVault() external view returns (uint8 vaultIndex);
    /// @notice Derived share depth d_i for vault i (view; uses live Vault balances when available).
    function derivedShareDepth(uint256 vaultIndex) external view returns (uint256);

    /// @notice Current amplification (includes AMP_PRECISION).
    function getAmplificationParameter() external view returns (uint256 value, bool isUpdating, uint256 precision);
}
