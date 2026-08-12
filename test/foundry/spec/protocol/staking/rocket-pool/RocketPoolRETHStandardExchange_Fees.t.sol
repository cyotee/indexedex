// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_RocketPoolRETHStandardExchange} from
    "contracts/test/bases/TestBase_RocketPoolRETHStandardExchange.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

/**
 * @title RocketPoolRETHStandardExchange_Fees_Test
 * @notice Usage fee + liquid % oracle smoke.
 */
contract RocketPoolRETHStandardExchange_Fees_Test is TestBase_RocketPoolRETHStandardExchange {
    function test_F1_usageFee_zeroVsNonZero() public {
        // Default usage fee 0
        uint256 amount = 10 ether;
        _dealWeth(address(this), amount);
        hermeticWeth.approve(seVault, amount);
        seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            amount,
            IERC20(seVault),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        address feeTo = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 feeBal0 = feeTo == address(0) ? 0 : IERC20(seVault).balanceOf(feeTo);

        // Set usage fee 1% on this vault
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seVault, 0.01e18);

        _dealWeth(address(this), amount);
        hermeticWeth.approve(seVault, amount);
        seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            amount,
            IERC20(seVault),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        if (feeTo != address(0)) {
            assertGt(IERC20(seVault).balanceOf(feeTo), feeBal0);
        }
    }

    function test_F3_defaultLiquid20pct() public view {
        assertEq(
            IVaultFeeOracleQuery(address(indexedexManager)).liquidReservePercentageOfVault(seVault),
            DEFAULT_LIQUID_PCT
        );
        assertEq(rocketPoolSe.targetLiquidReservePercentage(), DEFAULT_LIQUID_PCT);
    }
}
