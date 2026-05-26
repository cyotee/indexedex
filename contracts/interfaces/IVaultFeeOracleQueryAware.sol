// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

interface IVaultFeeOracleQueryAware {
    function vaultFeeOracleQuery() external view returns (IVaultFeeOracleQuery);
}
