// SPDX-License-Identifier: BSL-1.1
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

contract MixedBufferMultiVaultStableDetf_Burn_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function setUp() public virtual override {
        super.setUp();
        detf = _deployDetfN(1, 100e18, 10e18);
        detfInfo = IMixedBufferMultiVaultStableDetfInfo(detf);
        detfBonding = IMixedBufferMultiVaultStableDetfBonding(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _bootstrapDefault(detf, alice);
        assertTrue(detfInfo.isBurningAllowed(), "primary burn fixture");
    }

    function test_burn_to_buffer() public virtual {
        uint256 minted_ = _mintDetfFromBuffer(detf, bob, _fixtureAmount(100e18));
        uint256 burnAmt_ = minted_ / 2;
        uint256 out_ = _burnDetfToBuffer(detf, bob, burnAmt_);
        assertTrue(out_ > 0, "buffer out");
        _assertNoFreeInventory(detf);
    }

    function test_burn_to_vaultShare() public virtual {
        uint256 minted_ = _mintDetfFromBuffer(detf, bob, _fixtureAmount(100e18));
        vm.startPrank(bob);
        IERC20(detf).approve(detf, minted_);
        uint256 out_ = detfExchangeIn.exchangeIn(
            IERC20(detf), minted_ / 2, seShares[0], 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(out_ > 0, "share out");
        assertTrue(seShares[0].balanceOf(bob) >= out_, "share received");
        _assertNoFreeInventory(detf);
    }
}
