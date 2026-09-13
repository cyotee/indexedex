// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {Vm} from "forge-std/Vm.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IUniswapV4HookDiamondPackage} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";
import {IUniswapV4HookDiamondPackageCallBackFactory} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";

import {IUniswapV4DualStandardExchangeBufferConstantProductHookPackage} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.sol";

/**
 * @title UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService
 * @notice Facet + package deploy helpers for Dual SE Buffer CP Hook diamond package.
 * @dev CREATE3 monomorph deployHook path removed. Instances: pkg.deployVault → registry → hook factory.
 */
library UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployHooksFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4DualStandardExchangeBufferConstantProductHookHooksFacet.sol:UniswapV4DualStandardExchangeBufferConstantProductHookHooksFacet"),
            abi.encode("UniswapV4DualStandardExchangeBufferConstantProductHookHooksFacet")._hash()
        );
        vm.label(address(facet), "UniswapV4DualStandardExchangeBufferConstantProductHookHooksFacet");
    }

    function deployDepositFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4DualStandardExchangeBufferConstantProductHookDepositFacet.sol:UniswapV4DualStandardExchangeBufferConstantProductHookDepositFacet"),
            abi.encode("UniswapV4DualStandardExchangeBufferConstantProductHookDepositFacet")._hash()
        );
        vm.label(address(facet), "UniswapV4DualStandardExchangeBufferConstantProductHookDepositFacet");
    }

    function deployWithdrawFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawFacet.sol:UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawFacet"),
            abi.encode("UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawFacet")._hash()
        );
        vm.label(address(facet), "UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawFacet");
    }

    function deploySeFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet facet) {
        facet = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet.sol:UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet"),
            abi.encode("UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet")._hash()
        );
        vm.label(address(facet), "UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet");
    }

    function deployPackage(
        IVaultRegistryDeployment registry,
        address owner,
        IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.PkgInit memory init,
        bytes32 salt
    ) internal returns (IUniswapV4DualStandardExchangeBufferConstantProductHookPackage pkg) {
        vm.prank(owner);
        pkg = IUniswapV4DualStandardExchangeBufferConstantProductHookPackage(
            registry.deployPkg(
                ArtifactCreationCode.creationCode("UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol:UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg"),
                abi.encode(init),
                salt
            )
        );
        vm.label(address(pkg), "UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg");
    }

    function findMineNonce(
        IUniswapV4HookDiamondPackageCallBackFactory factory,
        IUniswapV4DualStandardExchangeBufferConstantProductHookPackage pkg,
        IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args
    ) internal returns (uint256 mineNonce) {
        return HookFactoryService.findMineNonce(
            factory, IUniswapV4HookDiamondPackage(address(pkg)), abi.encode(args)
        );
    }

    function deployHook(
        IUniswapV4DualStandardExchangeBufferConstantProductHookPackage pkg,
        IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args,
        uint256 mineNonce
    ) internal returns (address vault) {
        return pkg.deployVault(args, mineNonce);
    }

    /// @dev Must match DFPkg.requiredHookFlags (no beforeRemoveLiquidity / beforeDonate).
    function requiredFlags() internal pure returns (uint160) {
        return uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );
    }
}
