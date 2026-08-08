// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title UniswapV4CurveQuadStableSwapHookRepo
 * @notice Diamond storage: bindings, rate-scaled book, reentrancy.
 * @dev Slot: indexedex.hooks.uv4.stable.quad.storage
 *      LP ERC-20 uses shared ERC20Repo; vaultTokens/reserves use MultiAssetBasicVaultRepo.
 *      Bindings written in package initAccount — no constructor immutables.
 */
library UniswapV4CurveQuadStableSwapHookRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256("indexedex.hooks.uv4.stable.quad.storage")) - 1)
    ) & ~bytes32(uint256(0xff));

    uint256 internal constant NOT_ENTERED = 1;
    uint256 internal constant ENTERED = 2;

    struct Layout {
        // --- bindings (immortal instance identity) ---
        address poolManager;
        address token0;
        address token1;
        address token2;
        address token3;
        uint24 lpFeePips;
        uint256 baseAmp;
        address rateProvider0;
        address rateProvider1;
        address rateProvider2;
        address rateProvider3;
        uint8 decimals0;
        uint8 decimals1;
        uint8 decimals2;
        uint8 decimals3;
        uint256 baseScale0;
        uint256 baseScale1;
        uint256 baseScale2;
        uint256 baseScale3;
        bool bindingsInitialized;
        // --- product book (raw face amounts) ---
        uint256[4] reserves;
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
        address token0_,
        address token1_,
        address token2_,
        address token3_,
        uint24 lpFeePips_,
        uint256 baseAmp_,
        address[4] memory rateProviders_,
        uint8[4] memory decimals_,
        uint256[4] memory baseScales_
    ) internal {
        Layout storage l = _layout();
        require(!l.bindingsInitialized, "bound");
        l.poolManager = poolManager_;
        l.token0 = token0_;
        l.token1 = token1_;
        l.token2 = token2_;
        l.token3 = token3_;
        l.lpFeePips = lpFeePips_;
        l.baseAmp = baseAmp_;
        l.rateProvider0 = rateProviders_[0];
        l.rateProvider1 = rateProviders_[1];
        l.rateProvider2 = rateProviders_[2];
        l.rateProvider3 = rateProviders_[3];
        l.decimals0 = decimals_[0];
        l.decimals1 = decimals_[1];
        l.decimals2 = decimals_[2];
        l.decimals3 = decimals_[3];
        l.baseScale0 = baseScales_[0];
        l.baseScale1 = baseScales_[1];
        l.baseScale2 = baseScales_[2];
        l.baseScale3 = baseScales_[3];
        l.bindingsInitialized = true;
        l.reentrancyStatus = NOT_ENTERED;
    }
}
