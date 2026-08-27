// SPDX-License-Identifier: BSL-1.1
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

import {DETFNFTVaultFacet} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultFacet.sol";
import {UniswapV4DetfBondNFTVaultFacet} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/UniswapV4DetfBondNFTVaultFacet.sol";
import {RebasingClaimTokenFacet} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenFacet.sol";
import {RebasingDETFTokenFacet} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenFacet.sol";
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

    function deployUniswapV4DetfBondNFTVaultFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV4DetfBondNFTVaultFacet).creationCode,
            abi.encode(type(UniswapV4DetfBondNFTVaultFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV4DetfBondNFTVaultFacet).name);
    }

    function deployRebasingClaimTokenFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(type(RebasingClaimTokenFacet).creationCode, abi.encode(type(RebasingClaimTokenFacet).name)._hash());
        vm.label(address(instance), type(RebasingClaimTokenFacet).name);
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