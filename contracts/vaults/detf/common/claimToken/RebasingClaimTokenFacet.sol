// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {StakedDETFTarget} from "contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol";

/// @title RebasingClaimTokenFacet
/// @notice Funded staking facet for the existing rebasing-token package role.
/// @dev Standard principal routes replace the legacy LP-claim selectors.
contract RebasingClaimTokenFacet is StakedDETFTarget, IFacet {
    /// @inheritdoc IFacet
    function facetName() public pure returns (string memory) {
        return type(RebasingClaimTokenFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](5);
        interfaces_[0] = type(IERC20).interfaceId;
        interfaces_[1] = type(IERC20Metadata).interfaceId;
        interfaces_[2] = type(IStakedDETF).interfaceId;
        interfaces_[3] = type(IStandardExchangeIn).interfaceId;
        interfaces_[4] = type(IStandardExchangeOut).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](19);
        funcs_[0] = IERC20.totalSupply.selector;
        funcs_[1] = IERC20.balanceOf.selector;
        funcs_[2] = IERC20.transfer.selector;
        funcs_[3] = IERC20.allowance.selector;
        funcs_[4] = IERC20.approve.selector;
        funcs_[5] = IERC20.transferFrom.selector;
        funcs_[6] = IERC20Metadata.name.selector;
        funcs_[7] = IERC20Metadata.symbol.selector;
        funcs_[8] = IERC20Metadata.decimals.selector;
        funcs_[9] = IStakedDETF.detf.selector;
        funcs_[10] = IStakedDETF.gonsOf.selector;
        funcs_[11] = IStakedDETF.stakingState.selector;
        funcs_[12] = IStakedDETF.fundRewards.selector;
        funcs_[13] = IStakedDETF.retireEscrowDust.selector;
        funcs_[14] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[15] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[16] = IStandardExchangeOut.previewExchangeOut.selector;
        funcs_[17] = IStandardExchangeOut.exchangeOut.selector;
        funcs_[18] = IStakedDETF.previewDistributions.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata()
        external pure returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory functions_)
    {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
