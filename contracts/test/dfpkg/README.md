TestDFPkgBase
=================

Shared test base used by DFPkg-related spec tests. It inherits from
`contracts/test/IndexedexTest.sol` and exposes a couple small helper
accessors to reduce boilerplate in tests that need the `indexedexManager`
or `feeCollector` addresses.

Usage
-----

In your test contract simply inherit from `TestDFPkgBase` instead of
`IndexedexTest` to get the same environment plus the convenience methods.

Example
-------

contract MyDFPkgTest is TestDFPkgBase {
    function setUp() public override {
        super.setUp();
        // use indexedexManagerAddress() or feeCollectorAddress() in tests
    }
}
