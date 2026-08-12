// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    TestBase_MultiVaultWeightedDetf_Adversarial
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/TestBase_MultiVaultWeightedDetf_Adversarial.sol";
import {
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";

/// @dev Same-tx helper: transfers `transferAmt_` then calls exchangeIn/bond with `claimAmt_` + pretransferred=true.
///      Under durable U = B - R, when prior residual is booked, U equals the same-tx push amount.
contract PretransferRouterHelper {
    function mintPretransfer(
        address detf_,
        IERC20 vaultShare_,
        uint256 transferAmt_,
        uint256 claimAmt_,
        address recipient_
    ) external returns (uint256 out_) {
        if (transferAmt_ > 0) {
            vaultShare_.transferFrom(msg.sender, detf_, transferAmt_);
        }
        out_ = IStandardExchangeIn(detf_).exchangeIn(
            vaultShare_, claimAmt_, IERC20(detf_), 0, recipient_, true, block.timestamp + 1 hours
        );
    }

    function burnPretransfer(
        address detf_,
        IERC20 vaultShareOut_,
        uint256 transferAmt_,
        uint256 claimAmt_,
        address recipient_
    ) external returns (uint256 out_) {
        if (transferAmt_ > 0) {
            IERC20(detf_).transferFrom(msg.sender, detf_, transferAmt_);
        }
        out_ = IStandardExchangeIn(detf_).exchangeIn(
            IERC20(detf_), claimAmt_, vaultShareOut_, 0, recipient_, true, block.timestamp + 1 hours
        );
    }

    function bondPretransfer(
        address detf_,
        IERC20 vaultShare_,
        uint256 transferAmt_,
        uint256 claimAmt_,
        uint256 lock_,
        address recipient_
    ) external returns (uint256 tokenId_, uint256 shares_) {
        if (transferAmt_ > 0) {
            vaultShare_.transferFrom(msg.sender, detf_, transferAmt_);
        }
        return IMultiVaultWeightedDetfBonding(detf_).bond(
            vaultShare_, claimAmt_, lock_, recipient_, true, block.timestamp + 1 hours
        );
    }
}

/**
 * @title Adversarial_TrustFlags_Test
 * @notice Catalog I1/I2/I3 + K1 under durable reserve-delta pretransfer (U = B - R).
 * @dev Production proxy via TestBase_MultiVaultWeightedDetf_Adversarial (no mock SUT).
 *      I1: booked residual (R==B), pretransferred=true, no new push → TransferDeltaInsufficient(claimed, 0)
 *      I2: book residual first; same-tx push shortDelta then claim > short → TransferDeltaInsufficient(claimed, shortDelta)
 *      I3: residual after honest money-route end-sync is booked; free true reverts
 *      K1: bare donation free-credits by design (L-RSRV-DUST); after honest sync, booked residual cannot free-credit
 */
contract Adversarial_TrustFlags_Test is TestBase_MultiVaultWeightedDetf_Adversarial {
    PretransferRouterHelper internal preHelper;

    function setUp() public virtual override {
        super.setUp();
        preHelper = new PretransferRouterHelper();
    }

    /// @dev Donate residual then honest !pretransferred mint so full-set end-sync books residual (R==B).
    function _bookVaultShareResidual(address instance_, uint256 residual_) internal {
        uint256 funded_ = _fundSeSharesLeg(0, bob, residual_);
        vm.prank(bob);
        seShares[0].transfer(instance_, funded_);

        uint256 honestIn_ = _fundSeSharesLeg(0, alice, residual_ / 2 == 0 ? residual_ : residual_ / 2);
        vm.startPrank(alice);
        seShares[0].approve(instance_, honestIn_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            seShares[0], honestIn_, IERC20(instance_), 0, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(out_ > 0, "book residual: honest mint ok");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: booked inventory, no in-call transfer, pretransferred=true        */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 mint: booked vaultShare residual cannot free-credit pretransfer mint.
    /// @dev Bare donation free-credits until end-sync (L-RSRV-DUST) — book via honest mint first.
    function test_I1_pretransferred_mint_inventoryNoInCallTransfer_revertsDelta0() public {
        address instance_ = _openLiveN1();
        uint256 residual_ = 50e18;
        _bookVaultShareResidual(instance_, residual_);

        uint256 balBefore_ = seShares[0].balanceOf(instance_);
        assertGe(balBefore_, residual_, "absolute inventory present (anti-theater)");
        uint256 claimed_ = residual_;
        uint256 attackerDetfBefore_ = IERC20(instance_).balanceOf(attacker);
        assertEq(seShares[0].allowance(attacker, instance_), 0);
        assertEq(seShares[0].balanceOf(attacker), 0);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            seShares[0], claimed_, IERC20(instance_), 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(seShares[0].balanceOf(instance_), balBefore_, "I1 mint must not move inventory");
        assertEq(IERC20(instance_).balanceOf(attacker), attackerDetfBefore_, "I1: no free detfToken mint");
    }

    /// @notice I1 burn: booked detfToken residual cannot fund pretransfer burn.
    /// @dev Bare donate detf free-credits until end-sync — book via honest burn path first.
    function test_I1_pretransferred_burn_detfInventoryNoInCallTransfer_revertsDelta0() public {
        address instance_ = _openLiveN1();
        require(IMultiVaultWeightedDetfInfo(instance_).isBurningAllowed(), "burn open");

        uint256 minted_ = _mintOnLeg(instance_, 0, victim, 40e18);
        uint256 donateAmt_ = minted_ / 2;
        if (donateAmt_ == 0) donateAmt_ = minted_;
        uint256 burnHonest_ = minted_ - donateAmt_;
        if (burnHonest_ == 0) burnHonest_ = 1;

        vm.startPrank(victim);
        IERC20(instance_).transfer(instance_, donateAmt_);
        IERC20(instance_).approve(instance_, burnHonest_);
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), burnHonest_, seShares[0], 0, victim, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        uint256 residualDetf_ = IERC20(instance_).balanceOf(instance_);
        assertGt(residualDetf_, 0, "booked detf residual present");
        assertEq(IERC20(instance_).balanceOf(attacker), 0);

        uint256 invBefore_ = residualDetf_;
        uint256 attackerShareBefore_ = seShares[0].balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, residualDetf_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), residualDetf_, seShares[0], 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(IERC20(instance_).balanceOf(instance_), invBefore_, "I1 burn must not free-burn inventory");
        assertEq(seShares[0].balanceOf(attacker), attackerShareBefore_, "I1: no free vaultShare extract");
    }

    /// @notice I1 bond: booked vaultShare residual + pretransferred without inbound delta reverts.
    function test_I1_pretransferred_bond_inventoryNoInCallTransfer_revertsDelta0() public {
        address instance_ = _openLiveN1();
        uint256 residual_ = 40e18;
        _bookVaultShareResidual(instance_, residual_);

        uint256 claimed_ = residual_;
        uint256 balBefore_ = seShares[0].balanceOf(instance_);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IMultiVaultWeightedDetfBonding(instance_).bond(
            seShares[0], claimed_, DEFAULT_MIN_LOCK, attacker, true, block.timestamp + 1 hours
        );

        assertEq(seShares[0].balanceOf(instance_), balBefore_, "bond I1: inventory unchanged");
    }

    /* ---------------------------------------------------------------------- */
    /*  I2: short delivery — claimed > U (U = same-tx shortDelta when booked) */
    /* ---------------------------------------------------------------------- */

    /// @notice I2 mint: book residual, then same-tx push shortDelta and claim > short → (claimed, shortDelta).
    /// @dev Durable U includes same-tx external push. Not observed-delta-0 when shortDelta lands.
    function test_I2_pretransferred_mint_shortDelta_reverts() public {
        address instance_ = _openLiveN1();

        // Book residual so U starts at 0.
        _bookVaultShareResidual(instance_, 40e18);
        uint256 bookedBal_ = seShares[0].balanceOf(instance_);

        uint256 claimed_ = _fundSeSharesLeg(0, attacker, 60e18);
        uint256 shortDelta_ = claimed_ / 2;
        require(shortDelta_ > 0 && shortDelta_ < claimed_, "need short < claimed");

        // Leave only shortDelta funded for the push (return excess if fund returns full claimed).
        // Attacker keeps shortDelta to push; claim more than short.
        // If fund gave full claimed_, transfer only shortDelta via helper.
        vm.startPrank(attacker);
        seShares[0].approve(address(preHelper), shortDelta_);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, shortDelta_
            )
        );
        preHelper.mintPretransfer(instance_, seShares[0], shortDelta_, claimed_, attacker);
        vm.stopPrank();

        // Helper reverts as one call — short transfer rolls back; only booked inventory remains.
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "I2: no mint on short");
        assertEq(seShares[0].balanceOf(instance_), bookedBal_, "I2: only booked inventory remains");
    }

    /// @notice I2 burn: book residual, same-tx push shortDelta of detf, claim > short → (claimed, shortDelta).
    function test_I2_pretransferred_burn_shortDelta_reverts() public {
        address instance_ = _openLiveN1();
        require(IMultiVaultWeightedDetfInfo(instance_).isBurningAllowed(), "burn open");

        uint256 minted_ = _mintOnLeg(instance_, 0, victim, 50e18);
        uint256 residualSeed_ = minted_ / 4;
        if (residualSeed_ == 0) residualSeed_ = 1;
        uint256 burnHonest_ = minted_ / 4;
        if (burnHonest_ == 0) burnHonest_ = 1;
        uint256 toAttacker_ = minted_ - residualSeed_ - burnHonest_;
        if (toAttacker_ == 0) {
            // Fall back: leave residual + short path from a second mint if split is tight.
            toAttacker_ = minted_ / 2;
            residualSeed_ = minted_ / 4;
            burnHonest_ = minted_ - residualSeed_ - toAttacker_;
            if (burnHonest_ == 0) burnHonest_ = 1;
        }

        // Book residual: donate + honest burn end-syncs free detf into R.
        vm.startPrank(victim);
        IERC20(instance_).transfer(instance_, residualSeed_);
        if (burnHonest_ > 0 && IERC20(instance_).balanceOf(victim) >= burnHonest_) {
            IERC20(instance_).approve(instance_, burnHonest_);
            IStandardExchangeIn(instance_).exchangeIn(
                IERC20(instance_), burnHonest_, seShares[0], 0, victim, false, block.timestamp + 1 hours
            );
        }
        uint256 attackerBal_ = IERC20(instance_).balanceOf(victim);
        if (attackerBal_ > 0) {
            IERC20(instance_).transfer(attacker, attackerBal_);
        }
        vm.stopPrank();

        uint256 claimed_ = IERC20(instance_).balanceOf(attacker);
        require(claimed_ >= 2, "need attacker detf for short path");
        uint256 shortDelta_ = claimed_ / 2;
        if (shortDelta_ == 0) shortDelta_ = 1;
        require(shortDelta_ < claimed_, "need short < claimed");

        uint256 invBeforeTransfer_ = IERC20(instance_).balanceOf(instance_);

        vm.startPrank(attacker);
        IERC20(instance_).approve(address(preHelper), shortDelta_);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, shortDelta_
            )
        );
        preHelper.burnPretransfer(instance_, seShares[0], shortDelta_, claimed_, attacker);
        vm.stopPrank();

        // Helper reverts as one call — short transfer rolls back; residual inventory unchanged.
        assertEq(
            IERC20(instance_).balanceOf(instance_),
            invBeforeTransfer_,
            "I2 burn: residual inventory intact after atomic revert"
        );
    }

    /* ---------------------------------------------------------------------- */
    /*  I3: residual inventory cannot fund second free pretransfer credit     */
    /* ---------------------------------------------------------------------- */

    /// @notice I3: after honest !pretransferred mint, residual idle inventory cannot fund free pretransfer.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer_mint() public {
        address instance_ = _openLiveN1();

        // Seed residual inventory that will remain after first mint (booked by end-sync).
        uint256 residualSeed_ = _fundSeSharesLeg(0, bob, 30e18);
        vm.prank(bob);
        seShares[0].transfer(instance_, residualSeed_);

        // Honest mint path (!pretransferred) — end-sync books residual seed.
        uint256 honestIn_ = _fundSeSharesLeg(0, alice, 40e18);
        vm.startPrank(alice);
        seShares[0].approve(instance_, honestIn_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            seShares[0], honestIn_, IERC20(instance_), 0, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(out_ > 0, "honest mint ok");

        uint256 residual_ = seShares[0].balanceOf(instance_);
        assertGe(residual_, residualSeed_, "residual inventory remains");

        // Second call: pretransferred=true, claim against residual, no new transfer.
        uint256 claim_ = residualSeed_;

        uint256 attackerDetfBefore_ = IERC20(instance_).balanceOf(attacker);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claim_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            seShares[0], claim_, IERC20(instance_), 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(seShares[0].balanceOf(instance_), residual_, "I3 residual unmoved");
        assertEq(IERC20(instance_).balanceOf(attacker), attackerDetfBefore_, "I3 no free mint");
    }

    /// @notice I3 burn: residual detfToken on diamond cannot fund a second free pretransfer burn.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer_burn() public {
        address instance_ = _openLiveN1();
        require(IMultiVaultWeightedDetfInfo(instance_).isBurningAllowed(), "burn open");

        uint256 minted_ = _mintOnLeg(instance_, 0, victim, 50e18);
        uint256 residualSeed_ = minted_ / 3;
        if (residualSeed_ == 0) residualSeed_ = 1;
        uint256 burnAmt_ = minted_ / 3;
        if (burnAmt_ == 0) burnAmt_ = 1;

        vm.startPrank(victim);
        IERC20(instance_).transfer(instance_, residualSeed_);
        IERC20(instance_).approve(instance_, burnAmt_);
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), burnAmt_, seShares[0], 0, victim, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        uint256 residual_ = IERC20(instance_).balanceOf(instance_);
        assertGe(residual_, residualSeed_, "residual detfToken remains");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, residualSeed_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), residualSeed_, seShares[0], 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(IERC20(instance_).balanceOf(instance_), residual_, "I3 burn residual unmoved");
    }

    /* ---------------------------------------------------------------------- */
    /*  K1: donation free-credit is L-RSRV-DUST until honest end-sync books it */
    /* ---------------------------------------------------------------------- */

    /// @notice K1: bare donation free-credits by design (L-RSRV-DUST); after honest mint end-sync,
    ///         booked residual cannot free-credit via pretransferred mint.
    function test_K1_donation_cannotFundPretransferCredit_mint() public {
        address instance_ = _openLiveN1();
        uint256 donated_ = _fundSeSharesLeg(0, attacker, 80e18);

        // Donation (no exchangeIn) — idle unbooked inventory (L-RSRV-DUST free-credit by design).
        vm.prank(attacker);
        seShares[0].transfer(instance_, donated_);

        // Honest money route end-syncs → books donation residual into R.
        uint256 honestIn_ = _fundSeSharesLeg(0, alice, 20e18);
        vm.startPrank(alice);
        seShares[0].approve(instance_, honestIn_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            seShares[0], honestIn_, IERC20(instance_), 0, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(out_ > 0, "honest mint books residual");

        uint256 balBefore_ = seShares[0].balanceOf(instance_);
        assertGe(balBefore_, donated_, "donated residual still on diamond");
        uint256 attackerDetfBefore_ = IERC20(instance_).balanceOf(attacker);

        // Booked residual cannot free-credit.
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, donated_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            seShares[0], donated_, IERC20(instance_), 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(seShares[0].balanceOf(instance_), balBefore_, "K1 booked donation unmoved");
        assertEq(IERC20(instance_).balanceOf(attacker), attackerDetfBefore_, "K1 no free detfToken");
    }

    /// @notice Positive control: honest !pretransferred mint (in-call transferFrom) succeeds.
    function test_I_positive_honestPullMint_succeeds() public {
        address instance_ = _openLiveN1();
        uint256 amount_ = _fundSeSharesLeg(0, alice, 35e18);

        vm.startPrank(alice);
        seShares[0].approve(instance_, amount_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            seShares[0], amount_, IERC20(instance_), 0, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertTrue(out_ > 0, "honest !pretransferred mint");
        assertEq(IERC20(instance_).balanceOf(alice), out_, "alice received detfToken");
    }

    /// @notice Positive control: honest !pretransferred burn succeeds.
    function test_I_positive_honestPullBurn_succeeds() public {
        address instance_ = _openLiveN1();
        require(IMultiVaultWeightedDetfInfo(instance_).isBurningAllowed(), "burn open");

        uint256 minted_ = _mintOnLeg(instance_, 0, alice, 40e18);
        uint256 burnAmt_ = minted_ / 2;
        if (burnAmt_ == 0) burnAmt_ = minted_;

        vm.startPrank(alice);
        IERC20(instance_).approve(instance_, burnAmt_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), burnAmt_, seShares[0], 0, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertTrue(out_ > 0, "honest !pretransferred burn");
    }
}
