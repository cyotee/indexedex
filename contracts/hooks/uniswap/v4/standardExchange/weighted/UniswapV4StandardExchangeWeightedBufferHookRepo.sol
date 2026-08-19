// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title UniswapV4StandardExchangeWeightedBufferHookRepo
 * @notice Diamond storage: n∈[2,8] binding, optional SE/RP per leg, inventory scales, kLast, lock.
 * @dev Slot: indexedex.hooks.uv4.se.weighted.buffer.storage
 *      LP ERC-20 uses shared ERC20Repo; vaultTokens use MultiAssetBasicVaultRepo.
 *      Raw-leg intentional inventory in rawReserves[i]; SE-leg book is live SE share balances.
 */
library UniswapV4StandardExchangeWeightedBufferHookRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256("indexedex.hooks.uv4.se.weighted.buffer.storage")) - 1)
    ) & ~bytes32(uint256(0xff));

    uint256 internal constant MINIMUM_LIQUIDITY = 1000;
    uint256 internal constant FEE_DENOMINATOR = 100_000;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant MIN_WEIGHT = 1e16;
    uint256 internal constant MAX_DUST_WEI = 10;
    uint256 internal constant NOT_ENTERED = 1;
    uint256 internal constant ENTERED = 2;
    uint8 internal constant MIN_N = 2;
    uint8 internal constant MAX_N = 8;
    int24 internal constant TICK_SPACING = 1;

    /// @dev KLastMode: 0 = FullProduct, 1 = PartialInterim
    struct Layout {
        address poolManager;
        address feeOracle;
        uint8 numTokens;
        bool bindingsInitialized;
        uint256 kLast;
        uint8 kLastMode;
        uint256 reentrancyStatus;
        address[] tokens;
        uint256[] weights;
        address[] standardExchanges;
        address[] rateProviders;
        /// @dev Inventory scale: 10^(36 - invDecimals); raw = pair decimals; SE = share decimals.
        uint256[] invScales;
        /// @dev Rated scale: always 10^(36 - pairToken.decimals()).
        uint256[] ratedScales;
        uint8[] pairDecimals;
        uint8[] invDecimals;
        /// @dev Intentional raw face inventory for raw legs only (buffered legs stay 0).
        uint256[] rawReserves;
        bool initializationFinalized;
        bool ownerOnlyLiquidity;
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
        address[] memory ses_,
        address[] memory rps_,
        uint256[] memory invScales_,
        uint256[] memory ratedScales_,
        uint8[] memory pairDecimals_,
        uint8[] memory invDecimals_
    ) internal {
        Layout storage l = _layout();
        require(!l.bindingsInitialized, "bound");
        uint8 n = uint8(tokens_.length);
        require(n >= MIN_N && n <= MAX_N, "n");
        l.poolManager = poolManager_;
        l.feeOracle = feeOracle_;
        l.numTokens = n;
        l.tokens = tokens_;
        l.weights = weights_;
        l.standardExchanges = ses_;
        l.rateProviders = rps_;
        l.invScales = invScales_;
        l.ratedScales = ratedScales_;
        l.pairDecimals = pairDecimals_;
        l.invDecimals = invDecimals_;
        l.rawReserves = new uint256[](n);
        l.bindingsInitialized = true;
        l.reentrancyStatus = NOT_ENTERED;
    }

    function _indexOf(Layout storage l, address token) internal view returns (uint8) {
        uint8 n = l.numTokens;
        for (uint8 i; i < n; ++i) {
            if (l.tokens[i] == token) return i;
        }
        revert("token");
    }

    function _lock(Layout storage l) internal {
        require(l.reentrancyStatus != ENTERED, "REENTRANCY");
        l.reentrancyStatus = ENTERED;
    }

    function _unlock(Layout storage l) internal {
        l.reentrancyStatus = NOT_ENTERED;
    }
}
