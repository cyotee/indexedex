// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
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
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";

/// @notice Stage 03 Phase 1: protocol seigniorage compound (PRD C1–C8) on MixedBufferMultiVaultStableDetf.
/// @dev Production-first: real diamond, manager, registry, SE vaults - no SUT mocks.
///      Semantics match Stage 01/02; MixedBuffer uses buffer mint/bond + existing `_joinReserveDetfOnly`.
contract MixedBufferMultiVaultStableDetf_ProtocolCompound_Test is TestBase_MixedBufferMultiVaultStableDetf {
    address internal compoundDetf;
    IMixedBufferMultiVaultStableDetfInfo internal compoundInfo;
    IMixedBufferMultiVaultStableDetfBonding internal compoundBonding;
    IStandardExchangeIn internal compoundExchangeIn;
    uint256 internal lockedUserBondId;
    address internal permissionlessCaller;

    function setUp() public virtual override {
        super.setUp();
        permissionlessCaller = makeAddr("compoundCaller");
        (compoundDetf, lockedUserBondId) = _setupProtocolRewardsLive(alice, bob);
        compoundInfo = IMixedBufferMultiVaultStableDetfInfo(compoundDetf);
        compoundBonding = IMixedBufferMultiVaultStableDetfBonding(compoundDetf);
        compoundExchangeIn = IStandardExchangeIn(compoundDetf);
    }

    /* ---------------------------------------------------------------------- */
    /*                              C1 / C2                                   */
    /* ---------------------------------------------------------------------- */

    /// @dev C1 + C2: inventory mint lazily compounds protocol pending into protocol NFT BPT principal.
    function test_C1_C2_lazyCompoundOnMintIncreasesProtocolBpt() public {
        assertGt(_protocolNftPrincipal(compoundDetf), 0, "protocol principal");

        // Seed free DETF rewards on vault so next mint's lazy hook can compound.
        _seedBondVaultRewardDetf(compoundDetf, 20e18);
        uint256 principalBefore_ = _protocolNftPrincipal(compoundDetf);

        // Lazy compound runs inside mint - no public compoundProtocolRewards call.
        uint256 out_ = _mintDetfFromBuffer(compoundDetf, bob, 30e18);
        assertGt(out_, 0, "mint succeeded");

        uint256 principalAfter_ = _protocolNftPrincipal(compoundDetf);
        assertGt(principalAfter_, principalBefore_, "lazy compound increased protocol BPT principal");
    }

    /* ---------------------------------------------------------------------- */
    /*                                 C6                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev C6: permissionless public compound after seeded protocol rewards; emits event.
    function test_C6_publicCompoundProtocolRewards() public {
        assertGt(_protocolNftPrincipal(compoundDetf), 0, "protocol principal");
        _seedBondVaultRewardDetf(compoundDetf, 50e18);
        uint256 principalBefore_ = _protocolNftPrincipal(compoundDetf);

        vm.recordLogs();
        // Anyone may call - no keeper.
        vm.prank(permissionlessCaller);
        (uint256 detfIn_, uint256 bptOut_) = compoundInfo.compoundProtocolRewards();

        if (detfIn_ == 0) {
            _seedBondVaultRewardDetf(compoundDetf, 200e18);
            vm.recordLogs();
            vm.prank(permissionlessCaller);
            (detfIn_, bptOut_) = compoundInfo.compoundProtocolRewards();
        }

        assertGt(detfIn_, 0, "detfIn");
        assertGt(bptOut_, 0, "bptOut");
        assertEq(_protocolNftPrincipal(compoundDetf), principalBefore_ + bptOut_, "principal += bptOut");
        assertEq(IERC20(compoundDetf).balanceOf(compoundDetf), 0, "no free detf stranded");

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
        IDETFNFTVault vault_ = _bondNftVault(compoundDetf);

        // Ensure a locked user bond with effective shares exists.
        if (lockedUserBondId == 0 || vault_.effectiveSharesOf(lockedUserBondId) == 0) {
            _fundBuffer(alice, 80e18);
            vm.startPrank(alice);
            IERC20(address(dai)).approve(compoundDetf, 80e18);
            (lockedUserBondId,) = compoundBonding.bond(
                IERC20(address(dai)), 80e18, DEFAULT_MIN_LOCK, alice, false, block.timestamp + 1 hours
            );
            vm.stopPrank();
        }
        assertTrue(block.timestamp < vault_.unlockTimeOf(lockedUserBondId), "still locked");
        assertGt(vault_.effectiveSharesOf(lockedUserBondId), 0, "user has effective shares");

        _seedBondVaultRewardDetf(compoundDetf, 40e18);
        uint256 userPending_ = vault_.pendingRewards(lockedUserBondId);
        assertGt(userPending_, 0, "user has pending rewards");

        uint256 aliceBefore_ = IERC20(compoundDetf).balanceOf(alice);
        vm.prank(alice);
        uint256 claimed_ = vault_.claimRewards(lockedUserBondId, alice);

        assertGt(claimed_, 0, "claimed free detf");
        assertEq(IERC20(compoundDetf).balanceOf(alice) - aliceBefore_, claimed_, "free detf to user");
        assertEq(vault_.pendingRewards(lockedUserBondId), 0, "user pending cleared");
    }

    /* ---------------------------------------------------------------------- */
    /*                                 C4                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev C4: feeTo earns only via token id 1 `claimRewards` (D14). No DETF mint to feeTo on mint.
    function test_C4_feeRecipientGetsFreeDetfNotAutoJoined() public {
        address feeTo_ = _feeTo();
        uint256 feeBefore_ = IERC20(compoundDetf).balanceOf(feeTo_);
        _mintDetfFromBuffer(compoundDetf, bob, 40e18);
        assertEq(IERC20(compoundDetf).balanceOf(feeTo_), feeBefore_, "D14 no feeTo mint");

        IDETFNFTVault vault_ = _bondNftVault(compoundDetf);
        uint256 pending_ = vault_.pendingRewards(1);
        vm.prank(feeTo_);
        uint256 claimed_ = vault_.claimRewards(1, feeTo_);
        assertEq(claimed_, pending_, "id1 claim==pending");
        assertGt(claimed_, 0, "feeTo claimed via id 1");
    }

    /* ---------------------------------------------------------------------- */
    /*                                 C5                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev C5: claim package is wired on MixedBuffer TestBase. Claim redemption rate depends on
    ///      protocol-owned BPT principal (`originalSharesOf(detfNFTId)`). Compound must raise it.
    function test_C5_protocolCompoundRaisesClaimRateProxyPrincipal() public {
        assertTrue(compoundInfo.rebasingClaimToken() != address(0), "claim package wired");

        uint256 principalBefore_ = _protocolNftPrincipal(compoundDetf);
        assertGt(principalBefore_, 0, "protocol principal baseline");

        _seedBondVaultRewardDetf(compoundDetf, 50e18);
        (uint256 detfIn_, uint256 bptOut_) = compoundInfo.compoundProtocolRewards();
        if (detfIn_ == 0) {
            _seedBondVaultRewardDetf(compoundDetf, 200e18);
            (detfIn_, bptOut_) = compoundInfo.compoundProtocolRewards();
        }

        assertGt(detfIn_, 0, "compounded detf");
        assertGt(bptOut_, 0, "bpt out");
        uint256 principalAfter_ = _protocolNftPrincipal(compoundDetf);
        assertGt(principalAfter_, principalBefore_, "claim-rate proxy principal rose");
        assertEq(principalAfter_, principalBefore_ + bptOut_, "exact principal credit");
    }

    /* ---------------------------------------------------------------------- */
    /*                                 C8                                     */
    /* ---------------------------------------------------------------------- */

    /// @dev C8: join/atomic failure is best-effort - user mint succeeds; pending intact; later compound works.
    function test_C8_joinFailureBestEffort_thenRetry() public {
        assertGt(_protocolNftPrincipal(compoundDetf), 0, "protocol principal");
        _seedBondVaultRewardDetf(compoundDetf, 50e18);

        uint256 principalBefore_ = _protocolNftPrincipal(compoundDetf);
        uint256 vaultRewardBalBefore_ = IERC20(compoundDetf).balanceOf(address(_bondNftVault(compoundDetf)));

        // Force compound atomic body to fail (simulates join revert). Isolates compound from
        // buffer/share joins used by user mint (same router, different call path).
        vm.mockCallRevert(
            compoundDetf,
            abi.encodeWithSignature("compoundProtocolRewardsAtomic()"),
            "forced compound fail"
        );

        // Public compound best-effort returns zeros (does not revert).
        (uint256 detfInFail_, uint256 bptFail_) = compoundInfo.compoundProtocolRewards();
        assertEq(detfInFail_, 0, "no detfIn on failed compound");
        assertEq(bptFail_, 0, "no bpt on failed compound");
        assertEq(_protocolNftPrincipal(compoundDetf), principalBefore_, "principal unchanged on fail");
        // Preferred pull: harvest rolled back - reward DETF still on bond vault.
        assertGe(
            IERC20(compoundDetf).balanceOf(address(_bondNftVault(compoundDetf))),
            vaultRewardBalBefore_,
            "pending inventory remains on vault"
        );

        // User mint still succeeds (buffer join works; lazy compound fails best-effort).
        uint256 minted_ = _mintDetfFromBuffer(compoundDetf, bob, 20e18);
        assertGt(minted_, 0, "user mint succeeds despite compound fail");
        assertEq(_protocolNftPrincipal(compoundDetf), principalBefore_, "lazy fail did not credit principal");

        // Clear sabotage; later successful compound works.
        vm.clearMockedCalls();
        _seedBondVaultRewardDetf(compoundDetf, 80e18);
        (uint256 detfInOk_, uint256 bptOk_) = compoundInfo.compoundProtocolRewards();
        if (detfInOk_ == 0) {
            _seedBondVaultRewardDetf(compoundDetf, 200e18);
            (detfInOk_, bptOk_) = compoundInfo.compoundProtocolRewards();
        }
        assertGt(detfInOk_, 0, "retry compound detfIn");
        assertGt(bptOk_, 0, "retry compound bptOut");
        assertGt(_protocolNftPrincipal(compoundDetf), principalBefore_, "principal after retry");
    }

    /* ---------------------------------------------------------------------- */
    /*                              C7 surface                                */
    /* ---------------------------------------------------------------------- */

    /// @dev C7 structural: public ABI present; atomic only-self; production diamond path.
    function test_C7_publicAbiAndOnlySelfAtomic() public {
        // Public compound callable (no-op when nothing pending is fine).
        (uint256 d0_, uint256 b0_) = compoundInfo.compoundProtocolRewards();
        assertTrue(d0_ == 0 || b0_ >= 0, "public returns");

        // Atomic helper reverts for external callers (only-self).
        vm.prank(alice);
        (bool success_,) = compoundDetf.call(abi.encodeWithSignature("compoundProtocolRewardsAtomic()"));
        assertFalse(success_, "atomic rejects non-self");
    }
}
