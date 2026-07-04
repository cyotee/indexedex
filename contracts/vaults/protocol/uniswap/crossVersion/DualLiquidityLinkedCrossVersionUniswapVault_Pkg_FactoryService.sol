// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg,
    DualLiquidityLinkedCrossVersionUniswapVaultDFPkg
} from "contracts/vaults/protocol/uniswap/crossVersion/DualLiquidityLinkedCrossVersionUniswapVaultDFPkg.sol";

/// @notice Registry-path package deploy helper for DualLiquidityLinkedCrossVersionUniswapVault.
library DualLiquidityLinkedCrossVersionUniswapVault_Pkg_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployDualLiquidityLinkedCrossVersionUniswapVaultDFPkg(
        IVaultRegistryDeployment vaultRegistry,
        IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg.PkgInit memory pkgInit
    ) internal returns (IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg instance) {
        instance = IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg(
            address(
                vaultRegistry.deployPkg(
                    type(DualLiquidityLinkedCrossVersionUniswapVaultDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(DualLiquidityLinkedCrossVersionUniswapVaultDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(DualLiquidityLinkedCrossVersionUniswapVaultDFPkg).name);
    }
}
