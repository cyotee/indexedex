// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    TestBase_MultiVaultWeightedDetf_Adversarial
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/TestBase_MultiVaultWeightedDetf_Adversarial.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";

/// @notice F1–F4 access control / immutability.
contract Adversarial_Access_Test is TestBase_MultiVaultWeightedDetf_Adversarial {
    function test_F1_noOwnerOnInstance() public {
        address instance_ = _openLiveN1();
        // MultiStepOwnable-style owner() if present should be zero or not expose cut.
        (bool ok, bytes memory ret) = instance_.staticcall(abi.encodeWithSignature("owner()"));
        if (ok && ret.length >= 32) {
            address owner_ = abi.decode(ret, (address));
            assertTrue(owner_ == address(0) || owner_ == instance_, "unowned or self-only wiring");
        }
        // diamondCut must not be freely callable
        (bool cutOk,) = instance_.call(
            abi.encodeWithSignature(
                "diamondCut((address,uint8,bytes4[])[],address,bytes)",
                new bytes(0),
                address(0),
                ""
            )
        );
        assertFalse(cutOk, "diamondCut not available to attacker");
    }

    function test_F2_bondNftVault_onlyOwner() public {
        address instance_ = _openLiveN1();
        IDETFNFTVault bondVault_ = IDETFNFTVault(IMultiVaultWeightedDetfInfo(instance_).bondNftVault());
        vm.prank(attacker);
        vm.expectRevert();
        bondVault_.createPosition(1e18, DEFAULT_MIN_LOCK, attacker);
    }

    function test_F3_claim_mintFromNFTSale_onlyOwner() public {
        address instance_ = _openLiveN1();
        IRebasingClaimToken claim_ =
            IRebasingClaimToken(IMultiVaultWeightedDetfInfo(instance_).rebasingClaimToken());
        assertTrue(address(claim_) != address(0), "claim wired");
        vm.prank(attacker);
        vm.expectRevert();
        claim_.mintFromNFTSale(1e18, attacker);
    }

    function test_F3_claim_burnShares_onlyOwner() public {
        address instance_ = _openLiveN1();
        IRebasingClaimToken claim_ =
            IRebasingClaimToken(IMultiVaultWeightedDetfInfo(instance_).rebasingClaimToken());
        vm.prank(attacker);
        vm.expectRevert();
        claim_.burnShares(1e18, attacker, false);
    }

    function test_F4_weightsImmutable_afterOps() public {
        address instance_ = _openLiveN1();
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);
        (uint256 w0, uint256[] memory vw0) = info_.weights();
        _mintOnLeg(instance_, 0, bob, 20e18);
        (uint256 w1, uint256[] memory vw1) = info_.weights();
        assertEq(w0, w1, "weightDetf immutable");
        assertEq(vw0[0], vw1[0], "vault weight immutable");
        // no setWeights selector
        (bool ok,) = instance_.call(abi.encodeWithSignature("setWeights(uint256,uint256[])", w0, vw0));
        assertFalse(ok, "no setWeights");
    }
}
