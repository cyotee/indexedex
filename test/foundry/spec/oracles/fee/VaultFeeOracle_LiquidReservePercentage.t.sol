// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {VaultFeeOracleRepo} from "contracts/oracles/fee/VaultFeeOracleRepo.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

/**
 * @title VaultFeeOracle_LiquidReservePercentage_Test
 * @notice FO-1..FO-6: liquid reserve percentage three-tier cascade and WAD bounds.
 */
contract VaultFeeOracle_LiquidReservePercentage_Test is IndexedexTest {
    IVaultFeeOracleQuery feeOracle;
    IVaultFeeOracleManager feeManager;

    bytes4 internal constant TEST_TYPE_ID = bytes4(keccak256("LidoWstETHStandardVaultType"));
    address internal testVault;

    uint256 internal constant DEFAULT_LIQUID = 0.05e18; // 5%

    function setUp() public override {
        super.setUp();
        feeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        feeManager = IVaultFeeOracleManager(address(indexedexManager));
        testVault = makeAddr("lidoSeVault");
        // usage fee type id is read from vault registry storage; for unset vault type id is 0,
        // so type-level tests use direct OfTypeId queries + vault override cascade.
    }

    /// @dev FO-1: global only → vault resolves global
    function test_FO1_globalOnly_resolvesForVault() public {
        vm.prank(owner);
        feeManager.setDefaultLiquidReservePercentage(DEFAULT_LIQUID);

        assertEq(feeOracle.defaultLiquidReservePercentage(), DEFAULT_LIQUID);
        // Unregistered vault: usage fee type id is 0, type mapping unset → global
        assertEq(feeOracle.liquidReservePercentageOfVault(testVault), DEFAULT_LIQUID);
    }

    /// @dev FO-2: type override via OfTypeId (direct type query)
    function test_FO2_typeDefault_storedAndQueryable() public {
        vm.startPrank(owner);
        feeManager.setDefaultLiquidReservePercentage(DEFAULT_LIQUID);
        feeManager.setDefaultLiquidReservePercentageOfTypeId(TEST_TYPE_ID, 0.10e18);
        vm.stopPrank();

        assertEq(feeOracle.defaultLiquidReservePercentageOfTypeId(TEST_TYPE_ID), 0.10e18);
        assertEq(feeOracle.defaultLiquidReservePercentage(), DEFAULT_LIQUID);
    }

    /// @dev FO-3: vault override wins over global
    function test_FO3_vaultOverride_winsOverGlobal() public {
        vm.startPrank(owner);
        feeManager.setDefaultLiquidReservePercentage(DEFAULT_LIQUID);
        feeManager.setLiquidReservePercentageOfVault(testVault, 0.15e18);
        vm.stopPrank();

        assertEq(feeOracle.liquidReservePercentageOfVault(testVault), 0.15e18);
        assertEq(feeOracle.defaultLiquidReservePercentage(), DEFAULT_LIQUID);
    }

    /// @dev FO-4: clear vault override (0) falls back to global
    function test_FO4_clearVaultOverride_fallsBackToGlobal() public {
        vm.startPrank(owner);
        feeManager.setDefaultLiquidReservePercentage(DEFAULT_LIQUID);
        feeManager.setLiquidReservePercentageOfVault(testVault, 0.20e18);
        assertEq(feeOracle.liquidReservePercentageOfVault(testVault), 0.20e18);

        feeManager.setLiquidReservePercentageOfVault(testVault, 0);
        vm.stopPrank();

        assertEq(feeOracle.liquidReservePercentageOfVault(testVault), DEFAULT_LIQUID);
    }

    /// @dev FO-5: > 1e18 reverts
    function test_FO5_revertsAboveWAD() public {
        uint256 above = ONE_WAD + 1;
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(VaultFeeOracleRepo.Percentage_ExceedsWAD.selector, above, ONE_WAD));
        feeManager.setDefaultLiquidReservePercentage(above);

        vm.expectRevert(abi.encodeWithSelector(VaultFeeOracleRepo.Percentage_ExceedsWAD.selector, above, ONE_WAD));
        feeManager.setDefaultLiquidReservePercentageOfTypeId(TEST_TYPE_ID, above);

        vm.expectRevert(abi.encodeWithSelector(VaultFeeOracleRepo.Percentage_ExceedsWAD.selector, above, ONE_WAD));
        feeManager.setLiquidReservePercentageOfVault(testVault, above);
        vm.stopPrank();
    }

    /// @dev FO-6: events emit old/new
    function test_FO6_eventsEmitOldAndNew() public {
        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true, address(feeManager));
        emit IVaultFeeOracleManager.NewDefaultLiquidReservePercentage(0, DEFAULT_LIQUID);
        feeManager.setDefaultLiquidReservePercentage(DEFAULT_LIQUID);

        vm.expectEmit(true, true, true, true, address(feeManager));
        emit IVaultFeeOracleManager.NewDefaultLiquidReservePercentageOfTypeId(TEST_TYPE_ID, 0, 0.08e18);
        feeManager.setDefaultLiquidReservePercentageOfTypeId(TEST_TYPE_ID, 0.08e18);

        vm.expectEmit(true, true, true, true, address(feeManager));
        emit IVaultFeeOracleManager.NewLiquidReservePercentageOfVault(testVault, 0, 0.12e18);
        feeManager.setLiquidReservePercentageOfVault(testVault, 0.12e18);

        vm.stopPrank();
    }

    function test_accepts100PercentLiquid() public {
        vm.prank(owner);
        feeManager.setDefaultLiquidReservePercentage(ONE_WAD);
        assertEq(feeOracle.defaultLiquidReservePercentage(), ONE_WAD);
    }

    function test_andFeeTo_returnsFeeToAndPercentage() public {
        vm.prank(owner);
        feeManager.setDefaultLiquidReservePercentage(DEFAULT_LIQUID);
        (IFeeCollectorProxy feeTo_, uint256 pct) = feeOracle.liquidReservePercentageOfVaultAndFeeTo(testVault);
        assertEq(address(feeTo_), address(feeOracle.feeTo()));
        assertEq(pct, DEFAULT_LIQUID);
    }
}
