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
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {IDETFSYDFPkg} from "contracts/vaults/detf/common/sy/DETFSYDFPkg.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";
import {IUniswapV4DetfBondNFTVaultDFPkg} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/UniswapV4DetfBondNFTVaultDFPkg.sol";

import {IUniswapV4DetfDFPkg} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {IRebasingDETFTokenDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenDFPkg.sol";

library DetfPkgFactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    /// @notice Shared test/script setup; the caller retains the registry's normal deployment authority.
    function deployDETFSYComponents(
        ICreate3FactoryProxy factory_, IVaultRegistryDeployment registry_, IVaultFeeOracleQuery oracle_,
        IFacet domain_, IFacet permit_
    ) internal returns (IDETFSYDFPkg) {
        return deployDETFSYDFPkg(registry_, IDETFSYDFPkg.PkgInit({
            erc5267Facet: domain_, erc2612Facet: permit_,
            syFacet: DetfFacetFactoryService.deployDETFSYFacet(factory_),
            feeOracle: oracle_, vaultRegistryDeployment: registry_
        }));
    }

    /// @notice Deploy/register the common wrapper package through the manager's vault registry.
    function deployDETFSYDFPkg(IVaultRegistryDeployment registry_, IDETFSYDFPkg.PkgInit memory init_)
        internal returns (IDETFSYDFPkg instance_)
    {
        bytes memory code_ = ArtifactCreationCode.creationCode("DETFSYDFPkg.sol:DETFSYDFPkg");
        bytes memory args_ = abi.encode(init_);
        instance_ = IDETFSYDFPkg(address(registry_.deployPkg(
            code_, args_, ArtifactCreationCode.releaseSalt(keccak256("DETFSYDFPkg"), code_, args_)
        )));
        vm.label(address(instance_), "DETFSYDFPkg");
    }

    function deployDETFNFTVaultDFPkg(
        IVaultRegistryDeployment vaultRegistry,
        IDETFNFTVaultDFPkg.PkgInit memory pkgInit
    ) internal returns (IDetfSelfNftInventoryDFPkg instance) {
        instance = IDetfSelfNftInventoryDFPkg(
            address(
                vaultRegistry.deployPkg(
                    ArtifactCreationCode.creationCode("DETFNFTVaultDFPkg.sol:DETFNFTVaultDFPkg"),
                    abi.encode(pkgInit),
                    abi.encode("DETFNFTVaultDFPkg")._hash()
                )
            )
        );
        vm.label(address(instance), "DETFNFTVaultDFPkg");
    }

    function deployUniswapV4DetfDFPkg(
        IVaultRegistryDeployment vaultRegistry,
        IUniswapV4DetfDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV4DetfDFPkg instance) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("UniswapV4DetfDFPkg.sol:UniswapV4DetfDFPkg");
        bytes memory initArgs_ = abi.encode(pkgInit);
        instance = IUniswapV4DetfDFPkg(
            address(
                vaultRegistry.deployPkg(
                    initCode_,
                    initArgs_,
                    ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4DetfDFPkg")._hash(), initCode_, initArgs_)
                )
            )
        );
        vm.label(address(instance), "UniswapV4DetfDFPkg");
    }

    function deployUniswapV4DetfBondNFTVaultDFPkg(
        IVaultRegistryDeployment vaultRegistry,
        IDETFNFTVaultDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV4DetfBondNFTVaultDFPkg instance) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("UniswapV4DetfBondNFTVaultDFPkg.sol:UniswapV4DetfBondNFTVaultDFPkg");
        bytes memory initArgs_ = abi.encode(pkgInit);
        instance = IUniswapV4DetfBondNFTVaultDFPkg(
            address(
                vaultRegistry.deployPkg(
                    initCode_,
                    initArgs_,
                    ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4DetfBondNFTVaultDFPkg")._hash(), initCode_, initArgs_)
                )
            )
        );
        vm.label(address(instance), "UniswapV4DetfBondNFTVaultDFPkg");
    }

    function deployRebasingDETFTokenDFPkg(
        ICreate3FactoryProxy create3Factory,
        IRebasingDETFTokenDFPkg.PkgInit memory pkgInit
    ) internal returns (IRebasingDETFTokenDFPkg instance) {
        instance = IRebasingDETFTokenDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    ArtifactCreationCode.creationCode("RebasingDETFTokenDFPkg.sol:RebasingDETFTokenDFPkg"),
                    abi.encode(pkgInit),
                    abi.encode("RebasingDETFTokenDFPkg")._hash()
                )
            )
        );
        vm.label(address(instance), "RebasingDETFTokenDFPkg");
    }

    function deployRebasingClaimTokenDFPkg(ICreate3FactoryProxy create3Factory, IRebasingClaimTokenDFPkg.PkgInit memory pkgInit)
        internal
        returns (IRebasingClaimTokenDFPkg instance)
    {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("RebasingClaimTokenDFPkg.sol:RebasingClaimTokenDFPkg");
        bytes memory initArgs_ = abi.encode(pkgInit);
        instance = IRebasingClaimTokenDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    initCode_,
                    initArgs_,
                    ArtifactCreationCode.releaseSalt(abi.encode("RebasingClaimTokenDFPkg")._hash(), initCode_, initArgs_)
                )
            )
        );
        vm.label(address(instance), "RebasingClaimTokenDFPkg");
    }
}
