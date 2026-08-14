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

        uint256 victimShares_ = _fundSeSharesLeg(0, victim, 1_000e18);
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = victimShares_;
        vm.startPrank(victim);
        seShares[0].approve(instance_, victimShares_);
        uint256 bptOut_ = IMultiVaultWeightedDetfBonding(instance_).initializeReserve(
            amounts_, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertFalse(IMultiVaultWeightedDetfInfo(instance_).isReserveLive(), "still inert until bond");

        address pool_ = IMultiVaultWeightedDetfInfo(instance_).reservePool();
        uint256 donate_ = bptOut_ / 2;
        require(donate_ > 0, "need residual BPT");
        vm.prank(victim);
        IERC20(pool_).transfer(instance_, donate_);
        uint256 bondAmt_ = IERC20(pool_).balanceOf(victim);
        assertEq(IERC20(pool_).balanceOf(instance_), donate_, "donated BPT idle pre-bond");

        vm.startPrank(victim);
        IERC20(pool_).approve(instance_, bondAmt_);
        (uint256 tokenId_, uint256 principal_) = IMultiVaultWeightedDetfBonding(instance_).bond(
            IERC20(pool_), bondAmt_, DEFAULT_MIN_LOCK, victim, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        _assertLive(instance_);
        assertEq(principal_, bondAmt_, "first bond principal is pulled BPT only");
        assertEq(
            IDETFNFTVault(IMultiVaultWeightedDetfInfo(instance_).bondNftVault()).originalSharesOf(tokenId_),
            bondAmt_,
            "NFT principal excludes donated BPT"
        );
        assertEq(IERC20(pool_).balanceOf(attacker), 0, "attacker has no BPT");
        assertEq(IERC20(pool_).balanceOf(victim), 0, "victim bonded remaining BPT");
        assertGe(IERC20(pool_).balanceOf(instance_), donate_, "donated BPT stays off first-mover wallet");

        // Honest mint syncs booked residual; attacker cannot bond idle BPT without inbound delta.
        uint256 syncIn_ = _fundSeSharesLeg(0, alice, 40e18);
        vm.startPrank(alice);
        seShares[0].approve(instance_, syncIn_);
        IStandardExchangeIn(instance_).exchangeIn(
            seShares[0], syncIn_, IERC20(instance_), 0, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        uint256 attackerDetfBefore_ = IERC20(instance_).balanceOf(attacker);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, donate_, uint256(0))
        );
        IMultiVaultWeightedDetfBonding(instance_).bond(
            IERC20(pool_), donate_, DEFAULT_MIN_LOCK, attacker, true, block.timestamp + 1 hours
        );
        assertGe(IERC20(pool_).balanceOf(instance_), donate_, "attacker cannot drain donated BPT");
        assertEq(IERC20(instance_).balanceOf(attacker), attackerDetfBefore_, "no free detfToken from donated BPT");
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
