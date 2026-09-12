// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {Vm} from "forge-std/Vm.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IUniswapV4HookDiamondPackage} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";
import {IUniswapV4HookDiamondPackageCallBackFactory} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";

import {IUniswapV4SingleStandardExchangeBufferHookPackage} from "contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHookPackage.sol";

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
            ArtifactCreationCode.creationCode("UniswapV4SingleStandardExchangeBufferHookFacet.sol:UniswapV4SingleStandardExchangeBufferHookFacet"),
            abi.encode("UniswapV4SingleStandardExchangeBufferHookFacet")._hash()
        );
        vm.label(address(facet), "UniswapV4SingleStandardExchangeBufferHookFacet");
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
                ArtifactCreationCode.creationCode("UniswapV4SingleStandardExchangeBufferHookDFPkg.sol:UniswapV4SingleStandardExchangeBufferHookDFPkg"),
                abi.encode(init),
                salt
            )
        );
        vm.label(address(pkg), "UniswapV4SingleStandardExchangeBufferHookDFPkg");
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
