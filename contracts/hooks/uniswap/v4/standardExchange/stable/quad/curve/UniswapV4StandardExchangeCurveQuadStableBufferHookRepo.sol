// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title UniswapV4StandardExchangeCurveQuadStableBufferHookRepo
 * @notice Diamond storage: 4-token binding, optional SE/RP per leg, dual scales, kLast, lock.
 * @dev Slot: indexedex.hooks.uv4.se.stable.quad.buffer.storage
 *      LP ERC-20 uses shared ERC20Repo; vaultTokens use MultiAssetBasicVaultRepo.
 *      Live inventory (D21): raw = face balanceOf(hook) (donations dilute LP);
 *      SE legs = SE share balanceOf(hook). Free pair on SE legs is never book.
 *      rawReserves[i] = intentional raw book for free-pretransfer gate only
 *      (free_raw = bal - rawReserves; inventory cannot fund pretransfer).
 *      I1 freeze: kLast = geometricMean4(invWad0..3).
 */
library UniswapV4StandardExchangeCurveQuadStableBufferHookRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256("indexedex.hooks.uv4.se.stable.quad.buffer.storage")) - 1)
    ) & ~bytes32(uint256(0xff));

    uint256 internal constant N_TOKENS = 4;
    uint256 internal constant MINIMUM_LIQUIDITY = 1000;
    uint256 internal constant FEE_DENOMINATOR = 100_000;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant AMP_PRECISION = 100;
    uint256 internal constant MAX_AMP = 1_000_000;
    uint256 internal constant MAX_DUST_WEI = 10;
    uint256 internal constant NOT_ENTERED = 1;
    uint256 internal constant ENTERED = 2;
    int24 internal constant TICK_SPACING = 1;

    struct Layout {
        address poolManager;
        address feeOracle;
        bool bindingsInitialized;
        uint256 kLast;
        uint256 reentrancyStatus;
        uint256 baseAmp;
        address[4] tokens;
        address[4] standardExchanges;
        address[4] rateProviders;
        /// @dev Inventory scale: 10^(36 - invDecimals); raw = pair decimals; SE = share decimals.
        uint256[4] invScales;
        /// @dev Rated scale: always 10^(36 - pairToken.decimals()).
        uint256[4] ratedScales;
        uint8[4] pairDecimals;
        uint8[4] invDecimals;
        /// @dev Intentional raw face inventory for raw legs only (buffered legs stay 0).
        uint256[4] rawReserves;
        /// @dev Append-only: set by finalizeInitialization after all six product doors are live.
        bool initializationFinalized;
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
        address[4] memory tokens_,
        address[4] memory ses_,
        address[4] memory rps_,
        uint256 baseAmp_,
        uint256[4] memory invScales_,
        uint256[4] memory ratedScales_,
        uint8[4] memory pairDecimals_,
        uint8[4] memory invDecimals_
    ) internal {
        Layout storage l = _layout();
        require(!l.bindingsInitialized, "bound");
        l.poolManager = poolManager_;
        l.feeOracle = feeOracle_;
        l.baseAmp = baseAmp_;
        l.tokens = tokens_;
        l.standardExchanges = ses_;
        l.rateProviders = rps_;
        l.invScales = invScales_;
        l.ratedScales = ratedScales_;
        l.pairDecimals = pairDecimals_;
        l.invDecimals = invDecimals_;
        l.bindingsInitialized = true;
        l.reentrancyStatus = NOT_ENTERED;
    }

    function _indexOf(Layout storage l, address token) internal view returns (uint8) {
        for (uint8 i; i < N_TOKENS; ++i) {
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
