// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_RocketPoolRETHStandardExchange} from "contracts/test/bases/TestBase_RocketPoolRETHStandardExchange.sol";
import {P4Handler, P4Invariants, IP4Host, P4Wallet} from "./P4Common.sol";

/// dz-rocket-honest-loss: isolate the P4_Rocket_Invariant invariant_honestNoLoss break
/// (deep campaign, fuzz seed 0x835ec620..., shrunk 3 calls):
///   advDonate(6.167e76, 25e18, true) -> advRateMove(4.405e76) -> advPretransferMintOutSweep(20447, 224, 4294967295)
contract DZ_RocketHonestLoss is TestBase_RocketPoolRETHStandardExchange, P4Invariants, IP4Host {
    P4Handler internal handler;
    bool internal bookedOnly; // corrected valuation: count only booked reserves in fairNav

    function _h() internal view override returns (P4Handler) { return handler; }

    function setUp() public override {
        super.setUp();
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seVault, 0);
        vm.stopPrank();
        hermeticReth.setRate(1.1e18);
        _enableBurn(1_000_000 ether);
        handler = new P4Handler(IP4Host(address(this)));
        handler.mintExactIn(0, 0, 100 ether);
        handler.mintExactIn(3 * 1000, 1, 100 ether);
    }

    // ---------------- IP4Host (identical to P4_Rocket_Invariant, plus optional booked-only fairNav)
    function se() external view returns (address) { return seVault; }
    function tokens() public view returns (address[] memory t) {
        t = new address[](2);
        t[0] = address(hermeticWeth);
        t[1] = address(hermeticReth);
    }
    function fund(address token, address to, uint256 amount) external {
        if (token == address(hermeticWeth)) {
            vm.deal(address(this), amount);
            hermeticWeth.deposit{value: amount}();
            hermeticWeth.transfer(to, amount);
        } else {
            hermeticReth.mint(to, amount);
        }
    }
    function fairValue(address token, uint256 amount) public view returns (uint256) {
        if (token == address(hermeticReth)) return hermeticReth.getEthValue(amount);
        return amount;
    }
    function portPending() external pure returns (uint256, uint256) { return (0, 0); }
    function fairNav() public view returns (uint256) {
        if (bookedOnly) {
            return IBasicVault(seVault).reserveOfToken(address(hermeticWeth))
                + hermeticReth.getEthValue(IBasicVault(seVault).reserveOfToken(address(hermeticReth)));
        }
        return hermeticWeth.balanceOf(seVault) + hermeticReth.getEthValue(hermeticReth.balanceOf(seVault));
    }
    function reportedNav() external view returns (uint256) { return rocketPoolSe.totalReserveEth(); }
    function virtShares() external pure returns (uint256) { return 1e3; }
    function navPlus() external pure returns (uint256) { return 1; }
    function outCap(address token) external view returns (uint256) { return IERC20(token).balanceOf(seVault); }
    function bare() external pure returns (address) { return address(0); }
    function hasQueue() external pure returns (bool) { return false; }
    function hasRebalance() external pure returns (bool) { return true; }
    function supportsSwap() external pure returns (bool) { return true; }
    function has4626Mutators() external pure returns (bool) { return false; }
    function finalizeAll() external {}
    function moveRate(uint256 seed) external returns (bool) {
        uint256 cur = hermeticReth.rateWad();
        uint256 nr = cur * bound(seed, 9_700, 10_300) / 10_000;
        if (nr < 0.9e18 || nr > 1.5e18) return false;
        hermeticReth.setRate(nr);
        return true;
    }

    // ---------------- helpers
    function _unbookedReth() internal view returns (uint256) {
        uint256 b = hermeticReth.balanceOf(seVault);
        uint256 r = IBasicVault(seVault).reserveOfToken(address(hermeticReth));
        return b > r ? b - r : 0;
    }

    /// honest actor 0's redeemable claim: shares priced off BOOKED reserves only
    function _honestBookedClaim() internal view returns (uint256) {
        uint256 sh = IERC20(seVault).balanceOf(handler.wallet(0));
        uint256 nav = IBasicVault(seVault).reserveOfToken(address(hermeticWeth))
            + hermeticReth.getEthValue(IBasicVault(seVault).reserveOfToken(address(hermeticReth)));
        return sh * (nav + 1) / (IERC20(seVault).totalSupply() + 1e3);
    }

    function _log(string memory step) internal view {
        console2.log("----", step);
        console2.log("  rate", hermeticReth.rateWad());
        console2.log("  unbooked rETH on vault", _unbookedReth());
        console2.log("  honest0 shares", IERC20(seVault).balanceOf(handler.wallet(0)));
        console2.log("  honest0 booked claim (ETH)", _honestBookedClaim());
        console2.log("  honest0 netGain (harness)"); console2.logInt(handler.netGain(0));
        console2.log("  adversary netGain (harness)"); console2.logInt(handler.netGain(3));
        console2.log("  adversary rETH wallet", hermeticReth.balanceOf(handler.wallet(3)));
    }

    function _replay() internal returns (uint256 claim0, uint256 rate0) {
        _log("seed");
        claim0 = _honestBookedClaim();
        rate0 = hermeticReth.rateWad();
        handler.advDonate(61678357398080765210293718086378416697372618187842506566286863523773954249005, 25e18, true);
        _log("after advDonate (adversary sends 20 rETH raw to vault, unbooked)");
        handler.advRateMove(44051847673791738410873509258043689323436256647277953205199071860345419071541);
        _log("after advRateMove");
        handler.advPretransferMintOutSweep(20447, 224, 4294967295);
        _log("after advPretransferMintOutSweep (exact-out credit refunds the unbooked rETH to adversary)");
    }

    /// 1) The fuzz break reproduces deterministically with the harness's raw-balance fairNav.
    function test_replay_shrunk_reproduces() public {
        (uint256 claim0, uint256 rate0) = _replay();
        int256 g0 = handler.netGain(0);
        int256 gA = handler.netGain(3);
        console2.log("honest0 netGain"); console2.logInt(g0);
        console2.log("adversary netGain"); console2.logInt(gA);
        assertLt(g0, -int256(VALUE_TOL), "harness flags honest loss");
        // ... but honest0's real, booked claim only moved by the rate move on ITS OWN rETH.
        uint256 claim1 = _honestBookedClaim();
        console2.log("honest0 booked claim before / after", claim0, claim1);
        console2.log("rate before / after", rate0, hermeticReth.rateWad());
        assertEq(_unbookedReth(), 0, "adversary swept back its own donation");
    }

    /// 2) Same sequence, valuing the vault on BOOKED reserves only (what honest shares can actually claim
    ///    once the donor reclaims it): honest loss disappears, adversary profit is 0.
    function test_replay_bookedValuation_noHonestLoss() public {
        bookedOnly = true;
        _replay();
        int256 g0 = handler.netGain(0);
        int256 gA = handler.netGain(3);
        console2.log("booked-valuation honest0 netGain"); console2.logInt(g0);
        console2.log("booked-valuation adversary netGain"); console2.logInt(gA);
        assertGe(g0, -int256(VALUE_TOL), "no honest loss under booked valuation");
        // The adversary's residual "gain" is exactly the rETH rate appreciation on ITS OWN 5 rETH that sat
        // unbooked on the vault during the rate move (exogenous, not extracted from anyone).
        int256 ownAppreciation = int256(5 ether * (1.1198e18 - 1.1e18) / 1e18);
        console2.log("own-donation appreciation"); console2.logInt(ownAppreciation);
        assertApproxEqAbs(gA, ownAppreciation, 1e6, "adversary gain == appreciation of its own donated rETH");
    }

    /// 3) Can the reversible donation be weaponised? Attacker (existing LP) donates rETH, honest user mints
    ///    at the inflated NAV, attacker tries to reclaim via pretransfer exact-out credit.
    P4Wallet internal aw;
    address internal victim;
    uint256 internal vSh;
    uint256 internal aVal0;
    uint256 internal aCost;

    function _attackerValue() internal view returns (uint256) {
        address a = address(aw);
        return IERC20(seVault).balanceOf(a) * (rocketPoolSe.totalReserveEth() + 1) / (IERC20(seVault).totalSupply() + 1e3)
            + hermeticReth.getEthValue(hermeticReth.balanceOf(a)) + hermeticWeth.balanceOf(a);
    }

    function _setupAttackerLp() internal {
        aw = new P4Wallet(); // attacker contract (controller = this test acting as attacker EOA)
        victim = makeAddr("victim");
        _dealWeth(address(this), 100 ether);
        hermeticWeth.transfer(address(aw), 100 ether);
        aw.exec(address(hermeticWeth), abi.encodeCall(IERC20.approve, (seVault, type(uint256).max)));
        aw.exec(seVault, abi.encodeCall(IStandardExchangeIn.exchangeIn, (IERC20(address(hermeticWeth)), 100 ether, IERC20(seVault), 0, address(aw), false, block.timestamp)));
        aVal0 = _attackerValue();
    }

    function _frontrunDonate(uint256 D) internal {
        hermeticReth.mint(address(aw), D);
        aCost += hermeticReth.getEthValue(D);
        aw.exec(address(hermeticReth), abi.encodeCall(IERC20.transfer, (seVault, D)));
    }

    function _victimMint(uint256 X) internal {
        _dealWeth(victim, X);
        vm.startPrank(victim);
        hermeticWeth.approve(seVault, X);vSh = IStandardExchangeIn(seVault).exchangeIn(IERC20(address(hermeticWeth)), X, IERC20(seVault), 0, victim, false, block.timestamp);
        vm.stopPrank();
    }

    function _backrunReclaim() internal returns (bool ok, uint256 refunded) {
        hermeticReth.mint(address(aw), 1e15);
        aCost += hermeticReth.getEthValue(1e15);
        uint256 rB = hermeticReth.balanceOf(address(aw));
        bytes memory consume = abi.encodeCall(
            IStandardExchangeOut.exchangeOut,
            (IERC20(address(hermeticReth)), type(uint256).max, IERC20(seVault), 1e9, address(aw), true, block.timestamp)
        );
        try aw.exec2(address(hermeticReth), abi.encodeCall(IERC20.transfer, (seVault, 1e15)), seVault, consume) { ok = true; } catch {}
        uint256 rA = hermeticReth.balanceOf(address(aw));
        refunded = rA > rB ? rA - rB : 0;
    }

    function test_sandwich_honestMint_refuted() public {
        uint256 X = 100 ether;
        _setupAttackerLp();
        _frontrunDonate(20 ether);
        _victimMint(X);
        console2.log("unbooked rETH after victim mint", _unbookedReth());
        (bool ok, uint256 refunded) = _backrunReclaim();
        console2.log("reclaim call ok / rETH refunded to attacker", ok ? 1 : 0, refunded);
        uint256 vVal = vSh * (rocketPoolSe.totalReserveEth() + 1) / (IERC20(seVault).totalSupply() + 1e3);
        uint256 aVal1 = _attackerValue();
        console2.log("victim paid / victim share value", X, vVal);
        console2.log("attacker value before+cost / after", aVal0 + aCost, aVal1);
        assertGe(vVal + 1e6, X, "victim not harmed: donation was booked by the victim's own op");
        assertLe(aVal1, aVal0 + aCost, "attacker cannot profit");
    }

    /// 4) Control: with no honest op in between, the donor gets its donation back in full (self-refund).
    function test_selfRefund_noHonestOp() public {
        _setupAttackerLp();
        _frontrunDonate(20 ether);
        (bool ok, uint256 refunded) = _backrunReclaim();
        console2.log("self-reclaim ok / refunded", ok ? 1 : 0, refunded);
        assertTrue(ok);
        assertApproxEqAbs(refunded, 20 ether, 1e15, "donor reclaims own donation");
    }
}
