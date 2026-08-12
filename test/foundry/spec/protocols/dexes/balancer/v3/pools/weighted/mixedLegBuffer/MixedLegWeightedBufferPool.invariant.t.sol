// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IMixedLegWeightedBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/IMixedLegWeightedBufferPool.sol";
import {
    TestBase_MixedLegWeightedBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/bases/TestBase_MixedLegWeightedBufferPool.sol";

/**
 * @title MixedLegWeightedBufferPoolInvariant
 * @notice Lightweight invariant-style smokes: virtual non-negative; unbalanced LP grows virtual;
 *         donation does not free-mint BPT (A3 overlap with core).
 */
contract MixedLegWeightedBufferPoolInvariant is TestBase_MixedLegWeightedBufferPool {
    function test_invariant_virtualBuffer_nonNegative_afterSwaps() public {
        for (uint256 i; i < 5; ++i) {
            uint256 amt = 1e17 + i * 1e16;
            dai.mint(alice, amt);
            swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), amt);
            assertGe(ml().virtualBuffer(0), 0);

            mintSharesForPair(0, alice, amt * 2);
            uint256 shBal = IERC20(address(seVault)).balanceOf(alice);
            if (shBal > amt / 2) {
                swapExactIn(alice, IERC20(address(seVault)), IERC20(address(dai)), amt / 2);
            }
        }
    }

    function test_unbalanced_add_growsVirtual() public {
        uint256 vtBefore = ml().virtualBuffer(0);
        mintSharesForPair(0, alice, 200e18);
        dai.mint(alice, 200e18);
        usdc.mint(alice, 200e18);
        _mintToken(address(weth), alice, 200e18);

        uint256 n = ml().tokenCount();
        uint256[] memory exactIn = new uint256[](n);
        for (uint256 t; t < n; ++t) {
            (IMixedLegWeightedBufferPool.TokenKind kind,) = ml().resolveTokenIndex(t);
            if (kind == IMixedLegWeightedBufferPool.TokenKind.Buffer) {
                exactIn[t] = 100e18;
            } else if (kind == IMixedLegWeightedBufferPool.TokenKind.Share) {
                exactIn[t] = 50e18;
            } else {
                exactIn[t] = 50e18; // unpaired non-zero for join stability
            }
        }

        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);
        IERC20(address(weth)).approve(address(router), type(uint256).max);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);
        router.addLiquidityUnbalanced(mixedLegPool, exactIn, 0, false, bytes(""));
        vm.stopPrank();

        assertEq(ml().virtualBuffer(0), vtBefore + 100e18);
    }

    function test_donation_noBptMint_virtualUnchanged() public {
        uint256 bptBefore = IERC20(mixedLegPool).totalSupply();
        uint256 vtBefore = ml().virtualBuffer(0);
        dai.mint(alice, 50e18);
        uint256[] memory amounts = new uint256[](ml().tokenCount());
        amounts[ml().bufferIndex(0)] = 50e18;
        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        router.donate(mixedLegPool, amounts, false, bytes(""));
        vm.stopPrank();
        assertEq(IERC20(mixedLegPool).totalSupply(), bptBefore);
        assertEq(ml().virtualBuffer(0), vtBefore);
    }
}
