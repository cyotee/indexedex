// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TestBase_UniswapV4StandardExchangeOrbitalBufferHook_Decimals} from
    "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook_Decimals.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";
import {ReentrantMockERC20} from "contracts/test/stubs/ReentrantMockERC20.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";

/// @dev Minimal IRateProvider harness (not a mock of the hook SUT). Copied from gold RateProvider suite.
contract StaticRateProviderDecimals {
    uint256 public immutable rate;
    bool public fail;

    constructor(uint256 rate_) {
        rate = rate_;
    }

    function setFail(bool f) external {
        fail = f;
    }

    function getRate() external view returns (uint256) {
        if (fail) revert("rate fail");
        return rate;
    }
}

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHook_Decimals
 * @notice PRD §5.6 SE orbital money-paths on each `B_*` book.
 * @dev pairToken = token0 (construction order). After PoolKey sort, currency0/currency1 may
 *      swap; amounts are `_u0/_u1/_u2` raw units. Hook LP / vaultShare stay 18. Wrappers override `_dec*`.
 *      First-mint two-leg/three-leg run on every book including B_P9_* and B_P18_R6.
 */
abstract contract UniswapV4StandardExchangeOrbitalBufferHook_Decimals is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook_Decimals
{
    /* ---------------------------------------------------------------------- */
    /*                              Liquidity                                 */
    /* ---------------------------------------------------------------------- */

    function test_firstMint_twoLegs_setsR() public {
        (uint256 a0, uint256 a1, uint256 a2) = _twoLegFirstMintAmounts();
        (uint256 shares, uint256 u0, uint256 u1, uint256 u2) = _addLiquidity(a0, a1, a2);
        assertGt(shares, 0, "shares");
        assertEq(u0, a0);
        assertEq(u1, a1);
        assertEq(u2, a2);
        assertGt(orbital.radius(), 0, "R set");
        assertGt(orbital.lSquared(), 0, "L2");
        assertEq(IERC20(hook).balanceOf(user), shares);
    }

    function test_firstMint_threeLegs() public {
        uint256 shares = _seedThreeLegHuman(100);
        assertGt(shares, 0);
        _assertLegBook(0, _u0(100));
        _assertLegBook(1, _u1(100));
        _assertLegBook(2, _u2(100));
        assertGt(orbital.radius(), 0);
    }

    function test_fullBook_subsequent_previewEqualsExec() public {
        _seedThreeLegHuman(200);
        (uint256 pShares, uint256 p0, uint256 p1, uint256 p2) =
            orbital.previewAddLiquidity(_u0(50), _u1(50), _u2(50));
        (uint256 eShares, uint256 e0, uint256 e1, uint256 e2) =
            _addLiquidity(_u0(50), _u1(50), _u2(50));
        _assertMoneyEq(eShares, pShares, "shares");
        _assertMoneyEq(e0, p0, "u0");
        _assertMoneyEq(e1, p1, "u1");
        _assertMoneyEq(e2, p2, "u2");
    }

    function test_remove_previewEqualsExec() public {
        uint256 shares = _seedThreeLegHuman(100);
        uint256 half = shares / 2;
        (uint256 p0, uint256 p1, uint256 p2) = orbital.previewRemoveLiquidity(half);
        vm.prank(user);
        (uint256 a0, uint256 a1, uint256 a2) =
            orbital.removeLiquidity(half, user, 0, 0, 0, block.timestamp + 1 hours);
        _assertMoneyEq(a0, p0, "a0");
        _assertMoneyEq(a1, p1, "a1");
        _assertMoneyEq(a2, p2, "a2");
    }

    function test_partialBook_seedThirdLeg() public {
        (uint256 a0, uint256 a1, uint256 a2) = _twoLegFirstMintAmounts();
        _addLiquidity(a0, a1, a2);
        uint256 z0 = a0 == 0 ? _u0(50) : 0;
        uint256 z1 = a1 == 0 ? _u1(50) : 0;
        uint256 z2 = a2 == 0 ? _u2(50) : 0;
        if (z0 == 0 && z1 == 0 && z2 == 0) {
            // ALL6/ALL9 already three-leg first mint.
            assertGt(orbital.effectiveReserve(2), 0);
            return;
        }
        (uint256 shares,,,) = _addLiquidity(z0, z1, z2);
        assertGt(shares, 0);
        if (z0 > 0) assertGt(orbital.effectiveReserve(0), 0);
        if (z1 > 0) assertGt(orbital.effectiveReserve(1), 0);
        if (z2 > 0) assertGt(orbital.effectiveReserve(2), 0);
    }

    /* ---------------------------------------------------------------------- */
    /*                                  B6                                    */
    /* ---------------------------------------------------------------------- */

    function test_B6_firstMint_withSeShares() public {
        if (!(orbital.isBuffered(0) && orbital.isBuffered(1) && orbital.isBuffered(2))) {
            IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args =
                _argsWithSE(true, true, true);
            uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
            hook = PkgFactory.deployHook(hookPkg, args, mineNonce);
            _ensureProductDoorsAndFinalize(hook);
            orbital = IUniswapV4StandardExchangeOrbitalBufferHook(hook);
        }

        uint256 s0 = _mintSeSharesToUser(se0, token0, _u0(80));
        uint256 s1 = _mintSeSharesToUser(se1, token1, _u1(80));
        uint256 s2 = _mintSeSharesToUser(se2, token2, _u2(80));
        vm.startPrank(user);
        IERC20(se0).approve(hook, type(uint256).max);
        IERC20(se1).approve(hook, type(uint256).max);
        IERC20(se2).approve(hook, type(uint256).max);
        (uint256 shares,,,) = orbital.depositFlexible(
            s0, true, s1, true, s2, true, user, 0, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(shares, 0);
        assertGt(orbital.radius(), 0);
    }

    /* ---------------------------------------------------------------------- */
    /*                                 Swap                                   */
    /* ---------------------------------------------------------------------- */

    function test_swap_exactIn_allSixDirections() public {
        _seedThreeLegHuman(500);
        address[3] memory t = [address(token0), address(token1), address(token2)];
        for (uint256 i; i < 3; i++) {
            for (uint256 j; j < 3; j++) {
                if (i == j) continue;
                uint256 amountIn = _uFor(t[i], 1);
                uint256 preview = orbital.previewSwapExactIn(t[i], t[j], amountIn);
                assertGt(preview, 0, "preview out");
                uint256 balBefore = IERC20(t[j]).balanceOf(user);
                _swapExactIn(t[i], t[j], amountIn);
                uint256 balAfter = IERC20(t[j]).balanceOf(user);
                _assertMoneyEq(balAfter - balBefore, preview, "preview==exec");
            }
        }
    }

    function test_swap_exactOut_preview() public {
        _seedThreeLegHuman(500);
        uint256 amountOut = _u1(1);
        uint256 amountIn = orbital.previewSwapExactOut(address(token0), address(token1), amountOut);
        assertGt(amountIn, 0);
        uint256 out = orbital.previewSwapExactIn(address(token0), address(token1), amountIn);
        _assertMoneyEq(out, amountOut, "round-trip");
    }

    function test_swap_exactOut_execution_previewEqualsExec() public {
        _seedThreeLegHuman(500);
        uint256 amountOut = _u1(1);
        uint256 amountIn = orbital.previewSwapExactOut(address(token0), address(token1), amountOut);
        assertGt(amountIn, 0);

        PoolKey memory key = _poolKeyFor(address(token0), address(token1));
        bool zeroForOne = address(token0) == Currency.unwrap(key.currency0);
        uint256 balOutBefore = token1.balanceOf(user);
        uint256 balInBefore = token0.balanceOf(user);

        vm.prank(user);
        swapRouter.swapExactOut(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: int256(amountOut),
                sqrtPriceLimitX96: _sqrtLimit(zeroForOne)
            }),
            amountIn + _u0(1),
            ""
        );

        uint256 gotOut = token1.balanceOf(user) - balOutBefore;
        uint256 paidIn = balInBefore - token0.balanceOf(user);
        _assertMoneyEq(gotOut, amountOut, "exact-out amount");
        _assertMoneyEq(paidIn, amountIn, "exact-out input matches preview");
    }

    /* ---------------------------------------------------------------------- */
    /*                              SE exchange                               */
    /* ---------------------------------------------------------------------- */

    function test_exchangeIn_previewEqualsExec() public {
        _seedThreeLegHuman(500);
        uint256 amountIn = _u0(5);
        uint256 preview = IStandardExchangeIn(hook).previewExchangeIn(
            IERC20(address(token0)), amountIn, IERC20(address(token1))
        );
        assertGt(preview, 0);
        uint256 balBefore = token1.balanceOf(user);
        vm.prank(user);
        uint256 out = IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token0)),
            amountIn,
            IERC20(address(token1)),
            preview,
            user,
            false,
            block.timestamp + 1 hours
        );
        _assertMoneyEq(out, preview, "exchangeIn");
        _assertMoneyEq(token1.balanceOf(user) - balBefore, out, "token1 moved");
    }

    function test_exchangeOut_previewEqualsExec() public {
        _seedThreeLegHuman(500);
        uint256 amountOut = _u1(2);
        uint256 amountIn = IStandardExchangeOut(hook).previewExchangeOut(
            IERC20(address(token0)), IERC20(address(token1)), amountOut
        );
        assertGt(amountIn, 0);
        uint256 balBefore = token1.balanceOf(user);
        vm.prank(user);
        uint256 paid = IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(token0)),
            amountIn,
            IERC20(address(token1)),
            amountOut,
            user,
            false,
            block.timestamp + 1 hours
        );
        _assertMoneyEq(paid, amountIn, "exchangeOut paid");
        _assertMoneyEq(token1.balanceOf(user) - balBefore, amountOut, "token1 out");
    }

    /* ---------------------------------------------------------------------- */
    /*                                Buffer                                  */
    /* ---------------------------------------------------------------------- */

    function test_bufferedLeg_freeTokenNotBook() public {
        _seedThreeLegHuman(100);
        _assertLegBook(0, _u0(100));
        _assertLegBook(1, _u1(100));
        _assertLegBook(2, _u2(100));
    }

    /* ---------------------------------------------------------------------- */
    /*                                 Fees                                   */
    /* ---------------------------------------------------------------------- */

    function test_protocolGrowth_onAdd_assertGt() public {
        _seedThreeLegHuman(200);
        _setUsageFee(0.05e18);
        _setDexFee(0.01e18);
        _addLiquidity(_u0(1), _u1(1), _u2(1));
        assertGt(orbital.kLast(), 0, "kLast set");

        for (uint256 i; i < 5; i++) {
            _swapExactIn(address(token0), address(token1), _u0(5));
            _swapExactIn(address(token1), address(token0), _u1(5));
        }

        address ft = orbital.feeTo();
        uint256 feeBalBefore = IERC20(hook).balanceOf(ft);
        _addLiquidity(_u0(2), _u1(2), _u2(2));
        uint256 feeBalAfter = IERC20(hook).balanceOf(ft);
        assertGt(feeBalAfter, feeBalBefore, "protocol growth LP must mint to feeTo");
        assertEq(
            uint8(orbital.kLastMode()),
            uint8(IUniswapV4StandardExchangeOrbitalBufferHook.KLastMode.FullProduct)
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                             Rate provider                              */
    /* ---------------------------------------------------------------------- */

    function test_RP1_effectiveReserve_is_sharesTimesRate() public {
        StaticRateProviderDecimals rp = new StaticRateProviderDecimals(2e18);
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args = _argsWithSE(
            true, token1.decimals() != 18, token2.decimals() != 18
        );
        args.rp0 = address(rp);
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(h);
        IUniswapV4StandardExchangeOrbitalBufferHook o = IUniswapV4StandardExchangeOrbitalBufferHook(h);

        token0.mint(user, _u0(500));
        token1.mint(user, _u1(500));
        token2.mint(user, _u2(500));
        vm.startPrank(user);
        token0.approve(h, type(uint256).max);
        token1.approve(h, type(uint256).max);
        token2.approve(h, type(uint256).max);
        o.addLiquidity(_u0(100), _u1(100), _u2(100), user, 0, block.timestamp + 1 hours, "");
        vm.stopPrank();

        uint256 seBal = o.seBalance(0);
        assertGt(seBal, 0, "SE shares");
        uint256 expected = (seBal * 2e18) / 1e18;
        assertEq(o.effectiveReserve(0), expected, "effective = shares * rate / 1e18");
        assertEq(o.rateProvider(0), address(rp));
    }

    /* ---------------------------------------------------------------------- */
    /*                              Adversarial                               */
    /* ---------------------------------------------------------------------- */

    /// @notice C1: hostile token reenters addLiquidity mid transferFrom → outer fails; no LP mint.
    /// @dev 18-dec hostile + 18-dec t0/t1. Independent of book decimals (mixed pull can be flaky).
    function test_C1_reentrancy_addLiquidity_duringTransferFrom_reverts() public {
        ReentrantMockERC20 hostile = new ReentrantMockERC20("HOST", "HOST", 18);
        SimpleMintableERC20 t0 = new SimpleMintableERC20("A", "A");
        SimpleMintableERC20 t1 = new SimpleMintableERC20("B", "B");
        require(
            address(t0) != address(t1) && address(t1) != address(hostile)
                && address(t0) != address(hostile),
            "addr"
        );
        SimpleYieldERC4626 v0 = new SimpleYieldERC4626(t0);
        address seLeg0 = _deployERC4626SE(address(v0));

        IPoolManager pm2 = IPoolManager(address(new PoolManager(address(this))));
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args =
            IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs({
            poolManager: address(pm2),
            feeOracle: address(indexedexManager),
            token0: address(t0),
            token1: address(t1),
            token2: address(hostile),
            decimals0: HookPkgArgsDecimalsLib.tokenDec(address(t0)),
            decimals1: HookPkgArgsDecimalsLib.tokenDec(address(t1)),
            decimals2: HookPkgArgsDecimalsLib.tokenDec(address(hostile)),
            se0: seLeg0,
            se1: address(0),
            se2: address(0),
            rp0: address(0),
            rp1: address(0),
            rp2: address(0),
            tickSpacing: 0,
            sqrtPriceX96: 0,
            ownerOnlyLiquidity: _pkgOwnerOnlyLiquidity(),
            owner: _pkgOwner()
        });
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(h, address(t0), address(t1), address(hostile));
        IUniswapV4StandardExchangeOrbitalBufferHook o = IUniswapV4StandardExchangeOrbitalBufferHook(h);

        t0.mint(user, 1_000_000 ether);
        t1.mint(user, 1_000_000 ether);
        hostile.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        t0.approve(h, type(uint256).max);
        t1.approve(h, type(uint256).max);
        hostile.approve(h, type(uint256).max);
        o.addLiquidity(100 ether, 100 ether, 100 ether, user, 0, block.timestamp + 1 hours, "");
        vm.stopPrank();

        uint256 sharesBefore = IERC20(h).balanceOf(user);
        bytes memory reentry = abi.encodeWithSelector(
            IUniswapV4StandardExchangeOrbitalBufferHook.addLiquidity.selector,
            uint256(1 ether),
            uint256(1 ether),
            uint256(1 ether),
            user,
            uint256(0),
            block.timestamp + 1 hours,
            bytes("")
        );
        hostile.arm(h, reentry);

        vm.prank(user);
        (bool ok,) = h.call(
            abi.encodeWithSelector(
                IUniswapV4StandardExchangeOrbitalBufferHook.addLiquidity.selector,
                uint256(10 ether),
                uint256(10 ether),
                uint256(10 ether),
                user,
                uint256(0),
                block.timestamp + 1 hours,
                bytes("")
            )
        );
        assertFalse(ok, "outer addLiquidity must fail under reentrancy");
        assertEq(IERC20(h).balanceOf(user), sharesBefore, "no LP minted under reentrancy");
    }

    /// @dev Gold two-leg is token0+token1 with token2=0. Non-18 self-legs are SE-buffered;
    ///      prefer a remaining 18-dec raw leg, else three-leg (ALL6/ALL9).
    function _twoLegFirstMintAmounts() internal view returns (uint256 a0, uint256 a1, uint256 a2) {
        a0 = _u0(100);
        if (!orbital.isBuffered(1)) {
            a1 = _u1(100);
            return (a0, a1, 0);
        }
        if (!orbital.isBuffered(2)) {
            a2 = _u2(100);
            return (a0, 0, a2);
        }
        return (a0, _u1(100), _u2(100));
    }

    function _assertLegBook(uint8 i, uint256 face) internal view {
        if (orbital.isBuffered(i)) {
            assertEq(orbital.rawReserve(i), 0, "buffered raw book");
            assertGt(orbital.seBalance(i), 0, "SE shares");
            assertGt(orbital.effectiveReserve(i), 0, "effective > 0");
        } else {
            assertEq(orbital.rawReserve(i), face, "raw leg face");
            assertEq(orbital.effectiveReserve(i), face, "raw effective");
        }
    }
}
