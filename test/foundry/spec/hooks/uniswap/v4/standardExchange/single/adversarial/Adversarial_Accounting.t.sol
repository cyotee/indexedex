// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {
    TestBase_UniswapV4SingleSEBufferHook_Adversarial as AdvBase
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/adversarial/TestBase_UniswapV4SingleSEBufferHook_Adversarial.sol";

contract Adversarial_Accounting_Test is AdvBase {
    /// @notice E1: successful four modes leave hook free residual 0
    function test_E1_fourModes_hookFlat() public {
        _wrapExactIn(8 ether);
        _assertHookFlat();
        _unwrapExactIn(3 ether);
        _assertHookFlat();
        _wrapExactOut(2 ether);
        _assertHookFlat();
        _unwrapExactOut(1 ether);
        _assertHookFlat();
    }

    /// @notice E2: zero amount preview reverts ZeroAmount
    function test_E2_zeroAmount_reverts() public {
        vm.expectRevert(abi.encodeWithSignature("ZeroAmount()"));
        buffer.previewWrap(0);
        vm.expectRevert(abi.encodeWithSignature("ZeroAmount()"));
        buffer.previewUnwrap(0);
    }

    /// @notice E3: failed minOut / insufficient exact-out → full revert, no stranded inventory
    function test_E3_exactOutInsufficientInput_noStranded() public {
        uint256 seOut = 5 ether;
        uint256 amountIn = buffer.previewWrapExactOut(seOut);
        bool zfo = _isWrapZFO();
        // Pass maxIn too low
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
            amountIn / 2,
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
}
