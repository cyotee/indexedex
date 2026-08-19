// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHookRepo
 * @notice Diamond storage: 3-token binding, optional SE/RP per leg, sphere book, kLast, lock.
 * @dev Slot: indexedex.hooks.uv4.se.orbital.buffer.storage
 *      LP ERC-20 uses shared ERC20Repo; vaultTokens use MultiAssetBasicVaultRepo.
 *      Raw-leg intentional inventory in reserves[token]; SE-leg book is SE share balances.
 */
library UniswapV4StandardExchangeOrbitalBufferHookRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256("indexedex.hooks.uv4.se.orbital.buffer.storage")) - 1)
    ) & ~bytes32(uint256(0xff));

    uint256 internal constant MINIMUM_LIQUIDITY = 1000;
    uint256 internal constant R_SAFETY_MULTIPLIER = 10;
    uint256 internal constant FEE_DENOMINATOR = 100_000;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant MAX_DUST_WEI = 10;
    uint256 internal constant NOT_ENTERED = 1;
    uint256 internal constant ENTERED = 2;

    /// @dev KLastMode: 0 = FullProduct, 1 = SumInterim
    struct Layout {
        address poolManager;
        address feeOracle;
        address token0;
        address token1;
        address token2;
        address se0;
        address se1;
        address se2;
        address rp0;
        address rp1;
        address rp2;
        uint8 decimals0;
        uint8 decimals1;
        uint8 decimals2;
        bool bindingsInitialized;
        int24 tickSpacing;
        uint160 sqrtPriceX96;
        uint256 R;
        /// @dev Intentional raw face inventory for raw legs only (buffered legs stay 0).
        mapping(address => uint256) reserves;
        uint256 L_SQUARED;
        uint256 kLast;
        uint8 kLastMode;
        uint256 reentrancyStatus;
        bool initializationFinalized;
        bool ownerOnlyLiquidity;
    }

    function _layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    /// @dev Packed init bindings (avoids stack-too-deep under legacy codegen without viaIR).
    struct BindingsInit {
        address poolManager;
        address feeOracle;
        address token0;
        address token1;
        address token2;
        address se0;
        address se1;
        address se2;
        address rp0;
        address rp1;
        address rp2;
        uint8 decimals0;
        uint8 decimals1;
        uint8 decimals2;
        int24 tickSpacing;
        uint160 sqrtPriceX96;
        bool ownerOnlyLiquidity;
    }

    function _initializeBindings(BindingsInit memory b) internal {
        Layout storage l = _layout();
        require(!l.bindingsInitialized, "bound");
        l.poolManager = b.poolManager;
        l.feeOracle = b.feeOracle;
        l.token0 = b.token0;
        l.token1 = b.token1;
        l.token2 = b.token2;
        l.se0 = b.se0;
        l.se1 = b.se1;
        l.se2 = b.se2;
        l.rp0 = b.rp0;
        l.rp1 = b.rp1;
        l.rp2 = b.rp2;
        l.decimals0 = b.decimals0;
        l.decimals1 = b.decimals1;
        l.decimals2 = b.decimals2;
        l.tickSpacing = b.tickSpacing;
        l.sqrtPriceX96 = b.sqrtPriceX96;
        l.bindingsInitialized = true;
        l.reentrancyStatus = NOT_ENTERED;
        l.ownerOnlyLiquidity = b.ownerOnlyLiquidity;
    }

    function _tokenAt(Layout storage l, uint8 i) internal view returns (address) {
        if (i == 0) return l.token0;
        if (i == 1) return l.token1;
        if (i == 2) return l.token2;
        revert("idx");
    }

    function _seAt(Layout storage l, uint8 i) internal view returns (address) {
        if (i == 0) return l.se0;
        if (i == 1) return l.se1;
        if (i == 2) return l.se2;
        revert("idx");
    }

    function _rpAt(Layout storage l, uint8 i) internal view returns (address) {
        if (i == 0) return l.rp0;
        if (i == 1) return l.rp1;
        if (i == 2) return l.rp2;
        revert("idx");
    }

    function _decimalsAt(Layout storage l, uint8 i) internal view returns (uint8) {
        if (i == 0) return l.decimals0;
        if (i == 1) return l.decimals1;
        if (i == 2) return l.decimals2;
        revert("idx");
    }

    function _indexOf(Layout storage l, address token) internal view returns (uint8) {
        if (token == l.token0) return 0;
        if (token == l.token1) return 1;
        if (token == l.token2) return 2;
        revert("token");
    }
}
