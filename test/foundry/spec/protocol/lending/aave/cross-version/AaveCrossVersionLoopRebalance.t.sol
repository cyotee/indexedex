// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolAddressesProvider} from
    "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPoolAddressesProvider.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";
import {IAaveOracle as IAaveOracleV4} from
    "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/IAaveOracle.sol";

import {TestBase_AaveCrossVersionLoopV3Market} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market.sol";
import {AaveCrossVersionLoopExchangeBase} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeBase.sol";
import {AaveCrossVersionLoopExchangeInTarget} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeInTarget.sol";
import {AaveCrossVersionLoopRebalanceTarget} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopRebalanceTarget.sol";
import {AaveV36Service} from "contracts/protocols/lending/aave/cross-version/AaveV36Service.sol";
import {AaveV4Service} from "contracts/protocols/lending/aave/cross-version/AaveV4Service.sol";

/// @dev Combined In + Rebalance vault mirroring the diamond (shared storage).
contract _RebalVault is AaveCrossVersionLoopExchangeInTarget, AaveCrossVersionLoopRebalanceTarget {}

/**
 * @title AaveCrossVersionLoopRebalance_Test
 * @notice Integration test for permissionless rebalance + forceRepay (PRD decisions 3, 7, 8).
 *         Validates the min-interval anti-churn gate, the de-risk action under negative carry
 *         (never-borrow, stays solvent), and forceRepay's not-at-risk revert.
 */
contract AaveCrossVersionLoopRebalance_Test is TestBase_AaveCrossVersionLoopV3Market {
    _RebalVault internal vault;
    address internal v3lp = address(0x3133);
    address internal v4lp = address(0x4144);
    address internal v4borrower = address(0x4099);

    function _initVault() internal {
        vault = new _RebalVault();
        vault.initCrossVersionLoop(
            AaveCrossVersionLoopExchangeBase.InitArgs({
                v36Pool: v36Pool,
                v36AddressesProvider: IPoolAddressesProvider(v36AddressesProvider),
                v36Oracle: IAaveOracle(v36Oracle),
                v4Spoke: v4Spoke,
                v4Hub: v4Hub,
                v4Oracle: IAaveOracleV4(address(v4Oracle)),
                tokenA: tokenA,
                tokenB: tokenB,
                v4AssetIdA: v4AssetIdA,
                v4ReserveIdA: v4ReserveIdA,
                v4AssetIdB: v4AssetIdB,
                v4ReserveIdB: v4ReserveIdB,
                shareName: "Cross Loop Vault",
                shareSymbol: "CLV"
            })
        );
    }

    function _seedAndDeposit() internal {
        _mint(tokenB, v3lp, 4_000_000e6);
        vm.startPrank(v3lp);
        tokenB.approve(address(v36Pool), 4_000_000e6);
        v36Pool.supply(address(tokenB), 4_000_000e6, v3lp, 0);
        vm.stopPrank();

        _mint(tokenA, v4lp, 2_000e18);
        vm.startPrank(v4lp);
        tokenA.approve(address(v4Spoke), 2_000e18);
        v4Spoke.supply(v4ReserveIdA, 2_000e18, v4lp);
        vm.stopPrank();

        _mint(tokenA, address(this), 100e18);
        tokenA.approve(address(vault), 100e18);
        vault.exchangeIn(tokenA, 100e18, IERC20(address(vault)), 0, address(this), false, block.timestamp);
    }

    /// @dev Spike V4 tokenA borrow utilization so V4 borrow rate >> V3 supply rate → negative carry.
    function _spikeV4ABorrow() internal {
        _mint(tokenB, v4borrower, 6_000_000e6);
        vm.startPrank(v4borrower);
        tokenB.approve(address(v4Spoke), 6_000_000e6);
        v4Spoke.supply(v4ReserveIdB, 6_000_000e6, v4borrower);
        v4Spoke.setUsingAsCollateral(v4ReserveIdB, true, v4borrower);
        v4Spoke.borrow(v4ReserveIdA, 1_500e18, v4borrower); // drains V4 tokenA → high borrow rate
        vm.stopPrank();
    }

    function test_rebalance_respects_min_interval() public {
        _initVault();
        _seedAndDeposit();

        vm.warp(block.timestamp + 2 hours);
        vault.rebalance(); // first rebalance ok

        vm.expectRevert(); // immediate second call within the interval reverts (anti-churn)
        vault.rebalance();
    }

    function test_rebalance_derisks_on_negative_carry() public {
        _initVault();
        _seedAndDeposit();
        _spikeV4ABorrow();

        uint256 suppliedBefore = AaveV36Service.suppliedOf(v36Pool, address(tokenA), address(vault));
        assertLt(vault.previewNetCarry(), int256(0), "carry is negative after spike");

        vm.warp(block.timestamp + 2 hours);
        vault.rebalance();

        // Negative carry → de-risk: V3 tokenA supply decreased, vault stays solvent on both versions.
        assertLt(
            AaveV36Service.suppliedOf(v36Pool, address(tokenA), address(vault)),
            suppliedBefore,
            "de-risked (V3 supply down)"
        );
        assertGt(AaveV36Service.healthFactor(v36Pool, address(vault)), 1e18, "V3 HF > 1");
        assertGt(AaveV4Service.healthFactor(v4Spoke, address(vault)), 1e18, "V4 HF > 1");
    }

    function test_forceRepay_reverts_when_healthy() public {
        _initVault();
        _seedAndDeposit();

        vm.expectRevert(AaveCrossVersionLoopRebalanceTarget.NotAtRisk.selector);
        vault.forceRepay();
    }
}
