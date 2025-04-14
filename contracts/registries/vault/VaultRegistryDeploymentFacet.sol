// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

// import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {Create3FactoryAwareRepo} from "@crane/contracts/factories/create3/Create3FactoryAwareRepo.sol";
import {DiamondPackageFactoryAwareRepo} from "@crane/contracts/factories/diamondPkg/DiamondPackageFactoryAwareRepo.sol";
import {OperableModifiers} from "@crane/contracts/access/operable/OperableModifiers.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
// import {VaultRegistryVaultRepo} from "contracts/registries/vault/VaultRegistryVaultRepo.sol";
// import {VaultRegistryVaultPackageRepo} from "contracts/registries/vault/VaultRegistryVaultPackageRepo.sol";
import {VaultRegistryDeploymentTarget} from "contracts/registries/vault/VaultRegistryDeploymentTarget.sol";

contract VaultRegistryDeploymentFacet is VaultRegistryDeploymentTarget, IFacet {
    /* ------------------------------- IFacet ------------------------------- */

    function facetName() public pure override returns (string memory name) {
        return type(VaultRegistryDeploymentFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IVaultRegistryDeployment).interfaceId;
    }

    /**
     * @notice Returns the function selectors supported by this facet
     * @return selectors Array of 4-byte function selectors
     */
    function facetFuncs() public pure override returns (bytes4[] memory selectors) {
        selectors = new bytes4[](2);
        selectors[0] = IVaultRegistryDeployment.deployPkg.selector;
        selectors[1] = IVaultRegistryDeployment.deployVault.selector;
    }

    function facetMetadata()
        public
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }

    /* -------------------------------------------------------------------------- */
    /*                          IVaultRegistryDeployment                          */
    /* -------------------------------------------------------------------------- */

    // function deployPkg(bytes calldata initCode, bytes calldata initArgs, bytes32 salt)
    //     public
    //     onlyOwnerOrOperator
    //     returns (address pkg)
    // {
    //     // pkg = CREATE2_CALLBACK_FACTORY.create3WithInitData(initCode, initArgs, salt);
    //     pkg = Create3FactoryAwareRepo._create3Factory().create3WithArgs(initCode, initArgs, salt);
    //     VaultRegistryVaultPackageRepo._registerPkg(pkg, IStandardVaultPkg(pkg).vaultDeclaration());
    //     return pkg;
    // }

    // function deployVault(IStandardVaultPkg pkg, bytes calldata pkgArgs) public returns (address vault) {
    //     if (!VaultRegistryVaultPackageRepo._isPkg(address(pkg))) {
    //         revert PkgNotRegistered(address(pkg));
    //     }
    //     vault = DiamondPackageFactoryAwareRepo._diamondPackageFactory()
    //         .deploy(IDiamondFactoryPackage(address(pkg)), pkgArgs);
    //     VaultRegistryVaultRepo._registerVault(vault, address(pkg), IStandardVault(vault).vaultConfig());
    // }
}
