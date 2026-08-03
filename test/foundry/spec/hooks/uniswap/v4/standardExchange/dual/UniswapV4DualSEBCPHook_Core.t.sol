// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {HookMinerCreate3} from
    "@crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMinerCreate3.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {TestBase_UniswapV4DualSEBCPHook} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService as DualFactory
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHook as IDualHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";

/**
 * @title UniswapV4DualSEBCPHook_Core_Test
 * @notice Hermetic DoD cases: deploy, deposit, withdraw, zap gates, fees, surface, amount order.
 */
contract UniswapV4DualSEBCPHook_Core_Test is TestBase_UniswapV4DualSEBCPHook {
    function test_D1_deployFlagsAndViews() public view {
        uint160 flags = DualFactory.requiredFlags();
        assertEq(uint160(hook) & HookMinerCreate3.FLAG_MASK, flags);
        assertEq(dual.poolManager(), address(pm));
        assertEq(dual.feeOracle(), address(indexedexManager));
        assertEq(dual.permit2(), 0x000000000022D473030F116dDEE9F6B43aC78BA3);
        assertEq(dual.tradingFeePercent(), 300);
        assertEq(dual.tradingFeeDenominator(), 100_000);
        IERC20Metadata meta = IERC20Metadata(hook);
        assertEq(meta.decimals(), 18);
        assertTrue(bytes(meta.symbol()).length > 0);
        // LP prefix DSEBCP-
        assertEq(bytes(meta.symbol())[0], bytes1("D"));
        assertEq(dual.standardExchange0(), seA);
        assertEq(dual.token0(), address(tokenA));
    }

    function test_D2_idempotentRedeploy() public {
        address again = DualFactory.deployHook(
            create3Factory,
            pm,
            IVaultFeeOracleQuery(address(indexedexManager)),
            seA,
            address(tokenA),
            seB,
            address(tokenB)
        );
        assertEq(again, hook);
    }

    function test_D3_secondPoolInit_reverts() public {
        _initPool();
        vm.expectRevert();
        pm.initialize(poolKey, SQRT_PRICE_1_1);
    }

    function test_P1_firstDeposit_mintsLpAndMinLiquidity() public {
        uint256 lp = _depositBoth(100 ether, 100 ether);
        assertGt(lp, 0);
        assertEq(IERC20(hook).balanceOf(address(0)), 1000); // MINIMUM_LIQUIDITY
        assertGt(dual.claimSupplyCurrency0(), 0);
        assertGt(dual.claimSupplyCurrency1(), 0);
        assertTrue(dual.claimSupplyCurrency0() > 0 && dual.claimSupplyCurrency1() > 0);
    }

    function test_P3_subsequentDeposit_previewEqualsExecution() public {
        _depositBoth(100 ether, 100 ether);
        uint256 a0 = _amountForCurrency(dual.currency0(), 50 ether, 50 ether);
        uint256 a1 = _amountForCurrency(dual.currency1(), 50 ether, 50 ether);
        (uint256 predLp, uint256 predU0, uint256 predU1) = dual.previewDeposit(a0, a1);
        vm.prank(user);
        (uint256 lp, uint256 u0, uint256 u1) = dual.deposit(a0, a1, user, 0, block.timestamp + 1);
        assertApproxEqAbs(lp, predLp, DUST);
        assertEq(u0, predU0);
        assertEq(u1, predU1);
    }

    function test_P5_deadline_reverts() public {
        vm.prank(user);
        vm.expectRevert();
        dual.deposit(1 ether, 1 ether, user, 0, block.timestamp - 1);
    }

    function test_W1_withdraw_unwrapBoth() public {
        uint256 lp = _depositBoth(100 ether, 100 ether);
        uint256 bal0Before = IERC20(dual.currency0()).balanceOf(user);
        uint256 bal1Before = IERC20(dual.currency1()).balanceOf(user);
        (uint256 pred0, uint256 pred1) = dual.previewWithdraw(lp / 2);
        vm.prank(user);
        (uint256 a0, uint256 a1) = dual.withdraw(lp / 2, user, 0, 0, block.timestamp + 1);
        assertApproxEqAbs(a0, pred0, DUST);
        assertApproxEqAbs(a1, pred1, DUST);
        assertEq(IERC20(dual.currency0()).balanceOf(user) - bal0Before, a0);
        assertEq(IERC20(dual.currency1()).balanceOf(user) - bal1Before, a1);
    }

    function test_Z3_depositSingle_emptyBook_reverts() public {
        vm.prank(user);
        vm.expectRevert();
        dual.depositSingle(address(tokenA), 10 ether, user, 0, block.timestamp + 1);
    }

    function test_Z1_depositSingle_whenEligible() public {
        _depositBoth(200 ether, 200 ether);
        uint256 pred = dual.previewDepositSingle(address(tokenA), 20 ether);
        (uint256 swapAmt, uint256 otherOut, uint256 kept) =
            dual.previewZapSplit(address(tokenA), 20 ether);
        assertGt(swapAmt, 0);
        assertGt(otherOut, 0);
        assertEq(kept + swapAmt, 20 ether);

        vm.prank(user);
        uint256 lp = dual.depositSingle(address(tokenA), 20 ether, user, 0, block.timestamp + 1);
        assertApproxEqAbs(lp, pred, DUST);
        assertGt(lp, 0);
    }

    function test_Z4_depositSingle_afterFullExit_reverts() public {
        uint256 lp = _depositBoth(100 ether, 100 ether);
        vm.prank(user);
        dual.withdraw(lp, user, 0, 0, block.timestamp + 1);
        // only MINIMUM_LIQUIDITY remains
        assertEq(IERC20(hook).totalSupply(), 1000);
        vm.prank(user);
        vm.expectRevert();
        dual.depositSingle(address(tokenA), 10 ether, user, 0, block.timestamp + 1);
        // re-seed via dual deposit still works
        _depositBoth(50 ether, 50 ether);
        assertGt(IERC20(hook).totalSupply(), 1000);
    }

    function test_F2_protocolFee_mintsToFeeTo() public {
        _enableProtocolFee(0.05e18); // 5% growth share
        _depositBoth(100 ether, 100 ether);
        // generate k growth via yield (fund + approve for simulateYield pull)
        tokenA.mint(address(this), 10 ether);
        tokenB.mint(address(this), 10 ether);
        tokenA.approve(address(vaultA), 10 ether);
        tokenB.approve(address(vaultB), 10 ether);
        vaultA.simulateYield(10 ether);
        vaultB.simulateYield(10 ether);
        address feeTo_ = dual.feeTo();
        uint256 feeLpBefore = IERC20(hook).balanceOf(feeTo_);
        _depositBoth(10 ether, 10 ether);
        assertGt(IERC20(hook).balanceOf(feeTo_), feeLpBefore);
        assertGt(dual.kLast(), 0);
    }

    function test_E1_requiredSurface() public view {
        dual.feeOracle();
        dual.dexSwapFee();
        dual.feeTo();
        dual.kLast();
        dual.tradingFeePercent();
        dual.tradingFeeDenominator();
        dual.claimSupply0();
        dual.claimSupply1();
        dual.claimSupplyCurrency0();
        dual.claimSupplyCurrency1();
        dual.currency0();
        dual.currency1();
        IERC20Metadata(hook).name();
        IERC20Metadata(hook).symbol();
        IERC20(hook).totalSupply();
    }

    function test_A1_amountOrder_whenCtorOrderDiffersFromSort() public {
        // redeploy with reversed ctor legs
        address hook2 = DualFactory.deployHook(
            create3Factory,
            pm,
            IVaultFeeOracleQuery(address(indexedexManager)),
            seB,
            address(tokenB),
            seA,
            address(tokenA),
            "uv4-dual-se-buffer-constant-product-hook-rev-"
        );
        IDualHook d2 = IDualHook(hook2);
        // currency0 is always address-min of pair tokens
        address c0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        assertEq(d2.currency0(), c0);
        // deposit uses pool order regardless of ctor
        tokenA.mint(user, 100 ether);
        tokenB.mint(user, 100 ether);
        vm.startPrank(user);
        tokenA.approve(hook2, type(uint256).max);
        tokenB.approve(hook2, type(uint256).max);
        uint256 a0 = d2.currency0() == address(tokenA) ? 40 ether : 60 ether;
        uint256 a1 = d2.currency1() == address(tokenA) ? 40 ether : 60 ether;
        (uint256 lp, uint256 u0, uint256 u1) = d2.deposit(a0, a1, user, 0, block.timestamp + 1);
        assertGt(lp, 0);
        assertEq(u0, a0);
        assertEq(u1, a1);
        vm.stopPrank();
    }

    function test_SE_previewEqualsExecution_bufferRoute() public {
        // Phase 0 style: SE buffer pair→SE with fee
        tokenA.mint(address(this), 100 ether);
        tokenA.approve(seA, type(uint256).max);
        uint256 amountIn = 10 ether;
        uint256 pred = IStandardExchangeIn(seA).previewExchangeIn(
            IERC20(address(tokenA)), amountIn, IERC20(seA)
        );
        uint256 got = IStandardExchangeIn(seA).exchangeIn(
            IERC20(address(tokenA)),
            amountIn,
            IERC20(seA),
            pred,
            address(this),
            false,
            block.timestamp
        );
        assertEq(got, pred);
    }
}
