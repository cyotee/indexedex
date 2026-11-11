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

    function test_adminDeclarationMatchesInterfaceAndCannotBeRestored() public {
        bytes4[] memory expected_ = new bytes4[](6);
        expected_[0] = Allocation.bootstrapMigrationReserve.selector;
        expected_[1] = Allocation.captureMigrationSnapshot.selector;
        expected_[2] = Allocation.configureIndependentAllocations.selector;
        expected_[3] = Allocation.issueIndependentAllocations.selector;
        expected_[4] = Allocation.activateMigration.selector;
        expected_[5] = Allocation.configureNftEntitlements.selector;
        IFacet facet_ = IFacet(IDiamondLoupe(detf).facetAddress(expected_[0]));
        assertTrue(Behavior_IFacet.areValid_IFacet_facetFuncs(facet_, expected_, facet_.facetFuncs()));
        _fundAndCapture();
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
        for (uint256 i_; i_ < expected_.length; ++i_) assertEq(IDiamondLoupe(detf).facetAddress(expected_[i_]), address(0));
    }

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
