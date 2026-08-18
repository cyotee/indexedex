// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";

/// @title UniswapV4DetfHookStagedInitLib
/// @notice Granular door + finalize helpers plus TestBase-only `ensureReserveReady*`.
/// @dev Broadcast scripts must call `openProductPair` once per unordered pair, then
///      `finalizeHook`, then the two instance wiring functions. Do not call
///      `ensureReserveReady*` from scripts (that is one transaction).
library UniswapV4DetfHookStagedInitLib {
    function productTokensCp(IUniswapV4SingleStandardExchangeDETF detf)
        internal
        view
        returns (address[] memory tokens)
    {
        tokens = new address[](2);
        tokens[0] = address(detf);
        tokens[1] = detf.pairToken();
    }

    function productTokensOrbital(IUniswapV4StandardExchangeOrbitalDETF detf)
        internal
        view
        returns (address[] memory tokens)
    {
        return _orbitalTokens(detf);
    }

    function productTokensWeighted(IUniswapV4StandardExchangeWeightedDETF detf)
        internal
        view
        returns (address[] memory tokens)
    {
        uint8 m_ = detf.m();
        uint8 n_ = m_ + 1;
        tokens = new address[](n_);
        tokens[0] = address(detf);
        for (uint8 i; i < m_; ++i) {
            tokens[i + 1] = detf.pairToken(i);
        }
        _sort(tokens);
    }

    function productTokensQuad(IUniswapV4StandardExchangeCurveQuadStableDETF detf)
        internal
        view
        returns (address[] memory tokens)
    {
        tokens = new address[](4);
        tokens[0] = address(detf);
        tokens[1] = detf.pairToken(0);
        tokens[2] = detf.pairToken(1);
        tokens[3] = detf.pairToken(2);
        _sort(tokens);
    }

    function openProductPair(address hook, address tokenA, address tokenB) internal {
        IUniswapV4HookStagedPairInit(hook).deployPair(tokenA, tokenB);
    }

    function finalizeHook(address hook) internal {
        IUniswapV4HookStagedPairInit(hook).finalizeInitialization();
    }

    function ensureReserveReadyCp(IUniswapV4SingleStandardExchangeDETF detf) internal {
        address hook_ = detf.reserveHook();
        require(hook_ != address(0), "reserveHook");
        _openAllPairs(hook_, productTokensCp(detf));
        finalizeHook(hook_);
        detf.completeReserveBondNft();
        detf.completeReserveClaim();
    }

    function ensureReserveReadyOrbital(IUniswapV4StandardExchangeOrbitalDETF detf) internal {
        address hook_ = detf.reserveHook();
        require(hook_ != address(0), "reserveHook");
        _openAllPairs(hook_, productTokensOrbital(detf));
        finalizeHook(hook_);
        detf.completeReserveBondNft();
        detf.completeReserveClaim();
    }

    function ensureReserveReadyWeighted(IUniswapV4StandardExchangeWeightedDETF detf) internal {
        address hook_ = detf.reserveHook();
        require(hook_ != address(0), "reserveHook");
        _openAllPairs(hook_, productTokensWeighted(detf));
        finalizeHook(hook_);
        detf.completeReserveBondNft();
        detf.completeReserveClaim();
    }

    function ensureReserveReadyQuad(IUniswapV4StandardExchangeCurveQuadStableDETF detf) internal {
        address hook_ = detf.reserveHook();
        require(hook_ != address(0), "reserveHook");
        _openAllPairs(hook_, productTokensQuad(detf));
        finalizeHook(hook_);
        detf.completeReserveBondNft();
        detf.completeReserveClaim();
    }

    function _orbitalTokens(IUniswapV4StandardExchangeOrbitalDETF detf)
        private
        view
        returns (address[] memory tokens)
    {
        tokens = new address[](3);
        uint8 detfIdx_ = detf.detfBindingIndex();
        uint8[2] memory rem_;
        uint256 k_;
        for (uint8 i; i < 3; ++i) {
            if (i != detfIdx_) rem_[k_++] = i;
        }
        tokens[detfIdx_] = address(detf);
        tokens[rem_[0]] = detf.pairToken0();
        tokens[rem_[1]] = detf.pairToken1();
    }

    function _openAllPairs(address hook, address[] memory tokens) private {
        uint256 n_ = tokens.length;
        for (uint256 i; i < n_; ++i) {
            for (uint256 j = i + 1; j < n_; ++j) {
                openProductPair(hook, tokens[i], tokens[j]);
            }
        }
    }

    function _sort(address[] memory a) private pure {
        uint256 n = a.length;
        for (uint256 i = 1; i < n; ++i) {
            address key = a[i];
            uint256 j = i;
            while (j > 0 && a[j - 1] > key) {
                a[j] = a[j - 1];
                unchecked {
                    --j;
                }
            }
            a[j] = key;
        }
    }
}
