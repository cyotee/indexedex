// SPDX-License-Identifier: BSL-1.1
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
    UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/facets/UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/facets/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawFacet
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/facets/UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawFacet.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";

library UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deploySeFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet).creationCode,
            abi.encode(type(UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet).name)._hash()
        );
        vm.label(address(facet), type(UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet).name);
    }

    function deployDepositFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet).creationCode,
            abi.encode(type(UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet).name)._hash()
        );
        vm.label(address(facet), type(UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet).name);
    }

    function deployWithdrawFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            type(UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawFacet).creationCode,
            abi.encode(type(UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawFacet).name)._hash()
        );
        vm.label(address(facet), type(UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawFacet).name);
    }

    function deployPackage(
        IVaultRegistryDeployment registry,
        address owner,
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgInit memory init,
        bytes32 salt
    ) internal returns (IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage pkg) {
        vm.prank(owner);
        pkg = IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage(
            registry.deployPkg(
                type(UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg).creationCode,
                abi.encode(init),
                salt
            )
        );
        vm.label(address(pkg), type(UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg).name);
    }

    function findMineNonce(
        IUniswapV4HookDiamondPackageCallBackFactory factory,
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage pkg,
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args
    ) internal returns (uint256 mineNonce) {
        return HookFactoryService.findMineNonce(
            factory, IUniswapV4HookDiamondPackage(address(pkg)), abi.encode(args)
        );
    }

    function deployHook(
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage pkg,
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args,
        uint256 mineNonce
    ) internal returns (address vault) {
        return pkg.deployVault(args, mineNonce);
    }
}
