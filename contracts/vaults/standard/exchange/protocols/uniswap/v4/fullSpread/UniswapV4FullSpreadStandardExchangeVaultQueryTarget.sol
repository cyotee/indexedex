// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {WETHAwareRepo} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETHAwareRepo.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {UniswapV4SinglePositionAwareRepo} from "@crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4SinglePositionAwareRepo.sol";
import {UniswapV4FullSpreadStandardExchangeVaultComponentBindings} from "./UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol";
import {UniswapV4FullSpreadStandardExchangeVaultProjection as Projection} from "./UniswapV4FullSpreadStandardExchangeVaultProjection.sol";

contract UniswapV4FullSpreadStandardExchangeVaultQueryTarget is
    UniswapV4FullSpreadStandardExchangeVaultComponentBindings
{
    function reserveOfToken(address token) external view returns (uint256 reserve_) {
        (address face0_, address face1_) = _faces();
        Projection.PositionRead memory read_ = Projection.read();
        if (token == face0_) return read_.amount0 + read_.fee0;
        if (token == face1_) return read_.amount1 + read_.fee1;
        return 0;
    }

    function reserves() external view returns (uint256[] memory reserves_) {
        (address face0_, address face1_) = _faces();
        Projection.PositionRead memory read_ = Projection.read();
        reserves_ = new uint256[](2);
        face0_;
        face1_;
        reserves_[0] = read_.amount0 + read_.fee0;
        reserves_[1] = read_.amount1 + read_.fee1;
    }

    function _faces() internal view returns (address face0_, address face1_) {
        PoolKey memory key_ = UniswapV4SinglePositionAwareRepo._poolKey();
        address weth_ = address(WETHAwareRepo._weth());
        face0_ = Currency.unwrap(key_.currency0);
        if (face0_ == address(0)) face0_ = weth_;
        face1_ = Currency.unwrap(key_.currency1);
        if (face1_ == address(0)) face1_ = weth_;
    }
}
