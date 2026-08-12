// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title UniswapV4WeightedSwapHookRepo
 * @notice Diamond storage for weighted hook: bindings, reserves, kLast, lock.
 * @dev Slot: indexedex.hooks.uv4.weighted.swap.storage
 *      LP ERC-20 uses shared ERC20Repo; vaultTokens/reserves use MultiAssetBasicVaultRepo.
 *      Bindings written in package initAccount — no constructor immutables.
 */
library UniswapV4WeightedSwapHookRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256("indexedex.hooks.uv4.weighted.swap.storage")) - 1)
    ) & ~bytes32(uint256(0xff));

    uint256 internal constant NOT_ENTERED = 1;
    uint256 internal constant ENTERED = 2;
    uint256 internal constant FEE_DENOMINATOR = 100_000;
    uint256 internal constant MINIMUM_LIQUIDITY = 1000;

    struct Layout {
        // --- bindings (immortal instance identity) ---
        address poolManager;
        address feeOracle;
        address[] tokens;
        uint256[] weights;
        address[] rateProviders;
        uint256[] baseScales;
        uint8 numTokens;
        bool bindingInitialized;
        // --- pool ensure process args (not in salt) ---
        int24 tickSpacing;
        uint160 sqrtPriceX96;
        // --- book ---
        uint256[] reserves;
        uint256 kLast;
        uint8 kLastMode; // 0 FullProduct, 1 PartialInterim
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
        address[] memory tokens_,
        uint256[] memory weights_,
        address[] memory rateProviders_,
        uint256[] memory baseScales_,
        int24 tickSpacing_,
        uint160 sqrtPriceX96_
    ) internal {
        Layout storage l = _layout();
        require(!l.bindingInitialized, "binding set");
        uint8 n = uint8(tokens_.length);
        l.poolManager = poolManager_;
        l.feeOracle = feeOracle_;
        l.numTokens = n;
        l.tokens = tokens_;
        l.weights = weights_;
        l.rateProviders = rateProviders_;
        l.baseScales = baseScales_;
        l.reserves = new uint256[](n);
        l.tickSpacing = tickSpacing_;
        l.sqrtPriceX96 = sqrtPriceX96_;
        l.bindingInitialized = true;
        l.reentrancyStatus = NOT_ENTERED;
    }
}
