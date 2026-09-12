// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleFacet} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/facets/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleFacet.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewFacet} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/facets/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewFacet.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
// Explicit dependencies keep factory-loaded bytecode available in focused builds.
import {UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawFacet} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/facets/UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawFacet.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/facets/UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/facets/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet.sol";

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

import {IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";

library UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deploySeFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = type(UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet).creationCode /* unlinked artifact; type().creationCode required */;
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet");
    }

    function deployDepositFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = type(UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet).creationCode /* unlinked artifact; type().creationCode required */;
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet");
    }

    function deployDepositSingleFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = type(UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleFacet).creationCode /* unlinked artifact; type().creationCode required */;
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleFacet");
    }

    function deployDepositPreviewFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = type(UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewFacet).creationCode /* unlinked artifact; type().creationCode required */;
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewFacet");
    }

    function deployWithdrawFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        bytes memory initCode_ = type(UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawFacet).creationCode /* unlinked artifact; type().creationCode required */;
        facet = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(facet), "UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawFacet");
    }

    function deployPackage(
        IVaultRegistryDeployment registry,
        address owner,
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgInit memory init,
        bytes32 salt
    ) internal returns (IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage pkg) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol:UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg");
        bytes memory initArgs_ = abi.encode(init);
        vm.prank(owner);
        pkg = IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage(
            registry.deployPkg(
                initCode_,
                initArgs_,
                ArtifactCreationCode.releaseSalt(salt, initCode_, initArgs_)
            )
        );
        vm.label(address(pkg), "UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg");
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
