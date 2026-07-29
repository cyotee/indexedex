// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IMixedBufferMultiVaultStableDetfDFPkg,
    MixedBufferMultiVaultStableDetfDFPkg
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfDFPkg.sol";

library MixedBufferMultiVaultStableDetf_Pkg_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployMixedBufferMultiVaultStableDetfDFPkg(
        IVaultRegistryDeployment vaultRegistry_,
        IMixedBufferMultiVaultStableDetfDFPkg.PkgInit memory pkgInit_
    ) internal returns (IMixedBufferMultiVaultStableDetfDFPkg instance_) {
        instance_ = IMixedBufferMultiVaultStableDetfDFPkg(
            address(
                vaultRegistry_.deployPkg(
                    type(MixedBufferMultiVaultStableDetfDFPkg).creationCode,
                    abi.encode(pkgInit_),
                    abi.encode(type(MixedBufferMultiVaultStableDetfDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance_), type(MixedBufferMultiVaultStableDetfDFPkg).name);
    }
}
