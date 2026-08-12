// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryVaultManager} from "contracts/interfaces/IVaultRegistryVaultManager.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultRegistryVaultPackageManager} from "contracts/interfaces/IVaultRegistryVaultPackageManager.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {
    DEFAULT_BOND_MIN_TERM,
    DEFAULT_BOND_MAX_TERM,
    DEFAULT_BOND_MIN_BONUS_PERCENTAGE,
    DEFAULT_BOND_MAX_BONUS_PERCENTAGE
} from "contracts/constants/Indexedex_CONSTANTS.sol";

/**
 * @title IndexedexManager_Surface_Test
 * @notice WP-J-MGR-002: J1–J3 diamond surface for manager/registry/oracle beyond seigniorage.
 * @dev Guards silent-missing API: Target ⊆ facetFuncs ⊆ loupe ⊆ proxy call (not facet impl alone).
 *      Seigniorage covered by WP-J-MGR-001 (`VaultFeeOracle_Seigniorage_Surface`).
 */
contract IndexedexManager_Surface_Test is IndexedexTest {
    address testVault;
    address testPkg;
    bytes4 testTypeId;

    bytes32 constant FEE_IDS = bytes32(
        abi.encodePacked(
            bytes4(0x11111111),
            bytes4(0x22222222),
            bytes4(0x33333333),
            bytes4(0x44444444),
            bytes4(0x55555555),
            bytes12(0)
        )
    );

    function setUp() public override {
        super.setUp();
        testVault = makeAddr("testVault");
        testPkg = makeAddr("testPkg");
        testTypeId = bytes4(keccak256("TEST_TYPE"));
    }

    function _contains(bytes4[] memory funcs_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < funcs_.length; ++i) {
            if (funcs_[i] == sel_) return true;
        }
        return false;
    }

    function _assertFacetFuncsOnLoupe(IFacet facet_, address expectedFacet_) internal view {
        bytes4[] memory funcs_ = facet_.facetFuncs();
        IDiamondLoupe loupe_ = IDiamondLoupe(address(indexedexManager));
        for (uint256 i; i < funcs_.length; ++i) {
            address loupeFacet_ = loupe_.facetAddress(funcs_[i]);
            assertEq(loupeFacet_, expectedFacet_, "J2 loupe maps selector to CREATE3 facet");
            assertTrue(loupeFacet_ != address(0), "J2 not zero");
            assertTrue(loupeFacet_ != address(indexedexManager), "J2 not self-facet");
        }
    }

    /* ---------------------------------------------------------------------- */
    /*  J1: Target/product selectors ⊆ facetFuncs (non-seigniorage)           */
    /* ---------------------------------------------------------------------- */

    /// @notice J1: fee-oracle manager non-seigniorage setters are cut into facetFuncs.
    function test_J1_managerFeeOracle_nonSeigniorage_selectors_in_facetFuncs() public view {
        bytes4[] memory funcs_ = vaultFeeOracleManagerFacet.facetFuncs();
        assertTrue(_contains(funcs_, IVaultFeeOracleManager.setFeeTo.selector), "J1 setFeeTo");
        assertTrue(_contains(funcs_, IVaultFeeOracleManager.setDefaultUsageFee.selector), "J1 setDefaultUsageFee");
        assertTrue(
            _contains(funcs_, IVaultFeeOracleManager.setDefaultUsageFeeOfTypeId.selector),
            "J1 setDefaultUsageFeeOfTypeId"
        );
        assertTrue(_contains(funcs_, IVaultFeeOracleManager.setUsageFeeOfVault.selector), "J1 setUsageFeeOfVault");
        assertTrue(_contains(funcs_, IVaultFeeOracleManager.setDefaultBondTerms.selector), "J1 setDefaultBondTerms");
        assertTrue(
            _contains(funcs_, IVaultFeeOracleManager.setDefaultBondTermsOfTypeId.selector),
            "J1 setDefaultBondTermsOfTypeId"
        );
        assertTrue(_contains(funcs_, IVaultFeeOracleManager.setVaultBondTerms.selector), "J1 setVaultBondTerms");
        assertTrue(_contains(funcs_, IVaultFeeOracleManager.setDefaultDexSwapFee.selector), "J1 setDefaultDexSwapFee");
        assertTrue(
            _contains(funcs_, IVaultFeeOracleManager.setDefaultDexSwapFeeOfTypeId.selector),
            "J1 setDefaultDexSwapFeeOfTypeId"
        );
        assertTrue(_contains(funcs_, IVaultFeeOracleManager.setVaultDexSwapFee.selector), "J1 setVaultDexSwapFee");
        assertTrue(
            _contains(funcs_, IVaultFeeOracleManager.setDefaultLiquidReservePercentage.selector),
            "J1 setDefaultLiquidReservePercentage"
        );
        assertTrue(
            _contains(funcs_, IVaultFeeOracleManager.setDefaultLiquidReservePercentageOfTypeId.selector),
            "J1 setDefaultLiquidReservePercentageOfTypeId"
        );
        assertTrue(
            _contains(funcs_, IVaultFeeOracleManager.setLiquidReservePercentageOfVault.selector),
            "J1 setLiquidReservePercentageOfVault"
        );
        assertEq(funcs_.length, 16, "J1 fee manager facetFuncs length");
    }

    /// @notice J1: fee-oracle query non-seigniorage getters are cut.
    function test_J1_queryFeeOracle_nonSeigniorage_selectors_in_facetFuncs() public view {
        bytes4[] memory funcs_ = vaultFeeOracleQueryFacet.facetFuncs();
        assertTrue(_contains(funcs_, IVaultFeeOracleQuery.feeTo.selector), "J1 feeTo");
        assertTrue(_contains(funcs_, IVaultFeeOracleQuery.defaultUsageFee.selector), "J1 defaultUsageFee");
        assertTrue(_contains(funcs_, IVaultFeeOracleQuery.usageFeeOfVault.selector), "J1 usageFeeOfVault");
        assertTrue(_contains(funcs_, IVaultFeeOracleQuery.defaultDexSwapFee.selector), "J1 defaultDexSwapFee");
        assertTrue(_contains(funcs_, IVaultFeeOracleQuery.dexSwapFeeOfVault.selector), "J1 dexSwapFeeOfVault");
        assertTrue(_contains(funcs_, IVaultFeeOracleQuery.defaultBondTerms.selector), "J1 defaultBondTerms");
        assertTrue(_contains(funcs_, IVaultFeeOracleQuery.bondTermsOfVault.selector), "J1 bondTermsOfVault");
        assertTrue(
            _contains(funcs_, IVaultFeeOracleQuery.defaultLiquidReservePercentage.selector),
            "J1 defaultLiquidReservePercentage"
        );
        assertTrue(
            _contains(funcs_, IVaultFeeOracleQuery.liquidReservePercentageOfVault.selector),
            "J1 liquidReservePercentageOfVault"
        );
        assertEq(funcs_.length, 25, "J1 fee query facetFuncs length");
    }

    /// @notice J1: registry vault manager/package/disable/deployment selectors cut.
    function test_J1_registry_manager_selectors_in_facetFuncs() public view {
        bytes4[] memory vaultMgr_ = vaultRegistryVaultManagerFacet.facetFuncs();
        assertTrue(_contains(vaultMgr_, IVaultRegistryVaultManager.registerVault.selector), "J1 registerVault");
        assertTrue(_contains(vaultMgr_, IVaultRegistryVaultManager.unregisterVault.selector), "J1 unregisterVault");
        assertEq(vaultMgr_.length, 2, "J1 vault manager length");

        bytes4[] memory pkgMgr_ = vaultRegistryVaultPackageManagerFacet.facetFuncs();
        assertTrue(
            _contains(pkgMgr_, IVaultRegistryVaultPackageManager.registerPackage.selector), "J1 registerPackage"
        );
        assertTrue(
            _contains(pkgMgr_, IVaultRegistryVaultPackageManager.unregisterPackage.selector), "J1 unregisterPackage"
        );
        assertEq(pkgMgr_.length, 2, "J1 package manager length");

        bytes4[] memory disMgr_ = vaultRegistryDisableManagerFacet.facetFuncs();
        assertTrue(
            _contains(disMgr_, IVaultRegistryDisableManager.setVaultAddressDisabled.selector),
            "J1 setVaultAddressDisabled"
        );
        assertTrue(
            _contains(disMgr_, IVaultRegistryDisableManager.setPackageDisabled.selector), "J1 setPackageDisabled"
        );
        assertEq(disMgr_.length, 2, "J1 disable manager length");

        bytes4[] memory deploy_ = vaultRegistryDeploymentFacet.facetFuncs();
        assertTrue(_contains(deploy_, IVaultRegistryDeployment.deployPkg.selector), "J1 deployPkg");
        assertTrue(_contains(deploy_, IVaultRegistryDeployment.deployVault.selector), "J1 deployVault");
        assertTrue(_contains(deploy_, IVaultRegistryDeployment.deployHookVault.selector), "J1 deployHookVault");
        assertTrue(
            _contains(deploy_, IVaultRegistryDeployment.deployHookVaultAutoMine.selector), "J1 deployHookVaultAutoMine"
        );
        assertTrue(
            _contains(deploy_, IVaultRegistryDeployment.setHookDiamondPackageFactory.selector),
            "J1 setHookDiamondPackageFactory"
        );
        assertEq(deploy_.length, 5, "J1 deployment length");
    }

    /// @notice J1: registry query surfaces (vault + package + disable) are cut.
    function test_J1_registry_query_selectors_in_facetFuncs() public view {
        bytes4[] memory vaultQ_ = vaultRegistryVaultQueryFacet.facetFuncs();
        assertTrue(_contains(vaultQ_, IVaultRegistryVaultQuery.vaults.selector), "J1 vaults");
        assertTrue(_contains(vaultQ_, IVaultRegistryVaultQuery.isVault.selector), "J1 isVault");
        assertTrue(_contains(vaultQ_, IVaultRegistryVaultQuery.vaultUsageFeeTypeId.selector), "J1 vaultUsageFeeTypeId");
        assertTrue(_contains(vaultQ_, IVaultRegistryVaultQuery.vaultDexTermsTypeId.selector), "J1 vaultDexTermsTypeId");
        assertTrue(
            _contains(vaultQ_, IVaultRegistryVaultQuery.vaultBondTermsTypeId.selector), "J1 vaultBondTermsTypeId"
        );
        assertTrue(
            _contains(vaultQ_, IVaultRegistryVaultQuery.vaultLendingTermsTypeId.selector), "J1 vaultLendingTermsTypeId"
        );
        assertEq(vaultQ_.length, 22, "J1 vault query length");

        bytes4[] memory pkgQ_ = vaultRegistryVaultPackageQueryFacet.facetFuncs();
        assertTrue(_contains(pkgQ_, IVaultRegistryVaultPackageQuery.vaultPackages.selector), "J1 vaultPackages");
        assertTrue(_contains(pkgQ_, IVaultRegistryVaultPackageQuery.isPackage.selector), "J1 isPackage");
        assertTrue(
            _contains(pkgQ_, IVaultRegistryVaultPackageQuery.vaultUsageFeeTypeIds.selector), "J1 vaultUsageFeeTypeIds"
        );
        assertEq(pkgQ_.length, 10, "J1 package query length");

        bytes4[] memory disQ_ = vaultRegistryDisableQueryFacet.facetFuncs();
        assertTrue(_contains(disQ_, IVaultRegistryDisableQuery.isDisabled.selector), "J1 isDisabled");
        assertTrue(
            _contains(disQ_, IVaultRegistryDisableQuery.isDisabledDetailed.selector), "J1 isDisabledDetailed"
        );
        assertTrue(
            _contains(disQ_, IVaultRegistryDisableQuery.isVaultAddressDisabled.selector), "J1 isVaultAddressDisabled"
        );
        assertEq(disQ_.length, 7, "J1 disable query length");
    }

    /* ---------------------------------------------------------------------- */
    /*  J2: facetFuncs ⊆ loupe on production manager proxy                    */
    /* ---------------------------------------------------------------------- */

    function test_J2_feeOracleManager_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(vaultFeeOracleManagerFacet, address(vaultFeeOracleManagerFacet));
    }

    function test_J2_feeOracleQuery_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(vaultFeeOracleQueryFacet, address(vaultFeeOracleQueryFacet));
    }

    function test_J2_registryVaultManager_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(vaultRegistryVaultManagerFacet, address(vaultRegistryVaultManagerFacet));
    }

    function test_J2_registryVaultQuery_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(vaultRegistryVaultQueryFacet, address(vaultRegistryVaultQueryFacet));
    }

    function test_J2_registryPackageManager_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(vaultRegistryVaultPackageManagerFacet, address(vaultRegistryVaultPackageManagerFacet));
    }

    function test_J2_registryPackageQuery_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(vaultRegistryVaultPackageQueryFacet, address(vaultRegistryVaultPackageQueryFacet));
    }

    function test_J2_registryDisableManager_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(vaultRegistryDisableManagerFacet, address(vaultRegistryDisableManagerFacet));
    }

    function test_J2_registryDisableQuery_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(vaultRegistryDisableQueryFacet, address(vaultRegistryDisableQueryFacet));
    }

    function test_J2_registryDeployment_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(vaultRegistryDeploymentFacet, address(vaultRegistryDeploymentFacet));
    }

    /* ---------------------------------------------------------------------- */
    /*  J3: proxy smoke — loupe-routed calls (not facet impl)                 */
    /* ---------------------------------------------------------------------- */

    /// @notice J3: fee oracle usage/dex/bond/liquid-reserve manager+query via manager proxy.
    function test_J3_proxySmoke_feeOracle_nonSeigniorage() public {
        IVaultFeeOracleManager mgr_ = IVaultFeeOracleManager(address(indexedexManager));
        IVaultFeeOracleQuery qry_ = IVaultFeeOracleQuery(address(indexedexManager));

        // Seeded defaults on manager init
        assertEq(address(qry_.feeTo()), address(feeCollector), "J3 feeTo seeded");
        assertTrue(qry_.defaultUsageFee() > 0, "J3 default usage fee seeded");
        assertTrue(qry_.defaultDexSwapFee() > 0, "J3 default dex fee seeded");
        BondTerms memory bond_ = qry_.defaultBondTerms();
        assertEq(bond_.minLockDuration, DEFAULT_BOND_MIN_TERM, "J3 bond min term");
        assertEq(bond_.maxLockDuration, DEFAULT_BOND_MAX_TERM, "J3 bond max term");
        assertEq(bond_.minBonusPercentage, DEFAULT_BOND_MIN_BONUS_PERCENTAGE, "J3 bond min bonus");
        assertEq(bond_.maxBonusPercentage, DEFAULT_BOND_MAX_BONUS_PERCENTAGE, "J3 bond max bonus");

        // Mutating non-seigniorage surface via proxy
        vm.prank(owner);
        assertTrue(mgr_.setDefaultUsageFee(1e15), "J3 setDefaultUsageFee");
        assertEq(qry_.defaultUsageFee(), 1e15, "J3 usage readback");

        vm.prank(owner);
        assertTrue(mgr_.setDefaultUsageFeeOfTypeId(testTypeId, 2e15), "J3 setUsageOfTypeId");
        assertEq(qry_.defaultUsageFeeOfTypeId(testTypeId), 2e15, "J3 usage type readback");

        vm.prank(owner);
        assertTrue(mgr_.setUsageFeeOfVault(testVault, 3e15), "J3 setUsageOfVault");
        assertEq(qry_.usageFeeOfVault(testVault), 3e15, "J3 usage vault readback");

        vm.prank(owner);
        assertTrue(mgr_.setDefaultDexSwapFee(5e16), "J3 setDefaultDex");
        assertEq(qry_.defaultDexSwapFee(), 5e16, "J3 dex readback");

        vm.prank(owner);
        assertTrue(mgr_.setDefaultDexSwapFeeOfTypeId(testTypeId, 6e16), "J3 setDexOfTypeId");
        assertEq(qry_.defaultDexSwapFeeOfTypeId(testTypeId), 6e16, "J3 dex type readback");

        vm.prank(owner);
        assertTrue(mgr_.setVaultDexSwapFee(testVault, 7e16), "J3 setDexOfVault");
        assertEq(qry_.dexSwapFeeOfVault(testVault), 7e16, "J3 dex vault readback");

        BondTerms memory newBond_ = BondTerms({
            minLockDuration: 7 days,
            maxLockDuration: 90 days,
            minBonusPercentage: 1e16,
            maxBonusPercentage: 5e16
        });
        vm.prank(owner);
        assertTrue(mgr_.setDefaultBondTerms(newBond_), "J3 setDefaultBondTerms");
        BondTerms memory rb_ = qry_.defaultBondTerms();
        assertEq(rb_.minLockDuration, 7 days, "J3 bond min readback");
        assertEq(rb_.maxBonusPercentage, 5e16, "J3 bond max bonus readback");

        vm.prank(owner);
        assertTrue(mgr_.setDefaultBondTermsOfTypeId(testTypeId, newBond_), "J3 setBondOfTypeId");
        assertEq(qry_.defaultBondTermsOfVaultTypeId(testTypeId).minLockDuration, 7 days, "J3 bond type readback");

        vm.prank(owner);
        assertTrue(mgr_.setVaultBondTerms(testVault, newBond_), "J3 setVaultBondTerms");
        assertEq(qry_.bondTermsOfVault(testVault).maxLockDuration, 90 days, "J3 bond vault readback");

        vm.prank(owner);
        assertTrue(mgr_.setDefaultLiquidReservePercentage(5e16), "J3 setDefaultLR");
        assertEq(qry_.defaultLiquidReservePercentage(), 5e16, "J3 LR readback");

        vm.prank(owner);
        assertTrue(mgr_.setDefaultLiquidReservePercentageOfTypeId(testTypeId, 6e16), "J3 setLROfTypeId");
        assertEq(qry_.defaultLiquidReservePercentageOfTypeId(testTypeId), 6e16, "J3 LR type readback");

        vm.prank(owner);
        assertTrue(mgr_.setLiquidReservePercentageOfVault(testVault, 7e16), "J3 setLROfVault");
        assertEq(qry_.liquidReservePercentageOfVault(testVault), 7e16, "J3 LR vault readback");

        // Loupe: non-seigniorage selector routes to CREATE3 facet, not proxy self
        address loupeUsage_ =
            IDiamondLoupe(address(indexedexManager)).facetAddress(IVaultFeeOracleManager.setDefaultUsageFee.selector);
        assertEq(loupeUsage_, address(vaultFeeOracleManagerFacet), "J3 setDefaultUsageFee loupe");
        assertTrue(loupeUsage_ != address(indexedexManager), "J3 not self-facet");
    }

    /// @notice J3: registry vault/package/disable/query via manager proxy.
    function test_J3_proxySmoke_registry_vaultPackageDisable() public {
        address tokenA = makeAddr("tokenA");
        address tokenB = makeAddr("tokenB");
        if (uint160(tokenA) > uint160(tokenB)) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }
        address[] memory tokens_ = new address[](2);
        tokens_[0] = tokenA;
        tokens_[1] = tokenB;
        bytes4[] memory types_ = new bytes4[](1);
        types_[0] = bytes4(0xdeadbeef);

        IStandardVault.VaultConfig memory cfg_ = IStandardVault.VaultConfig({
            vaultFeeTypeIds: FEE_IDS,
            contentsId: keccak256(abi.encode(tokens_)),
            vaultTypes: types_,
            tokens: tokens_
        });

        IStandardVaultPkg.VaultPkgDeclaration memory dec_ = IStandardVaultPkg.VaultPkgDeclaration({
            name: "JMgrPkg",
            vaultFeeTypeIds: FEE_IDS,
            vaultTypes: types_
        });

        IVaultRegistryVaultPackageManager pkgMgr_ = IVaultRegistryVaultPackageManager(address(indexedexManager));
        IVaultRegistryVaultPackageQuery pkgQry_ = IVaultRegistryVaultPackageQuery(address(indexedexManager));
        IVaultRegistryVaultManager vaultMgr_ = IVaultRegistryVaultManager(address(indexedexManager));
        IVaultRegistryVaultQuery vaultQry_ = IVaultRegistryVaultQuery(address(indexedexManager));
        IVaultRegistryDisableManager disMgr_ = IVaultRegistryDisableManager(address(indexedexManager));
        IVaultRegistryDisableQuery disQry_ = IVaultRegistryDisableQuery(address(indexedexManager));

        // Package surface via proxy
        vm.prank(owner);
        assertTrue(pkgMgr_.registerPackage(testPkg, dec_), "J3 registerPackage");
        assertTrue(pkgQry_.isPackage(testPkg), "J3 isPackage");
        assertEq(pkgQry_.packageName(testPkg), "JMgrPkg", "J3 packageName");
        assertEq(pkgQry_.packageFeeTypeIds(testPkg), FEE_IDS, "J3 packageFeeTypeIds");

        // Vault surface via proxy
        vm.prank(owner);
        assertTrue(vaultMgr_.registerVault(testVault, testPkg, cfg_), "J3 registerVault");
        assertTrue(vaultQry_.isVault(testVault), "J3 isVault");
        assertEq(vaultQry_.vaultUsageFeeTypeId(testVault), bytes4(0x11111111), "J3 usage type id");
        assertEq(vaultQry_.vaultDexTermsTypeId(testVault), bytes4(0x22222222), "J3 dex type id");
        assertEq(vaultQry_.vaultBondTermsTypeId(testVault), bytes4(0x33333333), "J3 bond type id");
        assertEq(vaultQry_.vaultLendingTermsTypeId(testVault), bytes4(0x55555555), "J3 lending type id");
        assertEq(vaultQry_.vaultsOfPackage(testPkg).length, 1, "J3 vaultsOfPackage");

        // Disable surface via proxy
        assertFalse(disQry_.isDisabled(testVault), "J3 default active");
        vm.prank(owner);
        assertTrue(disMgr_.setVaultAddressDisabled(testVault, true), "J3 setVaultAddressDisabled");
        assertTrue(disQry_.isDisabled(testVault), "J3 vault disabled");
        assertTrue(disQry_.isVaultAddressDisabled(testVault), "J3 isVaultAddressDisabled");
        (bool disabled_, bool byVault_, bool byPackage_) = disQry_.isDisabledDetailed(testVault);
        assertTrue(disabled_ && byVault_ && !byPackage_, "J3 isDisabledDetailed");
        assertEq(disQry_.packageOfVault(testVault), testPkg, "J3 packageOfVault");

        vm.prank(owner);
        assertTrue(disMgr_.setVaultAddressDisabled(testVault, false), "J3 re-enable vault");
        assertFalse(disQry_.isDisabled(testVault), "J3 vault re-enabled");

        vm.prank(owner);
        assertTrue(disMgr_.setPackageDisabled(testPkg, true), "J3 setPackageDisabled");
        assertTrue(disQry_.isDisabled(testVault), "J3 disabled via package");
        assertTrue(disQry_.isPackageDisabled(testPkg), "J3 isPackageDisabled");

        // Loupe routes
        IDiamondLoupe loupe_ = IDiamondLoupe(address(indexedexManager));
        assertEq(
            loupe_.facetAddress(IVaultRegistryVaultManager.registerVault.selector),
            address(vaultRegistryVaultManagerFacet),
            "J3 registerVault loupe"
        );
        assertEq(
            loupe_.facetAddress(IVaultRegistryVaultPackageManager.registerPackage.selector),
            address(vaultRegistryVaultPackageManagerFacet),
            "J3 registerPackage loupe"
        );
        assertEq(
            loupe_.facetAddress(IVaultRegistryDisableManager.setVaultAddressDisabled.selector),
            address(vaultRegistryDisableManagerFacet),
            "J3 setVaultAddressDisabled loupe"
        );
        assertEq(
            loupe_.facetAddress(IVaultRegistryVaultQuery.isVault.selector),
            address(vaultRegistryVaultQueryFacet),
            "J3 isVault loupe"
        );
        assertTrue(
            loupe_.facetAddress(IVaultRegistryVaultManager.registerVault.selector) != address(indexedexManager),
            "J3 not self-facet"
        );
    }

    /// @notice J3: deployment facet selector is loupe-routed; setHook factory is callable on proxy.
    function test_J3_proxySmoke_registry_deployment_setHookFactory() public {
        address hookFactory = makeAddr("hookFactory");
        vm.prank(owner);
        IVaultRegistryDeployment(address(indexedexManager)).setHookDiamondPackageFactory(hookFactory);

        address loupeFacet_ = IDiamondLoupe(address(indexedexManager)).facetAddress(
            IVaultRegistryDeployment.setHookDiamondPackageFactory.selector
        );
        assertEq(loupeFacet_, address(vaultRegistryDeploymentFacet), "J3 setHookFactory loupe");
        assertTrue(loupeFacet_ != address(indexedexManager), "J3 not self-facet");

        // deployVault product fail (pkg not registered) proves selector is cut, not FunctionNotFound
        address fakePkg = makeAddr("fakePkg");
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDeployment.PkgNotRegistered.selector, fakePkg));
        IVaultRegistryDeployment(address(indexedexManager)).deployVault(IStandardVaultPkg(fakePkg), bytes(""));
    }

    /// @notice J facet metadata parity on CREATE3 fee-oracle query facet (non-seigniorage companion).
    function test_J_facetMetadata_query_matches_CREATE3_facet() public view {
        IFacet facet_ = vaultFeeOracleQueryFacet;
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = facet_.facetMetadata();
        assertEq(keccak256(bytes(name_)), keccak256(bytes("VaultFeeOracleQueryFacet")));
        assertTrue(ifaces_.length >= 1, "interfaces");
        assertEq(facet_.facetFuncs().length, funcs_.length, "funcs match metadata");
        assertEq(
            keccak256(abi.encodePacked(funcs_)),
            keccak256(abi.encodePacked(facet_.facetFuncs())),
            "metadata funcs == facetFuncs"
        );
    }

    /// @notice Operable is cut on manager (used by fee oracle onlyOwnerOrOperator).
    function test_J3_proxySmoke_operable_setOperator() public {
        address op_ = makeAddr("operatorJ");
        vm.prank(owner);
        IOperable(address(indexedexManager)).setOperator(op_, true);
        assertTrue(IOperable(address(indexedexManager)).isOperator(op_), "J3 isOperator on proxy");
    }
}
