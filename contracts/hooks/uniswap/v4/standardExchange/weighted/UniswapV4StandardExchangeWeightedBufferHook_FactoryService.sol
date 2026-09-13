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

import {IUniswapV4StandardExchangeWeightedBufferHookPackage} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHook_FactoryService
 * @notice CREATE3 product facets + registry deployPkg; mineNonce for hook CREATE2.
 */
library UniswapV4StandardExchangeWeightedBufferHook_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployHooksFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode(create3Factory, "UniswapV4StandardExchangeWeightedBufferHookHooksFacet.sol:UniswapV4StandardExchangeWeightedBufferHookHooksFacet");
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeWeightedBufferHookHooksFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeWeightedBufferHookHooksFacet");
    }

    function deployJoinFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode(create3Factory, "UniswapV4StandardExchangeWeightedBufferHookJoinFacet.sol:UniswapV4StandardExchangeWeightedBufferHookJoinFacet");
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeWeightedBufferHookJoinFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeWeightedBufferHookJoinFacet");
    }

    function deployJoinFlexibleFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode(create3Factory, "UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleFacet.sol:UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleFacet");
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleFacet");
    }

    function deployJoinQueryFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode(create3Factory, "UniswapV4StandardExchangeWeightedBufferHookJoinQueryFacet.sol:UniswapV4StandardExchangeWeightedBufferHookJoinQueryFacet");
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeWeightedBufferHookJoinQueryFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeWeightedBufferHookJoinQueryFacet");
    }

    function deployExitFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode(create3Factory, "UniswapV4StandardExchangeWeightedBufferHookExitFacet.sol:UniswapV4StandardExchangeWeightedBufferHookExitFacet");
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeWeightedBufferHookExitFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeWeightedBufferHookExitFacet");
    }

    /// @dev Backward-compat alias: deploy Join facet (prefer deployJoinFacet + deployExitFacet).
    function deployExitQueryFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode(create3Factory, "UniswapV4StandardExchangeWeightedBufferHookExitQueryFacet.sol:UniswapV4StandardExchangeWeightedBufferHookExitQueryFacet");
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeWeightedBufferHookExitQueryFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeWeightedBufferHookExitQueryFacet");
    }

    function deployLiquidityFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        return deployJoinFacet(create3Factory);
    }

    function deploySeFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode(create3Factory, "UniswapV4StandardExchangeWeightedBufferHookSeFacet.sol:UniswapV4StandardExchangeWeightedBufferHookSeFacet");
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeWeightedBufferHookSeFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeWeightedBufferHookSeFacet");
    }

    function deployPackage(
        IVaultRegistryDeployment registry,
        address owner,
        IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgInit memory init,
        bytes32 salt
    ) internal returns (IUniswapV4StandardExchangeWeightedBufferHookPackage pkg) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol:UniswapV4StandardExchangeWeightedBufferHookDFPkg");
        bytes memory initArgs_ = abi.encode(init);
        vm.prank(owner);
        pkg = IUniswapV4StandardExchangeWeightedBufferHookPackage(
            registry.deployPkg(
                initCode_,
                initArgs_,
                ArtifactCreationCode.releaseSalt(salt, initCode_, initArgs_)
            )
        );
        vm.label(address(pkg), "UniswapV4StandardExchangeWeightedBufferHookDFPkg");
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
