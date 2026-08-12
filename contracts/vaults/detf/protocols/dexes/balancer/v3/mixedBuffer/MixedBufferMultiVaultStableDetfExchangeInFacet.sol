// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    MixedBufferMultiVaultStableDetfExchangeQueryTarget
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfExchangeQueryTarget.sol";

/// @title MixedBufferMultiVaultStableDetfExchangeInFacet
/// @notice Exchange In/Out + previews only (Option 1c size split from combined mega-Facet).
contract MixedBufferMultiVaultStableDetfExchangeInFacet is IFacet, MixedBufferMultiVaultStableDetfExchangeQueryTarget {
    function facetName() external pure returns (string memory) {
        return "MixedBufferMultiVaultStableDetfExchangeInFacet";
    }

    function facetInterfaces() external pure override returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](4);
        funcs_[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[2] = bytes4(keccak256("previewExchangeOut(address,address,uint256)"));
        funcs_[3] = bytes4(keccak256("exchangeOut(address,address,uint256,uint256,address,bool,uint256)"));
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "MixedBufferMultiVaultStableDetfExchangeInFacet";
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        funcs_ = new bytes4[](4);
        funcs_[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[2] = bytes4(keccak256("previewExchangeOut(address,address,uint256)"));
        funcs_[3] = bytes4(keccak256("exchangeOut(address,address,uint256,uint256,address,bool,uint256)"));
    }
}
