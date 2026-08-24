// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IUniswapV3StandardExchangeLiquidReserve
 * @notice Local free-sleeve views + permissionless rebalance for Uniswap V3 Standard Exchange.
 * @dev Interface id keys USAGE fee type and liquid-reserve type-default cascade.
 *      Gate is bound-pool `slot0.unlocked` (true = idle), not Uniswap V4 PoolManager `isUnlocked`.
 */
interface IUniswapV3StandardExchangeLiquidReserve {
    /// @notice Emitted after a rebalance that moved free↔deployed inventory.
    event LiquidReserveRebalanced(
        uint256 free0, uint256 free1, uint256 deployed0, uint256 deployed1, uint256 liquidPct
    );

    /// @notice Optional telemetry when a deposit mints against the sleeve while the bound pool is locked.
    event LocalDepositWhileBlocked(address token, uint256 amount, uint256 sharesOut);

    /**
     * @notice True when this vault may open bound-pool `mint` / `burn` / `swap` / `collect` (pool idle).
     * @dev `canOpenBoundPoolOps() := pool.slot0().unlocked`. Uniswap V3 `unlocked == false` while a
     *      swap or mint callback is in flight (`LOK` if the vault nested another pool op).
     */
    function canOpenBoundPoolOps() external view returns (bool);

    /**
     * @notice Free ERC-20 balance of a pool currency held by this vault (local sleeve).
     * @dev Returns 0 for non-pool tokens. Does not include deployed position amounts.
     */
    function localReserve(address token) external view returns (uint256);

    /// @notice Deployed amounts implied by the managed (or imported) Uniswap V3 center position only.
    function deployedReserve() external view returns (uint256 amount0, uint256 amount1);

    /// @notice Live fee-oracle liquid reserve percentage (WAD) for this vault.
    function targetLiquidReservePercentage() external view returns (uint256);

    /**
     * @notice Free / total for one pool currency (WAD). Returns 0 if total is 0 or token is not a pool currency.
     */
    function actualLiquidReservePercentage(address token) external view returns (uint256);

    /**
     * @notice Permissionless rebalance free↔deployed toward the oracle liquid target (add/remove only).
     * @dev Reverts with `UniswapV3Exchange_BoundPoolInteractionBlocked` when `slot0.unlocked == false`.
     *      Succeeds without pool ops when both tokens are already within the deadband.
     *      Add/remove only on the existing full-range (or imported) ticks; does not recast.
     */
    function rebalanceLiquidReserve() external;
}
