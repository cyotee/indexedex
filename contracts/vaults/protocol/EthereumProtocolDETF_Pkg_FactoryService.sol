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
import {IEthereumProtocolDETFDFPkg, EthereumProtocolDETFDFPkg} from "contracts/vaults/protocol/EthereumProtocolDETFDFPkg.sol";

/**
 * @title EthereumProtocolDETF_Pkg_FactoryService
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Factory service for deploying Ethereum Protocol DETF packages via CREATE3.
 */
library EthereumProtocolDETF_Pkg_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployEthereumProtocolDETFDFPkg(
        IVaultRegistryDeployment vaultRegistry,
        IEthereumProtocolDETFDFPkg.PkgInit memory pkgInit
    ) internal returns (IEthereumProtocolDETFDFPkg instance) {
        instance = IEthereumProtocolDETFDFPkg(
            address(
                vaultRegistry.deployPkg(
                    type(EthereumProtocolDETFDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(EthereumProtocolDETFDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(EthereumProtocolDETFDFPkg).name);
    }
}