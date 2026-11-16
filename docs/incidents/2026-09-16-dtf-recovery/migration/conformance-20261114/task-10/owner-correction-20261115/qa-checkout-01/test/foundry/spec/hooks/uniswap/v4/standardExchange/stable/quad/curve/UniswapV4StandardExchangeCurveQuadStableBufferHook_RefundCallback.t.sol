// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook as TestBase} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {IUniswapV4StandardExchangeCurveQuadStableBufferHook as IHook} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage as IPackage} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";

contract UniswapV4StandardExchangeCurveQuadStableBufferHook_RefundCallback is TestBase {
    function test_refundCallback_observesCompletedComponentOwnership() public {
        CurveRefundObserver observer = new CurveRefundObserver();
        token1 = observer;
        IPackage.PkgArgs memory args = _defaultPkgArgs();
        for (uint256 i; i < 4; ++i) for (uint256 j = i + 1; j < 4; ++j) {
            if (args.tokens[j] >= args.tokens[i]) continue;
            (args.tokens[i], args.tokens[j]) = (args.tokens[j], args.tokens[i]);
            (args.standardExchanges[i], args.standardExchanges[j]) = (args.standardExchanges[j], args.standardExchanges[i]);
            (args.rateProviders[i], args.rateProviders[j]) = (args.rateProviders[j], args.rateProviders[i]);
            (args.tokenDecimals[i], args.tokenDecimals[j]) = (args.tokenDecimals[j], args.tokenDecimals[i]);
            (args.seDecimals[i], args.seDecimals[j]) = (args.seDecimals[j], args.seDecimals[i]);
        }
        _deployHookWithArgs(args);
        _fundAndApprove(token0);
        _fundAndApprove(token1);
        _fundAndApprove(token2);
        _fundAndApprove(token3);
        _firstMintEqual(100 ether);
        uint256[] memory amounts = new uint256[](4);
        uint256 observerIndex;
        for (uint256 i; i < 4; ++i) {
            amounts[i] = 1 ether;
            if (args.tokens[i] == address(observer)) observerIndex = i;
        }
        amounts[observerIndex] = 100 ether;
        observer.arm(hook, user);
        vm.prank(user);
        (uint256 net, uint256[] memory used) = quad.joinProportional(amounts, user, 1, block.timestamp);
        assertGt(net, 0);
        assertLt(used[observerIndex], amounts[observerIndex], "real excess raw input is refunded");
        assertEq(observer.attempts(), 1);
        assertEq(observer.observedSupply(), IERC20(hook).totalSupply(), "refund sees final LP ownership");
        if (observer.querySucceeded()) {
            assertEq(abi.decode(observer.observedBook(), (uint256[])), quad.nativeReserves(), "refund sees every committed component");
        } else {
            assertEq(observer.observedBook(), abi.encodeWithSignature("Reentrancy()"));
        }
    }
}

contract CurveRefundObserver is SimpleMintableERC20 {
    address private hook;
    address private recipient;
    bool private armed;
    uint256 public attempts;
    uint256 public observedSupply;
    bool public querySucceeded;
    bytes public observedBook;

    constructor() SimpleMintableERC20("Curve refund observer", "CRO") {}

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
