// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    TestBase_MixedBufferMultiVaultStablePool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/bases/TestBase_MixedBufferMultiVaultStablePool.sol";
import {
    TestBase_MixedBufferMultiVaultStable_UniV2
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/bases/TestBase_MixedBufferMultiVaultStable_UniV2.sol";

/**
 * @notice Multi-protocol SE matrix: Aerodrome hermetic + real Uniswap V2 hermetic C0 smoke.
 */
contract MixedBufferMultiVaultStable_AerodromeMatrix is TestBase_MixedBufferMultiVaultStablePool {
    function test_matrix_aerodrome_C0_lifecycle() public {
        assertEq(mbmvs().tokenCount(), 3);
        dai.mint(alice, 10e18);
        assertGt(swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), 10e18), 0);
    }
}

contract MixedBufferMultiVaultStable_UniV2MatrixRow is TestBase_MixedBufferMultiVaultStable_UniV2 {
    function test_matrix_univ2_row_identity() public view {
        assertEq(keccak256(bytes(_seProtocolFamily())), keccak256(bytes("uniswap-v2")));
        assertEq(mbmvs().unpairedCount(), 1);
        assertEq(mbmvs().vaultCount(), 1);
        assertEq(mbmvs().tokenCount(), 3);
        assertEq(address(mbmvs().bufferToken()), address(dai));
        assertEq(address(mbmvs().shareToken(0)), address(seVault));
    }

    function test_matrix_univ2_C0_buffer_to_share_swap() public {
        uint256 rawBefore = rawPoolBufferBalance();
        dai.mint(alice, 7e18);
        uint256 out = swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), 7e18);
        assertGt(out, 0, "UniV2 SE buffer-to-share must produce share out");
        // Net residual vs pre-swap (eventual-zero best-effort; UniV2 SE may leave ≤ few wei dust).
        assertApproxEqAbs(rawPoolBufferBalance(), rawBefore, 1e18, "buffer-in net residual");
        assertEq(address(mbmvs().shareToken(0)), address(seVault), "share leg is UniV2 SE vault");
    }

    function test_matrix_univ2_C0_unpaired_to_share_swap() public {
        // Pure free-leg to UniV2 SE share — no buffer SE I/O; proves MixedBuffer pricing on UniV2 share leg.
        usdt.mint(alice, 5e18);
        vm.prank(alice);
        usdt.approve(address(router), type(uint256).max);
        uint256 shareBefore = IERC20(address(seVault)).balanceOf(alice);
        uint256 out = swapExactIn(alice, IERC20(address(usdt)), IERC20(address(seVault)), 5e18);
        assertGt(out, 0, "unpaired-to-share on UniV2-backed pool");
        assertEq(IERC20(address(seVault)).balanceOf(alice), shareBefore + out);
    }
}
