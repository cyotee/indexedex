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
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {DETFNFTVaultDFPkg, IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";
import {
    UniswapV4DetfBondNFTVaultDFPkg,
    IUniswapV4DetfBondNFTVaultDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/UniswapV4DetfBondNFTVaultDFPkg.sol";
import {UniswapV4DetfDFPkg} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol";
import {IUniswapV4DetfDFPkg} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {RebasingClaimTokenDFPkg, IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {
    IRebasingDETFTokenDFPkg,
    RebasingDETFTokenDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenDFPkg.sol";

library DetfPkgFactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployDETFNFTVaultDFPkg(
        IVaultRegistryDeployment vaultRegistry,
        IDETFNFTVaultDFPkg.PkgInit memory pkgInit
    ) internal returns (IDetfSelfNftInventoryDFPkg instance) {
        instance = IDetfSelfNftInventoryDFPkg(
            address(
                vaultRegistry.deployPkg(
                    type(DETFNFTVaultDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(DETFNFTVaultDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(DETFNFTVaultDFPkg).name);
    }

    function deployUniswapV4DetfDFPkg(
        IVaultRegistryDeployment vaultRegistry,
        IUniswapV4DetfDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV4DetfDFPkg instance) {
        instance = IUniswapV4DetfDFPkg(
            address(
                vaultRegistry.deployPkg(
                    type(UniswapV4DetfDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(UniswapV4DetfDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(UniswapV4DetfDFPkg).name);
    }

    function deployUniswapV4DetfBondNFTVaultDFPkg(
        IVaultRegistryDeployment vaultRegistry,
        IUniswapV4DetfBondNFTVaultDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV4DetfBondNFTVaultDFPkg instance) {
        instance = IUniswapV4DetfBondNFTVaultDFPkg(
            address(
                vaultRegistry.deployPkg(
                    type(UniswapV4DetfBondNFTVaultDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(UniswapV4DetfBondNFTVaultDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(UniswapV4DetfBondNFTVaultDFPkg).name);
    }

    function deployRebasingDETFTokenDFPkg(
        ICreate3FactoryProxy create3Factory,
        IRebasingDETFTokenDFPkg.PkgInit memory pkgInit
    ) internal returns (IRebasingDETFTokenDFPkg instance) {
        instance = IRebasingDETFTokenDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(RebasingDETFTokenDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(RebasingDETFTokenDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(RebasingDETFTokenDFPkg).name);
    }

    function deployRebasingClaimTokenDFPkg(ICreate3FactoryProxy create3Factory, IRebasingClaimTokenDFPkg.PkgInit memory pkgInit)
        internal
        returns (IRebasingClaimTokenDFPkg instance)
    {
        instance = IRebasingClaimTokenDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(RebasingClaimTokenDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(RebasingClaimTokenDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(RebasingClaimTokenDFPkg).name);
    }
}