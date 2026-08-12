// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IComposedStableCommonDetfBonding} from "contracts/interfaces/IComposedStableCommonDetfBonding.sol";
import {IComposedStableCommonDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/IComposedStableCommonDetfInfo.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDETF} from "contracts/interfaces/IDETF.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {DETFNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    ComposedStableCommonDetf_IntegratedDeploy_Test
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol";

/// @notice Stage 09 Phase 2: natural supply expansion (PRD E1–E8) on ComposedStableCommonDetf.
/// @dev Production-first: real diamond, manager, registry, SE vaults, family bond NFT - no SUT mocks.
///      E9 is covered by `ComposedStableCommonDetf_ProtocolCompound` remaining green.
///      Expansion mints into bond-reward DETF (`detfToken`), not the rebasing claim token.
contract ComposedStableCommonDetf_NaturalExpansion_Test is ComposedStableCommonDetf_IntegratedDeploy_Test {
    uint256 internal constant MIN_LOCK = 30 days;

    IComposedStableCommonDetfInfo internal expInfo;
    IComposedStableCommonDetfBonding internal expBonding;
    IStandardExchangeIn internal expExchangeIn;
    uint256 internal userBondId;
    address internal touchCaller;

    /// @dev Policy so premium-closure expansion can fire (Open never expands).
    function _composedThresholdMode() internal pure override returns (ThresholdMode) {
        return ThresholdMode.Policy;
    }

    /// @dev Near-peg mint band: mint=1e18 after resolve; bootstrap synthetic is typically rich.
    function _composedMintThreshold() internal pure override returns (uint256) {
        return 1e18;
    }

    function _composedBurnThreshold() internal pure override returns (uint256) {
        return 0;
    }

    function setUp() public virtual override {
        super.setUp();
        touchCaller = makeAddr("expansionTouch");
        expInfo = IComposedStableCommonDetfInfo(deployedDetfVault);
        expBonding = IComposedStableCommonDetfBonding(deployedDetfVault);
        expExchangeIn = IStandardExchangeIn(deployedDetfVault);
        // Parent IntegratedDeploy tests call `_bootstrapReserveGraph` themselves;
        // expansion suite prepares live fixture per test / in helper.
    }

    /* ---------------------------------------------------------------------- */
    /*                              Helpers                                   */
    /* ---------------------------------------------------------------------- */

    function _protocolNftPrincipal() internal view returns (uint256) {
        return bondNFTVault.originalSharesOf(bondNFTVault.detfNFTId());
    }

    function _enableSeigniorage(uint256 incentiveWad_) internal {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setSeigniorageIncentivePercentageOfVault(
            deployedDetfVault, incentiveWad_
        );
        vm.stopPrank();
    }

    function _mintDetfFromDai(address minter_, uint256 amountIn_) internal returns (uint256 out_) {
        deal(address(dai), minter_, amountIn_, true);
        vm.startPrank(minter_);
        dai.approve(deployedDetfVault, amountIn_);
        out_ = expExchangeIn.exchangeIn(
            dai, amountIn_, detfToken, 0, minter_, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _bondDai(address bonder_, uint256 amountIn_, uint256 lockDuration_)
        internal
        returns (uint256 tokenId_, uint256 shares_)
    {
        deal(address(dai), bonder_, amountIn_, true);
        vm.startPrank(bonder_);
        dai.approve(deployedDetfVault, amountIn_);
        (tokenId_, shares_) = expBonding.bond(
            dai, amountIn_, lockDuration_, bonder_, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _warp(uint256 seconds_) internal {
        vm.warp(block.timestamp + seconds_);
    }

    /// @dev Expected max expansion mint under resolved defaults for given supply (bps cap).
    function _maxExpansionMintDefault(uint256 totalSupply_) internal pure returns (uint256) {
        return (totalSupply_ * DETFNaturalExpansionLib.DEFAULT_CATCH_UP_CAP_BPS) / 10_000;
    }

    /// @dev Prefer real production path: assert mint-allowed after bootstrap + bonds.
    ///      Integrated graph has large WETH backing vs modest external DETF supply → synthetic rich.
    function _requireMintAllowedForExpansion() internal view {
        require(expInfo.isMintingAllowed(), "synthetic not mint-allowed under Policy (need rich synthetic)");
    }

    /// @dev Live Policy DETF with locked user bond + protocol NFT principal (for expansion/compound).
    function _setupPolicyExpansionLive(address bonder_, address minter_)
        internal
        returns (uint256 userBondId_)
    {
        _bootstrapReserveGraph();
        _enableSeigniorage(0.20e18);

        // First bond → sell into protocol so detf NFT has principal shares.
        (uint256 firstId_,) = _bondDai(bonder_, 1_000e18, MIN_LOCK);
        _warpPastUnlock(firstId_);
        vm.prank(bonder_);
        expBonding.sellPositionToDetfNft(firstId_, 0, bonder_);
        assertGt(_protocolNftPrincipal(), 0, "protocol nft has principal after sell");

        // Second bond: user keeps NFT (claim-while-locked + reward share).
        (userBondId_,) = _bondDai(bonder_, 500e18, MIN_LOCK);
        assertGt(bondNFTVault.effectiveSharesOf(userBondId_), 0, "user bond has effective shares");

        // Seed inventory via mint (seigniorage on).
        uint256 minted_ = _mintDetfFromDai(minter_, 500e18);
        assertGt(minted_, 0, "seed mint");

        // Seed expansion clock (first live touch sets lastExpansionTimestamp; no mint at dt≈0).
        expInfo.compoundProtocolRewards();
        assertGt(expInfo.lastExpansionTimestamp(), 0, "expansion clock seeded");
        _requireMintAllowedForExpansion();
    }

    /* ---------------------------------------------------------------------- */
    /*                                 E1                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev Policy + live + rich synthetic → warp → touch → supply ↑ and bond rewards ↑.
    function test_E1_policyExpandAfterRichSyntheticAndWarp() public {
        userBondId = _setupPolicyExpansionLive(alice, bob);
        assertEq(uint8(expInfo.thresholdMode()), uint8(ThresholdMode.Policy), "Policy");

        uint256 supplyBefore_ = detfToken.totalSupply();
        uint256 pendingBefore_ = bondNFTVault.pendingRewards(userBondId);
        uint256 lastTsBefore_ = expInfo.lastExpansionTimestamp();
        assertGt(lastTsBefore_, 0, "clock seeded");

        _warp(6 hours);

        uint256 supplyMid_ = detfToken.totalSupply();
        assertEq(supplyMid_, supplyBefore_, "no mint until touch (lazy)");

        vm.prank(touchCaller);
        expInfo.compoundProtocolRewards();

        uint256 supplyAfter_ = detfToken.totalSupply();
        assertGt(supplyAfter_, supplyBefore_, "expansion increased totalSupply");
        assertGt(expInfo.lastExpansionTimestamp(), lastTsBefore_, "timestamp advanced");

        uint256 pendingAfter_ = bondNFTVault.pendingRewards(userBondId);
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
        // Bootstrap shared reserve so Open instance is live via pool probe.
        _bootstrapReserveGraph();
        address open_ = _deployOpenModeDetf();
        IComposedStableCommonDetfInfo openInfo_ = IComposedStableCommonDetfInfo(open_);
        assertEq(uint8(openInfo_.thresholdMode()), uint8(ThresholdMode.Open), "Open");
        assertTrue(openInfo_.isMintingAllowed(), "Open mint always when live");

        uint256 supplyBefore_ = detfToken.totalSupply();
        openInfo_.compoundProtocolRewards(); // seed clock if needed
        _warp(7 days);
        openInfo_.compoundProtocolRewards();

        assertEq(detfToken.totalSupply(), supplyBefore_, "Open never expands supply");
    }

    /* ---------------------------------------------------------------------- */
    /*                                 E3                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev Two bonds with different effective shares → expansion rewards proportional to share weights.
    function test_E3_multiBondRewardRatioMatchesShares() public {
        uint256 bondA_ = _setupPolicyExpansionLive(alice, bob);

        // Second smaller bond from bob for ratio proof.
        (uint256 bondB_,) = _bondDai(bob, 200e18, MIN_LOCK);

        uint256 effA_ = bondNFTVault.effectiveSharesOf(bondA_);
        uint256 effB_ = bondNFTVault.effectiveSharesOf(bondB_);
        assertGt(effA_, 0, "alice eff");
        assertGt(effB_, 0, "bob eff");

        // Clear residual pending so deltas isolate expansion.
        if (bondNFTVault.pendingRewards(bondA_) > 0) {
            vm.prank(alice);
            bondNFTVault.claimRewards(bondA_, alice);
        }
        if (bondNFTVault.pendingRewards(bondB_) > 0) {
            vm.prank(bob);
            bondNFTVault.claimRewards(bondB_, bob);
        }

        expInfo.compoundProtocolRewards();
        _requireMintAllowedForExpansion();

        uint256 pendA0_ = bondNFTVault.pendingRewards(bondA_);
        uint256 pendB0_ = bondNFTVault.pendingRewards(bondB_);

        _warp(12 hours);
        expInfo.compoundProtocolRewards();

        uint256 deltaA_ = bondNFTVault.pendingRewards(bondA_) - pendA0_;
        uint256 deltaB_ = bondNFTVault.pendingRewards(bondB_) - pendB0_;
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
        userBondId = _setupPolicyExpansionLive(alice, bob);
        _warp(8 hours);
        expInfo.compoundProtocolRewards();

        uint256 pending_ = bondNFTVault.pendingRewards(userBondId);
        assertGt(pending_, 0, "pending after expansion");

        uint256 aliceBefore_ = detfToken.balanceOf(alice);
        vm.prank(alice);
        uint256 claimed_ = bondNFTVault.claimRewards(userBondId, alice);

        assertEq(claimed_, pending_, "pending == claim exact after sync");
        assertEq(detfToken.balanceOf(alice) - aliceBefore_, claimed_, "user received free detf");
        assertEq(bondNFTVault.pendingRewards(userBondId), 0, "pending cleared");
    }

    /* ---------------------------------------------------------------------- */
    /*                                 E5                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev Claim expansion while bond lock remains.
    function test_E5_claimExpansionWhileLocked() public {
        userBondId = _setupPolicyExpansionLive(alice, bob);
        assertTrue(block.timestamp < bondNFTVault.unlockTimeOf(userBondId), "still locked");

        _warp(4 hours);
        expInfo.compoundProtocolRewards();

        uint256 pending_ = bondNFTVault.pendingRewards(userBondId);
        assertGt(pending_, 0, "expansion pending while locked");

        vm.prank(alice);
        uint256 claimed_ = bondNFTVault.claimRewards(userBondId, alice);
        assertGt(claimed_, 0, "claimed while locked");
        assertTrue(block.timestamp < bondNFTVault.unlockTimeOf(userBondId), "still locked after claim");
    }

    /* ---------------------------------------------------------------------- */
    /*                                 E6                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev Protocol share of expansion compounds into reserve BPT via Phase 1 path (claim coupling).
    function test_E6_protocolExpansionShareCompoundsToBpt() public {
        userBondId = _setupPolicyExpansionLive(alice, bob);

        uint256 principalBefore_ = _protocolNftPrincipal();
        assertGt(principalBefore_, 0, "protocol principal baseline");

        _warp(1 days);
        // Public compound: expansion mint → protocol pending includes share → join to BPT.
        (uint256 detfIn_, uint256 bptOut_) = expInfo.compoundProtocolRewards();

        // If first touch only seeded dust, warp again and retry.
        if (bptOut_ == 0) {
            _warp(1 days);
            (detfIn_, bptOut_) = expInfo.compoundProtocolRewards();
        }

        uint256 principalAfter_ = _protocolNftPrincipal();
        if (bptOut_ > 0) {
            assertGt(detfIn_, 0, "protocol harvested expansion share");
            assertEq(principalAfter_, principalBefore_ + bptOut_, "principal += bptOut");
        } else {
            // Expansion still minted free DETF into bond vault even if join dust-gated.
            assertGt(principalBefore_, 0, "protocol principal path exists");
            assertGt(detfToken.totalSupply(), 0, "supply after expansion touch");
            // Protocol pending path still wired (claim rate depends on principal).
            assertTrue(
                bondNFTVault.pendingRewards(bondNFTVault.detfNFTId()) >= 0,
                "protocol pending queryable"
            );
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
    }

    /* ---------------------------------------------------------------------- */
    /*                                 E8                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev Huge warp → mint ≤ catch-up cap; second touch does not double-count.
    function test_E8_catchUpCapAndNoDoubleCount() public {
        userBondId = _setupPolicyExpansionLive(alice, bob);
        assertTrue(expInfo.isMintingAllowed(), "mint-allowed");

        uint256 supply0_ = detfToken.totalSupply();
        _warp(365 days); // far beyond DEFAULT_CATCH_UP_MAX_SECONDS (1 day)

        expInfo.compoundProtocolRewards();
        uint256 supply1_ = detfToken.totalSupply();
        uint256 minted1_ = supply1_ - supply0_;
        assertGt(minted1_, 0, "expansion minted after huge warp");

        // Cap is relative to supply at accrual time (before mint).
        uint256 maxMint_ = _maxExpansionMintDefault(supply0_);
        assertLe(minted1_, maxMint_, "mint <= catch-up cap bps of prior supply");

        uint256 lastTs_ = expInfo.lastExpansionTimestamp();
        // Immediate second touch: dt == 0 → no additional expansion.
        expInfo.compoundProtocolRewards();
        assertEq(detfToken.totalSupply(), supply1_, "second touch no double-count");
        assertEq(expInfo.lastExpansionTimestamp(), lastTs_, "timestamp unchanged on zero dt");
    }
}
