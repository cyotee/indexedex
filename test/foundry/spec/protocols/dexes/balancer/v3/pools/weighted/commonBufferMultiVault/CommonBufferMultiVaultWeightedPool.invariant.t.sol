// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_CommonBufferMultiVaultWeightedPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/bases/TestBase_CommonBufferMultiVaultWeightedPool.sol";
import {
    Handler_CommonBufferMultiVault
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/Handler_CommonBufferMultiVault.sol";

/// forge-config: default.invariant.runs = 20
/// forge-config: default.invariant.depth = 10
contract CommonBufferMultiVaultWeightedPoolInvariant is TestBase_CommonBufferMultiVaultWeightedPool {
    function _targetVaultCount() internal pure override returns (uint8) {
        return 2;
    }

    Handler_CommonBufferMultiVault internal handler;

    function setUp() public override {
        super.setUp();
        handler = new Handler_CommonBufferMultiVault(this);
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = Handler_CommonBufferMultiVault.swap_buffer_in.selector;
        selectors[1] = Handler_CommonBufferMultiVault.swap_share_in.selector;
        selectors[2] = Handler_CommonBufferMultiVault.lp_add_proportional.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_virtualBounded() public view {
        assertLt(cbmv().virtualBuffer(), type(uint128).max, "virtual overflow");
    }

    function invariant_bptSupplyPositive() public view {
        assertGt(IERC20(cbmvPool).totalSupply(), 0, "BPT supply");
    }

    function invariant_physicalBufferSmall() public view {
        // After ops, residual physical buffer should stay modest (swept on buffer-in).
        assertLt(rawPoolBufferBalance(), 50_000e18, "runaway physical buffer");
    }
}
