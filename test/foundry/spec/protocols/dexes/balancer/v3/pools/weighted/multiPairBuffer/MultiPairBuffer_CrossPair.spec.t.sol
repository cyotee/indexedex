// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_MultiPairStandardExchangeBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/bases/TestBase_MultiPairStandardExchangeBufferPool.sol";

/**
 * @title MultiPairBuffer_CrossPair
 * @notice P=2 deploy + full-graph EXACT_IN: within-pair, cross-pair, share↔share, buffer↔buffer.
 */
contract MultiPairBuffer_CrossPair is TestBase_MultiPairStandardExchangeBufferPool {
    function _targetPairCount() internal pure override returns (uint8) {
        return 2;
    }

    function test_deploy_P2() public view {
        assertEq(mp().pairCount(), 2);
        assertEq(mp().tokenCount(), 4);
        assertEq(address(mp().bufferToken(0)), address(dai));
        assertEq(address(mp().bufferToken(1)), address(usdt));
        assertTrue(address(mp().shareToken(0)) != address(mp().shareToken(1)));
    }

    function test_swap_withinPair0_bufferToShare() public {
        uint256 amt = 5e18;
        dai.mint(alice, amt);
        uint256 v0 = mp().virtualBuffer(0);
        uint256 rawBefore = rawPoolBufferBalance(0);
        uint256 out = swapExactIn(alice, buffer0, IERC20(address(seVault)), amt);
        assertGt(out, 0);
        assertGt(mp().virtualBuffer(0), v0);
        // Op-reconcile removes swap amount; init residual may remain (net ~0).
        assertApproxEqAbs(rawPoolBufferBalance(0), rawBefore, 10);
    }

    function test_swap_withinPair1_bufferToShare() public {
        uint256 amt = 5e18;
        usdt.mint(alice, amt);
        uint256 v1 = mp().virtualBuffer(1);
        uint256 rawBefore = rawPoolBufferBalance(1);
        uint256 out = swapExactIn(alice, buffer1, IERC20(address(seVault1)), amt);
        assertGt(out, 0);
        assertGt(mp().virtualBuffer(1), v1);
        assertApproxEqAbs(rawPoolBufferBalance(1), rawBefore, 10);
    }

    function test_swap_crossPair_buffer0_to_share1() public {
        uint256 amt = 5e18;
        dai.mint(alice, amt);
        uint256 v0 = mp().virtualBuffer(0);
        uint256 v1 = mp().virtualBuffer(1);
        int256 h1 = mp().hookShareDelta(1);
        uint256 out = swapExactIn(alice, buffer0, IERC20(address(seVault1)), amt);
        assertGt(out, 0);
        // buffer-in grows pair0 virtual; share-out does not change pair1 virtualBuffer
        assertGt(mp().virtualBuffer(0), v0);
        assertEq(mp().virtualBuffer(1), v1);
        assertEq(mp().hookShareDelta(1), h1); // donation path not used on share-out
    }

    function test_swap_crossPair_share0_to_buffer1() public {
        uint256 amt = 5e18;
        mintSharesForPair(0, alice, amt * 2);
        uint256 v1 = mp().virtualBuffer(1);
        uint256 out = swapExactIn(alice, IERC20(address(seVault)), buffer1, amt);
        assertGt(out, 0);
        // buffer1 out decreases virtual1
        assertLt(mp().virtualBuffer(1), v1);
    }

    function test_swap_share_to_share() public {
        uint256 amt = 5e18;
        mintSharesForPair(0, alice, amt * 2);
        uint256 v0 = mp().virtualBuffer(0);
        uint256 v1 = mp().virtualBuffer(1);
        uint256 out = swapExactIn(alice, IERC20(address(seVault)), IERC20(address(seVault1)), amt);
        assertGt(out, 0);
        assertEq(mp().virtualBuffer(0), v0);
        assertEq(mp().virtualBuffer(1), v1);
    }

    function test_swap_buffer_to_buffer() public {
        uint256 amt = 5e18;
        dai.mint(alice, amt);
        uint256 v0 = mp().virtualBuffer(0);
        uint256 v1 = mp().virtualBuffer(1);
        uint256 raw0 = rawPoolBufferBalance(0);
        uint256 raw1 = rawPoolBufferBalance(1);
        uint256 out = swapExactIn(alice, buffer0, buffer1, amt);
        assertGt(out, 0);
        assertGt(mp().virtualBuffer(0), v0);
        assertLt(mp().virtualBuffer(1), v1);
        assertApproxEqAbs(rawPoolBufferBalance(0), raw0, 10);
        assertApproxEqAbs(rawPoolBufferBalance(1), raw1, 10);
    }

    function test_E3_withinPair0_leavesPair1Unchanged() public {
        uint256 v1 = mp().virtualBuffer(1);
        int256 h1 = mp().hookShareDelta(1);
        dai.mint(alice, 3e18);
        swapExactIn(alice, buffer0, IERC20(address(seVault)), 3e18);
        assertEq(mp().virtualBuffer(1), v1);
        assertEq(mp().hookShareDelta(1), h1);
    }
}

/**
 * @title MultiPairBuffer_P4_Smoke
 * @notice Deploy + init P=4 and cross-pair / share↔share smoke swaps.
 */
contract MultiPairBuffer_P4_Smoke is TestBase_MultiPairStandardExchangeBufferPool {
    function _targetPairCount() internal pure override returns (uint8) {
        return 4;
    }

    function test_deploy_P4() public view {
        assertEq(mp().pairCount(), 4);
        assertEq(mp().tokenCount(), 8);
    }

    function test_swap_P4_crossPair_buffer0_to_share3() public {
        uint256 amt = 2e18;
        dai.mint(alice, amt);
        uint256 v0 = mp().virtualBuffer(0);
        uint256 out = swapExactIn(alice, buffer0, IERC20(address(seVault3)), amt);
        assertGt(out, 0);
        assertGt(mp().virtualBuffer(0), v0);
    }

    function test_swap_P4_share_to_share() public {
        uint256 amt = 2e18;
        mintSharesForPair(1, alice, amt * 2);
        uint256 out = swapExactIn(alice, IERC20(address(seVault1)), IERC20(address(seVault2)), amt);
        assertGt(out, 0);
    }
}
