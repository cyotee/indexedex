// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV3StandardExchange_Decimals
} from "contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange_Decimals.sol";

/// @notice Preview = execution. pairToken = tokenA. Amounts are raw units via `_u0`/`_u1`.
abstract contract UniswapV3StandardExchange_Previews_Decimals is TestBase_UniswapV3StandardExchange_Decimals {
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

    function test_P_IN_01_exactIn_token0_to_token1() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        uint256 amountIn = _u0(5);
        uint256 preview = vault.previewExchangeIn(IERC20(token0), amountIn, IERC20(token1));

        _mint(token0, alice, amountIn);
        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), amountIn);
        uint256 executed =
            vault.exchangeIn(IERC20(token0), amountIn, IERC20(token1), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();

        assertEq(preview, executed, "P-IN-01");
    }

    function test_P_IN_02_exactIn_token1_to_token0() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        uint256 amountIn = _u1(5);
        uint256 preview = vault.previewExchangeIn(IERC20(token1), amountIn, IERC20(token0));

        _mint(token1, alice, amountIn);
        vm.startPrank(alice);
        IERC20(token1).approve(address(vault), amountIn);
        uint256 executed =
            vault.exchangeIn(IERC20(token1), amountIn, IERC20(token0), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();

        assertEq(preview, executed, "P-IN-02");
    }

    function test_P_IN_03_singleToken0ActivationRejected() public {
        address token = pool.token0();
        uint256 amount = _u0(50);
        assertEq(vault.previewExchangeIn(IERC20(token), amount, IERC20(address(vault))), 0, "one token cannot activate");
        _mint(token, alice, amount);
        vm.startPrank(alice);
        IERC20(token).approve(address(vault), amount);
        uint256 balanceBefore = IERC20(token).balanceOf(alice);
        vm.expectRevert(bytes4(keccak256("UniswapV3Exchange_ZeroAmount()")));
        vault.exchangeIn(IERC20(token), amount, IERC20(address(vault)), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();
        assertEq(IERC20(address(vault)).totalSupply(), 0, "no unbacked initial shares");
        assertEq(IERC20(token).balanceOf(alice), balanceBefore, "failed activation returns input");
    }

    function test_P_IN_04_singleToken1ActivationRejected() public {
        address token = pool.token1();
        uint256 amount = _u1(50);
        assertEq(vault.previewExchangeIn(IERC20(token), amount, IERC20(address(vault))), 0, "one token cannot activate");
        _mint(token, alice, amount);
        vm.startPrank(alice);
        IERC20(token).approve(address(vault), amount);
        uint256 balanceBefore = IERC20(token).balanceOf(alice);
        vm.expectRevert(bytes4(keccak256("UniswapV3Exchange_ZeroAmount()")));
        vault.exchangeIn(IERC20(token), amount, IERC20(address(vault)), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();
        assertEq(IERC20(address(vault)).totalSupply(), 0, "no unbacked initial shares");
        assertEq(IERC20(token).balanceOf(alice), balanceBefore, "failed activation returns input");
    }

    function test_P_IN_05_zapIn_subsequent_afterFees() public {
        address token0 = pool.token0();
        uint256 bootstrap = _u0(100);
        _mint(token0, alice, bootstrap + _u0(10));

        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);
        _activateWithFundedToken0(bootstrap, _u1(100));
        vm.stopPrank();

        _swapHuman(pool, true, 20_000);
        _swapHuman(pool, false, 20_000);

        uint256 amountIn = _u0(10);
        uint256 preview = vault.previewExchangeIn(IERC20(token0), amountIn, IERC20(address(vault)));

        vm.startPrank(alice);
        uint256 executed =
            vault.exchangeIn(IERC20(token0), amountIn, IERC20(address(vault)), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();

        assertApproxEqAbs(preview, executed, preview / 1000 + 1e15, "P-IN-05");
    }

    function test_P_OUT_01_exactOut_token0_to_token1() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        uint256 amountOut = _u1(1);
        uint256 preview = vault.previewExchangeOut(IERC20(token0), IERC20(token1), amountOut);

        _mint(token0, alice, preview * 2);
        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 executed = vault.exchangeOut(
            IERC20(token0), type(uint256).max, IERC20(token1), amountOut, alice, false, block.timestamp + 1
        );
        vm.stopPrank();

        assertEq(preview, executed, "P-OUT-01");
    }

    function test_P_OUT_02_exactOut_token1_to_token0() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        uint256 amountOut = _u0(1);
        uint256 preview = vault.previewExchangeOut(IERC20(token1), IERC20(token0), amountOut);

        _mint(token1, alice, preview * 2);
        vm.startPrank(alice);
        IERC20(token1).approve(address(vault), type(uint256).max);
        uint256 executed = vault.exchangeOut(
            IERC20(token1), type(uint256).max, IERC20(token0), amountOut, alice, false, block.timestamp + 1
        );
        vm.stopPrank();

        assertEq(preview, executed, "P-OUT-02");
    }

    function test_P_OUT_03_04_zapOut_bothTokens() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        uint256 amountIn = _u0(100);
        _mint(token0, alice, amountIn);

        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 shares =
            _activateWithFundedToken0(amountIn, _u1(100));

        uint256 want0 = _u0(1);
        uint256 previewShares0 = vault.previewExchangeOut(IERC20(address(vault)), IERC20(token0), want0);
        uint256 burned0 = vault.exchangeOut(
            IERC20(address(vault)), shares, IERC20(token0), want0, alice, false, block.timestamp + 1
        );
        assertEq(previewShares0, burned0, "P-OUT-03");

        uint256 remaining = IERC20(address(vault)).balanceOf(alice);
        uint256 want1 = _u1(1);
        uint256 previewShares1 = vault.previewExchangeOut(IERC20(address(vault)), IERC20(token1), want1);
        uint256 burned1 = vault.exchangeOut(
            IERC20(address(vault)), remaining, IERC20(token1), want1, alice, false, block.timestamp + 1
        );
        assertEq(previewShares1, burned1, "P-OUT-04");
        vm.stopPrank();
    }

    function test_P_PRE_01_pretransferred_exactIn() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        uint256 amountIn = _u0(3);
        uint256 preview = vault.previewExchangeIn(IERC20(token0), amountIn, IERC20(token1));

        _mint(token0, alice, amountIn);
        vm.startPrank(alice);
        IERC20(token0).transfer(address(vault), amountIn);
        uint256 executed =
            vault.exchangeIn(IERC20(token0), amountIn, IERC20(token1), 0, alice, true, block.timestamp + 1);
        vm.stopPrank();

        assertEq(preview, executed, "P-PRE-01");
    }
}
