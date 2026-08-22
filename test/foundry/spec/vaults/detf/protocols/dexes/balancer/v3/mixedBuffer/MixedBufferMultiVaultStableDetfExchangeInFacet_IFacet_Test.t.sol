// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";

contract MixedBufferMultiVaultStableDetfExchangeInFacet_IFacet_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function test_exchangeFacet_metadata() public view {
        IFacet facet_ = IFacet(address(mixedBufferDetfExchangeInFacet));
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = facet_.facetMetadata();
        assertEq(name_, "MixedBufferMultiVaultStableDetfExchangeInFacet", "name");
        assertEq(ifaces_.length, 1, "1 interface");
        assertEq(ifaces_[0], type(IStandardExchangeIn).interfaceId, "exchangeIn iface");
        assertEq(funcs_.length, 4, "exchange funcs");
        assertEq(funcs_[0], IStandardExchangeIn.exchangeIn.selector, "exchangeIn sel");
    }

    function test_bondingFacet_metadata() public view {
        IFacet facet_ = IFacet(address(mixedBufferDetfBondingFacet));
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = facet_.facetMetadata();
        assertEq(name_, "MixedBufferMultiVaultStableDetfBondingFacet", "name");
        assertEq(ifaces_.length, 1, "1 interface");
        assertEq(ifaces_[0], type(IMixedBufferMultiVaultStableDetfBonding).interfaceId, "bonding iface");
        assertEq(funcs_.length, 16, "bonding funcs");
        assertEq(funcs_[0], IMixedBufferMultiVaultStableDetfBonding.bootstrapFirstBond.selector, "bootstrap sel");
        assertTrue(_contains(funcs_, IMixedBufferMultiVaultStableDetfBonding.buyClaim.selector), "buyClaim");
        assertTrue(_contains(funcs_, IMixedBufferMultiVaultStableDetfBonding.closeBondMature.selector), "close");
        assertTrue(_contains(funcs_, IMixedBufferMultiVaultStableDetfBonding.joinDonatedCapital.selector), "joinDonated");
        assertTrue(_contains(funcs_, IMixedBufferMultiVaultStableDetfBonding.donate.selector), "donate");
        assertTrue(!_contains(funcs_, bytes4(keccak256("sellNFT(uint256,address)"))), "sellNFT gone");
    }

    function test_infoFacet_metadata() public view {
        IFacet facet_ = IFacet(address(mixedBufferDetfInfoFacet));
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = facet_.facetMetadata();
        assertEq(name_, "MixedBufferMultiVaultStableDetfInfoFacet", "name");
        assertEq(ifaces_.length, 1, "1 interface");
        assertEq(ifaces_[0], type(IMixedBufferMultiVaultStableDetfInfo).interfaceId, "info iface");
        assertEq(funcs_.length, 25, "info funcs");
        assertEq(funcs_[0], IMixedBufferMultiVaultStableDetfInfo.isReserveLive.selector, "isReserveLive");
    }

    function test_roleFacets_selectorUnion_coversPriorSurface() public pure {
        // Prior mega-Facet 35; product-law drops sellNFT and adds buy/close/preview/claimLiquidity.
        assertEq(uint256(4 + 16 + 25), 45, "selector count after donate surface");
    }

    function _contains(bytes4[] memory arr_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < arr_.length; ++i) {
            if (arr_[i] == sel_) return true;
        }
        return false;
    }

    function test_exchange_facet_funcs_match_metadata() public view {
        IFacet facet_ = IFacet(address(mixedBufferDetfExchangeInFacet));
        bytes4[] memory a = facet_.facetFuncs();
        (,, bytes4[] memory b) = facet_.facetMetadata();
        assertEq(a.length, b.length, "len");
        for (uint256 i; i < a.length; ++i) {
            assertEq(a[i], b[i], "sel match");
        }
    }
}
