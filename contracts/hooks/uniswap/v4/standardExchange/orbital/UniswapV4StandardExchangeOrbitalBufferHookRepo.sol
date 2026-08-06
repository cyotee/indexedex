// SPDX-License-Identifier: BUSL-1.1
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
        address se0_,
        address se1_,
        address se2_,
        address rp0_,
        address rp1_,
        address rp2_,
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
        l.se0 = se0_;
        l.se1 = se1_;
        l.se2 = se2_;
        l.rp0 = rp0_;
        l.rp1 = rp1_;
        l.rp2 = rp2_;
        l.decimals0 = d0;
        l.decimals1 = d1;
        l.decimals2 = d2;
        l.tickSpacing = tickSpacing_;
        l.sqrtPriceX96 = sqrtPriceX96_;
        l.bindingsInitialized = true;
        l.reentrancyStatus = NOT_ENTERED;
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
