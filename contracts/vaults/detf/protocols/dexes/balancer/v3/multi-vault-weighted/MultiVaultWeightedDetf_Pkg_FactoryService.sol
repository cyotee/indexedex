// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IMultiVaultWeightedDetfDFPkg,
    MultiVaultWeightedDetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol";

library MultiVaultWeightedDetf_Pkg_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployMultiVaultWeightedDetfDFPkg(
        IVaultRegistryDeployment vaultRegistry_,
        IMultiVaultWeightedDetfDFPkg.PkgInit memory pkgInit_
    ) internal returns (IMultiVaultWeightedDetfDFPkg instance_) {
        instance_ = IMultiVaultWeightedDetfDFPkg(
            address(
                vaultRegistry_.deployPkg(
                    type(MultiVaultWeightedDetfDFPkg).creationCode,
                    abi.encode(pkgInit_),
                    abi.encode(type(MultiVaultWeightedDetfDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance_), type(MultiVaultWeightedDetfDFPkg).name);
    }
}
