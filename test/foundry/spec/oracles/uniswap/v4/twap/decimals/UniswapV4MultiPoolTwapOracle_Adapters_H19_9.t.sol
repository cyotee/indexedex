// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {IOracle} from "@crane/contracts/external/morpho/blue/interfaces/IOracle.sol";
import {TestBase_UniswapV4MultiPoolTwapOracle} from
    "contracts/test/bases/TestBase_UniswapV4MultiPoolTwapOracle.sol";
import {IUniswapV4TwapAdapterErrors} from
    "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4TwapAdapterErrors.sol";
import {UniswapV4TwapMorphoOracle} from
    "contracts/oracles/uniswap/v4/twap/UniswapV4TwapMorphoOracle.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";

contract NoDecimalsToken9 {}

/**
 * @title UniswapV4MultiPoolTwapOracle_Adapters_H19_9
 * @notice Clone of gold `test_H19_non18SnapshotNativeAndMissingDecimals` with a 9-dec token (HAVE 6).
 */
contract UniswapV4MultiPoolTwapOracle_Adapters_H19_9 is TestBase_UniswapV4MultiPoolTwapOracle {
    uint32 internal constant SECONDS_AGO = 30;
    uint32 internal constant MAX_WRITE_AGE = 300;

    function test_H19_non18SnapshotNativeAndMissingDecimals_9() public {
        MintableERC20Decimals nine = new MintableERC20Decimals("NINE", "NINE", 9);
        PoolKey memory mixed = _buildPoolKey(address(nine), address(tokenA));
        _initPool(poolManager, mixed, TickMath.getSqrtPriceAtTick(0));
        assertTrue(_poke(mixed));
        _warp(SECONDS_AGO);
        UniswapV4TwapMorphoOracle morpho = UniswapV4TwapMorphoOracle(
            twapAdapterFactory.createMorphoOracle(twapOracle, mixed, SECONDS_AGO, true, MAX_WRITE_AGE)
        );
        uint8 collDec = morpho.collDecimals();
        uint8 loanDec = morpho.loanDecimals();
        assertTrue(collDec == 9 || loanDec == 9);
        assertTrue(collDec == 18 || loanDec == 18);
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

        NoDecimalsToken9 bad = new NoDecimalsToken9();
        PoolKey memory badKey = _buildPoolKey(address(bad), address(tokenA));
        vm.expectRevert(IUniswapV4TwapAdapterErrors.DecimalsQueryFailed.selector);
        twapAdapterFactory.createMorphoOracle(twapOracle, badKey, SECONDS_AGO, true, MAX_WRITE_AGE);
    }
}
