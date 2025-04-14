// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

library VaultFeeOracleQueryAwareRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.oracles.fee.vault.fee.oracle.query.aware");

    struct Storage {
        IVaultFeeOracleQuery vaultFeeOracleQuery;
    }

    function _layout(bytes32 slot) internal pure returns (Storage storage layout) {
        assembly {
            layout.slot := slot
        }
    }

    function _layout() internal pure returns (Storage storage layout) {
        return _layout(STORAGE_SLOT);
    }

    function _initialize(Storage storage layout, IVaultFeeOracleQuery vaultFeeOracleQuery_) internal {
        layout.vaultFeeOracleQuery = vaultFeeOracleQuery_;
    }

    function _initialize(IVaultFeeOracleQuery vaultFeeOracleQuery_) internal {
        _initialize(_layout(), vaultFeeOracleQuery_);
    }

    function _feeOracle(Storage storage layout) internal view returns (IVaultFeeOracleQuery vaultFeeOracleQuery_) {
        return layout.vaultFeeOracleQuery;
    }

    function _feeOracle() internal view returns (IVaultFeeOracleQuery vaultFeeOracleQuery_) {
        return _feeOracle(_layout());
    }
}
