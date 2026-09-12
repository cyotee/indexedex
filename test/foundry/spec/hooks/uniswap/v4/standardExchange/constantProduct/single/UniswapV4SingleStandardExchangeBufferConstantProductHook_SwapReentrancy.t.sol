// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

/// @title UniswapV4SingleStandardExchangeBufferConstantProductHook_SwapReentrancy_Test
/// @notice Production PoolManager callbacks share the direct hook exchange lock.
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_SwapReentrancy_Test is TestBase {
    CpSwapCallbackToken internal callbackToken;
    WrapperExactOutRouter internal swapRouter;

    struct SwapCheck {
        uint256 amountIn;
        uint256 amountOut;
        uint256 rawBefore;
        uint256 pairBefore;
        uint256 lpSupplyBefore;
    }

    /// @notice Reuse the registered CP package and real SE with a callback-capable raw token.
    function setUp() public override {
        super.setUp();
        callbackToken = new CpSwapCallbackToken();
        rawToken = callbackToken;
        hook = _deployBootstrapOnly(_defaultPkgArgs());
        _ensureProductDoorsAndFinalize(hook);
        single = IHook(hook);
        swapRouter = new WrapperExactOutRouter(pm);

        rawToken.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        rawToken.approve(hook, type(uint256).max);
        pairToken.approve(hook, type(uint256).max);
        rawToken.approve(address(swapRouter), type(uint256).max);
        pairToken.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
        _seedLiveLiquidity();
        callbackToken.mint(address(callbackToken), 10 ether);
    }

    /// @notice Exact-input raw intake through PoolManager.take rejects nested exchange.
    function test_swapExactIn_rawInput_transferCallbackUsesSharedLock() public {
        _checkSwap(true, false);
    }

    /// @notice Exact-output raw intake through PoolManager.take rejects nested exchange.
    function test_swapExactOut_rawInput_transferCallbackUsesSharedLock() public {
        _checkSwap(true, true);
    }

    /// @notice Exact-input raw settlement transfer rejects nested exchange.
    function test_swapExactIn_rawOutput_transferCallbackUsesSharedLock() public {
        _checkSwap(false, false);
    }

    /// @notice Exact-output raw settlement transfer rejects nested exchange.
    function test_swapExactOut_rawOutput_transferCallbackUsesSharedLock() public {
        _checkSwap(false, true);
    }

    /// @dev Assert the callback is reached, the exact guard rejects it, and outer settlement completes.
    function _checkSwap(bool rawInput, bool exactOutput) internal {
        bool zeroForOne = rawInput == _isRawCurrency0();
        SwapCheck memory c;
        if (exactOutput) {
            c.amountOut = 1 ether;
            c.amountIn = single.previewSwapExactOut(zeroForOne, c.amountOut);
        } else {
            c.amountIn = 5 ether;
            c.amountOut = single.previewSwapExactIn(zeroForOne, c.amountIn);
        }
        assertGt(c.amountIn, 0, "nonzero quoted input");
        assertGt(c.amountOut, 0, "nonzero quoted output");
        c.rawBefore = rawToken.balanceOf(user);
        c.pairBefore = pairToken.balanceOf(user);
        c.lpSupplyBefore = IERC20(hook).totalSupply();
        callbackToken.arm(hook, address(pairToken), rawInput ? address(pm) : hook, rawInput ? hook : address(pm));

        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: exactOutput ? int256(c.amountOut) : -int256(c.amountIn),
            sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        });
        vm.prank(user);
        if (exactOutput) {
            swapRouter.swapExactOut(poolKey, params, c.amountIn, "");
        } else {
            swapRouter.swapExactIn(poolKey, params, "");
        }

        assertEq(callbackToken.callbackAttempts(), 1, "actual transfer callback reached");
        assertFalse(callbackToken.nestedSucceeded(), "nested exchange blocked");
        assertEq(callbackToken.nestedRevert(), abi.encodeWithSignature("Reentrancy()"), "shared hook guard");
        assertEq(rawToken.balanceOf(address(callbackToken)), 10 ether, "nested input remains unspent");
        assertEq(pairToken.balanceOf(address(callbackToken)), 0, "no nested output");
        assertEq(IERC20(hook).totalSupply(), c.lpSupplyBefore, "swap does not change LP supply");
        if (rawInput) {
            assertEq(c.rawBefore - rawToken.balanceOf(user), c.amountIn, "exact raw spent");
            assertEq(pairToken.balanceOf(user) - c.pairBefore, c.amountOut, "exact pair received");
        } else {
            assertEq(c.pairBefore - pairToken.balanceOf(user), c.amountIn, "exact pair spent");
            assertEq(rawToken.balanceOf(user) - c.rawBefore, c.amountOut, "exact raw received");
        }
        assertEq(rawToken.balanceOf(address(pm)), 0, "PoolManager raw settled");
        assertEq(pairToken.balanceOf(address(pm)), 0, "PoolManager pair settled");

        // A subsequent direct call verifies the completed V4 callback released the lock.
        uint256 preview =
            IStandardExchangeIn(hook).previewExchangeIn(IERC20(address(rawToken)), 1 ether, IERC20(address(pairToken)));
        vm.prank(user);
        uint256 received = IStandardExchangeIn(hook)
            .exchangeIn(
                IERC20(address(rawToken)), 1 ether, IERC20(address(pairToken)), preview, user, false, block.timestamp
            );
        assertEq(received, preview, "shared lock released after swap");
    }
}

/// @title CpSwapCallbackToken
/// @notice Non-SUT ERC20 retaining normal balances while attempting one transfer callback.
contract CpSwapCallbackToken is SimpleMintableERC20 {
    address internal targetHook;
    address internal outputToken;
    address internal callbackFrom;
    address internal callbackTo;
    bool internal armed;
    uint256 public callbackAttempts;
    bool public nestedSucceeded;
    bytes public nestedRevert;

    /// @notice Initialize the balance-preserving raw-token callback fixture.
    constructor() SimpleMintableERC20("Callback raw", "cRAW") {}

    /// @notice Select the actual PoolManager intake or hook settlement transfer.
    function arm(address hook_, address output_, address from_, address to_) external {
        targetHook = hook_;
        outputToken = output_;
        callbackFrom = from_;
        callbackTo = to_;
        allowance[address(this)][hook_] = type(uint256).max;
        armed = true;
        callbackAttempts = 0;
        nestedSucceeded = false;
        delete nestedRevert;
    }

    /// @notice Transfer normally, then exercise a funded direct exchange during the selected callback.
    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        if (armed && msg.sender == callbackFrom && to == callbackTo) {
            armed = false;
            ++callbackAttempts;
            (nestedSucceeded, nestedRevert) = targetHook.call(
                abi.encodeCall(
                    IStandardExchangeIn.exchangeIn,
                    (IERC20(address(this)), 1 ether, IERC20(outputToken), 0, address(this), false, block.timestamp)
                )
            );
        }
        return true;
    }
}
