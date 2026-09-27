// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {HookLiquidityInvariantHandler} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/HookLiquidityInvariantHandler.sol";

/// @dev Concrete test-root artifact exposes the handler ABI to focused invariant runs.
contract Handler_SingleCpHook is HookLiquidityInvariantHandler {
    constructor(Config memory config_) HookLiquidityInvariantHandler(config_) {}
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_Invariant is TestBase {
    HookLiquidityInvariantHandler internal handler;

    function setUp() public override {
        super.setUp();
        _initPool();
        WrapperExactOutRouter route_ = new WrapperExactOutRouter(pm);
        HookLiquidityInvariantHandler.Config memory c;
        c.hook = hook;
        c.mode = 1;
        c.tokens = new SimpleMintableERC20[](2);
        c.tokens[0] = SimpleMintableERC20(single.currency0());
        c.tokens[1] = SimpleMintableERC20(single.currency1());
        c.input = address(pairToken);
        c.output = address(rawToken);
        c.inputSE = se;
        c.inputVault = address(pairProtocolVault);
        c.feeRecipient = address(feeCollector);
        c.router = route_;
        c.key = poolKey;
        c.observedTokens = new IERC20[](5);
        c.observedTokens[0] = IERC20(address(SimpleMintableERC20(single.currency0())));
        c.observedTokens[1] = IERC20(address(SimpleMintableERC20(single.currency1())));
        c.observedTokens[2] = IERC20(address(se));
        c.observedTokens[3] = IERC20(address(pairProtocolVault));
        c.observedTokens[4] = IERC20(address(hook));
        c.observedHolders = new address[](8);
        c.observedHolders[0] = address(hook);
        c.observedHolders[1] = address(se);
        c.observedHolders[2] = address(pairProtocolVault);
        c.observedHolders[3] = address(address(pm));
        c.observedHolders[4] = address(address(route_));
        c.observedHolders[5] = address(address(feeCollector));
        c.observedHolders[6] = address(user);
        c.observedHolders[7] = address(address(0));
        handler = new Handler_SingleCpHook(c);
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
