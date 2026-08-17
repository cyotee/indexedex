// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {ICreate3Factory} from "@crane/contracts/factories/create3/ICreate3Factory.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {UniswapV4LiquiditySeeder} from "scripts/foundry/shared/UniswapV4LiquiditySeeder.sol";
import {ROBINHOOD_TESTNET} from "@crane/contracts/constants/networks/ROBINHOOD_TESTNET.sol";

interface IWeth9 {
    function deposit() external payable;
    function balanceOf(address) external view returns (uint256);
}

/// @title PoolSeedLib
/// @notice Uni V4 pool init + seed via CREATE3 seeder (never `new` Uni V4 SUT).
library PoolSeedLib {
    function buildKey(address a, address b) internal pure returns (PoolKey memory key) {
        (address token0, address token1) = a < b ? (a, b) : (b, a);
        key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: FixtureEconomics.POOL_FEE,
            tickSpacing: FixtureEconomics.POOL_TICK_SPACING,
            hooks: IHooks(address(0))
        });
    }

    function ensureSeeder(ICreate3FactoryProxy factory, IPoolManager pm) internal returns (address seeder) {
        seeder = ICreate3Factory(address(factory)).create3WithArgs(
            type(UniswapV4LiquiditySeeder).creationCode,
            abi.encode(pm),
            keccak256(abi.encode(FixtureEconomics.SALT_NS, "V4LiquiditySeeder"))
        );
    }

    function wrapWeth(address holder, uint256 target) internal {
        IWeth9 weth = IWeth9(address(ROBINHOOD_TESTNET.WETH));
        uint256 have = weth.balanceOf(holder);
        if (have >= target) return;
        uint256 need = target - have;
        uint256 avail = holder.balance;
        uint256 reserve = 100 ether;
        if (avail <= reserve) return;
        if (need > avail - reserve) need = avail - reserve;
        if (need > 0) {
            weth.deposit{value: need}();
        }
    }

    function initAndSeed(IPoolManager pm, address seeder, PoolKey memory key, uint256 amount0, uint256 amount1)
        internal
    {
        try pm.initialize(key, FixtureEconomics.poolSqrtPrice()) {} catch {}
        address t0 = Currency.unwrap(key.currency0);
        address t1 = Currency.unwrap(key.currency1);
        IERC20(t0).transfer(seeder, amount0);
        IERC20(t1).transfer(seeder, amount1);
        int24 span = FixtureEconomics.POOL_TICK_SPACING * 2000;
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
            FixtureEconomics.poolSqrtPrice(),
            TickMath.getSqrtPriceAtTick(-span),
            TickMath.getSqrtPriceAtTick(span),
            amount0,
            amount1
        );
        UniswapV4LiquiditySeeder(seeder).addLiquidity(key, -span, span, liq);
    }

    function initEmpty(IPoolManager pm, PoolKey memory key) internal {
        try pm.initialize(key, FixtureEconomics.poolSqrtPrice()) {} catch {}
    }
}
