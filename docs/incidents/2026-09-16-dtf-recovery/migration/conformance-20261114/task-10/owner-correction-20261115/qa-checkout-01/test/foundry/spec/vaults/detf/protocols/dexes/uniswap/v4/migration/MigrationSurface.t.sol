// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IERC721Metadata} from "@crane/contracts/interfaces/IERC721Metadata.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {Behavior_IFacet} from "@crane/contracts/factories/diamondPkg/Behavior_IFacet.sol";
import {Base64} from "@crane/contracts/utils/Base64.sol";
import {LibString} from "@crane/contracts/utils/LibString.sol";
import {TestBase_UniswapV4DetfMigration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation}
    from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationStakedDETF as MigrationReceipt}
    from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/claimToken/IUniswapV4DetfMigrationStakedDETF.sol";

contract MigrationSurfaceTest is TestBase_UniswapV4DetfMigration {
    /// @notice Catches Migration administration leaking into the ordinary registry package or shared storage.
    function test_ordinaryRegistryPackageCannotAcquireMigrationAuthority() public {
        _fundAndCapture();
        _configure(address(this), 1 ether, bytes32("migration-only-original"));
        bytes memory before_ = abi.encode(migration.migrationWeightedPricing(),
            migration.independentAllocation(address(this)), IERC20(detf).totalSupply(), receipt.stakingState());
        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployDetfPkg();
        address ordinary_ = _deployWeightedHookThenDetf(_nLegDetfArgs(2));
        assertNotEq(ordinary_, detf);
        assertFalse(IERC165(ordinary_).supportsInterface(type(Allocation).interfaceId));
        assertEq(IDiamondLoupe(ordinary_).facetAddress(Allocation.setMigrationWeightedPricing.selector), address(0));
        assertEq(IDiamondLoupe(ordinary_).facetAddress(Allocation.issueIndependentAllocations.selector), address(0));
        assertEq(IDiamondLoupe(ordinary_).facetAddress(Migration.surrenderMigrationNft.selector), address(0));
        (bool ok_, bytes memory reason_) = ordinary_.call(
            abi.encodeCall(Allocation.setMigrationWeightedPricing, (_manualInputs())));
        assertFalse(ok_);
        assertEq(reason_, abi.encodeWithSignature("NoTargetFor(bytes4)", Allocation.setMigrationWeightedPricing.selector));
        assertEq(abi.encode(migration.migrationWeightedPricing(), migration.independentAllocation(address(this)),
            IERC20(detf).totalSupply(), receipt.stakingState()), before_, "ordinary deployment cannot mutate Migration");
    }

    /// @notice J2: catches a declared package selector missing or routed to a different deployed facet.
    function test_allPackageCutsReachRealProxyAndFitEip170() public {
        IDiamond.FacetCut[] memory cuts_ = migrationPkg.facetCuts();
        for (uint256 i_; i_ < cuts_.length; ++i_) {
            assertLe(cuts_[i_].facetAddress.code.length, 24576);
            assertTrue(Behavior_IFacet.isValid_IFacet_facetMetadata_consistency(IFacet(cuts_[i_].facetAddress)));
            for (uint256 j_; j_ < cuts_[i_].functionSelectors.length; ++j_) {
                assertEq(IDiamondLoupe(detf).facetAddress(cuts_[i_].functionSelectors[j_]), cuts_[i_].facetAddress);
            }
        }
        address[5] memory children_ = [address(bonds), address(receipt), address(rawSy), address(stakingSy),
            migration.migrationSyRewardToken()];
        for (uint256 i_; i_ < children_.length; ++i_) {
            IDiamondLoupe.Facet[] memory facets_ = IDiamondLoupe(children_[i_]).facets();
            for (uint256 j_; j_ < facets_.length; ++j_) assertLe(facets_[j_].facetAddress.code.length, 24576);
            assertEq(IDiamondLoupe(children_[i_]).facetAddress(IDiamondFactoryPackage.initAccount.selector), address(0));
            assertEq(IDiamondLoupe(children_[i_]).facetAddress(IPostDeployAccountHook.postDeploy.selector), address(0));
        }
        assertLe(address(migrationPkg).code.length, 24576);
    }

    /// @notice J1/J3: catches missing interface declarations and any administration route surviving the cut.
    function test_adminDeclarationMatchesInterfaceAndCannotBeRestored() public {
        bytes4[] memory expected_ = new bytes4[](8);
        expected_[0] = Allocation.bootstrapMigrationReserve.selector;
        expected_[1] = Allocation.setMigrationWeightedPricing.selector;
        expected_[2] = Allocation.configureIndependentAllocations.selector;
        expected_[3] = Allocation.issueIndependentAllocations.selector;
        expected_[4] = Allocation.activateMigration.selector;
        expected_[5] = Allocation.configureWeightedSyEntitlements.selector;
        expected_[6] = Allocation.configureDtfCustodySeEntitlements.selector;
        expected_[7] = Allocation.configureClaimedSyEntitlements.selector;
        IFacet facet_ = IFacet(IDiamondLoupe(detf).facetAddress(expected_[0]));
        assertTrue(Behavior_IFacet.areValid_IFacet_facetFuncs(facet_, expected_, facet_.facetFuncs()));
        IFacet direct_ = IFacet(IDiamondLoupe(detf).facetAddress(Allocation.configureClaimVaultEntitlements.selector));
        bytes4[] memory directSelectors_ = new bytes4[](8);
        directSelectors_[0] = Allocation.configureClaimVaultEntitlements.selector;
        directSelectors_[1] = Allocation.configureWeightedReceiptEntitlements.selector;
        directSelectors_[2] = Allocation.configureEarlierReceiptEntitlements.selector;
        directSelectors_[3] = Allocation.configureWeightedLiquidEntitlements.selector;
        directSelectors_[4] = Allocation.configureEarlierLiquidEntitlements.selector;
        directSelectors_[5] = Allocation.configureHeldSeLpEntitlements.selector;
        directSelectors_[6] = Allocation.configureNftEntitlements.selector;
        directSelectors_[7] = Allocation.configureNftContributionEntitlements.selector;
        assertTrue(Behavior_IFacet.areValid_IFacet_facetFuncs(direct_, directSelectors_, direct_.facetFuncs()));
        _fundAndCapture();
        _buyOwnerFirstBond();
        vm.prank(migrationOwner);
        allocation.activateMigration();
        (bool init_,) = detf.call(abi.encodeCall(IDiamondFactoryPackage.initAccount, (bytes(""))));
        (bool post_,) = detf.call(abi.encodeCall(IPostDeployAccountHook.postDeploy, ()));
        (bool update_,) = detf.call(abi.encodeCall(IDiamondFactoryPackage.updatePkg, (detf, bytes(""))));
        assertFalse(init_); assertFalse(post_); assertFalse(update_);
        (bool packageUpdate_,) = address(migrationPkg).call(abi.encodeCall(
            IDiamondFactoryPackage.updatePkg, (detf, abi.encode(_migrationArgs(migrationOwner)))
        ));
        assertFalse(packageUpdate_);
        assertFalse(IERC165(detf).supportsInterface(type(Allocation).interfaceId));
        for (uint256 i_; i_ < expected_.length; ++i_) _assertRemoved(expected_[i_]);
        for (uint256 i_; i_ < directSelectors_.length; ++i_) _assertRemoved(directSelectors_[i_]);
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureClaimVaultEntitlements.selector), address(0));
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureWeightedReceiptEntitlements.selector), address(0));
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureEarlierReceiptEntitlements.selector), address(0));
        assertEq(IDiamondLoupe(detf).facetAddress(Allocation.configureHeldSeLpEntitlements.selector), address(0));
    }

    function _assertRemoved(bytes4 selector_) private {
        assertEq(IDiamondLoupe(detf).facetAddress(selector_), address(0));
        (bool ok_, bytes memory reason_) = detf.call(abi.encodeWithSelector(selector_));
        assertFalse(ok_);
        assertEq(reason_, abi.encodeWithSignature("NoTargetFor(bytes4)", selector_));
    }

    /// @notice Catches metadata showing linear principal release on a compensation cliff.
    function test_realTokenUriNumericCliffBoundaries() public {
        _fundAndCapture();
        _configure(address(this), 1 ether, bytes32("metadata"));
        uint256 id_ = _issue(address(this));
        uint256 start_ = block.timestamp;
        string memory json_ = _json(id_);
        assertEq(vm.parseJsonUint(json_, ".attributes[11].value"), start_);
        assertEq(vm.parseJsonUint(json_, ".attributes[12].value"), start_ + 90 days);
        assertEq(vm.parseJsonUint(json_, ".attributes[13].value"), 90 days);
        assertEq(vm.parseJsonUint(json_, ".attributes[14].value"), 0);
        vm.warp(start_ + 90 days - 1);
        assertEq(vm.parseJsonUint(_json(id_), ".attributes[14].value"), 0);
        vm.warp(start_ + 90 days);
        assertEq(vm.parseJsonUint(_json(id_), ".attributes[14].value"), 10000);
        vm.warp(start_ + 90 days + 1);
        assertEq(vm.parseJsonUint(_json(id_), ".attributes[14].value"), 10000);
    }

    /// @notice Catches an arbitrary caller using stale child index arguments to manufacture backing.
    function test_wrongCustodyCallerCannotUseStaleIndexOrCreateBacking() public {
        _fundAndCapture();
        uint256 k_ = receipt.stakingState().gonsPerUnit;
        bytes[] memory calls_ = new bytes[](6);
        calls_[0] = abi.encodeCall(MigrationReceipt.deliverBondClaim, (address(this), 1, 0, k_ - 1));
        calls_[1] = abi.encodeCall(MigrationReceipt.deferSyRewards, (address(this), 1, k_ - 1));
        calls_[2] = abi.encodeCall(MigrationReceipt.transferSyPrincipal, (address(this), 1, k_ - 1));
        calls_[3] = abi.encodeCall(MigrationReceipt.withdrawSyPrincipal, (address(this), 1, k_ - 1));
        calls_[4] = abi.encodeCall(MigrationReceipt.issueSyRewardTokens, (address(this), k_ - 1));
        calls_[5] = abi.encodeCall(MigrationReceipt.paySyRewardRemainder, (address(this), k_ - 1));
        for (uint256 i_; i_ < calls_.length; ++i_) {
            (bool ok_, bytes memory reason_) = address(receipt).call(calls_[i_]);
            assertFalse(ok_);
            assertEq(bytes4(reason_), bytes4(keccak256("Unauthorized(address)")));
            assertEq(receipt.stakingState().totalGons, 0);
            assertEq(IERC20(detf).balanceOf(address(receipt)), 0);
        }
    }

    function _json(uint256 id_) private view returns (string memory) {
        string memory uri_ = IERC721Metadata(address(bonds)).tokenURI(id_);
        return string(Base64.decode(LibString.slice(uri_, bytes("data:application/json;base64,").length)));
    }
}
