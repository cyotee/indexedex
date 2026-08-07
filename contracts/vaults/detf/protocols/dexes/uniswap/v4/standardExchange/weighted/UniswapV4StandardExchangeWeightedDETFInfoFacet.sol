// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    UniswapV4StandardExchangeWeightedDETFInfoTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFInfoTarget.sol";
import {
    IUniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";

/// @title UniswapV4StandardExchangeWeightedDETFInfoFacet
/// @notice View/info selectors (EIP-170 size split from lifecycle facet).
contract UniswapV4StandardExchangeWeightedDETFInfoFacet is IFacet, UniswapV4StandardExchangeWeightedDETFInfoTarget {
    function facetName() external pure returns (string memory) {
        return "UniswapV4StandardExchangeWeightedDETFInfoFacet";
    }

    function facetInterfaces() external pure override returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IUniswapV4StandardExchangeWeightedDETF).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory) {
        return _allFuncs();
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "UniswapV4StandardExchangeWeightedDETFInfoFacet";
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IUniswapV4StandardExchangeWeightedDETF).interfaceId;
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
        f = new bytes4[](18);
        f[0] = IUniswapV4StandardExchangeWeightedDETF.isReserveLive.selector;
        f[1] = IUniswapV4StandardExchangeWeightedDETF.n.selector;
        f[2] = IUniswapV4StandardExchangeWeightedDETF.m.selector;
        f[3] = IUniswapV4StandardExchangeWeightedDETF.pairTokens.selector;
        f[4] = IUniswapV4StandardExchangeWeightedDETF.pairToken.selector;
        f[5] = IUniswapV4StandardExchangeWeightedDETF.standardExchanges.selector;
        f[6] = IUniswapV4StandardExchangeWeightedDETF.standardExchange.selector;
        f[7] = IUniswapV4StandardExchangeWeightedDETF.vaultShares.selector;
        f[8] = IUniswapV4StandardExchangeWeightedDETF.vaultShare.selector;
        f[9] = IUniswapV4StandardExchangeWeightedDETF.rateProviders.selector;
        f[10] = IUniswapV4StandardExchangeWeightedDETF.rateProvider.selector;
        f[11] = IUniswapV4StandardExchangeWeightedDETF.weights.selector;
        f[12] = IUniswapV4StandardExchangeWeightedDETF.weight.selector;
        f[13] = IUniswapV4StandardExchangeWeightedDETF.detfBindingIndex.selector;
        f[14] = IUniswapV4StandardExchangeWeightedDETF.pairBindingIndex.selector;
        f[15] = IUniswapV4StandardExchangeWeightedDETF.reserveHook.selector;
        f[16] = IUniswapV4StandardExchangeWeightedDETF.reservePool.selector;
        f[17] = IUniswapV4StandardExchangeWeightedDETF.syntheticVs.selector;
    }

    function _funcsB() private pure returns (bytes4[] memory f) {
        f = new bytes4[](21);
        f[0] = IUniswapV4StandardExchangeWeightedDETF.syntheticSpotVs.selector;
        f[1] = IUniswapV4StandardExchangeWeightedDETF.pendingExpansionDetf.selector;
        f[2] = IUniswapV4StandardExchangeWeightedDETF.mintThreshold.selector;
        f[3] = IUniswapV4StandardExchangeWeightedDETF.burnThreshold.selector;
        f[4] = IUniswapV4StandardExchangeWeightedDETF.thresholdMode.selector;
        f[5] = IUniswapV4StandardExchangeWeightedDETF.isMintingAllowed.selector;
        f[6] = IUniswapV4StandardExchangeWeightedDETF.isBurningAllowed.selector;
        f[7] = IUniswapV4StandardExchangeWeightedDETF.isAllLegsMintRich.selector;
        f[8] = IUniswapV4StandardExchangeWeightedDETF.bondNftVault.selector;
        f[9] = IUniswapV4StandardExchangeWeightedDETF.rebasingClaimToken.selector;
        f[10] = IUniswapV4StandardExchangeWeightedDETF.feeRecipientNftId.selector;
        f[11] = IUniswapV4StandardExchangeWeightedDETF.creationPairPerDetfWad.selector;
        f[12] = IUniswapV4StandardExchangeWeightedDETF.creationPairPerDetfWads.selector;
        f[13] = IUniswapV4StandardExchangeWeightedDETF.lastExpansionTimestamp.selector;
        f[14] = IUniswapV4StandardExchangeWeightedDETF.expansionEpochLength.selector;
        f[15] = IUniswapV4StandardExchangeWeightedDETF.expansionClosureRatePerYearWad.selector;
        f[16] = IUniswapV4StandardExchangeWeightedDETF.expansionMaxCatchUpEpochs.selector;
        f[17] = IUniswapV4StandardExchangeWeightedDETF.acceptedBondTokens.selector;
        f[18] = IUniswapV4StandardExchangeWeightedDETF.protocolLp.selector;
        f[19] = IUniswapV4StandardExchangeWeightedDETF.userBondedLp.selector;
        f[20] = IUniswapV4StandardExchangeWeightedDETF.capitalTokenOf.selector;
    }
}
