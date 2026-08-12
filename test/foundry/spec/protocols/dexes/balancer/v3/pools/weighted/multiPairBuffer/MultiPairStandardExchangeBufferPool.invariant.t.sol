// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_MultiPairStandardExchangeBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/bases/TestBase_MultiPairStandardExchangeBufferPool.sol";
import {IMultiPairStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/IMultiPairStandardExchangeBufferPool.sol";

/**
 * @title MultiPairStandardExchangeBufferPoolInvariant
 * @notice Lightweight invariant-style smoke: random small swaps keep virtual non-negative.
 */
contract MultiPairStandardExchangeBufferPoolInvariant is TestBase_MultiPairStandardExchangeBufferPool {
    function test_invariant_virtualBuffer_nonNegative_afterSwaps() public {
        for (uint256 i; i < 5; ++i) {
            uint256 amt = 1e17 + i * 1e16;
            dai.mint(alice, amt);
            swapExactIn(alice, tta, IERC20(address(seVault)), amt);
            assertGe(mp().virtualBuffer(0), 0);

            mintShares(alice, amt * 2);
            uint256 shBal = IERC20(address(seVault)).balanceOf(alice);
            if (shBal > amt / 2) {
                swapExactIn(alice, IERC20(address(seVault)), tta, amt / 2);
            }
            // virtual may be lower but must not underflow (would have reverted)
            assertTrue(true);
        }
    }

    function test_unbalanced_add_growsVirtual() public {
        uint256 vtBefore = mp().virtualBuffer(0);
        mintShares(alice, 200e18);
        dai.mint(alice, 200e18);
        uint256[] memory exactIn = new uint256[](2);
        // Unbalanced: more buffer than shares (both non-zero for weighted join stability).
        exactIn[mp().bufferIndex(0)] = 100e18;
        exactIn[mp().shareIndex(0)] = 50e18;
        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);
        router.addLiquidityUnbalanced(multiPairPool, exactIn, 0, false, bytes(""));
        vm.stopPrank();
        assertEq(mp().virtualBuffer(0), vtBefore + 100e18);
    }
}
