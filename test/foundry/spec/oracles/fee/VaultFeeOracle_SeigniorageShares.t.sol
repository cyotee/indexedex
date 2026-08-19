// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultFeeOracleRepo} from "contracts/oracles/fee/VaultFeeOracleRepo.sol";
import {DEFAULT_SEIGNIORAGE_INCENTIVE_PERCENTAGE} from "contracts/constants/Indexedex_CONSTANTS.sol";

/**
 * @title VaultFeeOracle_SeigniorageShares_Test
 * @notice Alignment D5/D6: 3-tier `f`/`c` on the production manager proxy.
 */
contract VaultFeeOracle_SeigniorageShares_Test is IndexedexTest {
    IVaultFeeOracleQuery internal qry;
    IVaultFeeOracleManager internal mgr;
    address internal testVault;
    bytes4 internal testTypeId;

    function setUp() public override {
        super.setUp();
        qry = IVaultFeeOracleQuery(address(indexedexManager));
        mgr = IVaultFeeOracleManager(address(indexedexManager));
        testVault = makeAddr("seigniorageShareVault");
        testTypeId = bytes4(keccak256("SEIGNIORAGE_SHARE_TYPE"));
    }

    function test_managerDeploy_inits_p_f_c() public view {
        assertEq(qry.defaultSeigniorageIncentivePercentage(), 5e16, "p init");
        assertEq(qry.defaultSeigniorageIncentivePercentage(), DEFAULT_SEIGNIORAGE_INCENTIVE_PERCENTAGE, "p constant");
        assertEq(qry.defaultSeigniorageFeeToSharePercentage(), 12e16, "f init");
        assertEq(qry.defaultSeigniorageCreatorSharePercentage(), 28e16, "c init");
        (uint256 p_, uint256 f_, uint256 c_) = qry.seigniorageSplitOfVault(testVault);
        assertEq(p_, 5e16, "tuple p");
        assertEq(f_, 12e16, "tuple f");
        assertEq(c_, 28e16, "tuple c");
        assertTrue(f_ + c_ < 1e18, "f+c < 1e18");
    }

    function test_tupleGetters_include_feeTo_and_bondTerms() public view {
        (IFeeCollectorProxy feeTo_, uint256 p_, uint256 f_, uint256 c_) = qry.seigniorageSplitAndFeeToOfVault(testVault);
        assertEq(address(feeTo_), address(qry.feeTo()), "feeTo");
        assertEq(p_, 5e16);
        assertEq(f_, 12e16);
        assertEq(c_, 28e16);

        BondTerms memory terms_;
        (feeTo_, terms_, p_, f_, c_) = qry.bondTermsAndSeigniorageOfVault(testVault);
        assertEq(address(feeTo_), address(qry.feeTo()), "bond feeTo");
        assertEq(terms_.minLockDuration, qry.defaultBondTerms().minLockDuration, "bond terms");
        assertEq(p_, 5e16);
        assertEq(f_, 12e16);
        assertEq(c_, 28e16);
    }

    function test_threeTier_f_and_c_readback() public {
        vm.prank(owner);
        mgr.setDefaultSeigniorageFeeToSharePercentageOfTypeId(testTypeId, 10e16);
        vm.prank(owner);
        mgr.setDefaultSeigniorageCreatorSharePercentageOfTypeId(testTypeId, 20e16);
        assertEq(qry.seigniorageFeeToSharePercentageOfTypeId(testTypeId), 10e16, "type f");
        assertEq(qry.seigniorageCreatorSharePercentageOfTypeId(testTypeId), 20e16, "type c");

        vm.prank(owner);
        mgr.setSeigniorageFeeToSharePercentageOfVault(testVault, 8e16);
        vm.prank(owner);
        mgr.setSeigniorageCreatorSharePercentageOfVault(testVault, 15e16);
        assertEq(qry.seigniorageFeeToSharePercentageOfVault(testVault), 8e16, "vault f");
        assertEq(qry.seigniorageCreatorSharePercentageOfVault(testVault), 15e16, "vault c");

        vm.prank(owner);
        mgr.setSeignioragePotSharesOfVault(testVault, 0, 0);
        assertEq(qry.seigniorageFeeToSharePercentageOfVault(testVault), 12e16, "clear vault falls to global");
        assertEq(qry.seigniorageCreatorSharePercentageOfVault(testVault), 28e16, "clear vault c");
    }

    function test_reject_setDefault_f_plus_c_eq_wad() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(VaultFeeOracleRepo.SeignioragePotShares_SumNotBelowWAD.selector, 12e16, 88e16)
        );
        mgr.setDefaultSeigniorageCreatorSharePercentage(88e16);
    }

    function test_reject_atomic_f_plus_c_ge_wad() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(VaultFeeOracleRepo.SeignioragePotShares_SumNotBelowWAD.selector, 50e16, 50e16)
        );
        mgr.setDefaultSeignioragePotShares(50e16, 50e16);
    }

    function test_reject_type_resolved_f_plus_c_ge_wad() public {
        // type f = 80%, type c unset → resolved c = global 28% → 108%.
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(VaultFeeOracleRepo.SeignioragePotShares_SumNotBelowWAD.selector, 80e16, 28e16)
        );
        mgr.setDefaultSeigniorageFeeToSharePercentageOfTypeId(testTypeId, 80e16);
    }

    function test_atomic_global_pot_shares_succeeds_under_wad() public {
        vm.prank(owner);
        bool ok_ = mgr.setDefaultSeignioragePotShares(10e16, 20e16);
        assertTrue(ok_);
        assertEq(qry.defaultSeigniorageFeeToSharePercentage(), 10e16);
        assertEq(qry.defaultSeigniorageCreatorSharePercentage(), 20e16);
        (uint256 p_, uint256 f_, uint256 c_) = qry.seigniorageSplitOfVault(testVault);
        assertEq(p_, 5e16);
        assertEq(f_, 10e16);
        assertEq(c_, 20e16);
    }
}
