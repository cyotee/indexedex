// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
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
    UniswapV4SingleStandardExchangeBufferHookFacet
} from "contracts/hooks/uniswap/v4/standardExchange/single/facets/UniswapV4SingleStandardExchangeBufferHookFacet.sol";
import {
    UniswapV4SingleStandardExchangeBufferHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookDFPkg.sol";
import {
    IUniswapV4SingleStandardExchangeBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHookPackage.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferHook_FactoryService
 * @notice Facet + package deploy helpers. No CREATE3 monomorph instance mine.
 */
library UniswapV4SingleStandardExchangeBufferHook_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployProductFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(UniswapV4SingleStandardExchangeBufferHookFacet).creationCode,
            abi.encode(type(UniswapV4SingleStandardExchangeBufferHookFacet).name)._hash()
        );
        vm.label(address(facet), type(UniswapV4SingleStandardExchangeBufferHookFacet).name);
    }

    function deployPackage(
        IVaultRegistryDeployment registry,
        address owner,
        IUniswapV4SingleStandardExchangeBufferHookPackage.PkgInit memory init,
        bytes32 salt
    ) internal returns (IUniswapV4SingleStandardExchangeBufferHookPackage pkg) {
        vm.prank(owner);
        pkg = IUniswapV4SingleStandardExchangeBufferHookPackage(
            registry.deployPkg(
                type(UniswapV4SingleStandardExchangeBufferHookDFPkg).creationCode,
                abi.encode(init),
                salt
            )
        );
        vm.label(address(pkg), type(UniswapV4SingleStandardExchangeBufferHookDFPkg).name);
    }

    function findMineNonce(
        IUniswapV4HookDiamondPackageCallBackFactory factory,
        IUniswapV4SingleStandardExchangeBufferHookPackage pkg,
        IUniswapV4SingleStandardExchangeBufferHookPackage.PkgArgs memory args
    ) internal returns (uint256 mineNonce) {
        return HookFactoryService.findMineNonce(
            factory, IUniswapV4HookDiamondPackage(address(pkg)), abi.encode(args)
        );
    }

    function deployHook(
        IUniswapV4SingleStandardExchangeBufferHookPackage pkg,
        IUniswapV4SingleStandardExchangeBufferHookPackage.PkgArgs memory args,
        uint256 mineNonce
    ) internal returns (address vault) {
        return pkg.deployVault(args, mineNonce);
    }
}
