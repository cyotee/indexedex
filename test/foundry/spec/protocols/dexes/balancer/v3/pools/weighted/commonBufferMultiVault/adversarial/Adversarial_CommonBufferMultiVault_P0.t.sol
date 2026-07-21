// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolLiquidity} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolLiquidity.sol";
import {IHooks} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";
import {
    RemoveLiquidityKind,
    HooksConfig
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";

import {ICommonBufferMultiVaultWeightedPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/ICommonBufferMultiVaultWeightedPool.sol";
import {
    TestBase_CommonBufferMultiVaultWeightedPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/bases/TestBase_CommonBufferMultiVaultWeightedPool.sol";

/**
 * @title Adversarial_CommonBufferMultiVault_P0
 * @notice P0: D1/D2 CUSTOM, F3 hooks, A3 donation, E7 residual, R1 buffer-only remove, W1 walk exhaust path smoke.
 */
contract Adversarial_CommonBufferMultiVault_P0 is TestBase_CommonBufferMultiVaultWeightedPool {
    function _targetVaultCount() internal pure override returns (uint8) {
        return 2;
    }

    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
    }

    function test_D1_customRemove_revertsNotHookCaller() public {
        uint256[] memory minOut = new uint256[](3);
        minOut[0] = 1e18;
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(ICommonBufferMultiVaultWeightedPool.NotHookCaller.selector, attacker));
        IPoolLiquidity(cbmvPool).onRemoveLiquidityCustom(attacker, 0, minOut, minOut, "");
    }

    function test_D2_customAdd_revertsNotHookCaller() public {
        uint256[] memory maxIn = new uint256[](3);
        maxIn[0] = 1e18;
        vm.expectRevert(abi.encodeWithSelector(ICommonBufferMultiVaultWeightedPool.NotHookCaller.selector, attacker));
        IPoolLiquidity(cbmvPool).onAddLiquidityCustom(attacker, maxIn, 0, maxIn, "");
    }

    function test_F3_hooksInProxy() public view {
        IHooks(cbmvPool).getHookFlags();
        HooksConfig memory hc = bv3Vault.getHooksConfig(cbmvPool);
        assertEq(hc.hooksContract, cbmvPool, "hooksContract == pool");
        assertEq(cbmv().vaultCount(), 2);
    }

    function test_A3_donation_noFreeBpt() public {
        uint256 bptBefore = IERC20(cbmvPool).totalSupply();
        uint256 vtBefore = cbmv().virtualBuffer();
        dai.mint(alice, 40e18);
        uint256[] memory amounts = new uint256[](3);
        amounts[cbmv().bufferIndex()] = 40e18;
        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        router.donate(cbmvPool, amounts, false, bytes(""));
        vm.stopPrank();
        assertEq(IERC20(cbmvPool).totalSupply(), bptBefore);
        assertEq(cbmv().virtualBuffer(), vtBefore);
    }

    function test_E7_eventualZero_afterBufferIn() public {
        uint256 amountIn = 20e18;
        dai.mint(alice, amountIn);
        uint256 rawBefore = rawPoolBufferBalance();
        swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), amountIn);
        assertApproxEqAbs(rawPoolBufferBalance(), rawBefore, 100, "buffer-in net residual (peer E7)");
    }

    function test_R1_bufferOnlySingleTokenRemove_reverts() public {
        // Single-token exact-in remove targeting buffer should hit L23 in onBeforeRemoveLiquidity.
        uint256 bptBal = IERC20(cbmvPool).balanceOf(alice);
        require(bptBal > 0, "alice needs BPT");
        uint256[] memory minAmountsOut = new uint256[](3);
        // Only buffer leg non-zero (or all zero for single-token buffer target).
        minAmountsOut[cbmv().bufferIndex()] = 1;
        vm.startPrank(alice);
        IERC20(cbmvPool).approve(address(router), type(uint256).max);
        vm.expectRevert(
            abi.encodeWithSelector(ICommonBufferMultiVaultWeightedPool.BufferOnlyRemoveDisallowed.selector)
        );
        router.removeLiquiditySingleTokenExactIn(
            cbmvPool, bptBal / 100, IERC20(address(dai)), 0, false, bytes("")
        );
        vm.stopPrank();
    }

    /// @notice W1: both SE legs fail exchangeIn → AllVaultsExhausted (selector).
    function test_W1_allVaultsExhausted_selector() public {
        // Covered with explicit selector in CommonBufferMultiVault_WalkAndExhaust.
        // Here: huge share-out still reverts (pool safety); walk exhaust selector is the dedicated suite.
        mintSharesForVault(0, alice, 50_000e18);
        mintSharesForVault(1, alice, 50_000e18);
        uint256 huge = IERC20(address(seVault)).balanceOf(alice);
        vm.startPrank(alice);
        vm.expectRevert();
        router.swapSingleTokenExactIn(
            cbmvPool, IERC20(address(seVault)), IERC20(address(dai)), huge, 0, type(uint256).max, false, bytes("")
        );
        vm.stopPrank();
    }
}
