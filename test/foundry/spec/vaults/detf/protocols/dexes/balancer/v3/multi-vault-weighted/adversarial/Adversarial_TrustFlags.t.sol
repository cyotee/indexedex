// SPDX-License-Identifier: BUSL-1.1
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
///      Models a router multicall pull window so observedDelta == transferAmt_.
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
 * @notice Catalog I1/I2/I3 + K1: pretransfer trust flags must not free-credit inventory (L-GAPS-9/10/12).
 * @dev Production proxy via TestBase_MultiVaultWeightedDetf_Adversarial (no mock SUT).
 *      I1: pretransferred=true, no in-call transfer, inventory present → TransferDeltaInsufficient(claimed, 0)
 *      I2: short observed delta (partial same-tx pretransfer) → TransferDeltaInsufficient(claimed, shortDelta)
 *      I3: residual inventory after a prior path cannot fund a second free pretransfer credit
 *      K1: donation cannot fund pretransfer credit (overlaps I1 after delta fix)
 */
contract Adversarial_TrustFlags_Test is TestBase_MultiVaultWeightedDetf_Adversarial {
    PretransferRouterHelper internal preHelper;

    function setUp() public virtual override {
        super.setUp();
        preHelper = new PretransferRouterHelper();
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: inventory present, no in-call transfer, pretransferred=true       */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 mint: donate vaultShare inventory to diamond; attacker claims pretransferred without transfer.
    function test_I1_pretransferred_mint_inventoryNoInCallTransfer_revertsDelta0() public {
        address instance_ = _openLiveN1();
        uint256 claimed_ = _fundSeSharesLeg(0, attacker, 50e18);

        // Seed inventory on diamond so absolute balance theater would have passed.
        vm.prank(attacker);
        seShares[0].transfer(instance_, claimed_);
        assertEq(seShares[0].balanceOf(instance_), claimed_, "vaultShare inventory on diamond");
        assertEq(seShares[0].balanceOf(attacker), 0);
        assertEq(seShares[0].allowance(attacker, instance_), 0);

        uint256 balBefore_ = seShares[0].balanceOf(instance_);
        uint256 attackerDetfBefore_ = IERC20(instance_).balanceOf(attacker);

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

    /// @notice I1 burn: donate detfToken inventory to diamond; attacker burns pretransferred without transfer.
    function test_I1_pretransferred_burn_detfInventoryNoInCallTransfer_revertsDelta0() public {
        address instance_ = _openLiveN1();
        require(IMultiVaultWeightedDetfInfo(instance_).isBurningAllowed(), "burn open");

        uint256 minted_ = _mintOnLeg(instance_, 0, victim, 40e18);
        uint256 claimed_ = minted_ / 2;
        if (claimed_ == 0) claimed_ = minted_;

        vm.prank(victim);
        IERC20(instance_).transfer(instance_, claimed_);
        assertEq(IERC20(instance_).balanceOf(instance_), claimed_, "detfToken inventory on diamond");
        assertEq(IERC20(instance_).balanceOf(attacker), 0);

        uint256 invBefore_ = IERC20(instance_).balanceOf(instance_);
        uint256 attackerShareBefore_ = seShares[0].balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), claimed_, seShares[0], 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(IERC20(instance_).balanceOf(instance_), invBefore_, "I1 burn must not free-burn inventory");
        assertEq(seShares[0].balanceOf(attacker), attackerShareBefore_, "I1: no free vaultShare extract");
    }

    /// @notice I1 bond: vaultShare inventory + pretransferred without inbound delta reverts.
    function test_I1_pretransferred_bond_inventoryNoInCallTransfer_revertsDelta0() public {
        address instance_ = _openLiveN1();
        uint256 claimed_ = _fundSeSharesLeg(0, attacker, 40e18);

        vm.prank(attacker);
        seShares[0].transfer(instance_, claimed_);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IMultiVaultWeightedDetfBonding(instance_).bond(
            seShares[0], claimed_, DEFAULT_MIN_LOCK, attacker, true, block.timestamp + 1 hours
        );
    }

    /* ---------------------------------------------------------------------- */
    /*  I2: short delivery — claimed > observedDelta                          */
    /* ---------------------------------------------------------------------- */

    /// @notice I2 mint: transfer-before-call is outside the pull window (observedDelta=0).
    /// @dev L-GAPS-9 measures balBefore at entry of _pullToken; prior external transfer is not delta.
    ///      Partial pre-call transfer + pretransferred=true therefore reverts with delta 0, not shortDelta.
    function test_I2_pretransferred_mint_shortDelta_reverts() public {
        address instance_ = _openLiveN1();
        uint256 claimed_ = _fundSeSharesLeg(0, attacker, 60e18);
        uint256 shortDelta_ = claimed_ / 2;
        require(shortDelta_ > 0 && shortDelta_ < claimed_, "need short < claimed");

        // Extra inventory so absolute balance would cover claimed if trusted.
        uint256 extra_ = _fundSeSharesLeg(0, bob, 40e18);
        vm.prank(bob);
        seShares[0].transfer(instance_, extra_);

        vm.startPrank(attacker);
        seShares[0].approve(address(preHelper), shortDelta_);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        preHelper.mintPretransfer(instance_, seShares[0], shortDelta_, claimed_, attacker);
        vm.stopPrank();

        // Helper reverts as one call — short transfer rolls back; only prior extra inventory remains.
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "I2: no mint on short");
        assertEq(seShares[0].balanceOf(instance_), extra_, "I2: only pre-existing inventory remains");
    }

    /// @notice I2 burn: transfer-before-call yields observedDelta=0 (not shortDelta).
    function test_I2_pretransferred_burn_shortDelta_reverts() public {
        address instance_ = _openLiveN1();
        require(IMultiVaultWeightedDetfInfo(instance_).isBurningAllowed(), "burn open");

        uint256 minted_ = _mintOnLeg(instance_, 0, victim, 50e18);
        uint256 extraInv_ = minted_ / 4;
        if (extraInv_ == 0) extraInv_ = 1;
        uint256 claimed_ = minted_ / 2;
        if (claimed_ == 0) claimed_ = minted_;
        uint256 shortDelta_ = claimed_ / 2;
        if (shortDelta_ == 0) shortDelta_ = 1;
        require(shortDelta_ < claimed_, "need short < claimed");

        vm.startPrank(victim);
        IERC20(instance_).transfer(instance_, extraInv_); // residual inventory
        IERC20(instance_).transfer(attacker, claimed_);
        vm.stopPrank();

        uint256 invBeforeTransfer_ = IERC20(instance_).balanceOf(instance_);

        vm.startPrank(attacker);
        IERC20(instance_).approve(address(preHelper), shortDelta_);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
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

        // Seed residual inventory that will remain after first mint.
        uint256 residualSeed_ = _fundSeSharesLeg(0, bob, 30e18);
        vm.prank(bob);
        seShares[0].transfer(instance_, residualSeed_);

        // Honest mint path (!pretransferred) — does not consume residual seed.
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
    /*  K1: donation cannot fund pretransfer credit                           */
    /* ---------------------------------------------------------------------- */

    /// @notice K1: direct donation of vaultShare cannot be credited via pretransferred mint.
    function test_K1_donation_cannotFundPretransferCredit_mint() public {
        address instance_ = _openLiveN1();
        uint256 donated_ = _fundSeSharesLeg(0, attacker, 80e18);

        // Donation (no exchangeIn) — idle inventory.
        vm.prank(attacker);
        seShares[0].transfer(instance_, donated_);

        uint256 balBefore_ = seShares[0].balanceOf(instance_);
        uint256 attackerDetfBefore_ = IERC20(instance_).balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, donated_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            seShares[0], donated_, IERC20(instance_), 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(seShares[0].balanceOf(instance_), balBefore_, "K1 donation unmoved");
        assertEq(IERC20(instance_).balanceOf(attacker), attackerDetfBefore_, "K1 no free detfToken");
    }

    /// @notice Positive control: honest !pretransferred mint (in-call transferFrom) succeeds.
    /// @dev Transfer-before-call + pretransferred=true is outside the pull window under L-GAPS-9;
    ///      the supported honest path is approve + pretransferred=false.
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
