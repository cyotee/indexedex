// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";

import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultRegistryVaultManager} from "contracts/interfaces/IVaultRegistryVaultManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";

/**
 * @title VaultRegistry_Disable_Test
 * @notice Kill-switch: vault address + package disable/re-enable on IndexedexManager diamond.
 */
contract VaultRegistry_Disable_Test is IndexedexTest {
    IVaultRegistryVaultManager vaultManager;
    IVaultRegistryDisableQuery disableQuery;
    IVaultRegistryDisableManager disableManager;

    address vault1;
    address vault2;
    address vault3;
    address pkg1;
    address pkg2;
    address token0;
    address token1;
    address stranger;

    bytes4 constant TYPE_DEX = bytes4(0xdeadbeef);

    bytes32 constant VAULT_FEE_TYPE_IDS = bytes32(
        abi.encodePacked(
            bytes4(0x11111111),
            bytes4(0x22222222),
            bytes4(0x33333333),
            bytes4(0x44444444),
            bytes4(0x55555555),
            bytes12(0)
        )
    );

    bytes32 contentsId1;
    IStandardVault.VaultConfig vaultConfig1;

    function setUp() public virtual override {
        super.setUp();

        vaultManager = IVaultRegistryVaultManager(address(indexedexManager));
        disableQuery = IVaultRegistryDisableQuery(address(indexedexManager));
        disableManager = IVaultRegistryDisableManager(address(indexedexManager));

        vault1 = makeAddr("vault1");
        vault2 = makeAddr("vault2");
        vault3 = makeAddr("vault3");
        pkg1 = makeAddr("pkg1");
        pkg2 = makeAddr("pkg2");
        token0 = makeAddr("token0");
        token1 = makeAddr("token1");
        stranger = makeAddr("stranger");

        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }

        address[] memory tokens = new address[](2);
        tokens[0] = token0;
        tokens[1] = token1;
        contentsId1 = keccak256(abi.encode(tokens));

        bytes4[] memory vaultTypes = new bytes4[](1);
        vaultTypes[0] = TYPE_DEX;

        vaultConfig1 = IStandardVault.VaultConfig({
            vaultFeeTypeIds: VAULT_FEE_TYPE_IDS, contentsId: contentsId1, vaultTypes: vaultTypes, tokens: tokens
        });
    }

    function _register(address vault, address pkg) internal {
        vm.prank(owner);
        vaultManager.registerVault(vault, pkg, vaultConfig1);
    }

    /* ---------------------------------------------------------------------- */
    /*                              Default active                            */
    /* ---------------------------------------------------------------------- */

    function test_isDisabled_defaultActive_unregistered() public view {
        assertFalse(disableQuery.isDisabled(vault1), "unregistered vault should be active");
    }

    function test_isDisabled_defaultActive_registered() public {
        _register(vault1, pkg1);
        assertFalse(disableQuery.isDisabled(vault1), "registered vault should be active by default");
        assertEq(disableQuery.packageOfVault(vault1), pkg1, "packageOfVault should be set on register");
    }

    function test_packageOfVault_clearedOnUnregister() public {
        _register(vault1, pkg1);
        vm.prank(owner);
        vaultManager.unregisterVault(vault1, pkg1, vaultConfig1);
        assertEq(disableQuery.packageOfVault(vault1), address(0), "packageOfVault cleared on unregister");
        assertFalse(disableQuery.isDisabled(vault1));
    }

    /* ---------------------------------------------------------------------- */
    /*                               onlyOwner                                */
    /* ---------------------------------------------------------------------- */

    function test_setVaultAddressDisabled_onlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert();
        disableManager.setVaultAddressDisabled(vault1, true);
    }

    function test_setPackageDisabled_onlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert();
        disableManager.setPackageDisabled(pkg1, true);
    }

    /* ---------------------------------------------------------------------- */
    /*                           Address disable                              */
    /* ---------------------------------------------------------------------- */

    function test_disableVaultAddress_isDisabled() public {
        _register(vault1, pkg1);
        _register(vault2, pkg1);

        vm.prank(owner);
        disableManager.setVaultAddressDisabled(vault1, true);

        assertTrue(disableQuery.isDisabled(vault1));
        assertTrue(disableQuery.isVaultAddressDisabled(vault1));
        assertFalse(disableQuery.isDisabled(vault2), "sibling vault of same package still active");
    }

    function test_reenableVaultAddress_isActive() public {
        _register(vault1, pkg1);

        vm.startPrank(owner);
        disableManager.setVaultAddressDisabled(vault1, true);
        assertTrue(disableQuery.isDisabled(vault1));
        disableManager.setVaultAddressDisabled(vault1, false);
        vm.stopPrank();

        assertFalse(disableQuery.isDisabled(vault1));
        assertFalse(disableQuery.isVaultAddressDisabled(vault1));
    }

    /* ---------------------------------------------------------------------- */
    /*                           Package disable                              */
    /* ---------------------------------------------------------------------- */

    function test_disablePackage_disablesAllVaultsOfPkg() public {
        _register(vault1, pkg1);
        _register(vault2, pkg1);
        _register(vault3, pkg2);

        vm.prank(owner);
        disableManager.setPackageDisabled(pkg1, true);

        assertTrue(disableQuery.isDisabled(vault1));
        assertTrue(disableQuery.isDisabled(vault2));
        assertFalse(disableQuery.isDisabled(vault3), "other package vault stays active");
        assertTrue(disableQuery.isPackageDisabled(pkg1));
        assertFalse(disableQuery.isVaultAddressDisabled(vault1), "package path does not set vault set");
    }

    function test_reenablePackage_restoresActive() public {
        _register(vault1, pkg1);

        vm.startPrank(owner);
        disableManager.setPackageDisabled(pkg1, true);
        assertTrue(disableQuery.isDisabled(vault1));
        disableManager.setPackageDisabled(pkg1, false);
        vm.stopPrank();

        assertFalse(disableQuery.isDisabled(vault1));
    }

    function test_vaultAddressAndPackage_OR() public {
        _register(vault1, pkg1);

        vm.startPrank(owner);
        disableManager.setPackageDisabled(pkg1, true);
        disableManager.setVaultAddressDisabled(vault1, true);
        // re-enable address only - package still disabled
        disableManager.setVaultAddressDisabled(vault1, false);
        vm.stopPrank();

        assertTrue(disableQuery.isDisabled(vault1), "still disabled via package");
        (bool disabled, bool byVault, bool byPackage) = disableQuery.isDisabledDetailed(vault1);
        assertTrue(disabled);
        assertFalse(byVault);
        assertTrue(byPackage);
    }

    function test_packageDisabled_addressStillIndependent() public {
        _register(vault1, pkg1);
        _register(vault2, pkg1);

        vm.prank(owner);
        disableManager.setVaultAddressDisabled(vault1, true);

        assertTrue(disableQuery.isDisabled(vault1));
        assertFalse(disableQuery.isDisabled(vault2));
    }

    function test_isDisabledDetailed() public {
        _register(vault1, pkg1);

        vm.startPrank(owner);
        disableManager.setVaultAddressDisabled(vault1, true);
        disableManager.setPackageDisabled(pkg1, true);
        vm.stopPrank();

        (bool disabled, bool byVault, bool byPackage) = disableQuery.isDisabledDetailed(vault1);
        assertTrue(disabled);
        assertTrue(byVault);
        assertTrue(byPackage);
    }

    function test_events_onChange() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true, address(indexedexManager));
        emit IVaultRegistryDisableManager.VaultAddressDisabled(vault1, true);
        disableManager.setVaultAddressDisabled(vault1, true);

        vm.prank(owner);
        // no event on no-op
        disableManager.setVaultAddressDisabled(vault1, true);

        vm.prank(owner);
        vm.expectEmit(true, false, false, true, address(indexedexManager));
        emit IVaultRegistryDisableManager.PackageDisabled(pkg1, true);
        disableManager.setPackageDisabled(pkg1, true);
    }

    function test_disabledSets_enumeration() public {
        vm.startPrank(owner);
        disableManager.setVaultAddressDisabled(vault1, true);
        disableManager.setPackageDisabled(pkg1, true);
        vm.stopPrank();

        address[] memory vaults = disableQuery.disabledVaults();
        address[] memory pkgs = disableQuery.disabledPackages();
        assertEq(vaults.length, 1);
        assertEq(vaults[0], vault1);
        assertEq(pkgs.length, 1);
        assertEq(pkgs[0], pkg1);
    }
}
