// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultSYTarget} from "./UniswapV4UpperLowerWingsStandardExchangeVaultSYTarget.sol";
contract UniswapV4UpperLowerWingsStandardExchangeVaultSYFacet is UniswapV4UpperLowerWingsStandardExchangeVaultSYTarget, IFacet {
    function facetName() public pure returns (string memory) { return type(UniswapV4UpperLowerWingsStandardExchangeVaultSYFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](1); ids_[0] = type(IStandardizedYield).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](16);
        selectors_[0] = IStandardizedYield.deposit.selector;
        selectors_[1] = IStandardizedYield.redeem.selector;
        selectors_[2] = IStandardizedYield.previewDeposit.selector;
        selectors_[3] = IStandardizedYield.previewRedeem.selector;
        selectors_[4] = IStandardizedYield.getTokensIn.selector;
        selectors_[5] = IStandardizedYield.getTokensOut.selector;
        selectors_[6] = IStandardizedYield.yieldToken.selector;
        selectors_[7] = IStandardizedYield.assetInfo.selector;
        selectors_[8] = IStandardizedYield.exchangeRate.selector;
        selectors_[9] = IStandardizedYield.isValidTokenIn.selector;
        selectors_[10] = IStandardizedYield.isValidTokenOut.selector;
        selectors_[11] = IStandardizedYield.getRewardTokens.selector;
        selectors_[12] = IStandardizedYield.accruedRewards.selector;
        selectors_[13] = IStandardizedYield.rewardIndexesCurrent.selector;
        selectors_[14] = IStandardizedYield.rewardIndexesStored.selector;
        selectors_[15] = IStandardizedYield.claimRewards.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
