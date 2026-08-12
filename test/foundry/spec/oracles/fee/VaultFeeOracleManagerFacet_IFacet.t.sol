// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {VaultFeeOracleManagerFacet} from "contracts/oracles/fee/VaultFeeOracleManagerFacet.sol";
import {IndexedexManagerFactoryService} from "contracts/manager/IndexedexManagerFactoryService.sol";

/**
 * @title VaultFeeOracleManagerFacet_IFacet_Test
 * @notice WP-J-MGR-002: IFacet declaration for fee-oracle manager (full selector cut, not seigniorage-only).
 */
contract VaultFeeOracleManagerFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using IndexedexManagerFactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployVaultFeeOracleManagerFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(VaultFeeOracleManagerFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](1);
        controlInterfaces[0] = type(IVaultFeeOracleManager).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](16);
        controlFuncs[0] = IVaultFeeOracleManager.setFeeTo.selector;
        controlFuncs[1] = IVaultFeeOracleManager.setDefaultUsageFee.selector;
        controlFuncs[2] = IVaultFeeOracleManager.setDefaultUsageFeeOfTypeId.selector;
        controlFuncs[3] = IVaultFeeOracleManager.setUsageFeeOfVault.selector;
        controlFuncs[4] = IVaultFeeOracleManager.setDefaultBondTerms.selector;
        controlFuncs[5] = IVaultFeeOracleManager.setDefaultBondTermsOfTypeId.selector;
        controlFuncs[6] = IVaultFeeOracleManager.setVaultBondTerms.selector;
        controlFuncs[7] = IVaultFeeOracleManager.setDefaultDexSwapFee.selector;
        controlFuncs[8] = IVaultFeeOracleManager.setDefaultDexSwapFeeOfTypeId.selector;
        controlFuncs[9] = IVaultFeeOracleManager.setVaultDexSwapFee.selector;
        controlFuncs[10] = IVaultFeeOracleManager.setDefaultSeigniorageIncentivePercentage.selector;
        controlFuncs[11] = IVaultFeeOracleManager.setDefaultSeigniorageIncentivePercentageOfTypeId.selector;
        controlFuncs[12] = IVaultFeeOracleManager.setSeigniorageIncentivePercentageOfVault.selector;
        controlFuncs[13] = IVaultFeeOracleManager.setDefaultLiquidReservePercentage.selector;
        controlFuncs[14] = IVaultFeeOracleManager.setDefaultLiquidReservePercentageOfTypeId.selector;
        controlFuncs[15] = IVaultFeeOracleManager.setLiquidReservePercentageOfVault.selector;
    }
}
