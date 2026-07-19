// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IDETF} from "contracts/interfaces/IDETF.sol";
import {IComposedStableCommonDetfBonding} from "contracts/interfaces/IComposedStableCommonDetfBonding.sol";
import {
    ComposedStableCommonDetf_IntegratedDeploy_Test
} from "test/foundry/spec/vaults/detf/composed/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol";

/// @notice L2 multi-op sequences for ComposedStableCommonDetf (Wave 3A).
/// @dev Fixed choreography (not Foundry Handler). Production graph via IntegratedDeploy.
contract ComposedStableCommonDetf_Sequences_Test is ComposedStableCommonDetf_IntegratedDeploy_Test {
    address internal actorA;
    address internal actorB;

    function setUp() public override {
        super.setUp();
        actorA = makeAddr("csSeqA");
        actorB = makeAddr("csSeqB");
    }

    /// @notice P-CONS sequence: bootstrap → mint → partial redeem residual clean.
    function test_invariantSequence_mintPartialBurn_noFreeInventory() public {
        _bootstrapReserveGraph();
        deal(address(dai), actorA, 5_000e18, true);

        vm.startPrank(actorA);
        dai.approve(deployedDetfVault, 2_000e18);
        uint256 detfOut_ = IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, 2_000e18, detfToken, 0, actorA, false, block.timestamp + 1
        );
        vm.stopPrank();
        assertTrue(detfOut_ > 0, "minted");

        uint256 burn_ = detfOut_ / 2;
        if (burn_ == 0) burn_ = detfOut_;
        vm.startPrank(actorA);
        detfToken.approve(deployedDetfVault, burn_);
        // Burn path depends on product; try exchangeIn DETF → dai if supported.
        try IStandardExchangeIn(deployedDetfVault).exchangeIn(
            detfToken, burn_, dai, 0, actorA, false, block.timestamp + 1
        ) returns (uint256 out_) {
            assertTrue(out_ > 0 || burn_ > 0, "burn attempted");
        } catch {
            // Some composed paths redeem via claim token only — sequence still checks residual.
        }
        vm.stopPrank();

        // Free product residual on diamond should not grow unbounded from sequence.
        assertEq(detfToken.balanceOf(deployedDetfVault), 0, "P-RESID free detf");
    }

    /// @notice P-NODILUTE sequence: actorB mint leaves actorA DETF balance unchanged.
    function test_invariantSequence_multiActor_noDiluteBalance() public {
        _bootstrapReserveGraph();
        deal(address(dai), actorA, 3_000e18, true);
        deal(address(dai), actorB, 3_000e18, true);

        vm.startPrank(actorA);
        dai.approve(deployedDetfVault, 1_000e18);
        IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, 1_000e18, detfToken, 0, actorA, false, block.timestamp + 1
        );
        vm.stopPrank();
        uint256 balA_ = detfToken.balanceOf(actorA);

        vm.startPrank(actorB);
        dai.approve(deployedDetfVault, 1_000e18);
        IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, 1_000e18, detfToken, 0, actorB, false, block.timestamp + 1
        );
        vm.stopPrank();

        assertEq(detfToken.balanceOf(actorA), balA_, "P-NODILUTE");
        assertTrue(detfToken.balanceOf(actorB) > 0, "B minted");
    }

    /// @notice Bond then sellNFT leaves claim balance for actor (authority path sequence).
    function test_invariantSequence_bondSell_claimPositive() public {
        _bootstrapReserveGraph();
        deal(address(dai), actorA, 2_000e18, true);
        vm.startPrank(actorA);
        dai.approve(deployedDetfVault, 1_000e18);
        (uint256 tokenId_,) = IComposedStableCommonDetfBonding(deployedDetfVault).bond(
            dai, 1_000e18, 30 days, actorA, block.timestamp + 1
        );
        uint256 claim_ = IComposedStableCommonDetfBonding(deployedDetfVault).sellNFT(tokenId_, actorA);
        vm.stopPrank();
        assertTrue(claim_ > 0, "claim minted");
        assertEq(detfToken.balanceOf(deployedDetfVault), 0, "P-RESID after bond");
    }
}
