// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IVault.sol";
import {SeMatrix_BalancerBufferPoolFixtureBase} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_BalancerBufferPoolFixtureBase.sol";
import {QuadStableBptRateManip} from "./QuadStableBptRateManip.t.sol";

/// Reviewer decomposition: where does the attacker's profit come from (hook LPs vs Balancer pool LPs)?
contract ReviewDecompose is QuadStableBptRateManip {
    function _pool(uint256 i) internal view returns (uint256 sumBal, uint256 supply) {
        SeMatrix_BalancerBufferPoolFixtureBase b = SeMatrix_BalancerBufferPoolFixtureBase(address(fxs[i]));
        (IERC20[] memory toks,, uint256[] memory bals,) = IVault(b.balancerVault()).getPoolTokenInfo(b.se());
        for (uint256 k; k < toks.length; ++k) {
            console2.log("    tok/bal", address(toks[k]), bals[k]);
            sumBal += bals[k];
        }
        supply = IERC20(b.se()).totalSupply();
        console2.log("    sumBal / supply", sumBal, supply);
        console2.log("    value per BPT (1:1 numeraire, 1e18)", sumBal * 1e18 / supply);
    }

    uint256 rs0; uint256 rt0; uint256 rs1; uint256 rt1;

    function _val(uint256 i, uint256 s, uint256 t, uint256 hBefore) internal returns (int256 ext, int256 hk) {
        (uint256 se_, uint256 te_) = _pool(i);
        uint256 he = _hookSeSharesOf(i);
        ext = int256((te_ - he) * se_ / te_) - int256((t - hBefore) * s / t);
        hk = int256(he * se_ / te_) - int256(hBefore * s / t);
    }

    function _decomp(uint256 X, uint256 P) internal returns (int256 profit, int256 ext1, int256 hookNetVal) {
        // snapshot pool states at rest (after honest LP join), then run the same attack
        _setup(200);
        console2.log("== pool0 rest"); (rs0, rt0) = _pool(faceIdx);
        console2.log("== pool1 rest"); (rs1, rt1) = _pool(otherIdx);
        _phase1(X, P);
        profit = int256(IERC20(face).balanceOf(bob0)) - int256(sStart) - int256(P * FLASH_FEE_BPS / 10_000);
        console2.log("attacker net profit:"); console2.logInt(profit);
        console2.log("== pool0 end"); (int256 ext0, int256 hk0) = _val(faceIdx, rs0, rt0, sHb0);
        console2.log("== pool1 end"); int256 hk1; (ext1, hk1) = _val(otherIdx, rs1, rt1, sHf1);
        console2.log("pool0 outside-LP value delta:"); console2.logInt(ext0);
        console2.log("pool1 outside-LP value delta:"); console2.logInt(ext1);
        console2.log("hook leg0 value delta:"); console2.logInt(hk0);
        console2.log("hook leg1 value delta:"); console2.logInt(hk1);
        hookNetVal = hk0 + hk1;
        // Conservative: attribute the ENTIRE pool1 outside-LP dilution (separate pool join/exit anomaly)
        // to the attacker and subtract it. What remains is profit sourced from the rate manipulation.
        console2.log("profit net of pool1 subsidy (conservative):"); console2.logInt(profit + ext1);
    }

    function test_review_decomp_P600() public {
        (int256 profit, int256 ext1, int256 hookNetVal) = _decomp(150e18, 600e18);
        assertGt(profit + ext1, 0, "profit survives removing pool1 subsidy");
        assertLt(hookNetVal, 0, "hook LP value loss");
    }
    function test_review_decomp_P300() public {
        (int256 profit, int256 ext1, int256 hookNetVal) = _decomp(100e18, 300e18);
        console2.log("(P300: conservative bound logged, no assert)"); profit; ext1; hookNetVal;
    }
    function test_review_decomp_control() public { _decomp(100e18, 0); }
}
