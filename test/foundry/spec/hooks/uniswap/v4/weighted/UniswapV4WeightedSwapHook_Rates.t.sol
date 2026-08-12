// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4WeightedSwapHook,
    MintableDec,
    RateProviderHarness
} from "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";

contract UniswapV4WeightedSwapHook_Rates_Test is TestBase_UniswapV4WeightedSwapHook {
    function test_R1_rateProviderPath() public {
        MintableDec a = new MintableDec("A", "A", 18);
        MintableDec b = new MintableDec("B", "B", 18);
        (MintableDec t0, MintableDec t1) = address(a) < address(b) ? (a, b) : (b, a);
        RateProviderHarness rp = new RateProviderHarness();
        rp.setRate(2e18);

        address[] memory tokens = new address[](2);
        tokens[0] = address(t0);
        tokens[1] = address(t1);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5e17;
        weights[1] = 5e17;
        address[] memory providers = new address[](2);
        providers[0] = address(rp);
        providers[1] = address(0);

        (address hook,) = _mineAndDeploy(tokens, weights, providers);
        _fundAndApprove(hook, tokens);

        // effectiveRate includes baseScale * oracleRate / 1e18
        uint256 rate0 = IUniswapV4WeightedSwapHook(hook).effectiveRate(0);
        uint256 rate1 = IUniswapV4WeightedSwapHook(hook).effectiveRate(1);
        assertEq(rate0, 2e18); // 18-dec baseScale=1e18, oracle=2e18
        assertEq(rate1, 1e18);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000e18;
        amounts[1] = 2000e18; // 2x to match rate
        vm.prank(user);
        (uint256 shares,) = IUniswapV4WeightedSwapHook(hook).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
        assertGt(shares, 0);
    }

    function test_R2_rateProviderFailClosed() public {
        MintableDec a = new MintableDec("A", "A", 18);
        MintableDec b = new MintableDec("B", "B", 18);
        (MintableDec t0, MintableDec t1) = address(a) < address(b) ? (a, b) : (b, a);
        RateProviderHarness rp = new RateProviderHarness();
        rp.setShouldRevert(true);

        address[] memory tokens = new address[](2);
        tokens[0] = address(t0);
        tokens[1] = address(t1);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5e17;
        weights[1] = 5e17;
        address[] memory providers = new address[](2);
        providers[0] = address(rp);

        (address hook,) = _mineAndDeploy(tokens, weights, providers);
        _fundAndApprove(hook, tokens);

        vm.expectRevert();
        IUniswapV4WeightedSwapHook(hook).effectiveRate(0);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000e18;
        amounts[1] = 1000e18;
        vm.prank(user);
        vm.expectRevert();
        IUniswapV4WeightedSwapHook(hook).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
    }

    function test_R3_badReturndataFailClosed() public {
        MintableDec a = new MintableDec("A", "A", 18);
        MintableDec b = new MintableDec("B", "B", 18);
        (MintableDec t0, MintableDec t1) = address(a) < address(b) ? (a, b) : (b, a);
        RateProviderHarness rp = new RateProviderHarness();
        rp.setBadReturndata(true);

        address[] memory tokens = new address[](2);
        tokens[0] = address(t0);
        tokens[1] = address(t1);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5e17;
        weights[1] = 5e17;
        address[] memory providers = new address[](2);
        providers[0] = address(rp);

        (address hook,) = _mineAndDeploy(tokens, weights, providers);
        vm.expectRevert();
        IUniswapV4WeightedSwapHook(hook).effectiveRate(0);
    }
}
