// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    ISingleStandardExchangeDETDFPkg,
    SingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETDFPkg.sol";

library SingleStandardExchangeDETF_Pkg_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deploySingleStandardExchangeDETDFPkg(
        IVaultRegistryDeployment vaultRegistry_,
        ISingleStandardExchangeDETDFPkg.PkgInit memory pkgInit_
    ) internal returns (ISingleStandardExchangeDETDFPkg instance_) {
        instance_ = ISingleStandardExchangeDETDFPkg(
            address(
                vaultRegistry_.deployPkg(
                    type(SingleStandardExchangeDETDFPkg).creationCode,
                    abi.encode(pkgInit_),
                    abi.encode(type(SingleStandardExchangeDETDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance_), type(SingleStandardExchangeDETDFPkg).name);
    }
}
