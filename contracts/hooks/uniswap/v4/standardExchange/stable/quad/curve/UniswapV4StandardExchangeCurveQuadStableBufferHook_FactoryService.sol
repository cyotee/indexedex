// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryFacet} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/facets/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryFacet.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
// Explicit dependencies keep factory-loaded bytecode available in focused builds.
import {UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookSeFacet} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/facets/UniswapV4StandardExchangeCurveQuadStableBufferHookSeFacet.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookJoinFacet} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/facets/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinFacet.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/facets/UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookExitFacet} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/facets/UniswapV4StandardExchangeCurveQuadStableBufferHookExitFacet.sol";

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
        bytes memory initCode_ = type(UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet).creationCode /* unlinked artifact; type().creationCode required */;
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet");
    }

    function deployJoinFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = type(UniswapV4StandardExchangeCurveQuadStableBufferHookJoinFacet).creationCode /* unlinked artifact; type().creationCode required */;
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeCurveQuadStableBufferHookJoinFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeCurveQuadStableBufferHookJoinFacet");
    }

    function deployJoinQueryFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = type(UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryFacet).creationCode /* unlinked artifact; type().creationCode required */;
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryFacet");
    }

    function deployExitFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = type(UniswapV4StandardExchangeCurveQuadStableBufferHookExitFacet).creationCode /* unlinked artifact; type().creationCode required */;
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeCurveQuadStableBufferHookExitFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeCurveQuadStableBufferHookExitFacet");
    }

    /// @dev Backward-compat alias (Join only). Prefer deployJoinFacet + deployExitFacet.
    function deployLiquidityFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        return deployJoinFacet(create3Factory);
    }

    function deploySeFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = type(UniswapV4StandardExchangeCurveQuadStableBufferHookSeFacet).creationCode /* unlinked artifact; type().creationCode required */;
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeCurveQuadStableBufferHookSeFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeCurveQuadStableBufferHookSeFacet");
    }

    function deployPackage(
        IVaultRegistryDeployment registry,
        address owner,
        IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgInit memory init,
        bytes32 salt
    ) internal returns (IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage pkg) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol:UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg");
        bytes memory initArgs_ = abi.encode(init);
        vm.prank(owner);
        pkg = IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage(
            registry.deployPkg(
                initCode_,
                initArgs_,
                ArtifactCreationCode.releaseSalt(salt, initCode_, initArgs_)
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
