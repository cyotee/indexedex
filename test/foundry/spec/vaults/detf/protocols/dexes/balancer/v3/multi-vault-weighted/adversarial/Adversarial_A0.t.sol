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
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";

/// @notice WP-SEC-DETF-MV-A0-001: first mover cannot drain pre-seeded inventory.
/// @dev Donate **before** first bond. Calls the production proxy. No mock SUT.
contract Adversarial_A0_Test is TestBase_MultiVaultWeightedDetf_Adversarial {
    function test_A0_preLive_donatedVaultShare_cannotBeFirstMinted() public {
        address instance_ = _deployOpenModeDetfN(1);
        _assertInert(instance_);
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "no user detfToken pre-live");

        uint256 donated_ = _fundSeSharesLeg(0, attacker, 100e18);
        vm.prank(attacker);
        seShares[0].transfer(instance_, donated_);
        assertEq(seShares[0].balanceOf(instance_), donated_, "donation sits idle");

        vm.startPrank(attacker);
        seShares[0].approve(instance_, donated_);
        vm.expectRevert(MultiVaultWeightedDetfRepo.ReservePoolNotInitialized.selector);
        IStandardExchangeIn(instance_).exchangeIn(
            seShares[0], donated_, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "pre-live mint blocked");
        assertEq(seShares[0].balanceOf(instance_), donated_, "donation unused by failed mint");

        _goLiveViaBptBond(instance_, alice, 1_000e18);
        _assertLive(instance_);
        assertEq(seShares[0].balanceOf(instance_), donated_, "init+bond does not join donation");

        uint256 attackerIn_ = _fundSeSharesLeg(0, attacker, 40e18);
        uint256 preview_ = IStandardExchangeIn(instance_).previewExchangeIn(
            seShares[0], attackerIn_, IERC20(instance_)
        );
        vm.startPrank(attacker);
        seShares[0].approve(instance_, attackerIn_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            seShares[0], attackerIn_, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(out_, preview_, "first mint == preview; idle donation not joined");
        assertEq(seShares[0].balanceOf(instance_), donated_, "donation still idle after first mint");
        assertEq(IERC20(instance_).balanceOf(attacker), out_, "attacker DETF is own pull only");

        // After honest money-route sync, booked residual cannot fund a free pretransfer mint.
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, donated_, uint256(0))
        );
        IStandardExchangeIn(instance_).exchangeIn(
            seShares[0], donated_, IERC20(instance_), 0, attacker, true, block.timestamp + 1 hours
        );
        assertEq(IERC20(instance_).balanceOf(attacker), out_, "booked donation not minted");
    }

    function test_A0_donatedBpt_firstBondDoesNotStealOthersSeed() public {
        address instance_ = _deployOpenModeDetfN(1);
        _assertInert(instance_);

        uint256 donate_ = _fundSeSharesLeg(0, attacker, 80e18);
        vm.prank(attacker);
        seShares[0].transfer(instance_, donate_);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, donate_, uint256(0))
        );
        IMultiVaultWeightedDetfBonding(instance_).bond(
            seShares[0], donate_, DEFAULT_MIN_LOCK, attacker, true, block.timestamp + 1 hours
        );

        assertFalse(IMultiVaultWeightedDetfInfo(instance_).isReserveLive(), "still inert");
        assertEq(seShares[0].balanceOf(instance_), donate_, "donation unmoved");
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "no free detfToken");
    }

    function test_A0_emptyUserSupply_donatedInventory_notDrainedByFirstMint() public {
        address instance_ = _deployOpenModeDetfN(1);
        _assertInert(instance_);
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "empty user supply");
        assertEq(IERC20(instance_).balanceOf(victim), 0, "victim empty");

        uint256 donated_ = _fundSeSharesLeg(0, victim, 80e18);
        vm.prank(victim);
        seShares[0].transfer(instance_, donated_);

        _goLiveViaBptBond(instance_, alice, 1_000e18);
        _assertLive(instance_);
        assertEq(seShares[0].balanceOf(instance_), donated_, "donation idle through go-live");
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "attacker still empty after others go live");

        uint256 attackerIn_ = _fundSeSharesLeg(0, attacker, 40e18);
        uint256 preview_ = IStandardExchangeIn(instance_).previewExchangeIn(
            seShares[0], attackerIn_, IERC20(instance_)
        );
        vm.startPrank(attacker);
        seShares[0].approve(instance_, attackerIn_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            seShares[0], attackerIn_, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(out_, preview_, "first mint matches preview");
        assertEq(IERC20(instance_).balanceOf(attacker), out_, "first mint is attacker pull only");
        assertEq(seShares[0].balanceOf(instance_), donated_, "victim donation still idle");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, donated_, uint256(0))
        );
        IStandardExchangeIn(instance_).exchangeIn(
            seShares[0], donated_, IERC20(instance_), 0, attacker, true, block.timestamp + 1 hours
        );
        assertEq(IERC20(instance_).balanceOf(attacker), out_, "booked donation not drained");
        assertEq(seShares[0].balanceOf(instance_), donated_, "donated inventory not drained");
    }
}
