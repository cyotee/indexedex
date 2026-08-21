// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    UniswapV4StandardExchangeWeightedDETFCommon
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFCommon.sol";
import {
    UniswapV4StandardExchangeWeightedDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFRepo.sol";

/// @title UniswapV4StandardExchangeWeightedDETFInfoTarget
/// @notice View/info surface split for runtime size (EIP-170). No rateAsset getter.
abstract contract UniswapV4StandardExchangeWeightedDETFInfoTarget is UniswapV4StandardExchangeWeightedDETFCommon {
    function isReserveLive() external view returns (bool) {
        return Repo._layoutStruct().isReserveLive;
    }

    function n() external view returns (uint8) {
        return Repo._layoutStruct().n;
    }

    function m() external view returns (uint8) {
        return Repo._layoutStruct().m;
    }

    function pairTokens() external view returns (address[] memory out_) {
        Repo.Storage storage s = Repo._layoutStruct();
        out_ = new address[](s.m);
        for (uint8 i; i < s.m; ++i) {
            out_[i] = address(s.pairTokens[i]);
        }
    }

    function pairToken(uint256 productIndex) external view returns (address) {
        return address(Repo._layoutStruct().pairTokens[productIndex]);
    }

    function standardExchanges() external view returns (address[] memory out_) {
        Repo.Storage storage s = Repo._layoutStruct();
        out_ = new address[](s.m);
        for (uint8 i; i < s.m; ++i) {
            out_[i] = address(s.standardExchanges[i]);
        }
    }

    function standardExchange(uint256 productIndex) external view returns (address) {
        return address(Repo._layoutStruct().standardExchanges[productIndex]);
    }

    function vaultShares() external view returns (address[] memory out_) {
        Repo.Storage storage s = Repo._layoutStruct();
        out_ = new address[](s.m);
        for (uint8 i; i < s.m; ++i) {
            out_[i] = address(s.vaultShares[i]);
        }
    }

    function vaultShare(uint256 productIndex) external view returns (address) {
        return address(Repo._layoutStruct().vaultShares[productIndex]);
    }

    function rateProviders() external view returns (address[] memory out_) {
        Repo.Storage storage s = Repo._layoutStruct();
        out_ = new address[](s.m);
        for (uint8 i; i < s.m; ++i) {
            out_[i] = s.rateProviders[i];
        }
    }

    function rateProvider(uint256 productIndex) external view returns (address) {
        return Repo._layoutStruct().rateProviders[productIndex];
    }

    function weights() external view returns (uint256[] memory out_) {
        Repo.Storage storage s = Repo._layoutStruct();
        out_ = new uint256[](s.n);
        for (uint8 i; i < s.n; ++i) {
            out_[i] = s.weights[i];
        }
    }

    function weight(uint256 bindingIndex) external view returns (uint256) {
        return Repo._layoutStruct().weights[bindingIndex];
    }

    function detfBindingIndex() external view returns (uint8) {
        return Repo._layoutStruct().detfBindingIndex;
    }

    function pairBindingIndex(uint256 productIndex) external view returns (uint8) {
        return Repo._layoutStruct().pairBindingIndex[productIndex];
    }

    function reserveHook() external view returns (address) {
        return Repo._layoutStruct().reserveHook;
    }

    function reservePool() external view returns (address) {
        return Repo._layoutStruct().reserveHook;
    }

    function syntheticVs(address pair) external view returns (uint256) {
        return _syntheticVsAddr(pair);
    }

    function syntheticSpotVs(address pair) external view returns (uint256) {
        return _syntheticSpotVsAddr(pair);
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

    function isMintingAllowed(address pair) external view returns (bool) {
        return _isMintingAllowedAddr(pair);
    }

    function isBurningAllowed(address pair) external view returns (bool) {
        return _isBurningAllowedAddr(pair);
    }

    function isAllLegsMintRich() external view returns (bool) {
        return _allLegsMintRich();
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

    function creationPairPerDetfWad(uint256 productIndex) external view returns (uint256) {
        return Repo._layoutStruct().creationPairPerDetfWad[productIndex];
    }

    function creationPairPerDetfWads() external view returns (uint256[] memory out_) {
        Repo.Storage storage s = Repo._layoutStruct();
        out_ = new uint256[](s.m);
        for (uint8 i; i < s.m; ++i) {
            out_[i] = s.creationPairPerDetfWad[i];
        }
    }

    function openingPairPerDetfWad(uint256 productIndex) external view returns (uint256) {
        return Repo._layoutStruct().openingPairPerDetfWad[productIndex];
    }

    function openingPairPerDetfWads() external view returns (uint256[] memory out_) {
        Repo.Storage storage s = Repo._layoutStruct();
        out_ = new uint256[](s.m);
        for (uint8 i; i < s.m; ++i) {
            out_[i] = s.openingPairPerDetfWad[i];
        }
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

    function acceptedBondTokens() external view returns (address[] memory out_) {
        Repo.Storage storage s = Repo._layoutStruct();
        out_ = new address[](s.m);
        for (uint8 i; i < s.m; ++i) {
            out_[i] = address(s.pairTokens[i]);
        }
    }

    function protocolLp() external view returns (uint256) {
        return _protocolLp();
    }

    function userBondedLp() external view returns (uint256) {
        return Repo._layoutStruct().userBondedLp;
    }

    function capitalTokenOf(uint256 tokenId) external view returns (address) {
        return Repo._layoutStruct().capitalTokenOf[tokenId];
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

    function previewCloseBondMature(uint256 tokenId) external view returns (uint256[] memory amountsOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        amountsOut_ = new uint256[](s.n);
        if (address(s.bondNftVault) == address(0)) return amountsOut_;
        uint256 orig_ = s.bondNftVault.originalSharesOf(tokenId);
        if (orig_ == 0) return amountsOut_;
        uint256 lp_ = s.bondNftVault.convertToAssets(orig_);
        if (lp_ == 0) return amountsOut_;
        try IUniswapV4StandardExchangeWeightedBufferHook(s.reserveHook).previewExitProportional(lp_) returns (
            uint256[] memory residual_
        ) {
            if (residual_.length != s.n) return amountsOut_;
            for (uint8 i; i < s.n; ++i) {
                if (i == s.detfBindingIndex) continue;
                amountsOut_[i] = residual_[i];
            }
        } catch {}
    }
}
