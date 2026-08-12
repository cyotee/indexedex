// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title UniswapV4DualStandardExchangeBufferConstantProductHookRepo
 * @notice Diamond storage for dual SE buffer CP hook (bindings + kLast + one-pool + reentrancy).
 * @dev LP ERC-20 uses shared ERC20Repo; vault tokens/reserves use MultiAssetBasicVaultRepo.
 *      Bindings live in storage (diamond package) — not constructor immutables.
 */
library UniswapV4DualStandardExchangeBufferConstantProductHookRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256("indexedex.hooks.uv4.dual.se.buffer.constant.product.storage")) - 1)
    ) & ~bytes32(uint256(0xff));

    uint256 internal constant MINIMUM_LIQUIDITY = 1000;
    uint256 internal constant MAX_DUST_WEI = 10;
    uint256 internal constant TRADING_FEE_PERCENT = 300;
    uint256 internal constant TRADING_FEE_DENOMINATOR = 100_000;
    uint256 internal constant NOT_ENTERED = 1;
    uint256 internal constant ENTERED = 2;

    struct Layout {
        // --- bindings (product-specific) ---
        address poolManager;
        address feeOracle;
        address se0;
        address token0;
        address se1;
        address token1;
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
        address se0_,
        address token0_,
        address se1_,
        address token1_,
        address currency0_,
        address currency1_,
        uint8 dec0,
        uint8 dec1
    ) internal {
        Layout storage l = _layout();
        require(!l.bindingsInitialized, "bound");
        l.poolManager = poolManager_;
        l.feeOracle = feeOracle_;
        l.se0 = se0_;
        l.token0 = token0_;
        l.se1 = se1_;
        l.token1 = token1_;
        l.currency0 = currency0_;
        l.currency1 = currency1_;
        l.decimalsCurrency0 = dec0;
        l.decimalsCurrency1 = dec1;
        l.bindingsInitialized = true;
        l.reentrancyStatus = NOT_ENTERED;
    }
}
