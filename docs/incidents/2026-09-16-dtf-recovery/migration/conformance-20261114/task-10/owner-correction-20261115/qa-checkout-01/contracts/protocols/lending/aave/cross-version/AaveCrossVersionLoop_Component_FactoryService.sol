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
import {IAaveCrossVersionLoopDFPkg} from "contracts/protocols/lending/aave/cross-version/IAaveCrossVersionLoopDFPkg.sol";

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

    function deployTransitionQuoteFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(
                "AaveCrossVersionLoopStandardExchangeTransitionQuoteFacet.sol:AaveCrossVersionLoopStandardExchangeTransitionQuoteFacet"
            ),
            abi.encode("AaveCrossVersionLoopStandardExchangeTransitionQuoteFacet")._hash()
        );
        vm.label(address(instance), "AaveCrossVersionLoopStandardExchangeTransitionQuoteFacet");
    }

    /// @notice Deploys + registers the DFPkg through the VaultRegistry (via the IndexedexManager).
    /// @dev Canonical (production/launch) entry point: the package salt is the fixed family namespace
    ///      so the package lands at the same deterministic address every deploy. A second package on
    ///      one manager reuses that address (CREATE3 is idempotent). Test harnesses that need several
    ///      distinct packages on one shared manager (the R10.3 multi-leg SE matrix, where each leg
    ///      binds a distinct Aave market) call the discriminated overload below.
    function deployCrossVersionLoopDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IAaveCrossVersionLoopDFPkg.PkgInit memory pkgInit
    ) internal returns (IAaveCrossVersionLoopDFPkg instance) {
        return deployCrossVersionLoopDFPkg(indexedexManager, pkgInit, bytes32(0));
    }

    /// @notice Same as the 2-argument deploy, with a salt discriminator so several packages can be
    ///         deployed on one manager at distinct addresses.
    /// @param disc Salt discriminator. `bytes32(0)` reproduces the canonical package address byte for
    ///        byte (production/launch/existing single-package callers stay unchanged); any non-zero
    ///        value namespaces the salt to a distinct package.
    function deployCrossVersionLoopDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IAaveCrossVersionLoopDFPkg.PkgInit memory pkgInit,
        bytes32 disc
    ) internal returns (IAaveCrossVersionLoopDFPkg instance) {
        bytes32 salt = disc == bytes32(0)
            ? abi.encode("AaveCrossVersionLoopDFPkg")._hash()
            : keccak256(abi.encode("AaveCrossVersionLoopDFPkg", disc));
        instance = IAaveCrossVersionLoopDFPkg(
            address(
                IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
                    ArtifactCreationCode.creationCode("AaveCrossVersionLoopDFPkg.sol:AaveCrossVersionLoopDFPkg"),
                    abi.encode(pkgInit),
                    salt
                )
            )
        );
        vm.label(address(instance), "AaveCrossVersionLoopDFPkg");
    }
}
