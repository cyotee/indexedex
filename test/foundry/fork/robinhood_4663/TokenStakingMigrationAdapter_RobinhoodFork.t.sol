// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDetfClaimPurchase} from "contracts/interfaces/IDetfClaimPurchase.sol";
import {ITokenStaking} from "contracts/interfaces/ITokenStaking.sol";
import {ITokenStakingDFPkg} from "contracts/protocols/staking/token/ITokenStakingDFPkg.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {TokenStakingMigrationAdapter} from "contracts/protocols/staking/token/TokenStakingMigrationAdapter.sol";
import {
    Phase_08_Stage_07_StakingPrincipalMigration as Migration
} from "scripts/foundry/anvil_robinhood_main/Phase_08_Stage_07_StakingPrincipalMigration.sol";

/// @notice Real historical staking/package and real funded DETF on an isolated fork of the rehearsal node.
/// @dev No broadcast, storage surgery, mock calls, replacement facets or current-source staking deployments.
contract TokenStakingMigrationAdapter_RobinhoodFork is Test {
    address internal constant EXISTING_STAKING = 0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00;
    address internal constant OWNER = 0x72BeA6Fa3E68EF18c87D045Aac7C4Aa5249d933B;
    IERC20 internal constant DTF = IERC20(0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01);
    IERC20 internal constant DETF = IERC20(0x8ff37779B8Fe866470aEcf64910F4Bf899d73705);
    address internal constant CLAIM = 0x764C96E8b66832c78030f36DbdeDF2A34FEadaaB;
    address internal constant SY = 0xce5b57f7c84825f789865719153684fC067fD6e7;
    address internal constant FACTORY = 0x976949aB55830fA4794bF40C88ea7D7567931003;
    address internal constant LEGACY_PACKAGE = 0xa1A1760e69416192135a00Bc6701001f03cE54f3;
    ITokenStaking internal staking;
    TokenStakingMigrationAdapter internal adapter;

    function setUp() public {
        vm.createSelectFork(
            vm.envOr("MIGRATION_ADAPTER_FORK_RPC", string("http://127.0.0.1:8545")),
            vm.envOr("MIGRATION_ADAPTER_FORK_BLOCK", uint256(60445001))
        );
        assertEq(block.chainid, 4663);
        staking = ITokenStaking(EXISTING_STAKING);
        assertEq(uint256(staking.phase()), uint256(ITokenStaking.Phase.Staking));
        _assertHistoricalFacet();
        _setAdapter();
    }

    function _assertHistoricalFacet() internal view {
        assertEq(
            IDiamondLoupe(address(staking)).facetAddress(ITokenStaking.migrateToClaimVault.selector),
            0x9C90d4a476f3473b9a0e32B530aF3474271a80B1
        );
        assertEq(
            IDiamondLoupe(address(staking)).facetAddress(ITokenStaking.withdrawClaim.selector),
            0x9C90d4a476f3473b9a0e32B530aF3474271a80B1
        );
    }

    function _setAdapter() internal {
        adapter = new TokenStakingMigrationAdapter(address(staking), DTF, DETF, CLAIM);
        vm.prank(OWNER);
        staking.setTargetDetf(IDetfClaimPurchase(address(adapter)));
    }

    function _assertClean() internal view {
        assertEq(adapter.totalSupply(), 0);
        assertEq(adapter.balanceOf(address(staking)), 0);
        assertEq(adapter.allowance(address(staking), address(adapter)), 0);
        assertEq(DTF.allowance(address(staking), address(adapter)), 0);
        assertEq(DTF.allowance(address(adapter), address(DETF)), 0);
        assertEq(DETF.allowance(address(adapter), SY), 0);
        assertEq(DTF.balanceOf(address(adapter)), 0);
        assertEq(DETF.balanceOf(address(adapter)), 0);
        assertEq(IERC20(CLAIM).balanceOf(address(adapter)), 0);
        assertEq(IERC20(CLAIM).balanceOf(address(staking)), 0);
        assertEq(IERC20(SY).balanceOf(address(adapter)), 0);
        assertEq(IERC20(SY).balanceOf(address(staking)), 0);
        assertEq(adapter.rebasingClaimToken(), SY);
        assertEq(adapter.fundedStakingToken(), CLAIM);
    }

    function _migrateAll() internal returns (uint256 chunks_) {
        uint256 before_ = staking.reserveRemaining();
        uint256 principal_ = staking.totalSupply();
        uint256 converted_;
        address vault_;
        while (staking.reserveRemaining() != 0) {
            assertLt(chunks_, 256);
            uint256 amount_ = Migration.nextChunkAmount(staking, address(DETF), before_);
            vm.startPrank(OWNER);
            Migration.Result memory result_ =
                Migration.execute(staking, address(DETF), amount_, before_, 1, block.timestamp + 1 hours);
            vm.stopPrank();
            uint256 claim_ = result_.claimOut;
            uint256 shares_ = result_.sharesOut;
            assertGt(claim_, 0);
            assertGt(shares_, 0);
            converted_ += amount_;
            assertEq(staking.reserveRemaining(), before_ - converted_);
            assertEq(staking.totalSupply(), principal_);
            assertEq(staking.claimVault().asset(), SY);
            if (vault_ == address(0)) vault_ = address(staking.claimVault());
            assertEq(address(staking.claimVault()), vault_);
            _assertClean();
            ++chunks_;
        }
        Migration.verifyComplete(staking, address(DETF));
        assertEq(converted_, before_);
        assertEq(staking.rewardRate(), 0);
        assertEq(uint256(staking.phase()), uint256(ITokenStaking.Phase.Wrapped));
    }

    /// @notice Entire original principal and reward balance migrates through unmodified deployed staking.
    function test_existingStaking_migrateAllPrincipalAndRewards() public {
        assertEq(staking.reserveRemaining(), 223355050624580728299834717);
        assertEq(staking.totalSupply(), 220032706803999006035614295);
        emit log_named_uint("Historical staking migration chunks", _migrateAll());
    }

    /// @notice Exercise user withdrawal on the original staking address, without replacing any implementation.
    function test_existingStaking_depositorWithdrawsRealClaim() public {
        address user_ = makeAddr("adapter-original-staking-user");
        // Test-only funding from the existing reserve; staking returns the same tokens immediately.
        // Use a material stake: microscopic weights can round below one native SY unit.
        vm.prank(EXISTING_STAKING);
        DTF.transfer(user_, 100 ether);
        vm.startPrank(user_);
        DTF.approve(address(staking), 100 ether);
        staking.stake(100 ether);
        vm.stopPrank();
        _migrateAll();
        _withdraw(user_, 40 ether);
        _withdraw(user_, 60 ether);
        assertEq(staking.balanceOf(user_), 0);
        _unwrap(user_);
        assertGt(IERC20(CLAIM).balanceOf(user_), 0);
        vm.prank(user_);
        vm.expectRevert(abi.encodeWithSelector(ITokenStaking.InsufficientStake.selector, user_, 1, 0));
        staking.withdrawClaim(1);
    }

    /// @notice A failed minimum atomically rolls back the first migration, including phase/approvals/receipts.
    function test_existingStaking_failedMinimumIsAtomic() public {
        uint256 amount_ = Migration.nextChunkAmount(staking, address(DETF), type(uint256).max);
        uint256 before_ = staking.reserveRemaining();
        uint256 snapshot_ = vm.snapshotState();
        vm.prank(OWNER);
        (uint256 expected_,) = staking.migrateToClaimVault(amount_, 1, block.timestamp + 1 hours);
        assertTrue(vm.revertToState(snapshot_));
        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSignature("MinimumOutputNotMet(uint256,uint256)", type(uint256).max, expected_));
        staking.migrateToClaimVault(amount_, type(uint256).max, block.timestamp + 1 hours);
        assertEq(staking.reserveRemaining(), before_);
        assertEq(uint256(staking.phase()), uint256(ITokenStaking.Phase.Staking));
        assertEq(address(staking.claimVault()), address(0));
        _assertClean();
    }

    /// @notice Reuse the historical package for a small, enumerable holder set and the exact legacy claim wrapper.
    function _knownHolders() internal returns (address alice_, address bob_) {
        staking = ITokenStakingDFPkg(LEGACY_PACKAGE)
            .deployStaking(
                IDiamondPackageCallBackFactory(FACTORY),
                ITokenStakingDFPkg.PkgArgs(DTF, 7 days, OWNER, 2 days, keccak256("adapter-withdrawal-proof"))
            );
        _assertHistoricalFacet();
        // Test-only funding from an existing DTF holder using real ERC20 transfers, never vm.store/deal on SUTs.
        alice_ = makeAddr("adapter-alice");
        bob_ = makeAddr("adapter-bob");
        vm.startPrank(EXISTING_STAKING);
        DTF.transfer(alice_, 100 ether);
        DTF.transfer(bob_, 200 ether);
        DTF.transfer(OWNER, 30 ether);
        vm.stopPrank();
        vm.startPrank(alice_);
        DTF.approve(address(staking), 100 ether);
        staking.stake(100 ether);
        vm.stopPrank();
        vm.startPrank(bob_);
        DTF.approve(address(staking), 200 ether);
        staking.stake(200 ether);
        vm.stopPrank();
        vm.startPrank(OWNER);
        DTF.approve(address(staking), 30 ether);
        staking.notifyRewardAmount(30 ether);
        vm.stopPrank();
        _setAdapter();
    }

    function _withdraw(address user_, uint256 amount_) internal returns (uint256 received_) {
        uint256 expected_ = staking.previewClaim(user_, amount_);
        assertGt(expected_, 0, "withdrawal fixture must exceed native output precision");
        uint256 before_ = IERC20(SY).balanceOf(user_);
        uint256 weight_ = staking.balanceOf(user_);
        vm.prank(user_);
        received_ = staking.withdrawClaim(amount_);
        assertEq(received_, expected_);
        assertEq(IERC20(SY).balanceOf(user_) - before_, received_);
        assertEq(staking.balanceOf(user_), weight_ - amount_);
        assertEq(adapter.totalSupply(), 0);
    }

    function _unwrap(address user_) internal returns (uint256 received_) {
        uint256 shares_ = IERC20(SY).balanceOf(user_);
        uint256 before_ = IERC20(CLAIM).balanceOf(user_);
        vm.prank(user_);
        received_ = IStandardizedYield(SY).redeem(user_, shares_, CLAIM, 1, false);
        assertGt(received_, 0);
        assertEq(IERC20(CLAIM).balanceOf(user_) - before_, received_);
        assertEq(IERC20(SY).balanceOf(user_), 0);
    }

    /// @notice Partial/full/final exits deliver SY, redeemable for real sDETF and subsequently unstakable DETF.
    function test_historicalPackage_partialFullFinalWithdrawals() public {
        (address alice_, address bob_) = _knownHolders();
        _migrateAll();
        _withdraw(alice_, 40 ether);
        _withdraw(bob_, 200 ether);
        uint256 lastVaultShares_ = staking.claimVault().balanceOf(address(staking));
        assertGt(lastVaultShares_, 0);
        _withdraw(alice_, 60 ether);
        assertEq(staking.claimVault().balanceOf(address(staking)), 0);
        assertEq(staking.totalSupply(), 0);
        _unwrap(alice_);
        _unwrap(bob_);
        uint256 claim_ = IERC20(CLAIM).balanceOf(alice_);
        vm.prank(alice_);
        uint256 detfOut_ =
            IStakedDETF(CLAIM).exchangeIn(IERC20(CLAIM), claim_, DETF, claim_, alice_, false, block.timestamp);
        assertEq(DETF.balanceOf(alice_), detfOut_);
        assertEq(detfOut_, claim_);
    }

    /// @notice Future funded rebases remain withdrawable through the historical stored claim-vault package.
    function test_historicalPackage_withdrawAfterRebase() public {
        (address alice_, address bob_) = _knownHolders();
        _migrateAll();
        uint256 shares_ = staking.previewClaim(alice_, 100 ether);
        uint256 before_ = IStandardizedYield(SY).previewRedeem(CLAIM, shares_);
        vm.warp(block.timestamp + 30 days);
        IDETFFundedRewards(address(DETF)).synchronizeRewards();
        assertEq(staking.previewClaim(alice_, 100 ether), shares_);
        assertGt(IStandardizedYield(SY).previewRedeem(CLAIM, shares_), before_);
        _withdraw(alice_, 100 ether);
        _withdraw(bob_, 200 ether);
        assertGt(_unwrap(alice_), before_);
        _unwrap(bob_);
        assertEq(staking.claimVault().balanceOf(address(staking)), 0);
    }

    /// @notice Check that an exit itself does not leave the user's pending funded growth behind in the wrapper.
    function test_historicalPackage_withdrawWithPendingRebase() public {
        (address alice_,) = _knownHolders();
        _migrateAll();
        vm.warp(block.timestamp + 30 days);
        uint256 snapshot_ = vm.snapshotState();
        IDETFFundedRewards(address(DETF)).synchronizeRewards();
        _withdraw(alice_, 100 ether);
        uint256 settledExpected_ = _unwrap(alice_);
        assertTrue(vm.revertToState(snapshot_));
        _withdraw(alice_, 100 ether);
        uint256 received_ = _unwrap(alice_);
        assertEq(received_, settledExpected_, "pending rebase must follow the exiting stake");
    }

    /// @notice Ownership continues growing if users wait between claiming static SY and redeeming it.
    function test_historicalPackage_delayedSYRedemptionKeepsRewards() public {
        (address alice_,) = _knownHolders();
        _migrateAll();
        _withdraw(alice_, 100 ether);
        uint256 shares_ = IERC20(SY).balanceOf(alice_);
        uint256 before_ = IStandardizedYield(SY).previewRedeem(CLAIM, shares_);
        vm.warp(block.timestamp + 90 days);
        uint256 snapshot_ = vm.snapshotState();
        IDETFFundedRewards(address(DETF)).synchronizeRewards();
        uint256 settledExpected_ = _unwrap(alice_);
        assertTrue(vm.revertToState(snapshot_));
        assertEq(IERC20(SY).balanceOf(alice_), shares_);
        uint256 received_ = _unwrap(alice_);
        assertEq(received_, settledExpected_);
        assertGt(received_, before_);
    }
}
