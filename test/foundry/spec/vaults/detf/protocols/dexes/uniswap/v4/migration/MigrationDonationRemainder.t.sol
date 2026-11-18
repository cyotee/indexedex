// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IReentrancyLock} from "@crane/contracts/interfaces/IReentrancyLock.sol";
import {SafeTransferLib} from "@crane/contracts/tokens/ERC20/utils/SafeTransferLib.sol";
import {Vm} from "forge-std/Vm.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IUniswapV4SeBufferHook, IUniswapV4SeBufferHookNativeLiquidity} from
    "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {UniswapV4DetfRepo as ParentRepo} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {TestBase_UniswapV4DetfMigration_Adversarial} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration_Adversarial.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IUniswapV4DetfMigration as Migration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {MigrationHostileContribution} from "./MigrationHostileContribution.t.sol";

/// @notice Explicit donation release on real registry proxies, with real SE and reserve-hook pulls.
/// @dev Recovery with positive legacy custody is covered by MigrationRecoveryDonation's pinned fork.
contract MigrationDonationRemainderTest is TestBase_UniswapV4DetfMigration_Adversarial {
    struct SweepState {
        uint256[6] held;
        uint256[6] booked;
        uint256[6] recovery;
        uint256[6] payer;
        uint256 lp;
        bytes32 protectedState;
    }

    /// @notice A fee-recipient Stage 1 sweep invests booked leftovers without purchasing a bond.
    function test_partialBootstrapRemainderSweepsBeforeActivation() public {
        _partialBootstrap();
        assertEq(migration.migrationOwnerFirstBondTokenId(), 0);
        _sweepAndCheck(true);
        assertFalse(migration.migrationActivated());
        assertEq(migration.migrationOwnerFirstBondTokenId(), 0);
    }

    /// @notice Each authorized call invests one basket; its refunds fund the next external call.
    function test_explicitSweepLeavesRefundsForNextCallerTransaction() public {
        _partialBootstrap();
        uint256 firstQuote_ = _nativeSweepQuote();
        assertGt(firstQuote_, 0);
        uint256 beforeLp_ = IERC20(reserveHook).balanceOf(address(bonds));
        _sweepAndCheck(true);
        assertEq(IERC20(reserveHook).balanceOf(address(bonds)) - beforeLp_, firstQuote_, "one quoted basket per call");

        uint256 secondQuote_ = _nativeSweepQuote();
        assertGt(secondQuote_, 0, "first-call refunds support a later deposit");
        beforeLp_ = IERC20(reserveHook).balanceOf(address(bonds));
        _sweepAndCheck(true);
        assertEq(IERC20(reserveHook).balanceOf(address(bonds)) - beforeLp_, secondQuote_, "next call invests retained refunds");
    }

    /// @notice The previously over-budget native migration fixture completes one maintenance call under its cap.
    function test_explicitSweepFitsNativeTransactionGasBudget() public {
        _partialBootstrap();
        bytes32 protected_ = _protectedState();
        uint256 beforeLp_ = IERC20(reserveHook).balanceOf(address(bonds));
        address authority_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        vm.prank(authority_);
        uint256 gasBefore_ = gasleft();
        migration.sweepDust{gas: 31_900_000}();
        emit log_named_uint("single sweep call gas", gasBefore_ - gasleft());
        assertGt(IERC20(reserveHook).balanceOf(address(bonds)), beforeLp_);
        assertEq(_protectedState(), protected_);
        _assertAllowancesCleared();
    }

    function _nativeSweepQuote() internal view returns (uint256) {
        address[] memory pairs_ = IUniswapV4SeBufferHook(reserveHook).tokens();
        uint256[] memory local_ = new uint256[](pairs_.length);
        uint256[] memory shares_ = new uint256[](pairs_.length);
        for (uint256 i_; i_ < pairs_.length; ++i_) {
            local_[i_] = IERC20(pairs_[i_]).balanceOf(detf);
            address se_ = IUniswapV4SeBufferHook(reserveHook).standardExchangeOf(pairs_[i_]);
            if (se_ != address(0)) shares_[i_] = IERC20(se_).balanceOf(detf);
        }
        return IUniswapV4SeBufferHookNativeLiquidity(reserveHook).previewJoinNativeComponents(local_, shares_);
    }

    /// @notice A paid purchase and activation leave the original donations for the explicit sweep.
    function test_partialBootstrapRemainderSweepsAfterActivation() public {
        _partialBootstrap();
        uint256 a_ = migration.migrationDonationInventory(IERC20(pairA));
        uint256 b_ = migration.migrationDonationInventory(IERC20(pairB));
        _setObservedPricing();
        uint256 id_ = _buyOwnerFirstBond();
        assertGt(id_, 0);
        assertEq(migration.migrationDonationInventory(IERC20(pairA)), a_);
        assertEq(migration.migrationDonationInventory(IERC20(pairB)), b_);
        vm.prank(migrationOwner);
        allocation.activateMigration();
        assertGt(migration.migrationDonationInventory(IERC20(pairA)), 0);
        assertGt(migration.migrationDonationInventory(IERC20(pairB)), 0);
        _sweepAndCheck(true);
        assertTrue(migration.migrationActivated());
        assertEq(migration.migrationOwnerFirstBondTokenId(), id_);
    }

    /// @notice Neither a stranger nor the migration administrator can initiate reserve maintenance.
    function test_explicitSweepRejectsStrangerAndMigrationOwner() public {
        _partialBootstrap();
        SweepState memory before_ = _sweepState();
        address authority_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        assertNotEq(authority_, migrationOwner);
        address[2] memory callers_ = [address(0xBEEF), migrationOwner];
        for (uint256 i_; i_ < callers_.length; ++i_) {
            vm.prank(callers_[i_]);
            vm.expectRevert(abi.encodeWithSelector(ParentRepo.NotAuthorized.selector, callers_[i_]));
            migration.sweepDust();
            assertEq(abi.encode(_sweepState()), abi.encode(before_));
        }
    }

    /// @notice Sweep authority follows the live oracle instead of a cached recipient or the proxy owner.
    function test_explicitSweepUsesCurrentFeeRecipient() public {
        _partialBootstrap();
        address prior_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        address next_ = makeAddr("next sweep fee recipient");
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(next_));
        vm.prank(prior_);
        vm.expectRevert(abi.encodeWithSelector(ParentRepo.NotAuthorized.selector, prior_));
        migration.sweepDust();
        _sweepAndCheck(true);
    }

    /// @notice A new donation invests only its payment, preserving previous-operation refunds.
    function test_newDonationDoesNotSweepEarlierResiduals() public {
        _partialBootstrap();
        _setObservedPricing();
        _buyOwnerFirstBond();
        uint256[4] memory before_ = _externalBalances();
        uint256 donationA_ = migration.migrationDonationInventory(IERC20(pairA));
        uint256 donationB_ = migration.migrationDonationInventory(IERC20(pairB));
        assertGt(before_[0] - donationA_ + before_[1] - donationB_ + before_[2] + before_[3], 0);
        assertGt(_donate(1 ether, 1 ether), 0);
        uint256[4] memory after_ = _externalBalances();
        for (uint256 i_; i_ < before_.length; ++i_) {
            assertGe(after_[i_], before_[i_], "earlier custody is outside the new payment");
        }
        assertEq(migration.migrationDonationInventory(IERC20(pairA)), donationA_);
        assertEq(migration.migrationDonationInventory(IERC20(pairB)), donationB_);
        _assertAllowancesCleared();
    }

    /// @notice Sweeping an inert instance cannot release genesis capital or manufacture liveness.
    function test_preLiveSweepCannotReleaseGenesisCapital() public {
        _donate(100 ether, 100 ether);
        _sweepAndCheck(false);
        assertFalse(migration.isReserveLive());
        assertEq(migration.migrationDonationInventory(IERC20(pairA)), 100 ether);
        assertEq(migration.migrationDonationInventory(IERC20(pairB)), 100 ether);
        assertEq(IERC20(detf).totalSupply(), 0);
        assertEq(IERC20(reserveHook).totalSupply(), 0);
    }

    /// @notice A retry can only spend genuine residuals, never release the same donation twice.
    function test_explicitSweepDoesNotReleaseTwice() public {
        _partialBootstrap();
        _sweepAndCheck(true);
        _sweepAndCheck(false);
    }

    /// @notice A later measured donation reopens and settles its own budget without taking unsolicited assets.
    function test_laterDonationOpensSettledBudget() public {
        _partialBootstrap();
        _sweepAndCheck(true);
        uint256 snapshot_ = vm.snapshotState();
        uint256 lp_ = _donate(1 ether, 1 ether);
        assertGt(lp_, 0);
        uint256[4] memory clean_ = _externalBalances();
        assertTrue(vm.revertToStateAndDelete(snapshot_));
        _sendUnbooked();
        bytes32 protected_ = _protectedState();
        uint256 payerA_ = IERC20(pairA).balanceOf(address(this));
        uint256 payerB_ = IERC20(pairB).balanceOf(address(this));
        uint256 beforeLp_ = IERC20(reserveHook).balanceOf(address(bonds));
        assertEq(_donate(1 ether, 1 ether), lp_);
        assertEq(IERC20(reserveHook).balanceOf(address(bonds)) - beforeLp_, lp_);
        assertEq(IERC20(pairA).balanceOf(address(this)), payerA_ - 1 ether);
        assertEq(IERC20(pairB).balanceOf(address(this)), payerB_ - 1 ether);
        _assertUnbookedDifference(clean_);
        assertEq(_protectedState(), protected_);
        _assertAllowancesCleared();
        // A second entry also proves that donation's own budget was closed.
        _sweepAndCheck(false);
    }

    /// @notice Actual pair conversion and reserve share refunds remain available to a later sweep.
    function test_pairAndShareRefundsRemainSpendable() public {
        _partialBootstrap();
        // Observe refunds from one transaction being spent by the next caller transaction.
        address[4] memory tokens_ = [pairA, pairB, se0, se1];
        uint256[4] memory refunds_;
        uint256[4] memory reused_;
        for (uint256 call_; call_ < 2; ++call_) {
            Vm.Log[] memory logs_ = _sweepAndCheck(true);
            for (uint256 i_; i_ < logs_.length; ++i_) {
                Vm.Log memory log_ = logs_[i_];
                if (log_.topics.length != 3 || log_.topics[0] != keccak256("Transfer(address,address,uint256)")) continue;
                address from_ = address(uint160(uint256(log_.topics[1])));
                address to_ = address(uint160(uint256(log_.topics[2])));
                uint256 amount_ = abi.decode(log_.data, (uint256));
                for (uint256 j_; j_ < tokens_.length; ++j_) {
                    if (log_.emitter != tokens_[j_]) continue;
                    if (to_ == detf && (from_ == reserveHook || from_ == se0 || from_ == se1)) refunds_[j_] += amount_;
                    if (from_ == detf) {
                        uint256 used_ = amount_ < refunds_[j_] ? amount_ : refunds_[j_];
                        refunds_[j_] -= used_;
                        reused_[j_] += used_;
                    }
                }
            }
        }
        assertGt(reused_[0] + reused_[1], 0, "real pair refunds enter a subsequent join");
        assertGt(reused_[2] + reused_[3], 0, "real share refunds enter a subsequent join");
        // Retained rounding dust is allowed; a new real receipt must still settle cleanly.
        assertGt(_donate(1 ether, 1 ether), 0);
        _sweepAndCheck(false);
    }

    /// @notice Unsolicited pair/share balances survive exactly, with the same LP progress as a clean sweep.
    function test_unbookedBalancesStayProtected() public {
        _partialBootstrap();
        uint256 snapshot_ = vm.snapshotState();
        _sweepAndCheck(true);
        uint256[4] memory clean_ = _externalBalances();
        uint256 lp_ = IERC20(reserveHook).balanceOf(address(bonds));
        assertTrue(vm.revertToStateAndDelete(snapshot_));
        _sendUnbooked();
        _sweepAndCheck(true);
        _assertUnbookedDifference(clean_);
        assertEq(IERC20(reserveHook).balanceOf(address(bonds)), lp_);
    }

    /// @notice A failed actual reserve-hook pull rolls back release, custody, backing and routing.
    function test_reserveHookPullFailureRollsBackRelease() public {
        _partialBootstrap();
        _sendUnbooked();
        MigrationHostileContribution(pairB).setTransferRevertCaller(reserveHook);
        SweepState memory before_ = _sweepState();
        bytes32 adversarial_ = _adversarialState(address(this), 3);
        // The hook's SafeTransferLib normalizes the token's ForcedTransferRevert.
        address authority_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        vm.prank(authority_);
        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
        migration.sweepDust();
        assertEq(abi.encode(_sweepState()), abi.encode(before_));
        _assertAdversarialUnchanged(adversarial_, address(this), 3);
        _assertAllowancesCleared();
        MigrationHostileContribution(pairB).setTransferRevertCaller(address(0));
        _sweepAndCheck(true);
    }

    /// @notice The actual hook pull records the exact parent-lock rejection while the outer sweep progresses.
    function test_reserveHookPullCannotReenterExplicitSweep() public {
        _partialBootstrap();
        _sendUnbooked();
        MigrationHostileContribution token_ = MigrationHostileContribution(pairB);
        token_.arm(false, reserveHook, detf, abi.encodeCall(IUniswapV4Detf.sweepDust, ()));
        assertFalse(token_.callbackAttempted());
        assertFalse(token_.callbackSucceeded());
        assertEq(token_.callbackReason(), "");
        _sweepAndCheck(true);
        assertTrue(token_.callbackAttempted());
        assertFalse(token_.callbackSucceeded());
        assertEq(token_.callbackReason(), abi.encodeWithSelector(IReentrancyLock.IsLocked.selector));
        assertGe(IERC20(pairA).balanceOf(detf), 7 ether);
        assertGe(IERC20(pairB).balanceOf(detf), 11 ether);
        assertGe(IERC20(se0).balanceOf(detf), 13 ether);
        assertGe(IERC20(se1).balanceOf(detf), 17 ether);
    }

    function _donate(uint256 a_, uint256 b_) internal returns (uint256) {
        IERC20[] memory tokens_ = new IERC20[](2);
        tokens_[0] = IERC20(pairA); tokens_[1] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = a_; amounts_[1] = b_;
        return migration.donateMigrationCapital(tokens_, amounts_, 0, 0, block.timestamp);
    }

    function _partialBootstrap() internal {
        _donate(100 ether, 100 ether);
        Migration.GenesisLeg[] memory legs_ = new Migration.GenesisLeg[](2);
        legs_[0] = Migration.GenesisLeg(IERC20(pairA), 50 ether, 1);
        legs_[1] = Migration.GenesisLeg(IERC20(pairB), 50 ether, 1);
        // Price the processed anchor on the same book before either conversion.
        (, uint256 refundA_) = IStandardExchangeIn(se0).previewExchangeIn(IERC20(pairA), 50 ether, IERC20(se0));
        (, uint256 refundB_) = IStandardExchangeIn(se1).previewExchangeIn(IERC20(pairB), 50 ether, IERC20(se1));
        uint256[] memory opening_ = migration.openingPairPerDetfWad();
        assertEq(opening_[0], opening_[1]);
        uint256 expected_ = (50 ether - refundA_) * 1e9 / opening_[0];
        vm.prank(migrationOwner);
        (uint256 minted_, uint256 lp_) = allocation.bootstrapMigrationReserve(legs_, 0, 1, block.timestamp);
        assertEq(minted_, expected_);
        assertEq(IERC20(detf).totalSupply(), expected_);
        assertEq(migration.migrationBootstrapSelfMinted(), expected_);
        assertGt(lp_, 0);
        assertEq(migration.migrationDonationInventory(IERC20(pairA)), 50 ether + refundA_);
        assertEq(migration.migrationDonationInventory(IERC20(pairB)), 50 ether + refundB_);
        assertEq(IERC20(pairA).balanceOf(detf), 50 ether + refundA_);
        assertEq(IERC20(pairB).balanceOf(detf), 50 ether + refundB_);
    }

    function _tokens() internal view returns (address[6] memory) {
        return [pairA, pairB, se0, se1, detf, reserveHook];
    }

    function _protectedState() internal view returns (bytes32 state_) {
        state_ = keccak256(abi.encode(
            IERC20(detf).totalSupply(), IERC20(detf).balanceOf(address(receipt)),
            receipt.stakingState(), receipt.gonsOf(address(bonds)), bonds.attributedBondGons(),
            rawSy.totalSupply(), stakingSy.totalSupply(), migration.migrationBootstrapSelfMinted(),
            migration.migrationOwnerFirstBondTokenId(), migration.migrationActivated(),
            migration.isReserveLive(), IDiamondLoupe(detf).facets(),
            migration.independentAllocation(address(this)), migration.independentIssuance(address(this))
        ));
        for (uint256 i_; i_ < 5; ++i_) {
            address holder_ = bonds.ownerOf(i_);
            state_ = keccak256(abi.encode(state_, holder_));
            if (holder_ != address(0)) state_ = keccak256(abi.encode(state_, bonds.positionOf(i_)));
        }
        address[6] memory tokens_ = _tokens();
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            state_ = keccak256(abi.encode(state_, IERC20(tokens_[i_]).balanceOf(address(0xBEEF))));
        }
    }

    function _sweepState() internal view returns (SweepState memory state_) {
        address[6] memory tokens_ = _tokens();
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            IERC20 token_ = IERC20(tokens_[i_]);
            state_.held[i_] = token_.balanceOf(detf);
            state_.booked[i_] = migration.migrationDonationInventory(token_);
            state_.recovery[i_] = Recovery(detf).migrationRecoveryInventory(tokens_[i_]);
            state_.payer[i_] = token_.balanceOf(address(this));
        }
        state_.lp = IERC20(reserveHook).balanceOf(address(bonds));
        state_.protectedState = _protectedState();
    }

    function _sweepAndCheck(bool progress_) internal returns (Vm.Log[] memory logs_) {
        SweepState memory before_ = _sweepState();
        vm.recordLogs();
        address authority_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        vm.prank(authority_);
        migration.sweepDust();
        logs_ = vm.getRecordedLogs();
        address[6] memory tokens_ = _tokens();
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            uint256 released_;
            uint256 releases_;
            uint256 received_;
            uint256 sent_;
            for (uint256 j_; j_ < logs_.length; ++j_) {
                Vm.Log memory log_ = logs_[j_];
                if (log_.emitter == detf && log_.topics.length == 2
                    && log_.topics[0] == keccak256("MigrationCapitalReleasedToResidual(address,uint256)")
                    && log_.topics[1] == bytes32(uint256(uint160(tokens_[i_])))) {
                    released_ += abi.decode(log_.data, (uint256));
                    ++releases_;
                }
                if (log_.emitter == tokens_[i_] && log_.topics.length == 3
                    && log_.topics[0] == keccak256("Transfer(address,address,uint256)")) {
                    if (log_.topics[1] == bytes32(uint256(uint160(detf)))) sent_ += abi.decode(log_.data, (uint256));
                    if (log_.topics[2] == bytes32(uint256(uint160(detf)))) received_ += abi.decode(log_.data, (uint256));
                }
            }
            uint256 expected_ = migration.isReserveLive() && tokens_[i_] != detf ? before_.booked[i_] : 0;
            assertEq(released_, expected_, "release is exactly the booked amount");
            assertEq(releases_, expected_ == 0 ? 0 : 1, "one release per token");
            assertEq(migration.migrationDonationInventory(IERC20(tokens_[i_])), before_.booked[i_] - released_);
            assertEq(IERC20(tokens_[i_]).balanceOf(detf), before_.held[i_] + received_ - sent_, "physical reconciliation");
            assertEq(Recovery(detf).migrationRecoveryInventory(tokens_[i_]), before_.recovery[i_]);
            assertEq(IERC20(tokens_[i_]).balanceOf(address(this)), before_.payer[i_], "no donor payout");
        }
        if (progress_) assertGt(IERC20(reserveHook).balanceOf(address(bonds)), before_.lp, "positive reserve LP progress");
        assertEq(_protectedState(), before_.protectedState, "no bond, supply, backing, marker or route mutation");
        _assertAllowancesCleared();
    }

    function _assertAllowancesCleared() internal view {
        address[6] memory tokens_ = _tokens();
        address[5] memory spenders_ = [reserveHook, se0, se1, address(bonds), address(receipt)];
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            for (uint256 j_; j_ < spenders_.length; ++j_) {
                assertEq(IERC20(tokens_[i_]).allowance(detf, spenders_[j_]), 0);
            }
        }
    }

    function _externalBalances() internal view returns (uint256[4] memory) {
        return [IERC20(pairA).balanceOf(detf), IERC20(pairB).balanceOf(detf),
            IERC20(se0).balanceOf(detf), IERC20(se1).balanceOf(detf)];
    }

    function _sendUnbooked() internal {
        IERC20(pairA).transfer(detf, 7 ether);
        IERC20(pairB).transfer(detf, 11 ether);
        IERC20(se0).transfer(detf, 13 ether);
        IERC20(se1).transfer(detf, 17 ether);
    }

    function _assertUnbookedDifference(uint256[4] memory clean_) internal view {
        uint256[4] memory actual_ = _externalBalances();
        uint256[4] memory unsolicited_ = [uint256(7 ether), 11 ether, 13 ether, 17 ether];
        for (uint256 i_; i_ < actual_.length; ++i_) assertEq(actual_[i_], clean_[i_] + unsolicited_[i_]);
    }
}
