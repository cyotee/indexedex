// SPDX-License-Identifier: BUSL-1.1
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
    UniswapV4StandardExchangeQuadStableBufferHookHooksFacet
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/facets/UniswapV4StandardExchangeQuadStableBufferHookHooksFacet.sol";
import {
    UniswapV4StandardExchangeQuadStableBufferHookLiquidityFacet
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/facets/UniswapV4StandardExchangeQuadStableBufferHookLiquidityFacet.sol";
import {
    UniswapV4StandardExchangeQuadStableBufferHookSeFacet
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/facets/UniswapV4StandardExchangeQuadStableBufferHookSeFacet.sol";
import {
    UniswapV4StandardExchangeQuadStableBufferHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/UniswapV4StandardExchangeQuadStableBufferHookDFPkg.sol";
import {
    IUniswapV4StandardExchangeQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/interfaces/IUniswapV4StandardExchangeQuadStableBufferHookPackage.sol";

/**
 * @title UniswapV4StandardExchangeQuadStableBufferHook_FactoryService
 * @notice CREATE3 product facets + registry deployPkg; mineNonce for hook CREATE2.
 */
library UniswapV4StandardExchangeQuadStableBufferHook_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployHooksFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeQuadStableBufferHookHooksFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeQuadStableBufferHookHooksFacet).name)._hash()
        );
        vm.label(address(facet), type(UniswapV4StandardExchangeQuadStableBufferHookHooksFacet).name);
    }

    function deployLiquidityFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeQuadStableBufferHookLiquidityFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeQuadStableBufferHookLiquidityFacet).name)._hash()
        );
        vm.label(address(facet), type(UniswapV4StandardExchangeQuadStableBufferHookLiquidityFacet).name);
    }

    function deploySeFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeQuadStableBufferHookSeFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeQuadStableBufferHookSeFacet).name)._hash()
        );
        vm.label(address(facet), type(UniswapV4StandardExchangeQuadStableBufferHookSeFacet).name);
    }

    function deployPackage(
        IVaultRegistryDeployment registry,
        address owner,
        IUniswapV4StandardExchangeQuadStableBufferHookPackage.PkgInit memory init,
        bytes32 salt
    ) internal returns (IUniswapV4StandardExchangeQuadStableBufferHookPackage pkg) {
        vm.prank(owner);
        pkg = IUniswapV4StandardExchangeQuadStableBufferHookPackage(
            registry.deployPkg(
                type(UniswapV4StandardExchangeQuadStableBufferHookDFPkg).creationCode,
                abi.encode(init),
                salt
            )
        );
        vm.label(address(pkg), type(UniswapV4StandardExchangeQuadStableBufferHookDFPkg).name);
    }

    function findMineNonce(
        IUniswapV4HookDiamondPackageCallBackFactory factory,
        IUniswapV4StandardExchangeQuadStableBufferHookPackage pkg,
        IUniswapV4StandardExchangeQuadStableBufferHookPackage.PkgArgs memory args
    ) internal returns (uint256 mineNonce) {
        return HookFactoryService.findMineNonce(
            factory, IUniswapV4HookDiamondPackage(address(pkg)), abi.encode(args)
        );
    }

    function deployHook(
        IUniswapV4StandardExchangeQuadStableBufferHookPackage pkg,
        IUniswapV4StandardExchangeQuadStableBufferHookPackage.PkgArgs memory args,
        uint256 mineNonce
    ) internal returns (address vault) {
        return pkg.deployVault(args, mineNonce);
    }

    function requiredFlags() internal pure returns (uint160) {
        return uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_DONATE_FLAG
        );
    }
}
