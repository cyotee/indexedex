// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ICLPool} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLPool.sol";

/**
 * @title SlipstreamPoolAwareRepo - Storage library for Slipstream pool dependency injection.
 * @author cyotee doge <doge.cyotee>
 * @notice Stores the Slipstream pool address for the vault.
 */
library SlipstreamPoolAwareRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.protocols.dexes.aerodrome.slipstream.pool.aware");

    struct Storage {
        ICLPool pool;
    }

    function _layout(bytes32 slot) internal pure returns (Storage storage layout) {
        assembly {
            layout.slot := slot
        }
    }

    function _layout() internal pure returns (Storage storage layout) {
        return _layout(STORAGE_SLOT);
    }

    function _initialize(Storage storage layout, ICLPool pool_) internal {
        layout.pool = pool_;
    }

    function _initialize(ICLPool pool_) internal {
        _initialize(_layout(), pool_);
    }

    function _slipstreamPool(Storage storage layout) internal view returns (ICLPool pool_) {
        return layout.pool;
    }

    function _slipstreamPool() internal view returns (ICLPool pool_) {
        return _slipstreamPool(_layout());
    }
}
