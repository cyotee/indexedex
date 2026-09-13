// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";

/// @notice Canonical Pendle selectors appended to an existing SE facet without ERC-20 duplicates.
library NativeStandardYieldSelectors {
    function _append(bytes4[] memory existing_) internal pure returns (bytes4[] memory selectors_) {
        uint256 n_ = existing_.length;
        selectors_ = new bytes4[](n_ + 16);
        for (uint256 i_; i_ < n_; ++i_) selectors_[i_] = existing_[i_];
        selectors_[n_ + 0] = IStandardizedYield.deposit.selector;
        selectors_[n_ + 1] = IStandardizedYield.redeem.selector;
        selectors_[n_ + 2] = IStandardizedYield.exchangeRate.selector;
        selectors_[n_ + 3] = IStandardizedYield.yieldToken.selector;
        selectors_[n_ + 4] = IStandardizedYield.assetInfo.selector;
        selectors_[n_ + 5] = IStandardizedYield.getTokensIn.selector;
        selectors_[n_ + 6] = IStandardizedYield.getTokensOut.selector;
        selectors_[n_ + 7] = IStandardizedYield.isValidTokenIn.selector;
        selectors_[n_ + 8] = IStandardizedYield.isValidTokenOut.selector;
        selectors_[n_ + 9] = IStandardizedYield.previewDeposit.selector;
        selectors_[n_ + 10] = IStandardizedYield.previewRedeem.selector;
        selectors_[n_ + 11] = IStandardizedYield.getRewardTokens.selector;
        selectors_[n_ + 12] = IStandardizedYield.accruedRewards.selector;
        selectors_[n_ + 13] = IStandardizedYield.rewardIndexesCurrent.selector;
        selectors_[n_ + 14] = IStandardizedYield.rewardIndexesStored.selector;
        selectors_[n_ + 15] = IStandardizedYield.claimRewards.selector;
    }
}
