// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    TestBase_SingleStandardExchangeDETF_Adversarial
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/adversarial/TestBase_SingleStandardExchangeDETF_Adversarial.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";

/// @notice Catalog I1–I3 (+ burn/bond) for SingleStandardExchangeDETF secure pull (WP-I-DETF-SSE-001/002).
/// @dev Anti-theater: I1 never transfers in-call; exact TransferDeltaInsufficient selector; proxy calls.
contract Adversarial_SingleSE_TrustFlag_Test is TestBase_SingleStandardExchangeDETF_Adversarial {
    /* ---------------------------------------------------------------------- */
    /*  I1: pretransferred=true, inventory present, no in-call transfer       */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 mint: donate vaultShare inventory; attacker claims pretransfer without transfer → delta 0.
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 claimed_ = _fundSeShares(attacker, 80e18);
        assertGt(claimed_, 0, "funded claim");

        // Donate vaultShare inventory so absolute balance >= claimed (absolute-credit theater would pass).
        vm.prank(attacker);
        seShare.transfer(instance_, claimed_);
        assertEq(seShare.balanceOf(instance_), claimed_, "inventory present");
        assertEq(seShare.balanceOf(attacker), 0, "attacker drained");
        assertEq(seShare.allowance(attacker, instance_), 0, "no allowance");

        uint256 attDetfBefore_ = IERC20(instance_).balanceOf(attacker);
        uint256 invBefore_ = seShare.balanceOf(instance_);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            seShare, claimed_, IERC20(instance_), 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(IERC20(instance_).balanceOf(attacker), attDetfBefore_, "I1: no free detfToken mint");
        assertEq(seShare.balanceOf(instance_), invBefore_, "I1: inventory unchanged (no in-call transfer)");
    }

    /// @notice I1 burn: free detfToken on diamond cannot fund pretransfer burn extract.
    function test_I1_burn_pretransferred_true_usesOnlyCallerTransferredDetf() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 minted_ = _mintSeSharesToDetf(instance_, alice, 40e18);
        assertGt(minted_, 0, "minted detfToken");
        uint256 donateAmt_ = minted_ / 2;
        if (donateAmt_ == 0) donateAmt_ = minted_;

        // A2 pattern: free detfToken inventory on diamond.
        vm.prank(alice);
        IERC20(instance_).transfer(instance_, donateAmt_);
        assertEq(IERC20(instance_).balanceOf(instance_), donateAmt_, "free detf inventory");
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "attacker has 0 detfToken");

        address pool_ = ISingleStandardExchangeDETFInfo(instance_).reservePool();
        uint256 bptBefore_ = IERC20(pool_).balanceOf(instance_);
        uint256 seShareBefore_ = seShare.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, donateAmt_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), donateAmt_, seShare, 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(IERC20(instance_).balanceOf(instance_), donateAmt_, "free detf still on diamond");
        assertEq(IERC20(pool_).balanceOf(instance_), bptBefore_, "I1 burn: BPT intact");
        assertEq(seShare.balanceOf(attacker), seShareBefore_, "I1 burn: no free vaultShare extract");
    }

    /// @notice I1 bond: donated vaultShare inventory cannot fund free pretransfer bond.
    function test_I1_bond_pretransferred_inventoryNoTransfer_reverts() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 claimed_ = _fundSeShares(attacker, 60e18);
        vm.prank(attacker);
        seShare.transfer(instance_, claimed_);
        assertEq(seShare.balanceOf(instance_), claimed_);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        ISingleStandardExchangeDETFBonding(instance_).bond(
            seShare, claimed_, DEFAULT_MIN_LOCK, attacker, true, block.timestamp + 1 hours
        );

        assertEq(seShare.balanceOf(instance_), claimed_, "bond I1: inventory unchanged");
    }

    /* ---------------------------------------------------------------------- */
    /*  I2: claimed > observedDelta                                           */
    /* ---------------------------------------------------------------------- */

    /// @notice I2: pretransferred short/zero delta reverts with exact selector + args.
    function test_I2_pretransferred_claimedGtDelta0_reverts() public {
        address instance_ = _openLiveOpenThreshold();
        // Seed inventory (absolute would satisfy claimed) but no inbound delta.
        uint256 donated_ = _fundSeShares(alice, 50e18);
        vm.prank(alice);
        seShare.transfer(instance_, donated_);

        uint256 claimed_ = donated_;
        assertGt(claimed_, 0);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            seShare, claimed_, IERC20(instance_), 0, attacker, true, block.timestamp + 1 hours
        );
    }

    /* ---------------------------------------------------------------------- */
    /*  I3: residual inventory cannot fund second free pretransfer            */
    /* ---------------------------------------------------------------------- */

    /// @notice I3: after honest pull, residual donation cannot fund a second free pretransfer credit.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer() public {
        address instance_ = _openLiveOpenThreshold();

        // Pre-seed residual inventory that remains after an honest mint joins only the pulled amount.
        uint256 residual_ = _fundSeShares(alice, 30e18);
        vm.prank(alice);
        seShare.transfer(instance_, residual_);
        assertEq(seShare.balanceOf(instance_), residual_, "residual seeded");

        // Honest first mint via pull path (not pretransfer).
        uint256 victimIn_ = _fundSeShares(victim, 20e18);
        vm.startPrank(victim);
        seShare.approve(instance_, victimIn_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            seShare, victimIn_, IERC20(instance_), 0, victim, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(out_, 0, "honest mint ok");
        // Residual donation remains free on diamond (not joined).
        assertEq(seShare.balanceOf(instance_), residual_, "residual still free after honest mint");

        // Second call: pretransferred against residual, no new inbound transfer.
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, residual_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            seShare, residual_, IERC20(instance_), 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(seShare.balanceOf(instance_), residual_, "I3: residual not free-credited");
    }
}
