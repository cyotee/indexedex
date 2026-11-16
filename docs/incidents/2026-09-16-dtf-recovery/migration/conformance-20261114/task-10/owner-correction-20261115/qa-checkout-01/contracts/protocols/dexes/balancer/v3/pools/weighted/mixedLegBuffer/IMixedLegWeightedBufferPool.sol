// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";

/**
 * @title IMixedLegWeightedBufferPool
 * @notice Up to 8 Balancer tokens: unpaired legs (physical balances) + bufferToken/vaultShare pairs.
 * @dev Constraints: unpairedCount + 2*pairCount ∈ [2, 8]; no duplicate token addresses;
 *      unpaired tokens cannot equal any pair buffer or share.
 */
interface IMixedLegWeightedBufferPool {
    enum TokenKind {
        Unpaired,
        Buffer,
        Share
    }

    /* ----- Errors ----- */
    error NotHookCaller(address caller);
    error PreSeatRedemptionFailed(uint256 sharesAttempted, uint256 bufferExpected);
    error PostSwapDepositFailed(uint256 bufferAttempted);
    error VirtualBufferUnderflow(uint256 current, uint256 deduct);
    error PoolShareSideExhausted(uint256 pairIndex);
    error PoolBufferSideExhausted(uint256 pairIndex);
    error PoolUnpairedSideExhausted(uint256 unpairedIndex);
    error RateProviderZero();
    error InitialInvariantTooSmall();
    error InvalidTokenLayout(uint8 unpairedCount, uint8 pairCount);
    error ArrayLengthMismatch();
    error DuplicatePoolToken(address token);
    error InvalidWeights();
    error UnknownPoolToken(address token);
    error WeightLengthMismatch(uint256 expected, uint256 actual);

    /* ----- Views ----- */
    function unpairedCount() external view returns (uint8);
    function pairCount() external view returns (uint8);
    function tokenCount() external view returns (uint256);

    function unpairedToken(uint256 unpairedIndex) external view returns (IERC20);
    function unpairedRateProvider(uint256 unpairedIndex) external view returns (IRateProvider);
    function unpairedIndex(uint256 unpairedIndex) external view returns (uint256);

    function bufferToken(uint256 pairIndex) external view returns (IERC20);
    function shareToken(uint256 pairIndex) external view returns (IERC20);
    function standardExchangeVault(uint256 pairIndex) external view returns (IStandardExchange);
    function pairRateProvider(uint256 pairIndex) external view returns (IRateProvider);
    function bufferIndex(uint256 pairIndex) external view returns (uint256);
    function shareIndex(uint256 pairIndex) external view returns (uint256);
    function virtualBuffer(uint256 pairIndex) external view returns (uint256);
    function hookShareDelta(uint256 pairIndex) external view returns (int256);

    function weight(uint256 tokenIndex) external view returns (uint256);

    /// @notice Resolve Balancer token index to role + leg index (unpaired i or pair i).
    function resolveTokenIndex(uint256 tokenIndex)
        external
        view
        returns (TokenKind kind, uint256 legIndex);
}
