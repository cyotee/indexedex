// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {TestBase_EtherFiWeETHStandardExchange} from
    "contracts/test/bases/TestBase_EtherFiWeETHStandardExchange.sol";
import {
    IEtherFiWeETHStandardVault
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWeETHStandardVault.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {
    EtherFiWeETHStandardExchangeCommon
} from "contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeCommon.sol";
import {
    HostileWETH
} from "contracts/protocols/staking/etherfi/test/hermetic/HostileWETH.sol";
import {
    HermeticEETH,
    HermeticWeETH,
    HermeticLiquidityPool,
    HermeticWithdrawRequestNFT,
    HermeticRedemptionManager
} from "contracts/protocols/staking/etherfi/test/hermetic/HermeticEtherFiPorts.sol";

/**
 * @title Adversarial_EtherFiWeETH_P0_Test
 * @notice P0 adversarial: donation, reentrancy IsLocked, sleeve grief, queue claim theft.
 */
contract Adversarial_EtherFiWeETH_P0_Test is TestBase_EtherFiWeETHStandardExchange {
    address internal attacker;
    address internal victim;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
    }

    function test_A0_pretransferredTrue_noBalanceDelta_revertsAndNoMint() public {
        _seedVaultInventory(10 ether, 10 ether);
        uint256 supplyBefore = IERC20(seVault).totalSupply();
        uint256 attackerBefore = IERC20(seVault).balanceOf(attacker);
        uint256 sleeveBefore = etherFiSe.liquidReserveEth();

        uint256 fakeIn = 1 ether;
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(EtherFiWeETHStandardExchangeCommon.InsufficientDeposit.selector, fakeIn, 0)
        );
        seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            fakeIn,
            IERC20(seVault),
            0,
            attacker,
            true,
            block.timestamp + 1 hours
        );

        assertEq(IERC20(seVault).totalSupply(), supplyBefore);
        assertEq(IERC20(seVault).balanceOf(attacker), attackerBefore);
        assertEq(etherFiSe.liquidReserveEth(), sleeveBefore);
    }

    function test_A1_donateWeth_noFreeMint() public {
        _seedVaultInventory(10 ether, 10 ether);
        uint256 supplyBefore = IERC20(seVault).totalSupply();

        _dealWeth(attacker, 5 ether);
        vm.prank(attacker);
        hermeticWeth.transfer(seVault, 5 ether);

        assertEq(IERC20(seVault).balanceOf(attacker), 0);
        assertEq(IERC20(seVault).totalSupply(), supplyBefore);

        uint256 mintIn = 1 ether;
        _dealWeth(victim, mintIn);
        vm.startPrank(victim);
        hermeticWeth.approve(seVault, mintIn);
        uint256 shares = seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            mintIn,
            IERC20(seVault),
            1,
            victim,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(shares, 0);
        uint256 supply = IERC20(seVault).totalSupply();
        uint256 claimEth = (shares * etherFiSe.totalReserveEth()) / supply;
        assertLe(claimEth, mintIn + mintIn / 10, "donation must not free-mint NAV to victim");
        assertGe(claimEth, mintIn / 2, "victim keeps fair claim on own deposit");
    }

    function test_A2_donateWeEth_noFreeMint() public {
        _seedVaultInventory(5 ether, 10 ether);
        uint256 supplyBefore = IERC20(seVault).totalSupply();
        _mintWeViaE(attacker, 5 ether);
        vm.prank(attacker);
        hermeticWeEth.transfer(seVault, 5 ether);
        assertEq(IERC20(seVault).balanceOf(attacker), 0);
        assertEq(IERC20(seVault).totalSupply(), supplyBefore);
    }

    function test_H1_emptySleeve_revertsWithArgs() public {
        _seedVaultInventory(0, 20 ether);
        assertEq(etherFiSe.liquidReserveEth(), 0);
        uint256 requested = 1 ether;
        vm.expectRevert(
            abi.encodeWithSelector(IEtherFiWeETHStandardVault.InsufficientLiquidReserve.selector, requested, 0)
        );
        seOut.exchangeOut(
            IERC20(seVault),
            type(uint256).max,
            IERC20(address(hermeticWeth)),
            requested,
            address(this),
            false,
            block.timestamp + 1 hours
        );
    }

    function test_H3_minOutFail_fullRevert() public {
        uint256 amount = 2 ether;
        _dealWeth(address(this), amount);
        hermeticWeth.approve(seVault, amount);
        uint256 preview = seIn.previewExchangeIn(IERC20(address(hermeticWeth)), amount, IERC20(seVault));
        vm.expectRevert(IEtherFiWeETHStandardVault.Slippage.selector);
        seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            amount,
            IERC20(seVault),
            preview + 1,
            address(this),
            false,
            block.timestamp + 1 hours
        );
    }

    function test_S1_drainSleeve_thenFail() public {
        _seedVaultInventory(0, 20 ether);
        _fundSleeve(5 ether);
        uint256 available = etherFiSe.liquidReserveEth();
        uint256 sharesIn = seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), available);
        seOut.exchangeOut(
            IERC20(seVault),
            sharesIn,
            IERC20(address(hermeticWeth)),
            available,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertEq(etherFiSe.liquidReserveEth(), 0);
        vm.expectRevert(
            abi.encodeWithSelector(IEtherFiWeETHStandardVault.InsufficientLiquidReserve.selector, 1, 0)
        );
        seOut.exchangeOut(
            IERC20(seVault),
            type(uint256).max,
            IERC20(address(hermeticWeth)),
            1,
            address(this),
            false,
            block.timestamp + 1 hours
        );
    }

    function test_S2_wethOut_doesNotSpendWeViaQueue() public {
        _seedVaultInventory(0, 15 ether);
        _fundSleeve(3 ether);
        uint256 weBefore = hermeticWeEth.balanceOf(seVault);
        uint256 reqBefore = hermeticQueue.lastRequestId();
        uint256 outAmt = 1 ether;
        uint256 inShares = seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), outAmt);
        seOut.exchangeOut(
            IERC20(seVault),
            inShares,
            IERC20(address(hermeticWeth)),
            outAmt,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        // sleeve pay only - weETH inventory and queue unchanged
        assertEq(hermeticWeEth.balanceOf(seVault), weBefore);
        assertEq(hermeticQueue.lastRequestId(), reqBefore);
    }

    function test_R_route_nativeEth_invalidRoute() public {
        _seedVaultInventory(2 ether, 2 ether);
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, seVault, address(0))
        );
        seOut.exchangeOut(
            IERC20(seVault),
            type(uint256).max,
            IERC20(address(0)),
            1 ether,
            address(this),
            false,
            block.timestamp + 1 hours
        );
    }

    function test_E1_roundTrip_wethSe_conservation() public {
        // Round-trip only the liquid sleeve portion (split mint stakes rest as weETH).
        uint256 amount = 10 ether;
        _dealWeth(address(this), amount);
        hermeticWeth.approve(seVault, amount);
        uint256 shares = seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            amount,
            IERC20(seVault),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        uint256 liquid = etherFiSe.liquidReserveEth();
        assertGt(liquid, 0);
        assertLt(liquid, amount); // split staked overage

        uint256 needShares =
            seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), liquid);
        uint256 balBefore = hermeticWeth.balanceOf(address(this));
        seOut.exchangeOut(
            IERC20(seVault),
            shares >= needShares ? shares : needShares,
            IERC20(address(hermeticWeth)),
            liquid,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        uint256 got = hermeticWeth.balanceOf(address(this)) - balBefore;
        assertEq(got, liquid);
        // Remaining SE value is locked weETH inventory (no free mint)
        assertGt(IERC20(seVault).balanceOf(address(this)), 0);
        assertGt(hermeticWeEth.balanceOf(seVault), 0);
    }

    function test_E2_roundTrip_weSe_conservation() public {
        uint256 amount = 5 ether;
        _mintWeViaE(address(this), amount);
        hermeticWeEth.approve(seVault, amount);
        uint256 shares = seIn.exchangeIn(
            IERC20(address(hermeticWeEth)),
            amount,
            IERC20(seVault),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        uint256 preview = seIn.previewExchangeIn(IERC20(seVault), shares, IERC20(address(hermeticWeEth)));
        uint256 balBefore = hermeticWeEth.balanceOf(address(this));
        seIn.exchangeIn(
            IERC20(seVault),
            shares,
            IERC20(address(hermeticWeEth)),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        uint256 got = hermeticWeEth.balanceOf(address(this)) - balBefore;
        assertApproxEqRel(got, preview, 0.01e18);
        assertLe(got, amount + 1);
    }

    function test_E5_zeroAmount_deadline() public {
        vm.expectRevert(IEtherFiWeETHStandardVault.ZeroAmount.selector);
        seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            0,
            IERC20(seVault),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        );

        vm.warp(block.timestamp + 2 hours);
        _dealWeth(address(this), 1 ether);
        hermeticWeth.approve(seVault, 1 ether);
        vm.expectRevert(IEtherFiWeETHStandardVault.DeadlineExpired.selector);
        seIn.exchangeIn(
            IERC20(address(hermeticWeth)),
            1 ether,
            IERC20(seVault),
            0,
            address(this),
            false,
            block.timestamp - 1
        );
    }

    function test_Q1_claimTheft_reverts() public {
        _seedVaultInventory(0, 50 ether);
        _fundSleeve(0.1 ether);
        seRebalance.rebalance();
        uint256 reqId = hermeticQueue.lastRequestId();
        if (reqId == 0) return;
        (/*o*/, uint256 face, /*f*/, /*c*/) = hermeticQueue.requests(reqId);
        vm.deal(address(this), face);
        hermeticQueue.finalizeForTest{value: face}(reqId);
        vm.prank(attacker);
        vm.expectRevert("not owner");
        hermeticQueue.claimWithdraw(reqId);
    }

    function test_Q2_doubleClaim_reverts() public {
        _seedVaultInventory(0, 50 ether);
        _fundSleeve(0.1 ether);
        seRebalance.rebalance();
        uint256 reqId = hermeticQueue.lastRequestId();
        if (reqId == 0) return;
        (/*o*/, uint256 face, /*f*/, /*c*/) = hermeticQueue.requests(reqId);
        vm.deal(address(this), face);
        hermeticQueue.finalizeForTest{value: face}(reqId);
        seRebalance.rebalance(); // first claim
        // second claim attempt on cleared/claimed request
        vm.expectRevert();
        hermeticQueue.claimWithdraw(reqId);
    }

    /// @dev C1: reenter exchangeIn during WETH transferFrom → IsLocked (nested fails, outer succeeds)
    function test_C1_reentrancy_exchangeIn_IsLocked() public {
        (HostileWETH hostile, address vault) = _deployHostileVault();
        IStandardExchangeIn vin = IStandardExchangeIn(vault);

        uint256 amount = 1 ether;
        vm.deal(attacker, amount);
        vm.prank(attacker);
        hostile.deposit{value: amount}();

        hostile.arm(
            vault,
            abi.encodeWithSelector(
                IStandardExchangeIn.exchangeIn.selector,
                IERC20(address(hostile)),
                amount,
                IERC20(vault),
                0,
                attacker,
                true,
                block.timestamp + 1 hours
            )
        );

        vm.startPrank(attacker);
        hostile.approve(vault, amount);
        uint256 shares = vin.exchangeIn(
            IERC20(address(hostile)), amount, IERC20(vault), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertGt(shares, 0);
        assertEq(hostile.reentryAttempts(), 1);
        assertFalse(hostile.nestedCallSucceeded());
        assertEq(hostile.nestedErrorSelector(), IReentrancyLock.IsLocked.selector);
    }

    /// @dev C2: reenter exchangeOut during WETH transfer out → IsLocked
    function test_C2_reentrancy_exchangeOut_IsLocked() public {
        (HostileWETH hostile, address vault) = _deployHostileVault();
        IStandardExchangeIn vin = IStandardExchangeIn(vault);
        IStandardExchangeOut vout = IStandardExchangeOut(vault);

        uint256 seed = 5 ether;
        vm.deal(attacker, seed);
        vm.prank(attacker);
        hostile.deposit{value: seed}();
        vm.startPrank(attacker);
        hostile.approve(vault, seed);
        uint256 shares = vin.exchangeIn(
            IERC20(address(hostile)), seed, IERC20(vault), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        // Ensure sleeve can pay 0.5 ETH
        if (IEtherFiWeETHStandardVault(vault).liquidReserveEth() < 0.5 ether) {
            vm.deal(address(this), 2 ether);
            hostile.deposit{value: 2 ether}();
            hostile.transfer(vault, 2 ether);
        }
        uint256 outAmt = 0.5 ether;

        hostile.arm(
            vault,
            abi.encodeWithSelector(
                IStandardExchangeOut.exchangeOut.selector,
                IERC20(vault),
                shares,
                IERC20(address(hostile)),
                outAmt,
                attacker,
                false,
                block.timestamp + 1 hours
            )
        );

        vm.prank(attacker);
        assertGt(
            vout.exchangeOut(
                IERC20(vault), shares, IERC20(address(hostile)), outAmt, attacker, false, block.timestamp + 1 hours
            ),
            0
        );
        assertEq(hostile.reentryAttempts(), 1);
        assertFalse(hostile.nestedCallSucceeded());
        assertEq(hostile.nestedErrorSelector(), IReentrancyLock.IsLocked.selector);
    }

    function _deployHostileVault() internal returns (HostileWETH hostile, address vault) {
        hostile = new HostileWETH();
        HermeticEETH e = new HermeticEETH();
        HermeticWeETH we = new HermeticWeETH(e);
        HermeticLiquidityPool pool = new HermeticLiquidityPool(e);
        pool.setWeETH(we);
        HermeticWithdrawRequestNFT q = new HermeticWithdrawRequestNFT();
        pool.setWithdrawNFT(q);
        HermeticRedemptionManager r = new HermeticRedemptionManager(we);
        vm.prank(owner);
        vault = etherFiSeDFPkg.deployVault(
            address(e), address(we), address(hostile), address(pool), address(q), address(r)
        );
    }
}

