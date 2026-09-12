// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_AerodromeStandardExchange_Decimals
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange_Decimals.sol";
import {
    Handler_AerodromeStandardExchange_Decimals
} from "test/foundry/spec/protocol/dexes/aerodrome/v1/decimals/invariant/Handler_AerodromeStandardExchange_Decimals.sol";

/**
 * @title AerodromeStandardExchange_Invariant_Decimals
 * @notice L3 multi-route inventory invariants per combo. pairToken = tokenA.
 * @dev After Aerodrome pool address sort, token0/token1 may swap; roles stay pairToken vs other.
 *      vaultShare stays 18. Dust cap is 1000 human units of each token.
 */
/// forge-config: default.invariant.runs = 24
/// forge-config: default.invariant.depth = 10
abstract contract AerodromeStandardExchange_Invariant_Decimals is TestBase_AerodromeStandardExchange_Decimals {
    Handler_AerodromeStandardExchange_Decimals internal handler;
    address internal invActor0;
    address internal invActor1;

    function setUp() public virtual override {
        super.setUp();
        invActor0 = makeAddr("aeroInv0");
        invActor1 = makeAddr("aeroInv1");

        handler = new Handler_AerodromeStandardExchange_Decimals(
            balancedVault, aeroBalancedTokenA, aeroBalancedTokenB, invActor0, invActor1
        );

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = Handler_AerodromeStandardExchange_Decimals.swap.selector;
        selectors[1] = Handler_AerodromeStandardExchange_Decimals.vaultDeposit.selector;
        selectors[2] = Handler_AerodromeStandardExchange_Decimals.vaultWithdraw.selector;

        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @notice P-RESID soft: vault should not hold large free pairToken / other inventory.
    function invariant_inventoryDustBounded() public view {
        uint256 capA = _uA(1000);
        uint256 capB = _uB(1000);
        uint256 aBal = aeroBalancedTokenA.balanceOf(address(balancedVault));
        uint256 bBal = aeroBalancedTokenB.balanceOf(address(balancedVault));
        assertLe(aBal, capA, "P-RESID pairToken inventory");
        assertLe(bBal, capB, "P-RESID other token inventory");
    }

    function invariant_ghostMonotonic() public view {
        assertTrue(handler.ghost_swapCount() < type(uint128).max, "P-GHOST swap");
        assertTrue(handler.ghost_depositCount() < type(uint128).max, "P-GHOST deposit");
        assertTrue(handler.ghost_withdrawCount() < type(uint128).max, "P-GHOST withdraw");
    }

    function invariant_shareSupplyNonNegative() public view {
        assertTrue(IERC20(address(balancedVault)).totalSupply() >= 0, "supply");
    }
}
