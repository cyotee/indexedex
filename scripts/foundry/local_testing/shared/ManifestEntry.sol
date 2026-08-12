// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

struct ManifestEntry {
    uint256 chainId;
    address addr;
    string name;
    string symbol;
    uint8 decimals;
    string[] tags;
}

library ManifestEntryLib {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @notice Serialize a ManifestEntry to a JSON string matching the Token List fragment shape.
    /// @dev Phase 1 emits only the base fields. Extensions are synthesized later by the
    ///      Node aggregator from cross-fragment context (composing assets, factory pointers, etc.).
    function toJson(ManifestEntry memory e) internal returns (string memory) {
        string memory obj = "fragment";
        vm.serializeUint(obj, "chainId", e.chainId);
        vm.serializeAddress(obj, "address", e.addr);
        vm.serializeString(obj, "name", e.name);
        vm.serializeString(obj, "symbol", e.symbol);

        if (e.tags.length > 0) {
            vm.serializeString(obj, "tags", e.tags);
        }

        // The last `serialize*` call returns the accumulated JSON string for `obj`.
        return vm.serializeUint(obj, "decimals", uint256(e.decimals));
    }
}
