// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacetRegistry} from "@crane/contracts/registries/facet/IFacetRegistry.sol";
import {ICREATE3DFPkg} from "@crane/contracts/factories/create3/Create3FactoryDFPkg.sol";
import {ERC165Facet} from "@crane/contracts/introspection/ERC165/ERC165Facet.sol";

/// @notice The actual IndexedEx deployment core must protect every canonical-registry write.
contract CanonicalRegistryAuthorizationTest is IndexedexTest {
    address private outsider;
    bytes private facetCode;

    function setUp() public override {
        super.setUp();
        outsider = makeAddr("canonical-registry-outsider");
        facetCode = type(ERC165Facet).creationCode;
    }

    function test_canonicalFacetOverride_rejectsUnauthorizedCallerAtomically() public {
        _assertUnauthorized(0);
    }

    function test_canonicalFacetWithArgsOverride_rejectsUnauthorizedCallerAtomically() public {
        _assertUnauthorized(1);
    }

    function test_canonicalPackageReplacement_rejectsUnauthorizedCallerAtomically() public {
        _assertUnauthorized(2);
    }

    function test_canonicalRegistry_ownerCanUseAllMutators() public {
        _assertAuthorized(address(this));
    }

    function test_canonicalRegistry_globalOperatorCanUseAllMutators() public {
        create3Factory.setOperator(outsider, true);
        _assertAuthorized(outsider);
    }

    function test_canonicalRegistry_revokedOperatorCannotUseAnyMutator() public {
        create3Factory.setOperator(outsider, true);
        create3Factory.setOperator(outsider, false);
        _assertUnauthorized(0);
        _assertUnauthorized(1);
        _assertUnauthorized(2);
    }

    function test_canonicalRegistry_functionOperatorIsLimitedToApprovedSelector() public {
        create3Factory.setOperatorFor(IFacetRegistry.deployCanonicalFacetOverride.selector, outsider, true);
        vm.prank(outsider);
        IFacet installed = create3Factory.deployCanonicalFacetOverride(
            facetCode, keccak256("authorized-function-facet"), type(IERC165).interfaceId
        );
        assertEq(address(create3Factory.canonicalFacet(type(IERC165).interfaceId)), address(installed));
        _assertUnauthorized(1);
        _assertUnauthorized(2);
        create3Factory.setOperatorFor(IFacetRegistry.deployCanonicalFacetOverride.selector, outsider, false);
        _assertUnauthorized(0);
    }

    function testFuzz_canonicalRegistry_constructiveUnauthorizedMutators(uint256 mutationSeed, uint256 callerSeed) public {
        outsider = address(uint160(bound(callerSeed, 0x1000, 0xffff)));
        _assertUnauthorized(bound(mutationSeed, 0, 2));
    }

    function _assertUnauthorized(uint256 mutation) private {
        IFacet previousFacet = create3Factory.canonicalFacet(type(IERC165).interfaceId);
        IDiamondFactoryPackage previousPackage = create3Factory.canonicalPackage(type(ICREATE3DFPkg).interfaceId);
        uint256 facetCount = create3Factory.allFacets().length;
        uint256 packageCount = create3Factory.allPackages().length;
        address factoryOwner = create3Factory.owner();
        bytes32 salt = keccak256(abi.encode("unauthorized-canonical-facet", mutation));

        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, outsider));
        vm.prank(outsider);
        if (mutation == 0) {
            create3Factory.deployCanonicalFacetOverride(facetCode, salt, type(IERC165).interfaceId);
        } else if (mutation == 1) {
            create3Factory.deployCanonicalFacetWithArgsOverride(facetCode, bytes(""), salt, type(IERC165).interfaceId);
        } else {
            create3Factory.setCanonicalPackage(
                type(ICREATE3DFPkg).interfaceId, IDiamondFactoryPackage(address(feeCollectorDFPkg))
            );
        }

        assertEq(address(create3Factory.canonicalFacet(type(IERC165).interfaceId)), address(previousFacet));
        assertEq(address(create3Factory.canonicalPackage(type(ICREATE3DFPkg).interfaceId)), address(previousPackage));
        assertEq(create3Factory.allFacets().length, facetCount, "no attacker facet registered");
        assertEq(create3Factory.allPackages().length, packageCount, "package inventory unchanged");
        assertEq(create3Factory.owner(), factoryOwner, "factory owner unchanged");
    }

    function _assertAuthorized(address caller) private {
        vm.prank(caller);
        IFacet plain = create3Factory.deployCanonicalFacetOverride(
            facetCode, keccak256("authorized-canonical-plain"), type(IERC165).interfaceId
        );
        assertGt(address(plain).code.length, 0);
        assertEq(address(create3Factory.canonicalFacet(type(IERC165).interfaceId)), address(plain));
        vm.prank(caller);
        IFacet withArgs = create3Factory.deployCanonicalFacetWithArgsOverride(
            facetCode, bytes(""), keccak256("authorized-canonical-args"), type(IERC165).interfaceId
        );
        assertGt(address(withArgs).code.length, 0);
        assertEq(address(create3Factory.canonicalFacet(type(IERC165).interfaceId)), address(withArgs));
        vm.prank(caller);
        assertTrue(create3Factory.setCanonicalPackage(
            type(ICREATE3DFPkg).interfaceId, IDiamondFactoryPackage(address(feeCollectorDFPkg))
        ));
        assertEq(
            address(create3Factory.canonicalPackage(type(ICREATE3DFPkg).interfaceId)), address(feeCollectorDFPkg)
        );
    }
}
