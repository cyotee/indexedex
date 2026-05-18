// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {ISingleVaultDetfDFPkg, SingleVaultDetfDFPkg} from "contracts/vaults/detf/composed/single/SingleVaultDetfDFPkg.sol";

library SingleVaultDetf_Pkg_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deploySingleVaultDetfDFPkg(
        IVaultRegistryDeployment vaultRegistry_,
        ISingleVaultDetfDFPkg.PkgInit memory pkgInit_
    ) internal returns (ISingleVaultDetfDFPkg instance_) {
        instance_ = ISingleVaultDetfDFPkg(
            address(
                vaultRegistry_.deployPkg(
                    type(SingleVaultDetfDFPkg).creationCode,
                    abi.encode(pkgInit_),
                    abi.encode(type(SingleVaultDetfDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance_), type(SingleVaultDetfDFPkg).name);
    }
}