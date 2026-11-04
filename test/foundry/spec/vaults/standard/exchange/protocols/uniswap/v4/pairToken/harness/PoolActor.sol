// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";

// tag::PoolActor[]
/// @notice Prefunded external position/trader for real-manager family tests.
/// @dev Never impersonates the vault. Positive receipts remain with this actor.
contract PoolActor is IUnlockCallback {
    IPoolManager public immutable manager;
    bytes32 private pending;

    enum Operation { Modify, Swap, Donate }

    /// @notice Bind the real manager used by the family fixture.
    constructor(IPoolManager manager_) {
        manager = manager_;
    }

    /// @notice Accept native funding and manager takes.
    receive() external payable {}

    /// @notice Add, remove or poke a genuine actor-owned position.
    function modifyLiquidity(PoolKey memory key_, ModifyLiquidityParams memory params_)
        external payable returns (BalanceDelta delta_, BalanceDelta fees_)
    {
        return abi.decode(_unlock(abi.encode(Operation.Modify, key_, abi.encode(params_))), (BalanceDelta, BalanceDelta));
    }

    /// @notice Execute a real swap; exact input is a negative amountSpecified.
    function swap(PoolKey memory key_, SwapParams memory params_) external payable returns (BalanceDelta) {
        return abi.decode(_unlock(abi.encode(Operation.Swap, key_, abi.encode(params_))), (BalanceDelta));
    }

    /// @notice Create genuine fee growth for in-range positions.
    function donate(PoolKey memory key_, uint256 amount0_, uint256 amount1_)
        external payable returns (BalanceDelta)
    {
        return abi.decode(_unlock(abi.encode(Operation.Donate, key_, abi.encode(amount0_, amount1_))), (BalanceDelta));
    }

    /// @inheritdoc IUnlockCallback
    function unlockCallback(bytes calldata data_) external returns (bytes memory result_) {
        require(msg.sender == address(manager) && pending != bytes32(0) && keccak256(data_) == pending, "actor callback");
        delete pending;
        (Operation operation_, PoolKey memory key_, bytes memory args_) = abi.decode(data_, (Operation, PoolKey, bytes));
        BalanceDelta delta_;
        if (operation_ == Operation.Modify) {
            BalanceDelta fees_;
            (delta_, fees_) = manager.modifyLiquidity(key_, abi.decode(args_, (ModifyLiquidityParams)), "");
            result_ = abi.encode(delta_, fees_);
        } else if (operation_ == Operation.Swap) {
            delta_ = manager.swap(key_, abi.decode(args_, (SwapParams)), "");
            result_ = abi.encode(delta_);
        } else {
            (uint256 amount0_, uint256 amount1_) = abi.decode(args_, (uint256, uint256));
            delta_ = manager.donate(key_, amount0_, amount1_, "");
            result_ = abi.encode(delta_);
        }
        _settle(key_.currency0, int256(delta_.amount0()));
        _settle(key_.currency1, int256(delta_.amount1()));
        require(TransientStateLibrary.currencyDelta(manager, address(this), key_.currency0) == 0, "actor delta0");
        require(TransientStateLibrary.currencyDelta(manager, address(this), key_.currency1) == 0, "actor delta1");
    }

    function _unlock(bytes memory data_) private returns (bytes memory) {
        require(pending == bytes32(0), "actor busy");
        pending = keccak256(data_);
        bytes memory result_ = manager.unlock(data_);
        require(pending == bytes32(0), "actor callback missing");
        return result_;
    }

    function _settle(Currency currency_, int256 delta_) private {
        if (delta_ > 0) {
            manager.take(currency_, address(this), uint256(delta_));
        } else if (delta_ < 0) {
            uint256 debt_ = uint256(-delta_);
            manager.sync(currency_);
            uint256 paid_;
            if (Currency.unwrap(currency_) == address(0)) {
                paid_ = manager.settle{value: debt_}();
            } else {
                require(IERC20(Currency.unwrap(currency_)).transfer(address(manager), debt_), "actor transfer");
                paid_ = manager.settle();
            }
            require(paid_ == debt_, "actor settlement");
        }
    }
}
// end::PoolActor[]
