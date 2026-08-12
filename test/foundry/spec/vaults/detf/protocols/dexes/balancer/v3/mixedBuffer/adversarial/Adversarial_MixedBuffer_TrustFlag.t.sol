// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";

/// @dev Same-tx helper: push shortDelta then claim > shortDelta with pretransferred=true.
///      Under durable U = B - R, observed unbooked surplus equals the same-tx push when residual is booked.
contract MixedBufferPretransferRouterHelper {
    function mintPretransfer(
        address detf_,
        IERC20 buffer_,
        uint256 transferAmt_,
        uint256 claimAmt_,
        address recipient_
    ) external returns (uint256 out_) {
        if (transferAmt_ > 0) {
            buffer_.transferFrom(msg.sender, detf_, transferAmt_);
        }
        out_ = IStandardExchangeIn(detf_).exchangeIn(
            buffer_, claimAmt_, IERC20(detf_), 0, recipient_, true, block.timestamp + 1 hours
        );
    }
}

/// @notice Catalog I1–I3 (+ burn/bond) for MixedBuffer multi-vault stable DETF secure pull (WP-I-DETF-MB-001).
/// @dev Durable reserve-delta: U = B - R. I1 requires booked residual (R==B); bare donation free-credits until end-sync (L-RSRV-DUST).
contract Adversarial_MixedBuffer_TrustFlag_Test is TestBase_MixedBufferMultiVaultStableDetf {
    address internal attacker;
    address internal victim;
    MixedBufferPretransferRouterHelper internal preHelper;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
        preHelper = new MixedBufferPretransferRouterHelper();
    }

    function _openLiveOpenThreshold() internal returns (address instance_) {
        instance_ = _deployOpenThresholdDetfN(1);
        _bootstrapDefault(instance_, alice);
        assertTrue(IMixedBufferMultiVaultStableDetfInfo(instance_).isReserveLive(), "live");
    }

    function _buffer(address instance_) internal view returns (IERC20) {
        return IERC20(IMixedBufferMultiVaultStableDetfInfo(instance_).bufferToken());
    }

    /// @dev Donate residual then honest !pretransferred mint so full-set end-sync books residual (R==B).
    function _bookBufferResidual(address instance_, uint256 residual_) internal {
        IERC20 buffer_ = _buffer(instance_);
        _fundBuffer(alice, residual_);
        vm.prank(alice);
        buffer_.transfer(instance_, residual_);

        uint256 honestIn_ = residual_ / 2;
        if (honestIn_ == 0) honestIn_ = residual_;
        _fundBuffer(victim, honestIn_);
        vm.startPrank(victim);
        buffer_.approve(instance_, honestIn_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            buffer_, honestIn_, IERC20(instance_), 0, victim, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(out_, 0, "book residual: honest mint ok");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: booked inventory (R==B), no new push, pretransferred=true         */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 mint: booked buffer residual cannot free-credit pretransfer mint (claimed, 0).
    /// @dev Bare donation free-credits until end-sync (L-RSRV-DUST) — not I1. Book via honest mint first.
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        address instance_ = _openLiveOpenThreshold();
        IERC20 buffer_ = _buffer(instance_);
        uint256 residual_ = 80e18;
        _bookBufferResidual(instance_, residual_);

        uint256 invBefore_ = buffer_.balanceOf(instance_);
        assertGe(invBefore_, residual_, "absolute inventory present (anti-theater)");
        uint256 claimed_ = residual_;
        uint256 attDetfBefore_ = IERC20(instance_).balanceOf(attacker);
        assertEq(buffer_.allowance(attacker, instance_), 0, "no allowance");
        assertEq(buffer_.balanceOf(attacker), 0, "attacker has no buffer");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            buffer_, claimed_, IERC20(instance_), 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(IERC20(instance_).balanceOf(attacker), attDetfBefore_, "I1: no free detfToken mint");
        assertEq(buffer_.balanceOf(instance_), invBefore_, "I1: inventory unchanged (no in-call transfer)");
    }

    /// @notice I1 burn: booked detfToken residual cannot fund pretransfer burn extract.
    /// @dev Bare donate detf free-credits until end-sync — book via honest burn path first.
    function test_I1_burn_pretransferred_true_usesOnlyCallerTransferredDetf() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 minted_ = _mintDetfFromBuffer(instance_, alice, 40e18);
        assertGt(minted_, 0, "minted detfToken");
        uint256 donateAmt_ = minted_ / 2;
        if (donateAmt_ == 0) donateAmt_ = minted_;
        uint256 burnHonest_ = minted_ - donateAmt_;
        if (burnHonest_ == 0) burnHonest_ = 1;

        // Unbooked donate then honest burn false → end-sync books remaining free detf residual.
        vm.startPrank(alice);
        IERC20(instance_).transfer(instance_, donateAmt_);
        IERC20(instance_).approve(instance_, burnHonest_);
        IERC20 buffer_ = _buffer(instance_);
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), burnHonest_, buffer_, 0, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        uint256 residualDetf_ = IERC20(instance_).balanceOf(instance_);
        assertGt(residualDetf_, 0, "booked detf residual present");
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "attacker has 0 detfToken");

        address pool_ = IMixedBufferMultiVaultStableDetfInfo(instance_).reservePool();
        uint256 bptBefore_ = IERC20(pool_).balanceOf(instance_);
        uint256 bufferBefore_ = buffer_.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, residualDetf_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), residualDetf_, buffer_, 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(IERC20(instance_).balanceOf(instance_), residualDetf_, "free detf still on diamond");
        assertEq(IERC20(pool_).balanceOf(instance_), bptBefore_, "I1 burn: BPT intact");
        assertEq(buffer_.balanceOf(attacker), bufferBefore_, "I1 burn: no free buffer extract");
    }

    /// @notice I1 bond: booked buffer residual cannot fund free pretransfer bond.
    function test_I1_bond_pretransferred_inventoryNoTransfer_reverts() public {
        address instance_ = _openLiveOpenThreshold();
        IERC20 buffer_ = _buffer(instance_);
        uint256 residual_ = 60e18;
        _bookBufferResidual(instance_, residual_);

        uint256 invBefore_ = buffer_.balanceOf(instance_);
        uint256 claimed_ = residual_;

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IMixedBufferMultiVaultStableDetfBonding(instance_).bond(
            buffer_, claimed_, DEFAULT_MIN_LOCK, attacker, true, block.timestamp + 1 hours
        );

        assertEq(buffer_.balanceOf(instance_), invBefore_, "bond I1: inventory unchanged");
    }

    /* ---------------------------------------------------------------------- */
    /*  I2: claimed > U (short same-tx push or zero unbooked)                 */
    /* ---------------------------------------------------------------------- */

    /// @notice I2 short: booked residual + same-tx push shortDelta then claim > short → (claimed, shortDelta).
    function test_I2_pretransferred_claimedGtDelta0_reverts() public {
        address instance_ = _openLiveOpenThreshold();
        IERC20 buffer_ = _buffer(instance_);

        // Book any residual so U starts at 0 (openLive + optional residual book).
        uint256 residual_ = 30e18;
        _bookBufferResidual(instance_, residual_);

        uint256 claimed_ = 50e18;
        uint256 shortDelta_ = claimed_ / 2;
        require(shortDelta_ > 0 && shortDelta_ < claimed_, "need short < claimed");

        _fundBuffer(attacker, shortDelta_);
        vm.startPrank(attacker);
        buffer_.approve(address(preHelper), shortDelta_);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, shortDelta_
            )
        );
        preHelper.mintPretransfer(instance_, buffer_, shortDelta_, claimed_, attacker);
        vm.stopPrank();

        assertEq(IERC20(instance_).balanceOf(attacker), 0, "I2: no mint on short");
    }

    /* ---------------------------------------------------------------------- */
    /*  I3: residual after honest money-route end-sync is booked              */
    /* ---------------------------------------------------------------------- */

    /// @notice I3: after honest pull end-sync, residual donation is booked; free true reverts U=0.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer() public {
        address instance_ = _openLiveOpenThreshold();
        IERC20 buffer_ = _buffer(instance_);

        // Pre-seed residual inventory that remains after an honest mint joins only the pulled amount.
        uint256 residual_ = 30e18;
        _fundBuffer(alice, residual_);
        vm.prank(alice);
        buffer_.transfer(instance_, residual_);
        assertEq(buffer_.balanceOf(instance_), residual_, "residual seeded");

        // Honest first mint via pull path (not pretransfer) — end-sync books residual.
        uint256 victimIn_ = 20e18;
        _fundBuffer(victim, victimIn_);
        vm.startPrank(victim);
        buffer_.approve(instance_, victimIn_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            buffer_, victimIn_, IERC20(instance_), 0, victim, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(out_, 0, "honest mint ok");
        // Residual remains on diamond but is booked (R==B) after end-sync.
        assertEq(buffer_.balanceOf(instance_), residual_, "residual still on diamond after honest mint");

        // Second call: pretransferred against residual, no new inbound transfer.
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, residual_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            buffer_, residual_, IERC20(instance_), 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(buffer_.balanceOf(instance_), residual_, "I3: residual not free-credited");
    }
}
