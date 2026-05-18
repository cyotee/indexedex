// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";

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
        SingleVaultDetfRepo.Storage storage layout = SingleVaultDetfRepo._layout();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        if (_isWethToken(layout, tokenIn) && _isRichToken(layout, tokenOut)) {
            return layout.wethRichVault.previewExchangeIn(tokenIn, amountIn, tokenOut);
        }

        if (_isRichToken(layout, tokenIn) && _isWethToken(layout, tokenOut)) {
            return layout.wethRichVault.previewExchangeIn(tokenIn, amountIn, tokenOut);
        }

        if (_isWethToken(layout, tokenIn) && _isRichirToken(tokenOut)) {
            uint256 vaultSharesOut =
                layout.wethRichVault.previewExchangeIn(layout.wethToken, amountIn, IERC20(address(layout.wethRichVault)));
            uint256 bptOut = _previewBptOutForAddLiquidity(layout, 0, vaultSharesOut);
            return _previewRichirMintForBpt(layout, bptOut);
        }

        if (_isRichToken(layout, tokenIn) && _isRichirToken(tokenOut)) {
            uint256 wethAmount = layout.wethRichVault.previewExchangeIn(layout.richToken, amountIn, layout.wethToken);
            uint256 vaultSharesOut =
                layout.wethRichVault.previewExchangeIn(layout.wethToken, wethAmount, IERC20(address(layout.wethRichVault)));
            uint256 bptOut = _previewBptOutForAddLiquidity(layout, 0, vaultSharesOut);
            return _previewRichirMintForBpt(layout, bptOut);
        }

        if (address(tokenIn) == layout.reservePool && _isWethToken(layout, tokenOut)) {
            (, uint256 vaultSharesOut) = _previewReservePoolExitProportional(layout, amountIn);
            return layout.wethRichVault.previewExchangeIn(IERC20(address(layout.wethRichVault)), vaultSharesOut, layout.wethToken);
        }

        if (address(tokenIn) == layout.reservePool && _isRichToken(layout, tokenOut)) {
            (, uint256 vaultSharesOut) = _previewReservePoolExitProportional(layout, amountIn);
            return layout.wethRichVault.previewExchangeIn(IERC20(address(layout.wethRichVault)), vaultSharesOut, layout.richToken);
        }

        if (_isChirToken(tokenIn) && _isWethToken(layout, tokenOut)) {
            uint256 reserveSpotPrice = _calcReserveSpotPrice();
            if (!_isBurningAllowed(layout, reserveSpotPrice)) {
                revert BurningNotAllowed(reserveSpotPrice, layout.burnThreshold);
            }

            uint256 bptIn = _previewChirRedemptionBptIn(amountIn);
            (, uint256 vaultSharesOut) = _previewReservePoolExitProportional(layout, bptIn);
            return layout.wethRichVault.previewExchangeIn(IERC20(address(layout.wethRichVault)), vaultSharesOut, layout.wethToken);
        }

        if (_isRichirToken(tokenIn) && _isWethToken(layout, tokenOut)) {
            uint256 bptIn = _previewRichirRedemptionBptIn(layout, amountIn);
            uint256 vaultSharesOut = _previewVaultTokenOutForBptIn(layout, bptIn);
            return layout.wethRichVault.previewExchangeIn(IERC20(address(layout.wethRichVault)), vaultSharesOut, layout.wethToken);
        }

        revert IStandardExchangeIn.ExchangeInNotAvailable();
    }

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        SingleVaultDetfRepo.Storage storage layout = SingleVaultDetfRepo._layout();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        if (_isWethToken(layout, tokenIn) && _isRichToken(layout, tokenOut)) {
            return layout.wethRichVault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        }

        if (_isRichToken(layout, tokenIn) && _isWethToken(layout, tokenOut)) {
            return layout.wethRichVault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        }

        if (_isChirToken(tokenIn) && _isWethToken(layout, tokenOut)) {
            uint256 reserveSpotPrice = _calcReserveSpotPrice();
            if (!_isBurningAllowed(layout, reserveSpotPrice)) {
                revert BurningNotAllowed(reserveSpotPrice, layout.burnThreshold);
            }

            uint256 vaultSharesNeeded =
                layout.wethRichVault.previewExchangeOut(IERC20(address(layout.wethRichVault)), layout.wethToken, amountOut);
            return _previewChirRedemptionAmountForVaultSharesOut(layout, vaultSharesNeeded);
        }

        if (_isRichirToken(tokenIn) && _isWethToken(layout, tokenOut)) {
            return _previewRichirToWethExact(layout, amountOut);
        }

        revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }

    function mintWithWeth(uint256 wethAmount_, address, bool) external view returns (uint256 chirMinted_) {
        if (wethAmount_ == 0) {
            revert ZeroAmount();
        }

        SingleVaultDetfRepo.Storage storage layout = SingleVaultDetfRepo._layout();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        uint256 reserveSpotPrice = _calcReserveSpotPrice();
        if (!_isMintingAllowed(layout, reserveSpotPrice)) {
            revert MintingNotAllowed(reserveSpotPrice, layout.mintThreshold);
        }

        uint256 vaultSharesOut =
            layout.wethRichVault.previewExchangeIn(layout.wethToken, wethAmount_, IERC20(address(layout.wethRichVault)));
        chirMinted_ = _calcProportionalChirForVaultShares(layout, vaultSharesOut);
    }

    function previewClaimLiquidity(uint256 lpAmount_) external view returns (uint256 wethOut_) {
        SingleVaultDetfRepo.Storage storage layout = SingleVaultDetfRepo._layout();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        (, uint256 vaultSharesOut) = _previewReservePoolExitProportional(layout, lpAmount_);
        wethOut_ = layout.wethRichVault.previewExchangeIn(IERC20(address(layout.wethRichVault)), vaultSharesOut, layout.wethToken);
    }

    function previewBridgeRichir(uint256 targetChainId_, uint256 richirAmount_)
        external
        view
        returns (IProtocolDETF.BridgeQuote memory quote_)
    {
        SingleVaultDetfRepo.Storage storage layout = SingleVaultDetfRepo._layout();
        ProtocolDETFSuperchainBridgeRepo.Storage storage bridgeLayout = ProtocolDETFSuperchainBridgeRepo._layout();

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

        (IERC20 remoteRichToken,) = bridgeLayout.bridgeTokenRegistry.getRemoteTokenAndLimit(targetChainId_, layout.richToken);
        if (address(remoteRichToken) == address(0)) {
            revert BridgeRemoteTokenNotConfigured(targetChainId_, layout.richToken);
        }

        if (richirAmount_ == 0) {
            return quote_;
        }

        quote_.richirAmountIn = richirAmount_;
        quote_.sharesBurned = layout._richirToken().convertToShares(richirAmount_);
        if (quote_.sharesBurned == 0) {
            return quote_;
        }

        uint256 totalRichirShares = layout._richirToken().totalShares();
        uint256 protocolNftBpt = layout.protocolNFTVault.originalSharesOf(layout.protocolNFTId);
        if (totalRichirShares == 0 || protocolNftBpt == 0) {
            return quote_;
        }

        quote_.reserveSharesBurned = quote_.sharesBurned * protocolNftBpt / totalRichirShares;
        (uint256 chirAmountOut, uint256 vaultSharesOut) = _previewReservePoolExitProportional(layout, quote_.reserveSharesBurned);

        if (chirAmountOut > 0) {
            uint256 localBptOut = _previewBptOutForAddLiquidity(layout, chirAmountOut, 0);
            quote_.localRichirOut = _previewRichirMintForBpt(layout, localBptOut);
        }

        if (vaultSharesOut > 0) {
            quote_.richOut = layout.wethRichVault.previewExchangeIn(
                IERC20(address(layout.wethRichVault)),
                vaultSharesOut,
                layout.richToken
            );
        }
    }

    function reserveOfToken(address token_) external view returns (uint256 reserve_) {
        if (token_ == address(ERC4626Repo._reserveAsset())) {
            return IERC20(token_).balanceOf(address(this));
        }
        return 0;
    }

    function reserves() external view returns (uint256[] memory reserves_) {
        reserves_ = new uint256[](1);
        reserves_[0] = IERC20(address(ERC4626Repo._reserveAsset())).balanceOf(address(this));
    }

    function vaultTokens() external view returns (address[] memory tokens_) {
        tokens_ = new address[](1);
        tokens_[0] = address(ERC4626Repo._reserveAsset());
    }
}