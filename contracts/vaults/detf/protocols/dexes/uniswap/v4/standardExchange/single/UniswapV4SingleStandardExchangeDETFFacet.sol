// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV4SingleStandardExchangeDETFBondingTarget,
    IUniswapV4SingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeDETFBondingTarget.sol";
import {
    UniswapV4SingleStandardExchangeDETFInfoTarget,
    IUniswapV4SingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeDETFInfoTarget.sol";

/// @dev Combined facet for exchange / bond / info (split later if size requires).
contract UniswapV4SingleStandardExchangeDETFFacet is
    IFacet,
    UniswapV4SingleStandardExchangeDETFBondingTarget,
    UniswapV4SingleStandardExchangeDETFInfoTarget
{
    function facetName() external pure returns (string memory) {
        return "UniswapV4SingleStandardExchangeDETFFacet";
    }

    function facetInterfaces() external pure override returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](3);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        interfaces_[1] = type(IUniswapV4SingleStandardExchangeDETFBonding).interfaceId;
        interfaces_[2] = type(IUniswapV4SingleStandardExchangeDETFInfo).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](32);
        funcs_[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[2] = IUniswapV4SingleStandardExchangeDETFBonding.openBond.selector;
        funcs_[3] = IUniswapV4SingleStandardExchangeDETFBonding.closeBond.selector;
        funcs_[4] = IUniswapV4SingleStandardExchangeDETFBonding.sellBond.selector;
        funcs_[5] = IUniswapV4SingleStandardExchangeDETFBonding.claimRewards.selector;
        funcs_[6] = IUniswapV4SingleStandardExchangeDETFBonding.acceptedBondTokens.selector;
        funcs_[7] = IUniswapV4SingleStandardExchangeDETFInfo.isReserveLive.selector;
        funcs_[8] = IUniswapV4SingleStandardExchangeDETFInfo.pairToken.selector;
        funcs_[9] = IUniswapV4SingleStandardExchangeDETFInfo.backingStandardExchangeVault.selector;
        funcs_[10] = IUniswapV4SingleStandardExchangeDETFInfo.standardExchangeVaultShare.selector;
        funcs_[11] = IUniswapV4SingleStandardExchangeDETFInfo.listingPoolKey.selector;
        funcs_[12] = IUniswapV4SingleStandardExchangeDETFInfo.poolId.selector;
        funcs_[13] = IUniswapV4SingleStandardExchangeDETFInfo.creationSqrtPriceX96.selector;
        funcs_[14] = IUniswapV4SingleStandardExchangeDETFInfo.twapSeconds.selector;
        funcs_[15] = IUniswapV4SingleStandardExchangeDETFInfo.widthMultiplier.selector;
        funcs_[16] = IUniswapV4SingleStandardExchangeDETFInfo.thresholdMode.selector;
        funcs_[17] = IUniswapV4SingleStandardExchangeDETFInfo.mintThreshold.selector;
        funcs_[18] = IUniswapV4SingleStandardExchangeDETFInfo.burnThreshold.selector;
        funcs_[19] = IUniswapV4SingleStandardExchangeDETFInfo.syntheticPrice.selector;
        funcs_[20] = IUniswapV4SingleStandardExchangeDETFInfo.isMintingAllowed.selector;
        funcs_[21] = IUniswapV4SingleStandardExchangeDETFInfo.isBurningAllowed.selector;
        funcs_[22] = IUniswapV4SingleStandardExchangeDETFInfo.isMarketMarkUsable.selector;
        funcs_[23] = IUniswapV4SingleStandardExchangeDETFInfo.bondNft.selector;
        funcs_[24] = IUniswapV4SingleStandardExchangeDETFInfo.rebasingClaimToken.selector;
        funcs_[25] = IUniswapV4SingleStandardExchangeDETFInfo.pokeListingOracle.selector;
        funcs_[26] = bytes4(keccak256("compoundProtocolRewards()"));
        funcs_[27] = bytes4(keccak256("compoundProtocolRewardsAtomic()"));
        funcs_[28] = IUniswapV4SingleStandardExchangeDETFInfo.expansionClosureRatePerSecond.selector;
        funcs_[29] = IUniswapV4SingleStandardExchangeDETFInfo.expansionCatchUpMaxSeconds.selector;
        funcs_[30] = IUniswapV4SingleStandardExchangeDETFInfo.expansionCatchUpCapBps.selector;
        funcs_[31] = IUniswapV4SingleStandardExchangeDETFInfo.lastExpansionTimestamp.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "UniswapV4SingleStandardExchangeDETFFacet";
        interfaces_ = new bytes4[](3);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        interfaces_[1] = type(IUniswapV4SingleStandardExchangeDETFBonding).interfaceId;
        interfaces_[2] = type(IUniswapV4SingleStandardExchangeDETFInfo).interfaceId;
        funcs_ = new bytes4[](32);
        funcs_[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[2] = IUniswapV4SingleStandardExchangeDETFBonding.openBond.selector;
        funcs_[3] = IUniswapV4SingleStandardExchangeDETFBonding.closeBond.selector;
        funcs_[4] = IUniswapV4SingleStandardExchangeDETFBonding.sellBond.selector;
        funcs_[5] = IUniswapV4SingleStandardExchangeDETFBonding.claimRewards.selector;
        funcs_[6] = IUniswapV4SingleStandardExchangeDETFBonding.acceptedBondTokens.selector;
        funcs_[7] = IUniswapV4SingleStandardExchangeDETFInfo.isReserveLive.selector;
        funcs_[8] = IUniswapV4SingleStandardExchangeDETFInfo.pairToken.selector;
        funcs_[9] = IUniswapV4SingleStandardExchangeDETFInfo.backingStandardExchangeVault.selector;
        funcs_[10] = IUniswapV4SingleStandardExchangeDETFInfo.standardExchangeVaultShare.selector;
        funcs_[11] = IUniswapV4SingleStandardExchangeDETFInfo.listingPoolKey.selector;
        funcs_[12] = IUniswapV4SingleStandardExchangeDETFInfo.poolId.selector;
        funcs_[13] = IUniswapV4SingleStandardExchangeDETFInfo.creationSqrtPriceX96.selector;
        funcs_[14] = IUniswapV4SingleStandardExchangeDETFInfo.twapSeconds.selector;
        funcs_[15] = IUniswapV4SingleStandardExchangeDETFInfo.widthMultiplier.selector;
        funcs_[16] = IUniswapV4SingleStandardExchangeDETFInfo.thresholdMode.selector;
        funcs_[17] = IUniswapV4SingleStandardExchangeDETFInfo.mintThreshold.selector;
        funcs_[18] = IUniswapV4SingleStandardExchangeDETFInfo.burnThreshold.selector;
        funcs_[19] = IUniswapV4SingleStandardExchangeDETFInfo.syntheticPrice.selector;
        funcs_[20] = IUniswapV4SingleStandardExchangeDETFInfo.isMintingAllowed.selector;
        funcs_[21] = IUniswapV4SingleStandardExchangeDETFInfo.isBurningAllowed.selector;
        funcs_[22] = IUniswapV4SingleStandardExchangeDETFInfo.isMarketMarkUsable.selector;
        funcs_[23] = IUniswapV4SingleStandardExchangeDETFInfo.bondNft.selector;
        funcs_[24] = IUniswapV4SingleStandardExchangeDETFInfo.rebasingClaimToken.selector;
        funcs_[25] = IUniswapV4SingleStandardExchangeDETFInfo.pokeListingOracle.selector;
        funcs_[26] = bytes4(keccak256("compoundProtocolRewards()"));
        funcs_[27] = bytes4(keccak256("compoundProtocolRewardsAtomic()"));
        funcs_[28] = IUniswapV4SingleStandardExchangeDETFInfo.expansionClosureRatePerSecond.selector;
        funcs_[29] = IUniswapV4SingleStandardExchangeDETFInfo.expansionCatchUpMaxSeconds.selector;
        funcs_[30] = IUniswapV4SingleStandardExchangeDETFInfo.expansionCatchUpCapBps.selector;
        funcs_[31] = IUniswapV4SingleStandardExchangeDETFInfo.lastExpansionTimestamp.selector;
    }
}
