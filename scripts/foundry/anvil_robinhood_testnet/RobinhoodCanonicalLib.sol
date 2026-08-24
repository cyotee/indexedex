// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ROBINHOOD_TESTNET} from "@crane/contracts/constants/networks/ROBINHOOD_TESTNET.sol";

/// @title RobinhoodCanonicalLib
/// @notice Live-46630 pin getters: Uni V4 cores, Permit2, WETH only.
/// @dev Morpho / Uni V3 live addresses come from Phase 01 JSON, not main CREATE2 dumps.
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

    function quoter() internal pure returns (address) {
        return ROBINHOOD_TESTNET.UNISWAP_V4_QUOTER;
    }

    function stateView() internal pure returns (address) {
        return ROBINHOOD_TESTNET.UNISWAP_V4_STATE_VIEW;
    }

    /// @dev Other-tree / future-constants accessors. 46630 Phase 01 JSON must not write these
    ///      when they have no code. Sibling `anvil_robinhood_fee_detf` still reads them.
    function v3Factory() internal pure returns (address) {
        return ROBINHOOD_TESTNET.UNISWAP_V3_FACTORY;
    }

    function morpho() internal pure returns (address) {
        return ROBINHOOD_TESTNET.MORPHO;
    }

    function morphoIrm() internal pure returns (address) {
        return ROBINHOOD_TESTNET.MORPHO_ADAPTIVE_CURVE_IRM;
    }

    function morphoOracleFactory() internal pure returns (address) {
        return ROBINHOOD_TESTNET.MORPHO_CHAINLINK_ORACLE_V2_FACTORY;
    }

    function morphoVaultV2Factory() internal pure returns (address) {
        return ROBINHOOD_TESTNET.MORPHO_VAULT_V2_FACTORY;
    }

    function morphoRegistry() internal pure returns (address) {
        return ROBINHOOD_TESTNET.MORPHO_REGISTRY;
    }

    function morphoBundler3() internal pure returns (address) {
        return ROBINHOOD_TESTNET.MORPHO_BUNDLER3;
    }

    function morphoVaultV1AdapterFactory() internal pure returns (address) {
        return ROBINHOOD_TESTNET.MORPHO_VAULT_V1_ADAPTER_FACTORY;
    }

    function morphoMarketV1AdapterV2Factory() internal pure returns (address) {
        return ROBINHOOD_TESTNET.MORPHO_MARKET_V1_ADAPTER_V2_FACTORY;
    }

    function morphoGeneralAdapter1() internal pure returns (address) {
        return ROBINHOOD_TESTNET.MORPHO_GENERAL_ADAPTER_1;
    }

    /// @notice Required live 46630 pins only. Does not require Uni V3, pons, Morpho, or Balancer.
    function requireCanonicalPins() internal view {
        require(poolManager().code.length > 0, "RH testnet pin: UNISWAP_V4_POOL_MANAGER missing code");
        require(positionManagerV4().code.length > 0, "RH testnet pin: UNISWAP_V4_POSITION_MANAGER missing code");
        require(permit2().code.length > 0, "RH testnet pin: PERMIT2 missing code");
        require(weth().code.length > 0, "RH testnet pin: WETH missing code");
        require(universalRouter().code.length > 0, "RH testnet pin: UNISWAP_UNIVERSAL_ROUTER missing code");
    }
}
