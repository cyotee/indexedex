// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {
    TestBase_UniswapV4HookDiamondPackageCallBackFactory
} from "test/foundry/spec/hooks/uniswap/v4/factory/TestBase_UniswapV4HookDiamondPackageCallBackFactory.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {
    IUniswapV4HookDiamondFactoryStubPackage
} from "test/foundry/spec/hooks/uniswap/v4/factory/stubs/IUniswapV4HookDiamondFactoryStubPackage.sol";
import {
    IUniswapV4HookDiamondPackage
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";

/**
 * @notice H15: product path Package.deployVault → registry.deployHookVault → factory → vault register.
 */
contract UniswapV4HookDiamondFactory_RegistryTest is TestBase_UniswapV4HookDiamondPackageCallBackFactory {
    using BetterEfficientHashLib for bytes;

    /// H15: package.deployVault registers vault; registry query returns vault under package
    function test_H15_packageDeployVault_registersViaRegistry() public {
        IUniswapV4HookDiamondFactoryStubPackage registeredPkg =
            _registerStubPkg(abi.encode("h15-pkg-deployVault")._hash());

        IUniswapV4HookDiamondFactoryStubPackage.PkgArgs memory args =
            IUniswapV4HookDiamondFactoryStubPackage.PkgArgs({value: 7});
        bytes memory encoded = abi.encode(args);
        uint256 mineNonce = HookFactoryService.findMineNonce(
            hookFactory, IUniswapV4HookDiamondPackage(address(registeredPkg)), encoded
        );

        // Product surface: package enumerates args, calls registry (pkg is msg.sender → authorized).
        address vault = registeredPkg.deployVault(args, mineNonce);

        assertTrue(vault.code.length > 0);
        assertTrue(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(vault));

        address[] memory ofPkg =
            IVaultRegistryVaultQuery(address(indexedexManager)).vaultsOfPackage(address(registeredPkg));
        bool found;
        for (uint256 i = 0; i < ofPkg.length; i++) {
            if (ofPkg[i] == vault) found = true;
        }
        assertTrue(found, "registry must list vault under package");
        assertEq(IUniswapV4HookDiamondFactoryStubPackage(vault).bindingValue(), 7);
    }

    /// Registry entrypoint remains callable by owner (same as SE deployVault)
    function test_H15_ownerDeployHookVault_stillWorks() public {
        IUniswapV4HookDiamondFactoryStubPackage registeredPkg =
            _registerStubPkg(abi.encode("h15-owner-direct")._hash());

        bytes memory args = abi.encode(IUniswapV4HookDiamondFactoryStubPackage.PkgArgs({value: 11}));
        uint256 mineNonce = HookFactoryService.findMineNonce(
            hookFactory, IUniswapV4HookDiamondPackage(address(registeredPkg)), args
        );

        vm.prank(owner);
        address vault = IVaultRegistryDeployment(address(indexedexManager)).deployHookVault(
            IStandardVaultPkg(address(registeredPkg)), args, mineNonce
        );
        assertTrue(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(vault));
    }

    function test_H15_packageDeployVaultAutoMine() public {
        IUniswapV4HookDiamondFactoryStubPackage registeredPkg =
            _registerStubPkg(abi.encode("h15-auto-mine-pkg")._hash());

        address vault = registeredPkg.deployVaultAutoMine(
            IUniswapV4HookDiamondFactoryStubPackage.PkgArgs({value: 13})
        );
        assertTrue(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(vault));
    }
}
