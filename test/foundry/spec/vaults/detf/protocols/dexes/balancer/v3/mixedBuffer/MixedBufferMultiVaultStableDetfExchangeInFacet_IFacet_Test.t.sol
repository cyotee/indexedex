// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDETFStandardizedYield, IDETFStakingPreview} from "contracts/interfaces/IDETFStandardizedYield.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {IMixedBufferMultiVaultStableDetfBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfBonding.sol";
import {IMixedBufferMultiVaultStableDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfInfo.sol";

contract MixedBufferMultiVaultStableDetfExchangeInFacet_IFacet_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function test_exchangeFacet_metadata() public view {
        IFacet facet_ = IFacet(address(mixedBufferDetfExchangeInFacet));
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = facet_.facetMetadata();
        assertEq(name_, "MixedBufferMultiVaultStableDetfExchangeInFacet", "name");
        assertEq(ifaces_.length, 2, "standard exchange interfaces");
        assertEq(ifaces_[1], type(IStandardExchangeOut).interfaceId, "exchangeOut iface");
        assertEq(ifaces_[0], type(IStandardExchangeIn).interfaceId, "exchangeIn iface");
        assertEq(funcs_.length, 5, "exchange and internal reserve callback funcs");
        assertEq(funcs_[0], IStandardExchangeIn.exchangeIn.selector, "exchangeIn sel");
    }

    function test_bondingFacet_metadata() public view {
        IFacet facet_ = IFacet(address(mixedBufferDetfBondingFacet));
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = facet_.facetMetadata();
        assertEq(name_, "MixedBufferMultiVaultStableDetfBondingFacet", "name");
        assertEq(ifaces_.length, 1, "1 interface");
        assertEq(ifaces_[0], type(IMixedBufferMultiVaultStableDetfBonding).interfaceId, "bonding iface");
        assertEq(funcs_.length, 9, "funded bonding funcs");
        assertEq(funcs_[0], IMixedBufferMultiVaultStableDetfBonding.bond.selector, "bond sel");
        assertEq(funcs_[1], IMixedBufferMultiVaultStableDetfBonding.bootstrapFirstBond.selector, "bootstrap sel");
        assertFalse(
            _contains(funcs_, bytes4(keccak256("buyClaim(uint256,uint256,address,bool,uint256)"))),
            "legacy buyClaim retired"
        );
        assertFalse(
            _contains(funcs_, bytes4(keccak256("closeBondMature(uint256,uint256[],address,uint256)"))),
            "claims are on the funded bond NFT"
        );
        assertTrue(
            _contains(funcs_, IMixedBufferMultiVaultStableDetfBonding.joinDonatedCapital.selector), "joinDonated"
        );
        assertTrue(_contains(funcs_, IMixedBufferMultiVaultStableDetfBonding.donate.selector), "donate");
        assertTrue(!_contains(funcs_, bytes4(keccak256("sellNFT(uint256,address)"))), "sellNFT gone");
    }

    function test_infoFacet_metadata() public view {
        IFacet facet_ = IFacet(address(mixedBufferDetfInfoFacet));
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = facet_.facetMetadata();
        assertEq(name_, "MixedBufferMultiVaultStableDetfInfoFacet", "name");
        assertEq(ifaces_.length, 4, "info, rewards and SY interfaces");
        assertEq(ifaces_[1], type(IDETFFundedRewards).interfaceId);
        assertEq(ifaces_[2], type(IDETFStandardizedYield).interfaceId);
        assertEq(ifaces_[3], type(IDETFStakingPreview).interfaceId);
        assertEq(ifaces_[0], type(IMixedBufferMultiVaultStableDetfInfo).interfaceId, "info iface");
        assertEq(funcs_.length, 26, "funded info funcs");
        assertEq(funcs_[0], IMixedBufferMultiVaultStableDetfInfo.isReserveLive.selector, "isReserveLive");
    }

    function test_roleFacets_selectorUnion_coversPriorSurface() public view {
        bytes4[] memory exchange_ = mixedBufferDetfExchangeInFacet.facetFuncs();
        bytes4[] memory bond_ = mixedBufferDetfBondingFacet.facetFuncs();
        bytes4[] memory info_ = mixedBufferDetfInfoFacet.facetFuncs();
        assertEq(exchange_.length + bond_.length + info_.length, 40, "funded product selector union");
        assertTrue(_contains(info_, IDETFFundedRewards.synchronizeRewards.selector), "funded settlement routed");
        assertTrue(
            _contains(bond_, IMixedBufferMultiVaultStableDetfBonding.previewBond.selector), "purchase preview routed"
        );
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
