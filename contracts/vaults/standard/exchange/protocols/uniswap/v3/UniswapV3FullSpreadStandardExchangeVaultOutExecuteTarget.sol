// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {UniswapV3FullSpreadStandardExchangeVaultCommon} from "./UniswapV3FullSpreadStandardExchangeVaultCommon.sol";

/// @notice Exact-output accounting is unavailable; validation does not touch the pool.
abstract contract UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget is UniswapV3FullSpreadStandardExchangeVaultCommon {
    function exchangeOut(IERC20, uint256, IERC20, uint256, address, bool, uint256 deadline_)
        external view returns (uint256)
    {
        _deadline(deadline_);
        _requireNotDisabled();
        revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }
}
