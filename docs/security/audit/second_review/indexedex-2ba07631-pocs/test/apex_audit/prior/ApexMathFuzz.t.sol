// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ApexMathSymbolic} from "./ApexMathSymbolic.t.sol";

/**
 * @notice APEX — bounded-fuzz execution of the same properties declared in
 *         `ApexMathSymbolic`.
 *
 *         Those properties are named `check_*` because that is the halmos
 *         convention; `forge test` does not collect them. The symbolic run left
 *         6 of 9 as TIMEOUT (nonlinear `mulDiv` — undecidable at any budget we
 *         can afford), so the INVARIANT-battery row for the math library cannot
 *         be closed symbolically.
 *
 *         These wrappers close it the other way: every property is executed as
 *         bounded fuzz, so the row is green by fuzz with symbolic recorded as
 *         attempted-and-inconclusive. Non-vacuity matters here — a property that
 *         `vm.assume`s itself into an empty input set would pass while testing
 *         nothing, so each wrapper is paired with a counter proving live inputs
 *         actually reached the assertion.
 */
contract ApexMathFuzz is ApexMathSymbolic {
    uint256 public reached;

    function test_fuzz_feeNeverIncreases(uint256 a, uint256 f) public {
        f = bound(f, 0, WAD - 1);
        a = bound(a, 0, uint256(type(uint128).max) - 1);
        reached++;
        check_feeNeverIncreases(a, f);
    }

    function test_fuzz_grossUpRecoversNet(uint256 n, uint256 f) public {
        f = bound(f, 0, WAD - 1);
        n = bound(n, 1, uint256(type(uint96).max) - 1);
        reached++;
        check_grossUpRecoversNet(n, f);
    }

    function test_fuzz_feeRoundTripNotProfitable(uint256 n, uint256 f) public {
        f = bound(f, 0, WAD - 1);
        n = bound(n, 1, uint256(type(uint96).max) - 1);
        reached++;
        check_feeRoundTripNotProfitable(n, f);
    }

    function test_fuzz_scaleRoundTripNoInflation(uint256 a, uint256 r) public {
        r = bound(r, 1, 1e27);
        a = bound(a, 0, uint256(type(uint96).max) - 1);
        reached++;
        check_scaleRoundTripNoInflation(a, r);
    }

    function test_fuzz_upVariantsDominate(uint256 a, uint256 r) public {
        r = bound(r, 1, 1e27);
        a = bound(a, 0, uint256(type(uint96).max) - 1);
        reached++;
        check_upVariantsDominate(a, r);
    }

    function test_fuzz_noRewardsWithoutIndexAdvance(uint256 eff, uint256 rps, uint256 paid) public {
        paid = bound(paid, 0, type(uint128).max);
        rps = bound(rps, 0, paid);
        reached++;
        check_noRewardsWithoutIndexAdvance(eff, rps, paid);
    }

    function test_fuzz_rewardsBoundedByDelta(uint256 eff, uint256 rps, uint256 paid) public {
        eff = bound(eff, 0, uint256(type(uint96).max) - 1);
        paid = bound(paid, 0, type(uint64).max);
        rps = bound(rps, paid + 1, paid + uint256(type(uint96).max) - 1);
        reached++;
        check_rewardsBoundedByDelta(eff, rps, paid);
    }

    function test_fuzz_effectiveSharesParityIsIdentity(uint256 s) public {
        s = bound(s, 0, uint256(type(uint96).max) - 1);
        reached++;
        check_effectiveSharesParityIsIdentity(s);
    }

    function test_fuzz_effectiveSharesMonotone(uint256 s, uint256 m) public {
        s = bound(s, 0, uint256(type(uint96).max) - 1);
        m = bound(m, 0, WAD);
        reached++;
        check_effectiveSharesMonotone(s, m);
    }
}
