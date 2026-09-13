// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IDETF} from "contracts/interfaces/IDETF.sol";
import {ILegacyComposedStableCommonDetfBonding as IComposedStableCommonDetfBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ILegacyComposedStableCommonDetfBonding.sol";
import {
    ComposedStableCommonDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol";
import {
    ComposedStableCommonDetf_IntegratedDeploy_Test
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol";

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
        uint256 raw_ = _buyFixtureRaw(actorA);
        uint256 amount_ = raw_ / 2;
        assertGt(amount_, 0);
        IERC20 output_ = IERC20(address(stablePool));
        uint256 quote_ = IStandardExchangeIn(deployedDetfVault).previewExchangeIn(detfToken, amount_, output_);
        assertGt(quote_, 0);
        uint256 before_ = output_.balanceOf(actorA);
        vm.startPrank(actorA);
        detfToken.approve(deployedDetfVault, amount_);
        uint256 paid_ = IStandardExchangeIn(deployedDetfVault)
            .exchangeIn(detfToken, amount_, output_, quote_, actorA, false, block.timestamp);
        vm.stopPrank();
        assertEq(paid_, quote_);
        assertEq(output_.balanceOf(actorA), before_ + paid_);
        assertEq(detfToken.balanceOf(actorA), raw_ - amount_);
        assertEq(detfToken.balanceOf(deployedDetfVault), 0);
    }

    /// @notice P-NODILUTE sequence: actorB mint leaves actorA DETF balance unchanged.
    function test_invariantSequence_multiActor_noDiluteBalance() public {
        uint256 paid_ = _buyFixtureRaw(actorA);
        assertGt(paid_, 0);
        uint256 before_ = detfToken.balanceOf(actorA);
        assertGt(_buyFixtureRaw(actorB), 0);
        assertEq(detfToken.balanceOf(actorA), before_);
    }

    /// @notice Bond then mature sell leaves claim balance for actor (authority path sequence).
    function test_invariantSequence_bondVesting_fundedClaimPositive() public {
        uint256 id_ = _buyFixtureBond(actorA);
        _assertBondPrincipalStillLocked(deployedDetfVault, id_, actorA);
        _assertBondPartialVesting(deployedDetfVault, id_, actorA);
        _assertBondMaturePreviewEqualsPayment(deployedDetfVault, id_, actorA);
        _assertFundedUnstake(deployedDetfVault, actorA, _fundedBondStaking(deployedDetfVault).balanceOf(actorA));
        assertEq(detfToken.balanceOf(deployedDetfVault), 0);
    }
}
