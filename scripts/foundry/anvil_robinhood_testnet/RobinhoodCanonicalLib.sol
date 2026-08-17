// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ROBINHOOD_TESTNET} from "@crane/contracts/constants/networks/ROBINHOOD_TESTNET.sol";

/// @title RobinhoodCanonicalLib
/// @notice Pins for Robinhood Chain Testnet (46630). Uni V3 / pons / USDG are absent.
library RobinhoodCanonicalLib {
    function chainId() internal pure returns (uint256) {
        return ROBINHOOD_TESTNET.CHAIN_ID;
    }

    function poolManager() internal pure returns (address) {
        return ROBINHOOD_TESTNET.UNISWAP_V4_POOL_MANAGER;
    }

    function positionManagerV4() internal pure returns (address) {
        return ROBINHOOD_TESTNET.UNISWAP_V4_POSITION_MANAGER;
    }

    function permit2() internal pure returns (address) {
        return ROBINHOOD_TESTNET.PERMIT2;
    }

    function weth() internal pure returns (address) {
        return address(ROBINHOOD_TESTNET.WETH);
    }

    function universalRouter() internal pure returns (address) {
        return ROBINHOOD_TESTNET.UNISWAP_UNIVERSAL_ROUTER;
    }

    /// @notice Required live pins only. Does not require Uni V3 or pons.
    function requireCanonicalPins() internal view {
        require(poolManager().code.length > 0, "RH testnet pin: UNISWAP_V4_POOL_MANAGER missing code");
        require(positionManagerV4().code.length > 0, "RH testnet pin: UNISWAP_V4_POSITION_MANAGER missing code");
        require(permit2().code.length > 0, "RH testnet pin: PERMIT2 missing code");
        require(weth().code.length > 0, "RH testnet pin: WETH missing code");
        require(universalRouter().code.length > 0, "RH testnet pin: UNISWAP_UNIVERSAL_ROUTER missing code");
    }
}
