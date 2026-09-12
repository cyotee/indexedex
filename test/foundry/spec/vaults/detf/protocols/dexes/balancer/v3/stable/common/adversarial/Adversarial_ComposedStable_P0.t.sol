// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IDETF} from "contracts/interfaces/IDETF.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    ILegacyComposedStableCommonDetfBonding as IComposedStableCommonDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenTarget.sol";
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

    function test_E5_zeroAmount_principalPreviewZero() public view {
        assertEq(
            IStandardExchangeIn(deployedDetfVault).previewExchangeIn(detfToken, 0, IERC20(address(rebasingDetfToken))),
            0
        );
    }

    function test_E5_expiredDeadline_reverts() public {
        _bootstrapReserveGraph();
        deal(address(dai), attacker, 10e18, true);
        vm.startPrank(attacker);
        dai.approve(deployedDetfVault, 10e18);
        vm.expectRevert();
        IStandardExchangeIn(deployedDetfVault)
            .exchangeIn(dai, 10e18, detfToken, 0, attacker, false, block.timestamp - 1);
        vm.stopPrank();
    }

    function test_A1_donateDai_cannotMintFreeDetf() public {
        _bootstrapReserveGraph();
        deal(address(dai), attacker, 5e18, true);
        uint256 attDetfBefore_ = detfToken.balanceOf(attacker);
        vm.prank(attacker);
        dai.transfer(deployedDetfVault, 5e18);
        assertEq(detfToken.balanceOf(attacker), attDetfBefore_, "A1: no free DETF from donation");
    }

    function test_A3_D2_unstakeWithoutBalance_noPrincipalDrain() public {
        _bootstrapReserveGraph();
        uint256 lp_ = IERC20(address(reservePool)).balanceOf(address(bondNFTVault));
        _assertFundedUnstakeRejected(deployedDetfVault, attacker, 1, detfToken, 0);
        assertEq(IERC20(address(reservePool)).balanceOf(address(bondNFTVault)), lp_);
    }

    function test_D3_doubleUnstake_secondReverts() public {
        uint256 id_ = _buyFixtureBond(alice);
        _assertBondMaturePreviewEqualsPayment(deployedDetfVault, id_, alice);
        _assertFundedUnstake(deployedDetfVault, alice, _fundedBondStaking(deployedDetfVault).balanceOf(alice));
        _assertFundedUnstakeRejected(deployedDetfVault, alice, 1, detfToken, 0);
    }

    function test_H2_failedUnstake_leavesFundedBalance() public {
        uint256 id_ = _buyFixtureBond(alice);
        _assertBondMaturePreviewEqualsPayment(deployedDetfVault, id_, alice);
        uint256 amount_ = _fundedBondStaking(deployedDetfVault).balanceOf(alice);
        _assertFundedUnstakeRejected(deployedDetfVault, alice, amount_, detfToken, amount_ + 1);
        _assertFundedUnstake(deployedDetfVault, alice, amount_);
    }

    function test_H3_minOutTooHigh_leavesNoStrandedMint() public {
        _bootstrapReserveGraph();
        deal(address(dai), attacker, 10e18, true);
        uint256 preview_ = IStandardExchangeIn(deployedDetfVault).previewExchangeIn(dai, 10e18, detfToken);
        vm.startPrank(attacker);
        dai.approve(deployedDetfVault, 10e18);
        vm.expectRevert();
        IStandardExchangeIn(deployedDetfVault)
            .exchangeIn(dai, 10e18, detfToken, preview_ + 1e18, attacker, false, block.timestamp + 1);
        vm.stopPrank();
        // no free detf minted to attacker on fail
        assertEq(detfToken.balanceOf(attacker), 0, "H3: no detf on fail");
    }

    function test_F2_bondNft_createFundedPosition_onlyDetf() public {
        IDetfBondNFT nft_ = IDetfBondNFT(address(bondNFTVault));
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized(address)", attacker));
        nft_.createFundedPosition(1e9, 30 days, attacker);
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
        uint256 paid_ = _buyFixtureRaw(victim);
        assertGt(paid_, 0);
        uint256 before_ = detfToken.balanceOf(victim);
        assertGt(_buyFixtureRaw(attacker), 0);
        assertEq(detfToken.balanceOf(victim), before_);
    }

    function test_A2_donateDetfToken_noTheft() public {
        uint256 paid_ = _buyFixtureRaw(attacker);
        uint256 donated_ = paid_ / 2;
        assertGt(donated_, 0);
        vm.prank(attacker);
        detfToken.transfer(deployedDetfVault, donated_);
        assertEq(detfToken.balanceOf(deployedDetfVault), donated_);
        assertEq(detfToken.balanceOf(victim), 0);
    }
}
