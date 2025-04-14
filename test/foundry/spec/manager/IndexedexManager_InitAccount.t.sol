// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {
    DEFAULT_VAULT_USAGE_FEE,
    DEFAULT_DEX_FEE,
    DEFAULT_BOND_MIN_BONUS_PERCENTAGE,
    DEFAULT_BOND_MAX_BONUS_PERCENTAGE,
    DEFAULT_SEIGNIORAGE_INCENTIVE_PERCENTAGE
} from "contracts/constants/Indexedex_CONSTANTS.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";

/**
 * @title IndexedexManager_InitAccount_Test
 * @notice Verifies that IndexedexManager.initAccount results in a usable Vault Fee Oracle
 *         and that the initial owner/feeTo wiring and defaults are present.
 */
contract IndexedexManager_InitAccount_Test is IndexedexTest {
    IVaultFeeOracleQuery feeOracle;
    IVaultFeeOracleManager feeManager;

    function setUp() public override {
        super.setUp();
        feeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        feeManager = IVaultFeeOracleManager(address(indexedexManager));
    }

    function test_managerHasDeployedCode() public view {
        assertTrue(address(indexedexManager).code.length > 0);
    }

    function test_initAccount_feeToIsConfigured() public view {
        assertEq(address(feeOracle.feeTo()), address(feeCollector));
    }

    function test_initAccount_defaultsMatchConstants() public view {
        assertEq(feeOracle.defaultUsageFee(), DEFAULT_VAULT_USAGE_FEE);
        assertEq(feeOracle.defaultDexSwapFee(), DEFAULT_DEX_FEE);
        BondTerms memory terms = feeOracle.defaultBondTerms();
        assertEq(terms.minBonusPercentage, DEFAULT_BOND_MIN_BONUS_PERCENTAGE);
        assertEq(terms.maxBonusPercentage, DEFAULT_BOND_MAX_BONUS_PERCENTAGE);
        assertEq(feeOracle.defaultSeigniorageIncentivePercentage(), DEFAULT_SEIGNIORAGE_INCENTIVE_PERCENTAGE);
    }

    function test_onlyOwner_canSetFeeTo() public {
        address attacker = makeAddr("attacker");

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, attacker));
        feeManager.setFeeTo(IFeeCollectorProxy(makeAddr("newFeeTo")));

        vm.prank(owner);
        bool ok = feeManager.setFeeTo(feeCollector);
        assertTrue(ok);
    }

    function test_setterAccessControl_nonOwnerNonOperator_reverts() public {
        address attacker = makeAddr("attacker");

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, attacker));
        feeManager.setDefaultUsageFee(123);
    }

    function test_managerOwnerAndFactoryOperator_areWired() public view {
        // manager owner should be the test owner
        assertEq(IMultiStepOwnable(address(indexedexManager)).owner(), owner);

        // create3Factory should have indexedexManager registered as an operator (set in IndexedexTest.setUp)
        assertTrue(IOperable(address(create3Factory)).isOperator(address(indexedexManager)));
    }
}
