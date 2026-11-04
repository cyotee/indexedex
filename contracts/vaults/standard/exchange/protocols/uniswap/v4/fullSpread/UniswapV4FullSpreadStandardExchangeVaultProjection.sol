// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {UniswapV4ProtocolAwareRepo} from "@crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4ProtocolAwareRepo.sol";
import {UniswapV4SinglePositionAwareRepo} from "@crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4SinglePositionAwareRepo.sol";
import {UniswapV4FullSpreadStandardExchangeVaultMath as Math} from "./UniswapV4FullSpreadStandardExchangeVaultMath.sol";

/// @notice Position amounts and unpaid fees. Booked balances are not included.
library UniswapV4FullSpreadStandardExchangeVaultProjection {
    uint256 internal constant Q128 = 1 << 128;

    struct PositionRead {
        uint128 liquidity;
        uint160 sqrtPriceX96;
        int24 tick;
        uint160 sqrtA;
        uint160 sqrtB;
        uint256 amount0;
        uint256 amount1;
        uint256 fee0;
        uint256 fee1;
    }

    function read() internal view returns (PositionRead memory read_) {
        UniswapV4SinglePositionAwareRepo.Storage storage position_ = UniswapV4SinglePositionAwareRepo._layoutStruct();
        IPoolManager manager_ = UniswapV4ProtocolAwareRepo._poolManager();
        PoolKey memory key_ = position_.poolKey;
        read_.sqrtA = TickMath.getSqrtPriceAtTick(position_.tickLower);
        read_.sqrtB = TickMath.getSqrtPriceAtTick(position_.tickUpper);
        (read_.sqrtPriceX96, read_.tick,,) = StateLibrary.getSlot0(manager_, key_.toId());
        uint256 last0_;
        uint256 last1_;
        (read_.liquidity, last0_, last1_) = StateLibrary.getPositionInfo(
            manager_, key_.toId(), address(this), position_.tickLower, position_.tickUpper, position_.salt
        );
        (read_.amount0, read_.amount1) =
            Math.amountsForLiquidity(read_.sqrtPriceX96, read_.sqrtA, read_.sqrtB, read_.liquidity);
        if (read_.liquidity == 0) return read_;
        (uint256 inside0_, uint256 inside1_) =
            StateLibrary.getFeeGrowthInside(manager_, key_.toId(), position_.tickLower, position_.tickUpper);
        read_.fee0 = FullMath.mulDiv(read_.liquidity, inside0_ - last0_, Q128);
        read_.fee1 = FullMath.mulDiv(read_.liquidity, inside1_ - last1_, Q128);
    }
}
