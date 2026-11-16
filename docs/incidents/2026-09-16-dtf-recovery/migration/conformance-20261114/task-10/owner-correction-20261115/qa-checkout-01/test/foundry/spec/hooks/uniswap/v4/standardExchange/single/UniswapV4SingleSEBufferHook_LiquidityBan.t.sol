// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ModifyLiquidityParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/single/TestBase_UniswapV4SingleStandardExchangeBufferHook.sol";

contract UniswapV4SingleSEBufferHook_LiquidityBan_Test is TestBase {
    function setUp() public override {
        super.setUp();
        _initPool();
    }

    function test_addLiquidity_revertsLiquidityNotAllowed() public {
        vm.expectRevert(abi.encodeWithSignature("WrappedError(address,bytes4,bytes,bytes)", hook, bytes4(keccak256("beforeAddLiquidity(address,(address,address,uint24,int24,address),(int24,int24,int256,bytes32),bytes)")), abi.encodeWithSignature("LiquidityNotAllowed()"), abi.encodeWithSignature("HookCallFailed()")));
        liqRouter.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 1e18,
                salt: bytes32(0)
            }),
            ""
        );
    }
}
