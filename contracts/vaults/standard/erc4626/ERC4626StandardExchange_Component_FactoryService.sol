// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IERC4626StandardExchangeDFPkg} from "contracts/vaults/standard/erc4626/IERC4626StandardExchangeDFPkg.sol";

library ERC4626StandardExchange_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployERC4626StandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("ERC4626StandardExchangeInFacet.sol:ERC4626StandardExchangeInFacet");
        instance = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("ERC4626StandardExchangeInFacet")._hash(), initCode_, "")
        );
        vm.label(address(instance), "ERC4626StandardExchangeInFacet");
    }

    function deployERC4626StandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("ERC4626StandardExchangeOutFacet.sol:ERC4626StandardExchangeOutFacet");
        instance = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("ERC4626StandardExchangeOutFacet")._hash(), initCode_, "")
        );
        vm.label(address(instance), "ERC4626StandardExchangeOutFacet");
    }

    function deployERC4626StandardExchangeMarkerFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("ERC4626StandardExchangeMarkerFacet.sol:ERC4626StandardExchangeMarkerFacet");
        instance = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("ERC4626StandardExchangeMarkerFacet")._hash(), initCode_, "")
        );
        vm.label(address(instance), "ERC4626StandardExchangeMarkerFacet");
    }

    function deployERC4626StandardExchangeDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IERC4626StandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IERC4626StandardExchangeDFPkg instance) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("ERC4626StandardExchangeDFPkg.sol:ERC4626StandardExchangeDFPkg");
        bytes memory initArgs_ = abi.encode(pkgInit);
        instance = IERC4626StandardExchangeDFPkg(
            address(
                IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
                    initCode_,
                    initArgs_,
                    ArtifactCreationCode.releaseSalt(abi.encode("ERC4626StandardExchangeDFPkg")._hash(), initCode_, initArgs_)
                )
            )
        );
        vm.label(address(instance), "ERC4626StandardExchangeDFPkg");
    }
}
