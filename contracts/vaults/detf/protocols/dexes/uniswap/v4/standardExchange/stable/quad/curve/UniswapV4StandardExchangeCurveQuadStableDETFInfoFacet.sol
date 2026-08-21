// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETFInfoTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFInfoTarget.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";

/// @title UniswapV4StandardExchangeCurveQuadStableDETFInfoFacet
/// @notice View/info selectors (EIP-170 size split). No rateAsset.
contract UniswapV4StandardExchangeCurveQuadStableDETFInfoFacet is
    IFacet,
    UniswapV4StandardExchangeCurveQuadStableDETFInfoTarget
{
    function facetName() external pure returns (string memory) {
        return "UniswapV4StandardExchangeCurveQuadStableDETFInfoFacet";
    }

    function facetInterfaces() external pure override returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IUniswapV4StandardExchangeCurveQuadStableDETF).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory) {
        return _allFuncs();
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "UniswapV4StandardExchangeCurveQuadStableDETFInfoFacet";
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IUniswapV4StandardExchangeCurveQuadStableDETF).interfaceId;
        funcs_ = _allFuncs();
    }

    function _allFuncs() private pure returns (bytes4[] memory f) {
        bytes4[] memory a = _funcsA();
        bytes4[] memory b = _funcsB();
        f = new bytes4[](a.length + b.length + 1);
        for (uint256 i; i < a.length; ++i) {
            f[i] = a[i];
        }
        for (uint256 j; j < b.length; ++j) {
            f[a.length + j] = b[j];
        }
        f[a.length + b.length] = IUniswapV4StandardExchangeCurveQuadStableDETF.capitalTokenOf.selector;
    }

    function _funcsA() private pure returns (bytes4[] memory f) {
        f = new bytes4[](18);
        f[0] = IUniswapV4StandardExchangeCurveQuadStableDETF.isReserveLive.selector;
        f[1] = IUniswapV4StandardExchangeCurveQuadStableDETF.n.selector;
        f[2] = IUniswapV4StandardExchangeCurveQuadStableDETF.m.selector;
        f[3] = IUniswapV4StandardExchangeCurveQuadStableDETF.pairTokens.selector;
        f[4] = IUniswapV4StandardExchangeCurveQuadStableDETF.pairToken.selector;
        f[5] = IUniswapV4StandardExchangeCurveQuadStableDETF.pairToken0.selector;
        f[6] = IUniswapV4StandardExchangeCurveQuadStableDETF.pairToken1.selector;
        f[7] = IUniswapV4StandardExchangeCurveQuadStableDETF.pairToken2.selector;
        f[8] = IUniswapV4StandardExchangeCurveQuadStableDETF.standardExchanges.selector;
        f[9] = IUniswapV4StandardExchangeCurveQuadStableDETF.standardExchange.selector;
        f[10] = IUniswapV4StandardExchangeCurveQuadStableDETF.vaultShares.selector;
        f[11] = IUniswapV4StandardExchangeCurveQuadStableDETF.vaultShare.selector;
        f[12] = IUniswapV4StandardExchangeCurveQuadStableDETF.rateProviders.selector;
        f[13] = IUniswapV4StandardExchangeCurveQuadStableDETF.rateProvider.selector;
        f[14] = IUniswapV4StandardExchangeCurveQuadStableDETF.baseAmp.selector;
        f[15] = IUniswapV4StandardExchangeCurveQuadStableDETF.detfBindingIndex.selector;
        f[16] = IUniswapV4StandardExchangeCurveQuadStableDETF.pairBindingIndex.selector;
        f[17] = IUniswapV4StandardExchangeCurveQuadStableDETF.reserveHook.selector;
    }

    function _funcsB() private pure returns (bytes4[] memory f) {
        f = new bytes4[](26);
        f[0] = IUniswapV4StandardExchangeCurveQuadStableDETF.reservePool.selector;
        f[1] = IUniswapV4StandardExchangeCurveQuadStableDETF.syntheticVs.selector;
        f[2] = IUniswapV4StandardExchangeCurveQuadStableDETF.syntheticSpotVs.selector;
        f[3] = IUniswapV4StandardExchangeCurveQuadStableDETF.pendingExpansionDetf.selector;
        f[4] = IUniswapV4StandardExchangeCurveQuadStableDETF.mintThreshold.selector;
        f[5] = IUniswapV4StandardExchangeCurveQuadStableDETF.burnThreshold.selector;
        f[6] = IUniswapV4StandardExchangeCurveQuadStableDETF.thresholdMode.selector;
        f[7] = IUniswapV4StandardExchangeCurveQuadStableDETF.isMintingAllowed.selector;
        f[8] = IUniswapV4StandardExchangeCurveQuadStableDETF.isBurningAllowed.selector;
        f[9] = IUniswapV4StandardExchangeCurveQuadStableDETF.isAllLegsMintRich.selector;
        f[10] = IUniswapV4StandardExchangeCurveQuadStableDETF.bondNftVault.selector;
        f[11] = IUniswapV4StandardExchangeCurveQuadStableDETF.rebasingClaimToken.selector;
        f[12] = IUniswapV4StandardExchangeCurveQuadStableDETF.feeRecipientNftId.selector;
        f[13] = IUniswapV4StandardExchangeCurveQuadStableDETF.creationPairPerDetfWad.selector;
        f[14] = IUniswapV4StandardExchangeCurveQuadStableDETF.creationPairPerDetfWads.selector;
        f[15] = IUniswapV4StandardExchangeCurveQuadStableDETF.openingPairPerDetfWad.selector;
        f[16] = IUniswapV4StandardExchangeCurveQuadStableDETF.openingPairPerDetfWads.selector;
        f[17] = IUniswapV4StandardExchangeCurveQuadStableDETF.lastExpansionTimestamp.selector;
        f[18] = IUniswapV4StandardExchangeCurveQuadStableDETF.expansionEpochLength.selector;
        f[19] = IUniswapV4StandardExchangeCurveQuadStableDETF.expansionClosureRatePerYearWad.selector;
        f[20] = IUniswapV4StandardExchangeCurveQuadStableDETF.expansionMaxCatchUpEpochs.selector;
        f[21] = IUniswapV4StandardExchangeCurveQuadStableDETF.acceptedBondTokens.selector;
        f[22] = IUniswapV4StandardExchangeCurveQuadStableDETF.protocolLp.selector;
        f[23] = IUniswapV4StandardExchangeCurveQuadStableDETF.userBondedLp.selector;
        f[24] = IUniswapV4StandardExchangeCurveQuadStableDETF.isReserveHookFinalized.selector;
        f[25] = IUniswapV4StandardExchangeCurveQuadStableDETF.isReserveWired.selector;
    }
}
