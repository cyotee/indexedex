// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_ComposedStableCommonDetf_Decimals
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/TestBase_ComposedStableCommonDetf_Decimals.sol";

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";

/**
 * @title Adversarial_ComposedStable_SecurePull_Test
 * @notice Catalog I1/I2/I3 on production ComposedStable proxy under durable U = B - R.
 * @dev Hold-set (vaultTokens) is detfToken + stable/common BPT — **not** DAI.
 *      Bare DAI donation free-credits by design (L-RSRV-DUST) until/unless hold-set membership changes.
 *      I1/I2 mint on DAI: after bootstrap free DAI balance is 0 → U=0 → free true reverts (claimed, 0).
 *      I3: after honest mint, if free DAI residual remains it free-credits (L-RSRV-DUST);
 *          if residual is 0, free true reverts U=0. Booked hold-set residual (detfToken) cannot free-credit.
 */
abstract contract Adversarial_ComposedStable_SecurePull_Decimals is TestBase_ComposedStableCommonDetf_Decimals {
    address internal attacker;
    address internal honest;

    uint256 internal CLAIMED;
    uint256 internal HONEST_PULL;

    function setUp() public override {
        super.setUp();
        CLAIMED = _from18(address(rateAsset), 10e18);
        HONEST_PULL = CLAIMED;
        attacker = makeAddr("csPullAttacker");
        honest = makeAddr("csPullHonest");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: U=0 (no free DAI), pretransferred=true, no inbound push           */
    /* ---------------------------------------------------------------------- */

    /// @notice I1: after bootstrap free DAI on vault is 0 → U=0; free true reverts (claimed, 0).
    /// @dev Bare `deal` of DAI free-credits by L-RSRV-DUST (DAI not in hold-set) — not an I1 failure.
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        _bootstrapReserveGraph();

        // Option B: free balance after open/bootstrap is 0 → U = 0.
        assertEq(rateAsset.balanceOf(deployedDetfVault), 0, "no free DAI after bootstrap");
        assertEq(rateAsset.balanceOf(attacker), 0);
        assertEq(rateAsset.allowance(attacker, deployedDetfVault), 0);

        uint256 attDetfBefore = detfToken.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, CLAIMED, uint256(0))
        );
        IStandardExchangeIn(deployedDetfVault)
            .exchangeIn(rateAsset, CLAIMED, detfToken, 0, attacker, true, block.timestamp + 1);

        assertEq(rateAsset.balanceOf(deployedDetfVault), 0, "I1 must not transfer in-call");
        assertEq(detfToken.balanceOf(attacker), attDetfBefore, "I1 must not mint free DETF");
    }

    /// @notice I1 variant: any claimed > 0 with U=0 reverts (no free-credit of zero surplus).
    function test_I1_pretransferred_claimedLeInventory_stillReverts() public {
        _bootstrapReserveGraph();
        assertEq(rateAsset.balanceOf(deployedDetfVault), 0, "no free DAI");
        uint256 claimed = CLAIMED / 2;
        if (claimed == 0) claimed = 1;

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed, uint256(0))
        );
        IStandardExchangeIn(deployedDetfVault)
            .exchangeIn(rateAsset, claimed, detfToken, 0, attacker, true, block.timestamp + 1);
    }

    /// @notice L-RSRV-DUST control: bare DAI donation free-credits (DAI not hold-set / not booked).
    /// @dev Documents product law — not a security failure. Contrasts with I1 booked hold-set paths.
    function test_L_RSRV_DUST_bareDaiDonation_freeCreditsPretransfer() public {
        _bootstrapReserveGraph();
        deal(address(rateAsset), honest, CLAIMED, true);
        vm.prank(honest);
        rateAsset.transfer(deployedDetfVault, CLAIMED);
        assertEq(rateAsset.balanceOf(deployedDetfVault), CLAIMED, "unbooked DAI inventory");

        // U = B - R = CLAIMED - 0 → free true succeeds (dust recovery).
        vm.prank(attacker);
        uint256 out_ = IStandardExchangeIn(deployedDetfVault)
            .exchangeIn(rateAsset, CLAIMED, detfToken, 0, attacker, true, block.timestamp + 1);
        assertGt(out_, 0, "L-RSRV-DUST: unbooked DAI funds pretransfer by design");
        assertGt(detfToken.balanceOf(attacker), 0, "attacker received detfToken");
    }

    // Rebasing claim redeem free-extract is owned by WP-I-CLAIM-001.

    /* ---------------------------------------------------------------------- */
    /*  I2: claimed > U with U=0                                              */
    /* ---------------------------------------------------------------------- */

    /// @notice I2: claimed > 0 with U=0 (pretransferred, no inbound, no free DAI).
    function test_I2_pretransferred_claimedGtDelta0_reverts() public {
        _bootstrapReserveGraph();
        assertEq(rateAsset.balanceOf(deployedDetfVault), 0, "no free DAI");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, CLAIMED, uint256(0))
        );
        IStandardExchangeIn(deployedDetfVault)
            .exchangeIn(rateAsset, CLAIMED, detfToken, 0, attacker, true, block.timestamp + 1);
    }

    /* ---------------------------------------------------------------------- */
    /*  I3: residual after honest path                                        */
    /* ---------------------------------------------------------------------- */

    /// @notice I3: after honest pull, free true with no new inbound fails when free DAI residual is 0.
    /// @dev If mint leaves unbooked DAI residual, that free-credits by L-RSRV-DUST (see dust control).
    ///      Hold-set tokens (detfToken/BPT) end-synced residual cannot free-credit — proven when residual detf is booked.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer() public {
        _bootstrapReserveGraph();

        deal(address(rateAsset), honest, HONEST_PULL, true);
        vm.startPrank(honest);
        rateAsset.approve(deployedDetfVault, HONEST_PULL);
        uint256 out_ = IStandardExchangeIn(deployedDetfVault)
            .exchangeIn(rateAsset, HONEST_PULL, detfToken, 0, honest, false, block.timestamp + 1);
        vm.stopPrank();
        assertGt(out_, 0, "honest mint ok");

        uint256 residualDai_ = rateAsset.balanceOf(deployedDetfVault);
        if (residualDai_ > 0) {
            // DAI not in hold-set: residual free-credits by design (L-RSRV-DUST). Not an I3 failure.
            // Prove instead that a second free true claiming more than residual reverts with U=residual.
            uint256 overClaim_ = residualDai_ + 1;
            vm.prank(attacker);
            vm.expectRevert(
                abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, overClaim_, residualDai_)
            );
            IStandardExchangeIn(deployedDetfVault)
                .exchangeIn(rateAsset, overClaim_, detfToken, 0, attacker, true, block.timestamp + 1);
            assertEq(rateAsset.balanceOf(deployedDetfVault), residualDai_, "I3 over-claim does not move residual");
        } else {
            // No free DAI residual → U=0; free true reverts.
            vm.prank(attacker);
            vm.expectRevert(
                abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, CLAIMED, uint256(0))
            );
            IStandardExchangeIn(deployedDetfVault)
                .exchangeIn(rateAsset, CLAIMED, detfToken, 0, attacker, true, block.timestamp + 1);
            assertEq(rateAsset.balanceOf(deployedDetfVault), 0, "I3: still no free DAI");
            assertEq(detfToken.balanceOf(attacker), 0, "I3 no free DETF");
        }
    }
}
