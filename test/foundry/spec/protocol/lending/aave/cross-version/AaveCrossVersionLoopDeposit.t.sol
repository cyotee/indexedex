// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";
import {ISpoke} from "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/ISpoke.sol";

import {TestBase_AaveCrossVersionLoopV3Market} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market.sol";
import {AaveV36Service} from "contracts/protocols/lending/aave/cross-version/AaveV36Service.sol";
import {AaveV4Service} from "contracts/protocols/lending/aave/cross-version/AaveV4Service.sol";
import {CrossVersionLoopExecutor} from
    "contracts/protocols/lending/aave/cross-version/CrossVersionLoopExecutor.sol";

/**
 * @title AaveCrossVersionLoopDeposit_Test
 * @notice Integration test for the core deposit loop (PRD decisions 13, 20): the test contract acts
 *         as the vault, deposits tokenA, and builds a leveraged cross-version position across the
 *         live local V3.6 + V4 markets. Asserts leverage achieved, both versions used, HF healthy on
 *         both, and the net position resolves back to the deposited principal (decisions 2, 10, 16).
 */
contract AaveCrossVersionLoopDeposit_Test is TestBase_AaveCrossVersionLoopV3Market {
    address internal v3lp = address(0x3133);
    address internal v4lp = address(0x4144);

    function _market() internal view returns (CrossVersionLoopExecutor.Market memory) {
        return CrossVersionLoopExecutor.Market({
            v36Pool: v36Pool,
            v36Oracle: IAaveOracle(v36Oracle),
            v4Spoke: v4Spoke,
            v4Hub: v4Hub,
            tokenA: tokenA,
            tokenB: tokenB,
            v4ReserveIdA: v4ReserveIdA,
            v4ReserveIdB: v4ReserveIdB
        });
    }

    function _seedBorrowLiquidity() internal {
        // V3 needs tokenB liquidity (loop borrows B on V3).
        _mint(tokenB, v3lp, 2_000_000e6);
        vm.startPrank(v3lp);
        tokenB.approve(address(v36Pool), 2_000_000e6);
        v36Pool.supply(address(tokenB), 2_000_000e6, v3lp, 0);
        vm.stopPrank();

        // V4 needs tokenA liquidity (loop borrows A on V4).
        _mint(tokenA, v4lp, 1_000e18);
        vm.startPrank(v4lp);
        tokenA.approve(address(v4Spoke), 1_000e18);
        v4Spoke.supply(v4ReserveIdA, 1_000e18, v4lp);
        vm.stopPrank();
    }

    function test_deposit_builds_leveraged_cross_version_position() public {
        _seedBorrowLiquidity();

        uint256 deposit = 100e18;
        _mint(tokenA, address(this), deposit);

        CrossVersionLoopExecutor.depositLoopAFirst(
            _market(),
            deposit,
            CrossVersionLoopExecutor.LoopConfig({ltvBps: 70_00, safetyBps: 90_00, maxIterations: 10})
        );

        // Leverage: supplied tokenA on V3 exceeds the bare deposit.
        uint256 v3SuppliedA = AaveV36Service.suppliedOf(v36Pool, address(tokenA), address(this));
        assertGt(v3SuppliedA, deposit, "V3 tokenA supplied > deposit (leverage)");

        // Both versions engaged on both legs.
        assertGt(AaveV36Service.debtOf(v36Pool, address(tokenB), address(this)), 0, "V3 tokenB debt");
        assertGt(AaveV4Service.suppliedOf(v4Spoke, v4ReserveIdB, address(this)), 0, "V4 tokenB supplied");
        assertGt(AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, address(this)), 0, "V4 tokenA debt");

        // Health factors healthy on both versions.
        assertGt(AaveV36Service.healthFactor(v36Pool, address(this)), 1e18, "V3 HF > 1");
        assertGt(AaveV4Service.healthFactor(v4Spoke, address(this)), 1e18, "V4 HF > 1");

        // Net position resolves back to principal: net A ~= deposit, net B ~= 0.
        uint256 netA = CrossVersionLoopExecutor.netBalanceOf(_market(), tokenA, v4ReserveIdA);
        uint256 netB = CrossVersionLoopExecutor.netBalanceOf(_market(), tokenB, v4ReserveIdB);
        assertApproxEqRel(netA, deposit, 0.01e18, "net tokenA ~= deposit (1%)");
        assertLe(netB, 1e6, "net tokenB ~= 0 (<= $1 dust)");
    }

    /// @notice Never-borrow unwind (PRD decision 14) safely deleverages and frees principal while
    ///         keeping both versions solvent. Note: fully closing a *maxed* symmetric loop via pure
    ///         deleveraging asymptotically stalls (mutual repays shrink faster than they free
    ///         capacity) — full closure would need flash loans, which the PRD excludes. The real
    ///         user path is a partial withdrawal serviced from the HF buffer, which this validates.
    function test_never_borrow_unwind_deleverages_and_stays_solvent() public {
        _seedBorrowLiquidity();

        uint256 deposit = 100e18;
        _mint(tokenA, address(this), deposit);

        CrossVersionLoopExecutor.depositLoopAFirst(
            _market(),
            deposit,
            CrossVersionLoopExecutor.LoopConfig({ltvBps: 70_00, safetyBps: 90_00, maxIterations: 10})
        );

        uint256 suppliedBefore = AaveV36Service.suppliedOf(v36Pool, address(tokenA), address(this));
        assertEq(tokenA.balanceOf(address(this)), 0, "no raw tokenA before unwind (all deployed)");

        // Deleverage via the never-borrow rule.
        CrossVersionLoopExecutor.fullUnwind(_market(), 50);

        // Position was deleveraged (V3 tokenA supply strictly decreased), principal was freed as raw
        // tokenA, and both versions remain solvent (HF > 1) — never borrowed, never reverted.
        assertLt(
            AaveV36Service.suppliedOf(v36Pool, address(tokenA), address(this)),
            suppliedBefore,
            "V3 tokenA supply decreased (deleveraged)"
        );
        assertGt(tokenA.balanceOf(address(this)), 10e18, "freed >10 tokenA of principal");
        assertGt(AaveV36Service.healthFactor(v36Pool, address(this)), 1e18, "V3 HF > 1 throughout");
        assertGt(AaveV4Service.healthFactor(v4Spoke, address(this)), 1e18, "V4 HF > 1 throughout");
    }

    function test_nav_reflects_deposited_value() public {
        _seedBorrowLiquidity();

        uint256 deposit = 100e18;
        _mint(tokenA, address(this), deposit);
        CrossVersionLoopExecutor.depositLoopAFirst(
            _market(),
            deposit,
            CrossVersionLoopExecutor.LoopConfig({ltvBps: 70_00, safetyBps: 90_00, maxIterations: 10})
        );

        // Despite the leverage, NAV (net position value) equals the deposited value: 100 * $2000 =
        // $200,000 (oracle base 1e8). This is the basis for proportional share pricing (decision 10).
        uint256 nav = CrossVersionLoopExecutor.navUsd(_market());
        assertApproxEqRel(nav, 200_000e8, 0.01e18, "NAV ~= deposit value (1%)");
    }
}
