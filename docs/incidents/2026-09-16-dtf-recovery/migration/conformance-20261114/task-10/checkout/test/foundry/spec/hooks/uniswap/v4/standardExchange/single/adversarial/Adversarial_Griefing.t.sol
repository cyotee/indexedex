// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {
    TestBase_UniswapV4SingleSEBufferHook_Adversarial as AdvBase
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/adversarial/TestBase_UniswapV4SingleSEBufferHook_Adversarial.sol";

contract Adversarial_Griefing_Test is AdvBase {
    /// @notice H1: SE reverts mid-swap → full tx revert
    function test_H1_zeroSwap_revertsAtRouter() public {
        // The router rejects a zero input before interacting with the hook.
        bool zfo = _isWrapZFO();
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "exact-in only"));
        swapRouter.swapExactIn(
            poolKey,
            SwapParams({zeroForOne: zfo, amountSpecified: 0, sqrtPriceLimitX96: _sqrtLimit(zfo)}),
            ""
        );
        _assertHookFlat();
    }

    /// @notice H2: exact-out insufficient user input
    function test_H2_exactOutInsufficient_reverts() public {
        uint256 seOut = 4 ether;
        uint256 amountIn = buffer.previewWrapExactOut(seOut);
        bool zfo = _isWrapZFO();
        uint256 beforePair = pairToken.balanceOf(user);
        uint256 beforeShares = IERC20(se).balanceOf(user);
        uint256 beforeSupply = IERC20(se).totalSupply();
        uint256 beforeBacking = pairToken.balanceOf(address(protocolVault));
        // The router prepays only maxIn. PoolManager's attempted transfer of the full
        // required input fails, wrapped by the currency library and then the hook call.
        bytes memory currencyFailure = abi.encodeWithSignature("WrappedError(address,bytes4,bytes,bytes)",
            address(pairToken), IERC20.transfer.selector, abi.encodeWithSignature("Error(string)", "balance"),
            abi.encodeWithSignature("ERC20TransferFailed()"));
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("WrappedError(address,bytes4,bytes,bytes)", hook,
            bytes4(keccak256("beforeSwap(address,(address,address,uint24,int24,address),(bool,int256,uint160),bytes)")),
            currencyFailure, abi.encodeWithSignature("HookCallFailed()")));
        swapRouter.swapExactOut(
            poolKey,
            SwapParams({zeroForOne: zfo, amountSpecified: int256(seOut), sqrtPriceLimitX96: _sqrtLimit(zfo)}),
            amountIn > 1 ? amountIn - 1 : 0,
            ""
        );
        _assertHookFlat();
        assertEq(pairToken.balanceOf(user), beforePair, "insufficient prepayment rolls back payer");
        assertEq(IERC20(se).balanceOf(user), beforeShares, "no output from rejected wrap");
        assertEq(IERC20(se).totalSupply(), beforeSupply, "rejected wrap cannot issue shares");
        assertEq(pairToken.balanceOf(address(protocolVault)), beforeBacking, "rejected wrap preserves backing");
        assertEq(_wrapExactOut(seOut), amountIn, "same-state fully funded wrap succeeds");
        _assertHookFlat();
    }

    /// @notice H3: add liquidity always LiquidityNotAllowed
    function test_H3_addLiquidity_alwaysReverts() public {
        vm.expectRevert(abi.encodeWithSignature("WrappedError(address,bytes4,bytes,bytes)", hook, bytes4(keccak256("beforeAddLiquidity(address,(address,address,uint24,int24,address),(int24,int24,int256,bytes32),bytes)")), abi.encodeWithSignature("LiquidityNotAllowed()"), abi.encodeWithSignature("HookCallFailed()")));
        liqRouter.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({
                tickLower: -60, tickUpper: 60, liquidityDelta: 1e18, salt: bytes32(0)
            }),
            ""
        );
    }

    /// @notice H4: init wrong fee/pair reverts
    function test_H4_initWrongFee_reverts() public {
        PoolKey memory bad = poolKey;
        bad.fee = 500;
        vm.expectRevert(abi.encodeWithSignature("WrappedError(address,bytes4,bytes,bytes)", hook, bytes4(keccak256("beforeInitialize(address,(address,address,uint24,int24,address),uint160)")), abi.encodeWithSignature("InvalidPoolFee()"), abi.encodeWithSignature("HookCallFailed()")));
        pm.initialize(bad, SQRT_PRICE_1_1);
    }
}
