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
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {DETFNFTVaultFacet} from "contracts/vaults/protocol/DETFNFTVaultFacet.sol";
import {RICHIRFacet} from "contracts/vaults/protocol/RICHIRFacet.sol";
import {RebasingDETFTokenFacet} from "contracts/vaults/detf/composed/stable/common/RebasingDETFTokenFacet.sol";
import {ERC4626BasedBasicVaultFacet} from "contracts/vaults/basic/ERC4626BasedBasicVaultFacet.sol";
import {ERC4626StandardVaultFacet} from "contracts/vaults/standard/ERC4626StandardVaultFacet.sol";

library DetfFacetFactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployDETFNFTVaultFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(DETFNFTVaultFacet).creationCode,
            abi.encode(type(DETFNFTVaultFacet).name)._hash()
        );
        vm.label(address(instance), type(DETFNFTVaultFacet).name);
    }

    function deployRICHIRFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(type(RICHIRFacet).creationCode, abi.encode(type(RICHIRFacet).name)._hash());
        vm.label(address(instance), type(RICHIRFacet).name);
    }

    function deployRebasingDETFTokenFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(RebasingDETFTokenFacet).creationCode,
            abi.encode(type(RebasingDETFTokenFacet).name)._hash()
        );
        vm.label(address(instance), type(RebasingDETFTokenFacet).name);
    }

    function deployERC4626BasedBasicVaultFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(ERC4626BasedBasicVaultFacet).creationCode,
            abi.encode(type(ERC4626BasedBasicVaultFacet).name)._hash()
        );
        vm.label(address(instance), type(ERC4626BasedBasicVaultFacet).name);
    }

    function deployERC4626StandardVaultFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(ERC4626StandardVaultFacet).creationCode,
            abi.encode(type(ERC4626StandardVaultFacet).name)._hash()
        );
        vm.label(address(instance), type(ERC4626StandardVaultFacet).name);
    }
}