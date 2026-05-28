// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import {Vm} from "forge-std/Vm.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IEthereumDualSelfCommonDETFDFPkg, EthereumDualSelfCommonDETFDFPkg} from "contracts/vaults/protocol/EthereumDualSelfCommonDETFDFPkg.sol";

/**
 * @title EthereumDualSelfCommonDETF_Pkg_FactoryService
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Factory service for deploying Ethereum Protocol DETF packages via CREATE3.
 */
library EthereumDualSelfCommonDETF_Pkg_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployEthereumDualSelfCommonDETFDFPkg(
        IVaultRegistryDeployment vaultRegistry,
        IEthereumDualSelfCommonDETFDFPkg.PkgInit memory pkgInit
    ) internal returns (IEthereumDualSelfCommonDETFDFPkg instance) {
        instance = IEthereumDualSelfCommonDETFDFPkg(
            address(
                vaultRegistry.deployPkg(
                    type(EthereumDualSelfCommonDETFDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(EthereumDualSelfCommonDETFDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(EthereumDualSelfCommonDETFDFPkg).name);
    }
}