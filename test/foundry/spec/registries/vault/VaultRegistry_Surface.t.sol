// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryVaultManager} from "contracts/interfaces/IVaultRegistryVaultManager.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultRegistryVaultPackageManager} from "contracts/interfaces/IVaultRegistryVaultPackageManager.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

/**
 * @title VaultRegistry_Surface_Test
 * @notice WP-J-MGR-002: J1–J3 diamond surface for vault registry facets on the manager proxy.
 * @dev Target ⊆ facetFuncs ⊆ loupe ⊆ proxy (not facet impl alone).
 */
contract VaultRegistry_Surface_Test is IndexedexTest {
    address vault1;
    address pkg1;
    address token0;
    address token1;

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

    IStandardVault.VaultConfig vaultConfig;
    IStandardVaultPkg.VaultPkgDeclaration pkgDec;

    function setUp() public override {
        super.setUp();
        vault1 = makeAddr("vault1");
        pkg1 = makeAddr("pkg1");
        token0 = makeAddr("token0");
        token1 = makeAddr("token1");
        if (uint160(token0) > uint160(token1)) {
            (token0, token1) = (token1, token0);
        }

        address[] memory tokens_ = new address[](2);
        tokens_[0] = token0;
        tokens_[1] = token1;
        bytes4[] memory types_ = new bytes4[](1);
        types_[0] = bytes4(0xdeadbeef);

        vaultConfig = IStandardVault.VaultConfig({
            vaultFeeTypeIds: FEE_IDS,
            contentsId: keccak256(abi.encode(tokens_)),
            vaultTypes: types_,
            tokens: tokens_
        });
        pkgDec = IStandardVaultPkg.VaultPkgDeclaration({
            name: "RegistrySurfacePkg", vaultFeeTypeIds: FEE_IDS, vaultTypes: types_
        });
    }

    function _contains(bytes4[] memory funcs_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < funcs_.length; ++i) {
            if (funcs_[i] == sel_) return true;
        }
        return false;
    }

    function _assertAllOnLoupe(IFacet facet_, address expected_) internal view {
        bytes4[] memory funcs_ = facet_.facetFuncs();
        IDiamondLoupe loupe_ = IDiamondLoupe(address(indexedexManager));
        for (uint256 i; i < funcs_.length; ++i) {
            address loupeFacet_ = loupe_.facetAddress(funcs_[i]);
            assertEq(loupeFacet_, expected_, "J2 loupe facet");
            assertTrue(loupeFacet_ != address(0) && loupeFacet_ != address(indexedexManager), "J2 not self/zero");
        }
    }

    /* ---------------------------------------------------------------------- */
    /*  J1                                                                    */
    /* ---------------------------------------------------------------------- */

    function test_J1_vaultManager_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = vaultRegistryVaultManagerFacet.facetFuncs();
        assertTrue(_contains(funcs_, IVaultRegistryVaultManager.registerVault.selector), "J1 registerVault");
        assertTrue(_contains(funcs_, IVaultRegistryVaultManager.unregisterVault.selector), "J1 unregisterVault");
        assertEq(funcs_.length, 2);
    }

    function test_J1_vaultQuery_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = vaultRegistryVaultQueryFacet.facetFuncs();
        assertTrue(_contains(funcs_, IVaultRegistryVaultQuery.vaults.selector), "J1 vaults");
        assertTrue(_contains(funcs_, IVaultRegistryVaultQuery.isVault.selector), "J1 isVault");
        assertTrue(_contains(funcs_, IVaultRegistryVaultQuery.vaultTokens.selector), "J1 vaultTokens");
        assertTrue(_contains(funcs_, IVaultRegistryVaultQuery.calcContentsId.selector), "J1 calcContentsId");
        assertTrue(
            _contains(funcs_, IVaultRegistryVaultQuery.vaultSeigniorageTermsTypeId.selector),
            "J1 vaultSeigniorageTermsTypeId"
        );
        assertTrue(
            _contains(funcs_, IVaultRegistryVaultQuery.vaultLendingTermsTypeId.selector), "J1 vaultLendingTermsTypeId"
        );
        assertEq(funcs_.length, 22);
    }

    function test_J1_packageManager_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = vaultRegistryVaultPackageManagerFacet.facetFuncs();
        assertTrue(_contains(funcs_, IVaultRegistryVaultPackageManager.registerPackage.selector), "J1 registerPackage");
        assertTrue(
            _contains(funcs_, IVaultRegistryVaultPackageManager.unregisterPackage.selector), "J1 unregisterPackage"
        );
        assertEq(funcs_.length, 2);
    }

    function test_J1_packageQuery_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = vaultRegistryVaultPackageQueryFacet.facetFuncs();
        assertTrue(_contains(funcs_, IVaultRegistryVaultPackageQuery.vaultPackages.selector), "J1 vaultPackages");
        assertTrue(_contains(funcs_, IVaultRegistryVaultPackageQuery.isPackage.selector), "J1 isPackage");
        assertTrue(_contains(funcs_, IVaultRegistryVaultPackageQuery.packageName.selector), "J1 packageName");
        assertTrue(
            _contains(funcs_, IVaultRegistryVaultPackageQuery.vaultLendingFeeTypeIds.selector),
            "J1 vaultLendingFeeTypeIds"
        );
        assertEq(funcs_.length, 10);
    }

    function test_J1_disable_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory m_ = vaultRegistryDisableManagerFacet.facetFuncs();
        assertTrue(
            _contains(m_, IVaultRegistryDisableManager.setVaultAddressDisabled.selector), "J1 setVaultAddressDisabled"
        );
        assertTrue(_contains(m_, IVaultRegistryDisableManager.setPackageDisabled.selector), "J1 setPackageDisabled");

        bytes4[] memory q_ = vaultRegistryDisableQueryFacet.facetFuncs();
        assertTrue(_contains(q_, IVaultRegistryDisableQuery.isDisabled.selector), "J1 isDisabled");
        assertTrue(_contains(q_, IVaultRegistryDisableQuery.disabledVaults.selector), "J1 disabledVaults");
        assertTrue(_contains(q_, IVaultRegistryDisableQuery.disabledPackages.selector), "J1 disabledPackages");
        assertEq(m_.length, 2);
        assertEq(q_.length, 7);
    }

    function test_J1_deployment_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = vaultRegistryDeploymentFacet.facetFuncs();
        assertTrue(_contains(funcs_, IVaultRegistryDeployment.deployPkg.selector), "J1 deployPkg");
        assertTrue(_contains(funcs_, IVaultRegistryDeployment.deployVault.selector), "J1 deployVault");
        assertTrue(_contains(funcs_, IVaultRegistryDeployment.deployHookVault.selector), "J1 deployHookVault");
        assertTrue(
            _contains(funcs_, IVaultRegistryDeployment.deployHookVaultAutoMine.selector), "J1 deployHookVaultAutoMine"
        );
        assertTrue(
            _contains(funcs_, IVaultRegistryDeployment.setHookDiamondPackageFactory.selector),
            "J1 setHookDiamondPackageFactory"
        );
        assertEq(funcs_.length, 5);
    }

    /* ---------------------------------------------------------------------- */
    /*  J2                                                                    */
    /* ---------------------------------------------------------------------- */

    function test_J2_vaultManager_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertAllOnLoupe(vaultRegistryVaultManagerFacet, address(vaultRegistryVaultManagerFacet));
    }

    function test_J2_vaultQuery_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertAllOnLoupe(vaultRegistryVaultQueryFacet, address(vaultRegistryVaultQueryFacet));
    }

    function test_J2_packageManager_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertAllOnLoupe(vaultRegistryVaultPackageManagerFacet, address(vaultRegistryVaultPackageManagerFacet));
    }

    function test_J2_packageQuery_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertAllOnLoupe(vaultRegistryVaultPackageQueryFacet, address(vaultRegistryVaultPackageQueryFacet));
    }

    function test_J2_disableManager_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertAllOnLoupe(vaultRegistryDisableManagerFacet, address(vaultRegistryDisableManagerFacet));
    }

    function test_J2_disableQuery_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertAllOnLoupe(vaultRegistryDisableQueryFacet, address(vaultRegistryDisableQueryFacet));
    }

    function test_J2_deployment_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertAllOnLoupe(vaultRegistryDeploymentFacet, address(vaultRegistryDeploymentFacet));
    }

    /* ---------------------------------------------------------------------- */
    /*  J3                                                                    */
    /* ---------------------------------------------------------------------- */

    /// @notice J3: register package + vault + fee type ids + disable via production proxy.
    function test_J3_proxySmoke_registerQueryDisable() public {
        IVaultRegistryVaultPackageManager pkgMgr_ = IVaultRegistryVaultPackageManager(address(indexedexManager));
        IVaultRegistryVaultPackageQuery pkgQry_ = IVaultRegistryVaultPackageQuery(address(indexedexManager));
        IVaultRegistryVaultManager vaultMgr_ = IVaultRegistryVaultManager(address(indexedexManager));
        IVaultRegistryVaultQuery vaultQry_ = IVaultRegistryVaultQuery(address(indexedexManager));
        IVaultRegistryDisableManager disMgr_ = IVaultRegistryDisableManager(address(indexedexManager));
        IVaultRegistryDisableQuery disQry_ = IVaultRegistryDisableQuery(address(indexedexManager));

        vm.prank(owner);
        assertTrue(pkgMgr_.registerPackage(pkg1, pkgDec), "J3 registerPackage");
        assertTrue(pkgQry_.isPackage(pkg1), "J3 isPackage");
        assertEq(pkgQry_.packageName(pkg1), "RegistrySurfacePkg", "J3 packageName");
        assertEq(pkgQry_.vaultPackages().length, 1, "J3 vaultPackages");

        vm.prank(owner);
        assertTrue(vaultMgr_.registerVault(vault1, pkg1, vaultConfig), "J3 registerVault");
        assertTrue(vaultQry_.isVault(vault1), "J3 isVault");
        assertEq(vaultQry_.vaults().length, 1, "J3 vaults");
        assertTrue(vaultQry_.isContainedToken(token0), "J3 isContainedToken");
        assertEq(vaultQry_.vaultsOfToken(token0).length, 1, "J3 vaultsOfToken");
        assertEq(vaultQry_.vaultUsageFeeTypeId(vault1), bytes4(0x11111111), "J3 usage fee type");
        assertEq(vaultQry_.vaultSeigniorageTermsTypeId(vault1), bytes4(0x44444444), "J3 seigniorage type");
        assertEq(vaultQry_.vaultLendingTermsTypeId(vault1), bytes4(0x55555555), "J3 lending type");
        assertEq(
            vaultQry_.calcContentsId(vaultConfig.tokens), vaultConfig.contentsId, "J3 calcContentsId pure on proxy"
        );

        assertFalse(disQry_.isDisabled(vault1), "J3 active default");
        vm.prank(owner);
        assertTrue(disMgr_.setPackageDisabled(pkg1, true), "J3 setPackageDisabled");
        assertTrue(disQry_.isDisabled(vault1), "J3 disabled by package");
        assertEq(disQry_.disabledPackages().length, 1, "J3 disabledPackages");

        // Loupe
        IDiamondLoupe loupe_ = IDiamondLoupe(address(indexedexManager));
        assertEq(
            loupe_.facetAddress(IVaultRegistryVaultQuery.vaults.selector),
            address(vaultRegistryVaultQueryFacet),
            "J3 vaults loupe"
        );
        assertEq(
            loupe_.facetAddress(IVaultRegistryDisableManager.setPackageDisabled.selector),
            address(vaultRegistryDisableManagerFacet),
            "J3 setPackageDisabled loupe"
        );
        assertTrue(
            loupe_.facetAddress(IVaultRegistryVaultManager.registerVault.selector) != address(indexedexManager),
            "J3 not self"
        );
    }

    /// @notice J3: deployVault product fail proves selector cut (PkgNotRegistered, not FunctionNotFound).
    function test_J3_proxySmoke_deployVault_pkgNotRegistered() public {
        address fakePkg = makeAddr("unregisteredPkg");
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDeployment.PkgNotRegistered.selector, fakePkg));
        IVaultRegistryDeployment(address(indexedexManager)).deployVault(IStandardVaultPkg(fakePkg), bytes(""));

        address loupe_ = IDiamondLoupe(address(indexedexManager)).facetAddress(
            IVaultRegistryDeployment.deployVault.selector
        );
        assertEq(loupe_, address(vaultRegistryDeploymentFacet), "J3 deployVault loupe");
    }

    /// @notice J facet metadata parity for vault query CREATE3 facet.
    function test_J_facetMetadata_vaultQuery_matches_CREATE3_facet() public view {
        IFacet facet_ = vaultRegistryVaultQueryFacet;
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = facet_.facetMetadata();
        assertEq(keccak256(bytes(name_)), keccak256(bytes("VaultRegistryVaultQueryFacet")));
        assertTrue(ifaces_.length >= 1, "interfaces");
        assertEq(facet_.facetFuncs().length, funcs_.length, "funcs match metadata");
        assertEq(
            keccak256(abi.encodePacked(funcs_)),
            keccak256(abi.encodePacked(facet_.facetFuncs())),
            "metadata funcs == facetFuncs"
        );
    }
}
