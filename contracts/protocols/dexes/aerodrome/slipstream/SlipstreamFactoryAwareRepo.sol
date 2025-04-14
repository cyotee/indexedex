// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ICLFactory} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLFactory.sol";

/**
 * @title SlipstreamFactoryAwareRepo - Storage library for Slipstream factory dependency injection.
 * @author cyotee doge <doge.cyotee>
 * @notice Stores the Slipstream CL factory address for the vault.
 */
library SlipstreamFactoryAwareRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.protocols.dexes.aerodrome.slipstream.factory.aware");

    struct Storage {
        ICLFactory factory;
    }

    function _layout(bytes32 slot) internal pure returns (Storage storage layout) {
        assembly {
            layout.slot := slot
        }
    }

    function _layout() internal pure returns (Storage storage layout) {
        return _layout(STORAGE_SLOT);
    }

    function _initialize(Storage storage layout, ICLFactory factory_) internal {
        layout.factory = factory_;
    }

    function _initialize(ICLFactory factory_) internal {
        _initialize(_layout(), factory_);
    }

    function _slipstreamFactory(Storage storage layout) internal view returns (ICLFactory factory_) {
        return layout.factory;
    }

    function _slipstreamFactory() internal view returns (ICLFactory factory_) {
        return _slipstreamFactory(_layout());
    }
}
