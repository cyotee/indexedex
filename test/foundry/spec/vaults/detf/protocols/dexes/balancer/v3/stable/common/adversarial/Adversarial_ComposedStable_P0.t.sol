// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IDETF} from "contracts/interfaces/IDETF.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IComposedStableCommonDetfBonding} from "contracts/interfaces/IComposedStableCommonDetfBonding.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    ComposedStableCommonDetf_IntegratedDeploy_Test
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol";

/// @notice Wave 1B P0 adversarial coverage on production ComposedStable graph.
/// @dev C1–C3 lock proofs live in Adversarial_ComposedStable_SecRemediation.t.sol (WP-SEC-DETF-CS-LOCK-001).
///      Deferred P2: B route grief.
///      H2 claim atomicity: failed redeem leaves claim balance (see also RebasingDETFTokenBehavior).
contract Adversarial_ComposedStable_P0_Test is ComposedStableCommonDetf_IntegratedDeploy_Test {
    address internal attacker;
    address internal victim;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
    }

    function test_E5_zeroAmount_mintPreviewZero() public view {
        assertEq(
            IStandardExchangeIn(deployedDetfVault).previewExchangeIn(dai, 0, detfToken),
            0,
            "E5 zero preview"
        );
    }

    function test_E5_expiredDeadline_reverts() public {
        _bootstrapReserveGraph();
        deal(address(dai), attacker, 1_000e18, true);
        vm.startPrank(attacker);
        dai.approve(deployedDetfVault, 1_000e18);
        vm.expectRevert();
        IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, 1_000e18, detfToken, 0, attacker, false, block.timestamp - 1
        );
        vm.stopPrank();
    }

    function test_A1_donateDai_cannotMintFreeDetf() public {
        _bootstrapReserveGraph();
        deal(address(dai), attacker, 500e18, true);
        uint256 attDetfBefore_ = detfToken.balanceOf(attacker);
        vm.prank(attacker);
        dai.transfer(deployedDetfVault, 500e18);
        assertEq(detfToken.balanceOf(attacker), attDetfBefore_, "A1: no free DETF from donation");
    }

    function test_A3_D2_redeemWithoutClaim_noPrincipalDrain() public {
        _bootstrapReserveGraph();
        address pool_ = IDETF(deployedDetfVault).reservePool();
        uint256 bptBefore_ = IERC20(pool_).balanceOf(deployedDetfVault);

        vm.prank(attacker);
        vm.expectRevert();
        rebasingDetfToken.redeem(1e18, attacker, false);

        assertEq(IERC20(pool_).balanceOf(deployedDetfVault), bptBefore_, "D2/A3: BPT intact");
    }

    function test_D3_doubleRedeemClaim_secondReverts() public {
        _bootstrapReserveGraph();
        deal(address(dai), alice, 2_000e18, true);
        vm.startPrank(alice);
        dai.approve(deployedDetfVault, 2_000e18);
        (uint256 tokenId_,) = IComposedStableCommonDetfBonding(deployedDetfVault).bond(
            dai, 1_000e18, 30 days, alice, block.timestamp + 1
        );
        _warpPastUnlock(tokenId_);
        uint256 claim_ = IComposedStableCommonDetfBonding(deployedDetfVault).sellPositionToDetfNft(tokenId_, 0, alice);
        uint256 part_ = claim_ / 2;
        if (part_ == 0) part_ = claim_;
        rebasingDetfToken.redeem(part_, alice, false);
        uint256 left_ = rebasingDetfToken.balanceOf(alice);
        vm.expectRevert();
        rebasingDetfToken.redeem(left_ + 1e18, alice, false);
        vm.stopPrank();
    }

    function test_H2_redeemClaim_failLeavesClaim() public {
        _bootstrapReserveGraph();
        deal(address(dai), alice, 2_000e18, true);
        vm.startPrank(alice);
        dai.approve(deployedDetfVault, 2_000e18);
        (uint256 tokenId_,) = IComposedStableCommonDetfBonding(deployedDetfVault).bond(
            dai, 1_000e18, 30 days, alice, block.timestamp + 1
        );
        _warpPastUnlock(tokenId_);
        uint256 claim_ = IComposedStableCommonDetfBonding(deployedDetfVault).sellPositionToDetfNft(tokenId_, 0, alice);
        uint256 before_ = rebasingDetfToken.balanceOf(alice);
        // Over-redeem reverts; claim balance must be unchanged (D15 DETF-only redeem).
        vm.expectRevert();
        rebasingDetfToken.redeem(before_ + 1, alice, false);
        assertEq(rebasingDetfToken.balanceOf(alice), before_, "H2: claim unchanged after fail");
        claim_;
        vm.stopPrank();
    }

    function test_H3_minOutTooHigh_leavesNoStrandedMint() public {
        _bootstrapReserveGraph();
        deal(address(dai), attacker, 1_000e18, true);
        uint256 preview_ =
            IStandardExchangeIn(deployedDetfVault).previewExchangeIn(dai, 1_000e18, detfToken);
        vm.startPrank(attacker);
        dai.approve(deployedDetfVault, 1_000e18);
        vm.expectRevert();
        IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, 1_000e18, detfToken, preview_ + 1e18, attacker, false, block.timestamp + 1
        );
        vm.stopPrank();
        // no free detf minted to attacker on fail
        assertEq(detfToken.balanceOf(attacker), 0, "H3: no detf on fail");
    }

    function test_F2_bondNft_createPosition_onlyOwner() public {
        _bootstrapReserveGraph();
        IDETFNFTVault bond_ = IDETFNFTVault(IDETF(deployedDetfVault).bondNftVault());
        vm.prank(attacker);
        vm.expectRevert();
        bond_.createPosition(1e18, 30 days, attacker);
    }

    function test_F1_diamondCut_blocked() public {
        (bool ok,) = deployedDetfVault.call(
            abi.encodeWithSignature(
                "diamondCut((address,uint8,bytes4[])[],address,bytes)", new bytes(0), address(0), ""
            )
        );
        assertFalse(ok, "F1 cut blocked");
    }

    function test_E4_holderBalance_notDilutedByOthersMint() public {
        _bootstrapReserveGraph();
        deal(address(dai), victim, 2_000e18, true);
        deal(address(dai), attacker, 2_000e18, true);
        vm.startPrank(victim);
        dai.approve(deployedDetfVault, 1_000e18);
        uint256 out_ = IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, 1_000e18, detfToken, 0, victim, false, block.timestamp + 1
        );
        vm.stopPrank();
        uint256 victimBal_ = detfToken.balanceOf(victim);
        assertTrue(out_ > 0 && victimBal_ > 0, "victim holds");

        vm.startPrank(attacker);
        dai.approve(deployedDetfVault, 500e18);
        IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, 500e18, detfToken, 0, attacker, false, block.timestamp + 1
        );
        vm.stopPrank();
        assertEq(detfToken.balanceOf(victim), victimBal_, "E4: victim balance unchanged");
    }

    function test_A2_donateDetfToken_noTheft() public {
        _bootstrapReserveGraph();
        deal(address(dai), attacker, 2_000e18, true);
        vm.startPrank(attacker);
        dai.approve(deployedDetfVault, 1_000e18);
        uint256 minted_ = IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai, 1_000e18, detfToken, 0, attacker, false, block.timestamp + 1
        );
        uint256 donate_ = minted_ / 2;
        if (donate_ == 0) donate_ = minted_;
        detfToken.transfer(deployedDetfVault, donate_);
        vm.stopPrank();
        assertEq(detfToken.balanceOf(deployedDetfVault), donate_, "donated detf idle");
        assertEq(detfToken.balanceOf(victim), 0, "victim not credited");
    }
}
