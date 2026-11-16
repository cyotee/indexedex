// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {TestBase_UniswapV4StandardExchangeWeightedBufferHook as TestBase} from "./TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {IUniswapV4StandardExchangeWeightedBufferHook as IHook} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";

contract UniswapV4StandardExchangeWeightedBufferHook_RefundCallback is TestBase {
    function test_refundCallback_observesCompletedComponentOwnership() public {
        SimpleMintableERC20 pair = new SimpleMintableERC20("Pair", "PAIR");
        WeightedRefundObserver raw = new WeightedRefundObserver();
        address se = _deployERC4626SE(address(new SimpleYieldERC4626(pair)));
        address[] memory tokens = new address[](2);
        address[] memory exchanges = new address[](2);
        uint256[] memory weights = new uint256[](2);
        uint256 rawIndex = address(raw) < address(pair) ? 0 : 1;
        tokens[rawIndex] = address(raw);
        tokens[1 - rawIndex] = address(pair);
        exchanges[1 - rawIndex] = se;
        weights[0] = 0.5e18;
        weights[1] = 0.5e18;
        _deployHookWithArgs(_pkgArgs(tokens, weights, exchanges, new address[](2)));
        pair.mint(user, 1000 ether);
        raw.mint(user, 1000 ether);
        vm.startPrank(user);
        pair.approve(hook, type(uint256).max);
        raw.approve(hook, type(uint256).max);
        vm.stopPrank();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100 ether;
        amounts[1] = 100 ether;
        _seedAmounts(user, amounts);
        amounts[rawIndex] = 100 ether;
        amounts[1 - rawIndex] = 1 ether;
        raw.arm(hook, user);
        vm.prank(user);
        (uint256 net, uint256[] memory used) = weighted.joinProportional(amounts, user, 1, block.timestamp);
        assertGt(net, 0);
        assertLt(used[rawIndex], amounts[rawIndex], "real excess input refund");
        assertEq(raw.attempts(), 1, "refund callback reached");
        assertEq(raw.observedSupply(), IERC20(hook).totalSupply(), "refund sees final LP ownership");
        if (raw.querySucceeded()) {
            assertEq(abi.decode(raw.observedBook(), (uint256[])), weighted.nativeReserves(), "refund sees every committed component");
        } else {
            assertEq(raw.observedBook(), abi.encodeWithSignature("Reentrancy()"), "partial book queries reject explicitly");
        }
    }
}

contract WeightedRefundObserver is SimpleMintableERC20 {
    address private hook;
    address private recipient;
    bool private armed;
    uint256 public attempts;
    uint256 public observedSupply;
    bool public querySucceeded;
    bytes public observedBook;

    constructor() SimpleMintableERC20("Refund observer", "OBS") {}

    function arm(address hook_, address recipient_) external {
        hook = hook_;
        recipient = recipient_;
        armed = true;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        if (armed && msg.sender == hook && to == recipient) {
            armed = false;
            ++attempts;
            observedSupply = IERC20(hook).totalSupply();
            (querySucceeded, observedBook) = hook.staticcall(abi.encodeCall(IHook.nativeReserves, ()));
        }
        return true;
    }
}
