// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPool.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";
import {IDefaultInterestRateStrategyV2} from
    "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IDefaultInterestRateStrategyV2.sol";
import {DataTypes} from "@crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/types/DataTypes.sol";
import {ReserveConfiguration} from
    "@crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/configuration/ReserveConfiguration.sol";

/**
 * @title AaveV36Service
 * @author cyotee doge <doge.cyotee>
 * @notice Stateless library wrapping the Aave V3.6 `Pool` calls used by the cross-version loop
 *         (spike WS1). All reads reconcile live from Aave (PRD decision 2); rates are RAY APR.
 *         The vault is its own position holder, so `onBehalfOf` is always `address(this)`.
 * @dev `interestRateMode` is always 2 (variable); stable rate is deprecated in v3.2.
 */
library AaveV36Service {
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    uint256 internal constant VARIABLE_RATE_MODE = 2;
    uint16 internal constant NO_REFERRAL = 0;

    /* --------------------------------- READS -------------------------------- */

    /// @notice Live supplied (aToken) balance of `account` for `asset`.
    function suppliedOf(IPool pool, address asset, address account) internal view returns (uint256) {
        return IERC20(pool.getReserveAToken(asset)).balanceOf(account);
    }

    /// @notice Live variable debt balance of `account` for `asset`.
    function debtOf(IPool pool, address asset, address account) internal view returns (uint256) {
        return IERC20(pool.getReserveVariableDebtToken(asset)).balanceOf(account);
    }

    /// @notice Current supply rate (RAY APR).
    function supplyRate(IPool pool, address asset) internal view returns (uint256) {
        return pool.getReserveData(asset).currentLiquidityRate;
    }

    /// @notice Current variable borrow rate (RAY APR).
    function borrowRate(IPool pool, address asset) internal view returns (uint256) {
        return pool.getReserveData(asset).currentVariableBorrowRate;
    }

    /// @notice Position health factor (WAD); `type(uint256).max` when no debt.
    function healthFactor(IPool pool, address account) internal view returns (uint256 hf) {
        (,,,,, hf) = pool.getUserAccountData(account);
    }

    /// @notice Oracle price of `asset` in the oracle base currency unit.
    function price(IAaveOracle oracle, address asset) internal view returns (uint256) {
        return oracle.getAssetPrice(asset);
    }

    /// @notice Effective collateral LTV for `asset` (BPS); eMode LTV must be applied by the caller
    ///         when the position is in an eMode (PRD decision 24).
    function ltv(IPool pool, address asset) internal view returns (uint256) {
        return pool.getConfiguration(asset).getLtv();
    }

    function liquidationThreshold(IPool pool, address asset) internal view returns (uint256) {
        return pool.getConfiguration(asset).getLiquidationThreshold();
    }

    /// @notice Whether `asset` can currently accept new leverage (active, not frozen, not paused,
    ///         borrowing enabled). Used by the graceful-degradation branch (PRD decision 23).
    function canLeverage(IPool pool, address asset) internal view returns (bool) {
        DataTypes.ReserveConfigurationMap memory cfg = pool.getConfiguration(asset);
        return cfg.getActive() && !cfg.getFrozen() && !cfg.getPaused() && cfg.getBorrowingEnabled();
    }

    /// @notice Whether `asset` can currently be unwound (active, not paused). Frozen still allows
    ///         withdraw/repay (PRD decision 23).
    function canUnwind(IPool pool, address asset) internal view returns (bool) {
        DataTypes.ReserveConfigurationMap memory cfg = pool.getConfiguration(asset);
        return cfg.getActive() && !cfg.getPaused();
    }

    /// @notice The Pool-level interest rate strategy (v3.4+: single strategy, not per-reserve).
    function interestRateStrategy(IPool pool) internal view returns (IDefaultInterestRateStrategyV2) {
        return IDefaultInterestRateStrategyV2(pool.RESERVE_INTEREST_RATE_STRATEGY());
    }

    /// @notice Projected (liquidityRate, variableBorrowRate) for `asset` after a hypothetical leg,
    ///         used to keep `preview == execution` (PRD decision 30). The caller assembles `params`
    ///         with adjusted `liquidityAdded`/`liquidityTaken`/`totalDebt`/`virtualUnderlyingBalance`.
    function projectedRates(IPool pool, DataTypes.CalculateInterestRatesParams memory params)
        internal
        view
        returns (uint256 liquidityRate, uint256 variableBorrowRate)
    {
        return interestRateStrategy(pool).calculateInterestRates(params);
    }

    /* --------------------------------- WRITES ------------------------------- */

    function supply(IPool pool, address asset, uint256 amount) internal {
        pool.supply(asset, amount, address(this), NO_REFERRAL);
    }

    function withdraw(IPool pool, address asset, uint256 amount) internal returns (uint256 withdrawn) {
        return pool.withdraw(asset, amount, address(this));
    }

    function borrow(IPool pool, address asset, uint256 amount) internal {
        pool.borrow(asset, amount, VARIABLE_RATE_MODE, NO_REFERRAL, address(this));
    }

    function repay(IPool pool, address asset, uint256 amount) internal returns (uint256 repaid) {
        return pool.repay(asset, amount, VARIABLE_RATE_MODE, address(this));
    }

    /// @notice Opt the vault into an eMode category for correlated efficiency (PRD decision 24).
    function setEMode(IPool pool, uint8 categoryId) internal {
        pool.setUserEMode(categoryId);
    }
}
