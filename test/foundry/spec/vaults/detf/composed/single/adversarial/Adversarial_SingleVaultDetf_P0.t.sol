// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    SingleVaultDetfExchangeIn_MintWithWeth_Test
} from "test/foundry/spec/vaults/detf/composed/single/SingleVaultDetfExchangeIn_MintWithWeth.t.sol";

/// @notice Wave 3A SingleVaultDetf adversarial P0 on production Uni V4 SE DETF path.
/// @dev Deferred: C1–C3 hostile reentrancy (heavy Uni V4 share wiring); use MultiVault/SingleSE as C gold.
///      Distinguishes intentional donate() API from free-transfer A1 abuse.
contract Adversarial_SingleVaultDetf_P0_Test is SingleVaultDetfExchangeIn_MintWithWeth_Test {
    address internal attacker;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("svAttacker");
    }

    function test_F1_diamondCut_blocked() public {
        (bool ok,) = address(detf).call(
            abi.encodeWithSignature(
                "diamondCut((address,uint8,bytes4[])[],address,bytes)", new bytes(0), address(0), ""
            )
        );
        assertFalse(ok, "F1 cut blocked");
    }

    function test_F2_bondNft_createPosition_onlyOwner() public {
        IDETFNFTVault bond_ = detf.detfNFTVault();
        vm.prank(attacker);
        vm.expectRevert();
        bond_.createPosition(1e18, MIN_LOCK_DURATION, attacker);
    }

    function test_A1_directTransferRateAsset_noFreeMint() public {
        uint256 before_ = IERC20(address(detf)).balanceOf(attacker);
        deal(address(rateAsset), attacker, 100e18, true);
        vm.prank(attacker);
        rateAsset.transfer(address(detf), 100e18);
        assertEq(IERC20(address(detf)).balanceOf(attacker), before_, "A1: no free DETF from transfer");
    }

    function test_E5_zeroAmount_revertsOrNoop() public {
        vm.prank(attacker);
        try IStandardExchangeIn(address(detf)).exchangeIn(
            rateAsset, 0, IERC20(address(detf)), 0, attacker, false, block.timestamp + 1 hours
        ) returns (uint256 out_) {
            assertEq(out_, 0, "E5 zero out");
        } catch {
            // revert is also acceptable
        }
    }

    function test_H3_minOutTooHigh_noStrandedState() public {
        deal(address(rateAsset), attacker, 50e18, true);
        vm.startPrank(attacker);
        rateAsset.approve(address(detf), 50e18);
        vm.expectRevert();
        IStandardExchangeIn(address(detf)).exchangeIn(
            rateAsset, 50e18, IERC20(address(detf)), type(uint128).max, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(IERC20(address(detf)).balanceOf(address(detf)), 0, "H3 residual detf");
    }
}
