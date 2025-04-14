// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";

/**
 * @title VaultFeeOracleManagerFacet_Auth_Test
 * @notice Tests that VaultFeeOracleManagerFacet access control is properly enforced
 * @dev All setter functions (except setFeeTo which is onlyOwner) should be onlyOwnerOrOperator
 * @dev Note: IndexedexManager doesn't include OperableFacet, so operator tests are skipped.
 *      When OperableFacet is added to IndexedexManagerDFPkg, operator tests can be enabled.
 */
contract VaultFeeOracleManagerFacet_Auth_Test is IndexedexTest {
    address attacker;
    address operator;
    bytes4 testTypeId;
    address testVault;
    BondTerms testBondTerms;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
        operator = makeAddr("operator");
        testTypeId = bytes4(keccak256("TEST_TYPE"));
        testVault = makeAddr("testVault");
        testBondTerms = BondTerms({
            minLockDuration: 1 days, maxLockDuration: 365 days, minBonusPercentage: 100, maxBonusPercentage: 1000
        });
        // Note: IndexedexManager doesn't include OperableFacet, so we can't set operators.
        // The onlyOwnerOrOperator modifier will still work - it allows owner and rejects non-authorized callers.
        // Set operator on the deployed manager so operator-paths can be exercised
        vm.prank(owner);
        IOperable(address(indexedexManager)).setOperator(operator, true);
    }

    /* ---------------------------------------------------------------------- */
    /*                          setFeeTo (onlyOwner)                          */
    /* ---------------------------------------------------------------------- */

    function test_setFeeTo_revertsForNonOwner() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, attacker));
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(makeAddr("newFeeTo")));
    }

    function test_setFeeTo_succeedsForOwner() public {
        vm.prank(owner);
        bool success = IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(feeCollector);
        assertTrue(success);
    }

    /* ---------------------------------------------------------------------- */
    /*                   setDefaultUsageFee (onlyOwnerOrOperator)             */
    /* ---------------------------------------------------------------------- */

    function test_setDefaultUsageFee_revertsForNonOwnerNonOperator() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, attacker));
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(100);
    }

    function test_setDefaultUsageFee_succeedsForOwner() public {
        vm.prank(owner);
        bool success = IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(100);
        assertTrue(success);
    }

    function test_setDefaultUsageFee_succeedsForOperator() public {
        vm.prank(operator);
        bool success = IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(100);
        assertTrue(success);
    }

    /* ---------------------------------------------------------------------- */
    /*              setDefaultUsageFeeOfTypeId (onlyOwnerOrOperator)          */
    /* ---------------------------------------------------------------------- */

    function test_setDefaultUsageFeeOfTypeId_revertsForNonOwnerNonOperator() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, attacker));
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFeeOfTypeId(testTypeId, 100);
    }

    function test_setDefaultUsageFeeOfTypeId_succeedsForOwner() public {
        vm.prank(owner);
        bool success = IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFeeOfTypeId(testTypeId, 100);
        assertTrue(success);
    }

    function test_setDefaultUsageFeeOfTypeId_succeedsForOperator() public {
        vm.prank(operator);
        bool success = IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFeeOfTypeId(testTypeId, 100);
        assertTrue(success);
    }

    /* ---------------------------------------------------------------------- */
    /*                  setUsageFeeOfVault (onlyOwnerOrOperator)              */
    /* ---------------------------------------------------------------------- */

    function test_setUsageFeeOfVault_revertsForNonOwnerNonOperator() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, attacker));
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(testVault, 100);
    }

    function test_setUsageFeeOfVault_succeedsForOwner() public {
        vm.prank(owner);
        bool success = IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(testVault, 100);
        assertTrue(success);
    }

    function test_setUsageFeeOfVault_succeedsForOperator() public {
        vm.prank(operator);
        bool success = IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(testVault, 100);
        assertTrue(success);
    }

    /* ---------------------------------------------------------------------- */
    /*                 setDefaultBondTerms (onlyOwnerOrOperator)              */
    /* ---------------------------------------------------------------------- */

    function test_setDefaultBondTerms_revertsForNonOwnerNonOperator() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, attacker));
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultBondTerms(testBondTerms);
    }

    function test_setDefaultBondTerms_succeedsForOwner() public {
        vm.prank(owner);
        bool success = IVaultFeeOracleManager(address(indexedexManager)).setDefaultBondTerms(testBondTerms);
        assertTrue(success);
    }

    function test_setDefaultBondTerms_succeedsForOperator() public {
        vm.prank(operator);
        bool success = IVaultFeeOracleManager(address(indexedexManager)).setDefaultBondTerms(testBondTerms);
        assertTrue(success);
    }

    /* ---------------------------------------------------------------------- */
    /*            setDefaultBondTermsOfTypeId (onlyOwnerOrOperator)           */
    /* ---------------------------------------------------------------------- */

    function test_setDefaultBondTermsOfTypeId_revertsForNonOwnerNonOperator() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, attacker));
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultBondTermsOfTypeId(testTypeId, testBondTerms);
    }

    function test_setDefaultBondTermsOfTypeId_succeedsForOwner() public {
        vm.prank(owner);
        bool success =
            IVaultFeeOracleManager(address(indexedexManager)).setDefaultBondTermsOfTypeId(testTypeId, testBondTerms);
        assertTrue(success);
    }

    function test_setDefaultBondTermsOfTypeId_succeedsForOperator() public {
        vm.prank(operator);
        bool success =
            IVaultFeeOracleManager(address(indexedexManager)).setDefaultBondTermsOfTypeId(testTypeId, testBondTerms);
        assertTrue(success);
    }

    /* ---------------------------------------------------------------------- */
    /*                  setVaultBondTerms (onlyOwnerOrOperator)               */
    /* ---------------------------------------------------------------------- */

    function test_setVaultBondTerms_revertsForNonOwnerNonOperator() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, attacker));
        IVaultFeeOracleManager(address(indexedexManager)).setVaultBondTerms(testVault, testBondTerms);
    }

    function test_setVaultBondTerms_succeedsForOwner() public {
        vm.prank(owner);
        bool success = IVaultFeeOracleManager(address(indexedexManager)).setVaultBondTerms(testVault, testBondTerms);
        assertTrue(success);
    }

    function test_setVaultBondTerms_succeedsForOperator() public {
        vm.prank(operator);
        bool success = IVaultFeeOracleManager(address(indexedexManager)).setVaultBondTerms(testVault, testBondTerms);
        assertTrue(success);
    }

    /* ---------------------------------------------------------------------- */
    /*                setDefaultDexSwapFee (onlyOwnerOrOperator)              */
    /* ---------------------------------------------------------------------- */

    function test_setDefaultDexSwapFee_revertsForNonOwnerNonOperator() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, attacker));
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultDexSwapFee(100);
    }

    function test_setDefaultDexSwapFee_succeedsForOwner() public {
        vm.prank(owner);
        bool success = IVaultFeeOracleManager(address(indexedexManager)).setDefaultDexSwapFee(100);
        assertTrue(success);
    }

    function test_setDefaultDexSwapFee_succeedsForOperator() public {
        vm.prank(operator);
        bool success = IVaultFeeOracleManager(address(indexedexManager)).setDefaultDexSwapFee(100);
        assertTrue(success);
    }

    /* ---------------------------------------------------------------------- */
    /*           setDefaultDexSwapFeeOfTypeId (onlyOwnerOrOperator)           */
    /* ---------------------------------------------------------------------- */

    function test_setDefaultDexSwapFeeOfTypeId_revertsForNonOwnerNonOperator() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, attacker));
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultDexSwapFeeOfTypeId(testTypeId, 100);
    }

    function test_setDefaultDexSwapFeeOfTypeId_succeedsForOwner() public {
        vm.prank(owner);
        bool success = IVaultFeeOracleManager(address(indexedexManager)).setDefaultDexSwapFeeOfTypeId(testTypeId, 100);
        assertTrue(success);
    }

    function test_setDefaultDexSwapFeeOfTypeId_succeedsForOperator() public {
        vm.prank(operator);
        bool success = IVaultFeeOracleManager(address(indexedexManager)).setDefaultDexSwapFeeOfTypeId(testTypeId, 100);
        assertTrue(success);
    }

    /* ---------------------------------------------------------------------- */
    /*                 setVaultDexSwapFee (onlyOwnerOrOperator)               */
    /* ---------------------------------------------------------------------- */

    function test_setVaultDexSwapFee_revertsForNonOwnerNonOperator() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, attacker));
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(testVault, 100);
    }

    function test_setVaultDexSwapFee_succeedsForOwner() public {
        vm.prank(owner);
        bool success = IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(testVault, 100);
        assertTrue(success);
    }

    function test_setVaultDexSwapFee_succeedsForOperator() public {
        vm.prank(operator);
        bool success = IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(testVault, 100);
        assertTrue(success);
    }

    /* ---------------------------------------------------------------------- */
    /*                         setFeeTo (operator forbidden)                  */
    /* ---------------------------------------------------------------------- */

    function test_setFeeTo_revertsForOperator() public {
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, operator));
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(makeAddr("newFeeTo")));
    }
}
