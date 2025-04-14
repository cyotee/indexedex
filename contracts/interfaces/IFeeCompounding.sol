// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IFeeCompounding
 * @notice Interface for fee compounding events emitted by vaults.
 * @dev These events allow off-chain indexing of fee compounding operations.
 */
interface IFeeCompounding {
    /**
     * @notice Emitted when fees are claimed from the underlying pool.
     * @param claimed0 Amount of token0 claimed
     * @param claimed1 Amount of token1 claimed
     */
    event FeesClaimed(uint256 claimed0, uint256 claimed1);

    /**
     * @notice Emitted when claimed fees are compounded back into LP.
     * @param lpMinted Total LP tokens minted from compounding (proportional + zap)
     * @param protocolFeeLP LP amount taken as protocol fee
     * @param excessToken0 Token0 amount held as dust (below threshold)
     * @param excessToken1 Token1 amount held as dust (below threshold)
     */
    event FeesCompounded(uint256 lpMinted, uint256 protocolFeeLP, uint256 excessToken0, uint256 excessToken1);
}
