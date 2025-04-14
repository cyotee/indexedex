// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";

/**
 * @title VaultFeeOracleManagerFacet_Seigniorage_Test
 * @notice Tests seigniorage incentive percentage setter functions
 * @dev Tests access control (onlyOwnerOrOperator) and functional correctness (value stored, event emitted)
 */
contract VaultFeeOracleManagerFacet_Seigniorage_Test is IndexedexTest {
    address attacker;
    bytes4 testTypeId;
    address testVault;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
        testTypeId = bytes4(keccak256("TEST_TYPE"));
        testVault = makeAddr("testVault");
    }

    /* ---------------------------------------------------------------------- */
    /*        setDefaultSeigniorageIncentivePercentage (onlyOwnerOrOperator)   */
    /* ---------------------------------------------------------------------- */

    function test_setDefaultSeigniorageIncentivePercentage_revertsForNonOwnerNonOperator() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, attacker));
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultSeigniorageIncentivePercentage(1e17);
    }

    function test_setDefaultSeigniorageIncentivePercentage_succeedsForOwner() public {
        vm.prank(owner);
        bool success = IVaultFeeOracleManager(address(indexedexManager)).setDefaultSeigniorageIncentivePercentage(1e17);
        assertTrue(success);
    }

    function test_setDefaultSeigniorageIncentivePercentage_emitsEvent() public {
        // Default is initialized to 5e17 (50%) in IndexedexManagerDFPkg
        vm.prank(owner);
        vm.expectEmit(true, true, false, false, address(indexedexManager));
        emit IVaultFeeOracleManager.NewDefaultSeigniorageIncentivePercentage(5e17, 1e17);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultSeigniorageIncentivePercentage(1e17);
    }

    function test_setDefaultSeigniorageIncentivePercentage_updatesValue() public {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultSeigniorageIncentivePercentage(1e17);

        // Set again to verify old value is emitted correctly
        vm.prank(owner);
        vm.expectEmit(true, true, false, false, address(indexedexManager));
        emit IVaultFeeOracleManager.NewDefaultSeigniorageIncentivePercentage(1e17, 2e17);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultSeigniorageIncentivePercentage(2e17);
    }

    /* ---------------------------------------------------------------------- */
    /*  setDefaultSeigniorageIncentivePercentageOfTypeId (onlyOwnerOrOperator) */
    /* ---------------------------------------------------------------------- */

    function test_setDefaultSeigniorageIncentivePercentageOfTypeId_revertsForNonOwnerNonOperator() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, attacker));
        IVaultFeeOracleManager(address(indexedexManager))
            .setDefaultSeigniorageIncentivePercentageOfTypeId(testTypeId, 1e17);
    }

    function test_setDefaultSeigniorageIncentivePercentageOfTypeId_succeedsForOwner() public {
        vm.prank(owner);
        bool success = IVaultFeeOracleManager(address(indexedexManager))
            .setDefaultSeigniorageIncentivePercentageOfTypeId(testTypeId, 1e17);
        assertTrue(success);
    }

    function test_setDefaultSeigniorageIncentivePercentageOfTypeId_emitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, false, address(indexedexManager));
        emit IVaultFeeOracleManager.NewDefaultSeigniorageIncentivePercentageOfTypeId(testTypeId, 0, 1e17);
        IVaultFeeOracleManager(address(indexedexManager))
            .setDefaultSeigniorageIncentivePercentageOfTypeId(testTypeId, 1e17);
    }

    /* ---------------------------------------------------------------------- */
    /*      setSeigniorageIncentivePercentageOfVault (onlyOwnerOrOperator)     */
    /* ---------------------------------------------------------------------- */

    function test_setSeigniorageIncentivePercentageOfVault_revertsForNonOwnerNonOperator() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, attacker));
        IVaultFeeOracleManager(address(indexedexManager)).setSeigniorageIncentivePercentageOfVault(testVault, 1e17);
    }

    function test_setSeigniorageIncentivePercentageOfVault_succeedsForOwner() public {
        vm.prank(owner);
        bool success =
            IVaultFeeOracleManager(address(indexedexManager)).setSeigniorageIncentivePercentageOfVault(testVault, 1e17);
        assertTrue(success);
    }

    function test_setSeigniorageIncentivePercentageOfVault_emitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, false, address(indexedexManager));
        emit IVaultFeeOracleManager.NewSeigniorageIncentivePercentageOfVault(testVault, 0, 1e17);
        IVaultFeeOracleManager(address(indexedexManager)).setSeigniorageIncentivePercentageOfVault(testVault, 1e17);
    }
}
