// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title UniswapV4SingleStandardExchangeBufferConstantProductHookRepo
 * @notice Diamond storage for single SE buffer constant-product hook.
 * @dev Bindings live in storage (diamond package); not constructor immutables.
 */
library UniswapV4SingleStandardExchangeBufferConstantProductHookRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256("indexedex.hooks.uv4.single.se.buffer.constant.product.storage")) - 1)
    ) & ~bytes32(uint256(0xff));

    uint256 internal constant MINIMUM_LIQUIDITY = 1000;
    uint256 internal constant MAX_DUST_WEI = 10;
    uint256 internal constant TRADING_FEE_PERCENT = 300;
    uint256 internal constant TRADING_FEE_DENOMINATOR = 100_000;
    uint256 internal constant NOT_ENTERED = 1;
    uint256 internal constant ENTERED = 2;

    struct Layout {
        // --- bindings (product-specific; LP ERC-20 + vault accounting use shared repos) ---
        address poolManager;
        address feeOracle;
        address standardExchange;
        address pairToken;
        address rawToken;
        address currency0;
        address currency1;
        uint8 decimalsCurrency0;
        uint8 decimalsCurrency1;
        bool bindingsInitialized;
        // --- AMM ---
        uint256 kLast;
        bool poolInitialized;
        uint256 reentrancyStatus;
    }

    function _layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    function _initializeBindings(
        address poolManager_,
        address feeOracle_,
        address se_,
        address pairToken_,
        address rawToken_,
        address currency0_,
        address currency1_,
        uint8 dec0,
        uint8 dec1
    ) internal {
        Layout storage l = _layout();
        require(!l.bindingsInitialized, "bound");
        l.poolManager = poolManager_;
        l.feeOracle = feeOracle_;
        l.standardExchange = se_;
        l.pairToken = pairToken_;
        l.rawToken = rawToken_;
        l.currency0 = currency0_;
        l.currency1 = currency1_;
        l.decimalsCurrency0 = dec0;
        l.decimalsCurrency1 = dec1;
        l.bindingsInitialized = true;
        l.reentrancyStatus = NOT_ENTERED;
    }
}
