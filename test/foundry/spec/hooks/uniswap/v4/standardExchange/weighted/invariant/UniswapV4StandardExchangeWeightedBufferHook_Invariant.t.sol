// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {TestBase_UniswapV4StandardExchangeWeightedBufferHook as TestBase} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {HookLiquidityInvariantHandler} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/HookLiquidityInvariantHandler.sol";

/// @dev Concrete test-root artifact exposes the handler ABI to focused invariant runs.
contract Handler_WeightedLiquidity is HookLiquidityInvariantHandler {
    constructor(Config memory config_) HookLiquidityInvariantHandler(config_) {}
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract UniswapV4StandardExchangeWeightedBufferHook_Invariant is TestBase {
    HookLiquidityInvariantHandler internal handler;

    function setUp() public override {
        super.setUp();
        WrapperExactOutRouter route_ = swapRouter;
        HookLiquidityInvariantHandler.Config memory c;
        c.hook = hook;
        c.mode = 0;
        c.tokens = new SimpleMintableERC20[](2);
        c.tokens[0] = token0;
        c.tokens[1] = token1;
        c.input = address(token0);
        c.output = address(token1);
        c.inputSE = se0;
        c.inputVault = address(vault0);
        c.feeRecipient = address(feeCollector);
        c.router = route_;
        c.key = poolKey01;
        c.observedTokens = new IERC20[](5);
        c.observedTokens[0] = IERC20(address(token0));
        c.observedTokens[1] = IERC20(address(token1));
        c.observedTokens[2] = IERC20(address(se0));
        c.observedTokens[3] = IERC20(address(vault0));
        c.observedTokens[4] = IERC20(address(hook));
        c.observedHolders = new address[](8);
        c.observedHolders[0] = address(hook);
        c.observedHolders[1] = address(se0);
        c.observedHolders[2] = address(vault0);
        c.observedHolders[3] = address(address(pm));
        c.observedHolders[4] = address(address(route_));
        c.observedHolders[5] = address(address(feeCollector));
        c.observedHolders[6] = address(user);
        c.observedHolders[7] = address(address(0));
        handler = new Handler_WeightedLiquidity(c);
        bytes4[] memory selectors_ = new bytes4[](1);
        selectors_[0] = handler.cycle.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors_}));
    }

    function invariant_liquidityAccounting() public view { handler.assertAccounting(); }
    function afterInvariant() public view { handler.assertCampaign(); }

    function test_deterministicLifecycle() public {
        for (uint256 i; i < 24; ++i) handler.cycle(10 ether, i, i);
        assertEq(handler.ghost_join(), 24);
        assertEq(handler.ghost_exit(), 24);
        handler.assertCampaign();
    }
}
