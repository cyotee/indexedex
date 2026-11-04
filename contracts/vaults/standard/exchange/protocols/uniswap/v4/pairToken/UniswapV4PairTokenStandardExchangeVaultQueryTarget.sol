// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {Position} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {UniswapV4PairTokenStandardExchangeVaultRepo as Repo} from "./UniswapV4PairTokenStandardExchangeVaultRepo.sol";
import {UniswapV4PairTokenStandardExchangeVaultTypes as Types} from "./UniswapV4PairTokenStandardExchangeVaultTypes.sol";
import {UniswapV4PairTokenStandardExchangeVaultMath as Math} from "./UniswapV4PairTokenStandardExchangeVaultMath.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultQueryTarget[]
/// @notice Immutable configuration and guarded raw-currency ownership observations.
contract UniswapV4PairTokenStandardExchangeVaultQueryTarget {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    // tag::poolManager-dc4c90d3[]
    /// @notice Bound manager; available during an operation.
    /// @custom:signature poolManager()
    /// @custom:selector 0xdc4c90d3
    function poolManager() external view returns (IPoolManager) {
        return Repo._layoutStruct().config.poolManager;
    }
    // end::poolManager-dc4c90d3[]

    // tag::poolKey-182148ef[]
    /// @notice Actual currency key, never its wrapped discovery faces.
    /// @custom:signature poolKey()
    /// @custom:selector 0x182148ef
    function poolKey() external view returns (PoolKey memory) {
        return Repo._layoutStruct().config.poolKey;
    }
    // end::poolKey-182148ef[]

    // tag::wrappedNative-eb6d3a11[]
    /// @notice Canonical native adapter, not an additional basket asset.
    /// @custom:signature wrappedNative()
    /// @custom:selector 0xeb6d3a11
    function wrappedNative() external view returns (address) {
        return Repo._layoutStruct().config.wrappedNative;
    }
    // end::wrappedNative-eb6d3a11[]

    // tag::rateAsset-cf77880f[]
    /// @notice Raw SY valuation face; not an issuance denominator.
    /// @custom:signature rateAsset()
    /// @custom:selector 0xcf77880f
    function rateAsset() external view returns (address) {
        return Repo._layoutStruct().config.rateAsset;
    }
    // end::rateAsset-cf77880f[]

    // tag::tickLower-59c4f905[]
    /// @notice Full-range usable lower boundary.
    /// @custom:signature tickLower()
    /// @custom:selector 0x59c4f905
    function tickLower() external view returns (int24) {
        return Repo._layoutStruct().config.tickLower;
    }
    // end::tickLower-59c4f905[]

    // tag::tickUpper-55b812a8[]
    /// @notice Full-range usable upper boundary.
    /// @custom:signature tickUpper()
    /// @custom:selector 0x55b812a8
    function tickUpper() external view returns (int24) {
        return Repo._layoutStruct().config.tickUpper;
    }
    // end::tickUpper-55b812a8[]

    // tag::positionLiquidity-7211dc36[]
    /// @notice The diamond's canonical salt-zero position, not active pool liquidity.
    /// @custom:signature positionLiquidity()
    /// @custom:selector 0x7211dc36
    function positionLiquidity() external view returns (uint128) {
        Repo._requireIdle();
        return _positionLiquidity(Repo._layoutStruct().config);
    }
    // end::positionLiquidity-7211dc36[]

    // tag::localReserves-765d889f[]
    /// @notice Booked local ownership only, in actual currency order.
    /// @custom:signature localReserves()
    /// @custom:selector 0x765d889f
    function localReserves() external view returns (uint256 amount0, uint256 amount1) {
        Repo.Storage storage state_ = Repo._layoutStruct();
        Repo._requireIdle(state_);
        return (state_.inventory.booked.amount0, state_.inventory.booked.amount1);
    }
    // end::localReserves-765d889f[]

    // tag::basket-edc832b3[]
    /// @notice Removable principal plus booked idle, without uncollected fees.
    /// @custom:signature basket()
    /// @custom:selector 0xedc832b3
    function basket() external view returns (uint256 amount0, uint256 amount1) {
        Repo.Storage storage state_ = Repo._layoutStruct();
        Repo._requireIdle(state_);
        Types.Config memory config_ = state_.config;
        (uint160 price_,,,) = config_.poolManager.getSlot0(config_.poolKey.toId());
        (amount0, amount1) = Math.principal(
            price_, TickMath.getSqrtPriceAtTick(config_.tickLower),
            TickMath.getSqrtPriceAtTick(config_.tickUpper), _positionLiquidity(config_)
        );
        amount0 += state_.inventory.booked.amount0;
        amount1 += state_.inventory.booked.amount1;
    }
    // end::basket-edc832b3[]

    // tag::maxZapBps-6e2abc14[]
    /// @notice Explicit zap size and compound-cap configuration.
    /// @custom:signature maxZapBps()
    /// @custom:selector 0x6e2abc14
    function maxZapBps() external view returns (uint16) {
        return Repo._layoutStruct().config.maxZapBps;
    }
    // end::maxZapBps-6e2abc14[]

    // tag::maxZapTickMove-67698371[]
    /// @notice Tick bound around the caller entry swap only.
    /// @custom:signature maxZapTickMove()
    /// @custom:selector 0x67698371
    function maxZapTickMove() external view returns (int24) {
        return Repo._layoutStruct().config.maxZapTickMove;
    }
    // end::maxZapTickMove-67698371[]

    function _positionLiquidity(Types.Config memory config_) private view returns (uint128) {
        return config_.poolManager.getPositionLiquidity(
            config_.poolKey.toId(),
            Position.calculatePositionKey(address(this), config_.tickLower, config_.tickUpper, bytes32(0))
        );
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultQueryTarget[]
