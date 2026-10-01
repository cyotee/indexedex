// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {TestBase_FullSpreadRegistryMaintenanceObservation} from "contracts/test/bases/TestBase_FullSpreadRegistryMaintenanceObservation.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";

/// @notice Registry-deployed H public-maintenance confirmation with independent core/custody observations.
// tag::HooklessRegistryMaintenanceObservationTest[]
contract HooklessRegistryMaintenanceObservationTest is
    TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance,
    TestBase_FullSpreadRegistryMaintenanceObservation
{
    function setUp() public override {
        super.setUp();
        _bootstrap();
        token0.approve(address(vault), 0);
        token1.approve(address(vault), 0);
    }
    function _registrySubject() internal view override returns (address) { return address(vault); }
    function _registryManager() internal view override returns (IPoolManager) { return poolManager; }
    function _registryKey() internal view override returns (PoolKey memory) { return poolKey; }
    function _registryPermit2() internal view override returns (address) { return address(permit2); }

    /// @notice Real external swaps leave owned LP fees pending; public repair collects them exactly once.
    function test_registryMaintenance_pendingOwnFeesBothDirections() public {
        for (uint256 direction; direction < 2; ++direction) {
            uint256 root = vm.snapshotState();
            _externalSwap(direction == 0, 1e18);
            Book memory accrued = _registryObserve();
            assertGt(accrued.earned[direction], 0, "actual pre-collection owned LP fee witness");
            _registryDonate(direction, (accrued.free[direction] + accrued.principal[direction]) / 100);
            Result memory result = _registryRun();
            assertGt(result.beforeBook.earned[direction], 0);
            assertEq(result.swaps, 1);
            assertTrue(vm.revertToStateAndDelete(root));
        }
    }
}
// end::HooklessRegistryMaintenanceObservationTest[]
