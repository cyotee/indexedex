// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {
    ThresholdMode
} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    UniswapV4SingleStandardExchangeDETFCommon
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeDETFCommon.sol";
import {
    UniswapV4SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeDETFRepo.sol";
import {
    UniV4DetfListingOracleLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/UniV4DetfListingOracleLib.sol";

interface IUniswapV4SingleStandardExchangeDETFInfo {
    function isReserveLive() external view returns (bool);
    function pairToken() external view returns (IERC20);
    function backingStandardExchangeVault() external view returns (address);
    function standardExchangeVaultShare() external view returns (IERC20);
    function listingPoolKey() external view returns (PoolKey memory);
    function poolId() external view returns (PoolId);
    function creationSqrtPriceX96() external view returns (uint160);
    function twapSeconds() external view returns (uint32);
    function widthMultiplier() external view returns (uint24);
    function thresholdMode() external view returns (ThresholdMode);
    function mintThreshold() external view returns (uint256);
    function burnThreshold() external view returns (uint256);
    function syntheticPrice() external view returns (uint256);
    function isMintingAllowed() external view returns (bool);
    function isBurningAllowed() external view returns (bool);
    function isMarketMarkUsable() external view returns (bool);
    function bondNft() external view returns (address);
    function rebasingClaimToken() external view returns (address);
    function pokeListingOracle() external;
    function expansionClosureRatePerSecond() external view returns (uint256);
    function expansionCatchUpMaxSeconds() external view returns (uint256);
    function expansionCatchUpCapBps() external view returns (uint256);
    function lastExpansionTimestamp() external view returns (uint256);
}

abstract contract UniswapV4SingleStandardExchangeDETFInfoTarget is
    UniswapV4SingleStandardExchangeDETFCommon,
    IUniswapV4SingleStandardExchangeDETFInfo
{
    function isReserveLive() external view returns (bool) {
        return _s().isReserveLive;
    }

    function pairToken() external view returns (IERC20) {
        return _s().pairToken;
    }

    function backingStandardExchangeVault() external view returns (address) {
        return address(_s().standardExchangeVault);
    }

    function standardExchangeVaultShare() external view returns (IERC20) {
        return _s().standardExchangeVaultShare;
    }

    function listingPoolKey() external view returns (PoolKey memory) {
        return _s().poolKey;
    }

    function poolId() external view returns (PoolId) {
        return _s().poolId;
    }

    function creationSqrtPriceX96() external view returns (uint160) {
        return _s().creationSqrtPriceX96;
    }

    function twapSeconds() external view returns (uint32) {
        return _s().twapSeconds;
    }

    function widthMultiplier() external view returns (uint24) {
        return _s().widthMultiplier;
    }

    function thresholdMode() external view returns (ThresholdMode) {
        return _s().thresholdMode;
    }

    function mintThreshold() external view returns (uint256) {
        return _s().mintThreshold;
    }

    function burnThreshold() external view returns (uint256) {
        return _s().burnThreshold;
    }

    function syntheticPrice() external view returns (uint256) {
        return _syntheticPrice();
    }

    function isMintingAllowed() external view returns (bool) {
        return _isMintingAllowed();
    }

    function isBurningAllowed() external view returns (bool) {
        return _isBurningAllowed();
    }

    function isMarketMarkUsable() external view returns (bool) {
        return _isMarketMarkUsable();
    }

    function bondNft() external view returns (address) {
        return _s().bondNft;
    }

    function rebasingClaimToken() external view returns (address) {
        return _s().rebasingClaimToken;
    }

    function pokeListingOracle() external {
        _pokeListingOracle();
    }

    function expansionClosureRatePerSecond() external view returns (uint256) {
        return _s().expansionClosureRatePerSecond;
    }

    function expansionCatchUpMaxSeconds() external view returns (uint256) {
        return _s().expansionCatchUpMaxSeconds;
    }

    function expansionCatchUpCapBps() external view returns (uint256) {
        return _s().expansionCatchUpCapBps;
    }

    function lastExpansionTimestamp() external view returns (uint256) {
        return _s().lastExpansionTimestamp;
    }
}
