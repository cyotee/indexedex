// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    AerodromeStandardExchangeOutExecuteTarget
} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutExecuteTarget.sol";

/// @notice Execute-only exchangeOut (Option 1b view/execute split).
contract AerodromeStandardExchangeOutFacet is AerodromeStandardExchangeOutExecuteTarget, IFacet {
    address private immutable SELF = address(this);
    error DelegateCallRequired();

    /// @dev Not installed on the vault. Native SY authorizes the holder and keeps its lock.
    function executeNativeSyRedemption(address holder_, address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_)
        external returns (uint256)
    {
        if (address(this) == SELF) revert DelegateCallRequired();
        return _redeemLpSharesFrom(holder_, receiver_, shares_, tokenOut_, minimum_);
    }

    function facetName() public pure returns (string memory name) {
        return type(AerodromeStandardExchangeOutFacet).name;
    }

    function facetInterfaces() public pure virtual returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardExchangeOut).interfaceId;
    }

    function facetFuncs() public pure virtual returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IStandardExchangeOut.exchangeOut.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}
