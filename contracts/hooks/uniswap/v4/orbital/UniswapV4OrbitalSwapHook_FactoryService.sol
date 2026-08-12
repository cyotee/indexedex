// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {Vm} from "forge-std/Vm.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IUniswapV4HookDiamondPackage
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";
import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {
    UniswapV4OrbitalSwapHookHooksFacet
} from "contracts/hooks/uniswap/v4/orbital/facets/UniswapV4OrbitalSwapHookHooksFacet.sol";
import {
    UniswapV4OrbitalSwapHookLiquidityFacet
} from "contracts/hooks/uniswap/v4/orbital/facets/UniswapV4OrbitalSwapHookLiquidityFacet.sol";
import {
    UniswapV4OrbitalSwapHookDFPkg
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookDFPkg.sol";
import {
    IUniswapV4OrbitalSwapHookPackage
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHookPackage.sol";

/**
 * @title UniswapV4OrbitalSwapHook_FactoryService
 * @notice CREATE3 product facets + registry deployPkg helpers; mineNonce for hook CREATE2.
 * @dev Instances: package.deployVault → registry.deployHookVault → shared hook factory.
 *      Monomorph CREATE3 product factory is retired.
 */
library UniswapV4OrbitalSwapHook_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployHooksFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(UniswapV4OrbitalSwapHookHooksFacet).creationCode,
            abi.encode(type(UniswapV4OrbitalSwapHookHooksFacet).name)._hash()
        );
        vm.label(address(facet), type(UniswapV4OrbitalSwapHookHooksFacet).name);
    }

    function deployLiquidityFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(UniswapV4OrbitalSwapHookLiquidityFacet).creationCode,
            abi.encode(type(UniswapV4OrbitalSwapHookLiquidityFacet).name)._hash()
        );
        vm.label(address(facet), type(UniswapV4OrbitalSwapHookLiquidityFacet).name);
    }

    function deployPackage(
        IVaultRegistryDeployment registry,
        address owner,
        IUniswapV4OrbitalSwapHookPackage.PkgInit memory init,
        bytes32 salt
    ) internal returns (IUniswapV4OrbitalSwapHookPackage pkg) {
        vm.prank(owner);
        pkg = IUniswapV4OrbitalSwapHookPackage(
            registry.deployPkg(
                type(UniswapV4OrbitalSwapHookDFPkg).creationCode, abi.encode(init), salt
            )
        );
        vm.label(address(pkg), type(UniswapV4OrbitalSwapHookDFPkg).name);
    }

    function findMineNonce(
        IUniswapV4HookDiamondPackageCallBackFactory factory,
        IUniswapV4OrbitalSwapHookPackage pkg,
        IUniswapV4OrbitalSwapHookPackage.PkgArgs memory args
    ) internal returns (uint256 mineNonce) {
        return HookFactoryService.findMineNonce(
            factory, IUniswapV4HookDiamondPackage(address(pkg)), abi.encode(args)
        );
    }

    function deployHook(
        IUniswapV4OrbitalSwapHookPackage pkg,
        IUniswapV4OrbitalSwapHookPackage.PkgArgs memory args,
        uint256 mineNonce
    ) internal returns (address vault) {
        return pkg.deployVault(args, mineNonce);
    }

    function requiredFlags() internal pure returns (uint160) {
        return uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );
    }
}
