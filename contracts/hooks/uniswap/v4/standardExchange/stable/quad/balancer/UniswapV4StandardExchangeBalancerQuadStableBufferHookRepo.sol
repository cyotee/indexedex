// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo
 * @notice Diamond storage: 2–5 token binding, optional SE/RP per leg, dual scales, kLast, lock.
 * @dev Slot: indexedex.hooks.uv4.se.balancer.stable.quad.buffer.storage.v2
 *      LP ERC-20 uses shared ERC20Repo; vaultTokens use MultiAssetBasicVaultRepo.
 *      Live inventory (D21): raw = face balanceOf(hook) (donations dilute LP);
 *      SE legs = SE share balanceOf(hook). Free pair on SE legs is never book.
 *      rawReserves[i] = intentional raw book for free-pretransfer gate only
 *      (free_raw = bal - rawReserves; inventory cannot fund pretransfer).
 *      kLast = SE-valued StableMath invariant / active token count, with native inventory fee checkpoints.
 */
library UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256("indexedex.hooks.uv4.se.balancer.stable.quad.buffer.storage.v2")) - 1)
    ) & ~bytes32(uint256(0xff));

    uint256 internal constant MIN_TOKENS = 2;
    uint256 internal constant MAX_TOKENS = 5;
    uint256 internal constant MINIMUM_LIQUIDITY = 1000;
    uint256 internal constant FEE_DENOMINATOR = 100_000;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant AMP_PRECISION = 1e3;
    uint256 internal constant MAX_AMP = 50_000;
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
        address[] tokens;
        address[] standardExchanges;
        address[] rateProviders;
        /// @dev Inventory scale: 10^(36 - invDecimals). Pair native and SE shares both use pair decimals
        ///      (Univ3/V4/ERC4626 first mint is `shares = assets` in pair units, not vault decimals()).
        uint256[] invScales;
        /// @dev Rated scale: always 10^(36 - pairToken.decimals()).
        uint256[] ratedScales;
        uint8[] pairDecimals;
        uint8[] invDecimals;
        /// @dev Raw-leg inventory baseline; on SE legs, recorded retained pair-token balance.
        uint256[] rawReserves;
        /// @dev Appended: true after finalizeInitialization (I8). Defaults false.
        bool initializationFinalized;
        /// @dev Native inventory at the last fee checkpoint, revalued at current SE rates when charging growth.
        uint256[] feeReserves;
        uint256 liquidityValueBefore;
        uint256 liquiditySupplyBefore;
        uint256[] liquidityValuesBefore;
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
        address[] memory ses_,
        address[] memory rps_,
        uint256 baseAmp_,
        uint256[] memory invScales_,
        uint256[] memory ratedScales_,
        uint8[] memory pairDecimals_,
        uint8[] memory invDecimals_
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
        l.rawReserves = new uint256[](tokens_.length);
        l.bindingsInitialized = true;
        l.reentrancyStatus = NOT_ENTERED;
    }

    function _indexOf(Layout storage l, address token) internal view returns (uint8) {
        for (uint8 i; i < l.tokens.length; ++i) {
            if (l.tokens[i] == token) return i;
        }
        revert("token");
    }

    function _numTokens() internal view returns (uint256) {
        return _layout().tokens.length;
    }

    function _lock(Layout storage l) internal {
        require(l.reentrancyStatus != ENTERED, "REENTRANCY");
        l.reentrancyStatus = ENTERED;
    }

    function _unlock(Layout storage l) internal {
        l.reentrancyStatus = NOT_ENTERED;
    }
}
