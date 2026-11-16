// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IOracle} from "@crane/contracts/external/morpho/blue/interfaces/IOracle.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    IUniswapV4TwapAdapterErrors
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4TwapAdapterErrors.sol";
import {
    UniswapV4TruncatedTwapOracleLib
} from "contracts/oracles/uniswap/v4/twap/libraries/UniswapV4TruncatedTwapOracleLib.sol";

/// @notice Frozen Morpho `IOracle` monomorph. Example `maxWriteAge` is 300 seconds.
contract UniswapV4TwapMorphoOracle is IOracle, IUniswapV4TwapAdapterErrors {
    IUniswapV4MultiPoolTwapOracle public immutable oracle;
    Currency public immutable currency0;
    Currency public immutable currency1;
    uint24 public immutable fee;
    int24 public immutable tickSpacing;
    IHooks public immutable hooks;
    PoolId public immutable poolId;
    uint32 public immutable secondsAgo;
    bool public immutable collateralIsCurrency0;
    uint32 public immutable maxWriteAge;
    uint8 public immutable collDecimals;
    uint8 public immutable loanDecimals;
    address public immutable collateral;
    address public immutable loan;

    constructor(
        IUniswapV4MultiPoolTwapOracle oracle_,
        PoolKey memory key_,
        uint32 secondsAgo_,
        bool collateralIsCurrency0_,
        uint32 maxWriteAge_
    ) {
        if (address(oracle_) == address(0)) revert ZeroOracle();
        if (secondsAgo_ == 0) revert ZeroSecondsAgo();
        if (maxWriteAge_ == 0) revert ZeroMaxWriteAge();
        if (oracle_.poolManager() == address(0)) revert IUniswapV4MultiPoolTwapOracle.ZeroPoolManager();

        oracle = oracle_;
        currency0 = key_.currency0;
        currency1 = key_.currency1;
        fee = key_.fee;
        tickSpacing = key_.tickSpacing;
        hooks = key_.hooks;
        poolId = key_.toId();
        secondsAgo = secondsAgo_;
        collateralIsCurrency0 = collateralIsCurrency0_;
        maxWriteAge = maxWriteAge_;

        address currency0_ = Currency.unwrap(key_.currency0);
        address currency1_ = Currency.unwrap(key_.currency1);
        if (collateralIsCurrency0_) {
            collateral = currency0_;
            loan = currency1_;
        } else {
            collateral = currency1_;
            loan = currency0_;
        }
        collDecimals = _snapshotDecimals(collateral);
        loanDecimals = _snapshotDecimals(loan);
    }

    function price() external view returns (uint256) {
        uint16 cardinality;
        {
            uint16 index_;
            uint16 cardinalityNext_;
            int24 prevTick_;
            uint32 lastTimestamp_;
            (index_, cardinality, cardinalityNext_, prevTick_, lastTimestamp_) = oracle.getState(poolId);
            index_;
            cardinalityNext_;
            prevTick_;
            lastTimestamp_;
        }
        IUniswapV4MultiPoolTwapOracle.Observation memory first = oracle.getObservation(poolId, 0);
        if (cardinality == 0 || !first.initialized) {
            return 0;
        }
        uint256 age = oracle.writeAge(poolId);
        if (age > maxWriteAge) {
            revert StaleObservation(age, maxWriteAge);
        }
        int24 tick_ = oracle.consult(poolId, secondsAgo);
        // Morpho `IOracle.price()` is wei/wei * 1e36 (`loan_wei = coll_wei * price / 1e36`).
        // Uniswap ticks are already wei/wei; do not apply token decimals again (that is Chainlink human scale).
        uint256 quoteAmount =
            UniswapV4TruncatedTwapOracleLib.getQuoteAtTick(tick_, uint128(1e18), collateral, loan);
        return quoteAmount * 1e18;
    }

    function _snapshotDecimals(address token_) internal view returns (uint8) {
        if (token_ == address(0)) {
            return 18;
        }
        try IERC20Metadata(token_).decimals() returns (uint8 decimals_) {
            return decimals_;
        } catch {
            revert DecimalsQueryFailed();
        }
    }
}
