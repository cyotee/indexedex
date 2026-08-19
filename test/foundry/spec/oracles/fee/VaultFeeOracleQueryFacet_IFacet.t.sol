// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {VaultFeeOracleQueryFacet} from "contracts/oracles/fee/VaultFeeOracleQueryFacet.sol";
import {IndexedexManagerFactoryService} from "contracts/manager/IndexedexManagerFactoryService.sol";

/**
 * @title VaultFeeOracleQueryFacet_IFacet_Test
 * @notice WP-J-MGR-002: IFacet declaration for fee-oracle query (full surface).
 */
contract VaultFeeOracleQueryFacet_IFacet_Test is CraneTest, TestBase_IFacet {
    using IndexedexManagerFactoryService for ICreate3FactoryProxy;

    function setUp() public override(CraneTest, TestBase_IFacet) {
        CraneTest.setUp();
        TestBase_IFacet.setUp();
    }

    function facetTestInstance() public override returns (IFacet) {
        return create3Factory.deployVaultFeeOracleQueryFacet();
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(VaultFeeOracleQueryFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](1);
        controlInterfaces[0] = type(IVaultFeeOracleQuery).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](34);
        controlFuncs[0] = IVaultFeeOracleQuery.feeTo.selector;
        controlFuncs[1] = IVaultFeeOracleQuery.usageFeeVaultTypeIds.selector;
        controlFuncs[2] = IVaultFeeOracleQuery.defaultUsageFee.selector;
        controlFuncs[3] = IVaultFeeOracleQuery.defaultUsageFeeOfTypeId.selector;
        controlFuncs[4] = IVaultFeeOracleQuery.usageFeeOfVault.selector;
        controlFuncs[5] = IVaultFeeOracleQuery.usageFeeAndFeeToOfVault.selector;
        controlFuncs[6] = IVaultFeeOracleQuery.dexSwapFeeVaultTypeIds.selector;
        controlFuncs[7] = IVaultFeeOracleQuery.defaultDexSwapFee.selector;
        controlFuncs[8] = IVaultFeeOracleQuery.defaultDexSwapFeeOfTypeId.selector;
        controlFuncs[9] = IVaultFeeOracleQuery.dexSwapFeeOfVault.selector;
        controlFuncs[10] = IVaultFeeOracleQuery.dexSwapFeeAndFeeToOfVault.selector;
        controlFuncs[11] = IVaultFeeOracleQuery.bondVaultTypesIds.selector;
        controlFuncs[12] = IVaultFeeOracleQuery.defaultBondTerms.selector;
        controlFuncs[13] = IVaultFeeOracleQuery.defaultBondTermsOfVaultTypeId.selector;
        controlFuncs[14] = IVaultFeeOracleQuery.bondTermsOfVault.selector;
        controlFuncs[15] = IVaultFeeOracleQuery.bondTermsAndFeeToOfVault.selector;
        controlFuncs[16] = IVaultFeeOracleQuery.seigniorageVaultTypeIds.selector;
        controlFuncs[17] = IVaultFeeOracleQuery.defaultSeigniorageIncentivePercentage.selector;
        controlFuncs[18] = IVaultFeeOracleQuery.seigniorageIncentivePercentageOfTypeId.selector;
        controlFuncs[19] = IVaultFeeOracleQuery.seigniorageIncentivePercentageOfVault.selector;
        controlFuncs[20] = IVaultFeeOracleQuery.seigniorageIncentivePercentageOfVaultAndFeeTo.selector;
        controlFuncs[21] = IVaultFeeOracleQuery.defaultLiquidReservePercentage.selector;
        controlFuncs[22] = IVaultFeeOracleQuery.defaultLiquidReservePercentageOfTypeId.selector;
        controlFuncs[23] = IVaultFeeOracleQuery.liquidReservePercentageOfVault.selector;
        controlFuncs[24] = IVaultFeeOracleQuery.liquidReservePercentageOfVaultAndFeeTo.selector;
        controlFuncs[25] = IVaultFeeOracleQuery.defaultSeigniorageFeeToSharePercentage.selector;
        controlFuncs[26] = IVaultFeeOracleQuery.seigniorageFeeToSharePercentageOfTypeId.selector;
        controlFuncs[27] = IVaultFeeOracleQuery.seigniorageFeeToSharePercentageOfVault.selector;
        controlFuncs[28] = IVaultFeeOracleQuery.defaultSeigniorageCreatorSharePercentage.selector;
        controlFuncs[29] = IVaultFeeOracleQuery.seigniorageCreatorSharePercentageOfTypeId.selector;
        controlFuncs[30] = IVaultFeeOracleQuery.seigniorageCreatorSharePercentageOfVault.selector;
        controlFuncs[31] = IVaultFeeOracleQuery.seigniorageSplitOfVault.selector;
        controlFuncs[32] = IVaultFeeOracleQuery.seigniorageSplitAndFeeToOfVault.selector;
        controlFuncs[33] = IVaultFeeOracleQuery.bondTermsAndSeigniorageOfVault.selector;
    }
}
