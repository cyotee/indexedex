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
    UniswapV4StandardExchangeWeightedBufferHookHooksFacet
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/facets/UniswapV4StandardExchangeWeightedBufferHookHooksFacet.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookJoinFacet
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/facets/UniswapV4StandardExchangeWeightedBufferHookJoinFacet.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookExitFacet
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/facets/UniswapV4StandardExchangeWeightedBufferHookExitFacet.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookSeFacet
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/facets/UniswapV4StandardExchangeWeightedBufferHookSeFacet.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHook_FactoryService
 * @notice CREATE3 product facets + registry deployPkg; mineNonce for hook CREATE2.
 */
library UniswapV4StandardExchangeWeightedBufferHook_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployHooksFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeWeightedBufferHookHooksFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeWeightedBufferHookHooksFacet).name)._hash()
        );
        vm.label(address(facet), type(UniswapV4StandardExchangeWeightedBufferHookHooksFacet).name);
    }

    function deployJoinFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeWeightedBufferHookJoinFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeWeightedBufferHookJoinFacet).name)._hash()
        );
        vm.label(address(facet), type(UniswapV4StandardExchangeWeightedBufferHookJoinFacet).name);
    }

    function deployExitFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeWeightedBufferHookExitFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeWeightedBufferHookExitFacet).name)._hash()
        );
        vm.label(address(facet), type(UniswapV4StandardExchangeWeightedBufferHookExitFacet).name);
    }

    /// @dev Backward-compat alias: deploy Join facet (prefer deployJoinFacet + deployExitFacet).
    function deployLiquidityFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        return deployJoinFacet(create3Factory);
    }

    function deploySeFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeWeightedBufferHookSeFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeWeightedBufferHookSeFacet).name)._hash()
        );
        vm.label(address(facet), type(UniswapV4StandardExchangeWeightedBufferHookSeFacet).name);
    }

    function deployPackage(
        IVaultRegistryDeployment registry,
        address owner,
        IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgInit memory init,
        bytes32 salt
    ) internal returns (IUniswapV4StandardExchangeWeightedBufferHookPackage pkg) {
        vm.prank(owner);
        pkg = IUniswapV4StandardExchangeWeightedBufferHookPackage(
            registry.deployPkg(
                type(UniswapV4StandardExchangeWeightedBufferHookDFPkg).creationCode,
                abi.encode(init),
                salt
            )
        );
        vm.label(address(pkg), type(UniswapV4StandardExchangeWeightedBufferHookDFPkg).name);
    }

    function findMineNonce(
        IUniswapV4HookDiamondPackageCallBackFactory factory,
        IUniswapV4StandardExchangeWeightedBufferHookPackage pkg,
        IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs memory args
    ) internal returns (uint256 mineNonce) {
        return HookFactoryService.findMineNonce(
            factory, IUniswapV4HookDiamondPackage(address(pkg)), abi.encode(args)
        );
    }

    function deployHook(
        IUniswapV4StandardExchangeWeightedBufferHookPackage pkg,
        IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs memory args,
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
