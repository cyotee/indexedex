// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {TestBase_UniswapV4DetfMigration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationAccounting as Accounting} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationStakedDETF as MigrationReceipt} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/claimToken/IUniswapV4DetfMigrationStakedDETF.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IUniswapV4DetfMigrationSY as SY} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/IUniswapV4DetfMigrationSY.sol";
import {IUniswapV4DetfMigrationRewardToken as RT} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/sy/rewards/IUniswapV4DetfMigrationRewardToken.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";

/// @notice Actual mature principal, closed reward custody, principal SY and owned activated rewards.
contract MigrationEgressTest is TestBase_UniswapV4DetfMigration {
    uint256 internal principal;
    uint256 internal bondId;
    address internal receiver = address(0xBEEF);

    function setUp() public override {
        super.setUp();
        _fundAndCapture();
        principal = _configure(address(this), 1 ether, bytes32("egress-original"));
        bondId = _issue(address(this));
        _donateCapital();
        vm.warp(block.timestamp + 90 days);
        migration.synchronizeRewards();
        require(bonds.previewClaim(bondId).rewardsDue > 0, "funded reward witness");
        bonds.claimPrincipal(bondId, address(this));
    }

    function _donateCapital() private {
        IERC20[] memory tokens_ = new IERC20[](2);
        tokens_[0] = IERC20(pairA); tokens_[1] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 50 ether; amounts_[1] = 50 ether;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 1, block.timestamp);
    }

    function _earnAgain() private {
        _donateCapital();
        vm.warp(block.timestamp + 8 hours);
        migration.synchronizeRewards();
    }

    function _activate() private {
        vm.prank(migrationOwner);
        allocation.activateMigration();
    }

    function _backing() private view {
        IStakedDETF.StakingState memory s_ = receipt.stakingState();
        assertEq(s_.accountedBacking, s_.totalGons / s_.gonsPerUnit + s_.allocationDust + s_.stakingDust);
        assertGe(IERC20(detf).balanceOf(address(receipt)), s_.accountedBacking);
        assertGe(receipt.gonsOf(address(bonds)), bonds.attributedBondGons());
        assertGe(receipt.gonsOf(address(stakingSy)), stakingSy.attributedSyGons());
        assertEq(receipt.tokenizedSyRewardGons(), RT(migration.migrationSyRewardToken()).totalSupply() * 1e18);
    }

    function test_receiptGrowthCannotLeaveThroughTransfer() public {
        _earnAgain();
        uint256 gons_ = receipt.gonsOf(address(this));
        vm.expectRevert(abi.encodeWithSelector(MigrationReceipt.InsufficientLiquidPrincipal.selector, principal + 1, principal));
        receipt.transfer(receiver, principal + 1);
        assertEq(receipt.gonsOf(address(this)), gons_);
        assertEq(receipt.deferredRewardGons(0, address(this)), 0);
        receipt.transfer(receiver, principal);
        assertEq(receipt.balanceOf(receiver), principal);
        assertGt(receipt.deferredRewardGons(0, address(this)), 0);
        _backing();
    }

    function test_receiptExactOutputRetainsGrowthAndPaysPrincipal() public {
        _earnAgain();
        uint256 before_ = IERC20(detf).balanceOf(receiver);
        uint256 used_ = receipt.exchangeOut(
            IERC20(address(receipt)), principal, IERC20(detf), principal, receiver, false, block.timestamp
        );
        assertEq(used_, principal);
        assertEq(IERC20(detf).balanceOf(receiver) - before_, principal);
        assertGt(receipt.deferredRewardGons(0, address(this)), 0);
        _backing();
    }

    function test_parentReceiptPacketPreservesOldParentInventory() public {
        receipt.transfer(detf, principal / 5);
        uint256 held_ = receipt.balanceOf(detf);
        _earnAgain();
        uint256 amount_ = principal / 3;
        receipt.approve(detf, amount_);
        uint256 before_ = IERC20(detf).balanceOf(receiver);
        detfExchangeIn.exchangeIn(IERC20(address(receipt)), amount_, IERC20(detf), amount_, receiver, false, block.timestamp);
        assertEq(IERC20(detf).balanceOf(receiver) - before_, amount_);
        (, uint256 basis_,,,,,) = receipt.egressState(detf);
        assertEq(basis_, held_);
        assertGt(receipt.deferredRewardGons(0, address(this)), 0);
        _backing();
    }

    function test_syDepositingIntoEarnedPositionPreservesOldRewards() public {
        receipt.approve(address(stakingSy), principal);
        uint256 first_ = principal / 2;
        stakingSy.deposit(address(this), address(receipt), first_, first_);
        _earnAgain();
        uint256 k_ = receipt.stakingState().gonsPerUnit;
        uint256 oldGons_ = stakingSy.attributedSyGons();
        stakingSy.deposit(address(this), address(receipt), principal - first_, principal - first_);
        assertEq(stakingSy.balanceOf(address(this)), principal);
        assertEq(stakingSy.attributedSyGons(), principal * k_);
        assertEq(receipt.deferredRewardGons(2, address(this)), oldGons_ - first_ * k_);
        assertEq(receipt.allowance(address(this), address(stakingSy)), 0);
        _backing();
    }

    function test_syOldHolderRetainsRewardsAfterFullDeparture() public {
        receipt.approve(address(stakingSy), principal);
        stakingSy.deposit(address(this), address(receipt), principal, principal);
        _earnAgain();
        uint256 expectedGons_ = stakingSy.attributedSyGons() - principal * receipt.stakingState().gonsPerUnit;
        stakingSy.transfer(receiver, principal);
        assertEq(receipt.deferredRewardGons(2, address(this)), expectedGons_);
        assertEq(receipt.deferredRewardGons(2, receiver), 0);
        vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
        stakingSy.claimRewards(address(this));
        assertEq(RT(migration.migrationSyRewardToken()).totalSupply(), 0);
        vm.prank(receiver);
        assertEq(stakingSy.redeem(receiver, principal, detf, principal, false), principal);
        _earnAgain();
        _activate();
        uint256[] memory claimed_ = stakingSy.claimRewards(address(this));
        assertEq(claimed_[0], expectedGons_ / 1e18);
        RT rt_ = RT(migration.migrationSyRewardToken());
        uint256 k_ = receipt.stakingState().gonsPerUnit;
        uint256 before_ = receipt.balanceOf(receiver);
        (uint256 paid_, uint256 remainder_) = rt_.redeem(claimed_[0], receiver, 0);
        assertEq(paid_, claimed_[0] * 1e18 / k_);
        assertEq(remainder_, claimed_[0] * 1e18 % k_);
        assertEq(receipt.balanceOf(receiver) - before_, paid_);
        assertEq(receipt.deferredRewardGons(0, address(this)), remainder_);
        assertEq(stakingSy.claimRewards(address(this))[0], 0);
        _backing();
    }

    function test_syBearerInternalBurnDoesNotRedirectOldRewards() public {
        receipt.approve(address(stakingSy), principal);
        stakingSy.deposit(address(this), address(receipt), principal, principal);
        _earnAgain();
        stakingSy.approve(receiver, principal);
        vm.prank(receiver);
        stakingSy.transferFrom(address(this), address(stakingSy), principal);
        uint256 owed_ = receipt.deferredRewardGons(2, address(this));
        assertGt(owed_, 0);
        vm.prank(receiver);
        assertEq(stakingSy.redeem(receiver, principal, address(receipt), principal, true), principal);
        assertEq(receipt.balanceOf(receiver), principal);
        assertEq(stakingSy.balanceOf(address(stakingSy)), 0);
        assertEq(receipt.deferredRewardGons(2, address(this)), owed_);
        _backing();
    }

    function test_syDelayedSelfRewardsRemainProtocolOwned() public {
        receipt.approve(address(stakingSy), principal);
        stakingSy.deposit(address(stakingSy), address(receipt), principal, principal);
        _earnAgain();
        uint256 heldBefore_ = receipt.gonsOf(address(stakingSy));
        uint256 k_ = receipt.stakingState().gonsPerUnit;
        vm.prank(receiver);
        stakingSy.redeem(receiver, principal, detf, principal, true);
        assertEq(receipt.deferredRewardGons(2, receiver), 0);
        assertEq(receipt.deferredRewardGons(2, address(stakingSy)), 0);
        assertGe(receipt.gonsOf(address(receipt)), heldBefore_ - principal * k_);
        _activate();
        assertEq(stakingSy.claimRewards(address(stakingSy))[0], 0);
        _backing();
    }

    function test_syFailedMinimumRollsBackGonsSharesAndAllowance() public {
        receipt.approve(address(stakingSy), principal);
        uint256 gons_ = receipt.gonsOf(address(this));
        (bool ok_,) = address(stakingSy).call(abi.encodeCall(
            IStandardizedYield.deposit, (address(this), address(receipt), principal, principal + 1)
        ));
        assertFalse(ok_);
        assertEq(receipt.gonsOf(address(this)), gons_);
        assertEq(receipt.allowance(address(this), address(stakingSy)), principal);
        assertEq(stakingSy.totalSupply(), 0);
        _backing();
    }

    function test_allConfiguredSyOutputsPayActualPrincipal() public {
        _activate();
        receipt.approve(address(stakingSy), principal);
        stakingSy.deposit(address(this), address(receipt), principal, principal);
        address[] memory outputs_ = stakingSy.getTokensOut();
        uint256 packet_ = principal / (2 * outputs_.length + 1);
        for (uint256 i_; i_ < outputs_.length; ++i_) {
            uint256 before_ = IERC20(outputs_[i_]).balanceOf(receiver);
            uint256 paid_ = stakingSy.redeem(receiver, packet_, outputs_[i_], 1, false);
            assertEq(IERC20(outputs_[i_]).balanceOf(receiver) - before_, paid_);
            assertGt(paid_, 0);
            stakingSy.transfer(address(stakingSy), packet_);
            before_ = IERC20(outputs_[i_]).balanceOf(receiver);
            vm.prank(receiver);
            paid_ = stakingSy.redeem(receiver, packet_, outputs_[i_], 1, true);
            assertEq(IERC20(outputs_[i_]).balanceOf(receiver) - before_, paid_);
            assertGt(paid_, 0);
            assertEq(IERC20(detf).allowance(address(stakingSy), detf), 0);
        }
        _backing();
    }

    function test_rawSyBothBurnModesAndEveryOutput() public {
        receipt.exchangeIn(IERC20(address(receipt)), principal, IERC20(detf), principal, address(this), false, block.timestamp);
        _activate();
        IERC20(detf).approve(address(rawSy), principal);
        rawSy.deposit(address(this), detf, principal, principal);
        address[] memory outputs_ = rawSy.getTokensOut();
        uint256 packet_ = principal / (2 * outputs_.length + 2);
        rawSy.transfer(address(rawSy), packet_);
        vm.prank(receiver);
        assertEq(rawSy.redeem(receiver, packet_, detf, packet_, true), packet_);
        for (uint256 i_; i_ < outputs_.length; ++i_) {
            uint256 before_ = IERC20(outputs_[i_]).balanceOf(receiver);
            uint256 paid_ = rawSy.redeem(receiver, packet_, outputs_[i_], 1, false);
            assertEq(IERC20(outputs_[i_]).balanceOf(receiver) - before_, paid_);
            assertGt(paid_, 0);
            rawSy.transfer(address(rawSy), packet_);
            before_ = IERC20(outputs_[i_]).balanceOf(receiver);
            vm.prank(receiver);
            paid_ = rawSy.redeem(receiver, packet_, outputs_[i_], 1, true);
            assertEq(IERC20(outputs_[i_]).balanceOf(receiver) - before_, paid_);
            assertGt(paid_, 0);
        }
        assertEq(rawSy.getRewardTokens().length, 0);
        assertEq(rawSy.claimRewards(address(this)).length, 0);
        assertEq(IERC20(detf).balanceOf(address(rawSy)), rawSy.totalSupply());
        _backing();
    }

    function test_bothWrappersAcquireEveryConfiguredInputAfterActivation() public {
        uint256 liquid_ = principal / 3;
        receipt.exchangeIn(IERC20(address(receipt)), liquid_, IERC20(detf), liquid_, address(this), false, block.timestamp);
        _activate();
        _allInputs(rawSy);
        _allInputs(stakingSy);
        _backing();
    }

    function _allInputs(SY sy_) private {
        address[] memory inputs_ = sy_.getTokensIn();
        for (uint256 i_; i_ < inputs_.length; ++i_) {
            uint256 amount_ = inputs_[i_] == detf || inputs_[i_] == address(receipt) ? principal / 20 : 1e14;
            IERC20(inputs_[i_]).approve(address(sy_), amount_);
            uint256 before_ = sy_.balanceOf(address(this));
            uint256 shares_ = sy_.deposit(address(this), inputs_[i_], amount_, 1);
            assertEq(sy_.balanceOf(address(this)) - before_, shares_);
            assertGt(shares_, 0);
            assertEq(IERC20(inputs_[i_]).allowance(address(sy_), detf), 0);
            assertEq(IERC20(detf).allowance(address(sy_), address(receipt)), 0);
        }
    }

    function test_failedUnderlyingRedeemRestoresWholeTransaction() public {
        receipt.approve(address(stakingSy), principal);
        stakingSy.deposit(address(this), address(receipt), principal, principal);
        _earnAgain();
        uint256 gons_ = receipt.gonsOf(address(stakingSy));
        uint256 backing_ = receipt.stakingState().accountedBacking;
        uint256 supply_ = IERC20(detf).totalSupply();
        (bool ok_,) = address(stakingSy).call(abi.encodeCall(
            IStandardizedYield.redeem, (receiver, principal / 2, pairA, type(uint256).max, false)
        ));
        assertFalse(ok_);
        assertEq(stakingSy.balanceOf(address(this)), principal);
        assertEq(receipt.gonsOf(address(stakingSy)), gons_);
        assertEq(receipt.stakingState().accountedBacking, backing_);
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(IERC20(detf).allowance(address(stakingSy), detf), 0);
        assertEq(receipt.deferredRewardGons(2, address(this)), 0);
        _backing();
    }

    function test_rolesReceiveNoClosedReceiptThenActualActivatedRelease() public {
        address beneficiary_ = IERC721(address(bonds)).ownerOf(1);
        assertEq(receipt.balanceOf(beneficiary_), 0);
        uint256 gons_ = receipt.deferredRewardGons(1, beneficiary_);
        assertGt(gons_, 0);
        vm.expectRevert(Accounting.MigrationRewardsClosed.selector);
        receipt.claimDeferredRoleRewards(beneficiary_);
        _activate();
        uint256 k_ = receipt.stakingState().gonsPerUnit;
        assertEq(receipt.claimDeferredRoleRewards(beneficiary_), gons_ / k_);
        assertEq(receipt.balanceOf(beneficiary_), gons_ / k_);
        assertEq(receipt.deferredRewardGons(1, beneficiary_), gons_ % k_);
        assertEq(receipt.claimDeferredRoleRewards(beneficiary_), 0);
        _backing();
    }

    function test_ordinaryActiveBondIsUnmarkedAndLinear() public {
        _activate();
        (uint256 id_,) = migration.bond(IERC20(pairA), 1 ether, 90 days, address(this), false, block.timestamp);
        assertFalse(bonds.isMigrationPosition(id_));
        uint256 amount_ = bonds.positionOf(id_).principal;
        vm.warp(block.timestamp + 45 days);
        assertEq(bonds.previewClaim(id_).principalDue, amount_ / 2);
        assertEq(bonds.claimPrincipal(id_, address(this)), amount_ / 2);
        _backing();
    }
}
