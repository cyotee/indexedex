// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";

import {AaveCrossVersionLoopExchangeBase} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeBase.sol";
import {AaveV4SpokeAwareRepo} from "contracts/protocols/lending/aave/cross-version/AaveV4SpokeAwareRepo.sol";
import {LoopPositionRepo} from "contracts/protocols/lending/aave/cross-version/LoopPositionRepo.sol";
import {AaveV36Service} from "contracts/protocols/lending/aave/cross-version/AaveV36Service.sol";
import {AaveV4Service} from "contracts/protocols/lending/aave/cross-version/AaveV4Service.sol";
import {CrossVersionLoopExecutor} from "contracts/protocols/lending/aave/cross-version/CrossVersionLoopExecutor.sol";
import {CrossVersionLoopService} from "contracts/protocols/lending/aave/cross-version/CrossVersionLoopService.sol";

/**
 * @title AaveCrossVersionLoopRebalanceTarget
 * @author cyotee doge <doge.cyotee>
 * @notice Permissionless rebalance + forceRepay for the cross-version loop vault (PRD decisions
 *         3, 7, 8, 25, 28). `rebalance` re-queries live rates, computes the current orientation's net
 *         carry, and takes one bounded step — de-risk (never-borrow deleverage) when carry is below
 *         threshold or HF is low, else extend — guarded by a minimum interval (anti-churn).
 *         `forceRepay` de-risks permissionlessly when either version's HF is below the safety floor.
 * @dev Thresholds/intervals are placeholder constants; production sources them from the Vault Fee
 *      Oracle (decisions 7, 26). v1 evaluates the A-first orientation (deposit orientation).
 */
contract AaveCrossVersionLoopRebalanceTarget is AaveCrossVersionLoopExchangeBase {
    uint256 internal constant MIN_REBALANCE_INTERVAL = 1 hours; // decision 7 (anti-churn)
    int256 internal constant MIN_SPREAD = 0; // decision 7/26 placeholder
    uint256 internal constant HF_SAFETY_FLOOR = 1.05e18; // decision 4 placeholder

    error RebalanceTooSoon(uint256 nextAllowed);
    error NotAtRisk();

    event Rebalanced(int256 netCarry, bool extended);
    event ForceRepaid();

    /// @notice Net carry (signed, common unit) of the current A-first orientation, from live rates.
    function _currentNetCarry(CrossVersionLoopExecutor.Market memory m) internal view returns (int256) {
        // A-first: supply A on V3, borrow A on V4; supply B on V4, borrow B on V3.
        uint256 sA_v3 = AaveV36Service.supplyRate(m.v36Pool, address(m.tokenA));
        uint256 bB_v3 = AaveV36Service.borrowRate(m.v36Pool, address(m.tokenB));
        uint256 assetIdA = AaveV4SpokeAwareRepo._assetIdOf(address(m.tokenA));
        uint256 assetIdB = AaveV4SpokeAwareRepo._assetIdOf(address(m.tokenB));
        uint256 bA_v4 = CrossVersionLoopService.effectiveV4BorrowRate(
            AaveV4Service.baseDrawnRate(m.v4Hub, assetIdA), AaveV4Service.riskPremium(m.v4Spoke, address(this))
        );
        uint256 sB_v4 = CrossVersionLoopService.deriveV4SupplyRate(
            AaveV4Service.baseDrawnRate(m.v4Hub, assetIdB),
            AaveV4Service.assetLiquidity(m.v4Hub, assetIdB),
            AaveV4Service.assetTotalOwed(m.v4Hub, assetIdB),
            AaveV4Service.assetLiquidityFee(m.v4Hub, assetIdB)
        );
        // Notionals = leveraged supplied exposure (common unit).
        uint256 nA =
            CrossVersionLoopExecutor.valueUsd(m, m.tokenA, AaveV36Service.suppliedOf(m.v36Pool, address(m.tokenA), address(this)));
        uint256 nB = CrossVersionLoopExecutor.valueUsd(
            m, m.tokenB, AaveV4Service.suppliedOf(m.v4Spoke, m.v4ReserveIdB, address(this))
        );
        return CrossVersionLoopService.netCarry(sA_v3, bA_v4, nA, sB_v4, bB_v3, nB);
    }

    /// @dev Test/inspection helper: current orientation net carry.
    function previewNetCarry() external view returns (int256) {
        return _currentNetCarry(_market());
    }

    /// @notice Permissionless rebalance (decision 3). One bounded step (decision 7): de-risk if carry
    ///         is below threshold or HF is low, else extend. Min-interval guarded (anti-churn).
    function rebalance() external {
        uint256 nextAllowed = LoopPositionRepo._lastRebalanceTimestamp() + MIN_REBALANCE_INTERVAL;
        if (block.timestamp < nextAllowed) revert RebalanceTooSoon(nextAllowed);

        CrossVersionLoopExecutor.Market memory m = _market();
        int256 nc = _currentNetCarry(m);
        bool healthy = AaveV36Service.healthFactor(m.v36Pool, address(this)) >= HF_SAFETY_FLOOR
            && AaveV4Service.healthFactor(m.v4Spoke, address(this)) >= HF_SAFETY_FLOOR;

        bool extended;
        if (nc > MIN_SPREAD && healthy) {
            _extendOneStep(m);
            extended = true;
        } else {
            // De-risk one bounded step (never borrow, decision 8/14).
            CrossVersionLoopExecutor.fullUnwind(m, 1);
        }

        LoopPositionRepo._setLastRebalanceTimestamp(block.timestamp);
        emit Rebalanced(nc, extended);
    }

    /// @notice Permissionless force-repay when either version's HF is below the safety floor (decision 3).
    function forceRepay() external {
        CrossVersionLoopExecutor.Market memory m = _market();
        bool atRisk = AaveV36Service.healthFactor(m.v36Pool, address(this)) < HF_SAFETY_FLOOR
            || AaveV4Service.healthFactor(m.v4Spoke, address(this)) < HF_SAFETY_FLOOR;
        if (!atRisk) revert NotAtRisk();
        CrossVersionLoopExecutor.fullUnwind(m, 3);
        emit ForceRepaid();
    }

    /// @dev Extend the loop by one bounded leg using the V3 available-borrow headroom: borrow tokenB
    ///      on V3 and supply it on V4 (re-levering existing collateral).
    function _extendOneStep(CrossVersionLoopExecutor.Market memory m) internal {
        (,, uint256 availableBorrowsBase,,,) = m.v36Pool.getUserAccountData(address(this));
        if (availableBorrowsBase == 0) return;
        uint256 priceB = m.v36Oracle.getAssetPrice(address(m.tokenB));
        uint8 decB = IERC20Metadata(address(m.tokenB)).decimals();
        // Use 50% of headroom for safety; convert base (1e8) to tokenB amount.
        uint256 borrowB = ((availableBorrowsBase / 2) * (10 ** decB)) / priceB;
        if (borrowB == 0) return;
        m.tokenB.approve(address(m.v36Pool), borrowB);
        AaveV36Service.borrow(m.v36Pool, address(m.tokenB), borrowB);
        m.tokenB.approve(address(m.v4Spoke), borrowB);
        AaveV4Service.supply(m.v4Spoke, m.v4ReserveIdB, borrowB);
    }
}
