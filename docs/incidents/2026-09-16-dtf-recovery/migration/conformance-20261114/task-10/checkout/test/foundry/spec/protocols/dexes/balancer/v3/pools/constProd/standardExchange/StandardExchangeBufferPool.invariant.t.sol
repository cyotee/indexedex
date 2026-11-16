// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRouter} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IRouter.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {TestBase_StandardExchangeBufferPool as TestBase} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";
import {BufferPoolInvariantHandler, IBufferInvariantFunding} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/invariant/BufferPoolInvariantHandler.sol";
import {Handler_StandardExchangeBufferPool} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/Handler_StandardExchangeBufferPool.sol";


/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract StandardExchangeBufferPoolInvariant is TestBase, IBufferInvariantFunding {
    BufferPoolInvariantHandler internal handler;

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
        c.bookCalls = new bytes[](2);
        c.bookCalls[0] = abi.encodeWithSignature("virtualTTA()");
        c.bookCalls[1] = abi.encodeWithSignature("hookSharesDelta()");
        handler = new Handler_StandardExchangeBufferPool(c);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = handler.cycle.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function fundInvariantToken(address actor, IERC20 token, uint256 amount) external {
        if (address(token) == address(seVault)) mintShares(actor, amount);
        else dai.mint(actor, amount);
    }

    function invariant_bufferPoolAccounting() public view { handler.assertAccounting(); }
    function afterInvariant() public view { handler.assertCampaign(); }
    function test_deterministicBufferLifecycle() public {
        for (uint256 i; i < 24; ++i) handler.cycle(1e15, i, i);
        assertEq(handler.attempted(), 24);
        handler.assertCampaign();
    }
}
