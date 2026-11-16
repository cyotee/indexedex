// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {Vm} from 'forge-std/Vm.sol';
import {VM_ADDRESS} from '@crane/contracts/constants/FoundryConstants.sol';
import {BetterEfficientHashLib} from '@crane/contracts/utils/BetterEfficientHashLib.sol';

import {IVaultRegistryDeployment} from 'contracts/interfaces/IVaultRegistryDeployment.sol';
import {IComposedStableCommonDetfDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/IComposedStableCommonDetfDFPkg.sol";

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
                    ArtifactCreationCode.creationCode("ComposedStableCommonDetfDFPkg.sol:ComposedStableCommonDetfDFPkg"),
                    abi.encode(pkgInit_),
                    abi.encode("ComposedStableCommonDetfDFPkg")._hash()
                )
            )
        );
        vm.label(address(instance_), "ComposedStableCommonDetfDFPkg");
    }
}