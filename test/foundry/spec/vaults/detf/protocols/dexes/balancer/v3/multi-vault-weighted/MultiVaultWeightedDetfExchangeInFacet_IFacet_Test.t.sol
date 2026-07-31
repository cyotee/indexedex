// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {
    MultiVaultWeightedDetfExchangeInFacet
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfExchangeInFacet.sol";

/// @notice Structural IFacet metadata for the multi-vault-weighted exchange facet.
contract MultiVaultWeightedDetfExchangeInFacet_IFacet_Test is Test {
    function test_facetMetadata_nonEmpty() public {
        MultiVaultWeightedDetfExchangeInFacet facet = new MultiVaultWeightedDetfExchangeInFacet();
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = facet.facetMetadata();
        assertEq(keccak256(bytes(name_)), keccak256(bytes("MultiVaultWeightedDetfExchangeInFacet")));
        assertTrue(ifaces_.length >= 3, "interfaces");
        assertTrue(funcs_.length >= 29, "funcs incl. compound selectors");
        assertTrue(facet.facetFuncs().length == funcs_.length, "funcs match");
    }
}
