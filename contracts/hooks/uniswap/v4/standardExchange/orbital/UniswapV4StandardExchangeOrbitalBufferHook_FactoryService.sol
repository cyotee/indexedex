// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchangeOrbitalBufferHookDepositQueryFacet} from "contracts/hooks/uniswap/v4/standardExchange/orbital/facets/UniswapV4StandardExchangeOrbitalBufferHookDepositQueryFacet.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookDepositZapFacet} from "contracts/hooks/uniswap/v4/standardExchange/orbital/facets/UniswapV4StandardExchangeOrbitalBufferHookDepositZapFacet.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
// Explicit dependencies keep factory-loaded bytecode available in focused builds.
import {UniswapV4StandardExchangeOrbitalBufferHookDFPkg} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet} from "contracts/hooks/uniswap/v4/standardExchange/orbital/facets/UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookSeFacet} from "contracts/hooks/uniswap/v4/standardExchange/orbital/facets/UniswapV4StandardExchangeOrbitalBufferHookSeFacet.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookHooksFacet} from "contracts/hooks/uniswap/v4/standardExchange/orbital/facets/UniswapV4StandardExchangeOrbitalBufferHookHooksFacet.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookDepositFacet} from "contracts/hooks/uniswap/v4/standardExchange/orbital/facets/UniswapV4StandardExchangeOrbitalBufferHookDepositFacet.sol";

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

import {IUniswapV4StandardExchangeOrbitalBufferHookPackage} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHook_FactoryService
 * @notice CREATE3 product facets + registry deployPkg; mineNonce for hook CREATE2.
 */
library UniswapV4StandardExchangeOrbitalBufferHook_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployHooksFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = type(UniswapV4StandardExchangeOrbitalBufferHookHooksFacet).creationCode /* unlinked artifact; type().creationCode required */;
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeOrbitalBufferHookHooksFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeOrbitalBufferHookHooksFacet");
    }

    function deployDepositFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = type(UniswapV4StandardExchangeOrbitalBufferHookDepositFacet).creationCode /* unlinked artifact; type().creationCode required */;
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeOrbitalBufferHookDepositFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeOrbitalBufferHookDepositFacet");
    }

    function deployDepositZapFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = type(UniswapV4StandardExchangeOrbitalBufferHookDepositZapFacet).creationCode /* unlinked artifact; type().creationCode required */;
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeOrbitalBufferHookDepositZapFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeOrbitalBufferHookDepositZapFacet");
    }

    function deployDepositQueryFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = type(UniswapV4StandardExchangeOrbitalBufferHookDepositQueryFacet).creationCode /* unlinked artifact; type().creationCode required */;
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeOrbitalBufferHookDepositQueryFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeOrbitalBufferHookDepositQueryFacet");
    }

    function deployWithdrawFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = type(UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet).creationCode /* unlinked artifact; type().creationCode required */;
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet");
    }

    function deploySeFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = type(UniswapV4StandardExchangeOrbitalBufferHookSeFacet).creationCode /* unlinked artifact; type().creationCode required */;
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4StandardExchangeOrbitalBufferHookSeFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4StandardExchangeOrbitalBufferHookSeFacet");
    }

    function deployPackage(
        IVaultRegistryDeployment registry,
        address owner,
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgInit memory init,
        bytes32 salt
    ) internal returns (IUniswapV4StandardExchangeOrbitalBufferHookPackage pkg) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol:UniswapV4StandardExchangeOrbitalBufferHookDFPkg");
        bytes memory initArgs_ = abi.encode(init);
        vm.prank(owner);
        pkg = IUniswapV4StandardExchangeOrbitalBufferHookPackage(
            registry.deployPkg(
                initCode_,
                initArgs_,
                ArtifactCreationCode.releaseSalt(salt, initCode_, initArgs_)
            )
        );
        vm.label(address(pkg), "UniswapV4StandardExchangeOrbitalBufferHookDFPkg");
    }

    function findMineNonce(
        IUniswapV4HookDiamondPackageCallBackFactory factory,
        IUniswapV4StandardExchangeOrbitalBufferHookPackage pkg,
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args
    ) internal returns (uint256 mineNonce) {
        return HookFactoryService.findMineNonce(
            factory, IUniswapV4HookDiamondPackage(address(pkg)), abi.encode(args)
        );
    }

    function deployHook(
        IUniswapV4StandardExchangeOrbitalBufferHookPackage pkg,
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args,
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
