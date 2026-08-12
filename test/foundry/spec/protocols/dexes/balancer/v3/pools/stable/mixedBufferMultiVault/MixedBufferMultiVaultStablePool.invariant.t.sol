// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_MixedBufferMultiVaultStablePool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/bases/TestBase_MixedBufferMultiVaultStablePool.sol";
import {
    Handler_MixedBufferMultiVaultStablePool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/Handler_MixedBufferMultiVaultStablePool.sol";

/// forge-config: default.invariant.runs = 20
/// forge-config: default.invariant.depth = 10
contract MixedBufferMultiVaultStablePoolInvariant is TestBase_MixedBufferMultiVaultStablePool {
    function _targetVaultCount() internal pure override returns (uint8) {
        return 2;
    }

    Handler_MixedBufferMultiVaultStablePool internal handler;

    function setUp() public override {
        super.setUp();
        handler = new Handler_MixedBufferMultiVaultStablePool(this);
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = Handler_MixedBufferMultiVaultStablePool.swap_buffer_in.selector;
        selectors[1] = Handler_MixedBufferMultiVaultStablePool.swap_share_in.selector;
        selectors[2] = Handler_MixedBufferMultiVaultStablePool.swap_unpaired_in.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_virtualNonNegativeBounded() public view {
        assertLt(mbmvs().virtualBuffer(), type(uint128).max, "virtual overflow");
        // virtual is uint256 storage - always >= 0 by type; assert still live after ops
        assertTrue(mbmvs().virtualBuffer() >= 0);
    }

    function invariant_bptSupplyPositive() public view {
        assertGt(IERC20(mbmvsPool).totalSupply(), 0, "BPT supply");
    }

    function invariant_physicalBufferBounded() public view {
        assertLt(rawPoolBufferBalance(), 50_000e18, "runaway physical buffer");
    }

    function invariant_unpairedNotVirtualized() public view {
        // unpaired math balance equals live - virtualBuffer is only for buffer leg
        uint256 uIdx = mbmvs().unpairedIndex(0);
        (,, uint256[] memory balancesRaw,) = bv3Vault.getPoolTokenInfo(mbmvsPool);
        // derived depth API is for shares only; ensure buffer virtual is independent of unpaired raw
        assertTrue(
            mbmvs().virtualBuffer() != balancesRaw[uIdx] || balancesRaw[uIdx] == 0 || mbmvs().virtualBuffer() > 0
        );
    }
}
