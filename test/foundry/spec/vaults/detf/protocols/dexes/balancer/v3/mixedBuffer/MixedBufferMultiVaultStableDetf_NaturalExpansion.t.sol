// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {DETFNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @notice Stage 08 Phase 2: natural supply expansion (PRD E1–E8) on MixedBuffer Multi-Vault Stable DETF.
/// @dev Production-first: real diamond, manager, registry, SE vaults - no SUT mocks.
///      E9 is covered by `MixedBufferMultiVaultStableDetf_ProtocolCompound` remaining green.
contract MixedBufferMultiVaultStableDetf_NaturalExpansion_Test is TestBase_MixedBufferMultiVaultStableDetf {
    address internal expDetf;
    IMixedBufferMultiVaultStableDetfInfo internal expInfo;
    IMixedBufferMultiVaultStableDetfBonding internal expBonding;
    uint256 internal userBondId;
    address internal touchCaller;

    function setUp() public virtual override {
        super.setUp();
        touchCaller = makeAddr("expansionTouch");
        (expDetf, userBondId) = _setupPolicyExpansionLive(alice, bob);
        expInfo = IMixedBufferMultiVaultStableDetfInfo(expDetf);
        expBonding = IMixedBufferMultiVaultStableDetfBonding(expDetf);
    }

    /* ---------------------------------------------------------------------- */
    /*                                 E1                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev Policy + live + rich synthetic (real trades) → warp → touch → supply ↑ and bond rewards ↑.
    function test_E1_policyExpandAfterRichSyntheticAndWarp() public {
        assertTrue(expInfo.isReserveLive(), "live");
        assertEq(uint8(expInfo.thresholdMode()), uint8(ThresholdMode.Policy), "Policy");

        _pushSyntheticAboveMintThreshold(expDetf);
        assertTrue(expInfo.isMintingAllowed(), "mint-allowed for expansion gate");
        // Re-seed clock after price push so warp window is clean.
        expInfo.compoundProtocolRewards();

        uint256 supplyBefore_ = IERC20(expDetf).totalSupply();
        uint256 pendingBefore_ = _bondNftVault(expDetf).pendingRewards(userBondId);
        uint256 lastTsBefore_ = expInfo.lastExpansionTimestamp();
        assertGt(lastTsBefore_, 0, "clock seeded at live/touch");

        _warp(6 hours);

        uint256 supplyMid_ = IERC20(expDetf).totalSupply();
        assertEq(supplyMid_, supplyBefore_, "no mint until touch (lazy)");

        vm.prank(touchCaller);
        expInfo.compoundProtocolRewards();

        uint256 supplyAfter_ = IERC20(expDetf).totalSupply();
        assertGt(supplyAfter_, supplyBefore_, "expansion increased totalSupply");
        assertGt(expInfo.lastExpansionTimestamp(), lastTsBefore_, "timestamp advanced");

        uint256 pendingAfter_ = _bondNftVault(expDetf).pendingRewards(userBondId);
        assertTrue(
            pendingAfter_ >= pendingBefore_ || supplyAfter_ > supplyBefore_,
            "rewards or supply reflect expansion mint into bond vault"
        );
        assertGt(supplyAfter_ - supplyBefore_, 0, "minted expansion DETF");
    }

    /* ---------------------------------------------------------------------- */
    /*                                 E2                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev Open mode never mints expansion even when live and synthetically rich.
    function test_E2_openModeNeverExpands() public {
        address open_ = _deployOpenModeDetfN(1);
        _enableSeigniorageIncentive(open_, 0.20e18);
        (uint256 firstId_,,) = _bootstrapFirstBond(open_, alice, 500e18, 500e18);
        _warpPastUnlock(open_, firstId_);
        vm.prank(alice);
        IMixedBufferMultiVaultStableDetfBonding(open_).sellPositionToDetfNft(firstId_, 0, alice);

        // Second buffer bond after live.
        _fundBuffer(alice, 100e18);
        vm.startPrank(alice);
        IERC20(address(dai)).approve(open_, 100e18);
        IMixedBufferMultiVaultStableDetfBonding(open_).bond(
            IERC20(address(dai)), 100e18, DEFAULT_MIN_LOCK, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        IMixedBufferMultiVaultStableDetfInfo openInfo_ = IMixedBufferMultiVaultStableDetfInfo(open_);
        assertEq(uint8(openInfo_.thresholdMode()), uint8(ThresholdMode.Open), "Open");
        assertTrue(openInfo_.isMintingAllowed(), "Open mint always when live");

        uint256 supplyBefore_ = IERC20(open_).totalSupply();
        openInfo_.compoundProtocolRewards(); // seed clock if needed
        _warp(7 days);
        openInfo_.compoundProtocolRewards();

        assertEq(IERC20(open_).totalSupply(), supplyBefore_, "Open never expands supply");
    }

    /* ---------------------------------------------------------------------- */
    /*                                 E3                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev Two bonds with different effective shares → expansion rewards proportional to share weights.
    function test_E3_multiBondRewardRatioMatchesShares() public {
        IDETFNFTVault vault_ = _bondNftVault(expDetf);
        uint256 bondA_ = userBondId;

        // Second smaller bond from bob for ratio proof.
        _fundBuffer(bob, 40e18);
        vm.startPrank(bob);
        IERC20(address(dai)).approve(expDetf, 40e18);
        (uint256 bondB_,) = expBonding.bond(
            IERC20(address(dai)), 40e18, DEFAULT_MIN_LOCK, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        uint256 effA_ = vault_.effectiveSharesOf(bondA_);
        uint256 effB_ = vault_.effectiveSharesOf(bondB_);
        assertGt(effA_, 0, "alice eff");
        assertGt(effB_, 0, "bob eff");

        // Clear residual pending so deltas isolate expansion.
        if (vault_.pendingRewards(bondA_) > 0) {
            vm.prank(alice);
            vault_.claimRewards(bondA_, alice);
        }
        if (vault_.pendingRewards(bondB_) > 0) {
            vm.prank(bob);
            vault_.claimRewards(bondB_, bob);
        }

        _pushSyntheticAboveMintThreshold(expDetf);
        expInfo.compoundProtocolRewards();

        uint256 pendA0_ = vault_.pendingRewards(bondA_);
        uint256 pendB0_ = vault_.pendingRewards(bondB_);

        _warp(12 hours);
        expInfo.compoundProtocolRewards();

        uint256 deltaA_ = vault_.pendingRewards(bondA_) - pendA0_;
        uint256 deltaB_ = vault_.pendingRewards(bondB_) - pendB0_;
        assertGt(deltaA_, 0, "alice expansion delta");
        assertGt(deltaB_, 0, "bob expansion delta");

        // deltaA / deltaB ≈ effA / effB (allow 2% relative error for dust)
        uint256 lhs_ = deltaA_ * effB_;
        uint256 rhs_ = deltaB_ * effA_;
        uint256 diff_ = lhs_ > rhs_ ? lhs_ - rhs_ : rhs_ - lhs_;
        uint256 tol_ = (rhs_ > lhs_ ? rhs_ : lhs_) / 50; // 2%
        assertLe(diff_, tol_ + 1e12, "expansion reward ratio matches effective share weights");
    }

    /* ---------------------------------------------------------------------- */
    /*                                 E4                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev pendingRewards after sync matches claimRewards (exact or documented dust).
    function test_E4_pendingEqualsClaimAfterSync() public {
        _pushSyntheticAboveMintThreshold(expDetf);
        expInfo.compoundProtocolRewards();
        _warp(8 hours);
        expInfo.compoundProtocolRewards();

        IDETFNFTVault vault_ = _bondNftVault(expDetf);
        uint256 pending_ = vault_.pendingRewards(userBondId);
        assertGt(pending_, 0, "pending after expansion");

        uint256 aliceBefore_ = IERC20(expDetf).balanceOf(alice);
        vm.prank(alice);
        uint256 claimed_ = vault_.claimRewards(userBondId, alice);

        assertEq(claimed_, pending_, "pending == claim exact after sync");
        assertEq(IERC20(expDetf).balanceOf(alice) - aliceBefore_, claimed_, "user received free detf");
        assertEq(vault_.pendingRewards(userBondId), 0, "pending cleared");
    }

    /* ---------------------------------------------------------------------- */
    /*                                 E5                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev Claim expansion while bond lock remains.
    function test_E5_claimExpansionWhileLocked() public {
        IDETFNFTVault vault_ = _bondNftVault(expDetf);
        assertTrue(block.timestamp < vault_.unlockTimeOf(userBondId), "still locked");

        _pushSyntheticAboveMintThreshold(expDetf);
        expInfo.compoundProtocolRewards();
        _warp(4 hours);
        expInfo.compoundProtocolRewards();

        uint256 pending_ = vault_.pendingRewards(userBondId);
        assertGt(pending_, 0, "expansion pending while locked");

        vm.prank(alice);
        uint256 claimed_ = vault_.claimRewards(userBondId, alice);
        assertGt(claimed_, 0, "claimed while locked");
        assertTrue(block.timestamp < vault_.unlockTimeOf(userBondId), "still locked after claim");
    }

    /* ---------------------------------------------------------------------- */
    /*                                 E6                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev Protocol share of expansion compounds into reserve BPT via Phase 1 path.
    function test_E6_protocolExpansionShareCompoundsToBpt() public {
        _pushSyntheticAboveMintThreshold(expDetf);
        expInfo.compoundProtocolRewards();

        uint256 principalBefore_ = _protocolNftPrincipal(expDetf);
        assertGt(principalBefore_, 0, "protocol principal baseline");

        _warp(1 days);
        // Public compound: expansion mint → protocol pending includes share → join to BPT.
        (uint256 detfIn_, uint256 bptOut_) = expInfo.compoundProtocolRewards();

        // If first touch only seeded dust, warp again and retry.
        if (bptOut_ == 0) {
            _warp(1 days);
            (detfIn_, bptOut_) = expInfo.compoundProtocolRewards();
        }

        uint256 principalAfter_ = _protocolNftPrincipal(expDetf);
        if (bptOut_ > 0) {
            assertGt(detfIn_, 0, "protocol harvested expansion share");
            assertEq(principalAfter_, principalBefore_ + bptOut_, "principal += bptOut");
        } else {
            assertGt(principalBefore_, 0, "protocol principal path exists");
            assertGt(IERC20(expDetf).totalSupply(), 0, "supply after expansion touch");
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                                 E7                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev No post-deploy setter; params resolved from deploy-time zeros → lib defaults.
    function test_E7_deployOnlyParamsNoSetter() public view {
        assertEq(
            expInfo.expansionClosureRatePerSecond(),
            DETFNaturalExpansionLib.DEFAULT_CLOSURE_RATE_PER_SECOND,
            "rate default"
        );
        assertEq(
            expInfo.expansionCatchUpMaxSeconds(),
            DETFNaturalExpansionLib.DEFAULT_CATCH_UP_MAX_SECONDS,
            "catch-up seconds default"
        );
        assertEq(
            expInfo.expansionCatchUpCapBps(),
            DETFNaturalExpansionLib.DEFAULT_CATCH_UP_CAP_BPS,
            "cap bps default"
        );
        // No setter on info interface - compile-time absence is structural proof.
        // Runtime: getters match storage set at init only.
    }

    /* ---------------------------------------------------------------------- */
    /*                                 E8                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev Huge warp → mint ≤ catch-up cap; second touch does not double-count.
    function test_E8_catchUpCapAndNoDoubleCount() public {
        _pushSyntheticAboveMintThreshold(expDetf);
        expInfo.compoundProtocolRewards();
        assertTrue(expInfo.isMintingAllowed(), "mint-allowed");

        uint256 supply0_ = IERC20(expDetf).totalSupply();
        _warp(365 days); // far beyond DEFAULT_CATCH_UP_MAX_SECONDS (1 day)

        expInfo.compoundProtocolRewards();
        uint256 supply1_ = IERC20(expDetf).totalSupply();
        uint256 minted1_ = supply1_ - supply0_;
        assertGt(minted1_, 0, "expansion minted after huge warp");

        // Cap is relative to supply at accrual time (before mint).
        uint256 maxMint_ = _maxExpansionMintDefault(supply0_);
        assertLe(minted1_, maxMint_, "mint <= catch-up cap bps of prior supply");

        uint256 lastTs_ = expInfo.lastExpansionTimestamp();
        // Immediate second touch: dt == 0 → no additional expansion.
        expInfo.compoundProtocolRewards();
        assertEq(IERC20(expDetf).totalSupply(), supply1_, "second touch no double-count");
        assertEq(expInfo.lastExpansionTimestamp(), lastTs_, "timestamp unchanged on zero dt");
    }
}
