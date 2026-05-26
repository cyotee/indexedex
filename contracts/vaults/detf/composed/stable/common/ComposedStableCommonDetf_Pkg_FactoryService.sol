// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {VM_ADDRESS} from '@crane/contracts/constants/FoundryConstants.sol';
import {BetterEfficientHashLib} from '@crane/contracts/utils/BetterEfficientHashLib.sol';

import {IVaultRegistryDeployment} from 'contracts/interfaces/IVaultRegistryDeployment.sol';
import {
    ComposedStableCommonDetfDFPkg,
    IComposedStableCommonDetfDFPkg
} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfDFPkg.sol';

library ComposedStableCommonDetf_Pkg_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployComposedStableCommonDetfDFPkg(
        IVaultRegistryDeployment vaultRegistry_,
        IComposedStableCommonDetfDFPkg.PkgInit memory pkgInit_
    ) internal returns (IComposedStableCommonDetfDFPkg instance_) {
        instance_ = IComposedStableCommonDetfDFPkg(
            address(
                vaultRegistry_.deployPkg(
                    type(ComposedStableCommonDetfDFPkg).creationCode,
                    abi.encode(pkgInit_),
                    abi.encode(type(ComposedStableCommonDetfDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance_), type(ComposedStableCommonDetfDFPkg).name);
    }
}