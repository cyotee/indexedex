// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title UniswapV4OrbitalSwapHookRepo
 * @notice Diamond storage for orbital hook: bindings, reserves, R, L², kLast, lock.
 * @dev Slot: indexedex.hooks.uv4.orbital.swap.storage
 *      LP ERC-20 uses shared ERC20Repo; vaultTokens/reserves use MultiAssetBasicVaultRepo.
 *      Bindings written in package initAccount — no constructor immutables.
 */
library UniswapV4OrbitalSwapHookRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256("indexedex.hooks.uv4.orbital.swap.storage")) - 1)
    ) & ~bytes32(uint256(0xff));

    uint256 internal constant MINIMUM_LIQUIDITY = 1000;
    uint256 internal constant R_SAFETY_MULTIPLIER = 10;
    uint256 internal constant FEE_DENOMINATOR = 100_000;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant NOT_ENTERED = 1;
    uint256 internal constant ENTERED = 2;

    /// @dev KLastMode: 0 = FullProduct, 1 = SumInterim (matches IUniswapV4OrbitalSwapHook.KLastMode)
    struct Layout {
        // --- bindings (immortal instance identity) ---
        address poolManager;
        address feeOracle;
        address token0;
        address token1;
        address token2;
        uint8 decimals0;
        uint8 decimals1;
        uint8 decimals2;
        bool bindingsInitialized;
        // --- pool ensure process args (not in salt) ---
        int24 tickSpacing;
        uint160 sqrtPriceX96;
        // --- sphere book ---
        uint256 R;
        mapping(address => uint256) reserves;
        uint256 L_SQUARED;
        uint256 kLast;
        uint8 kLastMode;
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
        address token0_,
        address token1_,
        address token2_,
        uint8 d0,
        uint8 d1,
        uint8 d2,
        int24 tickSpacing_,
        uint160 sqrtPriceX96_
    ) internal {
        Layout storage l = _layout();
        require(!l.bindingsInitialized, "bound");
        l.poolManager = poolManager_;
        l.feeOracle = feeOracle_;
        l.token0 = token0_;
        l.token1 = token1_;
        l.token2 = token2_;
        l.decimals0 = d0;
        l.decimals1 = d1;
        l.decimals2 = d2;
        l.tickSpacing = tickSpacing_;
        l.sqrtPriceX96 = sqrtPriceX96_;
        l.bindingsInitialized = true;
        l.reentrancyStatus = NOT_ENTERED;
    }
}
