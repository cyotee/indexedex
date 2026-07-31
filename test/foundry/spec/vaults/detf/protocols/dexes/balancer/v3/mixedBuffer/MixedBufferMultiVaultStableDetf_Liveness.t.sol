// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";

contract MixedBufferMultiVaultStableDetf_Liveness_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function test_preLive_mint_buffer_reverts() public {
        _fundBuffer(alice, 100e18);
        vm.startPrank(alice);
        IERC20(address(dai)).approve(detf, 100e18);
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.ReservePoolNotInitialized.selector);
        detfExchangeIn.exchangeIn(
            IERC20(address(dai)), 100e18, IERC20(detf), 0, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_preLive_mint_share_reverts() public {
        uint256 shares_ = _fundVaultShares(0, alice, 100e18);
        vm.startPrank(alice);
        seShares[0].approve(detf, shares_);
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.ReservePoolNotInitialized.selector);
        detfExchangeIn.exchangeIn(
            seShares[0], shares_, IERC20(detf), 0, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_preLive_burn_reverts() public {
        // No DETF yet; still attempt burn path
        vm.startPrank(alice);
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.ReservePoolNotInitialized.selector);
        detfExchangeIn.exchangeIn(
            IERC20(detf), 1e18, IERC20(address(dai)), 0, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_preLive_bond_reverts() public {
        _fundBuffer(alice, 100e18);
        vm.startPrank(alice);
        IERC20(address(dai)).approve(detf, 100e18);
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.ReservePoolNotInitialized.selector);
        detfBonding.bond(
            IERC20(address(dai)), 100e18, DEFAULT_MIN_LOCK, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_postBootstrap_live() public {
        _assertInert(detf);
        _bootstrapDefault(detf, alice);
        _assertLive(detf);
    }

    function test_acceptedBondTokens_postLive() public {
        _bootstrapDefault(detf, alice);
        address[] memory tokens_ = detfBonding.acceptedBondTokens();
        // buffer + 1 share + BPT
        assertEq(tokens_.length, 3, "buffer+share+bpt");
        assertEq(tokens_[0], address(dai), "buffer");
        assertEq(tokens_[1], address(seShares[0]), "share");
        assertEq(tokens_[2], detfInfo.reservePool(), "bpt");
    }
}
