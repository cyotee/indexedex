// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {RawLegRpSwapCurveQuad} from "./RawLegRpSwapCurveQuad.t.sol";

/// @notice Business-logic adjudication variant of APEX-2026-014 (Curve quad) at production fee parameters.
contract AdjProdCurveQuad is RawLegRpSwapCurveQuad {
    function _run(uint256 rate, uint256 loops) internal returns (int256 p, int256 d) {
        _deployRawRp(rate);
        _ensureFeeTo();
        _setUsageFee(5e16);
        _setDexFee(3e14);
        (p, d) = _attack(rate, loops);
    }

    function test_adj_prod_rate_1_05() public {
        (int256 p, int256 d) = _run(1.05e18, 3);
        assertGt(p, 0, "profit at prod fees");
        assertLt(d, 0, "LP loss");
    }

    function test_adj_prod_rate_1_01() public {
        (int256 p,) = _run(1.01e18, 3);
        assertGt(p, 0, "profit at prod fees r=1.01");
    }

    function test_adj_prod_control_rate_1() public {
        (int256 p,) = _run(1e18, 3);
        assertLt(p, 0, "control loses");
    }
}
