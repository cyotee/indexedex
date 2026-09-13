// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IBalancerV3StandardExchangeRouterDFPkg} from "contracts/protocols/dexes/balancer/v3/routers/IBalancerV3StandardExchangeRouterDFPkg.sol";

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

import "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";

library BalancerV3StandardExchangeRouter_FactoryService {
    using BetterEfficientHashLib for bytes;
    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployBalancerV3StandardExchangeRouterExactInQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet facet)
    {
        facet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("BalancerV3StandardExchangeRouterExactInQueryFacet.sol:BalancerV3StandardExchangeRouterExactInQueryFacet"),
            abi.encode("BalancerV3StandardExchangeRouterExactInQueryFacet")._hash()
        );
        vm.label(address(facet), "BalancerV3StandardExchangeRouterExactInQueryFacet");
    }

    function deployBalancerV3StandardExchangeRouterExactInSwapFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet facet)
    {
        facet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("BalancerV3StandardExchangeRouterExactInSwapFacet.sol:BalancerV3StandardExchangeRouterExactInSwapFacet"),
            abi.encode("BalancerV3StandardExchangeRouterExactInSwapFacet")._hash()
        );
        vm.label(address(facet), "BalancerV3StandardExchangeRouterExactInSwapFacet");
    }

    function deployBalancerV3StandardExchangeRouterExactOutQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet facet)
    {
        facet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("BalancerV3StandardExchangeRouterExactOutQueryFacet.sol:BalancerV3StandardExchangeRouterExactOutQueryFacet"),
            abi.encode("BalancerV3StandardExchangeRouterExactOutQueryFacet")._hash()
        );
        vm.label(address(facet), "BalancerV3StandardExchangeRouterExactOutQueryFacet");
    }

    function deployBalancerV3StandardExchangeRouterExactOutSwapFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet facet)
    {
        facet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("BalancerV3StandardExchangeRouterExactOutSwapFacet.sol:BalancerV3StandardExchangeRouterExactOutSwapFacet"),
            abi.encode("BalancerV3StandardExchangeRouterExactOutSwapFacet")._hash()
        );
        vm.label(address(facet), "BalancerV3StandardExchangeRouterExactOutSwapFacet");
    }

    function deployBalancerV3StandardExchangeBatchRouterExactInFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet facet)
    {
        facet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("BalancerV3StandardExchangeBatchRouterExactInFacet.sol:BalancerV3StandardExchangeBatchRouterExactInFacet"),
            abi.encode("BalancerV3StandardExchangeBatchRouterExactInFacet")._hash()
        );
        vm.label(address(facet), "BalancerV3StandardExchangeBatchRouterExactInFacet");
    }

    function deployBalancerV3StandardExchangeBatchRouterExactOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet facet)
    {
        facet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("BalancerV3StandardExchangeBatchRouterExactOutFacet.sol:BalancerV3StandardExchangeBatchRouterExactOutFacet"),
            abi.encode("BalancerV3StandardExchangeBatchRouterExactOutFacet")._hash()
        );
        vm.label(address(facet), "BalancerV3StandardExchangeBatchRouterExactOutFacet");
    }

    function deployBalancerV3StandardExchangeRouterPrepayFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet facet)
    {
        facet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("BalancerV3StandardExchangeRouterPrepayFacet.sol:BalancerV3StandardExchangeRouterPrepayFacet"),
            abi.encode("BalancerV3StandardExchangeRouterPrepayFacet")._hash()
        );
        vm.label(address(facet), "BalancerV3StandardExchangeRouterPrepayFacet");
    }

    function deployBalancerV3StandardExchangeRouterPrepayHooksFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet facet)
    {
        facet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("BalancerV3StandardExchangeRouterPrepayHooksFacet.sol:BalancerV3StandardExchangeRouterPrepayHooksFacet"),
            abi.encode("BalancerV3StandardExchangeRouterPrepayHooksFacet")._hash()
        );
        vm.label(address(facet), "BalancerV3StandardExchangeRouterPrepayHooksFacet");
    }

    function deployBalancerV3StandardExchangeRouterPermit2WitnessFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet facet)
    {
        facet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("BalancerV3StandardExchangeRouterPermit2WitnessFacet.sol:BalancerV3StandardExchangeRouterPermit2WitnessFacet"),
            abi.encode("BalancerV3StandardExchangeRouterPermit2WitnessFacet")._hash()
        );
        vm.label(address(facet), "BalancerV3StandardExchangeRouterPermit2WitnessFacet");
    }

    function deployBalancerV3StandardExchangeRouterDFPkg(
        ICreate3FactoryProxy create3Factory,
        IBalancerV3StandardExchangeRouterDFPkg.PkgInit memory pkgInit
    ) internal returns (IBalancerV3StandardExchangeRouterDFPkg instance) {
        instance = IBalancerV3StandardExchangeRouterDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    ArtifactCreationCode.creationCode("BalancerV3StandardExchangeRouterDFPkg.sol:BalancerV3StandardExchangeRouterDFPkg"),
                    abi.encode(pkgInit),
                    abi.encode("BalancerV3StandardExchangeRouterDFPkg")._hash()
                )
            )
        );
        vm.label(address(instance), "BalancerV3StandardExchangeRouterDFPkg");
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
