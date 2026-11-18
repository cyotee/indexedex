// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3SwapCallback} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3SwapCallback.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";

/// @notice Calls the real vault from a real bound-pool swap callback, then settles that swap.
contract UniswapV3PoolLockProbe is IUniswapV3SwapCallback {
    IUniswapV3Pool public immutable pool;
    address public immutable vault;
    bool public observedLocked;
    bool[] private successes;
    bytes[] private results;

    constructor(IUniswapV3Pool pool_, address vault_) {
        pool = pool_;
        vault = vault_;
    }

    function run(bytes[] memory calls_) external returns (bool[] memory, bytes[] memory) {
        delete successes;
        delete results;
        observedLocked = false;
        pool.swap(address(this), true, 1e6, TickMath.MIN_SQRT_RATIO + 1, abi.encode(calls_));
        return (successes, results);
    }

    function uniswapV3SwapCallback(int256 delta0_, int256 delta1_, bytes calldata data_) external override {
        require(msg.sender == address(pool), "foreign callback");
        (,,,,,, bool unlocked_) = pool.slot0();
        require(!unlocked_, "callback must hold the pool lock");
        observedLocked = true;
        bytes[] memory calls_ = abi.decode(data_, (bytes[]));
        for (uint256 i_; i_ < calls_.length; ++i_) {
            (bool success_, bytes memory result_) = vault.call(calls_[i_]);
            successes.push(success_);
            results.push(result_);
        }
        if (delta0_ > 0) require(IERC20(pool.token0()).transfer(msg.sender, uint256(delta0_)), "token0 payment");
        if (delta1_ > 0) require(IERC20(pool.token1()).transfer(msg.sender, uint256(delta1_)), "token1 payment");
    }
}
