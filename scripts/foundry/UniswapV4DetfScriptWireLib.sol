// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4DetfHookStagedInitLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4DetfHookStagedInitLib.sol";
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

/// @title UniswapV4DetfScriptWireLib
/// @notice Broadcast-safe door + finalize + two-step wiring. Each `openProductPair` is one TX.
/// @dev Must not call the TestBase-only reserve-ready bundle (one TX).
library UniswapV4DetfScriptWireLib {
    function _wireCp(address detf) internal {
        IUniswapV4SingleStandardExchangeDETF d = IUniswapV4SingleStandardExchangeDETF(detf);
        address hook = d.reserveHook();
        address[] memory tokens = UniswapV4DetfHookStagedInitLib.productTokensCp(d);
        for (uint256 i; i < tokens.length; ++i) {
            for (uint256 j = i + 1; j < tokens.length; ++j) {
                UniswapV4DetfHookStagedInitLib.openProductPair(hook, tokens[i], tokens[j]);
            }
        }
        UniswapV4DetfHookStagedInitLib.finalizeHook(hook);
        d.completeReserveBondNft();
        d.completeReserveClaim();
    }

    function _wireOrbital(address detf) internal {
        IUniswapV4StandardExchangeOrbitalDETF d = IUniswapV4StandardExchangeOrbitalDETF(detf);
        address hook = d.reserveHook();
        address[] memory tokens = UniswapV4DetfHookStagedInitLib.productTokensOrbital(d);
        for (uint256 i; i < tokens.length; ++i) {
            for (uint256 j = i + 1; j < tokens.length; ++j) {
                UniswapV4DetfHookStagedInitLib.openProductPair(hook, tokens[i], tokens[j]);
            }
        }
        UniswapV4DetfHookStagedInitLib.finalizeHook(hook);
        d.completeReserveBondNft();
        d.completeReserveClaim();
    }

    function _wireQuad(address detf) internal {
        IUniswapV4StandardExchangeCurveQuadStableDETF d = IUniswapV4StandardExchangeCurveQuadStableDETF(detf);
        address hook = d.reserveHook();
        address[] memory tokens = UniswapV4DetfHookStagedInitLib.productTokensQuad(d);
        for (uint256 i; i < tokens.length; ++i) {
            for (uint256 j = i + 1; j < tokens.length; ++j) {
                UniswapV4DetfHookStagedInitLib.openProductPair(hook, tokens[i], tokens[j]);
            }
        }
        UniswapV4DetfHookStagedInitLib.finalizeHook(hook);
        d.completeReserveBondNft();
        d.completeReserveClaim();
    }

    function _wireWeighted(address detf) internal {
        IUniswapV4StandardExchangeWeightedDETF d = IUniswapV4StandardExchangeWeightedDETF(detf);
        address hook = d.reserveHook();
        address[] memory tokens = UniswapV4DetfHookStagedInitLib.productTokensWeighted(d);
        for (uint256 i; i < tokens.length; ++i) {
            for (uint256 j = i + 1; j < tokens.length; ++j) {
                UniswapV4DetfHookStagedInitLib.openProductPair(hook, tokens[i], tokens[j]);
            }
        }
        UniswapV4DetfHookStagedInitLib.finalizeHook(hook);
        d.completeReserveBondNft();
        d.completeReserveClaim();
    }
}
