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
        vm.expectRevert();
        buffer.previewWrap(0);
        vm.expectRevert();
        buffer.previewUnwrap(0);
    }

    /// @notice E3: failed minOut / insufficient exact-out → full revert, no stranded inventory
    function test_E3_exactOutInsufficientInput_noStranded() public {
        uint256 seOut = 5 ether;
        uint256 amountIn = buffer.previewWrapExactOut(seOut);
        bool zfo = _isWrapZFO();
        // Pass maxIn too low
        vm.prank(user);
        vm.expectRevert();
        swapRouter.swapExactOut(
            poolKey,
            SwapParams({zeroForOne: zfo, amountSpecified: int256(seOut), sqrtPriceLimitX96: _sqrtLimit(zfo)}),
            amountIn / 2,
            ""
        );
        _assertHookFlat();
    }
}
