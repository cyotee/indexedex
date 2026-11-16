// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4StandardExchangeOrbitalBufferHookMath as HookMath} from
    "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookMath.sol";

import {IUniswapV4StandardExchangeOrbitalBufferHook} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";

contract UniswapV4StandardExchangeOrbitalBufferHook_LiquidityTest is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    function test_sphereNav_highPrecisionIntermediateProduct() public pure {
        _assertSymmetricNavShares(1e28, 1e27);
    }

    function test_sphereNav_highPrecisionNativeUnit() public pure {
        _assertSymmetricNavShares(1e28, 1);
    }

    function testFuzz_sphereNav_symmetricShares(uint256 reserve_, uint256 input_) public view {
        reserve_ = bound(reserve_, 1e27, 1e30);
        input_ = bound(input_, 1, reserve_);
        _assertSymmetricNavShares(reserve_, input_);
    }

    function test_sphereNav_zeroInputStillReverts() public {
        vm.expectRevert(HookMath.MathDomain.selector);
        HookMath.sphereNavShares(3e28, 4e28, 1e28, 1e28, 1e28, 0, 0, 0);
        HookMath.SphereNavArgs memory args_ = HookMath.SphereNavArgs({
            supply: 3e28, R: 4e28, r0Wad: 1e28, r1Wad: 1e28, r2Wad: 1e28,
            used0Wad: 0, used1Wad: 0, used2Wad: 0
        });
        vm.expectRevert(HookMath.MathDomain.selector);
        HookMath.sphereNavShares(args_);
    }

    function _assertSymmetricNavShares(uint256 reserve_, uint256 input_) internal pure {
        // Equal reserves and equal deposits preserve equal ownership. With one
        // LP unit per reserve unit, the three deposits must mint 3 * input.
        assertEq(
            HookMath.sphereNavShares(3 * reserve_, 4 * reserve_, reserve_, reserve_, reserve_, input_, input_, input_),
            3 * input_, "scalar NAV conserves symmetric ownership"
        );
        HookMath.SphereNavArgs memory args_ = HookMath.SphereNavArgs({
            supply: 3 * reserve_, R: 4 * reserve_, r0Wad: reserve_, r1Wad: reserve_, r2Wad: reserve_,
            used0Wad: input_, used1Wad: input_, used2Wad: input_
        });
        assertEq(HookMath.sphereNavShares(args_), 3 * input_, "packed NAV conserves symmetric ownership");
    }

    function test_firstMint_twoLegs_setsR() public {
        (uint256 shares, uint256 u0, uint256 u1, uint256 u2) =
            _addLiquidity(100 ether, 100 ether, 0);
        assertGt(shares, 0, "shares");
        assertEq(u0, 100 ether);
        assertEq(u1, 100 ether);
        assertEq(u2, 0);
        assertGt(orbital.radius(), 0, "R set");
        assertGt(orbital.lSquared(), 0, "L2");
        assertEq(IERC20(hook).balanceOf(user), shares);
    }

    function test_firstMint_threeLegs() public {
        uint256 shares = _seedThreeLeg(100 ether);
        assertGt(shares, 0);
        (uint256 e0, uint256 e1, uint256 e2) = orbital.effectiveReserves();
        // Default config buffers leg0: SE claim of buffer output tracks face (not always 1:1).
        assertGt(e0, 0);
        assertGt(orbital.seBalance(0), 0);
        assertEq(orbital.rawReserve(0), token0.balanceOf(hook));
        assertGt(orbital.rawReserve(0), 0);
        assertEq(e1, 100 ether);
        assertEq(e2, 100 ether);
        assertGt(orbital.radius(), 0);
    }

    function test_firstMint_oneLeg_reverts() public {
        uint256 supplied = _mintSeSharesToUser(se0, token0, 100 ether);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("FirstMintRequiresTwoLegs()"));
        orbital.depositFlexible(supplied, true, 0, false, 0, false, user, 0, block.timestamp + 1 hours);
    }

    function test_fullBook_subsequent_previewEqualsExec() public {
        _seedThreeLeg(200 ether);
        (uint256 pShares, uint256 p0, uint256 p1, uint256 p2) =
            orbital.previewAddLiquidity(50 ether, 50 ether, 50 ether);
        (uint256 eShares, uint256 e0, uint256 e1, uint256 e2) =
            _addLiquidity(50 ether, 50 ether, 50 ether);
        assertEq(eShares, pShares, "shares");
        assertEq(e0, p0);
        assertEq(e1, p1);
        assertEq(e2, p2);
    }

    function test_remove_previewEqualsExec() public {
        uint256 shares = _seedThreeLeg(100 ether);
        uint256 half = shares / 2;
        (uint256 p0, uint256 p1, uint256 p2) = orbital.previewRemoveLiquidity(half);
        vm.prank(user);
        (uint256 a0, uint256 a1, uint256 a2) =
            orbital.removeLiquidity(half, user, 0, 0, 0, block.timestamp + 1 hours);
        assertEq(a0, p0);
        assertEq(a1, p1);
        assertEq(a2, p2);
    }

    function test_partialBook_singleLegPurchasesMissingBasket() public {
        _addLiquidity(100 ether, 100 ether, 0);
        uint256 beforeInput = token2.balanceOf(user);
        uint256 beforeLp = IERC20(hook).balanceOf(user);
        (uint256 quote,,,) = orbital.previewAddLiquidity(0, 0, 50 ether);
        assertGt(quote, 0);
        vm.prank(user);
        (uint256 minted,,,) = orbital.addLiquidity(0, 0, 50 ether, user, quote, block.timestamp, "");
        assertEq(minted, quote);
        assertEq(IERC20(hook).balanceOf(user) - beforeLp, minted);
        assertGt(beforeInput - token2.balanceOf(user), 0);
        assertLe(beforeInput - token2.balanceOf(user), 50 ether);
        assertGt(orbital.rawReserve(2), 0, "new leg has actual paid backing");
        assertEq(orbital.rawReserve(0), token0.balanceOf(hook));
        assertEq(orbital.rawReserve(1), token1.balanceOf(hook));
        assertEq(orbital.rawReserve(2), token2.balanceOf(hook));
        assertEq(orbital.seBalance(0), IERC20(se0).balanceOf(hook));
    }

    function test_liquidity_1se_shareFundedLocalSeed() public {
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args = _argsWithSE(true, false, false);
        address h = PkgFactory.deployHook(hookPkg, args, PkgFactory.findMineNonce(hookFactory, hookPkg, args));
        IUniswapV4StandardExchangeOrbitalBufferHook target = IUniswapV4StandardExchangeOrbitalBufferHook(h);
        (uint256 minted,,,) = _seedFor(target, user, 100 ether, 100 ether, 100 ether);
        assertGt(minted, 0);
        assertGt(target.seBalance(0), 0);
        assertGt(target.rawReserve(0), 0);
        assertEq(target.rawReserve(0), token0.balanceOf(h));
        assertGt(target.radius(), 0);
    }
}
