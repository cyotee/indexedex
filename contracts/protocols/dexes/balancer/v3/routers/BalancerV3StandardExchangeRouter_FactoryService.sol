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
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";

import "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactInQueryFacet.sol";
import "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactInSwapFacet.sol";
import "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactOutQueryFacet.sol";
import "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactOutSwapFacet.sol";
import "contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterExactInFacet.sol";
import "contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterExactOutFacet.sol";
import "contracts/protocols/dexes/balancer/v3/routers/prepay/BalancerV3StandardExchangeRouterPrepayFacet.sol";
import "contracts/protocols/dexes/balancer/v3/routers/prepay/BalancerV3StandardExchangeRouterPrepayHooksFacet.sol";
import "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterDFPkg.sol";
import "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {BalancerV3StandardExchangeRouterPermit2WitnessFacet} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterPermit2WitnessFacet.sol";

library BalancerV3StandardExchangeRouter_FactoryService {
    using BetterEfficientHashLib for bytes;
    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployBalancerV3StandardExchangeRouterExactInQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet facet)
    {
        facet = create3Factory.deployFacet(
            type(BalancerV3StandardExchangeRouterExactInQueryFacet).creationCode,
            abi.encode(type(BalancerV3StandardExchangeRouterExactInQueryFacet).name)._hash()
        );
        vm.label(address(facet), type(BalancerV3StandardExchangeRouterExactInQueryFacet).name);
    }

    function deployBalancerV3StandardExchangeRouterExactInSwapFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet facet)
    {
        facet = create3Factory.deployFacet(
            type(BalancerV3StandardExchangeRouterExactInSwapFacet).creationCode,
            abi.encode(type(BalancerV3StandardExchangeRouterExactInSwapFacet).name)._hash()
        );
        vm.label(address(facet), type(BalancerV3StandardExchangeRouterExactInSwapFacet).name);
    }

    function deployBalancerV3StandardExchangeRouterExactOutQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet facet)
    {
        facet = create3Factory.deployFacet(
            type(BalancerV3StandardExchangeRouterExactOutQueryFacet).creationCode,
            abi.encode(type(BalancerV3StandardExchangeRouterExactOutQueryFacet).name)._hash()
        );
        vm.label(address(facet), type(BalancerV3StandardExchangeRouterExactOutQueryFacet).name);
    }

    function deployBalancerV3StandardExchangeRouterExactOutSwapFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet facet)
    {
        facet = create3Factory.deployFacet(
            type(BalancerV3StandardExchangeRouterExactOutSwapFacet).creationCode,
            abi.encode(type(BalancerV3StandardExchangeRouterExactOutSwapFacet).name)._hash()
        );
        vm.label(address(facet), type(BalancerV3StandardExchangeRouterExactOutSwapFacet).name);
    }

    function deployBalancerV3StandardExchangeBatchRouterExactInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet facet)
    {
        facet = create3Factory.deployFacet(
            type(BalancerV3StandardExchangeBatchRouterExactInFacet).creationCode,
            abi.encode(type(BalancerV3StandardExchangeBatchRouterExactInFacet).name)._hash()
        );
        vm.label(address(facet), type(BalancerV3StandardExchangeBatchRouterExactInFacet).name);
    }

    function deployBalancerV3StandardExchangeBatchRouterExactOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet facet)
    {
        facet = create3Factory.deployFacet(
            type(BalancerV3StandardExchangeBatchRouterExactOutFacet).creationCode,
            abi.encode(type(BalancerV3StandardExchangeBatchRouterExactOutFacet).name)._hash()
        );
        vm.label(address(facet), type(BalancerV3StandardExchangeBatchRouterExactOutFacet).name);
    }

    function deployBalancerV3StandardExchangeRouterPrepayFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet facet)
    {
        facet = create3Factory.deployFacet(
            type(BalancerV3StandardExchangeRouterPrepayFacet).creationCode,
            abi.encode(type(BalancerV3StandardExchangeRouterPrepayFacet).name)._hash()
        );
        vm.label(address(facet), type(BalancerV3StandardExchangeRouterPrepayFacet).name);
    }

    function deployBalancerV3StandardExchangeRouterPrepayHooksFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet facet)
    {
        facet = create3Factory.deployFacet(
            type(BalancerV3StandardExchangeRouterPrepayHooksFacet).creationCode,
            abi.encode(type(BalancerV3StandardExchangeRouterPrepayHooksFacet).name)._hash()
        );
        vm.label(address(facet), type(BalancerV3StandardExchangeRouterPrepayHooksFacet).name);
    }

    function deployBalancerV3StandardExchangeRouterPermit2WitnessFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet facet)
    {
        facet = create3Factory.deployFacet(
            type(BalancerV3StandardExchangeRouterPermit2WitnessFacet).creationCode,
            abi.encode(type(BalancerV3StandardExchangeRouterPermit2WitnessFacet).name)._hash()
        );
        vm.label(address(facet), type(BalancerV3StandardExchangeRouterPermit2WitnessFacet).name);
    }

    function deployBalancerV3StandardExchangeRouterDFPkg(
        ICreate3FactoryProxy create3Factory,
        IBalancerV3StandardExchangeRouterDFPkg.PkgInit memory pkgInit
    ) internal returns (IBalancerV3StandardExchangeRouterDFPkg instance) {
        instance = IBalancerV3StandardExchangeRouterDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(BalancerV3StandardExchangeRouterDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(BalancerV3StandardExchangeRouterDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(BalancerV3StandardExchangeRouterDFPkg).name);
    }

    // function deployBalancerV3StandardExchangeRouterDFPkg(
    //     ICreate3FactoryProxy create3Factory,
    //     IFacet senderGuardFacet,
    //     IFacet balancerV3StandardExchangeRouterExactInQueryFacet,
    //     IFacet balancerV3StandardExchangeRouterExactOutQueryFacet,
    //     IFacet balancerV3StandardExchangeRouterExactInSwapFacet,
    //     IFacet balancerV3StandardExchangeRouterExactOutSwapFacet,
    //     IFacet balancerV3StandardExchangeRouterPrepayFacet,
    //     IFacet balancerV3StandardExchangeRouterPrepayHooksFacet,
    //     IFacet balancerV3StandardExchangeBatchRouterExactInFacet,
    //     IFacet balancerV3StandardExchangeBatchRouterExactOutFacet,
    //     IFacet balancerV3StandardExchangePermit2WitnessFacet,
    //     IVault balancerV3Vault,
    //     IPermit2 permit2,
    //     IWETH weth
    // ) internal returns (IBalancerV3StandardExchangeRouterDFPkg instance) {
    //     IBalancerV3StandardExchangeRouterDFPkg.PkgInit memory pkgInit;
    //     {
    //         pkgInit.senderGuardFacet = senderGuardFacet;
    //         pkgInit.balancerV3StandardExchangeRouterExactInQueryFacet = balancerV3StandardExchangeRouterExactInQueryFacet;
    //         pkgInit.balancerV3StandardExchangeRouterExactInSwapFacet = balancerV3StandardExchangeRouterExactInSwapFacet;
    //         pkgInit.balancerV3StandardExchangeRouterExactOutQueryFacet = balancerV3StandardExchangeRouterExactOutQueryFacet;
    //         pkgInit.balancerV3StandardExchangeRouterExactOutSwapFacet = balancerV3StandardExchangeRouterExactOutSwapFacet;
    //         pkgInit.balancerV3StandardExchangeBatchRouterExactInFacet = balancerV3StandardExchangeBatchRouterExactInFacet;
    //         pkgInit.balancerV3StandardExchangeBatchRouterExactOutFacet = balancerV3StandardExchangeBatchRouterExactOutFacet;
    //         pkgInit.balancerV3StandardExchangeRouterPrepayFacet = balancerV3StandardExchangeRouterPrepayFacet;
    //         pkgInit.balancerV3StandardExchangeRouterPrepayHooksFacet = balancerV3StandardExchangeRouterPrepayHooksFacet;
    //         pkgInit.balancerV3StandardExchangePermit2WitnessFacet = balancerV3StandardExchangePermit2WitnessFacet;
    //         pkgInit.balancerV3Vault = balancerV3Vault;
    //         pkgInit.permit2 = permit2;
    //         pkgInit.weth = weth;
    //     }
    //     return deployBalancerV3StandardExchangeRouterDFPkg(create3Factory, pkgInit);
    // }

    function deployBalancerV3StandardExchangeRouter(
        IDiamondPackageCallBackFactory diamondPackageFactory,
        IBalancerV3StandardExchangeRouterDFPkg package
    ) internal returns (IBalancerV3StandardExchangeRouterProxy instance) {
        instance = IBalancerV3StandardExchangeRouterProxy(diamondPackageFactory.deploy(package, ""));
        vm.label(address(instance), "BalancerV3StandardExchangeRouterProxy");
    }
}
