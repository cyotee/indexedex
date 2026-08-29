// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID,
    DETF_FIRST_USER_BOND_NFT_ID,
    DETF_PROTOCOL_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4Detf_ClaimBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ClaimBase.sol";

/**
 * @title UniswapV4Detf_Alignment_FeeCreatorClaimBase
 * @notice D28 FC1–FC12 on unified CP gold. NFT `claimRewards`. FC4 is a later `bond`.
 */
abstract contract UniswapV4Detf_Alignment_FeeCreatorClaimBase is UniswapV4Detf_ClaimBase {
    address internal alice;
    address internal bob;

    function _fcActors() internal {
        if (alice == address(0)) {
            alice = makeAddr("alice");
            bob = makeAddr("bob");
        }
        _setPfc(detf);
        _setFeeOraclePfc(detf);
        _setBondTermsOn(detf);
    }

    function _feeToOf(address) internal view returns (address) {
        return address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
    }

    function _nftClaim(address d, uint256 tokenId, address to) internal returns (uint256 claimed) {
        IDETFNFTVault nft_ = _nftOf(d);
        vm.prank(to);
        claimed = nft_.claimRewards(tokenId, to);
    }

    function _potOf(address d) internal view returns (uint256) {
        return IERC20(d).balanceOf(address(_nftOf(d)));
    }

    function _bootAlice(uint256 amt) internal returns (uint256 tokenId, uint256 shares) {
        _fcActors();
        return _bondOn(detf, alice, amt);
    }

    function _assertFC1() internal {
        _bootAlice(20 ether);
        IDETFNFTVault nft_ = _nft();
        assertTrue(nft_.reservedBondNftsWired(), "reserved wired");
        address feeTo_ = _feeToOf(detf);
        assertEq(nft_.ownerOf(DETF_FEE_TO_BOND_NFT_ID), feeTo_, "id1 feeTo");
        assertEq(nft_.ownerOf(DETF_CREATOR_BOND_NFT_ID), feeTo_, "id2 D21 creator=0");

        uint256 potBefore_ = _potOf(detf);
        _liveMintOn(detf, alice, 2 ether);
        assertGt(_potOf(detf), potBefore_, "live mint pot");

        uint256 p1_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 p2_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        uint256 c1_ = _nftClaim(detf, DETF_FEE_TO_BOND_NFT_ID, feeTo_);
        uint256 c2_ = _nftClaim(detf, DETF_CREATOR_BOND_NFT_ID, feeTo_);
        assertGt(c1_, 0, "FC1 id1 claimed");
        assertGt(c2_, 0, "FC1 id2 claimed");
        assertEq(c1_, p1_, "FC1 id1 == pending");
        assertEq(c2_, p2_, "FC1 id2 == pending");
    }

    function _assertFC2() internal {
        _bootAlice(20 ether);
        _liveMintOn(detf, alice, 2 ether);
        IDETFNFTVault nft_ = _nft();
        address feeTo_ = _feeToOf(detf);
        uint256 pending_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 balBefore_ = IERC20(detf).balanceOf(feeTo_);
        uint256 claimed_ = _nftClaim(detf, DETF_FEE_TO_BOND_NFT_ID, feeTo_);
        assertEq(claimed_, pending_, "FC2 claim==pending");
        assertEq(IERC20(detf).balanceOf(feeTo_) - balBefore_, claimed_, "FC2 balance delta");
    }

    function _assertFC3() internal {
        _bootAlice(20 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 F_ = nft_.effectiveSharesOf(DETF_FEE_TO_BOND_NFT_ID);
        uint256 C_ = nft_.effectiveSharesOf(DETF_CREATOR_BOND_NFT_ID);
        uint256 T_ = nft_.totalShares();
        _liveMintOn(detf, alice, 2 ether);
        uint256 p1_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 p2_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        uint256 acc_ = p1_ + p2_ + nft_.pendingRewards(DETF_FIRST_USER_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_PROTOCOL_BOND_NFT_ID);
        assertGt(acc_, 0, "new pot");
        uint256 due1_ = (acc_ * F_) / T_;
        uint256 due2_ = (acc_ * C_) / T_;
        assertLe(p1_ > due1_ ? p1_ - due1_ : due1_ - p1_, 1, "FC3 id1 floor");
        assertLe(p2_ > due2_ ? p2_ - due2_ : due2_ - p2_, 1, "FC3 id2 floor");
        assertGt(F_, 0, "FC3 E/f");
        assertGt(C_, 0, "FC3 E/c");
    }

    function _assertFC4() internal {
        _bootAlice(20 ether);
        _liveMintOn(detf, alice, 2 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 pending1_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 pending2_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        assertGt(pending1_, 0, "old pot");
        _bondOn(detf, bob, 20 ether);
        uint256 after1_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 after2_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        assertLe(pending1_ > after1_ ? pending1_ - after1_ : 0, 1e13, "FC4 id1 old pot");
        assertLe(pending2_ > after2_ ? pending2_ - after2_ : 0, 1e13, "FC4 id2 old pot");
    }

    function _assertFC5() internal {
        _bootAlice(20 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 pendingBefore_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 accBefore_ = pendingBefore_ + nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_FIRST_USER_BOND_NFT_ID) + nft_.pendingRewards(DETF_PROTOCOL_BOND_NFT_ID);
        _liveMintOn(detf, alice, 2 ether);
        uint256 fromNew_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID) - pendingBefore_;
        uint256 accAfter_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID) + nft_.pendingRewards(DETF_FIRST_USER_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 delta_ = accAfter_ > accBefore_ ? accAfter_ - accBefore_ : 0;
        uint256 dueNew_ = (delta_ * nft_.effectiveSharesOf(DETF_FEE_TO_BOND_NFT_ID)) / nft_.totalShares();
        assertLe(fromNew_ > dueNew_ ? fromNew_ - dueNew_ : dueNew_ - fromNew_, 1, "FC5 id1 new pot");
    }

    function _assertFC6() internal {
        _bootAlice(20 ether);
        _liveMintOn(detf, alice, 2 ether);
        address feeTo_ = _feeToOf(detf);
        uint256 first_ = _nftClaim(detf, DETF_FEE_TO_BOND_NFT_ID, feeTo_);
        assertGt(first_, 0, "first claim");
        uint256 second_ = _nftClaim(detf, DETF_FEE_TO_BOND_NFT_ID, feeTo_);
        assertEq(second_, 0, "FC6 second claim 0");
    }

    function _assertFC7() internal {
        _bootAlice(20 ether);
        _liveMintOn(detf, alice, 2 ether);
        IDETFNFTVault nft_ = _nft();
        vm.prank(alice);
        vm.expectRevert();
        nft_.claimRewards(DETF_FEE_TO_BOND_NFT_ID, alice);
    }

    function _assertFC8() internal {
        _bootAlice(20 ether);
        IDETFNFTVault nft_ = _nft();
        assertTrue(nft_.reservedBondNftsWired(), "wired");
        address feeTo_ = _feeToOf(detf);
        uint256[] memory minOut_ = _minOutOf(detf);
        uint256 deadline_ = _deadline();
        vm.prank(feeTo_);
        vm.expectRevert();
        detfInfo.closeBondMature(DETF_FEE_TO_BOND_NFT_ID, minOut_, feeTo_, deadline_);
        vm.prank(feeTo_);
        vm.expectRevert();
        detfInfo.closeBondMature(DETF_CREATOR_BOND_NFT_ID, minOut_, feeTo_, deadline_);
        vm.prank(detf);
        vm.expectRevert(abi.encodeWithSelector(IDetfErrors.DETFNFTRestricted.selector, DETF_FEE_TO_BOND_NFT_ID));
        nft_.sellPositionToDetfNft(DETF_FEE_TO_BOND_NFT_ID, feeTo_, feeTo_);
        vm.prank(detf);
        vm.expectRevert(abi.encodeWithSelector(IDetfErrors.DETFNFTRestricted.selector, DETF_CREATOR_BOND_NFT_ID));
        nft_.sellPositionToDetfNft(DETF_CREATOR_BOND_NFT_ID, feeTo_, feeTo_);
    }

    function _assertFC9() internal {
        _bootAlice(15 ether);
        IDETFNFTVault nft_ = _nft();
        assertEq(nft_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID), 0, "FC9 id1 original");
        assertEq(nft_.originalSharesOf(DETF_CREATOR_BOND_NFT_ID), 0, "FC9 id2 original");
        assertGt(nft_.effectiveSharesOf(DETF_FEE_TO_BOND_NFT_ID), 0, "FC9 id1 effective");
        assertGt(nft_.effectiveSharesOf(DETF_CREATOR_BOND_NFT_ID), 0, "FC9 id2 effective");
        assertEq(nft_.convertToAssets(nft_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID)), 0, "FC9 no LP");
    }

    function _assertFC10() internal {
        _bootAlice(20 ether);
        _liveMintOn(detf, alice, 2 ether);
        address original_ = _feeToOf(detf);
        address newFeeTo_ = makeAddr("newFeeTo");
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(newFeeTo_));
        IDETFNFTVault nft_ = _nft();
        assertEq(nft_.ownerOf(DETF_FEE_TO_BOND_NFT_ID), original_, "FC10 owner stays");
        uint256 claimed_ = _nftClaim(detf, DETF_FEE_TO_BOND_NFT_ID, original_);
        assertGt(claimed_, 0, "original still claims");
        vm.prank(newFeeTo_);
        vm.expectRevert();
        nft_.claimRewards(DETF_FEE_TO_BOND_NFT_ID, newFeeTo_);
    }

    function _assertFC11() internal {
        _fcActors();
        IUniswapV4Detf.PkgArgs memory args_ = _openArgsPolicy();
        args_.creator = address(0);
        address instance_ = _deployTagged(args_, string.concat("fc11", _nextTag()));
        _bondOn(instance_, alice, 20 ether);
        _liveMintOn(instance_, alice, 2 ether);
        IDETFNFTVault nft_ = _nftOf(instance_);
        address feeTo_ = _feeToOf(instance_);
        assertEq(nft_.ownerOf(DETF_FEE_TO_BOND_NFT_ID), feeTo_);
        assertEq(nft_.ownerOf(DETF_CREATOR_BOND_NFT_ID), feeTo_);
        uint256 due1_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 due2_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        uint256 c1_ = _nftClaim(instance_, DETF_FEE_TO_BOND_NFT_ID, feeTo_);
        uint256 c2_ = _nftClaim(instance_, DETF_CREATOR_BOND_NFT_ID, feeTo_);
        assertEq(c1_, due1_, "FC11 id1");
        assertEq(c2_, due2_, "FC11 id2");
        assertGt(c1_, 0, "FC11 id1 claimed");
        assertGt(c2_, 0, "FC11 id2 claimed");
        assertTrue(c1_ + c2_ < IERC20(instance_).totalSupply(), "not whole supply");
    }

    function _assertFC12() internal {
        _bootAlice(20 ether);
        _liveMintOn(detf, alice, 2 ether);
        _bondOn(detf, bob, 4 ether);
        _liveMintOn(detf, bob, 1 ether);
        IDETFNFTVault nft_ = _nft();
        address feeTo_ = _feeToOf(detf);
        uint256 claimed_ = _nftClaim(detf, DETF_FEE_TO_BOND_NFT_ID, feeTo_)
            + _nftClaim(detf, DETF_CREATOR_BOND_NFT_ID, feeTo_)
            + _nftClaim(detf, DETF_FIRST_USER_BOND_NFT_ID, alice);
        try this.claimProtocolForFc12() returns (uint256 p0_) {
            claimed_ += p0_;
        } catch {}
        uint256 leftover_ = nft_.pendingRewards(DETF_PROTOCOL_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID)
            + nft_.pendingRewards(DETF_FIRST_USER_BOND_NFT_ID);
        assertLe(claimed_ + leftover_, IERC20(detf).totalSupply(), "FC12 not over mint");
        assertLe(leftover_, IERC20(detf).balanceOf(address(nft_)) + 4, "FC12 leftover backed");
    }

    function claimProtocolForFc12() external returns (uint256) {
        return _nft().claimRewards(DETF_PROTOCOL_BOND_NFT_ID, address(this));
    }
}
