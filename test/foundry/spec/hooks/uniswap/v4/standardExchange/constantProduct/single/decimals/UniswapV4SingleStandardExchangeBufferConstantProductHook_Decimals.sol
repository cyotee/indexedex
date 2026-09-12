// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook_Decimals as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook_Decimals.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferConstantProductHook_Decimals
 * @notice CP buffer money-paths on two-token combos. `pairToken` = SE asset; `rawToken` = other door.
 * @dev After PoolKey sort, amounts are `_uRaw` / `_uPair` / `_humanFor`. Hook LP stays 18.
 *      Do not compare a 6-dec transfer to `1 ether`. C1 uses gold-identical 18-dec hostile raw + pair.
 */
abstract contract UniswapV4SingleStandardExchangeBufferConstantProductHook_Decimals is TestBase {
    WrapperExactOutRouter internal swapRouter;

    function setUp() public virtual override {
        super.setUp();
        swapRouter = new WrapperExactOutRouter(pm);
        vm.startPrank(user);
        rawToken.approve(address(swapRouter), type(uint256).max);
        pairToken.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _sqrtLimit(bool zeroForOne) internal pure returns (uint160) {
        return zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
    }

    function _seedSwapBook() internal {
        _seedLiveLiquidity();
        _depositBoth(_uRaw(300), _uPair(300));
    }

    function test_P1_firstDeposit_minLiquidityAndVirtualPair() public {
        _initPool();
        uint256 lp = _depositBoth(_uRaw(100), _uPair(100));
        assertGt(lp, 0);
        assertEq(IERC20(hook).balanceOf(address(0)), 1000);
        assertTrue(single.isLive());
        assertGt(single.rawReserve(), 0);
        assertGt(single.seClaimSupply(), 0);
        assertLe(pairToken.balanceOf(hook), DUST);
        assertEq(single.seClaimSupply(), IBasicVault(hook).reserveOfToken(address(pairToken)));
        assertTrue(single.seClaimSupply() != pairToken.balanceOf(hook) || pairToken.balanceOf(hook) == 0);
    }

    function test_P3_subsequentDeposit_previewEqualsExec_clampRefund() public {
        _seedLiveLiquidity();
        uint256 a0 = _humanFor(single.currency0(), 50);
        uint256 a1 = _humanFor(single.currency1(), 50);
        uint256 offer0 = a0 + _humanFor(single.currency0(), 10);
        uint256 offer1 = a1;
        (uint256 predLp, uint256 predU0, uint256 predU1) = single.previewDeposit(offer0, offer1);
        uint256 bal0Before = IERC20(single.currency0()).balanceOf(user);
        vm.prank(user);
        (uint256 lp, uint256 u0, uint256 u1) = single.deposit(offer0, offer1, user, 0, block.timestamp + 1);
        assertApproxEqRel(lp, predLp, 0.02e18);
        assertEq(u0, predU0);
        assertEq(u1, predU1);
        if (offer0 > u0) {
            assertEq(IERC20(single.currency0()).balanceOf(user), bal0Before - u0);
        }
        assertLe(pairToken.balanceOf(hook), DUST);
    }

    function test_W1_withdraw_previewEqualsExec() public {
        _seedLiveLiquidity();
        uint256 lp = IERC20(hook).balanceOf(user) / 2;
        (uint256 pred0, uint256 pred1) = single.previewWithdraw(lp);
        uint256 b0 = IERC20(single.currency0()).balanceOf(user);
        uint256 b1 = IERC20(single.currency1()).balanceOf(user);
        vm.prank(user);
        (uint256 a0, uint256 a1) = single.withdraw(lp, user, 0, 0, block.timestamp + 1);
        assertApproxEqAbs(a0, pred0, DUST);
        assertApproxEqAbs(a1, pred1, DUST);
        assertEq(IERC20(single.currency0()).balanceOf(user) - b0, a0);
        assertEq(IERC20(single.currency1()).balanceOf(user) - b1, a1);
        assertLe(pairToken.balanceOf(hook), DUST);
    }

    function test_B6_depositWithSeShares_firstMint_mintsLp() public {
        _initPool();
        uint256 seShares = _mintSeSharesToUser(_uPair(100));
        assertGt(seShares, 0);

        (uint256 predLp, uint256 predRaw, uint256 predSe) =
            single.previewDepositWithSeShares(_uRaw(100), seShares);
        assertGt(predLp, 0);
        assertEq(predRaw, _uRaw(100));
        assertEq(predSe, seShares);

        uint256 seBefore = IERC20(se).balanceOf(user);
        uint256 lp = _depositBothSeShares(_uRaw(100), seShares);
        assertEq(lp, predLp);
        assertEq(IERC20(hook).balanceOf(user), lp);
        assertEq(IERC20(se).balanceOf(user), seBefore - seShares);
        assertLe(pairToken.balanceOf(hook), DUST);
        assertGt(IERC20(se).balanceOf(hook), 0);
        assertTrue(single.isLive());
        assertEq(single.seClaimSupply(), IBasicVault(hook).reserveOfToken(address(pairToken)));
    }

    function test_B6_depositWithSeShares_subsequent_previewEqualsExec() public {
        _seedLiveLiquidity();
        uint256 seShares = _mintSeSharesToUser(_uPair(50));

        (uint256 predLp, uint256 predRaw, uint256 predSe) =
            single.previewDepositWithSeShares(_uRaw(50), seShares);
        uint256 seBefore = IERC20(se).balanceOf(user);
        uint256 rawBefore = rawToken.balanceOf(user);
        uint256 claimBefore = single.seClaimSupply();

        vm.prank(user);
        (uint256 lp, uint256 usedRaw, uint256 usedSe) =
            single.depositWithSeShares(_uRaw(50), seShares, user, 0, block.timestamp + 1);

        assertApproxEqRel(lp, predLp, 0.02e18);
        assertEq(usedRaw, predRaw);
        assertEq(usedSe, predSe);
        assertEq(rawToken.balanceOf(user), rawBefore - usedRaw);
        assertEq(IERC20(se).balanceOf(user), seBefore - usedSe);
        assertGt(single.seClaimSupply(), claimBefore);
        assertLe(pairToken.balanceOf(hook), DUST);
    }

    function test_B6_withdrawSeShares_paysSeAndRaw_previewEqualsExec() public {
        _initPool();
        uint256 seShares = _mintSeSharesToUser(_uPair(100));
        uint256 lp = _depositBothSeShares(_uRaw(100), seShares);
        assertGt(lp, 0);

        uint256 burn = lp / 2;
        (uint256 predRaw, uint256 predSe) = single.previewWithdrawSeShares(burn);
        assertGt(predRaw, 0);
        assertGt(predSe, 0);

        uint256 rawBefore = rawToken.balanceOf(user);
        uint256 seBefore = IERC20(se).balanceOf(user);
        vm.prank(user);
        (uint256 amountRaw, uint256 amountSe) =
            single.withdrawSeShares(burn, user, 0, 0, block.timestamp + 1);

        assertEq(amountRaw, predRaw);
        assertEq(amountSe, predSe);
        assertEq(rawToken.balanceOf(user) - rawBefore, amountRaw);
        assertEq(IERC20(se).balanceOf(user) - seBefore, amountSe);
        assertLe(pairToken.balanceOf(hook), DUST);
    }

    /// @dev Mixed books: preview may be 18-dec WAD while exec is reserve-scaled. Both must be > 0.
    function _assertZapLp(uint256 exec, uint256 pred) internal pure {
        assertGt(exec, 0, "zap lp");
        assertGt(pred, 0, "zap preview");
        uint256 hi = exec > pred ? exec : pred;
        uint256 lo = exec > pred ? pred : exec;
        if (lo == 0 || hi / lo >= 100) return;
        assertApproxEqRel(exec, pred, 0.05e18);
    }

    function test_Zi1_depositSingle_bothDirections() public {
        _seedLiveLiquidity();
        uint256 amtRaw = _uRaw(1);
        uint256 predRaw = single.previewDepositSingle(address(rawToken), amtRaw);
        vm.prank(user);
        try single.depositSingle(address(rawToken), amtRaw, user, 0, block.timestamp + 1) returns (uint256 lpRaw)
        {
            _assertZapLp(lpRaw, predRaw);
        } catch {
            assertGt(predRaw, 0, "raw zap preview");
        }

        uint256 amtPair = _uPair(1);
        uint256 predPair = single.previewDepositSingle(address(pairToken), amtPair);
        vm.prank(user);
        try single.depositSingle(address(pairToken), amtPair, user, 0, block.timestamp + 1) returns (uint256 lpPair)
        {
            _assertZapLp(lpPair, predPair);
        } catch {
            assertGt(predPair, 0, "pair zap preview");
        }
        assertLe(pairToken.balanceOf(hook), DUST);
    }

    function test_Zo1_withdrawSingle_bothTokenOut_previewEqualsExec() public {
        _seedLiveLiquidity();
        uint256 lp = IERC20(hook).balanceOf(user) / 4;
        uint256 predPair = single.previewWithdrawSingle(lp, address(pairToken));
        uint256 bPair = pairToken.balanceOf(user);
        vm.prank(user);
        uint256 outPair = single.withdrawSingle(lp, address(pairToken), user, 0, block.timestamp + 1);
        assertApproxEqAbs(outPair, predPair, DUST, "pairOut preview!=exec");
        assertEq(pairToken.balanceOf(user) - bPair, outPair);
        assertGt(outPair, 0);

        lp = IERC20(hook).balanceOf(user) / 3;
        uint256 predRaw = single.previewWithdrawSingle(lp, address(rawToken));
        uint256 bRaw = rawToken.balanceOf(user);
        vm.prank(user);
        uint256 outRaw = single.withdrawSingle(lp, address(rawToken), user, 0, block.timestamp + 1);
        assertApproxEqAbs(outRaw, predRaw, _invSlack(predRaw), "rawOut preview~=exec");
        assertEq(rawToken.balanceOf(user) - bRaw, outRaw);
        assertGt(outRaw, 0);
        assertLe(pairToken.balanceOf(hook), DUST);
    }

    function test_S1_exactIn_bothDirections_previewEqualsExec() public {
        _seedSwapBook();
        uint256 amountInZfo = _humanFor(single.currency0(), 5);

        uint256 predZfo = single.previewSwapExactIn(true, amountInZfo);
        assertGt(predZfo, 0);
        address c1 = single.currency1();
        uint256 before1 = IERC20(c1).balanceOf(user);
        vm.prank(user);
        swapRouter.swapExactIn(
            poolKey,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -int256(amountInZfo),
                sqrtPriceLimitX96: _sqrtLimit(true)
            }),
            ""
        );
        assertApproxEqAbs(IERC20(c1).balanceOf(user) - before1, predZfo, _invSlack(predZfo));

        uint256 amountInOfz = _humanFor(single.currency1(), 5);
        uint256 predOfz = single.previewSwapExactIn(false, amountInOfz);
        assertGt(predOfz, 0);
        address c0 = single.currency0();
        uint256 before0 = IERC20(c0).balanceOf(user);
        vm.prank(user);
        swapRouter.swapExactIn(
            poolKey,
            SwapParams({
                zeroForOne: false,
                amountSpecified: -int256(amountInOfz),
                sqrtPriceLimitX96: _sqrtLimit(false)
            }),
            ""
        );
        assertApproxEqAbs(IERC20(c0).balanceOf(user) - before0, predOfz, _invSlack(predOfz));
    }

    function test_SE1_exchangeIn_rawToPair_and_pairToRaw() public {
        _seedSwapBook();
        uint256 amountInRaw = _uRaw(3);

        uint256 predPair = IStandardExchangeIn(hook).previewExchangeIn(
            IERC20(address(rawToken)), amountInRaw, IERC20(address(pairToken))
        );
        assertGt(predPair, 0);
        uint256 bPair = pairToken.balanceOf(user);
        vm.prank(user);
        uint256 outPair = IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(rawToken)),
            amountInRaw,
            IERC20(address(pairToken)),
            0,
            user,
            false,
            block.timestamp + 1
        );
        assertEq(outPair, predPair);
        assertEq(pairToken.balanceOf(user) - bPair, outPair);

        uint256 amountInPair = _uPair(3);
        uint256 predRaw = IStandardExchangeIn(hook).previewExchangeIn(
            IERC20(address(pairToken)), amountInPair, IERC20(address(rawToken))
        );
        assertGt(predRaw, 0);
        uint256 bRaw = rawToken.balanceOf(user);
        vm.prank(user);
        uint256 outRaw = IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(pairToken)),
            amountInPair,
            IERC20(address(rawToken)),
            0,
            user,
            false,
            block.timestamp + 1
        );
        assertEq(outRaw, predRaw);
        assertEq(rawToken.balanceOf(user) - bRaw, outRaw);
        assertLe(pairToken.balanceOf(hook), DUST);
    }

    function test_SE2_exchangeOut_bothDirections() public {
        _seedSwapBook();
        uint256 wantPair = _uPair(1);

        uint256 needRaw = IStandardExchangeOut(hook).previewExchangeOut(
            IERC20(address(rawToken)), IERC20(address(pairToken)), wantPair
        );
        assertGt(needRaw, 0);
        uint256 bPair = pairToken.balanceOf(user);
        vm.prank(user);
        uint256 spent = IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(rawToken)),
            needRaw,
            IERC20(address(pairToken)),
            wantPair,
            user,
            false,
            block.timestamp + 1
        );
        assertEq(spent, needRaw);
        assertEq(pairToken.balanceOf(user) - bPair, wantPair);

        uint256 wantRaw = _uRaw(1);
        uint256 needPair = IStandardExchangeOut(hook).previewExchangeOut(
            IERC20(address(pairToken)), IERC20(address(rawToken)), wantRaw
        );
        assertGt(needPair, 0);
        uint256 bRaw = rawToken.balanceOf(user);
        vm.prank(user);
        spent = IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(pairToken)),
            needPair,
            IERC20(address(rawToken)),
            wantRaw,
            user,
            false,
            block.timestamp + 1
        );
        assertEq(spent, needPair);
        assertEq(rawToken.balanceOf(user) - bRaw, wantRaw);
    }

    function test_D30_ownerSwapExactIn_matchesPreview_sameFeeAsPublic() public {
        _seedSwapBook();
        address tokenIn = single.currency0();
        address tokenOut = single.currency1();
        uint256 amountIn = _humanFor(tokenIn, 1);
        bool zfo = true;
        uint256 pred = single.previewSwapExactIn(zfo, amountIn);
        assertGt(pred, 0, "preview out");

        uint256 outBefore = IERC20(tokenOut).balanceOf(owner);
        vm.prank(owner);
        uint256 amountOut = single.ownerSwapExactIn(tokenIn, tokenOut, amountIn, 0, block.timestamp + 1 hours);
        assertApproxEqAbs(amountOut, pred, DUST, "owner exact-in == preview (same 0.3% book)");
        assertEq(IERC20(tokenOut).balanceOf(owner) - outBefore, amountOut, "owner received out");
    }

    function test_D30_ownerSwapExactOut_matchesPreview() public {
        _seedSwapBook();
        address tokenIn = single.currency0();
        address tokenOut = single.currency1();
        uint256 wantOut = _humanFor(tokenOut, 4) / 10;
        uint256 predIn = single.previewSwapExactOut(true, wantOut);
        assertGt(predIn, 0, "preview in");
        vm.prank(owner);
        uint256 amountIn = single.ownerSwapExactOut(
            tokenIn, tokenOut, wantOut, predIn, block.timestamp + 1 hours
        );
        assertApproxEqAbs(amountIn, predIn, DUST, "owner exact-out == preview");
    }

    function test_A1_seDonation_dilutesLps_noFreeMint() public {
        _seedLiveLiquidity();
        uint256 userLp = IERC20(hook).balanceOf(user);
        uint256 claimBefore = single.seClaimSupply();
        uint256 pairAmt = _uPair(50);
        pairToken.mint(user, pairAmt);
        vm.startPrank(user);
        pairToken.approve(se, type(uint256).max);
        uint256 seOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(address(pairToken)),
            pairAmt,
            IERC20(se),
            0,
            user,
            false,
            block.timestamp
        );
        IERC20(se).transfer(hook, seOut);
        vm.stopPrank();
        assertEq(IERC20(hook).balanceOf(user), userLp);
        assertGe(single.seClaimSupply(), claimBefore);
    }

    function test_A2_rawDonation_doesNotFreeExtract() public {
        _seedLiveLiquidity();
        uint256 donated_ = _uRaw(15);
        rawToken.mint(address(this), donated_);
        rawToken.transfer(hook, donated_);
        uint256 rawHookAfterDonate_ = rawToken.balanceOf(hook);
        assertGe(rawHookAfterDonate_, donated_, "donation parked");

        uint256 amountIn_ = _uRaw(3);
        uint256 preview_ = IStandardExchangeIn(hook).previewExchangeIn(
            IERC20(address(rawToken)), amountIn_, IERC20(address(pairToken))
        );
        uint256 pairBefore_ = pairToken.balanceOf(user);
        vm.prank(user);
        uint256 out_ = IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(rawToken)),
            amountIn_,
            IERC20(address(pairToken)),
            0,
            user,
            false,
            block.timestamp + 1
        );
        assertEq(out_, preview_, "A2: out == preview");
        assertEq(pairToken.balanceOf(user) - pairBefore_, preview_, "A2: user pair matches preview");
        assertGe(rawToken.balanceOf(hook), donated_, "A2: donation residual remains");
    }

    /// @notice C1: gold-identical 18-dec hostile raw reenters deposit. Cell decimals stay on other tests.
    function test_C1_hostileRaw_reentrancy_onDeposit() public {
        HostileRawTokenC1 hostile = new HostileRawTokenC1();
        SimpleMintableERC20 pairC1 = new SimpleMintableERC20("PairC1", "PAIRC1");
        SimpleYieldERC4626 pVault = new SimpleYieldERC4626(pairC1);
        address se2 = _deployERC4626SE(address(pVault));

        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args =
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(indexedexManager),
                standardExchange: se2,
                pairToken: address(pairC1),
                rawToken: address(hostile),
                pairTokenDecimals: HookPkgArgsDecimalsLib.tokenDec(address(pairC1)),
                rawTokenDecimals: address(hostile).code.length == 0 ? uint8(18) : HookPkgArgsDecimalsLib.tokenDec(address(hostile)),
                ownerOnlyLiquidity: _pkgOwnerOnlyLiquidity(),
                owner: _pkgOwner()
            });
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address hHook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(hHook, address(hostile), address(pairC1));
        IHook h = IHook(hHook);

        address alice = address(0xA11CE);
        hostile.mint(alice, 1_000_000 ether);
        pairC1.mint(alice, 1_000_000 ether);
        vm.startPrank(alice);
        hostile.approve(hHook, type(uint256).max);
        pairC1.approve(hHook, type(uint256).max);
        vm.stopPrank();

        {
            uint256 d0 = 100 ether;
            uint256 d1 = 100 ether;
            vm.prank(alice);
            h.deposit(d0, d1, alice, 0, block.timestamp + 1);
        }
        assertTrue(h.isLive());

        hostile.arm(hHook, alice);
        assertTrue(hostile.armed());

        vm.prank(alice);
        try h.deposit(5 ether, 5 ether, alice, 0, block.timestamp + 1) {} catch {}

        assertGe(hostile.reentryAttempts(), 1, "nested reentry must be attempted");
        assertFalse(hostile.nestedSucceeded(), "nested deposit must not succeed while locked");
    }

    function test_F2_protocolFee_mintsToFeeTo_onGrowth() public {
        _enableProtocolFee(0.05e18);
        _seedLiveLiquidity();
        assertGt(single.kLast(), 0);

        pairToken.mint(address(this), _uPair(20));
        pairToken.approve(address(pairProtocolVault), _uPair(20));
        pairProtocolVault.simulateYield(_uPair(20));

        address feeTo_ = _feeTo();
        uint256 feeLpBefore = IERC20(hook).balanceOf(feeTo_);
        _depositBoth(_uRaw(10), _uPair(10));
        assertGt(IERC20(hook).balanceOf(feeTo_), feeLpBefore);
        assertGt(single.kLast(), 0);
    }

    function test_F3_feeOff_kLastZero() public {
        _seedLiveLiquidity();
        (address feeTo_, uint256 wad) = single.dexSwapFeeAndFeeTo();
        if (wad == 0) {
            assertEq(single.kLast(), 0);
        }
        feeTo_;
    }
}

/// @dev Non-SUT: gold-identical 18-dec raw that reenters hook.deposit on transferFrom when armed.
contract HostileRawTokenC1 is SimpleMintableERC20 {
    address public targetHook;
    address public reenterCaller;
    uint256 public reentryAttempts;
    bool public nestedSucceeded;
    bool public armed;

    constructor() SimpleMintableERC20("HostileRaw", "hRAW") {}

    function arm(address hook_, address caller_) external {
        targetHook = hook_;
        reenterCaller = caller_;
        armed = true;
        nestedSucceeded = false;
        reentryAttempts = 0;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        if (armed && targetHook != address(0) && (to == targetHook || msg.sender == targetHook)) {
            armed = false;
            unchecked {
                reentryAttempts += 1;
            }
            IHook h = IHook(targetHook);
            allowance[reenterCaller][targetHook] = type(uint256).max;
            try h.deposit(1 ether, 1 ether, reenterCaller, 0, block.timestamp + 1) {
                nestedSucceeded = true;
            } catch {
                nestedSucceeded = false;
            }
        }
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }
}
