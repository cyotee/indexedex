// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    ERC4626StandardExchangeInFacet
} from "contracts/vaults/standard/erc4626/ERC4626StandardExchangeInFacet.sol";
import {
    ERC4626StandardExchangeOutFacet
} from "contracts/vaults/standard/erc4626/ERC4626StandardExchangeOutFacet.sol";
import {
    ERC4626StandardExchangeMarkerFacet
} from "contracts/vaults/standard/erc4626/ERC4626StandardExchangeMarkerFacet.sol";
import {
    IERC4626StandardExchangeDFPkg,
    ERC4626StandardExchangeDFPkg
} from "contracts/vaults/standard/erc4626/ERC4626StandardExchangeDFPkg.sol";

library ERC4626StandardExchange_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployERC4626StandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(ERC4626StandardExchangeInFacet).creationCode,
            abi.encode(type(ERC4626StandardExchangeInFacet).name)._hash()
        );
        vm.label(address(instance), type(ERC4626StandardExchangeInFacet).name);
    }

    function deployERC4626StandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(ERC4626StandardExchangeOutFacet).creationCode,
            abi.encode(type(ERC4626StandardExchangeOutFacet).name)._hash()
        );
        vm.label(address(instance), type(ERC4626StandardExchangeOutFacet).name);
    }

    function deployERC4626StandardExchangeMarkerFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(ERC4626StandardExchangeMarkerFacet).creationCode,
            abi.encode(type(ERC4626StandardExchangeMarkerFacet).name)._hash()
        );
        vm.label(address(instance), type(ERC4626StandardExchangeMarkerFacet).name);
    }

    function deployERC4626StandardExchangeDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IERC4626StandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IERC4626StandardExchangeDFPkg instance) {
        instance = IERC4626StandardExchangeDFPkg(
            address(
                IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
                    type(ERC4626StandardExchangeDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(ERC4626StandardExchangeDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(ERC4626StandardExchangeDFPkg).name);
    }
}
