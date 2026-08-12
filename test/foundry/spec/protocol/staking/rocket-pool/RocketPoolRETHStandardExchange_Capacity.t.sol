// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_RocketPoolRETHStandardExchange} from
    "contracts/test/bases/TestBase_RocketPoolRETHStandardExchange.sol";
import {
    IRocketPoolRETHStandardVault
} from "contracts/protocols/staking/rocket-pool/interfaces/IRocketPoolRETHStandardVault.sol";

/**
 * @title RocketPoolRETHStandardExchange_Capacity_Test
 * @notice Soft WETH→SE vs hard WETH→rETH capacity duality.
 */
contract RocketPoolRETHStandardExchange_Capacity_Test is TestBase_RocketPoolRETHStandardExchange {
    function test_H1_wethToReth_capacity0_revertsExact() public {
        hermeticPool.setMaxDepositAmount(0);
        uint256 amount = 2 ether;
        _dealWeth(address(this), amount);
        hermeticWeth.approve(seVault, amount);

        // Preview still non-zero (ungated)
        uint256 preview = seIn.previewExchangeIn(
            IERC20(address(hermeticWeth)), amount, IERC20(address(hermeticReth))
        );
        assertGt(preview, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IRocketPoolRETHStandardVault.InsufficientDepositCapacity.selector, 0, amount
            )
        );
        seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            amount,
            IERC20(address(hermeticReth)),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        );
    }

    function test_H2_wethToReth_capacityOpen_previewEqExec() public {
        hermeticPool.setMaxDepositAmount(type(uint256).max);
        uint256 amount = 4 ether;
        _dealWeth(address(this), amount);
        hermeticWeth.approve(seVault, amount);
        uint256 preview = seIn.previewExchangeIn(
            IERC20(address(hermeticWeth)), amount, IERC20(address(hermeticReth))
        );
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            amount,
            IERC20(address(hermeticReth)),
            preview,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview);
    }

    function test_S3_capacity0_wethToSe_doesNotHardFail() public {
        hermeticPool.setMaxDepositAmount(0);
        uint256 amount = 10 ether;
        _dealWeth(address(this), amount);
        hermeticWeth.approve(seVault, amount);
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            amount,
            IERC20(seVault),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertGt(out, 0);
        assertEq(rocketPoolSe.liquidReserveEth(), amount);
        assertEq(hermeticReth.balanceOf(seVault), 0);
    }

    function test_S4_capacity0_wethToReth_hardFail_noPartial() public {
        hermeticPool.setMaxDepositAmount(0);
        uint256 amount = 3 ether;
        _dealWeth(address(this), amount);
        hermeticWeth.approve(seVault, amount);
        uint256 rethBefore = hermeticReth.balanceOf(address(this));
        uint256 wethBefore = hermeticWeth.balanceOf(address(this));

        vm.expectRevert(
            abi.encodeWithSelector(
                IRocketPoolRETHStandardVault.InsufficientDepositCapacity.selector, 0, amount
            )
        );
        seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            amount,
            IERC20(address(hermeticReth)),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        );

        // Full revert: balances unchanged
        assertEq(hermeticReth.balanceOf(address(this)), rethBefore);
        assertEq(hermeticWeth.balanceOf(address(this)), wethBefore);
    }

    function test_partialCapacity_softStakeCaps() public {
        // Capacity only 10 eth; deposit 100 → mint SE, stake only 10 of overage path
        hermeticPool.setMaxDepositAmount(10 ether);
        uint256 amount = 100 ether;
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
        // Target liquid = 20; excess = 80; stakeable = 10 → liquid ≈ 90, some rETH locked
        assertGt(hermeticReth.balanceOf(seVault), 0);
        assertGt(rocketPoolSe.liquidReserveEth(), 20 ether);
        assertLt(rocketPoolSe.liquidReserveEth(), amount);
    }
}
