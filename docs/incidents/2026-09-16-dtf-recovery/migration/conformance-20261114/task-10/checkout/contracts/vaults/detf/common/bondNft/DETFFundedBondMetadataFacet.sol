// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC721Metadata} from "@crane/contracts/interfaces/IERC721Metadata.sol";
import {DETFFundedBondMetadataTarget} from "contracts/vaults/detf/common/bondNft/DETFFundedBondMetadataTarget.sol";

/// @title DETFFundedBondMetadataFacet
/// @notice Shared read-only SVG/JSON selectors for every funded bond NFT package.
contract DETFFundedBondMetadataFacet is DETFFundedBondMetadataTarget, IFacet {
    function facetName() public pure returns (string memory) { return type(DETFFundedBondMetadataFacet).name; }

    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](1);
        ids_[0] = type(IERC721Metadata).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](3);
        selectors_[0] = IERC721Metadata.name.selector;
        selectors_[1] = IERC721Metadata.symbol.selector;
        selectors_[2] = IERC721Metadata.tokenURI.selector;
    }

    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
