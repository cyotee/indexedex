// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultOutTarget[]
/// @notice Stage one deliberately has no exact-output route.
/// @dev Unavailability takes precedence over guards, funding and route validation.
contract UniswapV4PairTokenStandardExchangeVaultOutTarget is IStandardExchangeOut {
    // tag::previewExchangeOut[]
    /// @inheritdoc IStandardExchangeOut
    /// @custom:signature previewExchangeOut(address,address,uint256)
    /// @custom:selector 0xdb149bc5
    function previewExchangeOut(IERC20, IERC20, uint256) external pure returns (uint256) {
        revert ExchangeOutNotAvailable();
    }
    // end::previewExchangeOut[]

    // tag::exchangeOut[]
    /// @inheritdoc IStandardExchangeOut
    /// @custom:signature exchangeOut(address,uint256,address,uint256,address,bool,uint256)
    /// @custom:selector 0xbbac8477
    function exchangeOut(IERC20, uint256, IERC20, uint256, address, bool, uint256)
        external
        pure
        returns (uint256)
    {
        revert ExchangeOutNotAvailable();
    }
    // end::exchangeOut[]
}
// end::UniswapV4PairTokenStandardExchangeVaultOutTarget[]
