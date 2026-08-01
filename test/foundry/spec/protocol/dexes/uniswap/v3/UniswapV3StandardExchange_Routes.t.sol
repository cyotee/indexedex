// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {
    IUniswapV3MintCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3MintCallback.sol";
import {
    IUniswapV3SwapCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3SwapCallback.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_UniswapV3StandardExchange
} from "contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange.sol";

contract UniswapV3StandardExchange_Routes_Test is TestBase_UniswapV3StandardExchange {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IUniswapV3Pool internal pool;
    IStandardExchangeProxy internal vault;
    address internal alice = makeAddr("alice");

    function setUp() public override {
        super.setUp();
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
        pool = _createPoolOneToOne(address(tokenA), address(tokenB), FEE_MEDIUM);
        _seedExternalLiquidity(pool, 50_000_000e18);
        vault = _deployVault(pool, DEFAULT_WIDTH_MULTIPLIER);
    }

    function test_exchangeIn_exactIn_bothDirections() public {
        address token0 = pool.token0();
        address token1 = pool.token1();

        uint256 amountIn = 10 ether;
        ERC20PermitMintableStub(token0).mint(alice, amountIn);
        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), amountIn);
        uint256 out01 = vault.exchangeIn(IERC20(token0), amountIn, IERC20(token1), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();
        assertGt(out01, 0, "t0->t1");

        ERC20PermitMintableStub(token1).mint(alice, amountIn);
        vm.startPrank(alice);
        IERC20(token1).approve(address(vault), amountIn);
        uint256 out10 = vault.exchangeIn(IERC20(token1), amountIn, IERC20(token0), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();
        assertGt(out10, 0, "t1->t0");
    }

    function test_exchangeOut_exactOut_bothDirections() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        uint256 amountOut = 1 ether;

        ERC20PermitMintableStub(token0).mint(alice, 100 ether);
        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 in01 =
            vault.exchangeOut(IERC20(token0), type(uint256).max, IERC20(token1), amountOut, alice, false, block.timestamp + 1);
        vm.stopPrank();
        assertGt(in01, 0, "exact out t0->t1");

        ERC20PermitMintableStub(token1).mint(alice, 100 ether);
        vm.startPrank(alice);
        IERC20(token1).approve(address(vault), type(uint256).max);
        uint256 in10 =
            vault.exchangeOut(IERC20(token1), type(uint256).max, IERC20(token0), amountOut, alice, false, block.timestamp + 1);
        vm.stopPrank();
        assertGt(in10, 0, "exact out t1->t0");
    }

    function test_zapIn_firstDeposit_createsPositionsAndShares() public {
        address token0 = pool.token0();
        uint256 amountIn = 100 ether;
        ERC20PermitMintableStub(token0).mint(alice, amountIn);

        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), amountIn);
        uint256 shares =
            vault.exchangeIn(IERC20(token0), amountIn, IERC20(address(vault)), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();

        assertGt(shares, 0, "shares minted");
        assertEq(IERC20(address(vault)).balanceOf(alice), shares);
        assertEq(IERC20(address(vault)).totalSupply(), shares);
    }

    function test_zapIn_subsequentDeposit_addsSameTicks() public {
        address token0 = pool.token0();
        uint256 amountIn = 100 ether;
        ERC20PermitMintableStub(token0).mint(alice, amountIn * 2);

        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 first =
            vault.exchangeIn(IERC20(token0), amountIn, IERC20(address(vault)), 0, alice, false, block.timestamp + 1);
        uint256 second =
            vault.exchangeIn(IERC20(token0), amountIn, IERC20(address(vault)), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();

        assertGt(first, 0);
        assertGt(second, 0);
        assertEq(IERC20(address(vault)).totalSupply(), first + second);
    }

    function test_zapOut_paysMeasuredToken() public {
        address token0 = pool.token0();
        uint256 amountIn = 100 ether;
        ERC20PermitMintableStub(token0).mint(alice, amountIn);

        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 shares =
            vault.exchangeIn(IERC20(token0), amountIn, IERC20(address(vault)), 0, alice, false, block.timestamp + 1);

        uint256 balBefore = IERC20(token0).balanceOf(alice);
        // Burn shares for token0 out - use half shares as max, request some min out.
        uint256 sharesBurned = vault.exchangeOut(
            IERC20(address(vault)), shares, IERC20(token0), 1, alice, false, block.timestamp + 1
        );
        vm.stopPrank();

        assertGt(sharesBurned, 0);
        assertGt(IERC20(token0).balanceOf(alice), balBefore);
    }

    function test_unsupportedRoutes_revert() public {
        address token0 = pool.token0();
        ERC20PermitMintableStub foreign = new ERC20PermitMintableStub("Foreign", "FOR", 18, address(this), 0);
        foreign.mint(alice, 1 ether);

        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);
        IERC20(address(foreign)).approve(address(vault), type(uint256).max);

        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        vault.exchangeIn(IERC20(address(foreign)), 1 ether, IERC20(token0), 0, alice, false, block.timestamp + 1);

        // share -> share
        ERC20PermitMintableStub(token0).mint(alice, 10 ether);
        vault.exchangeIn(IERC20(token0), 10 ether, IERC20(address(vault)), 0, alice, false, block.timestamp + 1);
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        vault.exchangeIn(
            IERC20(address(vault)), 1, IERC20(address(vault)), 0, alice, false, block.timestamp + 1
        );
        vm.stopPrank();
    }

    function test_deadline_reverts() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        ERC20PermitMintableStub(token0).mint(alice, 1 ether);
        vm.warp(1000);
        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);
        // Cache token1 before expectRevert so the staticcall is not the "next call".
        vm.expectRevert(bytes4(keccak256("UniswapV3ExchangeIn_DeadlineExceeded()")));
        vault.exchangeIn(IERC20(token0), 1 ether, IERC20(token1), 0, alice, false, 1);
        vm.stopPrank();
    }

    function test_slippage_revertsWithoutPartialMint() public {
        address token0 = pool.token0();
        ERC20PermitMintableStub(token0).mint(alice, 100 ether);
        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);
        vm.expectRevert();
        vault.exchangeIn(
            IERC20(token0), 100 ether, IERC20(address(vault)), type(uint256).max, alice, false, block.timestamp + 1
        );
        vm.stopPrank();
        assertEq(IERC20(address(vault)).totalSupply(), 0, "no partial share mint");
    }

    function test_callbackSpoof_reverts() public {
        // Direct callback from EOA must revert.
        vm.expectRevert();
        IUniswapV3MintCallback(address(vault)).uniswapV3MintCallback(1, 1, "");
        vm.expectRevert();
        IUniswapV3SwapCallback(address(vault)).uniswapV3SwapCallback(1, 1, "");
    }
}
