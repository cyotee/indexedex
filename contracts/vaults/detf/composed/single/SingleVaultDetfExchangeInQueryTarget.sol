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
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {ISingleVaultDetf} from "contracts/interfaces/ISingleVaultDetf.sol";
import {SingleVaultDetfCommon} from "contracts/vaults/detf/composed/single/SingleVaultDetfCommon.sol";
import {SingleVaultDetfRepo} from "contracts/vaults/detf/composed/single/SingleVaultDetfRepo.sol";
import {ProtocolDETFSuperchainBridgeRepo} from "contracts/vaults/protocol/ProtocolDETFSuperchainBridgeRepo.sol";

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

        if (_isWethToken(layoutStruct, tokenIn) && _isRichToken(layoutStruct, tokenOut)) {
            return layoutStruct.wethRichVault.previewExchangeIn(tokenIn, amountIn, tokenOut);
        }

        if (_isRichToken(layoutStruct, tokenIn) && _isWethToken(layoutStruct, tokenOut)) {
            return layoutStruct.wethRichVault.previewExchangeIn(tokenIn, amountIn, tokenOut);
        }

        if (_isWethToken(layoutStruct, tokenIn) && _isRichirToken(tokenOut)) {
            uint256 vaultSharesOut =
                layoutStruct.wethRichVault.previewExchangeIn(layoutStruct.wethToken, amountIn, IERC20(address(layoutStruct.wethRichVault)));
            uint256 bptOut = _previewBptOutForAddLiquidity(layoutStruct, 0, vaultSharesOut);
            return _previewRichirMintForBpt(layoutStruct, bptOut);
        }

        if (_isRichToken(layoutStruct, tokenIn) && _isRichirToken(tokenOut)) {
            uint256 wethAmount = layoutStruct.wethRichVault.previewExchangeIn(layoutStruct.richToken, amountIn, layoutStruct.wethToken);
            uint256 vaultSharesOut =
                layoutStruct.wethRichVault.previewExchangeIn(layoutStruct.wethToken, wethAmount, IERC20(address(layoutStruct.wethRichVault)));
            uint256 bptOut = _previewBptOutForAddLiquidity(layoutStruct, 0, vaultSharesOut);
            return _previewRichirMintForBpt(layoutStruct, bptOut);
        }

        if (address(tokenIn) == layoutStruct.reservePool && _isWethToken(layoutStruct, tokenOut)) {
            (, uint256 vaultSharesOut) = _previewReservePoolExitProportional(layoutStruct, amountIn);
            return layoutStruct.wethRichVault.previewExchangeIn(IERC20(address(layoutStruct.wethRichVault)), vaultSharesOut, layoutStruct.wethToken);
        }

        if (address(tokenIn) == layoutStruct.reservePool && _isRichToken(layoutStruct, tokenOut)) {
            (, uint256 vaultSharesOut) = _previewReservePoolExitProportional(layoutStruct, amountIn);
            return layoutStruct.wethRichVault.previewExchangeIn(IERC20(address(layoutStruct.wethRichVault)), vaultSharesOut, layoutStruct.richToken);
        }

        if (_isChirToken(tokenIn) && _isWethToken(layoutStruct, tokenOut)) {
            uint256 reserveSpotPrice = _calcReserveSpotPrice();
            if (!_isBurningAllowed(layoutStruct, reserveSpotPrice)) {
                revert BurningNotAllowed(reserveSpotPrice, layoutStruct.burnThreshold);
            }

            uint256 bptIn = _previewChirRedemptionBptIn(amountIn);
            (, uint256 vaultSharesOut) = _previewReservePoolExitProportional(layoutStruct, bptIn);
            return layoutStruct.wethRichVault.previewExchangeIn(IERC20(address(layoutStruct.wethRichVault)), vaultSharesOut, layoutStruct.wethToken);
        }

        if (_isRichirToken(tokenIn) && _isWethToken(layoutStruct, tokenOut)) {
            uint256 bptIn = _previewRichirRedemptionBptIn(layoutStruct, amountIn);
            uint256 vaultSharesOut = _previewVaultTokenOutForBptIn(layoutStruct, bptIn);
            return layoutStruct.wethRichVault.previewExchangeIn(IERC20(address(layoutStruct.wethRichVault)), vaultSharesOut, layoutStruct.wethToken);
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

        if (_isWethToken(layoutStruct, tokenIn) && _isRichToken(layoutStruct, tokenOut)) {
            return layoutStruct.wethRichVault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        }

        if (_isRichToken(layoutStruct, tokenIn) && _isWethToken(layoutStruct, tokenOut)) {
            return layoutStruct.wethRichVault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        }

        if (_isChirToken(tokenIn) && _isWethToken(layoutStruct, tokenOut)) {
            uint256 reserveSpotPrice = _calcReserveSpotPrice();
            if (!_isBurningAllowed(layoutStruct, reserveSpotPrice)) {
                revert BurningNotAllowed(reserveSpotPrice, layoutStruct.burnThreshold);
            }

            uint256 vaultSharesNeeded =
                layoutStruct.wethRichVault.previewExchangeOut(IERC20(address(layoutStruct.wethRichVault)), layoutStruct.wethToken, amountOut);
            return _previewChirRedemptionAmountForVaultSharesOut(layoutStruct, vaultSharesNeeded);
        }

        if (_isRichirToken(tokenIn) && _isWethToken(layoutStruct, tokenOut)) {
            return _previewRichirToWethExact(layoutStruct, amountOut);
        }

        revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }

    function mintWithWeth(uint256 wethAmount_, address, bool) external view returns (uint256 chirMinted_) {
        if (wethAmount_ == 0) {
            revert ZeroAmount();
        }

        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        uint256 reserveSpotPrice = _calcReserveSpotPrice();
        if (!_isMintingAllowed(layoutStruct, reserveSpotPrice)) {
            revert MintingNotAllowed(reserveSpotPrice, layoutStruct.mintThreshold);
        }

        uint256 vaultSharesOut =
            layoutStruct.wethRichVault.previewExchangeIn(layoutStruct.wethToken, wethAmount_, IERC20(address(layoutStruct.wethRichVault)));
        chirMinted_ = _splitMintedChir(layoutStruct, _calcProportionalChirForVaultShares(layoutStruct, vaultSharesOut)).userChir;
    }

    function previewClaimLiquidity(uint256 lpAmount_) external view returns (uint256 wethOut_) {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        (, uint256 vaultSharesOut) = _previewReservePoolExitProportional(layoutStruct, lpAmount_);
        wethOut_ = layoutStruct.wethRichVault.previewExchangeIn(IERC20(address(layoutStruct.wethRichVault)), vaultSharesOut, layoutStruct.wethToken);
    }

    function previewBridgeRichir(uint256 targetChainId_, uint256 richirAmount_)
        external
        view
        returns (IProtocolDETF.BridgeQuote memory quote_)
    {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        ProtocolDETFSuperchainBridgeRepo.Storage storage bridgeLayout = ProtocolDETFSuperchainBridgeRepo._layoutStruct();

        if (
            address(bridgeLayout.messenger) == address(0)
                || address(bridgeLayout.standardBridge) == address(0)
                || address(bridgeLayout.bridgeTokenRegistry) == address(0)
        ) {
            revert BridgeConfigNotSet();
        }

        ProtocolDETFSuperchainBridgeRepo.PeerConfig memory peer = bridgeLayout.peers[targetChainId_];
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

        (IERC20 remoteRichToken,) = bridgeLayout.bridgeTokenRegistry.getRemoteTokenAndLimit(targetChainId_, layoutStruct.richToken);
        if (address(remoteRichToken) == address(0)) {
            revert BridgeRemoteTokenNotConfigured(targetChainId_, layoutStruct.richToken);
        }

        if (richirAmount_ == 0) {
            return quote_;
        }

        quote_.richirAmountIn = richirAmount_;
        quote_.sharesBurned = layoutStruct._richirToken().convertToShares(richirAmount_);
        if (quote_.sharesBurned == 0) {
            return quote_;
        }

        uint256 totalRichirShares = layoutStruct._richirToken().totalShares();
        uint256 protocolNftBpt = layoutStruct.protocolNFTVault.originalSharesOf(layoutStruct.protocolNFTId);
        if (totalRichirShares == 0 || protocolNftBpt == 0) {
            return quote_;
        }

        quote_.reserveSharesBurned = quote_.sharesBurned * protocolNftBpt / totalRichirShares;
        (uint256 chirAmountOut, uint256 vaultSharesOut) = _previewReservePoolExitProportional(layoutStruct, quote_.reserveSharesBurned);

        if (chirAmountOut > 0) {
            uint256 localBptOut = _previewBptOutForAddLiquidity(layoutStruct, chirAmountOut, 0);
            quote_.localRichirOut = _previewRichirMintForBpt(layoutStruct, localBptOut);
        }

        if (vaultSharesOut > 0) {
            quote_.richOut = layoutStruct.wethRichVault.previewExchangeIn(
                IERC20(address(layoutStruct.wethRichVault)),
                vaultSharesOut,
                layoutStruct.richToken
            );
        }
    }

    function reserveOfToken(address token_) external view returns (uint256 reserve_) {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (token_ == layoutStruct.reservePool) {
            return IERC20(token_).balanceOf(address(this));
        }
        return 0;
    }

    function reserves() external view returns (uint256[] memory reserves_) {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        reserves_ = new uint256[](1);
        reserves_[0] = IERC20(layoutStruct.reservePool).balanceOf(address(this));
    }

    function vaultTokens() external view returns (address[] memory tokens_) {
        tokens_ = new address[](1);
        tokens_[0] = SingleVaultDetfRepo._layoutStruct().reservePool;
    }
}