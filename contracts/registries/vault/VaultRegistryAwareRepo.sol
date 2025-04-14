// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IVaultRegistryProxy} from "contracts/interfaces/proxies/IVaultRegistryProxy.sol";

library VaultRegistryAwareRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("contracts.registries.vault.aware");

    struct Storage {
        IVaultRegistryProxy vaultRegistry;
    }

    function _layout(bytes32 slot_) internal pure returns (Storage storage layout_) {
        assembly {
            layout_.slot := slot_
        }
    }

    function _layout() internal pure returns (Storage storage) {
        return _layout(STORAGE_SLOT);
    }

    function _initialiaze(Storage storage s_, IVaultRegistryProxy vaultRegistry_) internal {
        s_.vaultRegistry = vaultRegistry_;
    }

    function _initialize(IVaultRegistryProxy vaultRegistry_) internal {
        _initialiaze(_layout(), vaultRegistry_);
    }

    function _vaultRegistry(Storage storage s_) internal view returns (IVaultRegistryProxy) {
        return s_.vaultRegistry;
    }

    function _vaultRegistry() internal view returns (IVaultRegistryProxy) {
        return _layout().vaultRegistry;
    }
}
