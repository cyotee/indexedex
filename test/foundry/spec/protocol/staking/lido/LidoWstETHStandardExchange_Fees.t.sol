// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_LidoWstETHStandardExchange} from
    "contracts/test/bases/TestBase_LidoWstETHStandardExchange.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {ILidoWstETHStandardVault} from
    "contracts/protocols/staking/lido/interfaces/ILidoWstETHStandardVault.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";

/**
 * @title LidoWstETHStandardExchange_Fees_Test
 * @notice F1/F2: usage fee shares mint to feeTo when type/vault fee > 0; none when 0.
 */
contract LidoWstETHStandardExchange_Fees_Test is TestBase_LidoWstETHStandardExchange {
    function test_F1_usageFee_mintsSharesToFeeTo() public {
        bytes4 typeId = type(ILidoWstETHStandardVault).interfaceId;
        uint256 feePct = 0.10e18; // 10%
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFeeOfTypeId(typeId, feePct);

        // Ensure vault resolves non-zero usage fee via type id (usage fee id of vault)
        uint256 resolved = IVaultFeeOracleQuery(address(indexedexManager)).usageFeeOfVault(seVault);
        // If registry type id not yet linked for this vault, set vault override
        if (resolved == 0) {
            vm.prank(owner);
            IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seVault, feePct);
            resolved = IVaultFeeOracleQuery(address(indexedexManager)).usageFeeOfVault(seVault);
        }
        assertEq(resolved, feePct);

        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 feeToBefore = IERC20(seVault).balanceOf(feeTo_);

        uint256 amount = 10 ether;
        _dealWeth(address(this), amount);
        hermeticWeth.approve(seVault, amount);
        uint256 userShares = seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            amount,
            IERC20(seVault),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        );

        uint256 expectedFee = BetterMath._percentageOfWAD(userShares, feePct);
        assertGt(expectedFee, 0);
        assertEq(IERC20(seVault).balanceOf(feeTo_) - feeToBefore, expectedFee);
        assertEq(IERC20(seVault).balanceOf(address(this)), userShares);
    }

    function test_F2_usageFeeZero_noFeeShares() public {
        // Oracle: stored 0 = unset and falls back; set all tiers to 0 so effective fee is 0.
        bytes4 typeId = type(ILidoWstETHStandardVault).interfaceId;
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seVault, 0);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFeeOfTypeId(typeId, 0);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        vm.stopPrank();

        assertEq(IVaultFeeOracleQuery(address(indexedexManager)).usageFeeOfVault(seVault), 0);

        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 feeToBefore = IERC20(seVault).balanceOf(feeTo_);

        uint256 amount = 5 ether;
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

        assertEq(IERC20(seVault).balanceOf(feeTo_), feeToBefore);
    }
}
