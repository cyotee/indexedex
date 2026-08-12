// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter,
    IBalancerV3UniswapV4CoordinatorRouterDFPkg
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    BalancerV3UniswapV4CoordinatorRouterDFPkg
} from "contracts/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouterDFPkg.sol";
import {
    BalancerV3UniswapV4CoordinatorRouterExactInFacet
} from "contracts/routers/balancerV3-uniswapV4/facets/BalancerV3UniswapV4CoordinatorRouterExactInFacet.sol";
import {
    BalancerV3UniswapV4CoordinatorRouterQueryFacet
} from "contracts/routers/balancerV3-uniswapV4/facets/BalancerV3UniswapV4CoordinatorRouterQueryFacet.sol";
import {
    BalancerV3UniswapV4CoordinatorRouterAdminFacet
} from "contracts/routers/balancerV3-uniswapV4/facets/BalancerV3UniswapV4CoordinatorRouterAdminFacet.sol";
import {
    BalancerV3UniswapV4CoordinatorRouterPermit2WitnessFacet
} from "contracts/routers/balancerV3-uniswapV4/facets/BalancerV3UniswapV4CoordinatorRouterPermit2WitnessFacet.sol";

library BalancerV3UniswapV4CoordinatorRouter_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployExactInFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(BalancerV3UniswapV4CoordinatorRouterExactInFacet).creationCode,
            abi.encode(type(BalancerV3UniswapV4CoordinatorRouterExactInFacet).name)._hash()
        );
        vm.label(address(facet), type(BalancerV3UniswapV4CoordinatorRouterExactInFacet).name);
    }

    function deployQueryFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(BalancerV3UniswapV4CoordinatorRouterQueryFacet).creationCode,
            abi.encode(type(BalancerV3UniswapV4CoordinatorRouterQueryFacet).name)._hash()
        );
        vm.label(address(facet), type(BalancerV3UniswapV4CoordinatorRouterQueryFacet).name);
    }

    function deployAdminFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(BalancerV3UniswapV4CoordinatorRouterAdminFacet).creationCode,
            abi.encode(type(BalancerV3UniswapV4CoordinatorRouterAdminFacet).name)._hash()
        );
        vm.label(address(facet), type(BalancerV3UniswapV4CoordinatorRouterAdminFacet).name);
    }

    function deployPermit2WitnessFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(BalancerV3UniswapV4CoordinatorRouterPermit2WitnessFacet).creationCode,
            abi.encode(type(BalancerV3UniswapV4CoordinatorRouterPermit2WitnessFacet).name)._hash()
        );
        vm.label(address(facet), type(BalancerV3UniswapV4CoordinatorRouterPermit2WitnessFacet).name);
    }

    function deployDFPkg(
        ICreate3FactoryProxy create3Factory,
        IBalancerV3UniswapV4CoordinatorRouterDFPkg.PkgInit memory pkgInit
    ) internal returns (IBalancerV3UniswapV4CoordinatorRouterDFPkg pkg) {
        pkg = IBalancerV3UniswapV4CoordinatorRouterDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(BalancerV3UniswapV4CoordinatorRouterDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(BalancerV3UniswapV4CoordinatorRouterDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(pkg), type(BalancerV3UniswapV4CoordinatorRouterDFPkg).name);
    }

    function deployCoordinator(
        ICreate3FactoryProxy create3Factory,
        IDiamondPackageCallBackFactory diamondFactory,
        IPermit2 permit2,
        IWETH weth,
        address v4Quoter,
        IBalancerV3UniswapV4CoordinatorRouterDFPkg.PkgArgs memory pkgArgs
    ) internal returns (IBalancerV3UniswapV4CoordinatorRouter coordinator) {
        IFacet multiStep = IFacet(
            address(IFacetRegistry(address(create3Factory)).canonicalFacet(type(IMultiStepOwnable).interfaceId))
        );
        IFacet exactIn = deployExactInFacet(create3Factory);
        IFacet query = deployQueryFacet(create3Factory);
        IFacet admin = deployAdminFacet(create3Factory);
        IFacet witness = deployPermit2WitnessFacet(create3Factory);

        IBalancerV3UniswapV4CoordinatorRouterDFPkg.PkgInit memory init =
            IBalancerV3UniswapV4CoordinatorRouterDFPkg.PkgInit({
                multiStepOwnableFacet: multiStep,
                exactInFacet: exactIn,
                queryFacet: query,
                adminFacet: admin,
                permit2WitnessFacet: witness,
                permit2: permit2,
                weth: weth,
                v4Quoter: v4Quoter
            });

        IBalancerV3UniswapV4CoordinatorRouterDFPkg pkg = deployDFPkg(create3Factory, init);
        coordinator = IBalancerV3UniswapV4CoordinatorRouter(
            diamondFactory.deploy(IDiamondFactoryPackage(address(pkg)), abi.encode(pkgArgs))
        );
        vm.label(address(coordinator), "BalancerV3UniswapV4CoordinatorRouter");
    }
}
