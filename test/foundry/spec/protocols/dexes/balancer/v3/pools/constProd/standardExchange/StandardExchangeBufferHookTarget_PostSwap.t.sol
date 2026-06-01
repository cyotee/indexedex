// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {AfterSwapParams, SwapKind} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {MockBalancerV3Vault, MockStandardExchange, StaticRateProvider, HookHarness} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/_HookMocks.sol";

contract HookPostSwapTest is Test {
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

    function _afterParams(uint256 amountIn, uint256 amountOut) internal view returns (AfterSwapParams memory) {
        return AfterSwapParams({
            kind: SwapKind.EXACT_IN,
            tokenIn: tta,
            tokenOut: shares,
            amountInScaled18: amountIn,
            amountOutScaled18: amountOut,
            tokenInBalanceScaled18: amountIn,
            tokenOutBalanceScaled18: 100e18 - amountOut,
            amountCalculatedScaled18: amountOut,
            amountCalculatedRaw: amountOut,
            router: address(0),
            pool: address(hook),
            userData: ""
        });
    }

    function test_postSwap_TTAin_executesFourVaultCallsInOrder() public {
        seVault.setAmountIn(10e18);
        vault.setScriptedSettleReturn(10e18);
        vm.prank(address(vault));
        (bool ok, uint256 returned) = hook.onAfterSwap(_afterParams(10e18, 9.090909090909090909e18));
        assertTrue(ok);
        assertEq(returned, 9.090909090909090909e18);
        assertEq(vault.observedCount(), 4);
        assertEq(uint256(vault.observed(0)), uint256(MockBalancerV3Vault.Sel.SEND_TO));
        assertEq(uint256(vault.observed(1)), uint256(MockBalancerV3Vault.Sel.SETTLE));
        assertEq(uint256(vault.observed(2)), uint256(MockBalancerV3Vault.Sel.REMOVE_LIQUIDITY));
        assertEq(uint256(vault.observed(3)), uint256(MockBalancerV3Vault.Sel.ADD_LIQUIDITY));
    }

    function test_postSwap_TTAin_updatesState() public {
        seVault.setAmountIn(10e18);
        vault.setScriptedSettleReturn(10e18);
        vm.prank(address(vault));
        hook.onAfterSwap(_afterParams(10e18, 9.090909090909090909e18));
        assertEq(hook.virtualTTA(), 110e18);
        assertEq(hook.hookSharesDelta(), int256(10e18));
    }

    function test_postSwap_SharesInIsNoOp() public {
        AfterSwapParams memory p = AfterSwapParams({
            kind: SwapKind.EXACT_IN,
            tokenIn: shares,
            tokenOut: tta,
            amountInScaled18: 10e18,
            amountOutScaled18: 9e18,
            tokenInBalanceScaled18: 100e18,
            tokenOutBalanceScaled18: 0,
            amountCalculatedScaled18: 9e18,
            amountCalculatedRaw: 9e18,
            router: address(0),
            pool: address(hook),
            userData: ""
        });
        vm.prank(address(vault));
        (bool ok, uint256 returned) = hook.onAfterSwap(p);
        assertTrue(ok);
        assertEq(returned, 9e18);
        assertEq(vault.observedCount(), 0);
    }

    function test_postSwap_rejectsWrongCaller() public {
        seVault.setAmountIn(10e18);
        vm.prank(address(0xDEAD));
        (bool ok,) = hook.onAfterSwap(_afterParams(10e18, 9e18));
        assertFalse(ok);
    }
}
