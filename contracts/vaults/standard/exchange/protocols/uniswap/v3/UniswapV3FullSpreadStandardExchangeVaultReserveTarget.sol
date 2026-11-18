// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {UniswapV3FullSpreadStandardExchangeVaultPlanner as Planner} from "./UniswapV3FullSpreadStandardExchangeVaultPlanner.sol";
import {UniswapV3FullSpreadStandardExchangeVaultPoolAwareRepo as PoolRepo} from "./UniswapV3FullSpreadStandardExchangeVaultPoolAwareRepo.sol";

contract UniswapV3FullSpreadStandardExchangeVaultReserveTarget {
    function reserves() external view returns (uint256[] memory reserves_) {
        Planner.PositionRead memory position_ = Planner.readPosition();
        reserves_ = new uint256[](2);
        reserves_[0] = position_.principal0 + position_.fee0;
        reserves_[1] = position_.principal1 + position_.fee1;
    }

    function reserveOfToken(address token_) external view returns (uint256) {
        bool token0_ = token_ == PoolRepo._uniswapV3Pool().token0();
        if (!token0_ && token_ != PoolRepo._uniswapV3Pool().token1()) return 0;
        Planner.PositionRead memory position_ = Planner.readPosition();
        return token0_ ? position_.principal0 + position_.fee0 : position_.principal1 + position_.fee1;
    }

    function canOpenBoundPoolOps() external view returns (bool) {
        (,,,,,, bool unlocked_) = PoolRepo._uniswapV3Pool().slot0();
        return unlocked_;
    }
}
