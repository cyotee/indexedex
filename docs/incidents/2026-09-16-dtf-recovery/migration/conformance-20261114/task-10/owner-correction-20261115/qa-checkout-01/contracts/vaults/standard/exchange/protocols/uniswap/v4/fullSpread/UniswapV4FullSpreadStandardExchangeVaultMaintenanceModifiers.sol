// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IOperable} from "@crane/contracts/access/operable/IOperable.sol";
import {OperableRepo} from "@crane/contracts/access/operable/OperableRepo.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";

abstract contract UniswapV4FullSpreadStandardExchangeVaultMaintenanceModifiers {
    modifier onlyLiveFeeToOwnerOrOperator() {
        address owner_ = address(IVaultFeeOracleQuery(address(StandardVaultRepo._feeOracle())).feeTo());
        if (
            msg.sender != owner_ && !OperableRepo._isOperator(msg.sender)
                && !OperableRepo._isFunctionOperator(msg.sig, msg.sender)
        ) revert IOperable.NotOperator(msg.sender);
        _;
    }
}
