// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {
    UniswapV3StandardExchangeInExecutionDelegate
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInExecutionDelegate.sol";
import {
    UniswapV3StandardExchangeInFacet
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInFacet.sol";
import {
    UniswapV3StandardExchangeInQueryFacet
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInQueryFacet.sol";
import {
    UniswapV3StandardExchangeOutExecutionDelegate
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeOutExecutionDelegate.sol";
import {
    UniswapV3StandardExchangeOutFacet
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeOutFacet.sol";
import {
    UniswapV3StandardExchangeOutQueryFacet
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeOutQueryFacet.sol";
import {
    UniswapV3StandardExchangePositionImportFacet
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangePositionImportFacet.sol";
import {
    UniswapV3StandardExchangeLiquidReserveFacet
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeLiquidReserveFacet.sol";
import {
    UniswapV3StandardExchangeInMultiFacet
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInMultiFacet.sol";
import {
    UniswapV3StandardExchangeInMultiQueryFacet
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInMultiQueryFacet.sol";
import {
    UniswapV3StandardExchangeOutMultiFacet
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeOutMultiFacet.sol";
import {
    UniswapV3StandardExchangeOutMultiQueryFacet
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeOutMultiQueryFacet.sol";
import {
    IUniswapV3StandardExchangeDFPkg,
    UniswapV3StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeDFPkg.sol";

library UniswapV3_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV3StandardExchangeInExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        instance = create3Factory.create3(
            type(UniswapV3StandardExchangeInExecutionDelegate).creationCode,
            abi.encode(type(UniswapV3StandardExchangeInExecutionDelegate).name)._hash()
        );
        vm.label(instance, type(UniswapV3StandardExchangeInExecutionDelegate).name);
    }

    function deployUniswapV3StandardExchangeInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        address executionDelegate = deployUniswapV3StandardExchangeInExecutionDelegate(create3Factory);
        instance = create3Factory.deployFacet(
            bytes.concat(type(UniswapV3StandardExchangeInFacet).creationCode, abi.encode(executionDelegate)),
            abi.encode(type(UniswapV3StandardExchangeInFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV3StandardExchangeInFacet).name);
    }

    function deployUniswapV3StandardExchangeInQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV3StandardExchangeInQueryFacet).creationCode,
            abi.encode(type(UniswapV3StandardExchangeInQueryFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV3StandardExchangeInQueryFacet).name);
    }

    function deployUniswapV3StandardExchangeOutExecutionDelegate(ICreate3FactoryProxy create3Factory)
        internal
        returns (address instance)
    {
        instance = create3Factory.create3(
            type(UniswapV3StandardExchangeOutExecutionDelegate).creationCode,
            abi.encode(type(UniswapV3StandardExchangeOutExecutionDelegate).name)._hash()
        );
        vm.label(instance, type(UniswapV3StandardExchangeOutExecutionDelegate).name);
    }

    function deployUniswapV3StandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        address executionDelegate = deployUniswapV3StandardExchangeOutExecutionDelegate(create3Factory);
        instance = create3Factory.deployFacet(
            bytes.concat(type(UniswapV3StandardExchangeOutFacet).creationCode, abi.encode(executionDelegate)),
            abi.encode(type(UniswapV3StandardExchangeOutFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV3StandardExchangeOutFacet).name);
    }

    function deployUniswapV3StandardExchangeOutQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV3StandardExchangeOutQueryFacet).creationCode,
            abi.encode(type(UniswapV3StandardExchangeOutQueryFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV3StandardExchangeOutQueryFacet).name);
    }

    function deployUniswapV3StandardExchangePositionImportFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV3StandardExchangePositionImportFacet).creationCode,
            abi.encode(type(UniswapV3StandardExchangePositionImportFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV3StandardExchangePositionImportFacet).name);
    }

    function deployUniswapV3StandardExchangeLiquidReserveFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV3StandardExchangeLiquidReserveFacet).creationCode,
            abi.encode(type(UniswapV3StandardExchangeLiquidReserveFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV3StandardExchangeLiquidReserveFacet).name);
    }

    function deployUniswapV3StandardExchangeInMultiFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV3StandardExchangeInMultiFacet).creationCode,
            abi.encode(type(UniswapV3StandardExchangeInMultiFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV3StandardExchangeInMultiFacet).name);
    }

    function deployUniswapV3StandardExchangeInMultiQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV3StandardExchangeInMultiQueryFacet).creationCode,
            abi.encode(type(UniswapV3StandardExchangeInMultiQueryFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV3StandardExchangeInMultiQueryFacet).name);
    }

    function deployUniswapV3StandardExchangeOutMultiFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV3StandardExchangeOutMultiFacet).creationCode,
            abi.encode(type(UniswapV3StandardExchangeOutMultiFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV3StandardExchangeOutMultiFacet).name);
    }

    function deployUniswapV3StandardExchangeOutMultiQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV3StandardExchangeOutMultiQueryFacet).creationCode,
            abi.encode(type(UniswapV3StandardExchangeOutMultiQueryFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV3StandardExchangeOutMultiQueryFacet).name);
    }

    function attachUniswapV3StandardExchangeMultiFacets(
        IUniswapV3StandardExchangeDFPkg.PkgInit memory pkgInit,
        IFacet uniswapV3StandardExchangeInMultiFacet,
        IFacet uniswapV3StandardExchangeInMultiQueryFacet,
        IFacet uniswapV3StandardExchangeOutMultiFacet,
        IFacet uniswapV3StandardExchangeOutMultiQueryFacet
    ) internal pure returns (IUniswapV3StandardExchangeDFPkg.PkgInit memory) {
        pkgInit.uniswapV3StandardExchangeInMultiFacet = uniswapV3StandardExchangeInMultiFacet;
        pkgInit.uniswapV3StandardExchangeInMultiQueryFacet = uniswapV3StandardExchangeInMultiQueryFacet;
        pkgInit.uniswapV3StandardExchangeOutMultiFacet = uniswapV3StandardExchangeOutMultiFacet;
        pkgInit.uniswapV3StandardExchangeOutMultiQueryFacet = uniswapV3StandardExchangeOutMultiQueryFacet;
        return pkgInit;
    }

    function deployUniswapV3StandardExchangeDFPkgFromVaultRegistry(
        IVaultRegistryDeployment vaultRegistry,
        IUniswapV3StandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV3StandardExchangeDFPkg instance) {
        instance = IUniswapV3StandardExchangeDFPkg(
            address(
                vaultRegistry.deployPkg(
                    type(UniswapV3StandardExchangeDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(UniswapV3StandardExchangeDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(UniswapV3StandardExchangeDFPkg).name);
    }

    function deployUniswapV3StandardExchangeDFPkg(
        IIndexedexManagerProxy indexedexManager,
        IUniswapV3StandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniswapV3StandardExchangeDFPkg instance) {
        return deployUniswapV3StandardExchangeDFPkgFromVaultRegistry(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
    }
}
