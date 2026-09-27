// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRouter} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IRouter.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {TestBase_CommonBufferMultiVaultStablePool as TestBase} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/bases/TestBase_CommonBufferMultiVaultStablePool.sol";
import {BufferPoolInvariantHandler, IBufferInvariantFunding} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/invariant/BufferPoolInvariantHandler.sol";

contract Handler_CommonBufferMultiVaultStable is BufferPoolInvariantHandler {
    constructor(Config memory config_) BufferPoolInvariantHandler(config_) {}
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract CommonBufferMultiVaultStablePoolInvariant is TestBase, IBufferInvariantFunding {
    BufferPoolInvariantHandler internal handler;
    function _targetVaultCount() internal pure override returns (uint8) { return 2; }

    function setUp() public override {
        super.setUp();
        BufferPoolInvariantHandler.Config memory c;
        c.pool = bufferPool;
        c.router = IRouter(address(router));
        c.vault = bv3Vault;
        c.permit2 = IAllowanceTransfer(address(permit2));
        c.buffer = IERC20(address(dai));
        c.shares = IERC20(address(seVault));
        c.funding = IBufferInvariantFunding(address(this));
        c.virtualBookCount = 1;
        c.buffers = new IERC20[](1);
        c.buffers[0] = IERC20(address(dai));
        c.bookCalls = new bytes[](3);
        c.bookCalls[0] = abi.encodeWithSignature("virtualBuffer()");
        c.bookCalls[1] = abi.encodeWithSignature("hookShareDelta(uint256)", 0);
        c.bookCalls[2] = abi.encodeWithSignature("hookShareDelta(uint256)", 1);
        handler = new Handler_CommonBufferMultiVaultStable(c);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = handler.cycle.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function fundInvariantToken(address actor, IERC20 token, uint256 amount) external {
        for (uint8 i; i < 2; ++i) {
            if (address(token) == address(_seVaultAt(i))) {
                mintSharesForVault(i, actor, amount);
                return;
            }
        }
        _mintToken(address(token), actor, amount);
    }

    function invariant_bufferPoolAccounting() public view { handler.assertAccounting(); }
    function afterInvariant() public view { handler.assertCampaign(); }
    function test_deterministicBufferLifecycle() public {
        for (uint256 i; i < 24; ++i) handler.cycle(1e15, i, i);
        assertEq(handler.attempted(), 24);
        handler.assertCampaign();
    }
}
