// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFInfoTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFInfoTarget.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";

/// @title UniswapV4StandardExchangeOrbitalDETFInfoFacet
/// @notice View/info selectors (EIP-170 size split from lifecycle facet).
contract UniswapV4StandardExchangeOrbitalDETFInfoFacet is IFacet, UniswapV4StandardExchangeOrbitalDETFInfoTarget {
    function facetName() external pure returns (string memory) {
        return "UniswapV4StandardExchangeOrbitalDETFInfoFacet";
    }

    function facetInterfaces() external pure override returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IUniswapV4StandardExchangeOrbitalDETF).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory) {
        return _allFuncs();
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "UniswapV4StandardExchangeOrbitalDETFInfoFacet";
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IUniswapV4StandardExchangeOrbitalDETF).interfaceId;
        funcs_ = _allFuncs();
    }

    function _allFuncs() private pure returns (bytes4[] memory f) {
        bytes4[] memory a = _funcsA();
        bytes4[] memory b = _funcsB();
        f = new bytes4[](a.length + b.length);
        for (uint256 i; i < a.length; ++i) {
            f[i] = a[i];
        }
        for (uint256 j; j < b.length; ++j) {
            f[a.length + j] = b[j];
        }
    }

    function _funcsA() private pure returns (bytes4[] memory f) {
        f = new bytes4[](16);
        f[0] = IUniswapV4StandardExchangeOrbitalDETF.isReserveLive.selector;
        f[1] = IUniswapV4StandardExchangeOrbitalDETF.pairToken0.selector;
        f[2] = IUniswapV4StandardExchangeOrbitalDETF.pairToken1.selector;
        f[3] = IUniswapV4StandardExchangeOrbitalDETF.standardExchange0.selector;
        f[4] = IUniswapV4StandardExchangeOrbitalDETF.standardExchange1.selector;
        f[5] = IUniswapV4StandardExchangeOrbitalDETF.vaultShare0.selector;
        f[6] = IUniswapV4StandardExchangeOrbitalDETF.vaultShare1.selector;
        f[7] = IUniswapV4StandardExchangeOrbitalDETF.rateProvider0.selector;
        f[8] = IUniswapV4StandardExchangeOrbitalDETF.rateProvider1.selector;
        f[9] = IUniswapV4StandardExchangeOrbitalDETF.rateAsset.selector;
        f[10] = IUniswapV4StandardExchangeOrbitalDETF.detfBindingIndex.selector;
        f[11] = IUniswapV4StandardExchangeOrbitalDETF.reserveHook.selector;
        f[12] = IUniswapV4StandardExchangeOrbitalDETF.reservePool.selector;
        f[13] = IUniswapV4StandardExchangeOrbitalDETF.syntheticPrice.selector;
        f[14] = IUniswapV4StandardExchangeOrbitalDETF.pendingExpansionDetf.selector;
        f[15] = IUniswapV4StandardExchangeOrbitalDETF.mintThreshold.selector;
    }

    function _funcsB() private pure returns (bytes4[] memory f) {
        f = new bytes4[](25);
        f[0] = IUniswapV4StandardExchangeOrbitalDETF.burnThreshold.selector;
        f[1] = IUniswapV4StandardExchangeOrbitalDETF.thresholdMode.selector;
        f[2] = IUniswapV4StandardExchangeOrbitalDETF.isMintingAllowed.selector;
        f[3] = IUniswapV4StandardExchangeOrbitalDETF.isBurningAllowed.selector;
        f[4] = IUniswapV4StandardExchangeOrbitalDETF.bondNftVault.selector;
        f[5] = IUniswapV4StandardExchangeOrbitalDETF.rebasingClaimToken.selector;
        f[6] = IUniswapV4StandardExchangeOrbitalDETF.feeRecipientNftId.selector;
        f[7] = IUniswapV4StandardExchangeOrbitalDETF.creationPair0PerDetfWad.selector;
        f[8] = IUniswapV4StandardExchangeOrbitalDETF.creationPair1PerDetfWad.selector;
        f[9] = IUniswapV4StandardExchangeOrbitalDETF.openingPair0PerDetfWad.selector;
        f[10] = IUniswapV4StandardExchangeOrbitalDETF.openingPair1PerDetfWad.selector;
        f[11] = IUniswapV4StandardExchangeOrbitalDETF.lastExpansionTimestamp.selector;
        f[12] = IUniswapV4StandardExchangeOrbitalDETF.expansionEpochLength.selector;
        f[13] = IUniswapV4StandardExchangeOrbitalDETF.expansionClosureRatePerYearWad.selector;
        f[14] = IUniswapV4StandardExchangeOrbitalDETF.expansionMaxCatchUpEpochs.selector;
        f[15] = IUniswapV4StandardExchangeOrbitalDETF.acceptedBondTokens.selector;
        f[16] = IUniswapV4StandardExchangeOrbitalDETF.protocolLp.selector;
        f[17] = IUniswapV4StandardExchangeOrbitalDETF.userBondedLp.selector;
        f[18] = IUniswapV4StandardExchangeOrbitalDETF.capitalModeOf.selector;
        f[19] = IUniswapV4StandardExchangeOrbitalDETF.capitalToken0Of.selector;
        f[20] = IUniswapV4StandardExchangeOrbitalDETF.capitalToken1Of.selector;
        f[21] = IUniswapV4StandardExchangeOrbitalDETF.fdRateAssetWad.selector;
        f[22] = IUniswapV4StandardExchangeOrbitalDETF.fdPairsOnlyRateAssetWad.selector;
        f[23] = IUniswapV4StandardExchangeOrbitalDETF.isReserveHookFinalized.selector;
        f[24] = IUniswapV4StandardExchangeOrbitalDETF.isReserveWired.selector;
    }
}
