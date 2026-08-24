// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IOracle} from "@crane/contracts/external/morpho/blue/interfaces/IOracle.sol";
import {
    TestBase_UniswapV4MultiPoolTwapOracle
} from "contracts/test/bases/TestBase_UniswapV4MultiPoolTwapOracle.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    IUniswapV4TwapAdapterErrors
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4TwapAdapterErrors.sol";
import {
    UniswapV4TwapMorphoOracle
} from "contracts/oracles/uniswap/v4/twap/UniswapV4TwapMorphoOracle.sol";
import {
    UniswapV4TwapAggregatorV3Adapter
} from "contracts/oracles/uniswap/v4/twap/UniswapV4TwapAggregatorV3Adapter.sol";

contract NoDecimalsToken {}

/**
 * @title UniswapV4MultiPoolTwapOracle_Adapters
 * @notice H10–H13, H19, H32 on factory-created Morpho and AggregatorV3 adapters.
 */
contract UniswapV4MultiPoolTwapOracle_Adapters is TestBase_UniswapV4MultiPoolTwapOracle {
    uint32 internal constant SECONDS_AGO = 30;
    uint32 internal constant MAX_WRITE_AGE = 300;

    function _createMorpho(bool collateralIsCurrency0) internal returns (UniswapV4TwapMorphoOracle) {
        return UniswapV4TwapMorphoOracle(
            twapAdapterFactory.createMorphoOracle(
                twapOracle, poolKey, SECONDS_AGO, collateralIsCurrency0, MAX_WRITE_AGE
            )
        );
    }

    function _createAgg(bool invert) internal returns (UniswapV4TwapAggregatorV3Adapter) {
        return UniswapV4TwapAggregatorV3Adapter(
            twapAdapterFactory.createAggregatorV3(twapOracle, poolKey, SECONDS_AGO, invert, MAX_WRITE_AGE)
        );
    }

    function test_H10_morphoPriceTick0_18_18() public {
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(0));
        assertTrue(_poke(poolKey));
        _warp(SECONDS_AGO);
        UniswapV4TwapMorphoOracle morpho = _createMorpho(true);
        assertEq(IOracle(address(morpho)).price(), 1e36);
        UniswapV4TwapMorphoOracle inverted = _createMorpho(false);
        assertEq(IOracle(address(inverted)).price(), 1e36);
    }

    function test_H11_invertDiffersAtNonZeroTick() public {
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(1_000));
        assertTrue(_poke(poolKey));
        _warp(SECONDS_AGO);
        UniswapV4TwapMorphoOracle fwd = _createMorpho(true);
        UniswapV4TwapMorphoOracle inv = _createMorpho(false);
        uint256 pFwd = IOracle(address(fwd)).price();
        uint256 pInv = IOracle(address(inv)).price();
        assertTrue(pFwd != pInv, "invert must differ at non-zero tick");
        assertTrue(pFwd > 0 && pInv > 0);
    }

    function test_H12_staleThenPokeRestores() public {
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(0));
        assertTrue(_poke(poolKey));
        UniswapV4TwapMorphoOracle morpho = _createMorpho(true);
        _warp(MAX_WRITE_AGE + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniswapV4TwapAdapterErrors.StaleObservation.selector, MAX_WRITE_AGE + 1, MAX_WRITE_AGE
            )
        );
        morpho.price();
        assertTrue(_poke(poolKey));
        _warp(SECONDS_AGO);
        assertEq(morpho.price(), 1e36);
    }

    function test_H13_H32_factoryIdempotentAndDistinct() public {
        address first = twapAdapterFactory.createMorphoOracle(twapOracle, poolKey, SECONDS_AGO, true, MAX_WRITE_AGE);
        address second = twapAdapterFactory.createMorphoOracle(twapOracle, poolKey, SECONDS_AGO, true, MAX_WRITE_AGE);
        assertEq(first, second);
        address otherWindow =
            twapAdapterFactory.createMorphoOracle(twapOracle, poolKey, SECONDS_AGO + 1, true, MAX_WRITE_AGE);
        assertTrue(otherWindow != first);
        PoolManager pmB = new PoolManager(address(this));
        IUniswapV4MultiPoolTwapOracle oracleB = _deployOracle(pmB);
        address otherInstance =
            twapAdapterFactory.createMorphoOracle(oracleB, poolKey, SECONDS_AGO, true, MAX_WRITE_AGE);
        assertTrue(otherInstance != first);

        address agg1 = twapAdapterFactory.createAggregatorV3(twapOracle, poolKey, SECONDS_AGO, false, MAX_WRITE_AGE);
        address agg2 = twapAdapterFactory.createAggregatorV3(twapOracle, poolKey, SECONDS_AGO, false, MAX_WRITE_AGE);
        assertEq(agg1, agg2);
        address aggOther =
            twapAdapterFactory.createAggregatorV3(twapOracle, poolKey, SECONDS_AGO + 1, false, MAX_WRITE_AGE);
        assertTrue(aggOther != agg1);
    }

    function test_H19_non18SnapshotNativeAndMissingDecimals() public {
        ERC20PermitMintableStub usdc = new ERC20PermitMintableStub("USD", "USDC", 6, address(this), 0);
        PoolKey memory mixed = _buildPoolKey(address(usdc), address(tokenA));
        _initPool(poolManager, mixed, TickMath.getSqrtPriceAtTick(0));
        assertTrue(_poke(mixed));
        _warp(SECONDS_AGO);
        UniswapV4TwapMorphoOracle morpho = UniswapV4TwapMorphoOracle(
            twapAdapterFactory.createMorphoOracle(twapOracle, mixed, SECONDS_AGO, true, MAX_WRITE_AGE)
        );
        uint8 collDec = morpho.collDecimals();
        uint8 loanDec = morpho.loanDecimals();
        assertTrue(collDec == 6 || loanDec == 6);
        assertTrue(collDec == 18 || loanDec == 18);
        // Tick 0 is 1 wei = 1 wei. Morpho scale is 1e36 for any decimal pair.
        assertEq(morpho.price(), 1e36);

        PoolKey memory nativeKey = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(tokenA)),
            fee: DEFAULT_FEE,
            tickSpacing: DEFAULT_TICK_SPACING,
            hooks: IHooks(address(0))
        });
        UniswapV4TwapMorphoOracle nativeMorpho = UniswapV4TwapMorphoOracle(
            twapAdapterFactory.createMorphoOracle(twapOracle, nativeKey, SECONDS_AGO, true, MAX_WRITE_AGE)
        );
        assertEq(nativeMorpho.collDecimals(), 18);

        NoDecimalsToken bad = new NoDecimalsToken();
        PoolKey memory badKey = _buildPoolKey(address(bad), address(tokenA));
        vm.expectRevert(IUniswapV4TwapAdapterErrors.DecimalsQueryFailed.selector);
        twapAdapterFactory.createMorphoOracle(twapOracle, badKey, SECONDS_AGO, true, MAX_WRITE_AGE);
    }

    function test_aggregatorNeverWrittenAndAfterWrite() public {
        UniswapV4TwapAggregatorV3Adapter agg = _createAgg(false);
        assertEq(agg.decimals(), 18);
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            agg.latestRoundData();
        assertEq(roundId, 0);
        assertEq(answer, 0);
        assertEq(startedAt, 0);
        assertEq(updatedAt, 0);
        assertEq(answeredInRound, 0);

        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(0));
        assertTrue(_poke(poolKey));
        _warp(SECONDS_AGO);
        (roundId, answer, startedAt, updatedAt, answeredInRound) = agg.latestRoundData();
        assertEq(roundId, 1);
        assertEq(uint256(answer), 1e18);
        assertEq(startedAt, updatedAt);
        assertEq(answeredInRound, 1);
        (uint80 gId, int256 gAns, uint256 gStart, uint256 gUp, uint80 gAnsRound) = agg.getRoundData(1);
        assertEq(gId, 1);
        assertEq(gAns, answer);
        assertEq(gStart, startedAt);
        assertEq(gUp, updatedAt);
        assertEq(gAnsRound, 1);
        vm.expectRevert(abi.encodeWithSelector(IUniswapV4TwapAdapterErrors.RoundNotFound.selector, uint80(2)));
        agg.getRoundData(2);
    }

    function test_H8_adapterNeverWrittenPriceZero() public {
        UniswapV4TwapMorphoOracle morpho = _createMorpho(true);
        assertEq(morpho.price(), 0);
    }
}
