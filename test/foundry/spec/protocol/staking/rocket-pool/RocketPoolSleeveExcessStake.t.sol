// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_RocketPoolRETHStandardExchange} from
    "contracts/test/bases/TestBase_RocketPoolRETHStandardExchange.sol";

/// @notice RC-05: production SE credits accumulate in the existing WETH sleeve.
contract RocketPoolSleeveExcessStake_Test is TestBase_RocketPoolRETHStandardExchange {
    /// @notice Use the registry-deployed SE and configure only its existing protocol port.
    function setUp() public override {
        super.setUp();
        hermeticSettings.setMinimumDeposit(1 ether);
    }

    /// @notice Below-minimum excess stays liquid while the SE issues the quoted shares.
    function test_RC05_belowMinimumCredit_mintsSharesAndRemainsLiquid() public {
        _credit(0.5 ether);
        _assertReserves(0.5 ether, 0, 0.5 ether);
        assertEq(address(hermeticPool).balance, 0, "no standalone small deposit");
    }

    /// @notice Earlier small credits participate in the first depositable sleeve excess.
    function test_RC05_smallCredits_accumulateThenStakeEntireExcess() public {
        _credit(0.5 ether);
        _assertReserves(0.5 ether, 0, 0.5 ether);
        _credit(0.5 ether);
        _assertReserves(1 ether, 0, 1 ether);
        assertEq(address(hermeticPool).balance, 0, "0.8 ether excess is below the minimum");

        uint256 total_ = 1.5 ether;
        uint256 target_ = total_ * DEFAULT_LIQUID_PCT / 1e18;
        uint256 excess_ = total_ - target_;
        assertEq(excess_, 1.2 ether);
        _credit(0.5 ether);
        assertEq(address(hermeticPool).balance, excess_, "one full excess, not a booked-only slice");
        _assertReserves(target_, excess_, total_);
    }

    /// @notice Capacity caps the combined excess and leaves the remainder in the sleeve.
    function test_RC05_accumulatedExcess_stakeIsCappedByMaximumDeposit() public {
        _credit(0.5 ether);
        _credit(0.5 ether);
        hermeticPool.setMaxDepositAmount(1 ether);
        _credit(0.5 ether);
        assertEq(address(hermeticPool).balance, 1 ether, "min(1.2 ether excess, 1 ether capacity)");
        assertEq(hermeticPool.getMaximumDepositAmount(), 0, "capacity used exactly");
        _assertReserves(0.5 ether, 1 ether, 1.5 ether);
    }

    function _credit(uint256 amount_) internal {
        _dealWeth(address(this), amount_);
        hermeticWeth.approve(seVault, amount_);
        uint256 expected_ = seIn.previewExchangeIn(IERC20(address(hermeticWeth)), amount_, IERC20(seVault));
        require(expected_ > 0, "funded credit must mint shares");
        uint256 sharesBefore_ = IERC20(seVault).balanceOf(address(this));
        uint256 inputBefore_ = hermeticWeth.balanceOf(address(this));
        uint256 minted_ = seIn.exchangeIn(IERC20(address(hermeticWeth)), amount_, IERC20(seVault), expected_,
            address(this), false, block.timestamp + 1 hours);
        assertEq(minted_, expected_, "preview equals minted shares");
        assertEq(IERC20(seVault).balanceOf(address(this)) - sharesBefore_, expected_);
        assertEq(inputBefore_ - hermeticWeth.balanceOf(address(this)), amount_);
    }

    function _assertReserves(uint256 liquid_, uint256 staked_, uint256 total_) internal view {
        assertEq(rocketPoolSe.liquidReserveEth(), liquid_, "liquid reserve retained");
        assertEq(hermeticWeth.balanceOf(seVault), liquid_, "liquid reserve is the WETH balance");
        assertEq(hermeticReth.balanceOf(seVault), staked_, "port rate is one ETH per rETH");
        assertEq(rocketPoolSe.totalReserveEth(), total_, "all credits retained in reserves");
    }
}
