// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {UniswapV4SingleStandardExchangeBufferPricingHookRepo} from
    "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferPricingHookRepo.sol";
import {UniswapV4SingleStandardExchangeBufferPricingHookTarget} from
    "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferPricingHookTarget.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferPricingHook
 * @notice CREATE3-mined single-contract V4 buffer/pricing hook for Standard Exchange shares.
 * @dev Binding is ctor immutables. wrapZeroForOne stored in Repo only (no public getter).
 */
/// @dev Implements IUniswapV4SingleStandardExchangeBufferPricingHook surface without dual-inheritance override noise.
contract UniswapV4SingleStandardExchangeBufferPricingHook is UniswapV4SingleStandardExchangeBufferPricingHookTarget {
    error ZeroAddress();
    error UnderlyingNotInVaultTokens();

    constructor(IPoolManager poolManager_, address standardExchange_, address underlying_)
        UniswapV4SingleStandardExchangeBufferPricingHookTarget(poolManager_, standardExchange_, underlying_)
    {
        if (address(poolManager_) == address(0) || standardExchange_ == address(0) || underlying_ == address(0)) {
            revert ZeroAddress();
        }
        _requireUnderlyingInVaultTokens(standardExchange_, underlying_);
        // Currency order from address sort (D62); Repo-only (D70/D73)
        bool wrapZFO = underlying_ < standardExchange_;
        UniswapV4SingleStandardExchangeBufferPricingHookRepo._setWrapZeroForOne(wrapZFO);
        Hooks.validateHookPermissions(this, getHookPermissions());
    }

    function _requireUnderlyingInVaultTokens(address se, address underlying_) internal view {
        address[] memory tokens = IBasicVault(se).vaultTokens();
        bool found;
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i] == underlying_) {
                found = true;
                break;
            }
        }
        if (!found) revert UnderlyingNotInVaultTokens();
    }

    /* ---------------------------------------------------------------------- */
    /*                         IUniswapV4SingleStandardExchangeBufferPricingHook                 */
    /* ---------------------------------------------------------------------- */

    function previewWrap(uint256 underlyingIn) external view returns (uint256 seOut) {
        return _previewWrap(underlyingIn);
    }

    function previewWrapExactOut(uint256 seOut) external view returns (uint256 underlyingIn) {
        return _previewWrapExactOut(seOut);
    }

    function previewUnwrap(uint256 seIn) external view returns (uint256 underlyingOut) {
        return _previewUnwrap(seIn);
    }

    function previewUnwrapExactOut(uint256 underlyingOut) external view returns (uint256 seIn) {
        return _previewUnwrapExactOut(underlyingOut);
    }
}
