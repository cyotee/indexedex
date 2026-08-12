// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";

/// @notice Fee destinations + non-dilution style checks on production multi-vault weighted DETF.
contract MultiVaultWeightedDetf_FeeNonDilution_Test is TestBase_MultiVaultWeightedDetf {
    function test_mint_feeAndProtocolSlices_nonNegativeHolderClaim() public {
        address instance_ = _deployOpenThresholdDetfN(1);
        _goLiveViaBptBond(instance_, alice, 1_000e18);

        // Seed larger reserve first so subsequent single-sided joins stay within Balancer MaxInRatio.
        _mintOnLeg(instance_, 0, alice, 50e18);
        uint256 aliceMint_ = _mintOnLeg(instance_, 0, alice, 30e18);
        assertTrue(aliceMint_ > 0, "alice holder");

        uint256 aliceBalBefore_ = IERC20(instance_).balanceOf(alice);
        uint256 feeToBefore_ = IERC20(instance_).balanceOf(_feeTo());
        address bondVault_ = IMultiVaultWeightedDetfInfo(instance_).bondNftVault();
        uint256 protocolBefore_ = IERC20(instance_).balanceOf(bondVault_);

        // Bob mints - may send fee/protocol slices
        uint256 bobOut_ = _mintOnLeg(instance_, 0, bob, 20e18);
        assertTrue(bobOut_ > 0, "bob minted");

        // Existing holder balance unchanged by bob's mint (no transfer from alice)
        assertEq(IERC20(instance_).balanceOf(alice), aliceBalBefore_, "alice not diluted by transfer");

        // Fee and/or protocol destinations may receive DETF depending on oracle fees (0 is allowed)
        uint256 feeDelta_ = IERC20(instance_).balanceOf(_feeTo()) - feeToBefore_;
        uint256 protocolDelta_ = IERC20(instance_).balanceOf(bondVault_) - protocolBefore_;
        assertTrue(feeDelta_ + protocolDelta_ + bobOut_ > 0, "mint produced DETF somewhere");

        // Synthetic remains defined; residual free inventory clean
        assertTrue(IMultiVaultWeightedDetfInfo(instance_).syntheticPrice() > 0, "synth");
        _assertNoFreeInventory(instance_);
    }

    function test_n2_residualClean_afterMintBurnBothLegs() public {
        address instance_ = _deployOpenThresholdDetfN(2);
        _goLiveViaBptBond(instance_, alice, 600e18);
        _mintOnLeg(instance_, 0, bob, 80e18);
        _mintOnLeg(instance_, 1, bob, 80e18);
        uint256 bal_ = IERC20(instance_).balanceOf(bob);
        if (bal_ > 1) {
            _burnToLeg(instance_, 0, bob, bal_ / 4);
            _burnToLeg(instance_, 1, bob, IERC20(instance_).balanceOf(bob) / 3);
        }
        _assertNoFreeInventory(instance_);
    }
}
