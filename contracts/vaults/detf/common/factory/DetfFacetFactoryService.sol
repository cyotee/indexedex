// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
// Explicit dependencies keep factory-loaded bytecode available in focused builds.
import {DETFFundedBondMetadataFacet} from "contracts/vaults/detf/common/bondNft/DETFFundedBondMetadataFacet.sol";
import {DETFSYFacet} from "contracts/vaults/detf/common/sy/DETFSYFacet.sol";
import {DETFNFTVaultFacet} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultFacet.sol";
import {UniswapV4DetfBondNFTVaultFacet} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/UniswapV4DetfBondNFTVaultFacet.sol";
import {RebasingClaimTokenFacet} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenFacet.sol";

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

library DetfFacetFactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    /// @notice Deploy the read-only funded bond renderer independently from custody.
    function deployDETFFundedBondMetadataFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        bytes memory code_ = ArtifactCreationCode.creationCode("DETFFundedBondMetadataFacet.sol:DETFFundedBondMetadataFacet");
        instance = create3Factory.deployFacet(
            code_, ArtifactCreationCode.releaseSalt(keccak256("DETFFundedBondMetadataFacet"), code_, bytes(""))
        );
        vm.label(address(instance), "DETFFundedBondMetadataFacet");
    }

    /// @notice Deploy the common static DETF SY facet through CREATE3.
    function deployDETFSYFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        bytes memory code_ = ArtifactCreationCode.creationCode("DETFSYFacet.sol:DETFSYFacet");
        instance = create3Factory.deployFacet(
            code_, ArtifactCreationCode.releaseSalt(keccak256("DETFSYFacet"), code_, bytes(""))
        );
        vm.label(address(instance), "DETFSYFacet");
    }

    function deployDETFNFTVaultFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("DETFNFTVaultFacet.sol:DETFNFTVaultFacet"),
            abi.encode("DETFNFTVaultFacet")._hash()
        );
        vm.label(address(instance), "DETFNFTVaultFacet");
    }

    function deployUniswapV4DetfBondNFTVaultFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("UniswapV4DetfBondNFTVaultFacet.sol:UniswapV4DetfBondNFTVaultFacet");
        instance = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4DetfBondNFTVaultFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(instance), "UniswapV4DetfBondNFTVaultFacet");
    }

    function deployRebasingClaimTokenFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("RebasingClaimTokenFacet.sol:RebasingClaimTokenFacet");
        instance = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("RebasingClaimTokenFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(instance), "RebasingClaimTokenFacet");
    }

    function deployRebasingDETFTokenFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("RebasingDETFTokenFacet.sol:RebasingDETFTokenFacet"),
            abi.encode("RebasingDETFTokenFacet")._hash()
        );
        vm.label(address(instance), "RebasingDETFTokenFacet");
    }

    function deployERC4626BasedBasicVaultFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("ERC4626BasedBasicVaultFacet.sol:ERC4626BasedBasicVaultFacet"),
            abi.encode("ERC4626BasedBasicVaultFacet")._hash()
        );
        vm.label(address(instance), "ERC4626BasedBasicVaultFacet");
    }

    function deployERC4626StandardVaultFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("ERC4626StandardVaultFacet.sol:ERC4626StandardVaultFacet"),
            abi.encode("ERC4626StandardVaultFacet")._hash()
        );
        vm.label(address(instance), "ERC4626StandardVaultFacet");
    }
}
