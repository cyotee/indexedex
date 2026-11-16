// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {UniswapV4PairTokenStandardExchangeVaultComponentBindings as ComponentBindings} from "./UniswapV4PairTokenStandardExchangeVaultComponentBindings.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {UniswapV4PairTokenStandardExchangeVaultSYMoneyTarget} from "./UniswapV4PairTokenStandardExchangeVaultSYMoneyTarget.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultSYMoneyFacet[]
/// @notice The SYMoney selectors of the composed stage-one exchange.
contract UniswapV4PairTokenStandardExchangeVaultSYMoneyFacet is UniswapV4PairTokenStandardExchangeVaultSYMoneyTarget, IFacet, ComponentBindings {
    // tag::facetName-5b6f4d01[]
    /// @inheritdoc IFacet
    /// @custom:signature facetName()
    /// @custom:selector 0x5b6f4d01
    function facetName() public pure returns (string memory) { return type(UniswapV4PairTokenStandardExchangeVaultSYMoneyFacet).name; }
    // end::facetName-5b6f4d01[]
    // tag::facetInterfaces-2ea80826[]
    /// @inheritdoc IFacet
    /// @custom:signature facetInterfaces()
    /// @custom:selector 0x2ea80826
    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](1); ids_[0] = type(IStandardizedYield).interfaceId;
    }
    // end::facetInterfaces-2ea80826[]
    // tag::facetFuncs-574a4cff[]
    /// @inheritdoc IFacet
    /// @custom:signature facetFuncs()
    /// @custom:selector 0x574a4cff
    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](4);
        funcs_[0] = IStandardizedYield.deposit.selector;
        funcs_[1] = IStandardizedYield.redeem.selector;
        funcs_[2] = IStandardizedYield.rewardIndexesCurrent.selector;
        funcs_[3] = IStandardizedYield.claimRewards.selector;
    }
    // end::facetFuncs-574a4cff[]
    // tag::facetMetadata-f10d7a75[]
    /// @inheritdoc IFacet
    /// @custom:signature facetMetadata()
    /// @custom:selector 0xf10d7a75
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
    // end::facetMetadata-f10d7a75[]
}
// end::UniswapV4PairTokenStandardExchangeVaultSYMoneyFacet[]

