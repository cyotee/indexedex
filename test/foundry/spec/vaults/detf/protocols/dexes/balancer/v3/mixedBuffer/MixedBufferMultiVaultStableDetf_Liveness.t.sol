// SPDX-License-Identifier: BSL-1.1
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
        _fundBuffer(alice, _fixtureAmount(100e18));
        vm.startPrank(alice);
        IERC20(address(_fixtureBufferToken())).approve(detf, _fixtureAmount(100e18));
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.ReservePoolNotInitialized.selector);
        detfExchangeIn.exchangeIn(
            IERC20(address(_fixtureBufferToken())),
            _fixtureAmount(100e18),
            IERC20(detf),
            0,
            alice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_preLive_mint_share_reverts() public {
        uint256 shares_ = _fundVaultShares(0, alice, 100e18);
        vm.startPrank(alice);
        seShares[0].approve(detf, shares_);
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.ReservePoolNotInitialized.selector);
        detfExchangeIn.exchangeIn(seShares[0], shares_, IERC20(detf), 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_preLive_burn_requiresFundedInput() public {
        // Secure pull rejects an unfunded caller before entering the reserve route.
        vm.startPrank(alice);
        vm.expectRevert(bytes4(keccak256("TransferFromFailed()")));
        detfExchangeIn.exchangeIn(
            IERC20(detf), 1e9, IERC20(address(_fixtureBufferToken())), 0, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_preLive_bond_reverts() public {
        _fundBuffer(alice, _fixtureAmount(100e18));
        vm.startPrank(alice);
        IERC20(address(_fixtureBufferToken())).approve(detf, _fixtureAmount(100e18));
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.ReservePoolNotInitialized.selector);
        detfBonding.bond(
            IERC20(address(_fixtureBufferToken())),
            _fixtureAmount(100e18),
            DEFAULT_MIN_LOCK,
            alice,
            false,
            block.timestamp + 1 hours
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
        assertEq(tokens_.length, 2, "buffer and configured share payments");
        assertEq(tokens_[0], address(_fixtureBufferToken()), "buffer");
        assertEq(tokens_[1], address(seShares[0]), "share");
    }
}
