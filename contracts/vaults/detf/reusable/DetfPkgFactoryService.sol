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
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {DETFNFTVaultDFPkg, IDETFNFTVaultDFPkg} from "contracts/vaults/protocol/DETFNFTVaultDFPkg.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/reusable/nft/IDetfSelfNftInventoryDFPkg.sol";
import {RebasingClaimTokenDFPkg, IRebasingClaimTokenDFPkg} from "contracts/vaults/protocol/RebasingClaimTokenDFPkg.sol";
import {
    IRebasingDETFTokenDFPkg,
    RebasingDETFTokenDFPkg
} from "contracts/vaults/detf/composed/stable/common/RebasingDETFTokenDFPkg.sol";

library DetfPkgFactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployDETFNFTVaultDFPkg(
        IVaultRegistryDeployment vaultRegistry,
        IDETFNFTVaultDFPkg.PkgInit memory pkgInit
    ) internal returns (IDetfSelfNftInventoryDFPkg instance) {
        instance = IDetfSelfNftInventoryDFPkg(
            address(
                vaultRegistry.deployPkg(
                    type(DETFNFTVaultDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(DETFNFTVaultDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(DETFNFTVaultDFPkg).name);
    }

    function deployRebasingDETFTokenDFPkg(
        ICreate3FactoryProxy create3Factory,
        IRebasingDETFTokenDFPkg.PkgInit memory pkgInit
    ) internal returns (IRebasingDETFTokenDFPkg instance) {
        instance = IRebasingDETFTokenDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(RebasingDETFTokenDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(RebasingDETFTokenDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(RebasingDETFTokenDFPkg).name);
    }

    function deployRebasingClaimTokenDFPkg(ICreate3FactoryProxy create3Factory, IRebasingClaimTokenDFPkg.PkgInit memory pkgInit)
        internal
        returns (IRebasingClaimTokenDFPkg instance)
    {
        instance = IRebasingClaimTokenDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(RebasingClaimTokenDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(RebasingClaimTokenDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(RebasingClaimTokenDFPkg).name);
    }
}