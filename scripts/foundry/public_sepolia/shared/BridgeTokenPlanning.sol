// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library BridgeTokenPlanning {
    uint256 internal constant SOURCE_CHAIN_ID = 11155111;
    uint256 internal constant DESTINATION_CHAIN_ID = 84532;
    uint32 internal constant BRIDGE_MIN_GAS_LIMIT = 200_000;

    uint256 internal constant INITIAL_LIQUIDITY = 10_000e18;
    uint256 internal constant UNBALANCED_RATIO_B = 1_000e18;
    uint256 internal constant UNBALANCED_RATIO_C = 100e18;

    uint256 internal constant INITIAL_UNDERLYING = 10_000e18;
    uint256 internal constant VAULT_ASSET_DEPOSIT = 30_000e18;

    uint256 internal constant INITIAL_PROTOCOL_WETH_DEPOSIT = 10e18;

    string internal constant BASE_NAME_SUFFIX = " (Base Sepolia)";
    string internal constant BASE_SYMBOL_SUFFIX = ".base";

    function wrappedName(string memory sourceName) internal pure returns (string memory) {
        return string.concat(sourceName, BASE_NAME_SUFFIX);
    }

    function wrappedSymbol(string memory sourceSymbol) internal pure returns (string memory) {
        return string.concat(sourceSymbol, BASE_SYMBOL_SUFFIX);
    }

    function bridgeAmountTTA() internal pure returns (uint256) {
        return _stage10AmountTTA() + _stage13UnderlyingAmountPerToken() + _stage13VaultAssetAmountTTA();
    }

    function bridgeAmountTTB() internal pure returns (uint256) {
        return _stage10AmountTTB() + _stage13UnderlyingAmountPerToken() + _stage13VaultAssetAmountTTB();
    }

    function bridgeAmountTTC() internal pure returns (uint256) {
        return _stage10AmountTTC() + _stage13UnderlyingAmountPerToken() + _stage13VaultAssetAmountTTC();
    }

    function bridgeAmountDemoWeth() internal pure returns (uint256) {
        return INITIAL_PROTOCOL_WETH_DEPOSIT;
    }

    function _stage10AmountTTA() private pure returns (uint256) {
        return 6 * INITIAL_LIQUIDITY;
    }

    function _stage10AmountTTB() private pure returns (uint256) {
        return 6 * INITIAL_LIQUIDITY;
    }

    function _stage10AmountTTC() private pure returns (uint256) {
        return 3 * (UNBALANCED_RATIO_B + UNBALANCED_RATIO_C);
    }

    function _stage13UnderlyingAmountPerToken() private pure returns (uint256) {
        return 4 * INITIAL_UNDERLYING;
    }

    function _stage13VaultAssetAmountTTA() private pure returns (uint256) {
        return 2 * (
            _requiredUnderlying(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY)
                + _requiredUnderlying(INITIAL_LIQUIDITY, UNBALANCED_RATIO_B)
        );
    }

    function _stage13VaultAssetAmountTTB() private pure returns (uint256) {
        return 2 * (
            _requiredUnderlying(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY)
                + _requiredUnderlying(INITIAL_LIQUIDITY, UNBALANCED_RATIO_C)
        );
    }

    function _stage13VaultAssetAmountTTC() private pure returns (uint256) {
        return 2 * (
            _requiredUnderlying(UNBALANCED_RATIO_B, INITIAL_LIQUIDITY)
                + _requiredUnderlying(UNBALANCED_RATIO_C, INITIAL_LIQUIDITY)
        );
    }

    function _requiredUnderlying(uint256 reserveToken, uint256 reservePaired) private pure returns (uint256) {
        uint256 totalSupply = _sqrt(reserveToken * reservePaired);
        return _ceilDiv(VAULT_ASSET_DEPOSIT * reserveToken, totalSupply);
    }

    function _ceilDiv(uint256 numerator, uint256 denominator) private pure returns (uint256) {
        return numerator == 0 ? 0 : ((numerator - 1) / denominator) + 1;
    }

    function _sqrt(uint256 x) private pure returns (uint256 result) {
        if (x == 0) return 0;

        uint256 z = (x + 1) / 2;
        result = x;

        while (z < result) {
            result = z;
            z = (x / z + z) / 2;
        }
    }
}