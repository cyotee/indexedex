// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";

/**
 * @title IUniswapV4FullSpreadPonsFamilyHookLiquidReserve
 * @notice Local free-sleeve views + permissionless rebalance for Uniswap V4 Standard Exchange.
 * @dev Interface id keys USAGE fee type and liquid-reserve type-default cascade (staking SE pattern).
 *      Product law: docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md.
 */
interface IUniswapV4FullSpreadPonsFamilyHookLiquidReserve {
    /// @notice Emitted after a rebalance that moved free↔deployed inventory.
    event LiquidReserveRebalanced(
        uint256 free0, uint256 free1, uint256 deployed0, uint256 deployed1, uint256 liquidPct
    );

    /// @notice Optional telemetry when a deposit mints against the sleeve while PoolManager is in-session.
    event LocalDepositWhileBlocked(address token, uint256 amount, uint256 sharesOut);

    /**
     * @notice True when this vault may open a new PoolManager `unlock` (manager idle).
     * @dev `canOpenPoolManagerUnlock() := !TransientStateLibrary.isUnlocked(poolManager)`.
     */
    function canOpenPoolManagerUnlock() external view returns (bool);

    /**
     * @notice Free ERC-20 balance of a pool currency held by this vault (local sleeve).
     * @dev Returns 0 for non-pool tokens. Does not include deployed position amounts.
     */
    function localReserve(address token) external view returns (uint256);

    /// @notice Deployed amounts implied by managed (or imported) Uniswap V4 positions only.
    function deployedReserve() external view returns (uint256 amount0, uint256 amount1);

    /// @notice Live fee-oracle liquid reserve percentage (WAD) for this vault.
    function targetLiquidReservePercentage() external view returns (uint256);

    /**
     * @notice Free / total for one pool currency (WAD). Returns 0 if total is 0 or token is not a pool currency.
     */
    function actualLiquidReservePercentage(address token) external view returns (uint256);

    /**
     * @notice Permissionless placement and bounded holder repair toward the live sleeve policy.
     * @dev Reverts with `UniswapV4Exchange_PoolManagerInteractionBlocked` when the manager is in-session.
     *      Stops trading when both composition and sleeve thresholds pass.
     *      Uses existing full-range ticks, at most one holder swap, and no caller reward or throttle.
     */
    function rebalanceLiquidReserve() external;

    function twapOracle() external view returns (IUniswapV4MultiPoolTwapOracle);
}
