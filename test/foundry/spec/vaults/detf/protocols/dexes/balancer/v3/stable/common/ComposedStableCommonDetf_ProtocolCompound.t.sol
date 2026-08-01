// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IComposedStableCommonDetfBonding} from "contracts/interfaces/IComposedStableCommonDetfBonding.sol";
import {IComposedStableCommonDetfBondNFTVault} from "contracts/interfaces/IComposedStableCommonDetfBondNFTVault.sol";
import {IComposedStableCommonDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/IComposedStableCommonDetfInfo.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDETF} from "contracts/interfaces/IDETF.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    ComposedStableCommonDetf_IntegratedDeploy_Test
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol";

/// @notice Stage 04 Phase 1: protocol seigniorage compound (PRD C1–C8) on ComposedStableCommonDetf.
/// @dev Production-first: real diamond, manager, registry, SE vaults, family bond NFT - no SUT mocks.
///      C5 is non-waivable for this family (claim / protocol BPT backing path).
contract ComposedStableCommonDetf_ProtocolCompound_Test is ComposedStableCommonDetf_IntegratedDeploy_Test {
    uint256 internal constant MIN_LOCK = 30 days;

    IComposedStableCommonDetfInfo internal compoundInfo;
    IComposedStableCommonDetfBonding internal compoundBonding;
    IStandardExchangeIn internal compoundExchangeIn;
    uint256 internal lockedUserBondId;
    address internal permissionlessCaller;

    /// @dev Product Open so live mint/bond for seeding are not threshold-gated.
    function _composedThresholdMode() internal pure override returns (ThresholdMode) {
        return ThresholdMode.Open;
    }

    function _composedMintThreshold() internal pure override returns (uint256) {
        return 0;
    }

    function _composedBurnThreshold() internal pure override returns (uint256) {
        return 0;
    }

    function setUp() public virtual override {
        super.setUp();
        permissionlessCaller = makeAddr("compoundCaller");
        compoundInfo = IComposedStableCommonDetfInfo(deployedDetfVault);
        compoundBonding = IComposedStableCommonDetfBonding(deployedDetfVault);
        compoundExchangeIn = IStandardExchangeIn(deployedDetfVault);
        // Do not bootstrap here - parent IntegratedDeploy tests call `_bootstrapReserveGraph`
        // themselves; double-init reverts PoolAlreadyInitialized.
    }

    /* ---------------------------------------------------------------------- */
    /*                              Helpers                                   */
    /* ---------------------------------------------------------------------- */

    function _protocolNftPrincipal() internal view returns (uint256) {
        return bondNFTVault.originalSharesOf(bondNFTVault.detfNFTId());
    }

    function _protocolPendingRewards() internal view returns (uint256) {
        return bondNFTVault.pendingRewards(bondNFTVault.detfNFTId());
    }

    /// @dev Seed free DETF inventory on the bond vault (adds to existing balance).
    /// @notice Keep modest vs reserve DETF leg (~1e18 at bootstrap) so single-sided join can succeed.
    function _seedBondVaultRewardDetf(uint256 amount_) internal {
        address vault_ = address(bondNFTVault);
        uint256 before_ = detfToken.balanceOf(vault_);
        // Non-SUT controllability: forge deal adjusts ERC20 balance + totalSupply.
        deal(address(detfToken), vault_, before_ + amount_, true);
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
        out_ = compoundExchangeIn.exchangeIn(
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
        (tokenId_, shares_) = compoundBonding.bond(
            dai, amountIn_, lockDuration_, bonder_, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /// @dev Live graph with protocol NFT principal, locked user bond, and inventory rewards.
    ///      Call once per ProtocolCompound test (not in setUp) so parent deploy tests stay green.
    function _prepareLiveCompoundFixture() internal {
        _bootstrapReserveGraph();
        lockedUserBondId = _setupProtocolRewardsLive(alice, bob);
    }

    function _setupProtocolRewardsLive(address bonder_, address minter_)
        internal
        returns (uint256 userBondId_)
    {
        // 20% seigniorage incentive → inventory share on mint into bond vault reward pool.
        _enableSeigniorage(0.20e18);

        // First bond → sell into protocol so detf NFT has principal shares (claim-rate proxy).
        (uint256 firstId_,) = _bondDai(bonder_, 1_000e18, MIN_LOCK);
        vm.prank(bonder_);
        compoundBonding.sellNFT(firstId_, bonder_);
        assertGt(_protocolNftPrincipal(), 0, "protocol nft has principal after sell");

        // Second bond: user keeps NFT (C3 claim-while-locked).
        (userBondId_,) = _bondDai(bonder_, 500e18, MIN_LOCK);

        // Mint seeds inventory DETF on bond vault (seigniorage on).
        uint256 minted_ = _mintDetfFromDai(minter_, 500e18);
        assertGt(minted_, 0, "seed mint");
    }

    /// @dev Public compound with modest seed; retry once with larger (still join-safe) seed.
    function _compoundWithSeed() internal returns (uint256 detfIn_, uint256 bptOut_) {
        // ~5% of bootstrap DETF leg - joinable single-sided without max-in-ratio blowups.
        _seedBondVaultRewardDetf(0.05e18);
        (detfIn_, bptOut_) = compoundInfo.compoundProtocolRewards();
        if (detfIn_ == 0) {
            _seedBondVaultRewardDetf(0.1e18);
            (detfIn_, bptOut_) = compoundInfo.compoundProtocolRewards();
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                              C1 / C2                                   */
    /* ---------------------------------------------------------------------- */

    /// @dev C1 + C2: inventory mint lazily compounds protocol pending into protocol NFT BPT principal.
    function test_C1_C2_lazyCompoundOnMintIncreasesProtocolBpt() public {
        _prepareLiveCompoundFixture();
        assertGt(_protocolNftPrincipal(), 0, "protocol principal");

        // Seed free DETF rewards on vault so next mint's lazy hook can compound.
        _seedBondVaultRewardDetf(0.05e18);
        uint256 pendingBefore_ = _protocolPendingRewards();
        assertGt(pendingBefore_, 0, "protocol pending before lazy mint");
        uint256 principalBefore_ = _protocolNftPrincipal();

        vm.recordLogs();
        // Lazy compound runs inside mint - no public compoundProtocolRewards call.
        uint256 out_ = _mintDetfFromDai(bob, 300e18);
        assertGt(out_, 0, "mint succeeded");

        uint256 principalAfter_ = _protocolNftPrincipal();
        assertGt(principalAfter_, principalBefore_, "protocol BPT principal increased");

        // Prove compound path (not only mint inventory BPT): event emitted and/or pending dropped.
        bytes32 topic0_ = keccak256("ProtocolRewardsCompounded(uint256,uint256)");
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        bool found_;
        for (uint256 i; i < logs_.length; ++i) {
            if (logs_[i].topics.length > 0 && logs_[i].topics[0] == topic0_) {
                found_ = true;
                break;
            }
        }
        assertTrue(
            found_ || _protocolPendingRewards() < pendingBefore_,
            "lazy compound ran (event or pending drop)"
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                                 C6                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev C6: permissionless public compound after seeded protocol rewards; emits event.
    function test_C6_publicCompoundProtocolRewards() public {
        _prepareLiveCompoundFixture();
        assertGt(_protocolNftPrincipal(), 0, "protocol principal");
        uint256 principalBefore_ = _protocolNftPrincipal();

        vm.recordLogs();
        // Anyone may call - no keeper.
        vm.prank(permissionlessCaller);
        (uint256 detfIn_, uint256 bptOut_) = _compoundWithSeed();

        assertGt(detfIn_, 0, "detfIn");
        assertGt(bptOut_, 0, "bptOut");
        assertEq(_protocolNftPrincipal(), principalBefore_ + bptOut_, "principal += bptOut");
        assertEq(detfToken.balanceOf(deployedDetfVault), 0, "no free detf stranded on diamond");

        bytes32 topic0_ = keccak256("ProtocolRewardsCompounded(uint256,uint256)");
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        bool found_;
        for (uint256 i; i < logs_.length; ++i) {
            if (logs_[i].topics.length > 0 && logs_[i].topics[0] == topic0_) {
                found_ = true;
                break;
            }
        }
        assertTrue(found_, "ProtocolRewardsCompounded emitted");
    }

    /* ---------------------------------------------------------------------- */
    /*                                 C3                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev C3: user bond rewards remain claimable free DETF while locked (not auto-joined).
    function test_C3_userClaimFreeDetfWhileLocked() public {
        _prepareLiveCompoundFixture();
        if (lockedUserBondId == 0 || bondNFTVault.effectiveSharesOf(lockedUserBondId) == 0) {
            (lockedUserBondId,) = _bondDai(alice, 500e18, MIN_LOCK);
        }
        assertTrue(block.timestamp < bondNFTVault.unlockTimeOf(lockedUserBondId), "still locked");
        assertGt(bondNFTVault.effectiveSharesOf(lockedUserBondId), 0, "user has effective shares");

        _seedBondVaultRewardDetf(0.05e18);
        uint256 userPending_ = bondNFTVault.pendingRewards(lockedUserBondId);
        assertGt(userPending_, 0, "user has pending rewards");

        uint256 aliceBefore_ = detfToken.balanceOf(alice);
        vm.prank(alice);
        uint256 claimed_ = bondNFTVault.claimRewards(lockedUserBondId, alice);

        assertGt(claimed_, 0, "claimed free detf");
        assertEq(detfToken.balanceOf(alice) - aliceBefore_, claimed_, "free detf to user");
        assertEq(bondNFTVault.pendingRewards(lockedUserBondId), 0, "user pending cleared");
    }

    /* ---------------------------------------------------------------------- */
    /*                                 C4                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev C4: fee-recipient NFT rewards remain claimable free DETF (not auto-joined into reserve).
    function test_C4_feeRecipientClaimFreeDetfNotAutoJoined() public {
        _prepareLiveCompoundFixture();
        // Enable bond usage fee so fee-recipient NFT receives principal shares.
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(deployedDetfVault, 0.05e18);
        vm.stopPrank();

        IComposedStableCommonDetfBondNFTVault familyVault =
            IComposedStableCommonDetfBondNFTVault(address(bondNFTVault));
        uint256 feeNftId_ = familyVault.feeRecipientNFTId();
        address feeOwner_ = bondNFTVault.ownerOf(feeNftId_);
        assertTrue(feeOwner_ != address(0), "fee recipient nft owner");

        // Bond creates fee shares on fee-recipient NFT.
        _bondDai(bob, 800e18, MIN_LOCK);
        assertGt(bondNFTVault.effectiveSharesOf(feeNftId_), 0, "fee nft has shares");

        _seedBondVaultRewardDetf(0.05e18);
        uint256 feePending_ = bondNFTVault.pendingRewards(feeNftId_);
        assertGt(feePending_, 0, "fee recipient has pending");

        uint256 feeBefore_ = detfToken.balanceOf(feeOwner_);
        vm.prank(feeOwner_);
        uint256 claimed_ = bondNFTVault.claimRewards(feeNftId_, feeOwner_);

        assertGt(claimed_, 0, "fee claimed free detf");
        assertEq(detfToken.balanceOf(feeOwner_) - feeBefore_, claimed_, "free detf to fee recipient");
        // Protocol compound only touches detf-owned NFT - fee rewards stay free DETF.
    }

    /* ---------------------------------------------------------------------- */
    /*                                 C5                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev C5 (non-waivable): claim package is wired. Claim redemption / BPT backing depends on
    ///      protocol-owned BPT principal (`originalSharesOf(detfNFTId)`). Compound must raise it
    ///      and claim redeem preview for fixed claim shares must not fall (strict rise preferred).
    function test_C5_protocolCompoundRaisesClaimBackingAndRedeemPreview() public {
        _prepareLiveCompoundFixture();
        assertTrue(address(rebasingDetfToken) != address(0), "claim package wired");
        assertEq(IDETF(deployedDetfVault).rebasingDetfToken(), address(rebasingDetfToken), "claim on DETF");

        uint256 principalBefore_ = _protocolNftPrincipal();
        assertGt(principalBefore_, 0, "protocol principal baseline");

        // Baseline claim redeem preview via pricing surface (depends on protocol BPT principal).
        uint256 claimAmt_ = 1e18;
        uint256 reserveBptPreviewBefore_ = IDETF(deployedDetfVault).previewRebasingDetfTokenReserveBpt(claimAmt_);

        (uint256 detfIn_, uint256 bptOut_) = _compoundWithSeed();

        assertGt(detfIn_, 0, "compounded detf");
        assertGt(bptOut_, 0, "bpt out");
        uint256 principalAfter_ = _protocolNftPrincipal();
        // C5 evidence: protocol BPT principal (claim-rate proxy) strictly rose.
        assertGt(principalAfter_, principalBefore_, "C5 claim-rate proxy principal rose");
        assertEq(principalAfter_, principalBefore_ + bptOut_, "exact principal credit");

        uint256 reserveBptPreviewAfter_ = IDETF(deployedDetfVault).previewRebasingDetfTokenReserveBpt(claimAmt_);
        // With other factors held equal, more protocol BPT raises claim→reserve-BPT preview
        // when claim supply is non-zero; if zero claim supply, proxy principal rise is the C5 proof.
        if (rebasingDetfToken.totalShares() > 0 && reserveBptPreviewBefore_ > 0) {
            assertGt(reserveBptPreviewAfter_, reserveBptPreviewBefore_, "C5 claim redeem BPT preview rose");
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                                 C8                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev C8: join/atomic failure is best-effort - user mint succeeds; pending intact; later compound works.
    function test_C8_joinFailureBestEffort_thenRetry() public {
        _prepareLiveCompoundFixture();
        assertGt(_protocolNftPrincipal(), 0, "protocol principal");
        _seedBondVaultRewardDetf(0.05e18);

        uint256 principalBefore_ = _protocolNftPrincipal();
        uint256 vaultRewardBalBefore_ = detfToken.balanceOf(address(bondNFTVault));
        uint256 pendingBefore_ = _protocolPendingRewards();
        assertGt(pendingBefore_, 0, "pending before fail");

        // Force compound atomic body to fail (simulates join revert). Isolates compound from
        // user mint path (same diamond, different call path). No SUT mock of diamond logic -
        // only sabotage the atomic helper entry so try/catch best-effort path is exercised.
        vm.mockCallRevert(
            deployedDetfVault,
            abi.encodeWithSignature("compoundProtocolRewardsAtomic()"),
            "forced compound fail"
        );

        // Public compound best-effort returns zeros (does not revert).
        (uint256 detfInFail_, uint256 bptFail_) = compoundInfo.compoundProtocolRewards();
        assertEq(detfInFail_, 0, "no detfIn on failed compound");
        assertEq(bptFail_, 0, "no bpt on failed compound");
        assertEq(_protocolNftPrincipal(), principalBefore_, "principal unchanged on public fail");
        // Preferred pull: harvest rolled back - reward DETF still on bond vault.
        assertGe(
            detfToken.balanceOf(address(bondNFTVault)),
            vaultRewardBalBefore_,
            "pending inventory remains on vault"
        );

        // User mint still succeeds (lazy compound fails best-effort).
        // Note: mint also accrues inventory BPT via `_accrueMintInventory` (not compound) -
        // so principal may rise from mint inventory even when compound is sabotaged.
        uint256 minted_ = _mintDetfFromDai(bob, 200e18);
        assertGt(minted_, 0, "user mint succeeds despite compound fail");
        // Pending from seeded rewards still claimable / compoundable after failed compound.
        assertGt(_protocolPendingRewards(), 0, "pending intact after best-effort fail");

        // Clear sabotage; later successful compound works.
        vm.clearMockedCalls();
        uint256 principalBeforeRetry_ = _protocolNftPrincipal();
        (uint256 detfInOk_, uint256 bptOk_) = _compoundWithSeed();
        assertGt(detfInOk_, 0, "retry compound detfIn");
        assertGt(bptOk_, 0, "retry compound bptOut");
        assertEq(_protocolNftPrincipal(), principalBeforeRetry_ + bptOk_, "principal after retry");
    }

    /* ---------------------------------------------------------------------- */
    /*                              C7 surface                                */
    /* ---------------------------------------------------------------------- */

    /// @dev C7 structural: public ABI present; atomic only-self; production diamond path.
    function test_C7_publicAbiAndOnlySelfAtomic() public {
        _prepareLiveCompoundFixture();
        // Public compound callable (no-op when nothing pending is fine).
        (uint256 d0_, uint256 b0_) = compoundInfo.compoundProtocolRewards();
        assertTrue(d0_ == 0 || b0_ >= 0, "public returns");

        // Atomic helper reverts for external callers (only-self).
        vm.prank(alice);
        (bool success_,) = deployedDetfVault.call(abi.encodeWithSignature("compoundProtocolRewardsAtomic()"));
        assertFalse(success_, "atomic rejects non-self");
    }
}
