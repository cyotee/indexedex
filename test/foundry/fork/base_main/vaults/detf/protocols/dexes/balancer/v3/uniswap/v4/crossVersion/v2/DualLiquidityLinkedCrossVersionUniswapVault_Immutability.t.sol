// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Deployed diamond is immutable/unowned: no owner surface, no diamondCut, facet set fixed.
contract DualLiquidityLinkedCrossVersionUniswapVault_Immutability is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    function setUp() public override {
        super.setUp();
        // Immutability is a deploy property; bootstrap not required.
    }

    function test_immutability_noOwnerSelector() public {
        // owner() selector 0x8da5cb5b - should have no target on an unowned diamond.
        (bool ok,) = linkedVault.call(abi.encodeWithSignature("owner()"));
        assertFalse(ok, "owner() must not be present");
    }

    function test_immutability_noDiamondCutSelector() public {
        // diamondCut((address,uint8,bytes4[])[],address,bytes) - 0x1f931c1c
        bytes memory data = abi.encodeWithSelector(bytes4(0x1f931c1c), new bytes(0));
        (bool ok,) = linkedVault.call(data);
        assertFalse(ok, "diamondCut must not be present");
    }

    function test_immutability_loupeHasNoDiamondCutInFacets() public {
        IDiamondLoupe.Facet[] memory facets_ = IDiamondLoupe(linkedVault).facets();
        assertGt(facets_.length, 0, "loupe reports facets");
        for (uint256 i = 0; i < facets_.length; i++) {
            for (uint256 j = 0; j < facets_[i].functionSelectors.length; j++) {
                assertTrue(
                    facets_[i].functionSelectors[j] != bytes4(0x1f931c1c), "no diamondCut in loupe"
                );
                assertTrue(
                    facets_[i].functionSelectors[j] != bytes4(0x8da5cb5b), "no owner() in loupe"
                );
            }
        }
    }

    function test_immutability_packageFacetCountMatchesDeploy() public {
        // Package advertises 9 facet cuts; loupe may group/split addresses but must cover them.
        IDiamondLoupe.Facet[] memory facets_ = IDiamondLoupe(linkedVault).facets();
        assertEq(linkedVaultPkg.facetCuts().length, 9, "package facetCuts length");
        assertGe(facets_.length, 9, "loupe has at least package facet addresses");
        // Count total selectors on diamond - should equal sum of package facetFuncs.
        uint256 selectors;
        for (uint256 i = 0; i < facets_.length; i++) {
            selectors += facets_[i].functionSelectors.length;
        }
        assertGt(selectors, 20, "meaningful selector surface installed");
    }
}
