// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";
import {ISpoke} from "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/ISpoke.sol";
import {AaveV36Service} from "contracts/protocols/lending/aave/cross-version/AaveV36Service.sol";
import {AaveV4Service} from "contracts/protocols/lending/aave/cross-version/AaveV4Service.sol";
import {CrossVersionLoopExecutor} from
    "contracts/protocols/lending/aave/cross-version/CrossVersionLoopExecutor.sol";
import {TestBase_AaveCrossVersionLoopV3Market_Decimals} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market_Decimals.sol";

/// @notice Deposit-loop money paths on each two-token combo. pairToken = tokenA.
abstract contract AaveCrossVersionLoopDeposit_Decimals is TestBase_AaveCrossVersionLoopV3Market_Decimals {
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
        _mint(tokenB, v3lp, _uB(2_000_000));
        vm.startPrank(v3lp);
        tokenB.approve(address(v36Pool), _uB(2_000_000));
        v36Pool.supply(address(tokenB), _uB(2_000_000), v3lp, 0);
        vm.stopPrank();

        _mint(tokenA, v4lp, _uA(1_000));
        vm.startPrank(v4lp);
        tokenA.approve(address(v4Spoke), _uA(1_000));
        v4Spoke.supply(v4ReserveIdA, _uA(1_000), v4lp);
        vm.stopPrank();
    }

    function test_deposit_builds_leveraged_cross_version_position() public {
        _seedBorrowLiquidity();
        uint256 deposit = _uA(100);
        _mint(tokenA, address(this), deposit);
        CrossVersionLoopExecutor.depositLoopAFirst(
            _market(),
            deposit,
            CrossVersionLoopExecutor.LoopConfig({ltvBps: 70_00, safetyBps: 90_00, maxIterations: 10})
        );
        uint256 v3SuppliedA = AaveV36Service.suppliedOf(v36Pool, address(tokenA), address(this));
        assertGt(v3SuppliedA, deposit, "V3 tokenA supplied > deposit (leverage)");
        assertGt(AaveV36Service.debtOf(v36Pool, address(tokenB), address(this)), 0, "V3 tokenB debt");
        assertGt(AaveV4Service.suppliedOf(v4Spoke, v4ReserveIdB, address(this)), 0, "V4 tokenB supplied");
        assertGt(AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, address(this)), 0, "V4 tokenA debt");
        assertGt(AaveV36Service.healthFactor(v36Pool, address(this)), 1e18, "V3 HF > 1");
        assertGt(AaveV4Service.healthFactor(v4Spoke, address(this)), 1e18, "V4 HF > 1");
        uint256 netA = CrossVersionLoopExecutor.netBalanceOf(_market(), tokenA, v4ReserveIdA);
        uint256 netB = CrossVersionLoopExecutor.netBalanceOf(_market(), tokenB, v4ReserveIdB);
        assertApproxEqRel(netA, deposit, 0.01e18, "net tokenA ~= deposit (1%)");
        assertLe(netB, _uB(1), "net tokenB ~= 0");
    }

    function test_never_borrow_unwind_deleverages_and_stays_solvent() public {
        _seedBorrowLiquidity();
        uint256 deposit = _uA(100);
        _mint(tokenA, address(this), deposit);
        CrossVersionLoopExecutor.depositLoopAFirst(
            _market(),
            deposit,
            CrossVersionLoopExecutor.LoopConfig({ltvBps: 70_00, safetyBps: 90_00, maxIterations: 10})
        );
        uint256 suppliedBefore = AaveV36Service.suppliedOf(v36Pool, address(tokenA), address(this));
        assertEq(tokenA.balanceOf(address(this)), 0, "no raw tokenA before unwind");
        CrossVersionLoopExecutor.fullUnwind(_market(), 50);
        assertLt(
            AaveV36Service.suppliedOf(v36Pool, address(tokenA), address(this)),
            suppliedBefore,
            "V3 tokenA supply decreased"
        );
        assertGt(tokenA.balanceOf(address(this)), _uA(10), "freed >10 tokenA of principal");
        assertGt(AaveV36Service.healthFactor(v36Pool, address(this)), 1e18, "V3 HF > 1");
        assertGt(AaveV4Service.healthFactor(v4Spoke, address(this)), 1e18, "V4 HF > 1");
    }

    function test_nav_reflects_deposited_value() public {
        _seedBorrowLiquidity();
        uint256 deposit = _uA(100);
        _mint(tokenA, address(this), deposit);
        CrossVersionLoopExecutor.depositLoopAFirst(
            _market(),
            deposit,
            CrossVersionLoopExecutor.LoopConfig({ltvBps: 70_00, safetyBps: 90_00, maxIterations: 10})
        );
        uint256 nav = CrossVersionLoopExecutor.navUsd(_market());
        assertApproxEqRel(nav, 200_000e8, 0.01e18, "NAV ~= deposit value (1%)");
    }
}
