// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ISpoke} from "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/ISpoke.sol";
import {IHub} from "@crane/contracts/protocols/lending/aave/v4/hub/interfaces/IHub.sol";
import {IAaveOracle as IAaveOracleV4} from
    "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/IAaveOracle.sol";

/**
 * @title AaveV4Service
 * @author cyotee doge <doge.cyotee>
 * @notice Stateless library wrapping the Aave V4 `Spoke`/`Hub` calls used by the cross-version loop
 *         (spike WS2). The vault operates as its own `onBehalfOf` (the `user == manager` shortcut),
 *         so no position-manager approval is needed. All reads reconcile live (PRD decision 2).
 * @dev V4 has no eMode (finding F1): borrow power is the reserve `collateralFactor`. V4 has no
 *      supply-rate getter (finding F3): supply APY is derived by the caller from the accessors here,
 *      including premium interest which accrues to suppliers net of `liquidityFee` (PRD decision 33).
 */
library AaveV4Service {
    /* --------------------------------- READS -------------------------------- */

    /// @notice Live supplied (underlying-equivalent) balance of `account` for `reserveId`.
    function suppliedOf(ISpoke spoke, uint256 reserveId, address account) internal view returns (uint256) {
        return spoke.getUserSuppliedAssets(reserveId, account);
    }

    /// @notice Live total debt (drawn + premium) of `account` for `reserveId`. The never-borrow
    ///         unwind must repay BOTH components (PRD decision 31).
    function debtOf(ISpoke spoke, uint256 reserveId, address account) internal view returns (uint256) {
        (uint256 drawn, uint256 premium) = spoke.getUserDebt(reserveId, account);
        return drawn + premium;
    }

    /// @notice Drawn vs premium debt split for `account` on `reserveId`.
    function debtSplitOf(ISpoke spoke, uint256 reserveId, address account)
        internal
        view
        returns (uint256 drawn, uint256 premium)
    {
        return spoke.getUserDebt(reserveId, account);
    }

    /// @notice Position health factor (WAD); `type(uint256).max` when no debt.
    function healthFactor(ISpoke spoke, address account) internal view returns (uint256) {
        return spoke.getUserAccountData(account).healthFactor;
    }

    /// @notice Current user risk premium (feeds the effective V4 borrow rate, PRD decision 28).
    function riskPremium(ISpoke spoke, address account) internal view returns (uint256) {
        return spoke.getUserAccountData(account).riskPremium;
    }

    /// @notice Base drawn (borrow) rate for `assetId` (RAY). Effective user rate = base * (1 + premium).
    function baseDrawnRate(IHub hub, uint256 assetId) internal view returns (uint256) {
        return hub.getAssetDrawnRate(assetId);
    }

    /// @notice Reserve collateral factor (BPS) — V4's borrow-power param (PRD decision 24).
    function collateralFactor(ISpoke spoke, uint256 reserveId) internal view returns (uint256) {
        ISpoke.Reserve memory r = spoke.getReserve(reserveId);
        return spoke.getDynamicReserveConfig(reserveId, r.dynamicConfigKey).collateralFactor;
    }

    /// @notice Oracle price for `reserveId` (reserveId-keyed oracle, PRD decision 29).
    function price(IAaveOracleV4 oracle, uint256 reserveId) internal view returns (uint256) {
        uint256[] memory ids = new uint256[](1);
        ids[0] = reserveId;
        return oracle.getReservesPrices(ids)[0];
    }

    /// @notice Accessors for deriving V4 supply APY (PRD decision 33).
    function assetLiquidity(IHub hub, uint256 assetId) internal view returns (uint256) {
        return hub.getAssetLiquidity(assetId);
    }

    function assetTotalOwed(IHub hub, uint256 assetId) internal view returns (uint256) {
        return hub.getAssetTotalOwed(assetId);
    }

    function assetLiquidityFee(IHub hub, uint256 assetId) internal view returns (uint256) {
        return hub.getAsset(assetId).liquidityFee;
    }

    /// @notice Whether the reserve can accept new leverage (not paused/frozen, borrowable) — PRD decision 23.
    function canLeverage(ISpoke spoke, uint256 reserveId) internal view returns (bool) {
        ISpoke.ReserveConfig memory cfg = spoke.getReserveConfig(reserveId);
        return !cfg.paused && !cfg.frozen && cfg.borrowable;
    }

    /// @notice Whether the reserve can be unwound (not paused); frozen still allows withdraw/repay.
    function canUnwind(ISpoke spoke, uint256 reserveId) internal view returns (bool) {
        return !spoke.getReserveConfig(reserveId).paused;
    }

    /* --------------------------------- WRITES ------------------------------- */

    function supply(ISpoke spoke, uint256 reserveId, uint256 amount) internal returns (uint256 shares) {
        (shares,) = spoke.supply(reserveId, amount, address(this));
    }

    function withdraw(ISpoke spoke, uint256 reserveId, uint256 amount) internal returns (uint256 withdrawn) {
        (, withdrawn) = spoke.withdraw(reserveId, amount, address(this));
    }

    function borrow(ISpoke spoke, uint256 reserveId, uint256 amount) internal returns (uint256 borrowed) {
        (, borrowed) = spoke.borrow(reserveId, amount, address(this));
    }

    function repay(ISpoke spoke, uint256 reserveId, uint256 amount) internal returns (uint256 repaid) {
        (, repaid) = spoke.repay(reserveId, amount, address(this));
    }

    /// @notice Refresh the vault's risk premium before accurate HF/debt reads in rebalance (PRD decision 31).
    function updateRiskPremium(ISpoke spoke) internal {
        spoke.updateUserRiskPremium(address(this));
    }
}
