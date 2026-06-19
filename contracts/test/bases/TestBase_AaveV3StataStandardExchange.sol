// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {BetterPermit2} from "@crane/contracts/protocols/utils/permit2/BetterPermit2.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {
    IAaveV3StataStandardExchangeDFPkg,
    AaveV3StataStandardExchangeDFPkg
} from "contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeDFPkg.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {
    AaveV3Stata_Component_FactoryService
} from "contracts/protocols/lending/aave/v3.6/AaveV3Stata_Component_FactoryService.sol";

import {StataTokenV2} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/StataTokenV2.sol";
import {IStataTokenFactory} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/interfaces/IStataTokenFactory.sol";
import {IPool} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPool.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";

/**
 * @title TestBase_AaveV3StataStandardExchange
 * @notice Test base for the Aave v3.6 Stata Standard Exchange Vault.
 */
contract TestBase_AaveV3StataStandardExchange is TestBase_Permit2, TestBase_VaultComponents {
    using AaveV3Stata_Component_FactoryService for ICreate3FactoryProxy;
    using AaveV3Stata_Component_FactoryService for IIndexedexManagerProxy;

    IFacet aaveV3StataStandardExchangeInFacet;
    IFacet aaveV3StataStandardExchangeOutFacet;
    IFacet aaveV3StataMarkerFacet;
    IAaveV3StataStandardExchangeDFPkg aaveV3StataStandardExchangeDFPkg;

    // Test Aave setup (using Crane vendored or stub)
    IPool internal pool;
    IStataTokenFactory internal stataFactory;
    address internal testUnderlying;
    address internal testStata;

    function setUp() public virtual override(TestBase_Permit2, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();

        // Setup simple test token and mock stata for basic tests (in real use Crane Aave test bases)
        // For full tests, use Crane's AaveV3 test procedures to deploy real pool + stata.
        testUnderlying = makeAddr("testUnderlying");
        testStata = makeAddr("testStata"); // placeholder - in real tests replace with actual StataTokenV2

        aaveV3StataStandardExchangeInFacet = create3Factory.deployAaveV3StataStandardExchangeInFacet();
        aaveV3StataStandardExchangeOutFacet = create3Factory.deployAaveV3StataStandardExchangeOutFacet();
        aaveV3StataMarkerFacet = create3Factory.deployAaveV3StataMarkerFacet();

        vm.prank(owner);
        aaveV3StataStandardExchangeDFPkg = indexedexManager.deployAaveV3StataStandardExchangeDFPkg(
            _buildAaveV3StataPkgInit()
        );
    }

    function _buildAaveV3StataPkgInit() internal view returns (IAaveV3StataStandardExchangeDFPkg.PkgInit memory) {
        return IAaveV3StataStandardExchangeDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc2612Facet: erc2612Facet,
            erc5267Facet: erc5267Facet,
            erc4626Facet: erc4626Facet,
            erc4626StandardVaultFacet: erc4626StandardVaultFacet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
            aaveV3StataStandardExchangeInFacet: aaveV3StataStandardExchangeInFacet,
            aaveV3StataStandardExchangeOutFacet: aaveV3StataStandardExchangeOutFacet,
            aaveV3StataMarkerFacet: aaveV3StataMarkerFacet,
            vaultFeeOracleQuery: indexedexManager,
            vaultRegistryDeployment: indexedexManager,
            permit2: permit2,
            stataTokenFactory: IStataTokenFactory(address(0)) // set in full test with real factory
        });
    }

    // Helper to deploy a vault for tests
    function _deployStataVault(address stata) internal returns (address vault) {
        vm.prank(owner);
        vault = aaveV3StataStandardExchangeDFPkg.deployVault(IERC20(stata));
    }
}
