// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    TestBase_MixedLegWeightedBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/bases/TestBase_MixedLegWeightedBufferPool.sol";

/**
 * @title MixedLeg_CrossConfig_U0P2
 * @notice U=0 P=2 — full-graph within/cross pair (MultiPair cross-pair parity).
 */
contract MixedLeg_CrossConfig_U0P2 is TestBase_MixedLegWeightedBufferPool {
    function _targetUnpairedCount() internal pure override returns (uint8) {
        return 0;
    }

    function _targetPairCount() internal pure override returns (uint8) {
        return 2;
    }

    function test_deploy_U0_P2() public view {
        assertEq(ml().unpairedCount(), 0);
        assertEq(ml().pairCount(), 2);
        assertEq(ml().tokenCount(), 4);
        assertEq(address(ml().bufferToken(0)), address(dai));
        assertEq(address(ml().bufferToken(1)), address(usdt));
        assertTrue(address(ml().shareToken(0)) != address(ml().shareToken(1)));
    }

    function test_swap_withinPair0_bufferToShare() public {
        uint256 amt = 5e18;
        dai.mint(alice, amt);
        uint256 v0 = ml().virtualBuffer(0);
        uint256 rawBefore = rawPoolBufferBalance(0);
        uint256 out = swapExactIn(alice, buffer0, IERC20(address(seVault)), amt);
        assertGt(out, 0);
        assertGt(ml().virtualBuffer(0), v0);
        assertApproxEqAbs(rawPoolBufferBalance(0), rawBefore, 10);
    }

    function test_swap_withinPair1_bufferToShare() public {
        uint256 amt = 5e18;
        usdt.mint(alice, amt);
        uint256 v1 = ml().virtualBuffer(1);
        uint256 rawBefore = rawPoolBufferBalance(1);
        uint256 out = swapExactIn(alice, buffer1, IERC20(address(seVault1)), amt);
        assertGt(out, 0);
        assertGt(ml().virtualBuffer(1), v1);
        assertApproxEqAbs(rawPoolBufferBalance(1), rawBefore, 10);
    }

    function test_swap_crossPair_buffer0_to_share1() public {
        uint256 amt = 5e18;
        dai.mint(alice, amt);
        uint256 v0 = ml().virtualBuffer(0);
        uint256 v1 = ml().virtualBuffer(1);
        int256 h1 = ml().hookShareDelta(1);
        uint256 out = swapExactIn(alice, buffer0, IERC20(address(seVault1)), amt);
        assertGt(out, 0);
        assertGt(ml().virtualBuffer(0), v0);
        assertEq(ml().virtualBuffer(1), v1);
        assertEq(ml().hookShareDelta(1), h1);
    }

    function test_swap_crossPair_share0_to_buffer1() public {
        uint256 amt = 5e18;
        mintSharesForPair(0, alice, amt * 2);
        uint256 v1 = ml().virtualBuffer(1);
        uint256 out = swapExactIn(alice, IERC20(address(seVault)), buffer1, amt);
        assertGt(out, 0);
        assertLt(ml().virtualBuffer(1), v1);
    }

    function test_swap_share_to_share() public {
        uint256 amt = 5e18;
        mintSharesForPair(0, alice, amt * 2);
        uint256 v0 = ml().virtualBuffer(0);
        uint256 v1 = ml().virtualBuffer(1);
        uint256 out = swapExactIn(alice, IERC20(address(seVault)), IERC20(address(seVault1)), amt);
        assertGt(out, 0);
        assertEq(ml().virtualBuffer(0), v0);
        assertEq(ml().virtualBuffer(1), v1);
    }

    function test_swap_buffer_to_buffer() public {
        uint256 amt = 5e18;
        dai.mint(alice, amt);
        uint256 v0 = ml().virtualBuffer(0);
        uint256 v1 = ml().virtualBuffer(1);
        uint256 raw0 = rawPoolBufferBalance(0);
        uint256 raw1 = rawPoolBufferBalance(1);
        uint256 out = swapExactIn(alice, buffer0, buffer1, amt);
        assertGt(out, 0);
        assertGt(ml().virtualBuffer(0), v0);
        assertLt(ml().virtualBuffer(1), v1);
        assertApproxEqAbs(rawPoolBufferBalance(0), raw0, 10);
        assertApproxEqAbs(rawPoolBufferBalance(1), raw1, 10);
    }
}

/**
 * @title MixedLeg_CrossConfig_U2P2
 * @notice U=2 P=2 (T=6): unpaired legs + two pairs; full-graph unpaired↔pair.
 */
contract MixedLeg_CrossConfig_U2P2 is TestBase_MixedLegWeightedBufferPool {
    function _targetUnpairedCount() internal pure override returns (uint8) {
        return 2;
    }

    function _targetPairCount() internal pure override returns (uint8) {
        return 2;
    }

    function test_deploy_U2_P2() public view {
        assertEq(ml().unpairedCount(), 2);
        assertEq(ml().pairCount(), 2);
        assertEq(ml().tokenCount(), 6);
        assertEq(address(ml().unpairedToken(0)), address(usdc));
        assertEq(address(ml().unpairedToken(1)), address(weth));
    }

    function test_swap_unpaired_to_buffer0() public {
        uint256 amt = 5e18;
        usdc.mint(alice, amt);
        uint256 v0 = ml().virtualBuffer(0);
        uint256 out = swapExactIn(alice, IERC20(address(usdc)), buffer0, amt);
        assertGt(out, 0);
        assertLt(ml().virtualBuffer(0), v0);
    }

    function test_swap_buffer0_to_unpaired() public {
        uint256 amt = 5e18;
        dai.mint(alice, amt);
        uint256 v0 = ml().virtualBuffer(0);
        uint256 out = swapExactIn(alice, buffer0, IERC20(address(usdc)), amt);
        assertGt(out, 0);
        assertGe(ml().virtualBuffer(0), v0);
    }

    function test_swap_unpaired_to_share1() public {
        uint256 amt = 5e18;
        usdc.mint(alice, amt);
        uint256 v0 = ml().virtualBuffer(0);
        uint256 v1 = ml().virtualBuffer(1);
        uint256 out = swapExactIn(alice, IERC20(address(usdc)), IERC20(address(seVault1)), amt);
        assertGt(out, 0);
        // unpaired in → no pair0 virtual change; share1 out does not change pair1 virtual
        assertEq(ml().virtualBuffer(0), v0);
        assertEq(ml().virtualBuffer(1), v1);
    }

    function test_swap_crossPair_with_unpaired_present() public {
        uint256 amt = 5e18;
        dai.mint(alice, amt);
        uint256 v1 = ml().virtualBuffer(1);
        uint256 out = swapExactIn(alice, buffer0, IERC20(address(seVault1)), amt);
        assertGt(out, 0);
        assertEq(ml().virtualBuffer(1), v1);
    }
}
