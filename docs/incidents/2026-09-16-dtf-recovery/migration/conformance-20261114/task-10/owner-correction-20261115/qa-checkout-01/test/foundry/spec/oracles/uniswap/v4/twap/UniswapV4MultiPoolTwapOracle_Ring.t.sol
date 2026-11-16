// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {
    TestBase_UniswapV4MultiPoolTwapOracle
} from "contracts/test/bases/TestBase_UniswapV4MultiPoolTwapOracle.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";

/**
 * @title UniswapV4MultiPoolTwapOracle_Ring
 * @notice H1–H9, H18, H31 plus keeper batch (missing key returns false, batch does not revert).
 */
contract UniswapV4MultiPoolTwapOracle_Ring is TestBase_UniswapV4MultiPoolTwapOracle {
    function test_H1_firstRealUpdate() public {
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(0));
        bool written = _poke(poolKey);
        assertTrue(written);
        (
            uint16 index,
            uint16 cardinality,
            uint16 cardinalityNext,
            int24 prevTick,
            uint32 lastTimestamp
        ) = twapOracle.getState(poolKey.toId());
        IUniswapV4MultiPoolTwapOracle.Observation memory obs = twapOracle.getObservation(poolKey.toId(), 0);
        assertEq(index, 0);
        assertEq(cardinality, 1);
        assertEq(cardinalityNext, 1);
        assertEq(prevTick, 0);
        assertEq(lastTimestamp, uint32(block.timestamp));
        assertEq(obs.tickCumulative, 0);
        assertTrue(obs.initialized);
        PoolKey memory stored = twapOracle.getPoolKey(poolKey.toId());
        assertEq(Currency.unwrap(stored.currency0), Currency.unwrap(poolKey.currency0));
        assertEq(Currency.unwrap(stored.currency1), Currency.unwrap(poolKey.currency1));
    }

    function test_H2_consultMatchesTruncatedAccumulator() public {
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(0));
        tokenA.mint(address(poolHarness), 1_000_000_000 ether);
        tokenB.mint(address(poolHarness), 1_000_000_000 ether);
        _seedFullRange(poolKey, 100_000_000 ether, 100_000_000 ether);
        twapOracle.increaseCardinalityNext(poolKey.toId(), 2);
        assertTrue(_poke(poolKey));
        _swapToTick(poolKey, 20_000);
        _warp(100);
        assertTrue(_poke(poolKey));
        (,,, int24 recorded,) = twapOracle.getState(poolKey.toId());
        assertEq(recorded, 9116);
        int24 mean = twapOracle.consult(poolKey.toId(), 100);
        assertEq(mean, 9116);
    }

    function test_H3_sameBlockSecondPokeUnchanged() public {
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(0));
        assertTrue(_poke(poolKey));
        IUniswapV4MultiPoolTwapOracle.Observation memory beforeObs = twapOracle.getObservation(poolKey.toId(), 0);
        (uint16 indexBefore, uint16 cardBefore,, int24 prevBefore, uint32 tsBefore) =
            twapOracle.getState(poolKey.toId());
        bool written = _poke(poolKey);
        assertFalse(written);
        IUniswapV4MultiPoolTwapOracle.Observation memory afterObs = twapOracle.getObservation(poolKey.toId(), 0);
        (uint16 indexAfter, uint16 cardAfter,, int24 prevAfter, uint32 tsAfter) = twapOracle.getState(poolKey.toId());
        assertEq(indexAfter, indexBefore);
        assertEq(cardAfter, cardBefore);
        assertEq(prevAfter, prevBefore);
        assertEq(tsAfter, tsBefore);
        assertEq(afterObs.tickCumulative, beforeObs.tickCumulative);
        assertEq(afterObs.blockTimestamp, beforeObs.blockTimestamp);
    }

    function test_H4_truncationClampsTo9116() public {
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(0));
        tokenA.mint(address(poolHarness), 1_000_000_000 ether);
        tokenB.mint(address(poolHarness), 1_000_000_000 ether);
        _seedFullRange(poolKey, 100_000_000 ether, 100_000_000 ether);
        assertTrue(_poke(poolKey));
        int24 beforeTick = _currentTick(poolKey);
        assertEq(beforeTick, 0);
        _swapToTick(poolKey, 20_000);
        int24 afterSwap = _currentTick(poolKey);
        assertTrue(afterSwap > 9116, "swap must dump more than 9116 ticks");
        _warp(1);
        assertTrue(_poke(poolKey));
        (uint16 index,,, int24 recorded,) = twapOracle.getState(poolKey.toId());
        assertEq(recorded, 9116);
        IUniswapV4MultiPoolTwapOracle.Observation memory obs = twapOracle.getObservation(poolKey.toId(), index);
        assertEq(obs.prevTick, 9116);
    }

    function test_H5_consultOlderThanOldestReverts() public {
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(0));
        assertTrue(_poke(poolKey));
        uint32 writtenAt = uint32(block.timestamp);
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniswapV4MultiPoolTwapOracle.TargetPredatesOldestObservation.selector, writtenAt, writtenAt - 1
            )
        );
        twapOracle.consult(poolKey.toId(), 1);
    }

    function test_H6_cardinalityGrowsOnLaterWrites() public {
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(0));
        twapOracle.increaseCardinalityNext(poolKey.toId(), 4);
        assertTrue(_poke(poolKey));
        (uint16 index0, uint16 card0, uint16 next0,,) = twapOracle.getState(poolKey.toId());
        assertEq(index0, 0);
        assertEq(card0, 1);
        assertEq(next0, 4);
        _warp(1);
        assertTrue(_poke(poolKey));
        (, uint16 card1, uint16 next1,,) = twapOracle.getState(poolKey.toId());
        assertEq(card1, 4);
        assertEq(next1, 4);
    }

    function test_H7_nativeCurrency0PokeAndConsult() public {
        PoolKey memory nativeKey = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(tokenA)),
            fee: DEFAULT_FEE,
            tickSpacing: DEFAULT_TICK_SPACING,
            hooks: IHooks(address(0))
        });
        _initPool(poolManager, nativeKey, TickMath.getSqrtPriceAtTick(0));
        twapOracle.increaseCardinalityNext(nativeKey.toId(), 2);
        assertTrue(_poke(nativeKey));
        _warp(50);
        assertTrue(_poke(nativeKey));
        int24 mean = twapOracle.consult(nativeKey.toId(), 50);
        assertEq(mean, 0);
    }

    function test_H8_neverWrittenAndPregrowReturnZero() public {
        uint32[] memory agos = new uint32[](2);
        agos[0] = 10;
        agos[1] = 0;
        int56[] memory cumulatives = twapOracle.observe(poolKey.toId(), agos);
        assertEq(cumulatives[0], 0);
        assertEq(cumulatives[1], 0);
        assertEq(twapOracle.consult(poolKey.toId(), 10), 0);

        twapOracle.increaseCardinalityNext(poolKey.toId(), 8);
        cumulatives = twapOracle.observe(poolKey.toId(), agos);
        assertEq(cumulatives[0], 0);
        assertEq(twapOracle.consult(poolKey.toId(), 10), 0);
        (, uint16 card, uint16 next,,) = twapOracle.getState(poolKey.toId());
        assertEq(card, 0);
        assertEq(next, 8);
    }

    function test_H8_consultZeroReverts() public {
        vm.expectRevert(IUniswapV4MultiPoolTwapOracle.InvalidSecondsAgo.selector);
        twapOracle.consult(poolKey.toId(), 0);
    }

    function test_H9_uninitializedPoolNoWrite() public {
        bool written = _poke(poolKey);
        assertFalse(written);
        (, uint16 cardinality,,,) = twapOracle.getState(poolKey.toId());
        assertEq(cardinality, 0);
        IUniswapV4MultiPoolTwapOracle.Observation memory obs = twapOracle.getObservation(poolKey.toId(), 0);
        assertFalse(obs.initialized);
    }

    function test_H18_updateDuringOuterUnlock() public {
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(0));
        bool written = unlockPokeHarness.pokeWhileUnlocked(twapOracle, poolKey);
        assertTrue(unlockPokeHarness.wasUnlocked());
        assertTrue(written);
        (, uint16 cardinality,,,) = twapOracle.getState(poolKey.toId());
        assertEq(cardinality, 1);
    }

    function test_H31_pregrowKeepsCardinalityNextOnFirstWrite() public {
        twapOracle.increaseCardinalityNext(poolKey.toId(), 16);
        assertEq(twapOracle.consult(poolKey.toId(), 10), 0);
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(0));
        assertTrue(_poke(poolKey));
        (, uint16 cardinality, uint16 next,,) = twapOracle.getState(poolKey.toId());
        assertEq(cardinality, 1);
        assertEq(next, 16);
    }

    function test_keeperBatchMissingKeyReturnsFalse() public {
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(0));
        PoolKey memory missing = _buildPoolKey(address(tokenA), address(uint160(address(tokenB)) + 1));
        if (Currency.unwrap(missing.currency0) == Currency.unwrap(missing.currency1)) {
            missing = PoolKey({
                currency0: poolKey.currency0,
                currency1: poolKey.currency1,
                fee: 10_000,
                tickSpacing: DEFAULT_TICK_SPACING,
                hooks: IHooks(address(0))
            });
        }
        PoolKey[] memory keys = new PoolKey[](2);
        keys[0] = poolKey;
        keys[1] = missing;
        bool[] memory written = twapOracle.update(keys);
        assertTrue(written[0]);
        assertFalse(written[1]);
        (, uint16 cardMissing,,,) = twapOracle.getState(missing.toId());
        assertEq(cardMissing, 0);
    }
}
