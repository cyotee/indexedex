// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {
    IAerodromeStandardExchangeDFPkg
} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol";
import {
    TestBase_AerodromeStandardExchange
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange.sol";

/**
 * @title VaultRegistryDeployment_Auth Tests
 * @notice Tests for authorization on VaultRegistryDeploymentTarget.deployVault()
 * @dev IDXEX-027: Verify that deployVault requires owner or operator permissions
 *
 * Note: The IndexedexManager Diamond does not include OperableFacet, so operators
 * cannot be set via setOperator(). Only the owner can deploy vaults. This test
 * verifies that unauthorized users are blocked.
 */
contract VaultRegistryDeployment_Auth_Test is TestBase_AerodromeStandardExchange {
    address attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
    }

    /* -------------------------------------------------------------------------- */
    /*                   US-IDXEX-027.1: Access Control Tests                      */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test that owner can deploy vault directly via registry
     * @dev US-IDXEX-027.1: owner can deploy vault
     */
    function test_deployVault_owner_succeeds() public {
        // Owner deploys vault through the IndexedexManager proxy
        vm.prank(owner);
        address vault = IVaultRegistryDeployment(address(indexedexManager))
            .deployVault(
                IStandardVaultPkg(address(aerodromeStandardExchangeDFPkg)),
                abi.encode(IAerodromeStandardExchangeDFPkg.PkgArgs({reserveAsset: aeroBalancedPool}))
            );

        assertTrue(vault != address(0), "Vault should be deployed");
    }

    /**
     * @notice Test that non-owner cannot deploy vault directly via registry
     * @dev US-IDXEX-027.1: non-owner/non-operator cannot deploy vault
     */
    function test_deployVault_unauthorized_reverts() public {
        // Attacker tries to deploy vault directly through registry
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, attacker));
        IVaultRegistryDeployment(address(indexedexManager))
            .deployVault(
                IStandardVaultPkg(address(aerodromeStandardExchangeDFPkg)),
                abi.encode(IAerodromeStandardExchangeDFPkg.PkgArgs({reserveAsset: aeroExtremeUnbalancedPool}))
            );
    }

    /**
     * @notice Test that owner can deploy vault via DFPkg helper method
     * @dev The DFPkg.deployVault() method internally calls VAULT_REGISTRY_DEPLOYMENT.deployVault()
     *      Since the DFPkg was deployed with IndexedexManager as the registry, owner should succeed.
     */
    function test_deployVault_viaDFPkg_asOwner_succeeds() public {
        // Owner deploys via DFPkg helper method
        vm.prank(owner);
        address vault = aerodromeStandardExchangeDFPkg.deployVault(aeroUnbalancedPool);

        assertTrue(vault != address(0), "Vault should be deployed via DFPkg");
    }

    /**
     * @notice Test that anyone can deploy via DFPkg helper (DFPkg is the authorized caller)
     * @dev When using DFPkg.deployVault(), the DFPkg itself (a registered package) is the
     *      msg.sender to the registry, not the original caller. This is by design - the
     *      security boundary is at package registration (deployPkg requires owner/operator),
     *      not at vault deployment through packages.
     */
    function test_deployVault_viaDFPkg_anyUser_succeeds() public {
        // Any user can deploy via registered DFPkg helper
        vm.prank(attacker);
        address vault = aerodromeStandardExchangeDFPkg.deployVault(aeroExtremeUnbalancedPool);

        assertTrue(vault != address(0), "Vault should be deployed via DFPkg by any user");
    }

    /* -------------------------------------------------------------------------- */
    /*                        Multiple Deployment Tests                            */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Test that owner can deploy multiple vaults
     * @dev Verifies authorization doesn't interfere with multiple deployments
     */
    function test_deployVault_owner_multipleVaults() public {
        vm.startPrank(owner);

        // Deploy first vault
        address vault1 = aerodromeStandardExchangeDFPkg.deployVault(aeroBalancedPool);
        assertTrue(vault1 != address(0), "First vault should be deployed");

        // Deploy second vault
        address vault2 = aerodromeStandardExchangeDFPkg.deployVault(aeroUnbalancedPool);
        assertTrue(vault2 != address(0), "Second vault should be deployed");

        // Different vaults should have different addresses
        assertTrue(vault1 != vault2, "Vaults should have different addresses");

        vm.stopPrank();
    }

    /**
     * @notice Test consistency: deployPkg also requires owner/operator
     * @dev Both deployPkg and deployVault should have same authorization requirements
     */
    function test_deployPkg_unauthorized_reverts() public {
        // Attacker tries to deploy package directly
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, attacker));
        IVaultRegistryDeployment(address(indexedexManager))
            .deployPkg(
                hex"", // dummy initCode
                hex"", // dummy initArgs
                bytes32(0) // dummy salt
            );
    }
}
