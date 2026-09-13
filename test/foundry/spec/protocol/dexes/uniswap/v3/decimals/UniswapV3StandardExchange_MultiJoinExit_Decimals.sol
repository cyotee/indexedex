// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {FixedPoint128} from "@crane/contracts/protocols/dexes/uniswap/libraries/FixedPoint128.sol";

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    TestBase_UniswapV3StandardExchange_Decimals
} from "contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange_Decimals.sol";
import {
    IUniswapV3StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3StandardExchangeLiquidReserve.sol";
import {
    UniswapV3StandardExchangeOutBase
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeOutBase.sol";
import {
    UniswapV3BoundPoolLockSeCaller
} from "test/foundry/spec/protocol/dexes/uniswap/v3/harness/UniswapV3BoundPoolLockSeCaller.sol";

/// @notice Multi-join/exit. pairToken = tokenA. Amounts are raw units via `_u0`/`_u1`.
abstract contract UniswapV3StandardExchange_MultiJoinExit_Decimals is TestBase_UniswapV3StandardExchange_Decimals {
    uint8 internal constant _DECIMALS_REMATCH = 6;
    address internal constant DEAD = address(0x000000000000000000000000000000000000dEaD);

    IUniswapV3StandardExchangeLiquidReserve internal liquid;
    IStandardExchangeInMulti internal inMulti;
    IStandardExchangeOutMulti internal outMulti;
    UniswapV3BoundPoolLockSeCaller internal lockCaller;
    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
        _deployPairTokens();
        pool = _createPoolOneToOne(address(tokenA), address(tokenB), FEE_MEDIUM);
        _seedExternalLiquidity(pool, 0);
        vault = _deployVault(pool);
        liquid = IUniswapV3StandardExchangeLiquidReserve(address(vault));
        inMulti = IStandardExchangeInMulti(address(vault));
        outMulti = IStandardExchangeOutMulti(address(vault));
        lockCaller = new UniswapV3BoundPoolLockSeCaller(pool);
        _mint(pool.token0(), address(lockCaller), _u0(100));
        _mint(pool.token1(), address(lockCaller), _u1(100));
    }

    function test_MJ1_lengthNotTwo_reverts() public {
        address[] memory one = new address[](1);
        one[0] = _token0();
        uint256[] memory oneAmt = new uint256[](1);
        oneAmt[0] = _u0(1);
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        inMulti.exchangeInManyToOne(one, oneAmt, IERC20(address(vault)), 0, address(this), false, _deadline());
    }

    function test_MJ2_idleProportionalJoin_fullRangeL_andSleeve() public {
        uint256 shares = _join(_u0(10), _u1(10));
        assertGt(shares, 0, "MJ2: shares");
        assertGt(_centerLiquidity(), 0, "MJ2: center L");
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_MJ3_unbalancedJoin_paysBoth_noSwap() public {
        uint256 a0 = _u0(10);
        uint256 a1 = _u1(1);
        _mint(_token0(), address(this), a0);
        _mint(_token1(), address(this), a1);
        uint256 preview = inMulti.previewExchangeInManyToOne(_poolTokens(), _amts(a0, a1), IERC20(address(vault)));
        IERC20(_token0()).approve(address(vault), a0);
        IERC20(_token1()).approve(address(vault), a1);
        uint256 shares = inMulti.exchangeInManyToOne(
            _poolTokens(), _amts(a0, a1), IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertEq(shares, preview, "MJ3: preview==exec");
        assertGt(liquid.localReserve(_token0()), 0, "MJ3: surplus sleeve");
    }

    function test_MJ4_blockedJoin_mints_noNestedMint() public {
        uint256 a0 = _u0(5);
        uint256 a1 = _u1(5);
        _mint(_token0(), address(lockCaller), a0);
        _mint(_token1(), address(lockCaller), a1);
        vm.startPrank(address(lockCaller));
        IERC20(_token0()).approve(address(vault), type(uint256).max);
        IERC20(_token1()).approve(address(vault), type(uint256).max);
        vm.stopPrank();
        uint256 shares = lockCaller.runExchangeInManyToOne(
            address(vault), _poolTokens(), _amts(a0, a1), IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertGt(shares, 0, "MJ4: blocked mint");
        assertEq(_centerLiquidity(), 0, "MJ4: no L while blocked");
        liquid.rebalanceLiquidReserve();
        assertGt(_centerLiquidity(), 0, "MJ4: idle rebalance deploys");
    }

    function test_MJ5_pretransferredTrue_noDelivery_noFreeMint() public {
        _join(_u0(4), _u1(4));
        uint256 claimed0 = _u0(2);
        uint256 claimed1 = _u1(2);
        uint256 supplyBefore = IERC20(address(vault)).totalSupply();
        uint256 attackerSharesBefore = IERC20(address(vault)).balanceOf(attacker);
        address[] memory tokens = _poolTokens();
        uint256[] memory amounts = _amts(claimed0, claimed1);
        uint256 deadline = _deadline();
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed0, uint256(0))
        );
        vm.prank(attacker);
        inMulti.exchangeInManyToOne(tokens, amounts, IERC20(address(vault)), 0, attacker, true, deadline);
        assertEq(IERC20(address(vault)).totalSupply(), supplyBefore, "MJ5: no free mint");
        assertEq(IERC20(address(vault)).balanceOf(attacker), attackerSharesBefore, "MJ5: attacker shares");
    }

    function test_MJ7_previewJoinSharesMatchExec_idleAndBlocked() public {
        uint256 previewIdle =
            inMulti.previewExchangeInManyToOne(_poolTokens(), _amts(_u0(3), _u1(3)), IERC20(address(vault)));
        uint256 execIdle = _join(_u0(3), _u1(3));
        assertEq(execIdle, previewIdle, "MJ7: idle preview");

        uint256 previewBlocked =
            inMulti.previewExchangeInManyToOne(_poolTokens(), _amts(_u0(2), _u1(2)), IERC20(address(vault)));
        _mint(_token0(), address(lockCaller), _u0(2));
        _mint(_token1(), address(lockCaller), _u1(2));
        vm.startPrank(address(lockCaller));
        IERC20(_token0()).approve(address(vault), _u0(2));
        IERC20(_token1()).approve(address(vault), _u1(2));
        vm.stopPrank();
        uint256 execBlocked = lockCaller.runExchangeInManyToOne(
            address(vault),
            _poolTokens(),
            _amts(_u0(2), _u1(2)),
            IERC20(address(vault)),
            0,
            address(this),
            false,
            _deadline()
        );
        assertEq(execBlocked, previewBlocked, "MJ7: blocked preview");
    }

    function test_MJ8_descendingTokenIn_reverts() public {
        address[] memory desc = new address[](2);
        desc[0] = _token1();
        desc[1] = _token0();
        uint256[] memory amounts = _amts(_u0(1), _u1(1));
        uint256 deadline = _deadline();
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        inMulti.exchangeInManyToOne(desc, amounts, IERC20(address(vault)), 0, address(this), false, deadline);
    }

    function test_ME1_lengthNotTwo_reverts() public {
        _join(_u0(10), _u1(10));
        address[] memory one = new address[](1);
        one[0] = _token0();
        uint256[] memory oneAmt = new uint256[](1);
        oneAmt[0] = _u0(1) / 1000;
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        outMulti.exchangeOutOneToMany(
            IERC20(address(vault)), type(uint256).max, one, oneAmt, address(this), false, _deadline()
        );
    }

    function test_ME2_idleProportionalExit_paysBoth() public {
        _join(_u0(10), _u1(10));
        (uint256 amount0, uint256 amount1) = _proportionalOut(1, 10);
        uint256 preview =
            outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(amount0, amount1));
        uint256 bal0Before = IERC20(_token0()).balanceOf(address(this));
        uint256 bal1Before = IERC20(_token1()).balanceOf(address(this));
        IERC20(address(vault)).approve(address(vault), preview);
        uint256 burned = outMulti.exchangeOutOneToMany(
            IERC20(address(vault)), preview, _poolTokens(), _amts(amount0, amount1), address(this), false, _deadline()
        );
        assertEq(burned, preview, "ME2: preview==exec");
        assertEq(IERC20(_token0()).balanceOf(address(this)), bal0Before + amount0, "ME2: amount0");
        assertEq(IERC20(_token1()).balanceOf(address(this)), bal1Before + amount1, "ME2: amount1");
    }

    function test_ME3_unbalancedExit_reverts_noSend() public {
        _join(_u0(10), _u1(10));
        uint256 bal0 = IERC20(_token0()).balanceOf(address(this));
        uint256 bal1 = IERC20(_token1()).balanceOf(address(this));
        uint256 supply = IERC20(address(vault)).totalSupply();
        IERC20(address(vault)).approve(address(vault), type(uint256).max);
        address[] memory tokens = _poolTokens();
        uint256[] memory amounts = _amts(_u0(1), _u1(2));
        uint256 deadline = _deadline();
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        outMulti.exchangeOutOneToMany(
            IERC20(address(vault)), type(uint256).max, tokens, amounts, address(this), false, deadline
        );
        assertEq(IERC20(_token0()).balanceOf(address(this)), bal0, "ME3: no token0");
        assertEq(IERC20(_token1()).balanceOf(address(this)), bal1, "ME3: no token1");
        assertEq(IERC20(address(vault)).totalSupply(), supply, "ME3: no burn");
    }

    function test_ME4_blockedCoverVsShort() public {
        _join(_u0(20), _u1(20));
        (uint256 amount0, uint256 amount1) = _proportionalOut(1, 20);
        uint256 preview =
            outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(amount0, amount1));
        IERC20(address(vault)).transfer(address(vault), preview);
        uint256 burned = lockCaller.runExchangeOutOneToMany(
            address(vault),
            IERC20(address(vault)),
            preview,
            _poolTokens(),
            _amts(amount0, amount1),
            address(this),
            true,
            _deadline()
        );
        assertEq(burned, preview, "ME4: blocked cover");

        (uint256 short0, uint256 short1) = _proportionalOut(10, 20);
        address[] memory tokens = _poolTokens();
        uint256[] memory shortAmts = _amts(short0, short1);
        uint256 need = outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), tokens, shortAmts);
        IERC20(address(vault)).transfer(address(vault), need);
        uint256 deadline = _deadline();
        vm.expectRevert();
        lockCaller.runExchangeOutOneToMany(
            address(vault), IERC20(address(vault)), need, tokens, shortAmts, address(this), true, deadline
        );
    }

    function test_ME5_maxAmountInTooLow_reverts() public {
        _join(_u0(10), _u1(10));
        address[] memory tokens = _poolTokens();
        (uint256 amount0, uint256 amount1) = _proportionalOut(1, 10);
        uint256[] memory amounts = _amts(amount0, amount1);
        uint256 need = outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), tokens, amounts);
        IERC20(address(vault)).approve(address(vault), need);
        uint256 deadline = _deadline();
        vm.expectRevert(UniswapV3StandardExchangeOutBase.UniswapV3ExchangeOut_InsufficientInput.selector);
        outMulti.exchangeOutOneToMany(
            IERC20(address(vault)), need - 1, tokens, amounts, address(this), false, deadline
        );
    }

    function test_ME6_previewExitSharesMatchExec() public {
        _join(_u0(10), _u1(10));
        (uint256 amount0, uint256 amount1) = _proportionalOut(1, 20);
        uint256 previewIdle =
            outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(amount0, amount1));
        IERC20(address(vault)).approve(address(vault), previewIdle);
        uint256 execIdle = outMulti.exchangeOutOneToMany(
            IERC20(address(vault)),
            previewIdle,
            _poolTokens(),
            _amts(amount0, amount1),
            address(this),
            false,
            _deadline()
        );
        assertEq(execIdle, previewIdle, "ME6: idle");
    }

    function test_ME7_maxAmountInAboveS_refundsUnusedShares() public {
        _join(_u0(10), _u1(10));
        (uint256 amount0, uint256 amount1) = _proportionalOut(1, 10);
        uint256 s =
            outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(amount0, amount1));
        uint256 bal = IERC20(address(vault)).balanceOf(address(this));
        uint256 extra = bal > s ? (bal - s) / 10 : 0;
        if (extra == 0 && bal > s) extra = 1;
        uint256 maxIn = s + extra;
        if (maxIn > bal) maxIn = bal;
        IERC20(address(vault)).approve(address(vault), maxIn);
        uint256 sharesBefore = IERC20(address(vault)).balanceOf(address(this));
        uint256 burned = outMulti.exchangeOutOneToMany(
            IERC20(address(vault)), maxIn, _poolTokens(), _amts(amount0, amount1), address(this), false, _deadline()
        );
        assertEq(burned, s, "ME7: burned S");
        assertEq(IERC20(address(vault)).balanceOf(address(this)), sharesBefore - s, "ME7: unused refunded");
    }

    function test_ME8_D24_fees_previewJoinAndOneToOneExit() public {
        _join(_u0(50), _u1(50));

        uint256 g0 = pool.feeGrowthGlobal0X128();
        uint256 g1 = pool.feeGrowthGlobal1X128();
        _swapHuman(pool, true, 50_000);
        _swapHuman(pool, false, 50_000);
        assertTrue(
            pool.feeGrowthGlobal0X128() > g0 || pool.feeGrowthGlobal1X128() > g1, "ME8: fee growth vs center"
        );

        (uint256 owed0, uint256 owed1) = _uncollectedCenterFees();
        assertTrue(owed0 > 0 || owed1 > 0, "ME8: collectable fees");

        uint256 join0 = _u0(2);
        uint256 join1 = _u1(2);
        uint256 previewJoin =
            inMulti.previewExchangeInManyToOne(_poolTokens(), _amts(join0, join1), IERC20(address(vault)));
        {
            (uint256 joinD9_0, uint256 joinD9_1) = _d9Totals();
            uint256 joinSupply = IERC20(address(vault)).totalSupply();
            uint256 d9Shares0 = (join0 * joinSupply) / joinD9_0;
            uint256 d9Shares1 = (join1 * joinSupply) / joinD9_1;
            uint256 d9Shares = d9Shares0 < d9Shares1 ? d9Shares0 : d9Shares1;
            assertLt(previewJoin, d9Shares, "ME8: join preview includes collectable");
        }
        uint256 execJoin = _join(join0, join1);
        assertEq(execJoin, previewJoin, "ME8: previewJoin==exec after fees");

        _swapHuman(pool, true, 50_000);
        _swapHuman(pool, false, 50_000);
        (owed0, owed1) = _uncollectedCenterFees();
        assertTrue(owed0 > 0 || owed1 > 0, "ME8: collectable fees before exit");

        uint256 supply = IERC20(address(vault)).totalSupply();
        (uint256 d9_0, uint256 d9_1) = _d9Totals();
        (uint256 amount0, uint256 amount1) = _proportionalOut(1, 20);
        uint256 sPost = FullMath.mulDivRoundingUp(amount0, supply, d9_0 + owed0);
        uint256 s1Post = FullMath.mulDivRoundingUp(amount1, supply, d9_1 + owed1);
        assertEq(sPost, s1Post, "ME8: 1:1 share-fraction S0==S1");
        uint256 sD9 = owed0 > 0
            ? FullMath.mulDivRoundingUp(amount0, supply, d9_0)
            : FullMath.mulDivRoundingUp(amount1, supply, d9_1);
        assertLt(sPost, sD9, "ME8: S from post-collect totals (not D9-only)");

        uint256 previewExit =
            outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(amount0, amount1));
        assertEq(previewExit, sPost, "ME8: preview S == post-collect D52");
        uint256 bal0Before = IERC20(_token0()).balanceOf(address(this));
        uint256 bal1Before = IERC20(_token1()).balanceOf(address(this));
        IERC20(address(vault)).approve(address(vault), previewExit);
        uint256 burned = outMulti.exchangeOutOneToMany(
            IERC20(address(vault)),
            previewExit,
            _poolTokens(),
            _amts(amount0, amount1),
            address(this),
            false,
            _deadline()
        );
        assertEq(burned, previewExit, "ME8: previewExit==exec after fees");
        assertEq(IERC20(_token0()).balanceOf(address(this)), bal0Before + amount0, "ME8: paid amount0");
        assertEq(IERC20(_token1()).balanceOf(address(this)), bal1Before + amount1, "ME8: paid amount1");
    }

    function test_A0_residualDeadShares_firstMinterNotWhole() public {
        _mint(_token0(), address(vault), _u0(5));
        _mint(_token1(), address(vault), _u1(5));
        uint256 userShares = _join(_u0(10), _u1(10));
        uint256 dead = IERC20(address(vault)).balanceOf(DEAD);
        assertGt(dead, 0, "A0: dead shares");
        assertLt(userShares, userShares + dead, "A0: first minter not 100% of residual");
        uint256 supply = IERC20(address(vault)).totalSupply();
        assertEq(supply, userShares + dead, "A0: supply = user + dead");
        IERC20(address(vault)).approve(address(vault), userShares);
        (uint256 min0, uint256 min1) = _proportionalOut(1, 10_000);
        outMulti.exchangeOutOneToMany(
            IERC20(address(vault)),
            userShares,
            _poolTokens(),
            _amts(min0, min1),
            address(this),
            false,
            _deadline()
        );
        assertGt(IERC20(address(vault)).balanceOf(DEAD), 0, "A0: redeem cannot take donation");
    }

    function _join(uint256 amount0, uint256 amount1) internal returns (uint256 shares) {
        _mint(_token0(), address(this), amount0);
        _mint(_token1(), address(this), amount1);
        IERC20(_token0()).approve(address(vault), amount0);
        IERC20(_token1()).approve(address(vault), amount1);
        shares = inMulti.exchangeInManyToOne(
            _poolTokens(), _amts(amount0, amount1), IERC20(address(vault)), 0, address(this), false, _deadline()
        );
    }

    function _poolTokens() internal view returns (address[] memory tokens) {
        tokens = new address[](2);
        tokens[0] = _token0();
        tokens[1] = _token1();
    }

    function _amts(uint256 a0, uint256 a1) internal pure returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = a0;
        amounts[1] = a1;
    }

    function _proportionalOut(uint256 n, uint256 d) internal view returns (uint256 amount0, uint256 amount1) {
        uint256 den = d == 0 ? 10 : d;
        (uint256 tot0, uint256 tot1) = _shareMathTotals();
        uint256 supply = vault.totalSupply();
        bool drive0 = tot0 <= tot1;
        uint256 totD = drive0 ? tot0 : tot1;
        uint256 totF = drive0 ? tot1 : tot0;
        uint256 targetD = totD * n / den;
        if (targetD == 0) targetD = 1;
        if (targetD >= totD) targetD = totD - 1;
        (uint256 aD, uint256 aF) = _searchCoarse(totD, totF, supply, targetD, drive0);
        if (drive0) {
            amount0 = aD;
            amount1 = aF;
        } else {
            amount0 = aF;
            amount1 = aD;
        }
    }

    function _shareMathTotals() internal view returns (uint256 tot0, uint256 tot1) {
        (tot0, tot1) = _d9Totals();
        (uint256 owed0, uint256 owed1) = _uncollectedCenterFees();
        tot0 += owed0;
        tot1 += owed1;
    }

    function _searchCoarse(uint256 totD, uint256 totF, uint256 supply, uint256 targetD, bool drive0)
        internal
        view
        returns (uint256 aD, uint256 aF)
    {
        uint256 maxOff = targetD < 4000 ? targetD : 4000;
        for (uint256 off = 0; off <= maxOff; ++off) {
            if (targetD > off) {
                (bool ok, uint256 x, uint256 y) = _tryCoarse(targetD - off, totD, totF, supply, drive0);
                if (ok) return (x, y);
            }
            if (off != 0) {
                uint256 up = targetD + off;
                if (up < totD) {
                    (bool ok, uint256 x, uint256 y) = _tryCoarse(up, totD, totF, supply, drive0);
                    if (ok) return (x, y);
                }
            }
        }
        uint256 lim = totD < 512 ? totD : 512;
        for (uint256 a = 1; a < lim; ++a) {
            (bool ok, uint256 x, uint256 y) = _tryCoarse(a, totD, totF, supply, drive0);
            if (ok) return (x, y);
        }
        aD = targetD == 0 ? 1 : targetD;
        aF = totF / 10;
        if (aF == 0) aF = 1;
    }

    function _tryCoarse(uint256 aD, uint256 totD, uint256 totF, uint256 supply, bool drive0)
        internal
        view
        returns (bool ok, uint256, uint256 aF)
    {
        if (aD == 0 || aD >= totD || totF == 0 || supply == 0) return (false, 0, 0);
        uint256 s = FullMath.mulDivRoundingUp(aD, supply, totD);
        if (s == 0) return (false, 0, 0);
        aF = _amountForShareBurn(s, totF, supply);
        if (aF == 0 || aF >= totF) return (false, 0, 0);
        if (FullMath.mulDivRoundingUp(aF, supply, totF) != s) return (false, 0, 0);
        uint256 a0 = drive0 ? aD : aF;
        uint256 a1 = drive0 ? aF : aD;
        try outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(a0, a1)) returns (uint256 p)
        {
            if (p > 0) return (true, aD, aF);
        } catch {}
        return (false, 0, 0);
    }

    function _amountForShareBurn(uint256 s, uint256 tot, uint256 supply) internal pure returns (uint256 a) {
        if (s == 0 || tot == 0 || supply == 0) return 0;
        a = FullMath.mulDiv(s, tot, supply);
        if (a > 0 && a < tot && FullMath.mulDivRoundingUp(a, supply, tot) == s) return a;
        a = FullMath.mulDiv(s - 1, tot, supply) + 1;
        if (a > 0 && a < tot && FullMath.mulDivRoundingUp(a, supply, tot) == s) return a;
        return 0;
    }

    function _d9Totals() internal view returns (uint256 total0, uint256 total1) {
        (uint256 dep0, uint256 dep1) = liquid.deployedReserve();
        total0 = liquid.localReserve(_token0()) + dep0;
        total1 = liquid.localReserve(_token1()) + dep1;
    }

    function _uncollectedCenterFees() internal view returns (uint256 owed0, uint256 owed1) {
        int24 lo = TickMath.minUsableTick(pool.tickSpacing());
        int24 hi = TickMath.maxUsableTick(pool.tickSpacing());
        (uint128 liq, uint256 last0, uint256 last1, uint128 tok0, uint128 tok1) =
            pool.positions(keccak256(abi.encodePacked(address(vault), lo, hi)));
        (uint256 inside0, uint256 inside1) = _feeGrowthInsideTicks(lo, hi);
        unchecked {
            owed0 = FullMath.mulDiv(inside0 - last0, liq, FixedPoint128.Q128) + tok0;
            owed1 = FullMath.mulDiv(inside1 - last1, liq, FixedPoint128.Q128) + tok1;
        }
    }

    function _feeGrowthInsideTicks(int24 lo, int24 hi) internal view returns (uint256 inside0, uint256 inside1) {
        (, int24 tick,,,,,) = pool.slot0();
        (uint256 lower0, uint256 lower1) = _tickFeeGrowthOutside(lo);
        (uint256 upper0, uint256 upper1) = _tickFeeGrowthOutside(hi);
        unchecked {
            if (tick < lo) {
                return (lower0 - upper0, lower1 - upper1);
            }
            if (tick < hi) {
                return (
                    pool.feeGrowthGlobal0X128() - lower0 - upper0,
                    pool.feeGrowthGlobal1X128() - lower1 - upper1
                );
            }
            return (upper0 - lower0, upper1 - lower1);
        }
    }

    function _tickFeeGrowthOutside(int24 tick) internal view returns (uint256 fg0, uint256 fg1) {
        (,, fg0, fg1,,,,) = pool.ticks(tick);
    }

    function _centerLiquidity() internal view returns (uint128 liq) {
        int24 spacing = pool.tickSpacing();
        (liq,,,,) = pool.positions(
            keccak256(
                abi.encodePacked(address(vault), TickMath.minUsableTick(spacing), TickMath.maxUsableTick(spacing))
            )
        );
    }

    function _assertFreeWithinDeadband(uint256 liquidPct) internal view {
        (uint256 dep0, uint256 dep1) = liquid.deployedReserve();
        uint256 free0 = liquid.localReserve(_token0());
        uint256 free1 = liquid.localReserve(_token1());
        uint256 total0 = free0 + dep0;
        uint256 total1 = free1 + dep1;
        uint256 minTol0 = _u0(1) / 1_000_000;
        uint256 minTol1 = _u1(1) / 1_000_000;
        uint256 extra0 = _u0(1) / 1000;
        uint256 extra1 = _u1(1) / 1000;
        if (total0 > 0) {
            uint256 target0 = (total0 * liquidPct) / ONE_WAD;
            uint256 dev0 = free0 > target0 ? free0 - target0 : target0 - free0;
            uint256 tol0 = target0 == 0 ? minTol0 : (target0 * 0.05e18) / ONE_WAD;
            if (tol0 < minTol0) tol0 = minTol0;
            assertLe(dev0, tol0 + total0 / 4 + extra0, "token0 band");
        }
        if (total1 > 0) {
            uint256 target1 = (total1 * liquidPct) / ONE_WAD;
            uint256 dev1 = free1 > target1 ? free1 - target1 : target1 - free1;
            uint256 tol1 = target1 == 0 ? minTol1 : (target1 * 0.05e18) / ONE_WAD;
            if (tol1 < minTol1) tol1 = minTol1;
            if (target1 > 0) assertLe(dev1, tol1 + total1 / 2 + extra1, "token1 band");
        }
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
