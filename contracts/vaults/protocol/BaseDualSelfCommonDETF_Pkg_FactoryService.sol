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
import {BaseDualSelfCommonDETFDFPkg, IBaseDualSelfCommonDETFDFPkg} from "contracts/vaults/protocol/BaseDualSelfCommonDETFDFPkg.sol";
import {ProtocolNFTVaultDFPkg, IProtocolNFTVaultDFPkg} from "contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/reusable/nft/IDetfSelfNftInventoryDFPkg.sol";
import {RICHIRDFPkg, IRICHIRDFPkg} from "contracts/vaults/protocol/RICHIRDFPkg.sol";

/**
 * @title BaseDualSelfCommonDETF_Pkg_FactoryService
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Factory service for deploying Protocol DETF packages via CREATE3.
 * @dev Separated from facet deployment to avoid stack-too-deep.
 */
library BaseDualSelfCommonDETF_Pkg_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    /* ---------------------------------------------------------------------- */
    /*                            Package Deployment                          */
    /* ---------------------------------------------------------------------- */

    function deployBaseDualSelfCommonDETFDFPkg(IVaultRegistryDeployment vaultRegistry, IBaseDualSelfCommonDETFDFPkg.PkgInit memory pkgInit)
        internal
        returns (IBaseDualSelfCommonDETFDFPkg instance)
    {
        instance = IBaseDualSelfCommonDETFDFPkg(
            address(
                vaultRegistry.deployPkg(
                    type(BaseDualSelfCommonDETFDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(BaseDualSelfCommonDETFDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(BaseDualSelfCommonDETFDFPkg).name);
    }

    function deployProtocolNFTVaultDFPkg(
        IVaultRegistryDeployment vaultRegistry,
        IProtocolNFTVaultDFPkg.PkgInit memory pkgInit
    ) internal returns (IDetfSelfNftInventoryDFPkg instance) {
        instance = IDetfSelfNftInventoryDFPkg(
            address(
                vaultRegistry.deployPkg(
                    type(ProtocolNFTVaultDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(ProtocolNFTVaultDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(ProtocolNFTVaultDFPkg).name);
    }

    function deployRICHIRDFPkg(ICreate3FactoryProxy create3Factory, IRICHIRDFPkg.PkgInit memory pkgInit)
        internal
        returns (IRICHIRDFPkg instance)
    {
        instance = IRICHIRDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(RICHIRDFPkg).creationCode, abi.encode(pkgInit), abi.encode(type(RICHIRDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(RICHIRDFPkg).name);
    }
}
