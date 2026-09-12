// SPDX-License-Identifier: BSL-1.1
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

/// @dev Same-tx helper for I2 short under durable U.
contract SingleSEPretransferRouterHelper {
    function mintPretransfer(
        address detf_,
        IERC20 seShare_,
        uint256 transferAmt_,
        uint256 claimAmt_,
        address recipient_
    ) external returns (uint256 out_) {
        if (transferAmt_ > 0) {
            seShare_.transferFrom(msg.sender, detf_, transferAmt_);
        }
        out_ = IStandardExchangeIn(detf_).exchangeIn(
            seShare_, claimAmt_, IERC20(detf_), 0, recipient_, true, block.timestamp + 1 hours
        );
    }
}

/// @notice Catalog I1–I3 (+ burn/bond) for SingleStandardExchangeDETF secure pull (WP-I-DETF-SSE-001/002).
/// @dev Durable U = B - R. I1 requires booked residual; bare donation free-credits until end-sync (L-RSRV-DUST).
contract Adversarial_SingleSE_TrustFlag_Test is TestBase_SingleStandardExchangeDETF_Adversarial {
    SingleSEPretransferRouterHelper internal preHelper;

    function setUp() public virtual override {
        super.setUp();
        preHelper = new SingleSEPretransferRouterHelper();
    }

    /// @dev Donate residual then honest !pretransferred mint so end-sync books residual (R==B).
    function _bookSeShareResidual(address instance_, uint256 residual_) internal {
        uint256 funded_ = _fundSeShares(alice, residual_);
        vm.prank(alice);
        seShare.transfer(instance_, funded_);

        uint256 honestIn_ = _fundSeShares(victim, residual_ / 2 == 0 ? residual_ : residual_ / 2);
        vm.startPrank(victim);
        seShare.approve(instance_, honestIn_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            seShare, honestIn_, IERC20(instance_), 0, victim, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(out_, 0, "book residual: honest mint ok");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: booked inventory, no in-call transfer, pretransferred=true        */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 mint: booked vaultShare residual cannot free-credit pretransfer mint.
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 residual_ = 80e18;
        _bookSeShareResidual(instance_, residual_);

        uint256 invBefore_ = seShare.balanceOf(instance_);
        assertGe(invBefore_, residual_, "absolute inventory present (anti-theater)");
        uint256 claimed_ = residual_;
        uint256 attDetfBefore_ = IERC20(instance_).balanceOf(attacker);
        assertEq(seShare.balanceOf(attacker), 0, "attacker drained");
        assertEq(seShare.allowance(attacker, instance_), 0, "no allowance");

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

    /// @notice I1 burn: booked detfToken residual cannot fund pretransfer burn extract.
    function test_I1_burn_pretransferred_true_usesOnlyCallerTransferredDetf() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 minted_ = _mintSeSharesToDetf(instance_, alice, 40e18);
        assertGt(minted_, 0, "minted detfToken");
        uint256 donateAmt_ = minted_ / 2;
        if (donateAmt_ == 0) donateAmt_ = minted_;
        uint256 burnHonest_ = minted_ - donateAmt_;
        if (burnHonest_ == 0) burnHonest_ = 1;

        vm.startPrank(alice);
        IERC20(instance_).transfer(instance_, donateAmt_);
        IERC20(instance_).approve(instance_, burnHonest_);
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), burnHonest_, seShare, 0, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        uint256 residualDetf_ = IERC20(instance_).balanceOf(instance_);
        assertGt(residualDetf_, 0, "booked detf residual present");
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "attacker has 0 detfToken");

        address pool_ = ISingleStandardExchangeDETFInfo(instance_).reservePool();
        uint256 bptBefore_ = IERC20(pool_).balanceOf(instance_);
        uint256 seShareBefore_ = seShare.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, residualDetf_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), residualDetf_, seShare, 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(IERC20(instance_).balanceOf(instance_), residualDetf_, "free detf still on diamond");
        assertEq(IERC20(pool_).balanceOf(instance_), bptBefore_, "I1 burn: BPT intact");
        assertEq(seShare.balanceOf(attacker), seShareBefore_, "I1 burn: no free vaultShare extract");
    }

    /// @notice I1 bond: booked vaultShare residual cannot fund free pretransfer bond.
    function test_I1_bond_pretransferred_inventoryNoTransfer_reverts() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 residual_ = 60e18;
        _bookSeShareResidual(instance_, residual_);

        uint256 claimed_ = residual_;
        uint256 invBefore_ = seShare.balanceOf(instance_);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        ISingleStandardExchangeDETFBonding(instance_).bond(
            seShare, claimed_, DEFAULT_MIN_LOCK, attacker, true, block.timestamp + 1 hours
        );

        assertEq(seShare.balanceOf(instance_), invBefore_, "bond I1: inventory unchanged");
    }

    /* ---------------------------------------------------------------------- */
    /*  I2: claimed > U                                                       */
    /* ---------------------------------------------------------------------- */

    /// @notice I2 short: book residual, same-tx push shortDelta, claim > short → (claimed, shortDelta).
    function test_I2_pretransferred_claimedGtDelta0_reverts() public {
        address instance_ = _openLiveOpenThreshold();
        _bookSeShareResidual(instance_, 30e18);

        uint256 claimed_ = _fundSeShares(attacker, 50e18);
        uint256 shortDelta_ = claimed_ / 2;
        require(shortDelta_ > 0 && shortDelta_ < claimed_, "need short < claimed");

        vm.startPrank(attacker);
        seShare.approve(address(preHelper), shortDelta_);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, shortDelta_
            )
        );
        preHelper.mintPretransfer(instance_, seShare, shortDelta_, claimed_, attacker);
        vm.stopPrank();

        assertEq(IERC20(instance_).balanceOf(attacker), 0, "I2: no mint on short");
    }

    /* ---------------------------------------------------------------------- */
    /*  I3: residual inventory cannot fund second free pretransfer            */
    /* ---------------------------------------------------------------------- */

    /// @notice I3: after honest pull end-sync, residual is booked; free true reverts U=0.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer() public {
        address instance_ = _openLiveOpenThreshold();

        // Pre-seed residual inventory that remains after an honest mint joins only the pulled amount.
        uint256 residual_ = _fundSeShares(alice, 30e18);
        vm.prank(alice);
        seShare.transfer(instance_, residual_);
        assertEq(seShare.balanceOf(instance_), residual_, "residual seeded");

        // Honest first mint via pull path (not pretransfer) — end-sync books residual.
        uint256 victimIn_ = _fundSeShares(victim, 20e18);
        vm.startPrank(victim);
        seShare.approve(instance_, victimIn_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            seShare, victimIn_, IERC20(instance_), 0, victim, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(out_, 0, "honest mint ok");
        // Residual remains on diamond but is booked (R==B) after end-sync.
        assertEq(seShare.balanceOf(instance_), residual_, "residual still on diamond after honest mint");

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
