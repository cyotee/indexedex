// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";

contract MultiVaultWeightedDetf_Liveness_Test is TestBase_MultiVaultWeightedDetf {
    function test_preLive_mint_reverts() public {
        uint256 seShares_ = _fundSeShares0(alice, 100e18);
        vm.startPrank(alice);
        seShare0.approve(detf, seShares_);
        vm.expectRevert();
        detfExchangeIn.exchangeIn(
            seShare0, seShares_, IERC20(detf), 0, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_preLive_bondVaultShare_n1_goesLive() public {
        _assertInert(detf);
        uint256 seShares_ = _fundSeShares0(alice, 100e18);
        vm.startPrank(alice);
        seShare0.approve(detf, seShares_);
        (uint256 tokenId_,) =
            detfBonding.bond(seShare0, seShares_, DEFAULT_MIN_LOCK, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(tokenId_ > 0, "n1 first bond nft");
        _assertLive(detf);
    }

    function test_firstBondBpt_setsLive() public {
        _assertInert(detf);
        (uint256 tokenId_, uint256 bpt_) = _goLiveViaBptBond(detf, alice, 1_000e18);
        _assertLive(detf);
        assertTrue(tokenId_ > 0, "nft");
        assertTrue(bpt_ > 0, "bpt");
        assertTrue(IERC20(detf).totalSupply() > 0, "detf supply from self-leg");
        assertTrue(IERC20(detfInfo.reservePool()).totalSupply() > 0, "pool supply");
    }

    function test_acceptedBondTokens_includesBptAndShares() public view {
        address[] memory tokens_ = detfBonding.acceptedBondTokens();
        assertEq(tokens_.length, 2, "bpt + 1 share");
        assertEq(tokens_[0], detfInfo.reservePool(), "bpt first");
        assertEq(tokens_[1], address(seShare0), "share");
    }
}
