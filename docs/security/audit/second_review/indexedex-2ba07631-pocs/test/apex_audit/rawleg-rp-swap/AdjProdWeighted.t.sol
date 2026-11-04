// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {RawLegRpSwap} from "./RawLegRpSwap.t.sol";

/// @notice Business-logic adjudication variant of APEX-2026-014 (weighted): production fee parameters
///         from scripts/foundry/anvil_robinhood_main/FixtureEconomics.sol (DEX_SWAP_FEE = 3e14, USAGE_FEE = 5e16,
///         feeTo set) and a realistic yield-token rate (1.05, 1.01). Attacker uses only its own capital.
contract AdjProdWeighted is RawLegRpSwap {
    function _prodFees() internal {
        _ensureFeeTo();
        _setUsageFee(5e16);
        _setDexFee(3e14);
    }

    function _run(uint256 rate, uint256 loops) internal returns (int256 p, int256 d) {
        _deployRawRp(rate);
        _prodFees();
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
