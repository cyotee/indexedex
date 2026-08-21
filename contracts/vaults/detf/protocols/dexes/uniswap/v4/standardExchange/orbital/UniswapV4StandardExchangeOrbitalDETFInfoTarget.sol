// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFCommon
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFCommon.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFRepo.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";

/// @title UniswapV4StandardExchangeOrbitalDETFInfoTarget
/// @notice View/info surface split for runtime size (EIP-170).
/// @dev Does not inherit full IUniswapV4StandardExchangeOrbitalDETF (lifecycle lives on other facet).
abstract contract UniswapV4StandardExchangeOrbitalDETFInfoTarget is UniswapV4StandardExchangeOrbitalDETFCommon {

    function isReserveLive() external view returns (bool) {
        return Repo._layoutStruct().isReserveLive;
    }

    function pairToken0() external view returns (address) {
        return address(Repo._layoutStruct().pairToken0);
    }

    function pairToken1() external view returns (address) {
        return address(Repo._layoutStruct().pairToken1);
    }

    function standardExchange0() external view returns (address) {
        return address(Repo._layoutStruct().standardExchange0);
    }

    function standardExchange1() external view returns (address) {
        return address(Repo._layoutStruct().standardExchange1);
    }

    function vaultShare0() external view returns (address) {
        return address(Repo._layoutStruct().vaultShare0);
    }

    function vaultShare1() external view returns (address) {
        return address(Repo._layoutStruct().vaultShare1);
    }

    function rateProvider0() external view returns (address) {
        return Repo._layoutStruct().rateProvider0;
    }

    function rateProvider1() external view returns (address) {
        return Repo._layoutStruct().rateProvider1;
    }

    function rateAsset() external view returns (address) {
        return address(Repo._layoutStruct().rateAsset);
    }

    function detfBindingIndex() external view returns (uint8) {
        return Repo._layoutStruct().detfBindingIndex;
    }

    function reserveHook() external view returns (address) {
        return Repo._layoutStruct().reserveHook;
    }

    function reservePool() external view returns (address) {
        return Repo._layoutStruct().reserveHook;
    }

    function syntheticPrice() external view returns (uint256) {
        return _syntheticPrice();
    }

    function pendingExpansionDetf() external view returns (uint256) {
        return _previewPendingExpansionMint();
    }

    function mintThreshold() external view returns (uint256) {
        return Repo._layoutStruct().mintThreshold;
    }

    function burnThreshold() external view returns (uint256) {
        return Repo._layoutStruct().burnThreshold;
    }

    function thresholdMode() external view returns (ThresholdMode) {
        return Repo._layoutStruct().thresholdMode;
    }

    function isMintingAllowed() external view returns (bool) {
        return _isMintingAllowed();
    }

    function isBurningAllowed() external view returns (bool) {
        return _isBurningAllowed();
    }

    function bondNftVault() external view returns (address) {
        return address(Repo._layoutStruct().bondNftVault);
    }

    function rebasingClaimToken() external view returns (address) {
        return address(Repo._layoutStruct().rebasingClaimToken);
    }

    function feeRecipientNftId() external view returns (uint256) {
        return Repo._layoutStruct().feeRecipientNftId;
    }

    function creationPair0PerDetfWad() external view returns (uint256) {
        return Repo._layoutStruct().creationPair0PerDetfWad;
    }

    function creationPair1PerDetfWad() external view returns (uint256) {
        return Repo._layoutStruct().creationPair1PerDetfWad;
    }

    function openingPair0PerDetfWad() external view returns (uint256) {
        return Repo._layoutStruct().openingPair0PerDetfWad;
    }

    function openingPair1PerDetfWad() external view returns (uint256) {
        return Repo._layoutStruct().openingPair1PerDetfWad;
    }

    function lastExpansionTimestamp() external view returns (uint256) {
        return Repo._layoutStruct().lastExpansionTimestamp;
    }

    function expansionEpochLength() external view returns (uint256) {
        return Repo._layoutStruct().expansionEpochLength;
    }

    function expansionClosureRatePerYearWad() external view returns (uint256) {
        return Repo._layoutStruct().expansionClosureRatePerYearWad;
    }

    function expansionMaxCatchUpEpochs() external view returns (uint256) {
        return Repo._layoutStruct().expansionMaxCatchUpEpochs;
    }

    function acceptedBondTokens() external view returns (address[] memory tokens_) {
        Repo.Storage storage s = Repo._layoutStruct();
        uint256 n_ = 2;
        if (address(s.vaultShare0) != address(0)) ++n_;
        if (address(s.vaultShare1) != address(0)) ++n_;
        tokens_ = new address[](n_);
        tokens_[0] = address(s.pairToken0);
        tokens_[1] = address(s.pairToken1);
        uint256 i_ = 2;
        if (address(s.vaultShare0) != address(0)) {
            tokens_[i_++] = address(s.vaultShare0);
        }
        if (address(s.vaultShare1) != address(0)) {
            tokens_[i_] = address(s.vaultShare1);
        }
    }

    function protocolLp() external view returns (uint256) {
        return _protocolLp();
    }

    function userBondedLp() external view returns (uint256) {
        return Repo._layoutStruct().userBondedLp;
    }

    function fdRateAssetWad() external view returns (uint256) {
        return _fdRateAssetWad();
    }

    function fdPairsOnlyRateAssetWad() external view returns (uint256) {
        return _fdPairsOnlyRateAssetWad();
    }

    function capitalModeOf(uint256 tokenId_)
        external
        view
        returns (IUniswapV4StandardExchangeOrbitalDETF.CapitalMode)
    {
        return Repo._layoutStruct().capitalOf[tokenId_].mode;
    }

    function capitalToken0Of(uint256 tokenId_) external view returns (address) {
        return Repo._layoutStruct().capitalOf[tokenId_].capitalToken0;
    }

    function capitalToken1Of(uint256 tokenId_) external view returns (address) {
        return Repo._layoutStruct().capitalOf[tokenId_].capitalToken1;
    }

    function isReserveHookFinalized() public view returns (bool) {
        address hook_ = Repo._layoutStruct().reserveHook;
        if (hook_ == address(0)) return false;
        try IUniswapV4HookStagedPairInit(hook_).isInitializationFinalized() returns (bool done_) {
            return done_;
        } catch {
            return true;
        }
    }

    function isReserveWired() public view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        return address(s.bondNftVault) != address(0) && address(s.rebasingClaimToken) != address(0);
    }
}
