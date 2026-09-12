// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {RebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626DFPkg.sol";
import {RebasingAwareERC4626Facet} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Facet.sol";
import {RebasingAwareStandardExchangeFacet} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareStandardExchangeFacet.sol";
import {RebasingAwareStandardYieldFacet} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldFacet.sol";
import {RebasingAwareVaultMetadataFacet} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareVaultMetadataFacet.sol";
import {RebasingAwareStandardExchangeQuoteFacet} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareStandardExchangeQuoteFacet.sol";

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";

import {IRebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";

library RebasingAwareERC4626_Component_FactoryService {
    string internal constant RELEASE_ID = "indexedex.rebasing-aware-erc4626.sy-se.v1";

    Vm constant vm = Vm(VM_ADDRESS);

    function releaseSalt(string memory componentName, bytes memory initCode, bytes memory initArgs)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(RELEASE_ID, componentName, keccak256(initCode), keccak256(initArgs)));
    }

    function deployRebasingAwareERC4626Facet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory code =
            ArtifactCreationCode.creationCode("RebasingAwareERC4626Facet.sol:RebasingAwareERC4626Facet");
        instance = create3Factory.deployFacet(code, releaseSalt("RebasingAwareERC4626Facet", code, ""));
        vm.label(address(instance), "RebasingAwareERC4626Facet");
    }

    function deployRebasingAwareStandardExchangeFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory code = ArtifactCreationCode.creationCode(
            "RebasingAwareStandardExchangeFacet.sol:RebasingAwareStandardExchangeFacet"
        );
        instance =
            create3Factory.deployFacet(code, releaseSalt("RebasingAwareStandardExchangeFacet", code, ""));
        vm.label(address(instance), "RebasingAwareStandardExchangeFacet");
    }

    function deployRebasingAwareStandardYieldFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory code = ArtifactCreationCode.creationCode(
            "RebasingAwareStandardYieldFacet.sol:RebasingAwareStandardYieldFacet"
        );
        instance = create3Factory.deployFacet(code, releaseSalt("RebasingAwareStandardYieldFacet", code, ""));
        vm.label(address(instance), "RebasingAwareStandardYieldFacet");
    }

    function deployRebasingAwareVaultMetadataFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory code = ArtifactCreationCode.creationCode(
            "RebasingAwareVaultMetadataFacet.sol:RebasingAwareVaultMetadataFacet"
        );
        instance = create3Factory.deployFacet(code, releaseSalt("RebasingAwareVaultMetadataFacet", code, ""));
        vm.label(address(instance), "RebasingAwareVaultMetadataFacet");
    }

    function deployRebasingAwareStandardExchangeQuoteFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory code = ArtifactCreationCode.creationCode(
            "RebasingAwareStandardExchangeQuoteFacet.sol:RebasingAwareStandardExchangeQuoteFacet"
        );
        instance = create3Factory.deployFacet(
            code, releaseSalt("RebasingAwareStandardExchangeQuoteFacet", code, "")
        );
        vm.label(address(instance), "RebasingAwareStandardExchangeQuoteFacet");
    }

    function deployRebasingAwareERC4626DFPkg(
        IIndexedexManagerProxy indexedexManager,
        IRebasingAwareERC4626DFPkg.PkgInit memory pkgInit
    ) internal returns (IRebasingAwareERC4626DFPkg instance) {
        bytes memory code =
            ArtifactCreationCode.creationCode("RebasingAwareERC4626DFPkg.sol:RebasingAwareERC4626DFPkg");
        bytes memory args = abi.encode(pkgInit);
        instance = IRebasingAwareERC4626DFPkg(
            IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
                code, args, releaseSalt("RebasingAwareERC4626DFPkg", code, args)
            )
        );
        vm.label(address(instance), "RebasingAwareERC4626DFPkg");
    }
}
