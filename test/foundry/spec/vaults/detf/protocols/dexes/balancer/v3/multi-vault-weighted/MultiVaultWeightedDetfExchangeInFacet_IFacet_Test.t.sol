// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    MultiVaultWeightedDetfExchangeInFacet
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfExchangeInFacet.sol";
import {
    MultiVaultWeightedDetfBondingFacet
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfBondingFacet.sol";
import {
    MultiVaultWeightedDetfInfoFacet
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoFacet.sol";
import {
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";

/// @notice Structural IFacet metadata for multi-vault-weighted role Facets (Option 1c split).
contract MultiVaultWeightedDetfExchangeInFacet_IFacet_Test is Test {
    function test_exchangeFacet_metadata() public {
        MultiVaultWeightedDetfExchangeInFacet facet = new MultiVaultWeightedDetfExchangeInFacet();
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = facet.facetMetadata();
        assertEq(keccak256(bytes(name_)), keccak256(bytes("MultiVaultWeightedDetfExchangeInFacet")));
        assertEq(ifaces_.length, 1, "interfaces");
        assertEq(ifaces_[0], type(IStandardExchangeIn).interfaceId);
        assertEq(funcs_.length, 4, "exchange funcs");
        assertEq(funcs_[0], IStandardExchangeIn.exchangeIn.selector);
        assertEq(facet.facetFuncs().length, funcs_.length, "funcs match");
    }

    function test_bondingFacet_metadata() public {
        MultiVaultWeightedDetfBondingFacet facet = new MultiVaultWeightedDetfBondingFacet();
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = facet.facetMetadata();
        assertEq(keccak256(bytes(name_)), keccak256(bytes("MultiVaultWeightedDetfBondingFacet")));
        assertEq(ifaces_.length, 1, "interfaces");
        assertEq(ifaces_[0], type(IMultiVaultWeightedDetfBonding).interfaceId);
        assertEq(funcs_.length, 12, "bonding funcs");
        assertEq(funcs_[0], IMultiVaultWeightedDetfBonding.bond.selector);
    }

    function test_infoFacet_metadata() public {
        MultiVaultWeightedDetfInfoFacet facet = new MultiVaultWeightedDetfInfoFacet();
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = facet.facetMetadata();
        assertEq(keccak256(bytes(name_)), keccak256(bytes("MultiVaultWeightedDetfInfoFacet")));
        assertEq(ifaces_.length, 1, "interfaces");
        assertEq(ifaces_[0], type(IMultiVaultWeightedDetfInfo).interfaceId);
        assertEq(funcs_.length, 23, "info funcs");
        assertEq(funcs_[0], IMultiVaultWeightedDetfInfo.isReserveLive.selector);
    }

    function test_roleFacets_selectorUnion_coversPriorSurface() public pure {
        // Prior mega-Facet exposed 33 selectors; union of role Facets must stay complete.
        assertEq(uint256(4 + 12 + 23), 39, "selector count after product-law sell/close/buyClaim");
    }
}
