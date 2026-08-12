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
    UniswapV4StandardExchangeOrbitalBufferHookHooksFacet
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/facets/UniswapV4StandardExchangeOrbitalBufferHookHooksFacet.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookDepositFacet
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/facets/UniswapV4StandardExchangeOrbitalBufferHookDepositFacet.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/facets/UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookSeFacet
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/facets/UniswapV4StandardExchangeOrbitalBufferHookSeFacet.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHook_FactoryService
 * @notice CREATE3 product facets + registry deployPkg; mineNonce for hook CREATE2.
 */
library UniswapV4StandardExchangeOrbitalBufferHook_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployHooksFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeOrbitalBufferHookHooksFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeOrbitalBufferHookHooksFacet).name)._hash()
        );
        vm.label(address(facet), type(UniswapV4StandardExchangeOrbitalBufferHookHooksFacet).name);
    }

    function deployDepositFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeOrbitalBufferHookDepositFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeOrbitalBufferHookDepositFacet).name)._hash()
        );
        vm.label(address(facet), type(UniswapV4StandardExchangeOrbitalBufferHookDepositFacet).name);
    }

    function deployWithdrawFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet).name)._hash()
        );
        vm.label(address(facet), type(UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet).name);
    }

    function deploySeFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(UniswapV4StandardExchangeOrbitalBufferHookSeFacet).creationCode,
            abi.encode(type(UniswapV4StandardExchangeOrbitalBufferHookSeFacet).name)._hash()
        );
        vm.label(address(facet), type(UniswapV4StandardExchangeOrbitalBufferHookSeFacet).name);
    }

    function deployPackage(
        IVaultRegistryDeployment registry,
        address owner,
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgInit memory init,
        bytes32 salt
    ) internal returns (IUniswapV4StandardExchangeOrbitalBufferHookPackage pkg) {
        vm.prank(owner);
        pkg = IUniswapV4StandardExchangeOrbitalBufferHookPackage(
            registry.deployPkg(
                type(UniswapV4StandardExchangeOrbitalBufferHookDFPkg).creationCode, abi.encode(init), salt
            )
        );
        vm.label(address(pkg), type(UniswapV4StandardExchangeOrbitalBufferHookDFPkg).name);
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
