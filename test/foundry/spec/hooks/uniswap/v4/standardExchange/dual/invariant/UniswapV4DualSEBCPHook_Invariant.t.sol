// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {TestBase_UniswapV4DualSEBCPHook as TestBase} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {HookLiquidityInvariantHandler} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/HookLiquidityInvariantHandler.sol";

/// @dev Concrete test-root artifact exposes the handler ABI to focused invariant runs.
contract Handler_DualBufferHook is HookLiquidityInvariantHandler {
    constructor(Config memory config_) HookLiquidityInvariantHandler(config_) {}
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract UniswapV4DualSEBCPHook_Invariant is TestBase {
    HookLiquidityInvariantHandler internal handler;

    function setUp() public override {
        super.setUp();
        _initPool();
        WrapperExactOutRouter route_ = new WrapperExactOutRouter(pm);
        HookLiquidityInvariantHandler.Config memory c;
        c.hook = hook;
        c.mode = 1;
        c.tokens = new SimpleMintableERC20[](2);
        c.tokens[0] = SimpleMintableERC20(dual.currency0());
        c.tokens[1] = SimpleMintableERC20(dual.currency1());
        c.input = address(tokenA);
        c.output = address(tokenB);
        c.inputSE = seA;
        c.inputVault = address(vaultA);
        c.feeRecipient = address(feeCollector);
        c.router = route_;
        c.key = poolKey;
        c.observedTokens = new IERC20[](7);
        c.observedTokens[0] = IERC20(address(SimpleMintableERC20(dual.currency0())));
        c.observedTokens[1] = IERC20(address(SimpleMintableERC20(dual.currency1())));
        c.observedTokens[2] = IERC20(address(seA));
        c.observedTokens[3] = IERC20(address(seB));
        c.observedTokens[4] = IERC20(address(vaultA));
        c.observedTokens[5] = IERC20(address(vaultB));
        c.observedTokens[6] = IERC20(address(hook));
        c.observedHolders = new address[](10);
        c.observedHolders[0] = address(hook);
        c.observedHolders[1] = address(seA);
        c.observedHolders[2] = address(seB);
        c.observedHolders[3] = address(vaultA);
        c.observedHolders[4] = address(vaultB);
        c.observedHolders[5] = address(address(pm));
        c.observedHolders[6] = address(address(route_));
        c.observedHolders[7] = address(address(feeCollector));
        c.observedHolders[8] = address(user);
        c.observedHolders[9] = address(address(0));
        handler = new Handler_DualBufferHook(c);
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
