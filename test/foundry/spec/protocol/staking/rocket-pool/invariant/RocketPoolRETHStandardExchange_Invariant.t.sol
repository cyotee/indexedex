// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_RocketPoolRETHStandardExchange} from
    "contracts/test/bases/TestBase_RocketPoolRETHStandardExchange.sol";
import {
    IRocketPoolRETHStandardVault
} from "contracts/protocols/staking/rocket-pool/interfaces/IRocketPoolRETHStandardVault.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IRocketPoolRETHRebalance} from
    "contracts/protocols/staking/rocket-pool/interfaces/IRocketPoolRETHStandardVault.sol";

/**
 * @dev Handler for RP rETH SE invariants (production vault + hermetic ports).
 */
contract RocketPoolRETHHandler {
    TestBase_RocketPoolRETHStandardExchange public immutable base;
    address public immutable seVault;
    IStandardExchangeIn public immutable seIn;
    IStandardExchangeOut public immutable seOut;
    IRocketPoolRETHRebalance public immutable seRebalance;
    IRocketPoolRETHStandardVault public immutable se;

    constructor(TestBase_RocketPoolRETHStandardExchange base_) {
        base = base_;
        seVault = base.seVault();
        seIn = base.seIn();
        seOut = base.seOut();
        seRebalance = base.seRebalance();
        se = base.rocketPoolSe();
    }

    function exchangeInWethToSe(uint256 amount) external {
        amount = bound(amount, 0.01 ether, 50 ether);
        base._dealWeth(address(this), amount);
        base.hermeticWeth().approve(seVault, amount);
        try seIn.exchangeIn(
            IERC20(address(base.hermeticWeth())),
            amount,
            IERC20(seVault),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        ) {} catch {}
    }

    function exchangeInRethToSe(uint256 amount) external {
        amount = bound(amount, 0.01 ether, 50 ether);
        base._mintReth(address(this), amount);
        base.hermeticReth().approve(seVault, amount);
        try seIn.exchangeIn(
            IERC20(address(base.hermeticReth())),
            amount,
            IERC20(seVault),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        ) {} catch {}
    }

    function rebalance() external {
        try seRebalance.rebalance() {} catch {}
    }

    function setCapacity(uint256 maxDep) external {
        maxDep = bound(maxDep, 0, 100 ether);
        base.hermeticPool().setMaxDepositAmount(maxDep);
    }

    function donateWeth(uint256 amount) external {
        amount = bound(amount, 0, 5 ether);
        if (amount == 0) return;
        base._fundSleeve(amount);
    }

    function bound(uint256 x, uint256 min, uint256 max) internal pure returns (uint256) {
        if (max <= min) return min;
        return min + (x % (max - min + 1));
    }
}

/**
 * @title RocketPoolRETHStandardExchange_Invariant_Test
 * @notice Invariants: reserve accounting, liquid = WETH bal, capacity 0 no phantom rETH.
 */
contract RocketPoolRETHStandardExchange_Invariant_Test is TestBase_RocketPoolRETHStandardExchange {
    RocketPoolRETHHandler internal handler;

    function setUp() public override {
        super.setUp();
        handler = new RocketPoolRETHHandler(this);
        targetContract(address(handler));
    }

    function invariant_I1_totalReserveEqLiquidPlusLocked() public view {
        assertEq(
            rocketPoolSe.totalReserveEth(),
            rocketPoolSe.liquidReserveEth() + rocketPoolSe.lockedReserveEth()
        );
    }

    function invariant_I2_liquidEqWethBalance() public view {
        assertEq(rocketPoolSe.liquidReserveEth(), hermeticWeth.balanceOf(seVault));
    }

    function invariant_I10_capacity0_noPhantomRethOnWethSe() public {
        // Snapshot: if capacity is 0 and only WETH was deposited, rETH shouldn't appear without stake
        // Soft property: locked eth face matches getEthValue of vault rETH balance always
        uint256 rethBal = hermeticReth.balanceOf(seVault);
        assertEq(rocketPoolSe.lockedReserveEth(), hermeticReth.getEthValue(rethBal));
    }
}
