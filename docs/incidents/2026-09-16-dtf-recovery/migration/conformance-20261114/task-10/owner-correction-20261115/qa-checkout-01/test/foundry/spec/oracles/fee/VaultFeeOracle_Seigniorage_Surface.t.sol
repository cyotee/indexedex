// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultRegistryVaultManager} from "contracts/interfaces/IVaultRegistryVaultManager.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";

/**
 * @title VaultFeeOracle_Seigniorage_Surface_Test
 * @notice WP-J-MGR-001: J1–J3 diamond surface for manager seigniorage APIs on the production proxy.
 * @dev Guards silent-missing API: Target ⊆ facetFuncs ⊆ loupe ⊆ proxy call (not facet impl alone).
 *      Covers fee-oracle seigniorage manager/query selectors and vault registry seigniorage type-id query
 *      (formerly typo'd `seeigniorageTermsTypeId` and omitted from interface/facetFuncs).
 */
contract VaultFeeOracle_Seigniorage_Surface_Test is IndexedexTest {
    address testVault;
    address testPkg;
    bytes4 testTypeId;

    // Packed fee type ids: usage, dex, bond, seigniorage, lending (see VaultTypeUtils).
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

    /* ---------------------------------------------------------------------- */
    /*  J1: Target/product seigniorage selectors ⊆ facetFuncs                 */
    /* ---------------------------------------------------------------------- */

    /// @notice J1: fee-oracle manager seigniorage setters are cut into facetFuncs.
    function test_J1_managerSeigniorage_selectors_in_facetFuncs() public view {
        bytes4[] memory funcs_ = vaultFeeOracleManagerFacet.facetFuncs();
        assertTrue(
            _contains(funcs_, IVaultFeeOracleManager.setDefaultSeigniorageIncentivePercentage.selector),
            "J1 setDefaultSeigniorageIncentivePercentage"
        );
        assertTrue(
            _contains(funcs_, IVaultFeeOracleManager.setDefaultSeigniorageIncentivePercentageOfTypeId.selector),
            "J1 setDefaultSeigniorageIncentivePercentageOfTypeId"
        );
        assertTrue(
            _contains(funcs_, IVaultFeeOracleManager.setSeigniorageIncentivePercentageOfVault.selector),
            "J1 setSeigniorageIncentivePercentageOfVault"
        );
        assertTrue(
            _contains(funcs_, IVaultFeeOracleManager.setDefaultSeignioragePotShares.selector),
            "J1 setDefaultSeignioragePotShares"
        );
        assertTrue(
            _contains(funcs_, IVaultFeeOracleManager.setSeignioragePotSharesOfVault.selector),
            "J1 setSeignioragePotSharesOfVault"
        );
    }

    /// @notice J1: fee-oracle query seigniorage getters are cut into facetFuncs.
    function test_J1_querySeigniorage_selectors_in_facetFuncs() public view {
        bytes4[] memory funcs_ = vaultFeeOracleQueryFacet.facetFuncs();
        assertTrue(
            _contains(funcs_, IVaultFeeOracleQuery.seigniorageVaultTypeIds.selector), "J1 seigniorageVaultTypeIds"
        );
        assertTrue(
            _contains(funcs_, IVaultFeeOracleQuery.defaultSeigniorageIncentivePercentage.selector),
            "J1 defaultSeigniorageIncentivePercentage"
        );
        assertTrue(
            _contains(funcs_, IVaultFeeOracleQuery.seigniorageIncentivePercentageOfTypeId.selector),
            "J1 seigniorageIncentivePercentageOfTypeId"
        );
        assertTrue(
            _contains(funcs_, IVaultFeeOracleQuery.seigniorageIncentivePercentageOfVault.selector),
            "J1 seigniorageIncentivePercentageOfVault"
        );
        assertTrue(
            _contains(funcs_, IVaultFeeOracleQuery.seigniorageIncentivePercentageOfVaultAndFeeTo.selector),
            "J1 seigniorageIncentivePercentageOfVaultAndFeeTo"
        );
        assertTrue(
            _contains(funcs_, IVaultFeeOracleQuery.defaultSeigniorageFeeToSharePercentage.selector),
            "J1 defaultSeigniorageFeeToSharePercentage"
        );
        assertTrue(
            _contains(funcs_, IVaultFeeOracleQuery.seigniorageSplitOfVault.selector), "J1 seigniorageSplitOfVault"
        );
        assertTrue(
            _contains(funcs_, IVaultFeeOracleQuery.bondTermsAndSeigniorageOfVault.selector),
            "J1 bondTermsAndSeigniorageOfVault"
        );
    }

    /// @notice J1: registry seigniorage terms type-id (ex-typo seeigniorageTermsTypeId) is cut.
    function test_J1_vaultSeigniorageTermsTypeId_in_facetFuncs() public view {
        bytes4[] memory funcs_ = vaultRegistryVaultQueryFacet.facetFuncs();
        assertTrue(
            _contains(funcs_, IVaultRegistryVaultQuery.vaultSeigniorageTermsTypeId.selector),
            "J1 vaultSeigniorageTermsTypeId in facetFuncs"
        );
        // Spelling guard: double-e typo must not be the cut selector.
        bytes4 typoSel_ = bytes4(keccak256("seeigniorageTermsTypeId(address)"));
        assertFalse(_contains(funcs_, typoSel_), "J1 typo selector must not be cut");
    }

    /* ---------------------------------------------------------------------- */
    /*  J2: facetFuncs ⊆ loupe on production manager proxy                    */
    /* ---------------------------------------------------------------------- */

    /// @notice J2: manager seigniorage selectors map to CREATE3 manager facet via loupe.
    function test_J2_managerSeigniorage_facetFuncs_subseteq_loupe_onProxy() public view {
        bytes4[3] memory sels_ = [
            IVaultFeeOracleManager.setDefaultSeigniorageIncentivePercentage.selector,
            IVaultFeeOracleManager.setDefaultSeigniorageIncentivePercentageOfTypeId.selector,
            IVaultFeeOracleManager.setSeigniorageIncentivePercentageOfVault.selector
        ];
        IDiamondLoupe loupe_ = IDiamondLoupe(address(indexedexManager));
        for (uint256 i; i < sels_.length; ++i) {
            address loupeFacet_ = loupe_.facetAddress(sels_[i]);
            assertEq(loupeFacet_, address(vaultFeeOracleManagerFacet), "J2 manager seigniorage loupe facet");
            assertTrue(loupeFacet_ != address(0) && loupeFacet_ != address(indexedexManager), "J2 not self/zero");
        }
    }

    /// @notice J2: query seigniorage selectors map to CREATE3 query facet via loupe.
    function test_J2_querySeigniorage_facetFuncs_subseteq_loupe_onProxy() public view {
        bytes4[5] memory sels_ = [
            IVaultFeeOracleQuery.seigniorageVaultTypeIds.selector,
            IVaultFeeOracleQuery.defaultSeigniorageIncentivePercentage.selector,
            IVaultFeeOracleQuery.seigniorageIncentivePercentageOfTypeId.selector,
            IVaultFeeOracleQuery.seigniorageIncentivePercentageOfVault.selector,
            IVaultFeeOracleQuery.seigniorageIncentivePercentageOfVaultAndFeeTo.selector
        ];
        IDiamondLoupe loupe_ = IDiamondLoupe(address(indexedexManager));
        for (uint256 i; i < sels_.length; ++i) {
            address loupeFacet_ = loupe_.facetAddress(sels_[i]);
            assertEq(loupeFacet_, address(vaultFeeOracleQueryFacet), "J2 query seigniorage loupe facet");
        }
    }

    /// @notice J2: vaultSeigniorageTermsTypeId is registered on the production proxy loupe.
    function test_J2_vaultSeigniorageTermsTypeId_loupe_onProxy() public view {
        address loupeFacet_ = IDiamondLoupe(address(indexedexManager)).facetAddress(
            IVaultRegistryVaultQuery.vaultSeigniorageTermsTypeId.selector
        );
        assertEq(loupeFacet_, address(vaultRegistryVaultQueryFacet), "J2 registry seigniorage loupe facet");
        assertTrue(loupeFacet_ != address(0), "J2 facet set");
        assertTrue(loupeFacet_ != address(indexedexManager), "J2 not self-facet");
    }

    /* ---------------------------------------------------------------------- */
    /*  J3: proxy smoke — loupe-routed seigniorage calls (not facet impl)     */
    /* ---------------------------------------------------------------------- */

    /// @notice J3: seigniorage manager + query execute on the manager proxy diamond.
    function test_J3_proxySmoke_seigniorageManagerAndQuery() public {
        IVaultFeeOracleManager mgr_ = IVaultFeeOracleManager(address(indexedexManager));
        IVaultFeeOracleQuery qry_ = IVaultFeeOracleQuery(address(indexedexManager));

        // View surface via proxy (default seeded in IndexedexManagerDFPkg).
        uint256 before_ = qry_.defaultSeigniorageIncentivePercentage();
        assertTrue(before_ > 0, "J3 default seigniorage seeded");

        // Mutating surface via proxy.
        vm.prank(owner);
        bool ok_ = mgr_.setDefaultSeigniorageIncentivePercentage(1e17);
        assertTrue(ok_, "J3 setDefault ok");
        assertEq(qry_.defaultSeigniorageIncentivePercentage(), 1e17, "J3 readback default");

        vm.prank(owner);
        ok_ = mgr_.setDefaultSeigniorageIncentivePercentageOfTypeId(testTypeId, 2e17);
        assertTrue(ok_, "J3 setOfTypeId ok");
        assertEq(qry_.seigniorageIncentivePercentageOfTypeId(testTypeId), 2e17, "J3 readback type");

        vm.prank(owner);
        ok_ = mgr_.setSeigniorageIncentivePercentageOfVault(testVault, 3e17);
        assertTrue(ok_, "J3 setOfVault ok");
        assertEq(qry_.seigniorageIncentivePercentageOfVault(testVault), 3e17, "J3 readback vault");

        // Loupe: seigniorage selector routes to CREATE3 facet, not proxy self.
        address loupeFacet_ = IDiamondLoupe(address(indexedexManager)).facetAddress(
            IVaultFeeOracleManager.setDefaultSeigniorageIncentivePercentage.selector
        );
        assertEq(loupeFacet_, address(vaultFeeOracleManagerFacet), "J3 setDefault loupe");
        assertTrue(loupeFacet_ != address(indexedexManager), "J3 not self-facet");
    }

    /// @notice J3: vaultSeigniorageTermsTypeId callable on proxy after register (not facet impl).
    function test_J3_proxySmoke_vaultSeigniorageTermsTypeId() public {
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

        vm.prank(owner);
        IVaultRegistryVaultManager(address(indexedexManager)).registerVault(testVault, testPkg, cfg_);

        IVaultRegistryVaultQuery qry_ = IVaultRegistryVaultQuery(address(indexedexManager));
        // 4th packed bytes4 is seigniorage (0x44444444).
        assertEq(qry_.vaultSeigniorageTermsTypeId(testVault), bytes4(0x44444444), "J3 seigniorage type id on proxy");
        assertEq(qry_.vaultUsageFeeTypeId(testVault), bytes4(0x11111111), "J3 usage sibling");
        assertEq(qry_.vaultBondTermsTypeId(testVault), bytes4(0x33333333), "J3 bond sibling");

        address loupeFacet_ = IDiamondLoupe(address(indexedexManager)).facetAddress(
            IVaultRegistryVaultQuery.vaultSeigniorageTermsTypeId.selector
        );
        assertEq(loupeFacet_, address(vaultRegistryVaultQueryFacet), "J3 registry seigniorage loupe");
        assertTrue(loupeFacet_ != address(indexedexManager), "J3 not self-facet");
    }

    /// @notice J facet metadata parity on CREATE3 fee-oracle manager facet.
    function test_J_facetMetadata_manager_matches_CREATE3_facet() public view {
        IFacet facet_ = vaultFeeOracleManagerFacet;
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = facet_.facetMetadata();
        assertEq(keccak256(bytes(name_)), keccak256(bytes("VaultFeeOracleManagerFacet")));
        assertTrue(ifaces_.length >= 1, "interfaces");
        assertEq(facet_.facetFuncs().length, funcs_.length, "funcs match metadata");
        assertEq(
            keccak256(abi.encodePacked(funcs_)),
            keccak256(abi.encodePacked(facet_.facetFuncs())),
            "metadata funcs == facetFuncs"
        );
    }
}
