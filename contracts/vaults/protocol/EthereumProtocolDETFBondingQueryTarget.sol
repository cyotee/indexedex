// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {TokenInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";
import {EthereumProtocolDETFCommon} from "contracts/vaults/protocol/EthereumProtocolDETFCommon.sol";
import {ProtocolDETFSuperchainBridgeRepo} from "contracts/vaults/protocol/ProtocolDETFSuperchainBridgeRepo.sol";
import {
    BalancerV38020WeightedPoolMath
} from "contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol";
import {BaseProtocolDETFPreviewHelpers} from "contracts/vaults/protocol/BaseProtocolDETFPreviewHelpers.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {BalancerV3VaultAwareRepo} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {
    PREVIEW_BUFFER_DENOMINATOR,
    PREVIEW_RICHIR_BUFFER_BPS,
    PREVIEW_BPT_BUFFER_DENOMINATOR,
    PREVIEW_BPT_BUFFER_BPS
} from "contracts/constants/Indexedex_CONSTANTS.sol";

contract EthereumProtocolDETFBondingQueryTarget is EthereumProtocolDETFCommon {
    using BaseProtocolDETFRepo for BaseProtocolDETFRepo.Storage;

    struct BridgeReservePoolBptPreview {
        uint256[] balancesRaw;
        uint256 bptOut;
        uint256 poolSupply;
        uint256 chirIdx;
        uint256 richIdx;
    }

    function syntheticPrice() external view returns (uint256) {
        BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();
        if (!_isInitialized()) {
            return ONE_WAD;
        }

        PoolReserves memory reserves;
        _loadPoolReserves(layout, reserves);
        return _calcSyntheticPrice(reserves);
    }

    function isMintingAllowed() external view returns (bool) {
        BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();
        if (!_isInitialized()) {
            return false;
        }

        PoolReserves memory reserves;
        _loadPoolReserves(layout, reserves);
        uint256 price = _calcSyntheticPrice(reserves);
        return _isMintingAllowed(layout, price);
    }

    function isBurningAllowed() external view returns (bool) {
        BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();
        if (!_isInitialized()) {
            return false;
        }

        PoolReserves memory reserves;
        _loadPoolReserves(layout, reserves);
        uint256 price = _calcSyntheticPrice(reserves);
        return _isBurningAllowed(layout, price);
    }

    function chirWethVault() external view returns (IStandardExchange chirWethVault_) {
        chirWethVault_ = BaseProtocolDETFRepo._layout().chirWethVault;
    }

    function richChirVault() external view returns (IStandardExchange richChirVault_) {
        richChirVault_ = BaseProtocolDETFRepo._layout().richChirVault;
    }

    function reservePool() external view returns (address reservePool_) {
        reservePool_ = address(ERC4626Repo._reserveAsset());
    }

    function protocolNFTVault() external view returns (IProtocolNFTVault protocolNFTVault_) {
        protocolNFTVault_ = BaseProtocolDETFRepo._layout().protocolNFTVault;
    }

    function richToken() external view returns (IERC20 richToken_) {
        richToken_ = BaseProtocolDETFRepo._layout().richToken;
    }

    function richirToken() external view returns (IERC20 richirToken_) {
        richirToken_ = IERC20(address(BaseProtocolDETFRepo._layout().richirToken));
    }

    function chirToken() external view returns (IERC20MintBurn chirToken_) {
        chirToken_ = IERC20MintBurn(address(this));
    }

    function protocolNFTId() external view returns (uint256 protocolNFTId_) {
        protocolNFTId_ = BaseProtocolDETFRepo._layout().protocolNFTId;
    }

    function mintThreshold() external view returns (uint256 mintThreshold_) {
        mintThreshold_ = BaseProtocolDETFRepo._layout().mintThreshold;
    }

    function burnThreshold() external view returns (uint256 burnThreshold_) {
        burnThreshold_ = BaseProtocolDETFRepo._layout().burnThreshold;
    }

    function wethToken() external view returns (IERC20 wethToken_) {
        wethToken_ = BaseProtocolDETFRepo._layout().wethToken;
    }

    function previewClaimLiquidity(uint256 lpAmount) external view returns (uint256 wethOut) {
        BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        uint256 expectedChirWethVaultOut = _previewChirWethVaultOutRaw(lpAmount);
        address poolAddr = IERC4626(address(layout.chirWethVault)).asset();
        uint256 lpOut = IERC4626(address(layout.chirWethVault)).previewRedeem(expectedChirWethVaultOut);
        wethOut = _previewWethOutFromUniV2Lp(poolAddr, lpOut, address(layout.wethToken));
    }

    function previewBridgeRichir(uint256 targetChainId, uint256 richirAmount)
        external
        view
        returns (IProtocolDETF.BridgeQuote memory quote)
    {
        BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();
        ProtocolDETFSuperchainBridgeRepo.Storage storage bridgeLayout = ProtocolDETFSuperchainBridgeRepo._layout();

        if (
            address(bridgeLayout.messenger) == address(0)
                || address(bridgeLayout.standardBridge) == address(0)
                || address(bridgeLayout.bridgeTokenRegistry) == address(0)
        ) {
            revert BridgeConfigNotSet();
        }

        ProtocolDETFSuperchainBridgeRepo.PeerConfig memory peer = bridgeLayout.peers[targetChainId];
        if (peer.relayer == address(0)) {
            peer.relayer = bridgeLayout.defaultPeerRelayer;
        }
        if (peer.relayer == address(0)) {
            revert BridgePeerNotConfigured(targetChainId);
        }

        IERC20 remoteDetf = bridgeLayout.bridgeTokenRegistry.getRemoteToken(targetChainId, IERC20(address(this)));
        if (address(remoteDetf) == address(0)) {
            revert BridgeRemoteTokenNotConfigured(targetChainId, IERC20(address(this)));
        }

        (IERC20 remoteRichToken,) = bridgeLayout.bridgeTokenRegistry.getRemoteTokenAndLimit(targetChainId, layout.richToken);
        if (address(remoteRichToken) == address(0)) {
            revert BridgeRemoteTokenNotConfigured(targetChainId, layout.richToken);
        }

        if (richirAmount == 0) {
            return quote;
        }

        quote.richirAmountIn = richirAmount;
        quote.sharesBurned = layout.richirToken.convertToShares(richirAmount);
        if (quote.sharesBurned == 0) {
            return quote;
        }

        uint256 totalRichirShares = layout.richirToken.totalShares();
        uint256 protocolNftBpt = layout.protocolNFTVault.originalSharesOf(layout.protocolNFTId);
        quote.reserveSharesBurned = (quote.sharesBurned * protocolNftBpt) / totalRichirShares;

        (uint256 chirWethVaultSharesOut, uint256 richChirVaultSharesOut) =
            _previewReservePoolExit(layout, quote.reserveSharesBurned);

        quote.localRichirOut = _previewLocalRichirCompensation(layout, chirWethVaultSharesOut);
        quote.richOut = layout.richChirVault.previewExchangeIn(
            IERC20(address(layout.richChirVault)), richChirVaultSharesOut, layout.richToken
        );
    }

    function _previewReservePoolExit(BaseProtocolDETFRepo.Storage storage layout_, uint256 bptIn_)
        internal
        view
        returns (uint256 chirWethVaultSharesOut_, uint256 richChirVaultSharesOut_)
    {
        ReservePoolData memory resPoolData;
        uint256[] memory currentBalancesRaw = _loadReservePoolData(resPoolData, new uint256[](0));
        if (resPoolData.resPoolTotalSupply == 0) {
            return (0, 0);
        }

        chirWethVaultSharesOut_ =
            (currentBalancesRaw[layout_.chirWethVaultIndex] * bptIn_) / resPoolData.resPoolTotalSupply;
        richChirVaultSharesOut_ =
            (currentBalancesRaw[layout_.richChirVaultIndex] * bptIn_) / resPoolData.resPoolTotalSupply;
    }

    function _previewLocalRichirCompensation(BaseProtocolDETFRepo.Storage storage layout_, uint256 chirWethVaultShares_)
        internal
        view
        returns (uint256 richirOut_)
    {
        if (chirWethVaultShares_ == 0) {
            return 0;
        }

        BridgeReservePoolBptPreview memory p =
            _previewBridgeReservePoolBptOut(layout_, layout_.chirWethVaultIndex, chirWethVaultShares_);

        ReservePoolData memory resPoolData;
        _loadReservePoolData(resPoolData, new uint256[](0));

        BaseProtocolDETFPreviewHelpers.RichirCalc memory calc = BaseProtocolDETFPreviewHelpers.RichirCalc({
            balV3Vault: address(resPoolData.balV3Vault),
            reservePool: address(resPoolData.reservePool),
            reservePoolSwapFee: resPoolData.reservePoolSwapFee,
            weightsArray: resPoolData.weightsArray,
            chirWethVault: address(layout_.chirWethVault),
            richChirVault: address(layout_.richChirVault),
            chirToken: address(this),
            wethToken: address(layout_.wethToken),
            poolBalsRaw: p.balancesRaw,
            chirIdx: p.chirIdx,
            richIdx: p.richIdx,
            vaultIdx: layout_.chirWethVaultIndex,
            sharesAdded: chirWethVaultShares_,
            poolSupply: p.poolSupply,
            bptAdded: p.bptOut,
            newPosShares: layout_.protocolNFTVault.getPosition(layout_.protocolNFTId).originalShares + p.bptOut,
            newTotShares: layout_.richirToken.totalShares() + p.bptOut
        });

        richirOut_ = BaseProtocolDETFPreviewHelpers.computeRichirOutFromDeposit(calc);
        richirOut_ = richirOut_ - ((richirOut_ * PREVIEW_RICHIR_BUFFER_BPS) / PREVIEW_BUFFER_DENOMINATOR);
    }

    function _previewBridgeReservePoolBptOut(
        BaseProtocolDETFRepo.Storage storage,
        uint256 vaultIndex_,
        uint256 vaultShares_
    ) internal view returns (BridgeReservePoolBptPreview memory p_) {
        ReservePoolData memory resPoolData;
        IVault balV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();
        address pool = address(ERC4626Repo._reserveAsset());
        (, TokenInfo[] memory tokenInfo, uint256[] memory currentBalancesRaw,) = balV3Vault.getPoolTokenInfo(pool);

        _loadReservePoolData(resPoolData, currentBalancesRaw);

        uint256[] memory balancesLiveScaled18 = new uint256[](currentBalancesRaw.length);
        for (uint256 i = 0; i < currentBalancesRaw.length; ++i) {
            balancesLiveScaled18[i] = _toLiveScaled18(currentBalancesRaw[i], tokenInfo[i]);
        }

        uint256 amountInLiveScaled18 = _toLiveScaled18(vaultShares_, tokenInfo[vaultIndex_]);
        uint256 bptOut = BalancerV38020WeightedPoolMath.calcBptOutGivenSingleIn(
            balancesLiveScaled18,
            resPoolData.weightsArray,
            vaultIndex_,
            amountInLiveScaled18,
            resPoolData.resPoolTotalSupply,
            resPoolData.reservePoolSwapFee
        );

        bptOut = bptOut - ((bptOut * PREVIEW_BPT_BUFFER_BPS) / PREVIEW_BPT_BUFFER_DENOMINATOR);

        p_.balancesRaw = currentBalancesRaw;
        p_.bptOut = bptOut;
        p_.poolSupply = resPoolData.resPoolTotalSupply;
        p_.chirIdx = resPoolData.chirWethVaultIndex;
        p_.richIdx = resPoolData.richChirVaultIndex;
    }

    function _previewChirWethVaultOutRaw(uint256 lpAmount) internal view returns (uint256 chirWethVaultOutRaw) {
        ReservePoolData memory resPoolData;
        (TokenInfo[] memory tokenInfo, uint256[] memory currentBalancesRaw) = _loadReservePoolDataWithTokenInfo(resPoolData);
        uint256[] memory balancesLiveScaled18 = new uint256[](currentBalancesRaw.length);
        for (uint256 i = 0; i < currentBalancesRaw.length; ++i) {
            balancesLiveScaled18[i] = _toLiveScaled18(currentBalancesRaw[i], tokenInfo[i]);
        }

        uint256 expectedChirWethVaultOutScaled18 = BalancerV38020WeightedPoolMath.calcSingleOutGivenBptIn(
            balancesLiveScaled18,
            resPoolData.weightsArray,
            resPoolData.chirWethVaultIndex,
            lpAmount,
            resPoolData.resPoolTotalSupply,
            resPoolData.reservePoolSwapFee
        );

        uint256 chirWethRate = FixedPoint.ONE;
        if (address(tokenInfo[resPoolData.chirWethVaultIndex].rateProvider) != address(0)) {
            chirWethRate = tokenInfo[resPoolData.chirWethVaultIndex].rateProvider.getRate();
        }

        chirWethVaultOutRaw = FixedPoint.divDown(expectedChirWethVaultOutScaled18, chirWethRate);
        if (chirWethVaultOutRaw > 0) {
            unchecked {
                chirWethVaultOutRaw = chirWethVaultOutRaw - 1;
            }
        }
    }

    function _previewWethOutFromUniV2Lp(address poolAddr, uint256 lpOut, address wethToken_)
        internal
        view
        returns (uint256 wethOut)
    {
        if (lpOut == 0) {
            return 0;
        }

        IUniswapV2Pair pair = IUniswapV2Pair(poolAddr);
        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
        uint256 totalSupply = IERC20(poolAddr).totalSupply();
        if (totalSupply == 0) {
            return 0;
        }

        uint256 amount0 = (lpOut * reserve0) / totalSupply;
        uint256 amount1 = (lpOut * reserve1) / totalSupply;

        if (pair.token0() == wethToken_) {
            wethOut = amount0;
        } else if (pair.token1() == wethToken_) {
            wethOut = amount1;
        }
    }

}