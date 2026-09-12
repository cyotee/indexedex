// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {Vm} from "forge-std/Vm.sol";

import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
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
            ArtifactCreationCode.creationCode("AaveCrossVersionLoopExchangeInFacet.sol:AaveCrossVersionLoopExchangeInFacet"),
            abi.encode("AaveCrossVersionLoopExchangeInFacet")._hash()
        );
        vm.label(address(instance), "AaveCrossVersionLoopExchangeInFacet");
    }

    function deployExchangeOutFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("AaveCrossVersionLoopExchangeOutFacet.sol:AaveCrossVersionLoopExchangeOutFacet"),
            abi.encode("AaveCrossVersionLoopExchangeOutFacet")._hash()
        );
        vm.label(address(instance), "AaveCrossVersionLoopExchangeOutFacet");
    }

    function deployRebalanceFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("AaveCrossVersionLoopRebalanceFacet.sol:AaveCrossVersionLoopRebalanceFacet"),
            abi.encode("AaveCrossVersionLoopRebalanceFacet")._hash()
        );
        vm.label(address(instance), "AaveCrossVersionLoopRebalanceFacet");
    }

    function deployMarkerFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("AaveCrossVersionLoopMarkerFacet.sol:AaveCrossVersionLoopMarkerFacet"),
            abi.encode("AaveCrossVersionLoopMarkerFacet")._hash()
        );
        vm.label(address(instance), "AaveCrossVersionLoopMarkerFacet");
    }

    /// @notice Deploys + registers the DFPkg through the VaultRegistry (via the IndexedexManager).
    function deployCrossVersionLoopDFPkg(
        IIndexedexManagerProxy indexedexManager,
        AaveCrossVersionLoopDFPkg.PkgInit memory pkgInit
    ) internal returns (AaveCrossVersionLoopDFPkg instance) {
        instance = AaveCrossVersionLoopDFPkg(
            address(
                IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
                    ArtifactCreationCode.creationCode("AaveCrossVersionLoopDFPkg.sol:AaveCrossVersionLoopDFPkg"),
                    abi.encode(pkgInit),
                    abi.encode("AaveCrossVersionLoopDFPkg")._hash()
                )
            )
        );
        vm.label(address(instance), "AaveCrossVersionLoopDFPkg");
    }
}
