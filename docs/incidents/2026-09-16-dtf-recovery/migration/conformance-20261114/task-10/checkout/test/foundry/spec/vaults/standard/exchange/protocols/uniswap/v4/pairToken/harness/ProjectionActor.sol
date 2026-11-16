// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";

// tag::ProjectionActor[]
/// @notice Funded real-manager participant for projector component differentials.
/// @dev This is not a vault, mock manager, or replacement for registered-product tests.
contract ProjectionActor is IUnlockCallback {
    IPoolManager public immutable manager;
    PoolKey internal _key;

    enum Kind {
        Modify,
        Swap,
        Donate
    }

    struct Request {
        Kind kind;
        int24 lower;
        int24 upper;
        int256 liquidityDelta;
        bytes32 salt;
        bool zeroForOne;
        uint256 amount0;
        uint256 amount1;
        uint160 limit;
    }

    // tag::constructor[]
    /// @notice Bind a real initialized pool.
    constructor(IPoolManager manager_, PoolKey memory key_) {
        manager = manager_;
        _key = key_;
    }
    // end::constructor[]

    // tag::receive[]
    /// @notice Accept real manager native-currency proceeds.
    receive() external payable {}
    // end::receive[]

    // tag::modify[]
    /// @notice Modify this actor's actual zero-salt position.
    function modify(int24 lower_, int24 upper_, int256 liquidityDelta_)
        external
        returns (BalanceDelta delta, BalanceDelta fees)
    {
        Request memory request;
        request.kind = Kind.Modify;
        request.lower = lower_;
        request.upper = upper_;
        request.liquidityDelta = liquidityDelta_;
        return abi.decode(manager.unlock(abi.encode(request)), (BalanceDelta, BalanceDelta));
    }
    // end::modify[]

    // tag::modifySalted[]
    /// @notice Create a distinct canonical position for position-key isolation checks.
    function modifySalted(int24 lower_, int24 upper_, int256 liquidityDelta_, bytes32 salt_)
        external
        returns (BalanceDelta delta, BalanceDelta fees)
    {
        Request memory request;
        request.kind = Kind.Modify;
        request.lower = lower_;
        request.upper = upper_;
        request.liquidityDelta = liquidityDelta_;
        request.salt = salt_;
        return abi.decode(manager.unlock(abi.encode(request)), (BalanceDelta, BalanceDelta));
    }
    // end::modifySalted[]

    // tag::swap[]
    /// @notice Execute exact input, retaining real proceeds on this funded actor.
    function swap(bool zeroForOne_, uint256 amountIn_, uint160 limit_) external returns (BalanceDelta delta) {
        Request memory request;
        request.kind = Kind.Swap;
        request.zeroForOne = zeroForOne_;
        request.amount0 = amountIn_;
        request.limit = limit_;
        (delta,) = abi.decode(manager.unlock(abi.encode(request)), (BalanceDelta, BalanceDelta));
    }
    // end::swap[]

    // tag::donate[]
    /// @notice Pay a real donation to generate independently specified position fees.
    function donate(uint256 amount0_, uint256 amount1_) external returns (BalanceDelta delta) {
        Request memory request;
        request.kind = Kind.Donate;
        request.amount0 = amount0_;
        request.amount1 = amount1_;
        (delta,) = abi.decode(manager.unlock(abi.encode(request)), (BalanceDelta, BalanceDelta));
    }
    // end::donate[]

    // tag::unlockCallback[]
    /// @inheritdoc IUnlockCallback
    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        require(msg.sender == address(manager), "actor: manager only");
        Request memory request = abi.decode(data_, (Request));
        BalanceDelta delta;
        BalanceDelta fees;
        if (request.kind == Kind.Modify) {
            (delta, fees) = manager.modifyLiquidity(
                _key,
                ModifyLiquidityParams(request.lower, request.upper, request.liquidityDelta, request.salt),
                ""
            );
        } else if (request.kind == Kind.Swap) {
            int256 specified;
            unchecked {
                specified = -int256(request.amount0);
            }
            delta = manager.swap(_key, SwapParams(request.zeroForOne, specified, request.limit), "");
        } else {
            delta = manager.donate(_key, request.amount0, request.amount1, "");
        }
        _settle(_key.currency0, delta.amount0());
        _settle(_key.currency1, delta.amount1());
        return abi.encode(delta, fees);
    }
    // end::unlockCallback[]

    function _settle(Currency currency_, int128 delta_) private {
        if (delta_ > 0) {
            manager.take(currency_, address(this), uint256(int256(delta_)));
        } else if (delta_ < 0) {
            uint256 debt = uint256(-int256(delta_));
            manager.sync(currency_);
            if (Currency.unwrap(currency_) == address(0)) {
                require(manager.settle{value: debt}() == debt, "actor: native settlement");
            } else {
                require(IERC20(Currency.unwrap(currency_)).transfer(address(manager), debt), "actor: transfer");
                require(manager.settle() == debt, "actor: token settlement");
            }
        }
    }
}
// end::ProjectionActor[]
