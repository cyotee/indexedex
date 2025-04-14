// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {DEFAULT_VAULT_USAGE_FEE, DEFAULT_DEX_FEE} from "contracts/constants/Indexedex_CONSTANTS.sol";

contract VaultFeeOracleManagerFacet_Events_Test is IndexedexTest {
    address testVault;
    bytes4 testTypeId;

    function setUp() public override {
        super.setUp();
        testVault = makeAddr("testVault");
        testTypeId = bytes4(keccak256("TEST_TYPE"));
    }

    function test_setDefaultUsageFee_emitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, false, address(indexedexManager));
        // Manager init sets a non-zero default; assert old value equals DEFAULT_VAULT_USAGE_FEE
        emit IVaultFeeOracleManager.NewDefaultVaultFee(uint256(DEFAULT_VAULT_USAGE_FEE), 1e16);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(1e16);
    }

    function test_setDefaultUsageFeeOfTypeId_emitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, false, address(indexedexManager));
        emit IVaultFeeOracleManager.NewDefaultVaultFeeOfTypeId(testTypeId, 0, 2e16);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFeeOfTypeId(testTypeId, 2e16);
    }

    function test_setUsageFeeOfVault_emitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, false, address(indexedexManager));
        emit IVaultFeeOracleManager.NewVaultFee(testVault, 0, 3e16);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(testVault, 3e16);
    }

    function test_setDefaultDexSwapFee_emitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, false, address(indexedexManager));
        // Manager init sets a non-zero default; assert old value equals DEFAULT_DEX_FEE
        emit IVaultFeeOracleManager.NewDefaultDexFee(uint256(DEFAULT_DEX_FEE), 4e16);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultDexSwapFee(4e16);
    }

    function test_setDefaultDexSwapFeeOfTypeId_emitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, false, address(indexedexManager));
        emit IVaultFeeOracleManager.NewDefaultDexFeeOfTypeId(testTypeId, 0, 5e16);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultDexSwapFeeOfTypeId(testTypeId, 5e16);
    }

    function test_setVaultDexSwapFee_emitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, false, address(indexedexManager));
        emit IVaultFeeOracleManager.NewDexSwapFeeOfVault(testVault, 0, 6e16);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(testVault, 6e16);
    }
}
