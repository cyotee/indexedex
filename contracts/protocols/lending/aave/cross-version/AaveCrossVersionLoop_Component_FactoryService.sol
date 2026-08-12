// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

import {AaveCrossVersionLoopExchangeInFacet} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeInFacet.sol";
import {AaveCrossVersionLoopExchangeOutFacet} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeOutFacet.sol";
import {AaveCrossVersionLoopRebalanceFacet} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopRebalanceFacet.sol";
import {AaveCrossVersionLoopMarkerFacet} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopMarkerFacet.sol";
import {AaveCrossVersionLoopDFPkg} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopDFPkg.sol";

/**
 * @title AaveCrossVersionLoop_Component_FactoryService
 * @author cyotee doge <doge.cyotee>
 * @notice CREATE3 deploy helpers for the cross-version loop facets + DFPkg, and the manager/registry
 *         package-deployment helper. Mirrors the AaveV3Stata component factory service.
 */
library AaveCrossVersionLoop_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployExchangeInFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(AaveCrossVersionLoopExchangeInFacet).creationCode,
            abi.encode(type(AaveCrossVersionLoopExchangeInFacet).name)._hash()
        );
        vm.label(address(instance), type(AaveCrossVersionLoopExchangeInFacet).name);
    }

    function deployExchangeOutFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(AaveCrossVersionLoopExchangeOutFacet).creationCode,
            abi.encode(type(AaveCrossVersionLoopExchangeOutFacet).name)._hash()
        );
        vm.label(address(instance), type(AaveCrossVersionLoopExchangeOutFacet).name);
    }

    function deployRebalanceFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(AaveCrossVersionLoopRebalanceFacet).creationCode,
            abi.encode(type(AaveCrossVersionLoopRebalanceFacet).name)._hash()
        );
        vm.label(address(instance), type(AaveCrossVersionLoopRebalanceFacet).name);
    }

    function deployMarkerFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(AaveCrossVersionLoopMarkerFacet).creationCode,
            abi.encode(type(AaveCrossVersionLoopMarkerFacet).name)._hash()
        );
        vm.label(address(instance), type(AaveCrossVersionLoopMarkerFacet).name);
    }

    /// @notice Deploys + registers the DFPkg through the VaultRegistry (via the IndexedexManager).
    function deployCrossVersionLoopDFPkg(
        IIndexedexManagerProxy indexedexManager,
        AaveCrossVersionLoopDFPkg.PkgInit memory pkgInit
    ) internal returns (AaveCrossVersionLoopDFPkg instance) {
        instance = AaveCrossVersionLoopDFPkg(
            address(
                IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
                    type(AaveCrossVersionLoopDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(AaveCrossVersionLoopDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(AaveCrossVersionLoopDFPkg).name);
    }
}
