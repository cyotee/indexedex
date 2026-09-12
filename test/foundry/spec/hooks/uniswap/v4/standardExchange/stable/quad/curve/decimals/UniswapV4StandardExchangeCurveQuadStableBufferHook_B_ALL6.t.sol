// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchangeCurveQuadStableBufferHook_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/decimals/UniswapV4StandardExchangeCurveQuadStableBufferHook_Decimals.sol";
/// @notice Book `B_ALL6`. pairToken (construction first) 6-dec; next 6; remaining 6/6. After address sort token0..token3 permute. Hook LP stays 18.
contract UniswapV4StandardExchangeCurveQuadStableBufferHook_B_ALL6 is UniswapV4StandardExchangeCurveQuadStableBufferHook_Decimals {
    function _dec0() internal pure override returns (uint8) { return 6; }
    function _dec1() internal pure override returns (uint8) { return 6; }
    function _dec2() internal pure override returns (uint8) { return 6; }
    function _dec3() internal pure override returns (uint8) { return 6; }
}
