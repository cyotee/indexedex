// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {TokenInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IRICHIR} from "contracts/interfaces/IRICHIR.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {DETFPreviewLib} from "contracts/vaults/detf/core/DETFPreviewLib.sol";
import {BaseDualSelfCommonDETFRepo} from "contracts/vaults/protocol/BaseDualSelfCommonDETFRepo.sol";
import {BaseDualSelfCommonDETFCommon} from "contracts/vaults/protocol/BaseDualSelfCommonDETFCommon.sol";
import {DualSelfCommonDETFSuperchainBridgeRepo} from "contracts/vaults/protocol/DualSelfCommonDETFSuperchainBridgeRepo.sol";
import {
    BalancerV38020WeightedPoolMath
} from "contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol";
import {BaseDualSelfCommonDETFPreviewHelpers} from "contracts/vaults/protocol/BaseDualSelfCommonDETFPreviewHelpers.sol";
import {BalancerV3VaultAwareRepo} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {
    PREVIEW_BUFFER_DENOMINATOR,
    PREVIEW_RICHIR_BUFFER_BPS,
    PREVIEW_BPT_BUFFER_DENOMINATOR,
    PREVIEW_BPT_BUFFER_BPS
} from "contracts/constants/Indexedex_CONSTANTS.sol";

/**
 * @title BaseDualSelfCommonDETFBondingQueryTarget
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice View-only query functions for Protocol DETF bonding operations.
 * @dev Split from BaseDualSelfCommonDETFBondingTarget to meet EIP-170 contract size limit.
 *      Contains all view/getter functions while the bonding target retains
 *      state-changing functions.
 */
