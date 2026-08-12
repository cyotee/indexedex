// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ROBINHOOD_MAIN} from "@crane/contracts/constants/networks/ROBINHOOD_MAIN.sol";

/// @title RobinhoodCanonicalLib
/// @notice Thin accessors + pin checks for Robinhood mainnet (chain 4663) Uni cores.
/// @dev Scripts must never redeploy PoolManager / Uni V3 factory when forked RH has code.
library RobinhoodCanonicalLib {
    function chainId() internal pure returns (uint256) {
        return ROBINHOOD_MAIN.CHAIN_ID;
    }

    function defaultForkBlock() internal pure returns (uint256) {
        return ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK;
    }

    function poolManager() internal pure returns (address) {
        return ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER;
    }

    function positionManagerV4() internal pure returns (address) {
        return ROBINHOOD_MAIN.UNISWAP_V4_POSITION_MANAGER;
    }

    function v3Factory() internal pure returns (address) {
        return ROBINHOOD_MAIN.UNISWAP_V3_FACTORY;
    }

    function v3Npm() internal pure returns (address) {
        return ROBINHOOD_MAIN.UNISWAP_V3_NFT_POSITION_MANAGER;
    }

    function v3SwapRouter() internal pure returns (address) {
        return ROBINHOOD_MAIN.UNISWAP_V3_SWAP_ROUTER02;
    }

    function permit2() internal pure returns (address) {
        return ROBINHOOD_MAIN.PERMIT2;
    }

    function weth() internal pure returns (address) {
        return address(ROBINHOOD_MAIN.WETH);
    }

    function universalRouter() internal pure returns (address) {
        return ROBINHOOD_MAIN.UNISWAP_UNIVERSAL_ROUTER;
    }

    /// @notice Revert if required RH externals lack bytecode on the fork.
    function requireCanonicalPins() internal view {
        require(poolManager().code.length > 0, "RH pin: UNISWAP_V4_POOL_MANAGER missing code");
        require(v3Factory().code.length > 0, "RH pin: UNISWAP_V3_FACTORY missing code");
        require(v3Npm().code.length > 0, "RH pin: UNISWAP_V3_NFT_POSITION_MANAGER missing code");
        require(permit2().code.length > 0, "RH pin: PERMIT2 missing code");
        require(weth().code.length > 0, "RH pin: WETH missing code");
        require(universalRouter().code.length > 0, "RH pin: UNISWAP_UNIVERSAL_ROUTER missing code");
        require(positionManagerV4().code.length > 0, "RH pin: UNISWAP_V4_POSITION_MANAGER missing code");
    }
}
