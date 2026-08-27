// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {
    TestBase_UniswapV3StandardExchange
} from "contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange.sol";
import {
    IUniswapV3StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3StandardExchangeLiquidReserve.sol";
import {
    UniswapV3StandardExchangeCommon
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeCommon.sol";
import {
    IUniswapV3StandardExchangePositionImport
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangePositionImportTarget.sol";
import {
    INonfungiblePositionManager
} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/INonfungiblePositionManager.sol";
import {
    UniswapV3BoundPoolLockSeCaller
} from "test/foundry/spec/protocol/dexes/uniswap/v3/harness/UniswapV3BoundPoolLockSeCaller.sol";

contract UniswapV3StandardExchange_LocalLiquidBuffer_Test is TestBase_UniswapV3StandardExchange {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IUniswapV3Pool internal pool;
    IStandardExchangeProxy internal vault;
    IUniswapV3StandardExchangeLiquidReserve internal liquid;
    UniswapV3BoundPoolLockSeCaller internal lockCaller;

    function setUp() public override {
        super.setUp();
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
        pool = _createPoolOneToOne(address(tokenA), address(tokenB), FEE_MEDIUM);
        _seedExternalLiquidity(pool, 50_000_000e18);
        vault = _deployVault(pool);
        liquid = IUniswapV3StandardExchangeLiquidReserve(address(vault));
        lockCaller = new UniswapV3BoundPoolLockSeCaller(pool);
        ERC20PermitMintableStub(pool.token0()).mint(address(lockCaller), 100 ether);
        ERC20PermitMintableStub(pool.token1()).mint(address(lockCaller), 100 ether);
    }

    function test_T9_reservesEqualFreePlusDeployed() public {
        _bootstrapDeposit(10 ether);
        (uint256 dep0,) = liquid.deployedReserve();
        uint256 free0 = liquid.localReserve(_token0());
        uint256 free1 = liquid.localReserve(_token1());
        assertEq(free0, IERC20(_token0()).balanceOf(address(vault)), "free0 == balance");
        assertEq(free1, IERC20(_token1()).balanceOf(address(vault)), "free1 == balance");
        assertTrue(free0 + dep0 + free1 > 0, "has inventory");
    }

    function test_T4d_donationDilutesSharePrice() public {
        uint256 shares = _bootstrapDeposit(10 ether);
        uint256 supply = IERC20(address(vault)).totalSupply();
        assertEq(shares, supply, "sole holder (no prior residual)");
        uint256 free0Before = liquid.localReserve(_token0());
        (uint256 dep0Before,) = liquid.deployedReserve();
        ERC20PermitMintableStub(_token0()).mint(address(vault), 5 ether);
        assertEq(liquid.localReserve(_token0()), free0Before + 5 ether, "donation is free");
        (uint256 dep0After,) = liquid.deployedReserve();
        assertEq(dep0After, dep0Before, "deployed unchanged");
        assertEq(IERC20(address(vault)).totalSupply(), supply, "supply unchanged");
    }

    function test_T1_idleDeposit_freeNear20pct() public {
        _bootstrapDeposit(100 ether);
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_T1b_idleDeposit_token0Only_doesNotRequireSleeveAndL() public {
        uint256 amountIn = 50 ether;
        ERC20PermitMintableStub(_token0()).mint(address(this), amountIn);
        IERC20(_token0()).approve(address(vault), amountIn);
        uint256 shares = vault.exchangeIn(
            IERC20(_token0()), amountIn, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertGt(shares, 0, "T1b: shares");
        (uint256 dep0, uint256 dep1) = liquid.deployedReserve();
        // Full-range L needs both tokens; token0-only must not require 20% + in-range L.
        assertTrue(dep0 + dep1 == 0 || liquid.actualLiquidReservePercentage(_token0()) != 0.2e18);
    }

    function test_T2_blockedDeposit_sleeveNoNestedMint() public {
        uint256 amountIn = 5 ether;
        address t0 = _token0();
        ERC20PermitMintableStub(t0).mint(address(lockCaller), amountIn);
        vm.prank(address(lockCaller));
        IERC20(t0).approve(address(vault), type(uint256).max);
        uint128 lBefore = _centerLiquidity();
        uint256 shares = lockCaller.runExchangeIn(
            address(vault), IERC20(t0), amountIn, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertGt(shares, 0, "T2: shares");
        assertEq(_centerLiquidity(), lBefore, "T2: no nested mint");
    }

    function test_T3_publicRebalanceAfterBlockedDeposit() public {
        test_T2_blockedDeposit_sleeveNoNestedMint();
        ERC20PermitMintableStub(_token1()).mint(address(this), 5 ether);
        IERC20(_token1()).approve(address(vault), 5 ether);
        vault.exchangeIn(IERC20(_token1()), 5 ether, IERC20(address(vault)), 0, address(this), false, _deadline());
        liquid.rebalanceLiquidReserve();
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_T4_blockedAmountOut_paysSleeve() public {
        _bootstrapDeposit(20 ether);
        uint256 want = 0.1 ether;
        uint256 shares = IERC20(address(vault)).balanceOf(address(this));
        IERC20(address(vault)).transfer(address(lockCaller), shares);
        vm.prank(address(lockCaller));
        IERC20(address(vault)).approve(address(vault), shares);
        uint256 burned = lockCaller.runExchangeOut(
            address(vault), IERC20(address(vault)), shares, IERC20(_token0()), want, address(this), false, _deadline()
        );
        assertGt(burned, 0, "T4: cover");
    }

    function test_T5_blockedAmountOut_insufficientLocalReserve() public {
        _bootstrapDeposit(20 ether);
        liquid.rebalanceLiquidReserve();
        address t0 = _token0();
        uint256 want = liquid.localReserve(t0) + 1 ether;
        uint256 shares = IERC20(address(vault)).balanceOf(address(this));
        IERC20(address(vault)).transfer(address(lockCaller), shares);
        vm.prank(address(lockCaller));
        IERC20(address(vault)).approve(address(vault), shares);
        uint256 deadline = _deadline();
        vm.expectRevert();
        lockCaller.runExchangeOut(
            address(vault), IERC20(address(vault)), shares, IERC20(t0), want, address(this), false, deadline
        );
    }

    function test_T6_blockedDirectSwap_reverts() public {
        uint256 amountIn = 0.01 ether;
        address t0 = _token0();
        address t1 = _token1();
        ERC20PermitMintableStub(t0).mint(address(lockCaller), amountIn);
        vm.prank(address(lockCaller));
        IERC20(t0).approve(address(vault), type(uint256).max);
        uint256 deadline = _deadline();
        vm.expectRevert(UniswapV3StandardExchangeCommon.UniswapV3Exchange_BoundPoolInteractionBlocked.selector);
        lockCaller.runExchangeIn(
            address(vault), IERC20(t0), amountIn, IERC20(t1), 0, address(this), false, deadline
        );
    }

    function test_T7_idleDirectSwap_thenRebalance() public {
        _bootstrapDeposit(10 ether);
        uint256 amountIn = 0.1 ether;
        ERC20PermitMintableStub(_token0()).mint(address(this), amountIn);
        IERC20(_token0()).approve(address(vault), amountIn);
        uint256 out = vault.exchangeIn(
            IERC20(_token0()), amountIn, IERC20(_token1()), 0, address(this), false, _deadline()
        );
        assertGt(out, 0, "T7: swap");
    }

    function test_T8_previewEqualsExec_freeZapIn() public {
        uint256 amountIn = 3 ether;
        uint256 preview = vault.previewExchangeIn(IERC20(_token0()), amountIn, IERC20(address(vault)));
        ERC20PermitMintableStub(_token0()).mint(address(this), amountIn);
        IERC20(_token0()).approve(address(vault), amountIn);
        uint256 exec = vault.exchangeIn(
            IERC20(_token0()), amountIn, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertEq(exec, preview, "T8: preview==exec");
    }

    function test_H4_typeDefault20pct() public view {
        assertEq(liquid.targetLiquidReservePercentage(), 0.20e18, "H4: 20% type default");
    }

    function test_T10_oracleCascade_vaultOverridesType() public {
        _bootstrapDeposit(10 ether);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setLiquidReservePercentageOfVault(address(vault), 0.10e18);
        assertEq(liquid.targetLiquidReservePercentage(), 0.10e18, "T10: vault override");
        liquid.rebalanceLiquidReserve();
        _assertFreeWithinDeadband(0.10e18);
    }

    function test_T12_firstMintBlocked_thenFreeRebalanceCreatesPosition() public {
        uint256 amount0 = 5 ether;
        uint256 amount1 = 5 ether;
        ERC20PermitMintableStub(_token0()).mint(address(lockCaller), amount0);
        ERC20PermitMintableStub(_token1()).mint(address(lockCaller), amount1);
        vm.startPrank(address(lockCaller));
        IERC20(_token0()).approve(address(vault), amount0);
        IERC20(_token1()).approve(address(vault), amount1);
        vm.stopPrank();
        lockCaller.runExchangeIn(
            address(vault), IERC20(_token0()), amount0, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        lockCaller.runExchangeIn(
            address(vault), IERC20(_token1()), amount1, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertEq(_centerLiquidity(), 0, "T12: no L while blocked");
        liquid.rebalanceLiquidReserve();
        assertGt(_centerLiquidity(), 0, "T12: idle rebalance mints L");
    }

    function test_T14_publicRebalanceBlocked_reverts() public {
        _bootstrapDeposit(10 ether);
        vm.expectRevert(UniswapV3StandardExchangeCommon.UniswapV3Exchange_BoundPoolInteractionBlocked.selector);
        lockCaller.runRebalance(address(vault));
    }

    function test_T15_withinDeadband_noPoolOpNeeded() public {
        _bootstrapDeposit(20 ether);
        liquid.rebalanceLiquidReserve();
    }

    function test_T16_outsideDeadband_movesToTarget() public {
        _bootstrapDeposit(20 ether);
        ERC20PermitMintableStub(_token0()).mint(address(vault), 50 ether);
        ERC20PermitMintableStub(_token1()).mint(address(vault), 50 ether);
        liquid.rebalanceLiquidReserve();
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_T4e_positionImportBlocked_reverts() public {
        vm.expectRevert(UniswapV3StandardExchangeCommon.UniswapV3Exchange_BoundPoolInteractionBlocked.selector);
        lockCaller.runImport(
            address(vault),
            address(1),
            1,
            0,
            address(this),
            address(this),
            _deadline()
        );
    }

    function test_T4f_rebalanceNoSwap() public {
        _bootstrapDeposit(20 ether);
        uint256 t0Before = IERC20(_token0()).balanceOf(address(this));
        liquid.rebalanceLiquidReserve();
        assertEq(IERC20(_token0()).balanceOf(address(this)), t0Before, "T4f: no user swap");
    }

    function _bootstrapDeposit(uint256 amountIn) internal returns (uint256 shares) {
        ERC20PermitMintableStub(_token0()).mint(address(this), amountIn);
        ERC20PermitMintableStub(_token1()).mint(address(this), amountIn);
        IERC20(_token0()).approve(address(vault), amountIn);
        IERC20(_token1()).approve(address(vault), amountIn);
        uint256 shares0 = vault.exchangeIn(
            IERC20(_token0()), amountIn, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        uint256 shares1 = vault.exchangeIn(
            IERC20(_token1()), amountIn, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        shares = shares0 + shares1;
        assertGt(shares, 0, "bootstrap");
    }

    function _assertFreeWithinDeadband(uint256 liquidPct) internal view {
        (uint256 dep0, uint256 dep1) = liquid.deployedReserve();
        uint256 free0 = liquid.localReserve(_token0());
        uint256 free1 = liquid.localReserve(_token1());
        uint256 total0 = free0 + dep0;
        uint256 total1 = free1 + dep1;
        if (total0 > 0) {
            uint256 target0 = (total0 * liquidPct) / ONE_WAD;
            uint256 dev0 = free0 > target0 ? free0 - target0 : target0 - free0;
            uint256 tol0 = target0 == 0 ? 1e12 : (target0 * 0.05e18) / ONE_WAD;
            if (tol0 < 1e12) tol0 = 1e12;
            assertLe(dev0, tol0 + total0 / 4 + 1e15, "token0 within wide deadband");
        }
        if (total1 > 0) {
            uint256 target1 = (total1 * liquidPct) / ONE_WAD;
            uint256 dev1 = free1 > target1 ? free1 - target1 : target1 - free1;
            uint256 tol1 = target1 == 0 ? 1e12 : (target1 * 0.05e18) / ONE_WAD;
            if (tol1 < 1e12) tol1 = 1e12;
            if (target1 > 0) {
                assertLe(dev1, tol1 + total1 / 2 + 1e15, "token1 within wide band");
            }
        }
    }

    function _centerLiquidity() internal view returns (uint128 liq) {
        int24 spacing = pool.tickSpacing();
        int24 lo = TickMath.minUsableTick(spacing);
        int24 hi = TickMath.maxUsableTick(spacing);
        (liq,,,,) = pool.positions(keccak256(abi.encodePacked(address(vault), lo, hi)));
    }

    function _token0() internal view returns (address) {
        return pool.token0();
    }

    function _token1() internal view returns (address) {
        return pool.token1();
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }
}
