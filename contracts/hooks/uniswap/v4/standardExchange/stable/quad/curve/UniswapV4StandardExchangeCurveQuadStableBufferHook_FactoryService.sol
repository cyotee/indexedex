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

import {IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";

/**
 * @title UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService
 * @notice CREATE3 product facets + registry deployPkg; mineNonce for hook CREATE2.
 */
library UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployHooksFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode(create3Factory, "UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet.sol:UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet");
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet")._hash())
        );
        vm.label(address(facet), "UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet");
    }

    function deployExitFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode(create3Factory, "UniswapV4StandardExchangeCurveQuadStableBufferHookExitFacet.sol:UniswapV4StandardExchangeCurveQuadStableBufferHookExitFacet");
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeCurveQuadStableBufferHookExitFacet")._hash())
        );
        vm.label(address(facet), "UniswapV4StandardExchangeCurveQuadStableBufferHookExitFacet");
    }

    /// @dev D19: mutating join/deposit half of the former fat LiquidityFacet.
    function deployLiquidityFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode(
            create3Factory,
            "UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet.sol:UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet"
        );
        facet = create3Factory.deployFacet(
            initCode_,
            ArtifactCreationCode.releaseSalt(
                abi.encode("UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet")._hash()
            )
        );
        vm.label(address(facet), "UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet");
    }

    /// @dev D19 Ext: join/deposit preview half. Salt is the contract name.
    function deployLiquidityFacetExt(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode(
            create3Factory,
            "UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacetExt.sol:UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacetExt"
        );
        facet = create3Factory.deployFacet(
            initCode_,
            ArtifactCreationCode.releaseSalt(
                abi.encode("UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacetExt")._hash()
            )
        );
        vm.label(address(facet), "UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacetExt");
    }

    function deploySeFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode(create3Factory, "UniswapV4StandardExchangeCurveQuadStableBufferHookSeFacet.sol:UniswapV4StandardExchangeCurveQuadStableBufferHookSeFacet");
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeCurveQuadStableBufferHookSeFacet")._hash())
        );
        vm.label(address(facet), "UniswapV4StandardExchangeCurveQuadStableBufferHookSeFacet");
    }

    function deployPackage(
        IVaultRegistryDeployment registry,
        address owner,
        IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgInit memory init
    ) internal returns (IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage pkg) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol:UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg");
        bytes memory initArgs_ = abi.encode(init);
        vm.prank(owner);
        pkg = IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage(
            registry.deployPkg(
                initCode_,
                initArgs_,
                ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg")._hash())
            )
        );
        vm.label(address(pkg), "UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg");
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
