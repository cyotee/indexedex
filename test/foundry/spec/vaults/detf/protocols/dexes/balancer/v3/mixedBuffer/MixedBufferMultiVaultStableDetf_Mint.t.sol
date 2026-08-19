// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
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

contract MixedBufferMultiVaultStableDetf_Mint_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function setUp() public override {
        super.setUp();
        // Open thresholds for mint/burn lifecycle without price-shift.
        detf = _deployOpenThresholdDetfN(1);
        detfInfo = IMixedBufferMultiVaultStableDetfInfo(detf);
        detfBonding = IMixedBufferMultiVaultStableDetfBonding(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _bootstrapDefault(detf, alice);
    }

    function test_mint_from_buffer() public {
        uint256 out_ = _mintDetfFromBuffer(detf, bob, 50e18);
        assertTrue(out_ > 0, "minted");
        assertEq(IERC20(detf).balanceOf(bob), out_, "user balance");
        _assertNoFreeInventory(detf);
    }

    function test_liveMint_doesNotJoinDetf() public {
        address pool_ = detfInfo.reservePool();
        uint256 detfIdx_ = detfInfo.detfIndex();
        (,, uint256[] memory before_,) = IVault(address(vault)).getPoolTokenInfo(pool_);
        _mintDetfFromBuffer(detf, bob, 20e18);
        (,, uint256[] memory after_,) = IVault(address(vault)).getPoolTokenInfo(pool_);
        assertEq(after_[detfIdx_], before_[detfIdx_], "D11 no DETF join");
    }

    function test_mint_from_vault_share() public {
        uint256 out_ = _mintDetfFromVaultShare(detf, 0, bob, 50e18);
        assertTrue(out_ > 0, "minted");
        assertEq(IERC20(detf).balanceOf(bob), out_, "user balance");
        _assertNoFreeInventory(detf);
    }

    function test_mint_n2_each_share() public {
        address d2 = _deployOpenThresholdDetfN(2);
        _bootstrapDefault(d2, alice);
        uint256 out0_ = _mintDetfFromVaultShare(d2, 0, bob, 40e18);
        uint256 out1_ = _mintDetfFromVaultShare(d2, 1, bob, 40e18);
        assertTrue(out0_ > 0 && out1_ > 0, "both legs");
        uint256 outBuf_ = _mintDetfFromBuffer(d2, bob, 40e18);
        assertTrue(outBuf_ > 0, "buffer mint");
        _assertNoFreeInventory(d2);
    }
}
