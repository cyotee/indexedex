// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IOperable} from "@crane/contracts/access/operable/IOperable.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";

abstract contract UniswapV4FullSpreadStandardExchangeVaultOwnerModifiers {
    modifier onlyLiveFeeToOwner() {
        if (msg.sender != address(IVaultFeeOracleQuery(address(StandardVaultRepo._feeOracle())).feeTo())) {
            revert IOperable.NotOperator(msg.sender);
        }
        _;
    }
}
