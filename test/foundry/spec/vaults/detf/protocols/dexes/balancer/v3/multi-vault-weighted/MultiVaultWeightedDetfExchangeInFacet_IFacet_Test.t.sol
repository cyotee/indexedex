// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDETFStandardizedYield, IDETFStakingPreview} from "contracts/interfaces/IDETFStandardizedYield.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {IMultiVaultWeightedDetfBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol";
import {IMultiVaultWeightedDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfInfo.sol";

/// @notice Structural IFacet metadata for multi-vault-weighted role Facets (Option 1c split).
contract MultiVaultWeightedDetfExchangeInFacet_IFacet_Test is TestBase_MultiVaultWeightedDetf {
    function test_exchangeFacet_metadata() public {
        IFacet facet = multiVaultWeightedDetfExchangeInFacet;
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = facet.facetMetadata();
        assertEq(keccak256(bytes(name_)), keccak256(bytes("MultiVaultWeightedDetfExchangeInFacet")));
        assertEq(ifaces_.length, 2, "standard exchange interfaces");
        assertEq(ifaces_[1], type(IStandardExchangeOut).interfaceId);
        assertEq(ifaces_[0], type(IStandardExchangeIn).interfaceId);
        assertEq(funcs_.length, 5, "exchange and internal reserve callback funcs");
        assertEq(funcs_[0], IStandardExchangeIn.exchangeIn.selector);
        assertEq(facet.facetFuncs().length, funcs_.length, "funcs match");
    }

    function test_bondingFacet_metadata() public {
        IFacet facet = multiVaultWeightedDetfBondingFacet;
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = facet.facetMetadata();
        assertEq(keccak256(bytes(name_)), keccak256(bytes("MultiVaultWeightedDetfBondingFacet")));
        assertEq(ifaces_.length, 1, "interfaces");
        assertEq(ifaces_[0], type(IMultiVaultWeightedDetfBonding).interfaceId);
        assertEq(funcs_.length, 8, "funded bonding funcs");
        assertEq(funcs_[0], IMultiVaultWeightedDetfBonding.bond.selector);
        assertEq(funcs_[5], IMultiVaultWeightedDetfBonding.joinDonatedCapital.selector);
        assertEq(funcs_[7], IMultiVaultWeightedDetfBonding.donate.selector);
    }

    function test_infoFacet_metadata() public {
        IFacet facet = multiVaultWeightedDetfInfoFacet;
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = facet.facetMetadata();
        assertEq(keccak256(bytes(name_)), keccak256(bytes("MultiVaultWeightedDetfInfoFacet")));
        assertEq(ifaces_.length, 4, "info, rewards and SY interfaces");
        assertEq(ifaces_[1], type(IDETFFundedRewards).interfaceId);
        assertEq(ifaces_[2], type(IDETFStandardizedYield).interfaceId);
        assertEq(ifaces_[3], type(IDETFStakingPreview).interfaceId);
        assertEq(ifaces_[0], type(IMultiVaultWeightedDetfInfo).interfaceId);
        assertEq(funcs_.length, 25, "funded info funcs");
        assertEq(funcs_[0], IMultiVaultWeightedDetfInfo.isReserveLive.selector);
    }

    function test_roleFacets_selectorUnion_coversPriorSurface() public view {
        assertEq(
            multiVaultWeightedDetfExchangeInFacet.facetFuncs().length
                + multiVaultWeightedDetfBondingFacet.facetFuncs().length
                + multiVaultWeightedDetfInfoFacet.facetFuncs().length,
            38,
            "funded product selector union"
        );
    }
}
