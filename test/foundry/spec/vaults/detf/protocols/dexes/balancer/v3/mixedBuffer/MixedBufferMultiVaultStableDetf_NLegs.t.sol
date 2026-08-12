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

contract MixedBufferMultiVaultStableDetf_NLegs_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function test_n1_full_lifecycle() public {
        address d = _deployOpenThresholdDetfN(1);
        _bootstrapDefault(d, alice);
        uint256 m1 = _mintDetfFromBuffer(d, bob, 50e18);
        uint256 m2 = _mintDetfFromVaultShare(d, 0, bob, 50e18);
        assertTrue(m1 > 0 && m2 > 0, "mints");
        uint256 burnOut = _burnDetfToBuffer(d, bob, m1 / 2);
        assertTrue(burnOut > 0, "burn");

        _fundBuffer(bob, 80e18);
        vm.startPrank(bob);
        IERC20(address(dai)).approve(d, 80e18);
        (uint256 tid,) = IMixedBufferMultiVaultStableDetfBonding(d).bond(
            IERC20(address(dai)), 80e18, DEFAULT_MIN_LOCK, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(tid > 0, "bond");
        _assertNoFreeInventory(d);
    }

    function test_n2_multi_protocol_lifecycle() public {
        // N=2 multi-pool Aerodrome SE legs sharing DAI buffer.
        address d = _deployOpenThresholdDetfN(2);
        _bootstrapDefault(d, alice);
        assertEq(IMixedBufferMultiVaultStableDetfInfo(d).vaultCount(), 2);
        _mintDetfFromBuffer(d, bob, 40e18);
        _mintDetfFromVaultShare(d, 0, bob, 40e18);
        _mintDetfFromVaultShare(d, 1, bob, 40e18);
        _assertNoFreeInventory(d);
    }

    function test_n3_smoke() public {
        address d = _deployOpenThresholdDetfN(3);
        _bootstrapDefault(d, alice);
        _mintDetfFromBuffer(d, bob, 30e18);
        _fundBuffer(bob, 50e18);
        vm.startPrank(bob);
        IERC20(address(dai)).approve(d, 50e18);
        (uint256 tid,) = IMixedBufferMultiVaultStableDetfBonding(d).bond(
            IERC20(address(dai)), 50e18, DEFAULT_MIN_LOCK, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(tid > 0, "bond n3");
        _assertNoFreeInventory(d);
    }
}
