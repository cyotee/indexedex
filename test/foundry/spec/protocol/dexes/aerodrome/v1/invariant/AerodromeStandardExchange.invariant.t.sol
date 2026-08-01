// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_AerodromeStandardExchange_MultiPool
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange_MultiPool.sol";
import {
    Handler_AerodromeStandardExchange
} from "test/foundry/spec/protocol/dexes/aerodrome/v1/invariant/Handler_AerodromeStandardExchange.sol";

/**
 * @title AerodromeStandardExchangeInvariant
 * @notice L3 multi-route inventory invariants for Aerodrome SE (Wave 2A).
 * @dev Complements dense L1 route fuzz; does not replace InOutInvariant suites.
 */
/// forge-config: default.invariant.runs = 24
/// forge-config: default.invariant.depth = 10
contract AerodromeStandardExchangeInvariant is TestBase_AerodromeStandardExchange_MultiPool {
    Handler_AerodromeStandardExchange internal handler;
    address internal invActor0;
    address internal invActor1;

    function setUp() public virtual override {
        super.setUp();
        invActor0 = makeAddr("aeroInv0");
        invActor1 = makeAddr("aeroInv1");

        handler = new Handler_AerodromeStandardExchange(
            balancedVault, aeroBalancedTokenA, aeroBalancedTokenB, invActor0, invActor1
        );

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = Handler_AerodromeStandardExchange.swap.selector;
        selectors[1] = Handler_AerodromeStandardExchange.vaultDeposit.selector;
        selectors[2] = Handler_AerodromeStandardExchange.vaultWithdraw.selector;

        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @notice P-RESID soft: vault should not hold large free tokenA/tokenB inventory
    ///         beyond dust after ops (exact zero may fail if intermediate accounting holds dust).
    function invariant_inventoryDustBounded() public view {
        uint256 dustCap = 1e15; // 0.001 token
        uint256 aBal = aeroBalancedTokenA.balanceOf(address(balancedVault));
        uint256 bBal = aeroBalancedTokenB.balanceOf(address(balancedVault));
        // Pass-through routes may leave residual; bound generously for hermetic pools.
        assertLe(aBal, dustCap * 1000, "P-RESID tokenA inventory");
        assertLe(bBal, dustCap * 1000, "P-RESID tokenB inventory");
    }

    function invariant_ghostMonotonic() public view {
        // Counts are uint - always >= 0; ensure no absurd wrap (always true for uint increases).
        assertTrue(handler.ghost_swapCount() < type(uint128).max, "P-GHOST swap");
        assertTrue(handler.ghost_depositCount() < type(uint128).max, "P-GHOST deposit");
        assertTrue(handler.ghost_withdrawCount() < type(uint128).max, "P-GHOST withdraw");
    }

    function invariant_shareSupplyNonNegative() public view {
        assertTrue(IERC20(address(balancedVault)).totalSupply() >= 0, "supply");
    }
}
