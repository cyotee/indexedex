// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/single/TestBase_UniswapV4SingleStandardExchangeBufferHook.sol";

contract UniswapV4SingleSEBufferHook_Init_Test is TestBase {
    function test_init_correctPoolSucceeds() public {
        _initPool();
        // re-init same pool should revert (already initialized)
        vm.expectRevert();
        pm.initialize(poolKey, SQRT_PRICE_1_1);
    }

    function test_init_wrongFee_reverts() public {
        PoolKey memory bad = PoolKey({
            currency0: Currency.wrap(buffer.currency0()),
            currency1: Currency.wrap(buffer.currency1()),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
        vm.expectRevert();
        pm.initialize(bad, SQRT_PRICE_1_1);
    }

    function test_init_wrongPair_reverts() public {
        address fake = address(0xDEAD);
        address c0 = address(pairToken) < fake ? address(pairToken) : fake;
        address c1 = address(pairToken) < fake ? fake : address(pairToken);
        PoolKey memory bad = PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: 0,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
        vm.expectRevert();
        pm.initialize(bad, SQRT_PRICE_1_1);
    }
}
