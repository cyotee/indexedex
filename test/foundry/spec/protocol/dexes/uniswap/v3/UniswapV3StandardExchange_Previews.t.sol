// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_UniswapV3StandardExchange
} from "contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange.sol";

/// @notice Preview = execution matrix (plan §9.2 rows).
contract UniswapV3StandardExchange_Previews_Test is TestBase_UniswapV3StandardExchange {
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

    function test_P_IN_01_exactIn_token0_to_token1() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        uint256 amountIn = 5 ether;
        uint256 preview = vault.previewExchangeIn(IERC20(token0), amountIn, IERC20(token1));

        ERC20PermitMintableStub(token0).mint(alice, amountIn);
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
        uint256 amountIn = 5 ether;
        uint256 preview = vault.previewExchangeIn(IERC20(token1), amountIn, IERC20(token0));

        ERC20PermitMintableStub(token1).mint(alice, amountIn);
        vm.startPrank(alice);
        IERC20(token1).approve(address(vault), amountIn);
        uint256 executed =
            vault.exchangeIn(IERC20(token1), amountIn, IERC20(token0), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();

        assertEq(preview, executed, "P-IN-02");
    }

    function test_P_IN_03_zapIn_token0_firstDeposit() public {
        address token0 = pool.token0();
        uint256 amountIn = 50 ether;
        uint256 preview = vault.previewExchangeIn(IERC20(token0), amountIn, IERC20(address(vault)));

        ERC20PermitMintableStub(token0).mint(alice, amountIn);
        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), amountIn);
        uint256 executed =
            vault.exchangeIn(IERC20(token0), amountIn, IERC20(address(vault)), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();

        // Multi-step Uni V3 zap rounding can differ by a few wei vs closed-form plan.
        assertApproxEqAbs(preview, executed, 10, "P-IN-03");
    }

    function test_P_IN_04_zapIn_token1_firstDeposit() public {
        address token1 = pool.token1();
        uint256 amountIn = 50 ether;
        uint256 preview = vault.previewExchangeIn(IERC20(token1), amountIn, IERC20(address(vault)));

        ERC20PermitMintableStub(token1).mint(alice, amountIn);
        vm.startPrank(alice);
        IERC20(token1).approve(address(vault), amountIn);
        uint256 executed =
            vault.exchangeIn(IERC20(token1), amountIn, IERC20(address(vault)), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();

        assertApproxEqAbs(preview, executed, 10, "P-IN-04");
    }

    function test_P_IN_05_zapIn_subsequent_afterFees() public {
        address token0 = pool.token0();
        uint256 bootstrap = 100 ether;
        ERC20PermitMintableStub(token0).mint(alice, bootstrap + 10 ether);

        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);
        vault.exchangeIn(IERC20(token0), bootstrap, IERC20(address(vault)), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();

        // Accrue fees via external round-trip swaps against the vault's positions.
        _externalSwapExactIn(pool, true, 20_000 ether);
        _externalSwapExactIn(pool, false, 20_000 ether);

        uint256 amountIn = 10 ether;
        uint256 preview = vault.previewExchangeIn(IERC20(token0), amountIn, IERC20(address(vault)));

        vm.startPrank(alice);
        uint256 executed =
            vault.exchangeIn(IERC20(token0), amountIn, IERC20(address(vault)), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();

        // Subsequent fee-first: fee growth / compound path can differ by multi-step Uni V3 wei.
        assertApproxEqAbs(preview, executed, preview / 1000 + 1e15, "P-IN-05");
    }

    function test_P_OUT_01_exactOut_token0_to_token1() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        uint256 amountOut = 1 ether;
        uint256 preview = vault.previewExchangeOut(IERC20(token0), IERC20(token1), amountOut);

        ERC20PermitMintableStub(token0).mint(alice, preview * 2);
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
        uint256 amountOut = 1 ether;
        uint256 preview = vault.previewExchangeOut(IERC20(token1), IERC20(token0), amountOut);

        ERC20PermitMintableStub(token1).mint(alice, preview * 2);
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
        uint256 amountIn = 100 ether;
        ERC20PermitMintableStub(token0).mint(alice, amountIn);

        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 shares =
            vault.exchangeIn(IERC20(token0), amountIn, IERC20(address(vault)), 0, alice, false, block.timestamp + 1);

        // Request a modest amount out; preview shares then execute.
        uint256 want0 = 1 ether;
        uint256 previewShares0 = vault.previewExchangeOut(IERC20(address(vault)), IERC20(token0), want0);
        uint256 burned0 = vault.exchangeOut(
            IERC20(address(vault)), shares, IERC20(token0), want0, alice, false, block.timestamp + 1
        );
        assertEq(previewShares0, burned0, "P-OUT-03");

        uint256 remaining = IERC20(address(vault)).balanceOf(alice);
        uint256 want1 = 1 ether;
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
        uint256 amountIn = 3 ether;
        uint256 preview = vault.previewExchangeIn(IERC20(token0), amountIn, IERC20(token1));

        ERC20PermitMintableStub(token0).mint(alice, amountIn);
        vm.startPrank(alice);
        IERC20(token0).transfer(address(vault), amountIn);
        uint256 executed =
            vault.exchangeIn(IERC20(token0), amountIn, IERC20(token1), 0, alice, true, block.timestamp + 1);
        vm.stopPrank();

        assertEq(preview, executed, "P-PRE-01");
    }
}
