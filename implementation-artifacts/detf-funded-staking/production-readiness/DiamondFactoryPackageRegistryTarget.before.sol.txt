// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondFactoryPackageRegistry} from "@crane/contracts/registries/package/IDiamondFactoryPackageRegistry.sol";
import {
    DiamondFactoryPackageRegistryRepo
} from "@crane/contracts/registries/package/DiamondFactoryPackageRegistryRepo.sol";
import {
    DiamondFactoryPackageRegistryFactoryService
} from "@crane/contracts/registries/package/DiamondFactoryPackageRegistryFactoryService.sol";
import {OperableModifiers} from "@crane/contracts/access/operable/OperableModifiers.sol";

contract DiamondFactoryPackageRegistryTarget is OperableModifiers, IDiamondFactoryPackageRegistry {
    function deployPackage(bytes memory initCode, bytes32 salt)
        external
        onlyOwnerOrOperator
        returns (IDiamondFactoryPackage package)
    {
        return DiamondFactoryPackageRegistryFactoryService._deployPackage(initCode, salt);
    }

    function deployCanonicalPackage(bytes calldata initCode, bytes32 salt, bytes4 interfaceId)
        external
        onlyOwnerOrOperator
        returns (IDiamondFactoryPackage package)
    {
        package = DiamondFactoryPackageRegistryFactoryService._deployPackage(initCode, salt);
        DiamondFactoryPackageRegistryRepo._setCanonicalPackage(interfaceId, package);
        return package;
    }

    function deployPackageWithArgs(bytes memory initCode, bytes memory constructorArgs, bytes32 salt)
        external
        onlyOwnerOrOperator
        returns (IDiamondFactoryPackage package)
    {
        return DiamondFactoryPackageRegistryFactoryService._deployPackage(initCode, constructorArgs, salt);
    }

    function deployCanonicalPackageWithArgs(
        bytes calldata initCode,
        bytes calldata constructorArgs,
        bytes32 salt,
        bytes4 interfaceId
    ) external onlyOwnerOrOperator returns (IDiamondFactoryPackage package) {
        package = DiamondFactoryPackageRegistryFactoryService._deployPackage(initCode, constructorArgs, salt);
        DiamondFactoryPackageRegistryRepo._setCanonicalPackage(interfaceId, package);
        return package;
    }

    function registerPackage(
        IDiamondFactoryPackage package,
        string memory name,
        bytes4[] memory interfaces,
        address[] memory facets
    ) external onlyOwnerOrOperator returns (bool) {
        DiamondFactoryPackageRegistryRepo._registerPackage(package, name, interfaces, facets);
        return true;
    }

    function setCanonicalPackage(bytes4 interfaceId, IDiamondFactoryPackage package) external returns (bool) {
        DiamondFactoryPackageRegistryRepo._setCanonicalPackage(interfaceId, package);
        return true;
    }

    function canonicalPackage(bytes4 interfaceId) external view returns (IDiamondFactoryPackage package) {
        return DiamondFactoryPackageRegistryRepo._canonicalPackage(interfaceId);
    }

    function allPackages() external view returns (address[] memory packages) {
        return DiamondFactoryPackageRegistryRepo._allPackages();
    }

    function nameOfPackage(IDiamondFactoryPackage package) external view returns (string memory) {
        return DiamondFactoryPackageRegistryRepo._nameOfPackage(package);
    }

    function packagesByName(string calldata name) external view returns (address[] memory packages) {
        return DiamondFactoryPackageRegistryRepo._packagesOfName(name);
    }

    function packagesByInterface(bytes4 interfaceId) external view returns (address[] memory packages) {
        return DiamondFactoryPackageRegistryRepo._packagesOfInterface(interfaceId);
    }

    function packagesByFacet(IFacet facet) external view returns (address[] memory packages) {
        return DiamondFactoryPackageRegistryRepo._packagesOfFacet(facet);
    }
}
