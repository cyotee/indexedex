// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

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
        assertEq(orbital.rawReserve(0), 0);
        assertEq(e1, 100 ether);
        assertEq(e2, 100 ether);
        assertGt(orbital.radius(), 0);
    }

    function test_firstMint_oneLeg_reverts() public {
        vm.prank(user);
        vm.expectRevert();
        orbital.addLiquidity(100 ether, 0, 0, user, 0, block.timestamp + 1 hours, "");
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

    function test_partialBook_seedThirdLeg() public {
        _addLiquidity(100 ether, 100 ether, 0);
        // partial: add third leg
        (uint256 shares,,,) = _addLiquidity(0, 0, 50 ether);
        assertGt(shares, 0);
        assertGt(orbital.effectiveReserve(2), 0);
    }

    function test_liquidity_1se_bufferLast() public {
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args =
            _argsWithSE(true, false, false);
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        // Approve SE to pull token0 when buffering (hook exchangeIn into SE)
        token0.mint(user, 1000 ether);
        token1.mint(user, 1000 ether);
        token2.mint(user, 1000 ether);
        vm.startPrank(user);
        token0.approve(h, type(uint256).max);
        token1.approve(h, type(uint256).max);
        token2.approve(h, type(uint256).max);
        (bool ok, bytes memory ret) = h.call(
            abi.encodeWithSignature(
                "addLiquidity(uint256,uint256,uint256,address,uint256,uint256,bytes)",
                100 ether,
                100 ether,
                100 ether,
                user,
                0,
                block.timestamp + 1 hours,
                ""
            )
        );
        vm.stopPrank();
        if (!ok) {
            // Decode custom error / string if present for diagnosis
            if (ret.length > 0) {
                assembly {
                    ret := add(ret, 0x04)
                }
            }
            revert(string(ret));
        }
        (ok, ret) = h.staticcall(abi.encodeWithSignature("seBalance(uint8)", uint8(0)));
        assertTrue(ok);
        assertGt(abi.decode(ret, (uint256)), 0, "SE shares held");
        (ok, ret) = h.staticcall(abi.encodeWithSignature("rawReserve(uint8)", uint8(0)));
        assertTrue(ok);
        assertEq(abi.decode(ret, (uint256)), 0, "buffered leg raw book 0");
        (ok, ret) = h.staticcall(abi.encodeWithSignature("radius()"));
        assertTrue(ok);
        assertGt(abi.decode(ret, (uint256)), 0, "R set with SE");
    }
}
