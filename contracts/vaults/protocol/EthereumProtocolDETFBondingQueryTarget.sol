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
import {DETFPreviewLib} from "contracts/vaults/detf/core/DETFPreviewLib.sol";
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

    function syntheticPrice() external view returns (uint256) {
        BaseProtocolDETFRepo.Storage storage layoutStruct = BaseProtocolDETFRepo._layoutStruct();
        return _currentSyntheticPrice(layoutStruct);
    }

    function isMintingAllowed() external view returns (bool) {
        BaseProtocolDETFRepo.Storage storage layoutStruct = BaseProtocolDETFRepo._layoutStruct();
        return _currentMintingAllowed(layoutStruct);
    }

    function isBurningAllowed() external view returns (bool) {
        BaseProtocolDETFRepo.Storage storage layoutStruct = BaseProtocolDETFRepo._layoutStruct();
        return _currentBurningAllowed(layoutStruct);
    }

    function chirWethVault() external view returns (IStandardExchange chirWethVault_) {
        chirWethVault_ = BaseProtocolDETFRepo._layoutStruct().chirWethVault;
    }

    function richChirVault() external view returns (IStandardExchange richChirVault_) {
        richChirVault_ = BaseProtocolDETFRepo._layoutStruct().richChirVault;
    }

    function reservePool() external view returns (address reservePool_) {
        reservePool_ = address(ERC4626Repo._reserveAsset());
    }

    function protocolNFTVault() external view returns (IProtocolNFTVault protocolNFTVault_) {
        protocolNFTVault_ = BaseProtocolDETFRepo._layoutStruct().protocolNFTVault;
    }

    function richToken() external view returns (IERC20 richToken_) {
        richToken_ = BaseProtocolDETFRepo._layoutStruct().richToken;
    }

    function richirToken() external view returns (IERC20 richirToken_) {
        richirToken_ = IERC20(address(BaseProtocolDETFRepo._layoutStruct().richirToken));
    }

    function chirToken() external view returns (IERC20MintBurn chirToken_) {
        chirToken_ = IERC20MintBurn(address(this));
    }

    function protocolNFTId() external view returns (uint256 protocolNFTId_) {
        protocolNFTId_ = BaseProtocolDETFRepo._layoutStruct().protocolNFTId;
    }

    function mintThreshold() external view returns (uint256 mintThreshold_) {
        mintThreshold_ = BaseProtocolDETFRepo._layoutStruct().mintThreshold;
    }

    function burnThreshold() external view returns (uint256 burnThreshold_) {
        burnThreshold_ = BaseProtocolDETFRepo._layoutStruct().burnThreshold;
    }

    function wethToken() external view returns (IERC20 wethToken_) {
        wethToken_ = BaseProtocolDETFRepo._layoutStruct().wethToken;
    }

    function previewClaimLiquidity(uint256 lpAmount) external view returns (uint256 wethOut) {
        BaseProtocolDETFRepo.Storage storage layoutStruct = BaseProtocolDETFRepo._layoutStruct();
        (address poolAddr, uint256 lpOut) = _previewClaimLiquidityLpOut(layoutStruct, lpAmount);
        wethOut = _previewWethOutFromUniV2Lp(poolAddr, lpOut, address(layoutStruct.wethToken));
    }

    function previewBridgeRichir(uint256 targetChainId, uint256 richirAmount)
        external
        view
        returns (IProtocolDETF.BridgeQuote memory quote)
    {
        quote = _previewBridgeRichirQuote(BaseProtocolDETFRepo._layoutStruct(), targetChainId, richirAmount);
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