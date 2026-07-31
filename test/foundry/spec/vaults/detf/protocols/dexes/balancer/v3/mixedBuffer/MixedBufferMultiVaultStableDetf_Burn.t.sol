// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";

contract MixedBufferMultiVaultStableDetf_Burn_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function setUp() public override {
        super.setUp();
        detf = _deployOpenThresholdDetfN(1);
        detfInfo = IMixedBufferMultiVaultStableDetfInfo(detf);
        detfBonding = IMixedBufferMultiVaultStableDetfBonding(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _bootstrapDefault(detf, alice);
    }

    function test_burn_to_buffer() public {
        uint256 minted_ = _mintDetfFromBuffer(detf, bob, 100e18);
        uint256 burnAmt_ = minted_ / 2;
        uint256 out_ = _burnDetfToBuffer(detf, bob, burnAmt_);
        assertTrue(out_ > 0, "buffer out");
        _assertNoFreeInventory(detf);
    }

    function test_burn_to_vaultShare_reverts_InvalidRoute() public {
        uint256 minted_ = _mintDetfFromBuffer(detf, bob, 100e18);
        vm.startPrank(bob);
        IERC20(detf).approve(detf, minted_);
        vm.expectRevert(
            abi.encodeWithSelector(
                MixedBufferMultiVaultStableDetfRepo.InvalidRoute.selector, detf, address(seShares[0])
            )
        );
        detfExchangeIn.exchangeIn(
            IERC20(detf), minted_ / 2, seShares[0], 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }
}
