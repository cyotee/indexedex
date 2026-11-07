// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TestBase_UniswapV4StandardExchangeOrbitalBufferHook as TestBase} from
    "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {IUniswapV4StandardExchangeOrbitalBufferHook as IHook} from
    "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {IUniswapV4SeBufferHookNativeLiquidity} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";

contract UniswapV4StandardExchangeOrbitalBufferHook_RefundCallback is TestBase {
    function test_nativeRefundCallback_cannotReenterJoin() public {
        OrbitalRefundObserver observer = new OrbitalRefundObserver();
        token1 = SimpleMintableERC20(address(observer));
        _deployHookWithArgs(_defaultPkgArgs());
        token1.mint(user, 1000 ether);
        vm.startPrank(user);
        token0.approve(hook, type(uint256).max);
        token1.approve(hook, type(uint256).max);
        token2.approve(hook, type(uint256).max);
        vm.stopPrank();
        _seedFor(orbital, user, 100 ether, 100 ether, 100 ether);
        uint256 acquired = _mintSeSharesToUser(se0, token0, 10 ether);
        uint256[] memory local = new uint256[](3);
        uint256[] memory shares = new uint256[](3);
        local[0] = 1 ether;
        local[1] = 1 ether;
        local[2] = 3 ether;
        shares[0] = acquired / 10;
        observer.armNative(hook, user);
        vm.prank(user);
        uint256 net = IUniswapV4SeBufferHookNativeLiquidity(hook).joinNativeComponents(
            local, shares, user, 1, block.timestamp
        );
        assertGt(net, 0);
        assertEq(observer.attempts(), 1, "real local refund invokes callback");
        assertFalse(observer.reentered());
        assertEq(observer.reentryError(), abi.encodeWithSignature("Reentrancy()"));
        assertEq(observer.observedSupply(), IERC20(hook).totalSupply());
        assertEq(observer.observedUserLp(), IERC20(hook).balanceOf(user));
    }

    function test_refundCallback_observesCompletedComponentOwnership() public {
        OrbitalRefundObserver observer = new OrbitalRefundObserver();
        token1 = SimpleMintableERC20(address(observer));
        _deployHookWithArgs(_defaultPkgArgs());
        token1.mint(user, 1000 ether);
        vm.startPrank(user);
        token0.approve(hook, type(uint256).max);
        token1.approve(hook, type(uint256).max);
        token2.approve(hook, type(uint256).max);
        vm.stopPrank();
        _seedFor(orbital, user, 100 ether, 100 ether, 100 ether);
        observer.arm(hook, user);
        vm.prank(user);
        (uint256 net,, uint256 used1,) =
            orbital.addLiquidity(1 ether, 100 ether, 1 ether, user, 1, block.timestamp, "");
        assertGt(net, 0);
        assertLt(used1, 100 ether, "actual excess raw-token refund");
        assertEq(observer.attempts(), 1, "refund callback reached");
        assertEq(observer.observedSupply(), IERC20(hook).totalSupply(), "refund sees final LP ownership");
        assertEq(observer.observedUserLp(), IERC20(hook).balanceOf(user), "refund sees final depositor LP");
        for (uint8 i; i < 3; ++i) {
            if (observer.querySucceeded(i)) {
                assertEq(abi.decode(observer.observedBook(i), (uint256)), orbital.rawReserve(i),
                    "refund sees every committed local component");
            } else {
                assertEq(observer.observedBook(i), abi.encodeWithSignature("Reentrancy()"),
                    "partial book query rejects explicitly");
            }
        }
    }
}

/// @dev Non-SUT token observes the real production hook during its refund transfer.
contract OrbitalRefundObserver is SimpleMintableERC20 {
    address private hook;
    address private recipient;
    bool private armed;
    uint256 public attempts;
    uint256 public observedSupply;
    uint256 public observedUserLp;
    bool[3] public querySucceeded;
    bytes[3] public observedBook;
    bool private nativeReentry;
    bool public reentered;
    bytes public reentryError;

    constructor() SimpleMintableERC20("Refund observer", "OBS") {}

    function arm(address hook_, address recipient_) external {
        hook = hook_;
        recipient = recipient_;
        armed = true;
    }

    function armNative(address hook_, address recipient_) external {
        hook = hook_;
        recipient = recipient_;
        armed = true;
        nativeReentry = true;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        if (armed && msg.sender == hook && to == recipient) {
            armed = false;
            ++attempts;
            observedSupply = IERC20(hook).totalSupply();
            observedUserLp = IERC20(hook).balanceOf(recipient);
            if (nativeReentry) {
                uint256[] memory amounts = new uint256[](3);
                (reentered, reentryError) = hook.call(abi.encodeCall(
                    IUniswapV4SeBufferHookNativeLiquidity.joinNativeComponents,
                    (amounts, amounts, recipient, 0, block.timestamp)
                ));
            }
            for (uint8 i; i < 3; ++i) {
                (querySucceeded[i], observedBook[i]) = hook.staticcall(abi.encodeCall(IHook.rawReserve, (i)));
            }
        }
        return true;
    }
}
