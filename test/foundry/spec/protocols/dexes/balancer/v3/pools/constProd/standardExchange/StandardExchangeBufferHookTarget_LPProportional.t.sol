// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {AddLiquidityKind, RemoveLiquidityKind} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {MockBalancerV3Vault, MockStandardExchange, StaticRateProvider, HookHarness} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/_HookMocks.sol";

contract HookLPProportionalTest is Test {
    MockBalancerV3Vault vault;
    MockStandardExchange seVault;
    StaticRateProvider rp;
    HookHarness hook;
    IERC20 tta = IERC20(address(0xAAA));
    IERC20 shares = IERC20(address(0xBBB));

    function setUp() public {
        vault = new MockBalancerV3Vault();
        seVault = new MockStandardExchange();
        rp = new StaticRateProvider(1e18);
        hook = new HookHarness(address(vault), address(0xFAC), tta, shares, seVault, rp);
        hook.setVirtualTTA(100e18);
        hook.setHookSharesDelta(int256(20e18));
    }

    function _mockTotalSupply(uint256 v) internal {
        vm.mockCall(address(hook), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(v));
    }

    function test_onAfterAddLiquidity_scalesProportionally() public {
        // totalSupply() = 100 BPT post-mint; bptOut = 25 -> T_pre = 75
        _mockTotalSupply(100e18);
        vm.prank(address(vault));
        (bool ok, uint256[] memory adj) = hook.onAfterAddLiquidity(
            address(0), address(hook), AddLiquidityKind.PROPORTIONAL,
            new uint256[](2), new uint256[](2), 25e18, new uint256[](2), ""
        );
        assertTrue(ok);
        assertEq(adj.length, 2);
        // virtualTTA += 25 * 100 / 75 = 33.333...e18 -> 133.333...e18
        uint256 bptOut = 25e18;
        uint256 tPre = 75e18;
        uint256 vtPre = 100e18;
        uint256 increment = (bptOut * vtPre) / tPre;
        assertApproxEqAbs(hook.virtualTTA(), vtPre + increment, 1e9);
        // hookSharesDelta += 25 * 20 / 75 = 6.666...e18 -> 26.666...e18
        int256 hPre = int256(20e18);
        uint256 hIncrement = (bptOut * uint256(hPre)) / tPre;
        assertApproxEqAbs(hook.hookSharesDelta(), hPre + int256(hIncrement), 1e9);
    }

    function test_onAfterRemoveLiquidity_scalesProportionallyDown() public {
        // totalSupply() = 75 BPT post-burn; bptIn = 25 -> T_pre = 100
        _mockTotalSupply(75e18);
        vm.prank(address(vault));
        (bool ok, uint256[] memory adj) = hook.onAfterRemoveLiquidity(
            address(0), address(hook), RemoveLiquidityKind.PROPORTIONAL,
            25e18, new uint256[](2), new uint256[](2), new uint256[](2), ""
        );
        assertTrue(ok);
        assertEq(adj.length, 2);
        // virtualTTA -= 25 * 100 / 100 = 25 -> 75e18
        uint256 expectedVT = 100e18 - 25e18;
        assertApproxEqAbs(hook.virtualTTA(), expectedVT, 1e9);
        // hookSharesDelta -= 25 * 20 / 100 = 5 -> 15e18
        int256 expectedHS = int256(20e18) - int256(5e18);
        assertApproxEqAbs(hook.hookSharesDelta(), expectedHS, 1e9);
    }

    function test_onAfterRemoveLiquidity_clampsVirtualTTAAtZero() public {
        hook.setVirtualTTA(100e18);
        // totalSupply() = 99e18 post-burn; bptIn = 100e18 -> T_pre = 199e18
        // vtSub = 100e18 * 100e18 / 199e18 ≈ 50.25e18
        _mockTotalSupply(99e18);
        vm.prank(address(vault));
        hook.onAfterRemoveLiquidity(
            address(0), address(hook), RemoveLiquidityKind.PROPORTIONAL,
            100e18, new uint256[](2), new uint256[](2), new uint256[](2), ""
        );
        // vtSub calculation: bptIn * vtPre / tPre
        uint256 bptIn = 100e18;
        uint256 vtPre = 100e18;
        uint256 tPre = 199e18;
        uint256 vtSub = (bptIn * vtPre) / tPre;
        assertApproxEqAbs(hook.virtualTTA(), vtPre - vtSub, 1e9);
    }

    function test_onAfterAddLiquidity_rejectsWrongCaller() public {
        _mockTotalSupply(100e18);
        vm.prank(address(0xDEAD));
        (bool ok, ) = hook.onAfterAddLiquidity(
            address(0), address(hook), AddLiquidityKind.PROPORTIONAL,
            new uint256[](2), new uint256[](2), 25e18, new uint256[](2), ""
        );
        assertFalse(ok);
    }

    function test_onAfterRemoveLiquidity_rejectsWrongPool() public {
        _mockTotalSupply(75e18);
        vm.prank(address(vault));
        (bool ok, ) = hook.onAfterRemoveLiquidity(
            address(0), address(0xBAD), RemoveLiquidityKind.PROPORTIONAL,
            25e18, new uint256[](2), new uint256[](2), new uint256[](2), ""
        );
        assertFalse(ok);
    }
}
