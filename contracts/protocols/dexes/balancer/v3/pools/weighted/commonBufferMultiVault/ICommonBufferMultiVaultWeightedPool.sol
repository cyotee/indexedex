// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";

/**
 * @title ICommonBufferMultiVaultWeightedPool
 * @notice One shared bufferToken → N SE vaults + optional unpaired legs (T = U+1+N ≤ 8).
 */
interface ICommonBufferMultiVaultWeightedPool {
    enum TokenKind {
        Unpaired,
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
    error PoolUnpairedSideExhausted(uint256 unpairedIndex);
    error RateProviderZero();
    error InitialInvariantTooSmall();
    error InvalidTokenLayout(uint8 unpairedCount, uint8 vaultCount);
    error ArrayLengthMismatch();
    error DuplicatePoolToken(address token);
    error InvalidWeights();
    error UnknownPoolToken(address token);
    error WeightLengthMismatch(uint256 expected, uint256 actual);
    error BufferTokenNotInVault(address bufferToken, address vault);
    error BufferOnlyRemoveDisallowed();

    /* ----- Views ----- */
    function unpairedCount() external view returns (uint8);
    function vaultCount() external view returns (uint8);
    function tokenCount() external view returns (uint256);

    function unpairedToken(uint256 unpairedIndex) external view returns (IERC20);
    function unpairedRateProvider(uint256 unpairedIndex) external view returns (IRateProvider);
    function unpairedIndex(uint256 unpairedIndex) external view returns (uint256);

    function bufferToken() external view returns (IERC20);
    function bufferIndex() external view returns (uint256);
    function virtualBuffer() external view returns (uint256);

    function shareToken(uint256 vaultIndex) external view returns (IERC20);
    function standardExchangeVault(uint256 vaultIndex) external view returns (IStandardExchange);
    function vaultShareRateProvider(uint256 vaultIndex) external view returns (IRateProvider);
    function shareIndex(uint256 vaultIndex) external view returns (uint256);
    function hookShareDelta(uint256 vaultIndex) external view returns (int256);

    function weight(uint256 tokenIndex) external view returns (uint256);

    function resolveTokenIndex(uint256 tokenIndex)
        external
        view
        returns (TokenKind kind, uint256 legIndex);

    /// @notice Lowest d_i/w_i among share legs (L7/L20).
    function mostNeededVault() external view returns (uint8 vaultIndex);
    /// @notice Highest d_i/w_i among share legs (L7/L20).
    function mostExcessVault() external view returns (uint8 vaultIndex);
    /// @notice Score d_i * 1e18 / w_i for vault i (view; uses live Vault balances when available).
    function depthPerWeight(uint256 vaultIndex) external view returns (uint256);
}
