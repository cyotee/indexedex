// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";

contract MultiVaultWeightedDetf_Bonding_Test is TestBase_MultiVaultWeightedDetf {
    function test_bond_revertsIfLockTooShort() public {
        (uint256 tokenId0_,) = _goLiveViaBptBond(detf, alice, 500e18);
        assertTrue(tokenId0_ > 0);

        uint256 seShares_ = _fundSeShares0(bob, 100e18);
        vm.startPrank(bob);
        seShare0.approve(detf, seShares_);
        vm.expectRevert();
        detfBonding.bond(seShare0, seShares_, 1 days, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_firstBond_joinsUnboostedDetf() public {
        uint256 reserveDetfBefore_ = IERC20(detf).balanceOf(address(vault));
        (uint256 tokenId_, uint256 shares_) = _goLiveViaBptBond(detf, alice, 1_000e18);
        assertTrue(tokenId_ > 0, "nft");
        assertTrue(shares_ > 0, "bpt principal");
        assertTrue(IERC20(detf).balanceOf(address(vault)) > reserveDetfBefore_, "D24 G joined");
        assertTrue(IERC20(detf).balanceOf(alice) > 0, "L1 free U");
    }

    function test_closeBondMature_previewEqualsExecute() public {
        (uint256 tokenId_,) = _goLiveViaBptBond(detf, alice, 1_200e18);
        _warpPastUnlock(detf, tokenId_);
        uint256[] memory preview_ = detfBonding.previewCloseBondMature(tokenId_);
        vm.prank(alice);
        uint256[] memory out_ =
            detfBonding.closeBondMature(tokenId_, _closeMinOut(detf), alice, block.timestamp + 1 hours);
        assertEq(preview_.length, out_.length, "D25 length");
        for (uint256 i; i < preview_.length; ++i) {
            assertEq(preview_[i], out_[i], "D25 preview==execute");
        }
    }

    function test_bond_vaultShare_afterLive() public {
        _goLiveViaBptBond(detf, alice, 1_000e18);
        uint256 seShares_ = _fundSeShares0(bob, 200e18);
        vm.startPrank(bob);
        seShare0.approve(detf, seShares_);
        (uint256 tokenId_, uint256 shares_) =
            detfBonding.bond(seShare0, seShares_, DEFAULT_MIN_LOCK, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(tokenId_ > 0, "nft");
        assertTrue(shares_ > 0, "bpt principal");
    }

    function test_sellPositionToDetfNft_revertsBondNotMature() public {
        (uint256 tokenId_,) = _goLiveViaBptBond(detf, alice, 800e18);
        uint256 unlock_ = IDETFNFTVault(detfInfo.bondNftVault()).unlockTimeOf(tokenId_);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("BondNotMature(uint256)")), unlock_));
        detfBonding.sellPositionToDetfNft(tokenId_, 0, alice);
    }

    function test_sellPositionToDetfNft_afterMaturity_mints4626() public {
        (uint256 tokenId_,) = _goLiveViaBptBond(detf, alice, 800e18);
        _warpPastUnlock(detf, tokenId_);
        uint256 protocolBefore_ = detfBonding.protocolBondOriginalShares();
        vm.prank(alice);
        uint256 claimMinted_ = detfBonding.sellPositionToDetfNft(tokenId_, 0, alice);
        assertTrue(claimMinted_ > 0, "claim minted");
        uint256 protocolId_ = IDETFNFTVault(detfInfo.bondNftVault()).detfNFTId();
        assertEq(
            IDETFNFTVault(detfInfo.bondNftVault()).effectiveSharesOf(protocolId_),
            IDETFNFTVault(detfInfo.bondNftVault()).originalSharesOf(protocolId_),
            "1:1 protocol nft"
        );
        assertTrue(IDETFNFTVault(detfInfo.bondNftVault()).originalSharesOf(protocolId_) > protocolBefore_, "protocol credited");
    }
}
