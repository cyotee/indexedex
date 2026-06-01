// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {AddLiquidityKind} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {MockBalancerV3Vault, MockStandardExchange, StaticRateProvider, HookHarness} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/_HookMocks.sol";

contract HookLPAddTest is Test {
    MockBalancerV3Vault vault;
    MockStandardExchange seVault;
    StaticRateProvider rp;
    HookHarness hook;
    address ttaAddr = address(0xAAA);
    address shareAddr = address(0xBBB);
    IERC20 tta = IERC20(ttaAddr);
    IERC20 shares = IERC20(shareAddr);

    function setUp() public {
        vault = new MockBalancerV3Vault();
        seVault = new MockStandardExchange();
        rp = new StaticRateProvider(1e18);
        vm.mockCall(shareAddr, abi.encodeWithSignature("decimals()"), abi.encode(uint8(18)));
        vm.mockCall(ttaAddr, abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
        hook = new HookHarness(address(vault), address(0xFAC), tta, shares, seVault, rp);
        hook.setVirtualTTA(100e18);
        hook.setHookSharesDelta(0);
    }

    function test_revertsForUnbalanced() public {
        uint256[] memory max = new uint256[](2); max[0] = 10e18; max[1] = 10e18;
        vm.expectRevert(IStandardExchangeBufferPool.AddLiquidityNotProportional.selector);
        vm.prank(address(vault));
        hook.onBeforeAddLiquidity(address(0), address(hook), AddLiquidityKind.UNBALANCED, max, 0, new uint256[](2), "");
    }

    function test_revertsForSingleTokenExactOut() public {
        uint256[] memory max = new uint256[](2); max[0] = 10e18; max[1] = 0;
        vm.expectRevert(IStandardExchangeBufferPool.AddLiquidityNotProportional.selector);
        vm.prank(address(vault));
        hook.onBeforeAddLiquidity(address(0), address(hook), AddLiquidityKind.SINGLE_TOKEN_EXACT_OUT, max, 0, new uint256[](2), "");
    }

    function test_customIsNoOp() public {
        uint256[] memory max = new uint256[](2); max[0] = 5e18; max[1] = 0;
        vm.prank(address(vault));
        bool ok = hook.onBeforeAddLiquidity(address(0), address(hook), AddLiquidityKind.CUSTOM, max, 0, new uint256[](2), "");
        assertTrue(ok);
        assertEq(vault.observedCount(), 0);
    }

    function test_proportionalWithoutTTA_skipsConversion() public {
        uint256[] memory max = new uint256[](2); max[0] = 0; max[1] = 5e18;
        vm.prank(address(vault));
        bool ok = hook.onBeforeAddLiquidity(address(0), address(hook), AddLiquidityKind.PROPORTIONAL, max, 0, new uint256[](2), "");
        assertTrue(ok);
        assertEq(hook.hookSharesDelta(), 0);
        assertEq(vault.observedCount(), 0);
    }

    function test_proportionalWithTTA_convertsAndReconciles() public {
        uint256[] memory max = new uint256[](2); max[0] = 5e18; max[1] = 5e18;
        seVault.setAmountIn(5e18); // exchangeIn returns 5 new shares
        vault.setScriptedSettleReturn(5e18);
        vm.prank(address(vault));
        bool ok = hook.onBeforeAddLiquidity(address(0), address(hook), AddLiquidityKind.PROPORTIONAL, max, 0, new uint256[](2), "");
        assertTrue(ok);
        assertEq(hook.hookSharesDelta(), int256(5e18));
        // 4 vault calls: sendTo, settle, removeLiquidity (custom remove of TTA), addLiquidity (donate shares)
        assertEq(vault.observedCount(), 4);
    }

    function test_rejectsWrongCaller() public {
        uint256[] memory max = new uint256[](2); max[0] = 5e18; max[1] = 5e18;
        vm.prank(address(0xDEAD));
        bool ok = hook.onBeforeAddLiquidity(address(0), address(hook), AddLiquidityKind.PROPORTIONAL, max, 0, new uint256[](2), "");
        assertFalse(ok);
    }

    function test_rejectsWrongPool() public {
        uint256[] memory max = new uint256[](2); max[0] = 5e18; max[1] = 5e18;
        vm.prank(address(vault));
        bool ok = hook.onBeforeAddLiquidity(address(0), address(0xBAD), AddLiquidityKind.PROPORTIONAL, max, 0, new uint256[](2), "");
        assertFalse(ok);
    }
}
