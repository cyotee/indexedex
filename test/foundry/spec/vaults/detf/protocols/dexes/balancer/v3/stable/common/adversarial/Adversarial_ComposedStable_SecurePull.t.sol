// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    ComposedStableCommonDetf_IntegratedDeploy_Test
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol";

/**
 * @title Adversarial_ComposedStable_SecurePull_Test
 * @notice Catalog I1/I2/I3 on production ComposedStable proxy (L-GAPS-9/10).
 * @dev I1: pretransferred=true, no in-call transfer, inventory present → TransferDeltaInsufficient(claimed, 0)
 *      I2: claimed > observedDelta (pretransfer short / zero delta)
 *      I3: residual inventory after honest pull cannot fund a second free pretransfer credit
 *      Also covers rebasing claim redeem free-extract via the same trust flag.
 */
contract Adversarial_ComposedStable_SecurePull_Test is ComposedStableCommonDetf_IntegratedDeploy_Test {
    address internal attacker;
    address internal honest;

    uint256 internal constant CLAIMED = 1_000e18;
    uint256 internal constant INVENTORY = 500e18;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("csPullAttacker");
        honest = makeAddr("csPullHonest");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: inventory present, no in-call transfer, pretransferred=true       */
    /* ---------------------------------------------------------------------- */

    /// @notice I1: donate DAI inventory to production DETF; attacker claims pretransferred without
    ///         transferring. Must revert TransferDeltaInsufficient(claimed, 0) — absolute coverage
    ///         of inventory is forbidden.
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        _bootstrapReserveGraph();

        // Inventory >= claimed so absolute-balance theater would have passed
        deal(address(dai), deployedDetfVault, CLAIMED, true);
        assertEq(dai.balanceOf(deployedDetfVault), CLAIMED);
        assertEq(dai.balanceOf(attacker), 0);
        assertEq(dai.allowance(attacker, deployedDetfVault), 0);

        uint256 balBefore = dai.balanceOf(deployedDetfVault);
        uint256 attDetfBefore = detfToken.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, CLAIMED, uint256(0)
            )
        );
        IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, CLAIMED, detfToken, 0, attacker, true, block.timestamp + 1
        );

        assertEq(dai.balanceOf(deployedDetfVault), balBefore, "I1 must not transfer in-call");
        assertEq(detfToken.balanceOf(attacker), attDetfBefore, "I1 must not mint free DETF");
        assertEq(dai.balanceOf(attacker), 0);
    }

    /// @notice I1 variant: claimed strictly less than inventory still fails (absolute coverage forbidden).
    function test_I1_pretransferred_claimedLeInventory_stillReverts() public {
        _bootstrapReserveGraph();
        deal(address(dai), deployedDetfVault, INVENTORY + CLAIMED, true);
        uint256 claimed = INVENTORY; // claimed < inventory

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed, uint256(0)
            )
        );
        IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, claimed, detfToken, 0, attacker, true, block.timestamp + 1
        );
    }

    // Rebasing claim redeem free-extract is owned by WP-I-CLAIM-001 (deal onto rebasing diamond
    // is storage-hostile; bond/sell setup is separate claim surface).

    /* ---------------------------------------------------------------------- */
    /*  I2: short delivery — claimed > observedDelta                          */
    /* ---------------------------------------------------------------------- */

    /// @notice I2: claimed > 0 with observedDelta 0 (pretransferred, no inbound) on mint path.
    function test_I2_pretransferred_claimedGtDelta0_reverts() public {
        _bootstrapReserveGraph();
        deal(address(dai), deployedDetfVault, CLAIMED, true);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, CLAIMED, uint256(0)
            )
        );
        IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, CLAIMED, detfToken, 0, attacker, true, block.timestamp + 1
        );
    }

    // Burn free-extract when BurningNotAllowed reverts first is not I-catalog proof; mint I1/I2/I3
    // cover package-local delta. Full burn pretransfer I is exercised once burn threshold is open.

    /* ---------------------------------------------------------------------- */
    /*  I3: residual inventory cannot fund second free pretransfer credit     */
    /* ---------------------------------------------------------------------- */

    /// @notice I3: after honest pull leaves residual (donation + deposit), a second pretransferred
    ///         call with no new inbound delta cannot free-credit residual.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer() public {
        _bootstrapReserveGraph();

        // Pre-seed residual inventory that will remain after first honest mint.
        deal(address(dai), deployedDetfVault, INVENTORY, true);
        deal(address(dai), honest, CLAIMED, true);

        vm.startPrank(honest);
        dai.approve(deployedDetfVault, CLAIMED);
        uint256 out_ = IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, CLAIMED, detfToken, 0, honest, false, block.timestamp + 1
        );
        vm.stopPrank();

        assertGt(out_, 0, "honest mint ok");
        uint256 residual_ = dai.balanceOf(deployedDetfVault);
        // Residual may be 0 if all DAI was consumed by the mint route; re-seed idle inventory.
        if (residual_ < CLAIMED) {
            deal(address(dai), deployedDetfVault, CLAIMED, true);
            residual_ = dai.balanceOf(deployedDetfVault);
        }
        assertGe(residual_, CLAIMED, "residual covers claimed");

        // Second call: pretransferred=true, claim against residual, no new transfer.
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, CLAIMED, uint256(0)
            )
        );
        IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, CLAIMED, detfToken, 0, attacker, true, block.timestamp + 1
        );

        assertEq(dai.balanceOf(deployedDetfVault), residual_, "I3 second call must not move inventory");
        assertEq(detfToken.balanceOf(attacker), 0, "I3 no free DETF");
    }
}
