// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {Vm} from "forge-std/Vm.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IUniswapV4HookDiamondPackage} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";
import {IUniswapV4HookDiamondPackageCallBackFactory} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";

import {IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.sol";

/**
 * @title UniswapV4StandardExchangeBalancerQuadStableBufferHook_FactoryService
 * @notice CREATE3 product facets + registry deployPkg; mineNonce for hook CREATE2.
 */
library UniswapV4StandardExchangeBalancerQuadStableBufferHook_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployHooksFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode = ArtifactCreationCode.creationCode(create3Factory, "UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksFacet.sol:UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksFacet");
        facet = create3Factory.deployFacet(
            initCode, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksFacet")._hash(), initCode, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksFacet");
    }

    function deployLiquidityFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode = ArtifactCreationCode.creationCode(create3Factory, "UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityFacet.sol:UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityFacet");
        facet = create3Factory.deployFacet(
            initCode, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityFacet")._hash(), initCode, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityFacet");
    }

    function deployExitFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode = ArtifactCreationCode.creationCode(create3Factory, "UniswapV4StandardExchangeBalancerQuadStableBufferHookExitFacet.sol:UniswapV4StandardExchangeBalancerQuadStableBufferHookExitFacet");
        facet = create3Factory.deployFacet(
            initCode, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeBalancerQuadStableBufferHookExitFacet")._hash(), initCode, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeBalancerQuadStableBufferHookExitFacet");
    }

    function deployQueryFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode = ArtifactCreationCode.creationCode(create3Factory, "UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryFacet.sol:UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryFacet");
        facet = create3Factory.deployFacet(
            initCode, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryFacet")._hash(), initCode, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryFacet");
    }

    function deploySeFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode = ArtifactCreationCode.creationCode(create3Factory, "UniswapV4StandardExchangeBalancerQuadStableBufferHookSeFacet.sol:UniswapV4StandardExchangeBalancerQuadStableBufferHookSeFacet");
        facet = create3Factory.deployFacet(
            initCode, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeBalancerQuadStableBufferHookSeFacet")._hash(), initCode, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeBalancerQuadStableBufferHookSeFacet");
    }

    function deployPackage(
        IVaultRegistryDeployment registry,
        address owner,
        IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.PkgInit memory init,
        bytes32 salt
    ) internal returns (IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage pkg) {
        bytes memory initCode = ArtifactCreationCode.creationCode("UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg.sol:UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg");
        bytes memory initArgs = abi.encode(init);
        vm.prank(owner);
        pkg = IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage(
            registry.deployPkg(
                initCode,
                initArgs,
                ArtifactCreationCode.releaseSalt(salt, initCode, initArgs)
            )
        );
        vm.label(address(pkg), "UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg");
    }

    function findMineNonce(
        IUniswapV4HookDiamondPackageCallBackFactory factory,
        IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage pkg,
        IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.PkgArgs memory args
    ) internal returns (uint256 mineNonce) {
        return HookFactoryService.findMineNonce(
            factory, IUniswapV4HookDiamondPackage(address(pkg)), abi.encode(args)
        );
    }

    function deployHook(
        IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage pkg,
        IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.PkgArgs memory args,
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
