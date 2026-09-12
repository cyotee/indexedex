// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import {Vm} from "forge-std/Vm.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {ISlipstreamStandardExchangeDFPkg} from "contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeDFPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";

/**
 * @title Slipstream_Component_FactoryService
 * @notice Library for deploying Slipstream Standard Exchange components via CREATE3.
 * @author cyotee doge <doge.cyotee>
 */
library Slipstream_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deploySlipstreamStandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("SlipstreamStandardExchangeInFacet.sol:SlipstreamStandardExchangeInFacet"),
            abi.encode("SlipstreamStandardExchangeInFacet")._hash()
        );
        vm.label(address(instance), "SlipstreamStandardExchangeInFacet");
    }

    function deploySlipstreamStandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("SlipstreamStandardExchangeOutFacet.sol:SlipstreamStandardExchangeOutFacet"),
            abi.encode("SlipstreamStandardExchangeOutFacet")._hash()
        );
        vm.label(address(instance), "SlipstreamStandardExchangeOutFacet");
    }

    function deploySlipstreamStandardExchangeDFPkgFromVaultRegistry(
        IVaultRegistryDeployment vaultRegistry,
        ISlipstreamStandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (ISlipstreamStandardExchangeDFPkg instance) {
        instance = ISlipstreamStandardExchangeDFPkg(
            address(
                vaultRegistry.deployPkg(
                    ArtifactCreationCode.creationCode("SlipstreamStandardExchangeDFPkg.sol:SlipstreamStandardExchangeDFPkg"),
                    abi.encode(pkgInit),
                    abi.encode("SlipstreamStandardExchangeDFPkg")._hash()
                )
            )
        );
        vm.label(address(instance), "SlipstreamStandardExchangeDFPkg");
    }

    function deploySlipstreamStandardExchangeDFPkg(
        IIndexedexManagerProxy indexedexManager,
        ISlipstreamStandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (ISlipstreamStandardExchangeDFPkg instance) {
        return deploySlipstreamStandardExchangeDFPkgFromVaultRegistry(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
    }
}
