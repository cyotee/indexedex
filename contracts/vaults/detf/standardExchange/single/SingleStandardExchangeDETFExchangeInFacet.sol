// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    SingleStandardExchangeDETFExchangeInTarget
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFExchangeInTarget.sol";
import {
    SingleStandardExchangeDETFBondingTarget,
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    SingleStandardExchangeDETFExchangeInQueryTarget
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFExchangeInQueryTarget.sol";
import {
    SingleStandardExchangeDETFInfoTarget,
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";

/// @dev Combined facet for exchange/bond/info/query (split later if size requires).
contract SingleStandardExchangeDETFExchangeInFacet is
    IFacet,
    SingleStandardExchangeDETFExchangeInTarget,
    SingleStandardExchangeDETFBondingTarget,
    SingleStandardExchangeDETFExchangeInQueryTarget,
    SingleStandardExchangeDETFInfoTarget
{
    function facetName() external pure returns (string memory) {
        return "SingleStandardExchangeDETFExchangeInFacet";
    }

    function facetInterfaces() external pure override returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](3);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        interfaces_[1] = type(ISingleStandardExchangeDETFBonding).interfaceId;
        interfaces_[2] = type(ISingleStandardExchangeDETFInfo).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](22);
        funcs_[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[2] = ISingleStandardExchangeDETFBonding.bond.selector;
        funcs_[3] = ISingleStandardExchangeDETFBonding.sellPositionToDetfNft.selector;
        funcs_[4] = ISingleStandardExchangeDETFInfo.isReserveLive.selector;
        funcs_[5] = ISingleStandardExchangeDETFInfo.standardExchangeVault.selector;
        funcs_[6] = ISingleStandardExchangeDETFInfo.standardExchangeVaultShare.selector;
        funcs_[7] = ISingleStandardExchangeDETFInfo.rateTarget.selector;
        funcs_[8] = ISingleStandardExchangeDETFInfo.reservePool.selector;
        funcs_[9] = ISingleStandardExchangeDETFInfo.syntheticPrice.selector;
        funcs_[10] = ISingleStandardExchangeDETFInfo.mintThreshold.selector;
        funcs_[11] = ISingleStandardExchangeDETFInfo.burnThreshold.selector;
        funcs_[12] = ISingleStandardExchangeDETFInfo.thresholdMode.selector;
        funcs_[13] = ISingleStandardExchangeDETFInfo.isMintingAllowed.selector;
        funcs_[14] = ISingleStandardExchangeDETFInfo.isBurningAllowed.selector;
        funcs_[15] = ISingleStandardExchangeDETFInfo.bondNftVault.selector;
        funcs_[16] = ISingleStandardExchangeDETFInfo.compoundProtocolRewards.selector;
        // Atomic self-call helper (only-self); not on ISingleStandardExchangeDETFInfo.
        funcs_[17] = bytes4(keccak256("compoundProtocolRewardsAtomic()"));
        funcs_[18] = ISingleStandardExchangeDETFInfo.lastExpansionTimestamp.selector;
        funcs_[19] = ISingleStandardExchangeDETFInfo.expansionClosureRatePerSecond.selector;
        funcs_[20] = ISingleStandardExchangeDETFInfo.expansionCatchUpMaxSeconds.selector;
        funcs_[21] = ISingleStandardExchangeDETFInfo.expansionCatchUpCapBps.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "SingleStandardExchangeDETFExchangeInFacet";
        interfaces_ = new bytes4[](3);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        interfaces_[1] = type(ISingleStandardExchangeDETFBonding).interfaceId;
        interfaces_[2] = type(ISingleStandardExchangeDETFInfo).interfaceId;
        funcs_ = new bytes4[](22);
        funcs_[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[2] = ISingleStandardExchangeDETFBonding.bond.selector;
        funcs_[3] = ISingleStandardExchangeDETFBonding.sellPositionToDetfNft.selector;
        funcs_[4] = ISingleStandardExchangeDETFInfo.isReserveLive.selector;
        funcs_[5] = ISingleStandardExchangeDETFInfo.standardExchangeVault.selector;
        funcs_[6] = ISingleStandardExchangeDETFInfo.standardExchangeVaultShare.selector;
        funcs_[7] = ISingleStandardExchangeDETFInfo.rateTarget.selector;
        funcs_[8] = ISingleStandardExchangeDETFInfo.reservePool.selector;
        funcs_[9] = ISingleStandardExchangeDETFInfo.syntheticPrice.selector;
        funcs_[10] = ISingleStandardExchangeDETFInfo.mintThreshold.selector;
        funcs_[11] = ISingleStandardExchangeDETFInfo.burnThreshold.selector;
        funcs_[12] = ISingleStandardExchangeDETFInfo.thresholdMode.selector;
        funcs_[13] = ISingleStandardExchangeDETFInfo.isMintingAllowed.selector;
        funcs_[14] = ISingleStandardExchangeDETFInfo.isBurningAllowed.selector;
        funcs_[15] = ISingleStandardExchangeDETFInfo.bondNftVault.selector;
        funcs_[16] = ISingleStandardExchangeDETFInfo.compoundProtocolRewards.selector;
        funcs_[17] = bytes4(keccak256("compoundProtocolRewardsAtomic()"));
        funcs_[18] = ISingleStandardExchangeDETFInfo.lastExpansionTimestamp.selector;
        funcs_[19] = ISingleStandardExchangeDETFInfo.expansionClosureRatePerSecond.selector;
        funcs_[20] = ISingleStandardExchangeDETFInfo.expansionCatchUpMaxSeconds.selector;
        funcs_[21] = ISingleStandardExchangeDETFInfo.expansionCatchUpCapBps.selector;
    }
}