contract BaseDualSelfCommonDETFBondingQueryTarget is BaseDualSelfCommonDETFCommon {
    using BaseDualSelfCommonDETFRepo for BaseDualSelfCommonDETFRepo.Storage;

    /* ---------------------------------------------------------------------- */
    /*                              View Functions                            */
    /* ---------------------------------------------------------------------- */

    function syntheticPrice() external view returns (uint256) {
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct = BaseDualSelfCommonDETFRepo._layoutStruct();
        return _currentSyntheticPrice(layoutStruct);
    }

    function isMintingAllowed() external view returns (bool) {
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct = BaseDualSelfCommonDETFRepo._layoutStruct();
        return _currentMintingAllowed(layoutStruct);
    }

    function isBurningAllowed() external view returns (bool) {
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct = BaseDualSelfCommonDETFRepo._layoutStruct();
        return _currentBurningAllowed(layoutStruct);
    }

    /* ---------------------------------------------------------------------- */
    /*                           IProtocolDETF Views                          */
    /* ---------------------------------------------------------------------- */

    function chirWethVault() external view returns (IStandardExchange chirWethVault_) {
        chirWethVault_ = BaseDualSelfCommonDETFRepo._layoutStruct().chirWethVault;
    }

    function richChirVault() external view returns (IStandardExchange richChirVault_) {
        richChirVault_ = BaseDualSelfCommonDETFRepo._layoutStruct().richChirVault;
    }

    function reservePool() external view returns (address reservePool_) {
        reservePool_ = address(ERC4626Repo._reserveAsset());
    }

    function protocolNFTVault() external view returns (IProtocolNFTVault protocolNFTVault_) {
        protocolNFTVault_ = BaseDualSelfCommonDETFRepo._layoutStruct().protocolNFTVault;
    }

    function bondNftVault() external view returns (address bondNftVault_) {
        bondNftVault_ = address(BaseDualSelfCommonDETFRepo._layoutStruct().protocolNFTVault);
    }

    function richToken() external view returns (IERC20 richToken_) {
        richToken_ = BaseDualSelfCommonDETFRepo._layoutStruct().richToken;
    }

    function richirToken() external view returns (IERC20 richirToken_) {
        richirToken_ = IERC20(address(BaseDualSelfCommonDETFRepo._layoutStruct().richirToken));
    }

    function rebasingDetfToken() external view returns (address rebasingDetfToken_) {
        rebasingDetfToken_ = address(BaseDualSelfCommonDETFRepo._layoutStruct().richirToken);
    }

    function chirToken() external view returns (IERC20MintBurn chirToken_) {
        chirToken_ = IERC20MintBurn(address(this));
    }

    function protocolNFTId() external view returns (uint256 protocolNFTId_) {
        protocolNFTId_ = BaseDualSelfCommonDETFRepo._layoutStruct().protocolNFTId;
    }

    function mintThreshold() external view returns (uint256 mintThreshold_) {
        mintThreshold_ = BaseDualSelfCommonDETFRepo._layoutStruct().mintThreshold;
    }

    function burnThreshold() external view returns (uint256 burnThreshold_) {
        burnThreshold_ = BaseDualSelfCommonDETFRepo._layoutStruct().burnThreshold;
    }

    function wethToken() external view returns (IERC20 wethToken_) {
        wethToken_ = BaseDualSelfCommonDETFRepo._layoutStruct().wethToken;
    }

    /* ---------------------------------------------------------------------- */
    /*                          Liquidity Preview                             */
    /* ---------------------------------------------------------------------- */

    function previewClaimLiquidity(uint256 lpAmount) external view returns (uint256 wethOut) {
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct = BaseDualSelfCommonDETFRepo._layoutStruct();
        (address poolAddr, uint256 lpOut) = _previewClaimLiquidityLpOut(layoutStruct, lpAmount);
        wethOut = _previewWethOutFromAerodromeLp(poolAddr, lpOut, address(layoutStruct.wethToken));
    }

    function previewRebasingDetfTokenReserveBpt(uint256 rebasingDetfAmount)
        external
        view
        returns (uint256 reserveBptAmount)
    {
        if (rebasingDetfAmount == 0) {
            return 0;
        }

        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct = BaseDualSelfCommonDETFRepo._layoutStruct();
        IRICHIR richirToken_ = layoutStruct.richirToken;
        IProtocolNFTVault protocolNFTVault_ = layoutStruct.protocolNFTVault;

        if (address(richirToken_) == address(0) || address(protocolNFTVault_) == address(0)) {
            return 0;
        }

        uint256 richirShares = richirToken_.convertToShares(rebasingDetfAmount);
        uint256 totalRichirShares = richirToken_.totalShares();
        uint256 protocolReserveBpt = protocolNFTVault_.originalSharesOf(layoutStruct.protocolNFTId);

        if (richirShares == 0 || totalRichirShares == 0 || protocolReserveBpt == 0) {
            return 0;
        }

        reserveBptAmount = (richirShares * protocolReserveBpt) / totalRichirShares;
    }

    function previewRebasingDetfTokenEthValue(uint256 reserveBptAmount) external view returns (uint256 wethValue) {
        if (reserveBptAmount == 0) {
            return 0;
        }

        wethValue = IProtocolDETF(address(this)).previewClaimLiquidity(reserveBptAmount);
    }

    function previewBridgeRichir(uint256 targetChainId, uint256 richirAmount)
        external
        view
        returns (IProtocolDETF.BridgeQuote memory quote)
    {
        quote = _previewBridgeRichirQuote(BaseDualSelfCommonDETFRepo._layoutStruct(), targetChainId, richirAmount);
    }

    function _previewWethOutFromAerodromeLp(address poolAddr, uint256 lpOut, address wethToken_)
        internal
        view
        virtual
        returns (uint256 wethOut)
    {
        if (lpOut == 0) {
            return 0;
        }

        IPool pool = IPool(poolAddr);
        (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
        uint256 totalSupply = IERC20(poolAddr).totalSupply();
        if (totalSupply == 0) {
            return 0;
        }

        uint256 amount0 = (lpOut * reserve0) / totalSupply;
        uint256 amount1 = (lpOut * reserve1) / totalSupply;

        if (pool.token0() == wethToken_) {
            wethOut = amount0;
        } else if (pool.token1() == wethToken_) {
            wethOut = amount1;
        }
    }

    // Note: token-specific RICH/WETH -> RICHIR preview functions were removed.
    // Use IStandardExchangeIn(address(this)).previewExchangeIn(tokenIn, amountIn, richirToken).
}
