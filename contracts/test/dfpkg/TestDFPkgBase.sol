// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";

/**
 * @title TestDFPkgBase
 * @notice Shared test base for DFPkg-related tests. Intentionally small —
 *         it reuses the existing `IndexedexTest` setup and exposes a few
 *         convenience accessors that reduce duplication in spec tests.
 */
contract TestDFPkgBase is IndexedexTest {
    /// Expose commonly-used addresses from the IndexedexTest setup.
    function indexedexManagerAddress() internal view returns (address) {
        return address(indexedexManager);
    }

    function feeCollectorAddress() internal view returns (address) {
        return address(feeCollector);
    }

    function testOwner() internal view returns (address) {
        return owner;
    }
}
