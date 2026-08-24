// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {FixedPoint128} from "@crane/contracts/protocols/dexes/uniswap/libraries/FixedPoint128.sol";

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
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
    UniswapV3StandardExchangeOutBase
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeOutBase.sol";
import {
    UniswapV3BoundPoolLockSeCaller
} from "test/foundry/spec/protocol/dexes/uniswap/v3/harness/UniswapV3BoundPoolLockSeCaller.sol";

contract UniswapV3StandardExchange_MultiJoinExit_Test is TestBase_UniswapV3StandardExchange {
    address internal constant DEAD = address(0x000000000000000000000000000000000000dEaD);

    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IUniswapV3Pool internal pool;
    IStandardExchangeProxy internal vault;
    IUniswapV3StandardExchangeLiquidReserve internal liquid;
    IStandardExchangeInMulti internal inMulti;
    IStandardExchangeOutMulti internal outMulti;
    UniswapV3BoundPoolLockSeCaller internal lockCaller;
    address internal attacker;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
        pool = _createPoolOneToOne(address(tokenA), address(tokenB), FEE_MEDIUM);
        _seedExternalLiquidity(pool, 50_000_000e18);
        vault = _deployVault(pool, DEFAULT_WIDTH_MULTIPLIER);
        liquid = IUniswapV3StandardExchangeLiquidReserve(address(vault));
        inMulti = IStandardExchangeInMulti(address(vault));
        outMulti = IStandardExchangeOutMulti(address(vault));
        lockCaller = new UniswapV3BoundPoolLockSeCaller(pool);
        ERC20PermitMintableStub(pool.token0()).mint(address(lockCaller), 100 ether);
        ERC20PermitMintableStub(pool.token1()).mint(address(lockCaller), 100 ether);
    }

    function test_MJ1_lengthNotTwo_reverts() public {
        address[] memory one = new address[](1);
        one[0] = _token0();
        uint256[] memory oneAmt = new uint256[](1);
        oneAmt[0] = 1 ether;
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        inMulti.exchangeInManyToOne(one, oneAmt, IERC20(address(vault)), 0, address(this), false, _deadline());
    }

    function test_MJ2_idleProportionalJoin_fullRangeL_andSleeve() public {
        uint256 shares = _join(10 ether, 10 ether);
        assertGt(shares, 0, "MJ2: shares");
        assertGt(_centerLiquidity(), 0, "MJ2: center L");
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_MJ3_unbalancedJoin_paysBoth_noSwap() public {
        uint256 a0 = 10 ether;
        uint256 a1 = 1 ether;
        ERC20PermitMintableStub(_token0()).mint(address(this), a0);
        ERC20PermitMintableStub(_token1()).mint(address(this), a1);
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
        uint256 a0 = 5 ether;
        uint256 a1 = 5 ether;
        ERC20PermitMintableStub(_token0()).mint(address(lockCaller), a0);
        ERC20PermitMintableStub(_token1()).mint(address(lockCaller), a1);
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
        _join(4 ether, 4 ether);
        uint256 claimed0 = 2 ether;
        uint256 claimed1 = 2 ether;
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
            inMulti.previewExchangeInManyToOne(_poolTokens(), _amts(3 ether, 3 ether), IERC20(address(vault)));
        uint256 execIdle = _join(3 ether, 3 ether);
        assertEq(execIdle, previewIdle, "MJ7: idle preview");

        uint256 previewBlocked =
            inMulti.previewExchangeInManyToOne(_poolTokens(), _amts(2 ether, 2 ether), IERC20(address(vault)));
        ERC20PermitMintableStub(_token0()).mint(address(lockCaller), 2 ether);
        ERC20PermitMintableStub(_token1()).mint(address(lockCaller), 2 ether);
        vm.startPrank(address(lockCaller));
        IERC20(_token0()).approve(address(vault), 2 ether);
        IERC20(_token1()).approve(address(vault), 2 ether);
        vm.stopPrank();
        uint256 execBlocked = lockCaller.runExchangeInManyToOne(
            address(vault), _poolTokens(), _amts(2 ether, 2 ether), IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertEq(execBlocked, previewBlocked, "MJ7: blocked preview");
    }

    function test_MJ8_descendingTokenIn_reverts() public {
        address[] memory desc = new address[](2);
        desc[0] = _token1();
        desc[1] = _token0();
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        inMulti.exchangeInManyToOne(desc, _amts(1 ether, 1 ether), IERC20(address(vault)), 0, address(this), false, _deadline());
    }

    function test_ME1_lengthNotTwo_reverts() public {
        _join(10 ether, 10 ether);
        address[] memory one = new address[](1);
        one[0] = _token0();
        uint256[] memory oneAmt = new uint256[](1);
        oneAmt[0] = 1e15;
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        outMulti.exchangeOutOneToMany(
            IERC20(address(vault)), type(uint256).max, one, oneAmt, address(this), false, _deadline()
        );
    }

    function test_ME2_idleProportionalExit_paysBoth() public {
        _join(10 ether, 10 ether);
        uint256 amount0 = 1 ether;
        uint256 amount1 = 1 ether;
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
        _join(10 ether, 10 ether);
        uint256 bal0 = IERC20(_token0()).balanceOf(address(this));
        uint256 bal1 = IERC20(_token1()).balanceOf(address(this));
        uint256 supply = IERC20(address(vault)).totalSupply();
        IERC20(address(vault)).approve(address(vault), type(uint256).max);
        address[] memory tokens = _poolTokens();
        uint256[] memory amounts = _amts(1 ether, 2 ether);
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
        _join(20 ether, 20 ether);
        uint256 amount0 = 1 ether;
        uint256 amount1 = 1 ether;
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

        // Half of a 20+20 join exceeds the 20% sleeve; S0==S1 because the book is proportional.
        uint256 short0 = 10 ether;
        uint256 short1 = 10 ether;
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
        _join(10 ether, 10 ether);
        address[] memory tokens = _poolTokens();
        uint256[] memory amounts = _amts(1 ether, 1 ether);
        uint256 need = outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), tokens, amounts);
        IERC20(address(vault)).approve(address(vault), need);
        uint256 deadline = _deadline();
        vm.expectRevert(UniswapV3StandardExchangeOutBase.UniswapV3ExchangeOut_InsufficientInput.selector);
        outMulti.exchangeOutOneToMany(
            IERC20(address(vault)), need - 1, tokens, amounts, address(this), false, deadline
        );
    }

    function test_ME6_previewExitSharesMatchExec() public {
        _join(10 ether, 10 ether);
        uint256 previewIdle =
            outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(5e17, 5e17));
        IERC20(address(vault)).approve(address(vault), previewIdle);
        uint256 execIdle = outMulti.exchangeOutOneToMany(
            IERC20(address(vault)), previewIdle, _poolTokens(), _amts(5e17, 5e17), address(this), false, _deadline()
        );
        assertEq(execIdle, previewIdle, "ME6: idle");
    }

    function test_ME7_maxAmountInAboveS_refundsUnusedShares() public {
        _join(10 ether, 10 ether);
        uint256 s = outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(1 ether, 1 ether));
        uint256 extra = 1 ether;
        uint256 maxIn = s + extra;
        IERC20(address(vault)).approve(address(vault), maxIn);
        uint256 sharesBefore = IERC20(address(vault)).balanceOf(address(this));
        uint256 burned = outMulti.exchangeOutOneToMany(
            IERC20(address(vault)), maxIn, _poolTokens(), _amts(1 ether, 1 ether), address(this), false, _deadline()
        );
        assertEq(burned, s, "ME7: burned S");
        assertEq(IERC20(address(vault)).balanceOf(address(this)), sharesBefore - s, "ME7: unused refunded");
    }

    /// @notice After dual join + external swaps vs the vault center: unpoked fees must enter
    ///         idle join preview (D24) and idle dual-exit S (collect then D52 from post-collect totals).
    function test_ME8_D24_fees_previewJoinAndOneToOneExit() public {
        _join(50 ether, 50 ether);

        uint256 g0 = pool.feeGrowthGlobal0X128();
        uint256 g1 = pool.feeGrowthGlobal1X128();
        _externalSwapExactIn(pool, true, 50_000 ether);
        _externalSwapExactIn(pool, false, 50_000 ether);
        assertTrue(
            pool.feeGrowthGlobal0X128() > g0 || pool.feeGrowthGlobal1X128() > g1, "ME8: fee growth vs center"
        );

        (uint256 owed0, uint256 owed1) = _uncollectedCenterFees();
        assertTrue(owed0 > 0 || owed1 > 0, "ME8: collectable fees");

        uint256 join0 = 2 ether;
        uint256 join1 = 2 ether;
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

        _externalSwapExactIn(pool, true, 50_000 ether);
        _externalSwapExactIn(pool, false, 50_000 ether);
        (owed0, owed1) = _uncollectedCenterFees();
        assertTrue(owed0 > 0 || owed1 > 0, "ME8: collectable fees before exit");

        uint256 supply = IERC20(address(vault)).totalSupply();
        (uint256 d9_0, uint256 d9_1) = _d9Totals();
        uint256 share0 = d9_0 + owed0;
        uint256 share1 = d9_1 + owed1;
        uint256 amount0 = share0 / 20;
        uint256 amount1 = share1 / 20;
        uint256 sPost = FullMath.mulDivRoundingUp(amount0, supply, share0);
        uint256 s1Post = FullMath.mulDivRoundingUp(amount1, supply, share1);
        assertEq(sPost, s1Post, "ME8: 1:1 share-fraction S0==S1");
        uint256 sD9 = FullMath.mulDivRoundingUp(amount0, supply, d9_0);
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
        ERC20PermitMintableStub(_token0()).mint(address(vault), 5 ether);
        ERC20PermitMintableStub(_token1()).mint(address(vault), 5 ether);
        uint256 userShares = _join(10 ether, 10 ether);
        uint256 dead = IERC20(address(vault)).balanceOf(DEAD);
        assertGt(dead, 0, "A0: dead shares");
        assertLt(userShares, userShares + dead, "A0: first minter not 100% of residual");
        uint256 supply = IERC20(address(vault)).totalSupply();
        assertEq(supply, userShares + dead, "A0: supply = user + dead");
        IERC20(address(vault)).approve(address(vault), userShares);
        outMulti.exchangeOutOneToMany(
            IERC20(address(vault)),
            userShares,
            _poolTokens(),
            _amts(1e15, 1e15),
            address(this),
            false,
            _deadline()
        );
        assertGt(IERC20(address(vault)).balanceOf(DEAD), 0, "A0: redeem cannot take donation");
    }

    function _join(uint256 amount0, uint256 amount1) internal returns (uint256 shares) {
        ERC20PermitMintableStub(_token0()).mint(address(this), amount0);
        ERC20PermitMintableStub(_token1()).mint(address(this), amount1);
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
        if (total0 > 0) {
            uint256 target0 = (total0 * liquidPct) / ONE_WAD;
            uint256 dev0 = free0 > target0 ? free0 - target0 : target0 - free0;
            uint256 tol0 = target0 == 0 ? 1e12 : (target0 * 0.05e18) / ONE_WAD;
            if (tol0 < 1e12) tol0 = 1e12;
            assertLe(dev0, tol0 + total0 / 4 + 1e15, "token0 band");
        }
        if (total1 > 0) {
            uint256 target1 = (total1 * liquidPct) / ONE_WAD;
            uint256 dev1 = free1 > target1 ? free1 - target1 : target1 - free1;
            uint256 tol1 = target1 == 0 ? 1e12 : (target1 * 0.05e18) / ONE_WAD;
            if (tol1 < 1e12) tol1 = 1e12;
            if (target1 > 0) assertLe(dev1, tol1 + total1 / 2 + 1e15, "token1 band");
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
