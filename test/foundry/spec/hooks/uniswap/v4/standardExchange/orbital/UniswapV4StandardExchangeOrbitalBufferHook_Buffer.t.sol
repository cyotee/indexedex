// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";

contract UniswapV4StandardExchangeOrbitalBufferHook_BufferTest is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    function test_bufferedLeg_freeTokenNotBook() public {
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args =
            _argsWithSE(true, false, false);
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        IUniswapV4StandardExchangeOrbitalBufferHook o = IUniswapV4StandardExchangeOrbitalBufferHook(h);
        token0.mint(user, 500 ether);
        token1.mint(user, 500 ether);
        token2.mint(user, 500 ether);
        vm.startPrank(user);
        token0.approve(h, type(uint256).max);
        token1.approve(h, type(uint256).max);
        token2.approve(h, type(uint256).max);
        o.addLiquidity(100 ether, 100 ether, 100 ether, user, 0, block.timestamp + 1 hours, "");
        vm.stopPrank();
        assertEq(o.rawReserve(0), 0, "buffered raw book 0");
        assertGt(o.seBalance(0), 0, "SE shares");
        assertGt(o.effectiveReserve(0), 0, "effective > 0");
        assertEq(o.rawReserve(1), 100 ether, "raw leg face");
    }
}
