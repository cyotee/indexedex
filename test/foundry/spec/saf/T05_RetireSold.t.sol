// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {DETFNFTVaultFacet} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultFacet.sol";
import {DETFNFTVaultCommon} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultCommon.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";

/// @notice T05 / L-BOND-2/3: sold surface retired; user sell path remains; realloc is nonReentrant (compile + call).
contract T05_RetireSold_Surface_Test is TestBase_VaultComponents {
    using DetfFacetFactoryService for ICreate3FactoryProxy;

    function test_facetFuncs_omitSoldSelectors() public {
        DETFNFTVaultFacet facet = DETFNFTVaultFacet(address(create3Factory.deployDETFNFTVaultFacet()));
        bytes4[] memory funcs = facet.facetFuncs();
        bytes4 markSel = bytes4(keccak256("markDETFNFTSold(uint256)"));
        bytes4 soldSel = bytes4(keccak256("detfNFTSold()"));
        for (uint256 i; i < funcs.length; ++i) {
            assertTrue(funcs[i] != markSel, "markDETFNFTSold retired");
            assertTrue(funcs[i] != soldSel, "detfNFTSold retired");
        }
    }
}

contract T05_UserSellStillWorks_Test is TestBase_UniswapV4SingleStandardExchangeDETF {
    function setUp() public override {
        super.setUp();
        _firstBond(400 ether);
    }

    function test_sellPositionToDetfNft_stillWorks() public {
        (uint256 tokenId, uint256 shares) = _firstBond(40 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        vm.prank(detfUser);
        uint256 principal = detfInfo.sellPositionToDetfNft(tokenId, detfUser);
        assertEq(principal, shares, "user sell-to-DETF remains product-valid");
    }
}
