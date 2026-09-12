// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IFacetRegistry} from "@crane/contracts/registries/facet/IFacetRegistry.sol";
import {FacetRegistryRepo} from "@crane/contracts/registries/facet/FacetRegistryRepo.sol";
import {FacetRegistryService} from "@crane/contracts/registries/facet/FacetRegistryService.sol";
import {OperableModifiers} from "@crane/contracts/access/operable/OperableModifiers.sol";

contract FacetRegistryTarget is OperableModifiers, IFacetRegistry {
    function deployFacet(bytes calldata initCode, bytes32 salt) external onlyOwnerOrOperator returns (IFacet facet) {
        return FacetRegistryService._deployFacet(initCode, salt);
    }

    function deployCanonicalFacetOverride(bytes calldata initCode, bytes32 salt, bytes4 interfaceId)
        external
        returns (IFacet facet)
    {
        facet = FacetRegistryService._deployFacet(initCode, salt);
        FacetRegistryRepo._setCanonicalFacet(interfaceId, facet);
        return facet;
    }

    function deployFacetWithArgs(bytes calldata initCode, bytes calldata initArgs, bytes32 salt)
        external
        onlyOwnerOrOperator
        returns (IFacet facet)
    {
        return FacetRegistryService._deployFacet(initCode, initArgs, salt);
    }

    function deployCanonicalFacetWithArgsOverride(
        bytes calldata initCode,
        bytes calldata initArgs,
        bytes32 salt,
        bytes4 interfaceId
    ) external returns (IFacet facet) {
        facet = FacetRegistryService._deployFacet(initCode, initArgs, salt);
        FacetRegistryRepo._setCanonicalFacet(interfaceId, facet);
        return facet;
    }

    function registerFacet(IFacet facet, string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
        external
        onlyOwnerOrOperator
        returns (bool)
    {
        FacetRegistryRepo._registerFacet(facet, name, interfaces, functions);
        return true;
    }

    function setCanonicalFacet(bytes4 interfaceId, IFacet facet) external onlyOwnerOrOperator returns (bool) {
        FacetRegistryRepo._setCanonicalFacet(interfaceId, facet);
        return true;
    }

    function allFacets() external view returns (address[] memory facetAddresses) {
        return FacetRegistryRepo._allFacets();
    }

    function facetsOfName(string calldata name) external view returns (address[] memory facetAddresses) {
        return FacetRegistryRepo._facetsOfName(name);
    }

    function facetsOfInterface(bytes4 interfaceId) external view returns (address[] memory facetAddresses) {
        return FacetRegistryRepo._facetsOfInterface(interfaceId);
    }

    function facetsOfFunction(bytes4 functionSelector) external view returns (address[] memory facetAddresses) {
        return FacetRegistryRepo._facetsOfFunction(functionSelector);
    }

    function canonicalFacet(bytes4 interfaceId) external view returns (IFacet facet) {
        return FacetRegistryRepo._canonicalFacet(interfaceId);
    }

    function nameOfFacet(IFacet facet) external view returns (string memory name) {
        return FacetRegistryRepo._nameOfFacet(facet);
    }

    function interfacesOfFacet(IFacet facet) external view returns (bytes4[] memory interfaces) {
        return FacetRegistryRepo._interfacesOfFacet(facet);
    }

    function functionsOfFacet(IFacet facet) external view returns (bytes4[] memory functions) {
        return FacetRegistryRepo._functionsOfFacet(facet);
    }
}
