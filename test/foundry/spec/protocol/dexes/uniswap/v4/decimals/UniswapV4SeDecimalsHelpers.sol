// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {TestBase_UniswapV4StandardExchange_Decimals} from
    "contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange_Decimals.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";

/**
 * @title UniswapV4SeDecimalsHelpers
 * @notice Amount and 1:1-human price helpers for Uni V4 SE decimal clones.
 *         pairToken = tokenA. vaultShare stays 18. Native ETH (address(0)) is 18-dec.
 */
abstract contract UniswapV4SeDecimalsHelpers is TestBase_UniswapV4StandardExchange_Decimals {
    function _decOf(address token) internal view returns (uint8) {
        if (token == address(0)) return 18;
        return IERC20Metadata(token).decimals();
    }

    function _uOf(address token, uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(_decOf(token)));
    }

    /// @dev Gold `1e12` of 18-dec is 1e-6 human. Floor at 1000 raw units so a 6-dec
    ///      0.3% fee swap still returns > 0 (1 raw unit of 6-dec rounds to zero).
    function _tinyOf(address token) internal view returns (uint256) {
        uint256 u = _uOf(token, 1);
        uint256 t = u / 1e6;
        if (t < 1000) {
            return u > 1000 ? 1000 : (u == 0 ? 1 : u);
        }
        return t;
    }

    /// @dev Gold `1e15` of 18-dec is 1e-3 human. Floor at 1 raw unit.
    function _milliOf(address token) internal view returns (uint256) {
        uint256 u = _uOf(token, 1);
        uint256 t = u / 1_000;
        return t == 0 ? 1 : t;
    }

    function _halfOf(address token) internal view returns (uint256) {
        uint256 u = _uOf(token, 1);
        uint256 h = u / 2;
        return h == 0 ? 1 : h;
    }

    function _encodeSqrtRatioX96(uint256 amount1, uint256 amount0) internal pure returns (uint160) {
        uint256 sqrt1 = Math.sqrt(amount1);
        uint256 sqrt0 = Math.sqrt(amount0);
        return uint160((sqrt1 << 96) / sqrt0);
    }

    /// @notice sqrtPriceX96 for 1 human token0 = 1 human token1 (decimal-adjusted).
    function _oneToOneHumanSqrtPrice(address token0, address token1) internal view returns (uint160) {
        return _encodeSqrtRatioX96(_uOf(token1, 1), _uOf(token0, 1));
    }

    function _seedTicksAround(uint160 sqrtPriceX96, int24 spacing)
        internal
        pure
        returns (int24 tickLower, int24 tickUpper)
    {
        int24 tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);
        int24 center = (tick / spacing) * spacing;
        tickLower = center - (2 * spacing);
        tickUpper = center + (2 * spacing);
    }

    function _mintToken(address token, address to, uint256 amount) internal {
        MintableERC20Decimals(token).mint(to, amount);
    }

    function _buildPoolKey(address token0Candidate, address token1Candidate)
        internal
        pure
        returns (PoolKey memory key)
    {
        (address token0, address token1) = token0Candidate < token1Candidate
            ? (token0Candidate, token1Candidate)
            : (token1Candidate, token0Candidate);
        key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }
}
