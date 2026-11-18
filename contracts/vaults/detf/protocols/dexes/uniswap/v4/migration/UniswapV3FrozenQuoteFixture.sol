// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {BitMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/BitMath.sol";
import {UniswapV3Quoter} from "@crane/contracts/utils/math/UniswapV3Quoter.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeFrozenQuoteInputs as Frozen} from "contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol";
import {StandardExchangeFrozenQuoteLib as Quote} from "contracts/utils/StandardExchangeFrozenQuoteLib.sol";

/// @notice Differential-fixture acquisition from explicit deployment bindings.
/// @dev Production pricing accepts manual owner operands and never invokes this collector.
/// A capture reads the complete pool domain in one view call. It either completes or reverts;
/// no truncated book is published. Sparse zero words retain their represented word boundaries.
library UniswapV3FrozenQuoteFixture {
    struct Binding {
        address exchange;
        address pool;
        address feeOracle;
    }

    function capture(Binding memory binding, address tokenIn)
        internal
        view
        returns (Frozen.VersionedInputs memory encoded)
    {
        IUniswapV3Pool pool = IUniswapV3Pool(binding.pool);
        Frozen.SwapDepositV2 memory q;
        q.exchange = binding.exchange;
        q.request = Frozen.Request(tokenIn, binding.exchange, address(0), Frozen.Mode.OrdinaryDeposit);
        q.pool = binding.pool;
        q.token0 = pool.token0();
        q.token1 = pool.token1();
        address[] memory tokens = IBasicVault(binding.exchange).vaultTokens();
        require(tokens.length == 2 && tokens[0] == q.token0 && tokens[1] == q.token1, "frozen pool token binding");
        // Acquisition failures propagate. An unreadable live position is not a zero-liquidity book.
        IStandardExchangeIn(binding.exchange).previewExchangeIn(IERC20(tokenIn), 0, IERC20(binding.exchange));
        q.supply = IERC20(binding.exchange).totalSupply();
        q.poolState = _pool(pool);
        if (q.supply != 0) {
            bytes32 key = keccak256(abi.encodePacked(
                binding.exchange,
                TickMath.minUsableTick(q.poolState.tickSpacing),
                TickMath.maxUsableTick(q.poolState.tickSpacing)
            ));
            (q.positionLiquidity,,,,) = pool.positions(key);
        }
        IVaultFeeOracleQuery oracle = IVaultFeeOracleQuery(binding.feeOracle);
        q.usageFeeWad = oracle.usageFeeOfVault(binding.exchange);
        q.feeTo = address(oracle.feeTo());
        encoded = Frozen.VersionedInputs(2, abi.encode(q));
        Quote.requireSupported(encoded);
    }

    function _pool(IUniswapV3Pool pool) private view returns (UniswapV3Quoter.PoolSnapshot memory state) {
        (state.sqrtPriceX96, state.tick,,,,,) = pool.slot0();
        state.activeLiquidity = pool.liquidity();
        state.tickSpacing = pool.tickSpacing();
        state.feePips = pool.fee();
        state.maxLiquidityPerTick = pool.maxLiquidityPerTick();
        (state.firstWord, state.lastWord) = UniswapV3Quoter.snapshotWordBounds(state.tickSpacing);
        uint256 wordCount = uint256(int256(state.lastWord) - int256(state.firstWord) + 1);
        uint256[] memory words = new uint256[](wordCount);
        uint256 populated;
        uint256 initialized;
        for (uint256 i; i < wordCount; ++i) {
            uint256 word = pool.tickBitmap(int16(int256(state.firstWord) + int256(i)));
            words[i] = word;
            if (word != 0) ++populated;
            while (word != 0) {
                ++initialized;
                word &= word - 1;
            }
        }
        state.bitmapWords = new UniswapV3Quoter.BitmapWord[](populated);
        state.initializedTicks = new UniswapV3Quoter.InitializedTick[](initialized);
        uint256 wordCursor;
        uint256 tickCursor;
        for (uint256 i; i < wordCount; ++i) {
            uint256 word = words[i];
            if (word == 0) continue;
            int16 wordIndex = int16(int256(state.firstWord) + int256(i));
            state.bitmapWords[wordCursor++] = UniswapV3Quoter.BitmapWord(wordIndex, word);
            while (word != 0) {
                uint8 bit = BitMath.leastSignificantBit(word);
                int24 tick = ((int24(wordIndex) << 8) + int24(uint24(bit))) * state.tickSpacing;
                (uint128 gross, int128 net,,,,,,) = pool.ticks(tick);
                state.initializedTicks[tickCursor++] = UniswapV3Quoter.InitializedTick(tick, gross, net);
                word &= word - 1;
            }
        }
    }
}
