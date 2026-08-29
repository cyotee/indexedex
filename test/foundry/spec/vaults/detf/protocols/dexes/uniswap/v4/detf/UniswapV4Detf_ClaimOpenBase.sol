// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {DETFNFTVaultCommon} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultCommon.sol";
import {
    DETF_PROTOCOL_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {UniswapV4Detf_ClaimBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ClaimBase.sol";

/// @notice Open-layer claim IDs (gold all four + Stage 11 Open). Sell via Bond NFT.
abstract contract UniswapV4Detf_ClaimOpenBase is UniswapV4Detf_ClaimBase {
    function test_preMaturity_sell_reverts() public {
        _firstBond(100 ether);
        (uint256 tokenId,) = _firstBond(20 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 unlock_ = nft_.unlockTimeOf(tokenId);
        assertGt(unlock_, block.timestamp, "still locked");
        vm.prank(detf);
        vm.expectRevert(abi.encodeWithSelector(DETFNFTVaultCommon.BondNotMature.selector, unlock_));
        nft_.sellPositionToDetfNft(tokenId, detfUser, detfUser);
    }

    function test_postMaturity_sell_mintsRebasingClaim() public {
        _firstBond(100 ether);
        (uint256 tokenId, uint256 shares) = _firstBond(40 ether);
        IDETFNFTVault nft_ = _nft();
        IERC20 lp_ = _lpOf(detf);
        uint256 lpBefore_ = lp_.balanceOf(address(nft_));
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 claimBefore_ = _claimTok().balanceOf(detfUser);

        _warpMature(tokenId);
        (uint256 principal, uint256 minted_) = _d10SellToClaimOn(detf, tokenId, detfUser);

        assertEq(principal, shares, "principal originalShares");
        assertGt(minted_, 0, "claim minted");
        assertEq(_claimTok().balanceOf(detfUser) - claimBefore_, minted_, "claim balance");
        assertEq(nft_.originalSharesOf(tokenId), 0, "sold originalShares");
        assertEq(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_ + principal, "id0 takes originalShares");
        assertEq(lp_.balanceOf(address(nft_)), lpBefore_, "no LP withdraw");
    }

    function test_claimRewards_whileLocked() public {
        _setPfc(detf);
        (uint256 tokenId,) = _firstBond(100 ether);
        _liveMintOn(detf, detfUser, 10 ether);
        IDETFNFTVault nft_ = _nft();
        assertLt(block.timestamp, nft_.unlockTimeOf(tokenId), "locked");
        uint256 pending_ = nft_.pendingRewards(tokenId);
        assertGt(pending_, 0, "pending while locked");
        uint256 balBefore_ = IERC20(detf).balanceOf(detfUser);
        vm.prank(detfUser);
        uint256 claimed_ = nft_.claimRewards(tokenId, detfUser);
        assertEq(claimed_, pending_, "claimed == pending");
        assertEq(IERC20(detf).balanceOf(detfUser) - balBefore_, claimed_, "DETF paid");
        assertEq(nft_.pendingRewards(tokenId), 0, "pending cleared");
    }
}
