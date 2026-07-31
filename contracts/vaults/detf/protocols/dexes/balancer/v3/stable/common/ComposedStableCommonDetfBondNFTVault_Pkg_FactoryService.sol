// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IComposedStableCommonDetfBondNFTVaultDFPkg,
    ComposedStableCommonDetfBondNFTVaultDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondNFTVaultDFPkg.sol";

library ComposedStableCommonDetfBondNFTVault_Pkg_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm internal constant vm = Vm(VM_ADDRESS);

    function deployComposedStableCommonDetfBondNFTVaultDFPkg(
        IVaultRegistryDeployment vaultRegistryDeployment_,
        IComposedStableCommonDetfBondNFTVaultDFPkg.PkgInit memory pkgInit_
    ) internal returns (IComposedStableCommonDetfBondNFTVaultDFPkg instance_) {
        instance_ = IComposedStableCommonDetfBondNFTVaultDFPkg(
            vaultRegistryDeployment_.deployPkg(
                type(ComposedStableCommonDetfBondNFTVaultDFPkg).creationCode,
                abi.encode(pkgInit_),
                abi.encode(type(ComposedStableCommonDetfBondNFTVaultDFPkg).name)._hash()
            )
        );
        vm.label(address(instance_), type(ComposedStableCommonDetfBondNFTVaultDFPkg).name);
    }
}