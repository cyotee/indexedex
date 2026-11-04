// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor[]
/// @notice Test-only actor executing real protocol operations for independent liquidation references.
/// @dev This is not a vault, share issuer, mock PoolManager or substitute SUT. Tokens are held by distinct actors.
contract UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    IPoolManager internal immutable manager;
    address internal immutable controller;
    bool internal active;

    error Unauthorized();

    constructor(IPoolManager manager_, address controller_) {
        manager = manager_;
        controller = controller_;
    }

    /// @notice Add or remove a position actually owned by this actor.
    function modify(PoolKey memory key_, int24 lower_, int24 upper_, int256 liquidity_, bytes32 salt_)
        external
        returns (BalanceDelta delta_, BalanceDelta fees_)
    {
        _start();
        bytes memory result = manager.unlock(
            abi.encode(uint8(0), key_, abi.encode(ModifyLiquidityParams(lower_, upper_, liquidity_, salt_)))
        );
        active = false;
        return abi.decode(result, (BalanceDelta, BalanceDelta));
    }

    /// @notice Actual exact-input swap toward the protocol limit; unused input remains with this actor.
    function swap(PoolKey memory key_, bool zeroForOne_, uint256 amount_) external returns (BalanceDelta delta_) {
        return
            _swap(key_, zeroForOne_, amount_, zeroForOne_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1);
    }

    /// @notice Real trade with an explicit price limit, used to construct and restore reference market states.
    function swapTo(PoolKey memory key_, bool zeroForOne_, uint256 amount_, uint160 limit_)
        external
        returns (BalanceDelta delta_)
    {
        return _swap(key_, zeroForOne_, amount_, limit_);
    }

    function _swap(PoolKey memory key_, bool zeroForOne_, uint256 amount_, uint160 limit_)
        internal
        returns (BalanceDelta delta_)
    {
        require(amount_ <= uint256(type(int256).max), "reference amount overflow");
        _start();
        SwapParams memory params = SwapParams(zeroForOne_, -int256(amount_), limit_);
        bytes memory result = manager.unlock(abi.encode(uint8(1), key_, abi.encode(params)));
        active = false;
        return abi.decode(result, (BalanceDelta));
    }

    /// @notice Non-vault reference actor opens an outer manager session around a real consumer call.
    function callWhileUnlocked(PoolKey memory key_, address callee_, bytes memory callData_) external returns (bytes memory) {
        _start();
        bytes memory result = manager.unlock(abi.encode(uint8(2), key_, abi.encode(callee_, callData_)));
        active = false;
        return result;
    }

    function approveToken(IERC20 token_, address spender_) external {
        require(msg.sender == controller, "controller");
        require(token_.approve(spender_, type(uint256).max), "approval");
    }

    /// @notice Settle the protocol's actual caller delta exactly once, including owned accrued fees.
    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        if (msg.sender != address(manager) || !active) revert Unauthorized();
        (uint8 operation, PoolKey memory key, bytes memory payload) = abi.decode(data_, (uint8, PoolKey, bytes));
        if (operation == 2) {
            (address callee, bytes memory callData) = abi.decode(payload, (address, bytes));
            (bool success, bytes memory result) = callee.call(callData);
            if (!success) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
            return result;
        }
        BalanceDelta delta;
        BalanceDelta fees;
        if (operation == 0) {
            (delta, fees) = manager.modifyLiquidity(key, abi.decode(payload, (ModifyLiquidityParams)), "");
        } else {
            delta = manager.swap(key, abi.decode(payload, (SwapParams)), "");
        }
        _settle(key.currency0, delta.amount0());
        _settle(key.currency1, delta.amount1());
        return operation == 0 ? abi.encode(delta, fees) : abi.encode(delta);
    }

    function _start() internal {
        if (msg.sender != controller || active) revert Unauthorized();
        active = true;
    }

    function _settle(Currency currency_, int128 delta_) internal {
        if (delta_ < 0) {
            manager.sync(currency_);
            require(
                IERC20(Currency.unwrap(currency_)).transfer(address(manager), uint256(-int256(delta_))),
                "reference settlement failed"
            );
            manager.settle();
        } else if (delta_ > 0) {
            manager.take(currency_, address(this), uint128(delta_));
        }
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor[]
