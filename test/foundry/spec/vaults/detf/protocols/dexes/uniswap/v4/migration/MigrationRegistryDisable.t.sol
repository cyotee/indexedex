// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {TestBase_UniswapV4DetfMigration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationAccounting as Accounting} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationSY as SY} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/IUniswapV4DetfMigrationSY.sol";

/// @notice Registry disable closes new capital while preserving mature principal, activated rewards and exits.
contract MigrationRegistryDisableTest is TestBase_UniswapV4DetfMigration {
    uint256 private principal;
    uint256 private bondId;
    address private receiver = address(0xBEEF);

    function setUp() public override {
        super.setUp();
        _fundAndCapture();
        _buyOwnerFirstBond();
        principal = _configure(address(this), 1 ether, bytes32("disabled-original"));
        bondId = _issue(address(this));
        IERC20[] memory tokens_ = new IERC20[](2);
        tokens_[0] = IERC20(pairA);
        tokens_[1] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 50 ether;
        amounts_[1] = 50 ether;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 1, block.timestamp);
        vm.warp(block.timestamp + 90 days);
        migration.synchronizeRewards();
        assertGt(bonds.previewClaim(bondId).rewardsDue, 0, "funded rewards exist before disable");
    }

    function test_addressDisablePreservesMatureClaimsAndAllWrapperExits() public {
        _checkDisabledLifecycle(false);
    }

    function test_packageDisablePreservesMatureClaimsAndAllWrapperExits() public {
        _checkDisabledLifecycle(true);
    }

    function _setDisabled(bool package_, bool disabled_) private {
        vm.prank(owner);
        if (package_) {
            IVaultRegistryDisableManager(address(indexedexManager)).setPackageDisabled(address(migrationPkg), disabled_);
        } else {
            IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(detf, disabled_);
        }
        assertEq(IVaultRegistryDisableQuery(address(indexedexManager)).isDisabled(detf), disabled_);
    }

    function _checkDisabledLifecycle(bool package_) private {
        _setDisabled(package_, true);
        vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
        bonds.claimRewards(bondId, address(this));
        uint256 before_ = receipt.balanceOf(address(this));
        assertEq(bonds.claimPrincipal(bondId, address(this)), principal, "mature Stage 1 principal remains payable");
        assertEq(receipt.balanceOf(address(this)) - before_, principal);
        vm.prank(migrationOwner);
        allocation.activateMigration();
        uint256 rewards_ = bonds.previewClaim(bondId).rewardsDue;
        before_ = receipt.balanceOf(address(this));
        assertEq(bonds.claimRewards(bondId, address(this)), rewards_);
        assertEq(receipt.balanceOf(address(this)) - before_, rewards_, "disabled parent does not trap activated rewards");
        assertTrue(IVaultRegistryDisableQuery(address(indexedexManager)).isDisabled(detf));
        _assertNewCapitalRejected();

        uint256 packet_ = principal / 4;
        receipt.approve(address(stakingSy), packet_);
        assertEq(stakingSy.deposit(address(this), address(receipt), packet_, packet_), packet_);
        receipt.exchangeIn(IERC20(address(receipt)), packet_, IERC20(detf), packet_, address(this), false, block.timestamp);
        IERC20(detf).approve(address(rawSy), packet_);
        assertEq(rawSy.deposit(address(this), detf, packet_, packet_), packet_);
        _allExitRoutes(stakingSy, packet_);
        _allExitRoutes(rawSy, packet_);

        before_ = IERC20(detf).balanceOf(receiver);
        (uint256 paid_,) = receipt.exchangeIn(
            IERC20(address(receipt)), packet_, IERC20(detf), packet_, receiver, false, block.timestamp);
        assertEq(paid_, packet_);
        assertEq(IERC20(detf).balanceOf(receiver) - before_, paid_, "receipt DETF exit settles exactly");
        IStakedDETF.StakingState memory state_ = receipt.stakingState();
        assertEq(state_.accountedBacking,
            state_.totalGons / state_.gonsPerUnit + state_.allocationDust + state_.stakingDust);
        assertGe(IERC20(detf).balanceOf(address(receipt)), state_.accountedBacking);
        assertGe(receipt.gonsOf(address(stakingSy)), stakingSy.attributedSyGons());

        _setDisabled(package_, false);
        (uint256 nextId_, uint256 lp_) =
            migration.bond(IERC20(pairA), 1 ether, 90 days, address(this), false, block.timestamp);
        assertGt(lp_, 0, "re-enabled ordinary purchase funds reserve liquidity");
        assertGt(bonds.positionOf(nextId_).principal, 0);
    }

    function _assertNewCapitalRejected() private {
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 payment_ = IERC20(pairA).balanceOf(address(this));
        bytes memory reason_ = abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, detf);
        IERC20(pairA).approve(detf, 1 ether);
        vm.expectRevert(reason_);
        migration.bond(IERC20(pairA), 1 ether, 90 days, address(this), false, block.timestamp);
        vm.expectRevert(reason_);
        IStandardExchangeIn(detf).exchangeIn(IERC20(pairA), 1 ether, IERC20(detf), 1, address(this), false, block.timestamp);
        IERC20[] memory tokens_ = new IERC20[](1);
        tokens_[0] = IERC20(pairA);
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = 1 ether;
        vm.expectRevert(reason_);
        migration.donateMigrationCapital(tokens_, amounts_, 0, 1, block.timestamp);
        IERC20(pairA).approve(address(rawSy), 1 ether);
        vm.expectRevert(reason_);
        rawSy.deposit(address(this), pairA, 1 ether, 1);
        IERC20(pairA).approve(address(stakingSy), 1 ether);
        vm.expectRevert(reason_);
        stakingSy.deposit(address(this), pairA, 1 ether, 1);
        assertEq(IERC20(pairA).balanceOf(address(this)), payment_, "rejected acquisitions take no payment");
        assertEq(IERC20(detf).totalSupply(), supply_, "rejected acquisitions issue nothing");
    }

    function _allExitRoutes(SY wrapper_, uint256 shares_) private {
        address[] memory outputs_ = wrapper_.getTokensOut();
        uint256 packet_ = shares_ / (2 * outputs_.length + 1);
        for (uint256 i_; i_ < outputs_.length; ++i_) {
            uint256 before_ = IERC20(outputs_[i_]).balanceOf(receiver);
            uint256 paid_ = wrapper_.redeem(receiver, packet_, outputs_[i_], 1, false);
            assertGt(paid_, 0);
            assertEq(IERC20(outputs_[i_]).balanceOf(receiver) - before_, paid_);
            wrapper_.transfer(address(wrapper_), packet_);
            before_ = IERC20(outputs_[i_]).balanceOf(receiver);
            vm.prank(receiver);
            paid_ = wrapper_.redeem(receiver, packet_, outputs_[i_], 1, true);
            assertGt(paid_, 0);
            assertEq(IERC20(outputs_[i_]).balanceOf(receiver) - before_, paid_);
            assertEq(IERC20(detf).allowance(address(wrapper_), detf), 0, "exit approval cleared");
        }
    }
}
