// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IPool} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPool.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";
import {ISpoke} from "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/ISpoke.sol";
import {IHub} from "@crane/contracts/protocols/lending/aave/v4/hub/interfaces/IHub.sol";

import {AaveV36Service} from "contracts/protocols/lending/aave/cross-version/AaveV36Service.sol";
import {AaveV4Service} from "contracts/protocols/lending/aave/cross-version/AaveV4Service.sol";

/**
 * @title CrossVersionLoopExecutor
 * @author cyotee doge <doge.cyotee>
 * @notice Core recursive cross-version leverage loop (PRD decisions 13, 20). Runs in the position
 *         holder's context (the vault) via the Service libs, which use `address(this)`.
 * @dev Geometric leverage: supply the deposit on V3, then per iteration borrow the paired token on
 *      one version (up to `ltvBps * safetyBps` of the freshly-added collateral) and supply it on the
 *      other version, alternating, until the layer shrinks below a dust threshold or `maxIterations`.
 *      Sizing uses the V3 oracle for both tokens (common USD scale). A precise target-LTV stop and
 *      live-HF gate per leg are refined when wired into the rebalance/exchange facets.
 */
library CrossVersionLoopExecutor {
    using AaveV36Service for IPool;
    using AaveV4Service for ISpoke;

    uint256 internal constant BPS = 1e4;
    uint256 internal constant MIN_LAYER_USD = 1e8; // $1 (oracle base 1e8) dust floor

    struct Market {
        IPool v36Pool;
        IAaveOracle v36Oracle;
        ISpoke v4Spoke;
        IHub v4Hub;
        IERC20 tokenA;
        IERC20 tokenB;
        uint256 v4ReserveIdA;
        uint256 v4ReserveIdB;
    }

    struct LoopConfig {
        uint256 ltvBps; // per-leg LTV cap to borrow against fresh collateral
        uint256 safetyBps; // fraction of the LTV actually used (margin)
        uint256 maxIterations;
    }

    /// @dev USD value (oracle base 1e8) of `amount` of a token with `decimals` at `price` (1e8).
    function _toUsd(uint256 amount, uint8 decimals, uint256 price) internal pure returns (uint256) {
        return (amount * price) / (10 ** decimals);
    }

    /// @dev Token amount for a target USD value (oracle base 1e8).
    function _fromUsd(uint256 usd, uint8 decimals, uint256 price) internal pure returns (uint256) {
        return (usd * (10 ** decimals)) / price;
    }

    /// @notice Deposit `amountA` of tokenA and build the leveraged cross-version loop (A-first):
    ///         supply A on V3, borrow B on V3, supply B on V4, borrow A on V4, supply A on V3, repeat.
    function depositLoopAFirst(Market memory m, uint256 amountA, LoopConfig memory cfg) internal {
        // One-time max approvals to both venues for both tokens.
        m.tokenA.approve(address(m.v36Pool), type(uint256).max);
        m.tokenB.approve(address(m.v36Pool), type(uint256).max);
        m.tokenA.approve(address(m.v4Spoke), type(uint256).max);
        m.tokenB.approve(address(m.v4Spoke), type(uint256).max);

        uint256 priceA = m.v36Oracle.getAssetPrice(address(m.tokenA));
        uint256 priceB = m.v36Oracle.getAssetPrice(address(m.tokenB));
        uint8 decA = IERC20Metadata(address(m.tokenA)).decimals();
        uint8 decB = IERC20Metadata(address(m.tokenB)).decimals();

        uint256 factorBps = (cfg.ltvBps * cfg.safetyBps) / BPS; // effective per-leg borrow fraction

        // Initial collateral.
        AaveV36Service.supply(m.v36Pool, address(m.tokenA), amountA);

        // Borrow capacity (USD) created by the initial collateral.
        uint256 layerUsd = (_toUsd(amountA, decA, priceA) * factorBps) / BPS;

        for (uint256 i = 0; i < cfg.maxIterations; ++i) {
            if (layerUsd < MIN_LAYER_USD) break;

            // Borrow B on V3, supply B on V4 (enable as collateral on first V4 supply).
            uint256 borrowB = _fromUsd(layerUsd, decB, priceB);
            AaveV36Service.borrow(m.v36Pool, address(m.tokenB), borrowB);
            AaveV4Service.supply(m.v4Spoke, m.v4ReserveIdB, borrowB);
            if (i == 0) m.v4Spoke.setUsingAsCollateral(m.v4ReserveIdB, true, address(this));

            // Borrow A on V4 against the freshly supplied B, supply A back on V3.
            uint256 nextUsd = (layerUsd * factorBps) / BPS;
            if (nextUsd < MIN_LAYER_USD) break;
            uint256 borrowA = _fromUsd(nextUsd, decA, priceA);
            AaveV4Service.borrow(m.v4Spoke, m.v4ReserveIdA, borrowA);
            AaveV36Service.supply(m.v36Pool, address(m.tokenA), borrowA);

            layerUsd = (nextUsd * factorBps) / BPS;
        }
    }

    /// @dev Fraction (WAD) of collateral safely removable to keep HF >= ~1.05, with a 5% extra
    ///      margin. Version-agnostic (works off the reported HF). Returns 0 if HF is already tight.
    function _safeFraction(uint256 hf) internal pure returns (uint256) {
        uint256 floorHf = 1.05e18;
        if (hf <= floorHf + 0.01e18) return 0;
        // Removing fraction f of collateral lowers HF roughly proportionally (collateral-dominated
        // position): newHF ~= hf*(1-f). Keep newHF >= floorHf => f <= 1 - floorHf/hf. Apply 95% margin.
        uint256 f = 1e18 - (floorHf * 1e18) / hf;
        return (f * 95) / 100;
    }

    /// @notice Fully unwind the loop using the never-borrow rule (PRD decision 14): alternately
    ///         withdraw an HF-safe fraction of collateral and repay debt across versions until debt
    ///         clears, then withdraw the remainder. Never borrows; HF stays >= ~1.05 each step, so it
    ///         never reverts on the HF edge. Leaves net tokenA + tokenB as raw balances.
    function fullUnwind(Market memory m, uint256 maxIterations) internal {
        m.tokenA.approve(address(m.v36Pool), type(uint256).max);
        m.tokenB.approve(address(m.v36Pool), type(uint256).max);
        m.tokenA.approve(address(m.v4Spoke), type(uint256).max);
        m.tokenB.approve(address(m.v4Spoke), type(uint256).max);

        for (uint256 i = 0; i < maxIterations; ++i) {
            bool progressed = false;

            // V4 side: withdraw an HF-safe fraction of tokenB collateral, repay V3 tokenB debt.
            if (AaveV36Service.debtOf(m.v36Pool, address(m.tokenB), address(this)) > 0) {
                uint256 suppliedB = AaveV4Service.suppliedOf(m.v4Spoke, m.v4ReserveIdB, address(this));
                uint256 wB = (suppliedB * _safeFraction(AaveV4Service.healthFactor(m.v4Spoke, address(this)))) / 1e18;
                if (wB > 0) {
                    AaveV4Service.withdraw(m.v4Spoke, m.v4ReserveIdB, wB);
                    progressed = true;
                }
                uint256 rawB = m.tokenB.balanceOf(address(this));
                if (rawB > 0) {
                    AaveV36Service.repay(m.v36Pool, address(m.tokenB), rawB);
                    progressed = true;
                }
            }

            // V3 side: withdraw an HF-safe fraction of tokenA collateral, repay V4 tokenA debt.
            if (AaveV4Service.debtOf(m.v4Spoke, m.v4ReserveIdA, address(this)) > 0) {
                uint256 suppliedA = AaveV36Service.suppliedOf(m.v36Pool, address(m.tokenA), address(this));
                uint256 wA = (suppliedA * _safeFraction(AaveV36Service.healthFactor(m.v36Pool, address(this)))) / 1e18;
                if (wA > 0) {
                    AaveV36Service.withdraw(m.v36Pool, address(m.tokenA), wA);
                    progressed = true;
                }
                uint256 rawA = m.tokenA.balanceOf(address(this));
                if (rawA > 0) {
                    AaveV4Service.repay(m.v4Spoke, m.v4ReserveIdA, rawA);
                    progressed = true;
                }
            }

            if (!progressed) break;
        }

        // Once a side's debt is fully cleared, its collateral is unconstrained: withdraw all of it.
        if (AaveV36Service.debtOf(m.v36Pool, address(m.tokenB), address(this)) == 0) {
            if (AaveV36Service.suppliedOf(m.v36Pool, address(m.tokenA), address(this)) > 0) {
                AaveV36Service.withdraw(m.v36Pool, address(m.tokenA), type(uint256).max);
            }
        }
        if (AaveV4Service.debtOf(m.v4Spoke, m.v4ReserveIdA, address(this)) == 0) {
            if (AaveV4Service.suppliedOf(m.v4Spoke, m.v4ReserveIdB, address(this)) > 0) {
                AaveV4Service.withdraw(m.v4Spoke, m.v4ReserveIdB, type(uint256).max);
            }
        }
    }

    /// @notice Net balance (post-unwind) of `token` across both versions: supplied - debt, floored at 0.
    function netBalanceOf(Market memory m, IERC20 token, uint256 v4ReserveId)
        internal
        view
        returns (uint256)
    {
        uint256 supplied = AaveV36Service.suppliedOf(m.v36Pool, address(token), address(this))
            + AaveV4Service.suppliedOf(m.v4Spoke, v4ReserveId, address(this));
        uint256 debt = AaveV36Service.debtOf(m.v36Pool, address(token), address(this))
            + AaveV4Service.debtOf(m.v4Spoke, v4ReserveId, address(this));
        return supplied >= debt ? supplied - debt : 0;
    }

    /// @notice Max tokenA directly withdrawable from V3 now, keeping HF safe (5% margin). This is the
    ///         amount a single-token withdrawal can free from the buffer without deleveraging
    ///         (PRD decisions 14, 15). Larger withdrawals (requiring deleverage) are a later refinement.
    function maxWithdrawableA(Market memory m) internal view returns (uint256) {
        uint256 suppliedA = AaveV36Service.suppliedOf(m.v36Pool, address(m.tokenA), address(this));
        (uint256 totalColl, uint256 totalDebt,, uint256 liqThresh,,) = m.v36Pool.getUserAccountData(address(this));
        if (totalDebt == 0) return suppliedA;
        uint256 needColl = (totalDebt * BPS) / liqThresh;
        if (totalColl <= needColl) return 0;
        uint256 priceA = m.v36Oracle.getAssetPrice(address(m.tokenA));
        uint256 removableA =
            ((totalColl - needColl) * (10 ** IERC20Metadata(address(m.tokenA)).decimals())) / priceA;
        removableA = (removableA * 95) / 100; // HF safety margin
        return removableA < suppliedA ? removableA : suppliedA;
    }

    /// @notice Withdraw `amount` of tokenA from V3 supply to the vault (never borrows).
    function withdrawA(Market memory m, uint256 amount) internal returns (uint256) {
        return AaveV36Service.withdraw(m.v36Pool, address(m.tokenA), amount);
    }

    /// @notice Common-unit USD value (oracle base 1e8) of `amount` of a pair token.
    function valueUsd(Market memory m, IERC20 token, uint256 amount) internal view returns (uint256) {
        uint256 price = m.v36Oracle.getAssetPrice(address(token));
        return _toUsd(amount, IERC20Metadata(address(token)).decimals(), price);
    }

    /// @notice Net position value (NAV) in the common USD unit (oracle base 1e8), reconciled live
    ///         from Aave (PRD decisions 2, 10): netA*priceA + netB*priceB. Used for share pricing.
    function navUsd(Market memory m) internal view returns (uint256) {
        uint256 priceA = m.v36Oracle.getAssetPrice(address(m.tokenA));
        uint256 priceB = m.v36Oracle.getAssetPrice(address(m.tokenB));
        uint256 netA = netBalanceOf(m, m.tokenA, m.v4ReserveIdA);
        uint256 netB = netBalanceOf(m, m.tokenB, m.v4ReserveIdB);
        return _toUsd(netA, IERC20Metadata(address(m.tokenA)).decimals(), priceA)
            + _toUsd(netB, IERC20Metadata(address(m.tokenB)).decimals(), priceB);
    }
}
