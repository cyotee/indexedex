// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3SwapCallback} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3SwapCallback.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";

/// @notice Executes real vault calldata during a bound-pool swap callback (V3-ACC-15).
contract UniswapV3FullSpreadStandardExchangeVaultBoundPoolLockSeCaller is IUniswapV3SwapCallback {
    IUniswapV3Pool public immutable pool;
    address private target;
    bytes private pending;
    bytes private result;

    constructor(IUniswapV3Pool pool_) { pool = pool_; }

    /// @notice Approves pull inputs and invokes the supplied route while slot0.unlocked is false.
    function run(address target_, bytes calldata data_) external returns (bytes memory) {
        target = target_;
        pending = data_;
        IERC20(pool.token0()).approve(target_, type(uint256).max);
        IERC20(pool.token1()).approve(target_, type(uint256).max);
        pool.swap(address(this), true, int256(1), TickMath.MIN_SQRT_RATIO + 1, "");
        return result;
    }

    /// @notice Only the bound pool may dispatch pending calldata and collect its actual debt.
    function uniswapV3SwapCallback(int256 delta0, int256 delta1, bytes calldata) external override {
        require(msg.sender == address(pool), "not pool");
        (bool success, bytes memory returned) = target.call(pending);
        if (!success) {
            assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
        }
        result = returned;
        if (delta0 > 0) IERC20(pool.token0()).transfer(msg.sender, uint256(delta0));
        if (delta1 > 0) IERC20(pool.token1()).transfer(msg.sender, uint256(delta1));
    }
}
