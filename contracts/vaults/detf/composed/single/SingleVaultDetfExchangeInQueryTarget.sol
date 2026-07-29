// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {DetfSuperchainBridgeRepo} from "contracts/vaults/detf/DetfSuperchainBridgeRepo.sol";
import {SingleVaultDetfCommon} from "contracts/vaults/detf/composed/single/SingleVaultDetfCommon.sol";
import {SingleVaultDetfRepo} from "contracts/vaults/detf/composed/single/SingleVaultDetfRepo.sol";

contract SingleVaultDetfExchangeInQueryTarget is SingleVaultDetfCommon {
    using SingleVaultDetfRepo for SingleVaultDetfRepo.Storage;

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        if (_isRateAsset(layoutStruct, tokenIn) && _isPairToken(layoutStruct, tokenOut)) {
            return layoutStruct.underlyingVault.previewExchangeIn(tokenIn, amountIn, tokenOut);
        }

        if (_isPairToken(layoutStruct, tokenIn) && _isRateAsset(layoutStruct, tokenOut)) {
            return layoutStruct.underlyingVault.previewExchangeIn(tokenIn, amountIn, tokenOut);
        }

        if (_isRateAsset(layoutStruct, tokenIn) && _isRebasingClaimToken(tokenOut)) {
            uint256 vaultSharesOut =
                layoutStruct.underlyingVault.previewExchangeIn(layoutStruct.rateAsset, amountIn, IERC20(address(layoutStruct.underlyingVault)));
            uint256 bptOut = _previewBptOutForAddLiquidity(layoutStruct, 0, vaultSharesOut);
            return _previewRebasingClaimMintForBpt(layoutStruct, bptOut);
        }

        if (_isPairToken(layoutStruct, tokenIn) && _isRebasingClaimToken(tokenOut)) {
            uint256 wethAmount = layoutStruct.underlyingVault.previewExchangeIn(layoutStruct.pairToken, amountIn, layoutStruct.rateAsset);
            uint256 vaultSharesOut =
                layoutStruct.underlyingVault.previewExchangeIn(layoutStruct.rateAsset, wethAmount, IERC20(address(layoutStruct.underlyingVault)));
            uint256 bptOut = _previewBptOutForAddLiquidity(layoutStruct, 0, vaultSharesOut);
            return _previewRebasingClaimMintForBpt(layoutStruct, bptOut);
        }

        if (address(tokenIn) == layoutStruct.reservePool && _isRateAsset(layoutStruct, tokenOut)) {
            (, uint256 vaultSharesOut) = _previewReservePoolExitProportional(layoutStruct, amountIn);
            return layoutStruct.underlyingVault.previewExchangeIn(IERC20(address(layoutStruct.underlyingVault)), vaultSharesOut, layoutStruct.rateAsset);
        }

        if (address(tokenIn) == layoutStruct.reservePool && _isPairToken(layoutStruct, tokenOut)) {
            (, uint256 vaultSharesOut) = _previewReservePoolExitProportional(layoutStruct, amountIn);
            return layoutStruct.underlyingVault.previewExchangeIn(IERC20(address(layoutStruct.underlyingVault)), vaultSharesOut, layoutStruct.pairToken);
        }

        if (_isDetfToken(tokenIn) && _isRateAsset(layoutStruct, tokenOut)) {
            uint256 syntheticPrice = _calcSyntheticPrice();
            if (!_isBurningAllowed(layoutStruct, syntheticPrice)) {
                revert BurningNotAllowed(syntheticPrice, layoutStruct.burnThreshold);
            }

            uint256 bptIn = _previewDetfRedemptionBptIn(amountIn);
            (, uint256 vaultSharesOut) = _previewReservePoolExitProportional(layoutStruct, bptIn);
            return layoutStruct.underlyingVault.previewExchangeIn(IERC20(address(layoutStruct.underlyingVault)), vaultSharesOut, layoutStruct.rateAsset);
        }

        if (_isRebasingClaimToken(tokenIn) && _isRateAsset(layoutStruct, tokenOut)) {
            uint256 bptIn = _previewRebasingClaimRedemptionBptIn(layoutStruct, amountIn);
            uint256 vaultSharesOut = _previewVaultTokenOutForBptIn(layoutStruct, bptIn);
            return layoutStruct.underlyingVault.previewExchangeIn(IERC20(address(layoutStruct.underlyingVault)), vaultSharesOut, layoutStruct.rateAsset);
        }

        revert IStandardExchangeIn.ExchangeInNotAvailable();
    }

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        if (_isRateAsset(layoutStruct, tokenIn) && _isPairToken(layoutStruct, tokenOut)) {
            return layoutStruct.underlyingVault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        }

        if (_isPairToken(layoutStruct, tokenIn) && _isRateAsset(layoutStruct, tokenOut)) {
            return layoutStruct.underlyingVault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        }

        if (_isDetfToken(tokenIn) && _isRateAsset(layoutStruct, tokenOut)) {
            uint256 syntheticPrice = _calcSyntheticPrice();
            if (!_isBurningAllowed(layoutStruct, syntheticPrice)) {
                revert BurningNotAllowed(syntheticPrice, layoutStruct.burnThreshold);
            }

            uint256 vaultSharesNeeded =
                layoutStruct.underlyingVault.previewExchangeOut(IERC20(address(layoutStruct.underlyingVault)), layoutStruct.rateAsset, amountOut);
            return _previewDetfRedemptionAmountForVaultSharesOut(layoutStruct, vaultSharesNeeded);
        }

        if (_isRebasingClaimToken(tokenIn) && _isRateAsset(layoutStruct, tokenOut)) {
            return _previewRebasingClaimToRateAssetExact(layoutStruct, amountOut);
        }

        revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }

    function previewClaimLiquidity(uint256 lpAmount_) external view returns (uint256 wethOut_) {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        (, uint256 vaultSharesOut) = _previewReservePoolExitProportional(layoutStruct, lpAmount_);
        wethOut_ = layoutStruct.underlyingVault.previewExchangeIn(IERC20(address(layoutStruct.underlyingVault)), vaultSharesOut, layoutStruct.rateAsset);
    }

    function previewBridgeRebasingClaim(uint256 targetChainId_, uint256 rebasingClaimAmount_)
        external
        view
        returns (IProtocolDETF.BridgeQuote memory quote_)
    {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        DetfSuperchainBridgeRepo.Storage storage bridgeLayout = DetfSuperchainBridgeRepo._layoutStruct();

        if (
            address(bridgeLayout.messenger) == address(0)
                || address(bridgeLayout.standardBridge) == address(0)
                || address(bridgeLayout.bridgeTokenRegistry) == address(0)
        ) {
            revert BridgeConfigNotSet();
        }

        DetfSuperchainBridgeRepo.PeerConfig memory peer = bridgeLayout.peers[targetChainId_];
        if (peer.relayer == address(0)) {
            peer.relayer = bridgeLayout.defaultPeerRelayer;
        }
        if (peer.relayer == address(0)) {
            revert BridgePeerNotConfigured(targetChainId_);
        }

        IERC20 remoteDetf = bridgeLayout.bridgeTokenRegistry.getRemoteToken(targetChainId_, IERC20(address(this)));
        if (address(remoteDetf) == address(0)) {
            revert BridgeRemoteTokenNotConfigured(targetChainId_, IERC20(address(this)));
        }

        (IERC20 remotePairToken,) = bridgeLayout.bridgeTokenRegistry.getRemoteTokenAndLimit(targetChainId_, layoutStruct.pairToken);
        if (address(remotePairToken) == address(0)) {
            revert BridgeRemoteTokenNotConfigured(targetChainId_, layoutStruct.pairToken);
        }

        if (rebasingClaimAmount_ == 0) {
            return quote_;
        }

        quote_.rebasingClaimAmountIn = rebasingClaimAmount_;
        quote_.sharesBurned = layoutStruct._rebasingClaimToken().convertToShares(rebasingClaimAmount_);
        if (quote_.sharesBurned == 0) {
            return quote_;
        }

        uint256 totalRebasingClaimShares = layoutStruct._rebasingClaimToken().totalShares();
        uint256 protocolNftBpt = layoutStruct.detfNFTVault.originalSharesOf(layoutStruct.detfNFTId);
        if (totalRebasingClaimShares == 0 || protocolNftBpt == 0) {
            return quote_;
        }

        quote_.reserveSharesBurned = quote_.sharesBurned * protocolNftBpt / totalRebasingClaimShares;
        (uint256 detfAmountOut, uint256 vaultSharesOut) = _previewReservePoolExitProportional(layoutStruct, quote_.reserveSharesBurned);

        if (detfAmountOut > 0) {
            uint256 localBptOut = _previewBptOutForAddLiquidity(layoutStruct, detfAmountOut, 0);
            quote_.localRebasingClaimOut = _previewRebasingClaimMintForBpt(layoutStruct, localBptOut);
        }

        if (vaultSharesOut > 0) {
            quote_.pairOut = layoutStruct.underlyingVault.previewExchangeIn(
                IERC20(address(layoutStruct.underlyingVault)),
                vaultSharesOut,
                layoutStruct.pairToken
            );
        }
    }

}