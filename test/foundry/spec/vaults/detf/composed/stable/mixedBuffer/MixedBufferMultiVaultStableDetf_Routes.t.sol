// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/composed/stable/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";

contract MixedBufferMultiVaultStableDetf_Routes_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function setUp() public override {
        super.setUp();
        detf = _deployOpenThresholdDetfN(2);
        detfInfo = IMixedBufferMultiVaultStableDetfInfo(detf);
        detfBonding = IMixedBufferMultiVaultStableDetfBonding(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _bootstrapDefault(detf, alice);
    }

    function test_share_to_share_InvalidRoute() public {
        uint256 s0_ = _fundVaultShares(0, bob, 50e18);
        vm.startPrank(bob);
        seShares[0].approve(detf, s0_);
        vm.expectRevert();
        detfExchangeIn.exchangeIn(
            seShares[0], s0_, seShares[1], 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_unconfigured_token_InvalidRoute() public {
        _fundBuffer(bob, 10e18);
        // usdc is not buffer for this DETF (buffer=dai) and not a vault share
        vm.startPrank(bob);
        IERC20(address(usdc)).approve(detf, 10e18);
        // mint usdc to bob first
        vm.stopPrank();
        _mintToken(address(usdc), bob, 10e18);
        vm.startPrank(bob);
        IERC20(address(usdc)).approve(detf, 10e18);
        vm.expectRevert();
        detfExchangeIn.exchangeIn(
            IERC20(address(usdc)), 10e18, IERC20(detf), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_exactOut_InvalidRoute() public {
        // exact-out is not a closed-form route; diamond previewExchangeOut must revert.
        (bool ok,) = detf.call(
            abi.encodeWithSignature(
                "previewExchangeOut(address,address,uint256)", address(dai), detf, uint256(1e18)
            )
        );
        assertFalse(ok, "expected InvalidRoute revert");
    }
}
