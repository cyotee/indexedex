// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {UniswapV4FullSpreadStandardExchangeVaultComponentBindings} from "./UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol";

contract UniswapV4FullSpreadStandardExchangeVaultOutTarget is
    IStandardExchangeOut,
    UniswapV4FullSpreadStandardExchangeVaultComponentBindings
{
    function previewExchangeOut(IERC20, IERC20, uint256) external pure returns (uint256) {
        return 0;
    }

    function exchangeOut(IERC20, uint256, IERC20, uint256, address, bool, uint256 deadline)
        external
        view
        returns (uint256)
    {
        if (block.timestamp > deadline) revert IStandardExchangeErrors.DeadlineExceeded(deadline, block.timestamp);
        if (IVaultRegistryDisableQuery(address(StandardVaultRepo._feeOracle())).isDisabled(address(this))) {
            revert IVaultRegistryDisableQuery.VaultDisabled(address(this));
        }
        revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }
}
