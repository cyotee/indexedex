// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {TestBase_UniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/// @notice Bond NFT packaging keeps generic ERC721 methods separate from guarded product transfers.
contract UniswapV4Detf_BondNftPackaging is TestBase_UniswapV4Detf {
    /// @notice Generic queries/approvals remain routed to ERC721; guarded transfers stay on the product facet.
    function test_bondNft_genericErc721AndGuardedTransferRouting() public view {
        address nft = detfInfo.bondNftVault();
        IDiamondLoupe loupe = IDiamondLoupe(nft);
        address product = loupe.facetAddress(IDETFNFTVault.createPosition.selector);
        address erc721 = loupe.facetAddress(IERC721.ownerOf.selector);
        assertGt(product.code.length, 0, "product facet deployed");
        assertLe(product.code.length, 24_576, "bond NFT facet runtime limit");
        assertGt(erc721.code.length, 0, "ERC721 facet deployed");
        assertTrue(erc721 != product, "generic ERC721 has separate implementation");
        assertEq(loupe.facetAddress(IERC721.balanceOf.selector), erc721, "balance query");
        assertEq(loupe.facetAddress(IERC721.approve.selector), erc721, "token approval");
        assertEq(loupe.facetAddress(IERC721.getApproved.selector), erc721, "approval query");
        assertEq(loupe.facetAddress(IERC721.setApprovalForAll.selector), erc721, "operator approval");
        assertEq(loupe.facetAddress(IERC721.isApprovedForAll.selector), erc721, "operator query");
        assertEq(loupe.facetAddress(IERC721.transferFrom.selector), product, "guarded transfer");
        assertEq(
            loupe.facetAddress(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))),
            product,
            "guarded safe transfer"
        );
        assertEq(
            loupe.facetAddress(bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"))),
            product,
            "guarded safe transfer with data"
        );
    }

    /// @notice A real bond remains queryable and approvable, while transfer to its DETF still reverts.
    function test_bondNft_genericErc721ApprovalsAndTransferGuard() public {
        (uint256 id,) = _firstBond(100 ether);
        IERC721 nft = IERC721(detfInfo.bondNftVault());
        address operator = makeAddr("bond-nft-operator");
        assertEq(nft.ownerOf(id), detfUser, "bond owner");
        assertEq(nft.balanceOf(detfUser), 1, "bond balance");
        vm.startPrank(detfUser);
        nft.approve(operator, id);
        assertEq(nft.getApproved(id), operator, "token approval is live");
        nft.setApprovalForAll(operator, true);
        assertTrue(nft.isApprovedForAll(detfUser, operator), "operator approval is live");
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, detf));
        nft.transferFrom(detfUser, detf, id);
        vm.stopPrank();
        assertEq(nft.ownerOf(id), detfUser, "guard preserves original owner");
    }
}
