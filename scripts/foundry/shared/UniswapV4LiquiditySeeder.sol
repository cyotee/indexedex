// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";

contract UniswapV4LiquiditySeeder is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;

    IPoolManager internal immutable poolManager;

    constructor(IPoolManager poolManager_) {
        poolManager = poolManager_;
    }

    function addLiquidity(PoolKey memory poolKey_, int24 tickLower_, int24 tickUpper_, uint128 liquidity_) external {
        poolManager.unlock(abi.encode(poolKey_, tickLower_, tickUpper_, liquidity_));
    }

    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "not pool manager");

        (PoolKey memory poolKey_, int24 tickLower_, int24 tickUpper_, uint128 liquidity_) =
            abi.decode(data_, (PoolKey, int24, int24, uint128));

        (BalanceDelta callerDelta,) = poolManager.modifyLiquidity(
            poolKey_,
            ModifyLiquidityParams({
                tickLower: tickLower_,
                tickUpper: tickUpper_,
                liquidityDelta: int256(uint256(liquidity_)),
                salt: bytes32(0)
            }),
            bytes("")
        );

        _settle(poolKey_.currency0, callerDelta.amount0());
        _settle(poolKey_.currency1, callerDelta.amount1());

        return abi.encode(callerDelta);
    }

    function _settle(Currency currency_, int128 delta_) internal {
        if (delta_ < 0) {
            uint256 amount = uint128(-delta_);
            poolManager.sync(currency_);
            IERC20(Currency.unwrap(currency_)).transfer(address(poolManager), amount);
            poolManager.settle();
        } else if (delta_ > 0) {
            poolManager.take(currency_, address(this), uint128(delta_));
        }
    }
}