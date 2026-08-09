// SPDX-License-Identifier: BUSL-1.1
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

/// @notice Catalog I1–I3 (+ burn/bond) for MixedBuffer multi-vault stable DETF secure pull (WP-I-DETF-MB-001).
/// @dev Anti-theater: I1 never transfers in-call; exact TransferDeltaInsufficient selector; proxy calls.
contract Adversarial_MixedBuffer_TrustFlag_Test is TestBase_MixedBufferMultiVaultStableDetf {
    address internal attacker;
    address internal victim;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
    }

    function _openLiveOpenThreshold() internal returns (address instance_) {
        instance_ = _deployOpenThresholdDetfN(1);
        _bootstrapDefault(instance_, alice);
        assertTrue(IMixedBufferMultiVaultStableDetfInfo(instance_).isReserveLive(), "live");
    }

    function _buffer(address instance_) internal view returns (IERC20) {
        return IERC20(IMixedBufferMultiVaultStableDetfInfo(instance_).bufferToken());
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: pretransferred=true, inventory present, no in-call transfer       */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 mint: donate bufferToken inventory; attacker claims pretransfer without transfer → delta 0.
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        address instance_ = _openLiveOpenThreshold();
        IERC20 buffer_ = _buffer(instance_);
        uint256 claimed_ = 80e18;
        _fundBuffer(attacker, claimed_);

        // Donate buffer inventory so absolute balance >= claimed (absolute-credit theater would pass).
        vm.prank(attacker);
        buffer_.transfer(instance_, claimed_);
        assertEq(buffer_.balanceOf(instance_), claimed_, "inventory present");
        assertEq(buffer_.balanceOf(attacker), 0, "attacker drained");
        assertEq(buffer_.allowance(attacker, instance_), 0, "no allowance");

        uint256 attDetfBefore_ = IERC20(instance_).balanceOf(attacker);
        uint256 invBefore_ = buffer_.balanceOf(instance_);

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

    /// @notice I1 burn: free detfToken on diamond cannot fund pretransfer burn extract.
    function test_I1_burn_pretransferred_true_usesOnlyCallerTransferredDetf() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 minted_ = _mintDetfFromBuffer(instance_, alice, 40e18);
        assertGt(minted_, 0, "minted detfToken");
        uint256 donateAmt_ = minted_ / 2;
        if (donateAmt_ == 0) donateAmt_ = minted_;

        // A2 pattern: free detfToken inventory on diamond.
        vm.prank(alice);
        IERC20(instance_).transfer(instance_, donateAmt_);
        assertEq(IERC20(instance_).balanceOf(instance_), donateAmt_, "free detf inventory");
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "attacker has 0 detfToken");

        address pool_ = IMixedBufferMultiVaultStableDetfInfo(instance_).reservePool();
        IERC20 buffer_ = _buffer(instance_);
        uint256 bptBefore_ = IERC20(pool_).balanceOf(instance_);
        uint256 bufferBefore_ = buffer_.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, donateAmt_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), donateAmt_, buffer_, 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(IERC20(instance_).balanceOf(instance_), donateAmt_, "free detf still on diamond");
        assertEq(IERC20(pool_).balanceOf(instance_), bptBefore_, "I1 burn: BPT intact");
        assertEq(buffer_.balanceOf(attacker), bufferBefore_, "I1 burn: no free buffer extract");
    }

    /// @notice I1 bond: donated bufferToken inventory cannot fund free pretransfer bond.
    function test_I1_bond_pretransferred_inventoryNoTransfer_reverts() public {
        address instance_ = _openLiveOpenThreshold();
        IERC20 buffer_ = _buffer(instance_);
        uint256 claimed_ = 60e18;
        _fundBuffer(attacker, claimed_);
        vm.prank(attacker);
        buffer_.transfer(instance_, claimed_);
        assertEq(buffer_.balanceOf(instance_), claimed_);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IMixedBufferMultiVaultStableDetfBonding(instance_).bond(
            buffer_, claimed_, DEFAULT_MIN_LOCK, attacker, true, block.timestamp + 1 hours
        );

        assertEq(buffer_.balanceOf(instance_), claimed_, "bond I1: inventory unchanged");
    }

    /* ---------------------------------------------------------------------- */
    /*  I2: claimed > observedDelta                                           */
    /* ---------------------------------------------------------------------- */

    /// @notice I2: pretransferred short/zero delta reverts with exact selector + args.
    function test_I2_pretransferred_claimedGtDelta0_reverts() public {
        address instance_ = _openLiveOpenThreshold();
        IERC20 buffer_ = _buffer(instance_);
        // Seed inventory (absolute would satisfy claimed) but no inbound delta.
        uint256 donated_ = 50e18;
        _fundBuffer(alice, donated_);
        vm.prank(alice);
        buffer_.transfer(instance_, donated_);

        uint256 claimed_ = donated_;
        assertGt(claimed_, 0);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            buffer_, claimed_, IERC20(instance_), 0, attacker, true, block.timestamp + 1 hours
        );
    }

    /* ---------------------------------------------------------------------- */
    /*  I3: residual inventory cannot fund second free pretransfer            */
    /* ---------------------------------------------------------------------- */

    /// @notice I3: after honest pull, residual donation cannot fund a second free pretransfer credit.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer() public {
        address instance_ = _openLiveOpenThreshold();
        IERC20 buffer_ = _buffer(instance_);

        // Pre-seed residual inventory that remains after an honest mint joins only the pulled amount.
        uint256 residual_ = 30e18;
        _fundBuffer(alice, residual_);
        vm.prank(alice);
        buffer_.transfer(instance_, residual_);
        assertEq(buffer_.balanceOf(instance_), residual_, "residual seeded");

        // Honest first mint via pull path (not pretransfer).
        uint256 victimIn_ = 20e18;
        _fundBuffer(victim, victimIn_);
        vm.startPrank(victim);
        buffer_.approve(instance_, victimIn_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            buffer_, victimIn_, IERC20(instance_), 0, victim, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(out_, 0, "honest mint ok");
        // Residual donation remains free on diamond (not joined).
        assertEq(buffer_.balanceOf(instance_), residual_, "residual still free after honest mint");

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
