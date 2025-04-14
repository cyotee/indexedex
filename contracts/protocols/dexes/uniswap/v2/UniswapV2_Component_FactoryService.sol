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
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IUniswapV2Router} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import {IUniswapV2Factory} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    UniswapV2StandardExchangeInFacet
} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInFacet.sol";
import {
    UniswapV2StandardExchangeOutFacet
} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutFacet.sol";
import {
    IUniswapV2StandardExchangeDFPkg,
    UniswapV2StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

library UniswapV2_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV2StandardExchangeInFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(UniswapV2StandardExchangeInFacet).creationCode,
            abi.encode(type(UniswapV2StandardExchangeInFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV2StandardExchangeInFacet).name);
    }

    function deployUniswapV2StandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV2StandardExchangeOutFacet).creationCode,
            abi.encode(type(UniswapV2StandardExchangeOutFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV2StandardExchangeOutFacet).name);
    }

    function deployUniswapV2StandardExchangeDFPkg(
        IVaultRegistryDeployment vaultRegistry,
        IUniswapV2StandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV2StandardExchangeDFPkg instance) {
        instance = IUniswapV2StandardExchangeDFPkg(
            address(
                vaultRegistry.deployPkg(
                    type(UniswapV2StandardExchangeDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(UniswapV2StandardExchangeDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(UniswapV2StandardExchangeDFPkg).name);
    }

    function buildArgsUniswapV2StandardExchangePkgInit(
        IFacet erc20Facet,
        IFacet erc2612Facet,
        IFacet erc5267Facet,
        IFacet erc4626Facet,
        IFacet erc4626BasicVaultFacet,
        IFacet erc4626StandardVaultFacet,
        IFacet uniswapV2StandardExchangeInFacet,
        IFacet uniswapV2StandardExchangeOutFacet,
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
            pkgInit.erc4626BasicVaultFacet = erc4626BasicVaultFacet;
            pkgInit.erc4626StandardVaultFacet = erc4626StandardVaultFacet;
            pkgInit.uniswapV2StandardExchangeInFacet = uniswapV2StandardExchangeInFacet;
            pkgInit.uniswapV2StandardExchangeOutFacet = uniswapV2StandardExchangeOutFacet;
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
