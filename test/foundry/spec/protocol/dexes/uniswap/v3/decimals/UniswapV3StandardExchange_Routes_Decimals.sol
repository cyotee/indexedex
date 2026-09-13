// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    IUniswapV3MintCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3MintCallback.sol";
import {
    IUniswapV3SwapCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3SwapCallback.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_UniswapV3StandardExchange_Decimals
} from "contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange_Decimals.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";

/// @notice Routes money paths. pairToken = tokenA. Amounts are raw units via `_u0`/`_u1`.
abstract contract UniswapV3StandardExchange_Routes_Decimals is TestBase_UniswapV3StandardExchange_Decimals {
    address internal alice = makeAddr("alice");

    /// @dev Caller has already funded/approved token0 and is pranking as alice.
    function _activateWithFundedToken0(uint256 amount0, uint256 amount1) internal returns (uint256 shares) {
        _mint(pool.token1(), alice, amount1);
        IERC20(pool.token1()).approve(address(vault), amount1);
        address[] memory tokens = new address[](2);
        tokens[0] = pool.token0();
        tokens[1] = pool.token1();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;
        shares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 0, alice, false, block.timestamp + 1
        );
    }

    function setUp() public virtual override {
        super.setUp();
        _deployPairTokens();
        pool = _createPoolOneToOne(address(tokenA), address(tokenB), FEE_MEDIUM);
        _seedExternalLiquidity(pool, 0);
        vault = _deployVault(pool);
    }

    function test_exchangeIn_exactIn_bothDirections() public {
        address token0 = pool.token0();
        address token1 = pool.token1();

        uint256 amountIn0 = _u0(10);
        _mint(token0, alice, amountIn0);
        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), amountIn0);
        uint256 out01 = vault.exchangeIn(IERC20(token0), amountIn0, IERC20(token1), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();
        assertGt(out01, 0, "t0->t1");

        uint256 amountIn1 = _u1(10);
        _mint(token1, alice, amountIn1);
        vm.startPrank(alice);
        IERC20(token1).approve(address(vault), amountIn1);
        uint256 out10 = vault.exchangeIn(IERC20(token1), amountIn1, IERC20(token0), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();
        assertGt(out10, 0, "t1->t0");
    }

    function test_exchangeOut_exactOut_bothDirections() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        uint256 amountOut1 = _u1(1);

        _mint(token0, alice, _u0(100));
        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 in01 =
            vault.exchangeOut(IERC20(token0), type(uint256).max, IERC20(token1), amountOut1, alice, false, block.timestamp + 1);
        vm.stopPrank();
        assertGt(in01, 0, "exact out t0->t1");

        uint256 amountOut0 = _u0(1);
        _mint(token1, alice, _u1(100));
        vm.startPrank(alice);
        IERC20(token1).approve(address(vault), type(uint256).max);
        uint256 in10 =
            vault.exchangeOut(IERC20(token1), type(uint256).max, IERC20(token0), amountOut0, alice, false, block.timestamp + 1);
        vm.stopPrank();
        assertGt(in10, 0, "exact out t1->t0");
    }

    function test_twoTokenActivation_createsPositionsAndShares() public {
        address token0 = pool.token0();
        uint256 amountIn = _u0(100);
        _mint(token0, alice, amountIn);

        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), amountIn);
        uint256 shares =
            _activateWithFundedToken0(amountIn, _u1(100));
        vm.stopPrank();

        assertGt(shares, 0, "shares minted");
        assertEq(IERC20(address(vault)).balanceOf(alice), shares);
        assertEq(IERC20(address(vault)).totalSupply(), shares);
    }

    function test_zapIn_subsequentDeposit_addsSameTicks() public {
        address token0 = pool.token0();
        uint256 amountIn = _u0(100);
        _mint(token0, alice, amountIn * 2);

        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 first =
            _activateWithFundedToken0(amountIn, _u1(100));
        uint256 second =
            vault.exchangeIn(IERC20(token0), amountIn, IERC20(address(vault)), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();

        assertGt(first, 0);
        assertGt(second, 0);
        assertEq(IERC20(address(vault)).totalSupply(), first + second);
    }

    function test_zapOut_paysMeasuredToken() public {
        address token0 = pool.token0();
        uint256 amountIn = _u0(100);
        _mint(token0, alice, amountIn);

        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 shares =
            _activateWithFundedToken0(amountIn, _u1(100));

        uint256 balBefore = IERC20(token0).balanceOf(alice);
        uint256 sharesBurned = vault.exchangeOut(
            IERC20(address(vault)), shares, IERC20(token0), 1, alice, false, block.timestamp + 1
        );
        vm.stopPrank();

        assertGt(sharesBurned, 0);
        assertGt(IERC20(token0).balanceOf(alice), balBefore);
    }

    function test_unsupportedRoutes_revert() public {
        address token0 = pool.token0();
        MintableERC20Decimals foreign = new MintableERC20Decimals("Foreign", "FOR", 18);
        foreign.mint(alice, 1 ether);

        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);
        IERC20(address(foreign)).approve(address(vault), type(uint256).max);

        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        vault.exchangeIn(IERC20(address(foreign)), 1 ether, IERC20(token0), 0, alice, false, block.timestamp + 1);

        _mint(token0, alice, _u0(10));
        _activateWithFundedToken0(_u0(10), _u1(10));
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        vault.exchangeIn(
            IERC20(address(vault)), 1, IERC20(address(vault)), 0, alice, false, block.timestamp + 1
        );
        vm.stopPrank();
    }

    function test_deadline_reverts() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        uint256 amountIn = _u0(1);
        _mint(token0, alice, amountIn);
        vm.warp(1000);
        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);
        vm.expectRevert(bytes4(keccak256("UniswapV3ExchangeIn_DeadlineExceeded()")));
        vault.exchangeIn(IERC20(token0), amountIn, IERC20(token1), 0, alice, false, 1);
        vm.stopPrank();
    }

    function test_slippage_revertsWithoutPartialMint() public {
        address token0 = pool.token0();
        uint256 amountIn = _u0(100);
        _mint(token0, alice, amountIn);
        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 supplyBefore = _activateWithFundedToken0(amountIn, _u1(100));
        _mint(token0, alice, amountIn);
        vm.expectRevert(bytes4(keccak256("UniswapV3ExchangeIn_SlippageExceeded()")));
        vault.exchangeIn(
            IERC20(token0), amountIn, IERC20(address(vault)), type(uint256).max, alice, false, block.timestamp + 1
        );
        vm.stopPrank();
        assertEq(IERC20(address(vault)).totalSupply(), supplyBefore, "no partial share mint");
    }

    function test_callbackSpoof_reverts() public {
        vm.expectRevert();
        IUniswapV3MintCallback(address(vault)).uniswapV3MintCallback(1, 1, "");
        vm.expectRevert();
        IUniswapV3SwapCallback(address(vault)).uniswapV3SwapCallback(1, 1, "");
    }
}
