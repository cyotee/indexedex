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
    UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/facets/UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/facets/UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookSeFacet
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/facets/UniswapV4StandardExchangeCurveQuadStableBufferHookSeFacet.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";

/**
 * @title UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService
 * @notice CREATE3 product facets + registry deployPkg; mineNonce for hook CREATE2.
 */
library UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployHooksFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet).name)._hash()
        );
        vm.label(address(facet), type(UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet).name);
    }

    function deployLiquidityFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet).name)._hash()
        );
        vm.label(address(facet), type(UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet).name);
    }

    function deploySeFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeCurveQuadStableBufferHookSeFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeCurveQuadStableBufferHookSeFacet).name)._hash()
        );
        vm.label(address(facet), type(UniswapV4StandardExchangeCurveQuadStableBufferHookSeFacet).name);
    }

    function deployPackage(
        IVaultRegistryDeployment registry,
        address owner,
        IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgInit memory init,
        bytes32 salt
    ) internal returns (IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage pkg) {
        vm.prank(owner);
        pkg = IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage(
            registry.deployPkg(
                type(UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg).creationCode,
                abi.encode(init),
                salt
            )
        );
        vm.label(address(pkg), type(UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg).name);
    }

    function findMineNonce(
        IUniswapV4HookDiamondPackageCallBackFactory factory,
        IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage pkg,
        IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs memory args
    ) internal returns (uint256 mineNonce) {
        return HookFactoryService.findMineNonce(
            factory, IUniswapV4HookDiamondPackage(address(pkg)), abi.encode(args)
        );
    }

    function deployHook(
        IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage pkg,
        IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs memory args,
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
