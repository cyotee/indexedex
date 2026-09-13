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
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IUniswapV2Router} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import {IUniswapV2Factory} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IUniswapV2StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v2/IUniswapV2StandardExchangeDFPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

library UniswapV2_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV2StandardExchangeInFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV2StandardExchangeInFacet.sol:UniswapV2StandardExchangeInFacet"),
            ArtifactCreationCode.releaseSalt(
                        keccak256(bytes("UniswapV2StandardExchangeInFacet")),
                        ArtifactCreationCode.creationCode("UniswapV2StandardExchangeInFacet.sol:UniswapV2StandardExchangeInFacet"), bytes("")
                    )
        );
        vm.label(address(instance), "UniswapV2StandardExchangeInFacet");
    }

    function deployUniswapV2StandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV2StandardExchangeOutFacet.sol:UniswapV2StandardExchangeOutFacet"),
            ArtifactCreationCode.releaseSalt(
                        keccak256(bytes("UniswapV2StandardExchangeOutFacet")),
                        ArtifactCreationCode.creationCode("UniswapV2StandardExchangeOutFacet.sol:UniswapV2StandardExchangeOutFacet"), bytes("")
                    )
        );
        vm.label(address(instance), "UniswapV2StandardExchangeOutFacet");
    }

    function deployUniswapV2StandardExchangeQueryFacet(ICreate3FactoryProxy create3Factory)
        internal returns (IFacet instance)
    {
        bytes memory code = ArtifactCreationCode.creationCode("UniswapV2StandardExchangeQueryFacet.sol:UniswapV2StandardExchangeQueryFacet");
        instance = create3Factory.deployFacet(code, ArtifactCreationCode.releaseSalt(
            keccak256(bytes("UniswapV2StandardExchangeQueryFacet")), code, bytes("")
        ));
        vm.label(address(instance), "UniswapV2StandardExchangeQueryFacet");
    }

    function deployUniswapV2StandardExchangeDFPkg(
        IVaultRegistryDeployment vaultRegistry,
        IUniswapV2StandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV2StandardExchangeDFPkg instance) {
        instance = IUniswapV2StandardExchangeDFPkg(
            address(
                vaultRegistry.deployPkg(
                    ArtifactCreationCode.creationCode("UniswapV2StandardExchangeDFPkg.sol:UniswapV2StandardExchangeDFPkg"),
                    abi.encode(pkgInit),
                    ArtifactCreationCode.releaseSalt(
                        keccak256(bytes("UniswapV2StandardExchangeDFPkg")),
                        ArtifactCreationCode.creationCode("UniswapV2StandardExchangeDFPkg.sol:UniswapV2StandardExchangeDFPkg"), abi.encode(pkgInit)
                    )
                )
            )
        );
        vm.label(address(instance), "UniswapV2StandardExchangeDFPkg");
    }

    function buildArgsUniswapV2StandardExchangePkgInit(
        IFacet erc20Facet,
        IFacet erc2612Facet,
        IFacet erc5267Facet,
        IFacet erc4626Facet,
        // IFacet erc4626BasicVaultFacet,
        IFacet multiAssetBasicVaultFacet,
        // IFacet erc4626StandardVaultFacet,
        IFacet multiAssetStandardVaultFacet,
        IFacet uniswapV2StandardExchangeInFacet,
        IFacet uniswapV2StandardExchangeOutFacet,
        IFacet uniswapV2StandardExchangeQueryFacet,
        IVaultFeeOracleQuery vaultFeeOracleQuery,
        IVaultRegistryDeployment vaultRegistryDeployment,
        IPermit2 permit2,
        IUniswapV2Factory uniswapV2Factory,
        IUniswapV2Router uniswapV2Router
    ) internal pure returns (IUniswapV2StandardExchangeDFPkg.PkgInit memory pkgInit) {
        {
            pkgInit.erc20Facet = erc20Facet;
            pkgInit.erc2612Facet = erc2612Facet;
            pkgInit.erc5267Facet = erc5267Facet;
            pkgInit.erc4626Facet = erc4626Facet;
            // pkgInit.erc4626BasicVaultFacet = erc4626BasicVaultFacet;
            pkgInit.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
            // pkgInit.erc4626StandardVaultFacet = erc4626StandardVaultFacet;
            pkgInit.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
            pkgInit.uniswapV2StandardExchangeInFacet = uniswapV2StandardExchangeInFacet;
            pkgInit.uniswapV2StandardExchangeOutFacet = uniswapV2StandardExchangeOutFacet;
            pkgInit.uniswapV2StandardExchangeQueryFacet = uniswapV2StandardExchangeQueryFacet;
            pkgInit.vaultFeeOracleQuery = vaultFeeOracleQuery;
            pkgInit.vaultRegistryDeployment = vaultRegistryDeployment;
            pkgInit.permit2 = permit2;
            pkgInit.uniswapV2Factory = uniswapV2Factory;
            pkgInit.uniswapV2Router = uniswapV2Router;
        }
    }

    // function deployUniswapV2StandardExchangeDFPkg(
    //     IVaultRegistryDeployment vaultRegistry,
    //     IFacet erc20Facet,
    //     IFacet erc2612Facet,
    //     IFacet erc5267Facet,
    //     IFacet erc4626Facet,
    //     IFacet erc4626BasicVaultFacet,
    //     IFacet erc4626StandardVaultFacet,
    //     IFacet uniswapV2StandardExchangeInFacet,
    //     IFacet uniswapV2StandardExchangeOutFacet,
    //     IVaultFeeOracleQuery vaultFeeOracleQuery,
    //     IVaultRegistryDeployment vaultRegistryDeployment,
    //     IPermit2 permit2,
    //     IUniswapV2Factory uniswapV2Factory,
    //     IUniswapV2Router uniswapV2Router
    // ) internal returns (IUniswapV2StandardExchangeDFPkg instance) {
    //     // IUniswapV2StandardExchangeDFPkg.PkgInit memory pkgInit;
    //     // {
    //     //     pkgInit.erc20Facet = erc20Facet;
    //     //     pkgInit.erc2612Facet = erc2612Facet;
    //     //     pkgInit.erc5267Facet = erc5267Facet;
    //     //     pkgInit.erc4626Facet = erc4626Facet;
    //     //     pkgInit.erc4626BasicVaultFacet = erc4626BasicVaultFacet;
    //     //     pkgInit.erc4626StandardVaultFacet = erc4626StandardVaultFacet;
    //     //     pkgInit.uniswapV2StandardExchangeInFacet = uniswapV2StandardExchangeInFacet;
    //     //     pkgInit.uniswapV2StandardExchangeOutFacet = uniswapV2StandardExchangeOutFacet;
    //     //     pkgInit.vaultFeeOracleQuery = vaultFeeOracleQuery;
    //     //     pkgInit.vaultRegistryDeployment = vaultRegistryDeployment;
    //     //     pkgInit.permit2 = permit2;
    //     //     pkgInit.uniswapV2Factory = uniswapV2Factory;
    //     //     pkgInit.uniswapV2Router = uniswapV2Router;
    //     // }
    //     return deployUniswapV2StandardExchangeDFPkg(
    //         vaultRegistry,
    //         // pkgInit
    //         buildArgsUniswapV2StandardExchangePkkgInit(
    //             erc20Facet,
    //             erc2612Facet,
    //             erc5267Facet,
    //             erc4626Facet,
    //             erc4626BasicVaultFacet,
    //             erc4626StandardVaultFacet,
    //             uniswapV2StandardExchangeInFacet,
    //             uniswapV2StandardExchangeOutFacet,
    //             vaultFeeOracleQuery,
    //             vaultRegistryDeployment,
    //             permit2,
    //             uniswapV2Factory,
    //             uniswapV2Router
    //         )
    //     );
    // }
}
