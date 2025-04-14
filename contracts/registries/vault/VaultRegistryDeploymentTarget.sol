// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

// import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {Create3FactoryAwareRepo} from "@crane/contracts/factories/create3/Create3FactoryAwareRepo.sol";
import {DiamondPackageFactoryAwareRepo} from "@crane/contracts/factories/diamondPkg/DiamondPackageFactoryAwareRepo.sol";
import {OperableModifiers} from "@crane/contracts/access/operable/OperableModifiers.sol";
import {OperableRepo} from "@crane/contracts/access/operable/OperableRepo.sol";
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {VaultRegistryVaultRepo} from "contracts/registries/vault/VaultRegistryVaultRepo.sol";
import {VaultRegistryVaultPackageRepo} from "contracts/registries/vault/VaultRegistryVaultPackageRepo.sol";

contract VaultRegistryDeploymentTarget is OperableModifiers, IVaultRegistryDeployment {
    /* -------------------------------------------------------------------------- */
    /*                          IVaultRegistryDeployment                          */
    /* -------------------------------------------------------------------------- */

    function deployPkg(bytes calldata initCode, bytes calldata initArgs, bytes32 salt)
        public
        onlyOwnerOrOperator
        returns (address pkg)
    {
        // pkg = CREATE2_CALLBACK_FACTORY.create3WithInitData(initCode, initArgs, salt);
        pkg = Create3FactoryAwareRepo._create3Factory().create3WithArgs(initCode, initArgs, salt);
        VaultRegistryVaultPackageRepo._registerPkg(pkg, IStandardVaultPkg(pkg).vaultDeclaration());
        return pkg;
    }

    /**
     * @notice Deploy a vault instance from a registered package.
     * @dev Authorization: Only owner, operator, or registered packages can call this.
     *      Registered packages (deployed via deployPkg) are implicitly authorized to deploy
     *      vault instances for themselves, enabling the DFPkg.deployVault() helper pattern.
     * @param pkg The vault package to deploy from (must be registered)
     * @param pkgArgs Package-specific arguments for vault initialization
     * @return vault The address of the deployed vault
     */
    function deployVault(IStandardVaultPkg pkg, bytes calldata pkgArgs) public returns (address vault) {
        // Authorization: owner, operator, or registered package
        _onlyOwnerOrOperatorOrPkg();

        if (!VaultRegistryVaultPackageRepo._isPkg(address(pkg))) {
            revert PkgNotRegistered(address(pkg));
        }
        vault = DiamondPackageFactoryAwareRepo._diamondPackageFactory()
            .deploy(IDiamondFactoryPackage(address(pkg)), pkgArgs);
        VaultRegistryVaultRepo._registerVault(vault, address(pkg), IStandardVault(vault).vaultConfig());
    }

    /* -------------------------------------------------------------------------- */
    /*                              Internal Functions                             */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Reverts if caller is not owner, operator, or a registered package.
     *      This allows DFPkg contracts to call deployVault() on behalf of users while
     *      still blocking arbitrary unauthorized callers.
     */
    function _onlyOwnerOrOperatorOrPkg() internal view {
        // Check if caller is owner
        if (MultiStepOwnableRepo._owner() == msg.sender) {
            return;
        }
        // Check if caller is global operator
        if (OperableRepo._isOperator(msg.sender)) {
            return;
        }
        // Check if caller is function-level operator
        if (OperableRepo._isFunctionOperator(msg.sig, msg.sender)) {
            return;
        }
        // Check if caller is a registered package
        if (VaultRegistryVaultPackageRepo._isPkg(msg.sender)) {
            return;
        }
        // None of the above - revert
        revert IOperable.NotOperator(msg.sender);
    }
}
