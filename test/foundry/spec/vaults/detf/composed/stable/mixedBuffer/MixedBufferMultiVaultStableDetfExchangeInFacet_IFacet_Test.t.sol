// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/composed/stable/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";

contract MixedBufferMultiVaultStableDetfExchangeInFacet_IFacet_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function test_facet_metadata() public view {
        IFacet facet_ = IFacet(address(mixedBufferDetfExchangeInFacet));
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = facet_.facetMetadata();
        assertEq(name_, "MixedBufferMultiVaultStableDetfExchangeInFacet", "name");
        assertEq(ifaces_.length, 3, "3 interfaces");
        assertEq(ifaces_[0], type(IStandardExchangeIn).interfaceId, "exchangeIn iface");
        assertEq(ifaces_[1], type(IMixedBufferMultiVaultStableDetfBonding).interfaceId, "bonding iface");
        assertEq(ifaces_[2], type(IMixedBufferMultiVaultStableDetfInfo).interfaceId, "info iface");
        assertTrue(funcs_.length >= 20, "funcs");
        assertEq(funcs_[0], IStandardExchangeIn.exchangeIn.selector, "exchangeIn sel");
        assertEq(funcs_[4], IMixedBufferMultiVaultStableDetfBonding.bootstrapFirstBond.selector, "bootstrap sel");
    }

    function test_facet_funcs_match_metadata() public view {
        IFacet facet_ = IFacet(address(mixedBufferDetfExchangeInFacet));
        bytes4[] memory a = facet_.facetFuncs();
        (,, bytes4[] memory b) = facet_.facetMetadata();
        assertEq(a.length, b.length, "len");
        for (uint256 i; i < a.length; ++i) {
            assertEq(a[i], b[i], "sel match");
        }
    }
}
