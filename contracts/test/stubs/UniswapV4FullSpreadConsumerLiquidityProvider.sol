// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";

/// @notice Independently funded real-core LP for consumer tests; no legacy SE imports.
contract UniswapV4FullSpreadConsumerLiquidityProvider is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    IPoolManager private active;
    IWETH private weth;
    receive() external payable {}

    function addV4(IPoolManager manager, PoolKey memory key, IWETH wrapped, uint128 liquidity) external {
        require(address(active) == address(0), "active callback");
        active = manager;
        weth = wrapped;
        manager.unlock(abi.encode(key, liquidity));
        active = IPoolManager(address(0));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(active), "manager");
        (PoolKey memory key, uint128 liquidity) = abi.decode(data, (PoolKey, uint128));
        (BalanceDelta delta,) = active.modifyLiquidity(key, ModifyLiquidityParams(TickMath.minUsableTick(key.tickSpacing),
            TickMath.maxUsableTick(key.tickSpacing), int256(uint256(liquidity)), bytes32(0)), "");
        _settle(key.currency0, delta.amount0());
        _settle(key.currency1, delta.amount1());
        return "";
    }

    function _settle(Currency currency, int128 delta) private {
        if (delta >= 0) return;
        uint256 amount = uint128(-delta);
        if (Currency.unwrap(currency) == address(0)) {
            weth.withdraw(amount);
            active.settle{value: amount}();
        } else {
            active.sync(currency);
            IERC20(Currency.unwrap(currency)).transfer(address(active), amount);
            active.settle();
        }
    }
}
