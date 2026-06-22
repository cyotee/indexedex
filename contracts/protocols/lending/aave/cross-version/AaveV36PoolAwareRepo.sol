// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPool} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPool.sol";
import {IPoolAddressesProvider} from
    "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPoolAddressesProvider.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";

/**
 * @title AaveV36PoolAwareRepo
 * @author cyotee doge <doge.cyotee>
 * @notice Dependency-injection storage for the Aave V3.6 source contracts used by the
 *         cross-version loop vault. Initialized in the Package `initAccount` from immutable
 *         values resolved at deploy time (PRD decision: AwareRepos; spike WS1/WS3).
 */
library AaveV36PoolAwareRepo {
    bytes32 internal constant STORAGE_SLOT =
        keccak256(abi.encode("indexedex.protocols.lending.aave.cross-version.v36.pool.aware"));

    struct Storage {
        IPool pool;
        IPoolAddressesProvider addressesProvider;
        IAaveOracle oracle;
    }

    function _layout(bytes32 slot) internal pure returns (Storage storage layoutStruct) {
        assembly {
            layoutStruct.slot := slot
        }
    }

    function _layout() internal pure returns (Storage storage layoutStruct) {
        return _layout(STORAGE_SLOT);
    }

    function _initialize(
        Storage storage layoutStruct,
        IPool pool_,
        IPoolAddressesProvider addressesProvider_,
        IAaveOracle oracle_
    ) internal {
        layoutStruct.pool = pool_;
        layoutStruct.addressesProvider = addressesProvider_;
        layoutStruct.oracle = oracle_;
    }

    function _initialize(IPool pool_, IPoolAddressesProvider addressesProvider_, IAaveOracle oracle_) internal {
        _initialize(_layout(), pool_, addressesProvider_, oracle_);
    }

    function _pool(Storage storage layoutStruct) internal view returns (IPool) {
        return layoutStruct.pool;
    }

    function _pool() internal view returns (IPool) {
        return _pool(_layout());
    }

    function _addressesProvider() internal view returns (IPoolAddressesProvider) {
        return _layout().addressesProvider;
    }

    function _oracle(Storage storage layoutStruct) internal view returns (IAaveOracle) {
        return layoutStruct.oracle;
    }

    function _oracle() internal view returns (IAaveOracle) {
        return _oracle(_layout());
    }
}
