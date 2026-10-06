// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IUniswapV4StandardExchangeLiquidReserve} from
    "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";
import {UniswapV4StandardExchangeCommon} from
    "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol";
import {UniswapV4StandardExchangeOutBase} from
    "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutBase.sol";
import {PoolManagerUnlockSeCaller} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/harness/PoolManagerUnlockSeCaller.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {UniswapV4SeDecimalsHelpers} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4SeDecimalsHelpers.sol";
import {UniswapV4LiquiditySeeder_ProDexUniV4} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/harness/UniswapV4SeDecimalsPoolOps.sol";

/**
 * @title UniswapV4StandardExchange_MultiJoinExit_Decimals
 * @notice MJ1–MJ8 and ME1–ME7 on combo decimals. pairToken = tokenA. vaultShare stays 18.
 */
abstract contract UniswapV4StandardExchange_MultiJoinExit_Decimals is UniswapV4SeDecimalsHelpers {
    using PoolIdLibrary for PoolKey;
    uint8 internal constant _DECIMALS_REMATCH = 5;

    MintableERC20Decimals internal tokenA;
    MintableERC20Decimals internal tokenB;
    IStandardExchangeProxy internal vault;
    IUniswapV4StandardExchangeLiquidReserve internal liquid;
    IStandardExchangeInMulti internal inMulti;
    IStandardExchangeOutMulti internal outMulti;
    PoolKey internal poolKey;
    UniswapV4LiquiditySeeder_ProDexUniV4 internal seeder;
    PoolManagerUnlockSeCaller internal unlockCaller;
    address internal attacker;

    function _u0(uint256 human) internal view returns (uint256) {
        return _uOf(_token0(), human);
    }

    function _u1(uint256 human) internal view returns (uint256) {
        return _uOf(_token1(), human);
    }

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
        tokenA = new MintableERC20Decimals("Token A", "TKNA", _tokenADecimals());
        tokenB = new MintableERC20Decimals("Token B", "TKNB", _tokenBDecimals());
        poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        uint160 sqrtP = _oneToOneHumanSqrtPrice(_token0(), _token1());
        poolManager.initialize(poolKey, sqrtP);

        seeder = new UniswapV4LiquiditySeeder_ProDexUniV4(poolManager);
        unlockCaller = new PoolManagerUnlockSeCaller(poolManager);
        tokenA.mint(address(seeder), _uA(1_000_000));
        tokenB.mint(address(seeder), _uB(1_000_000));
        (int24 tickLower, int24 tickUpper) = _seedTicksAround(sqrtP, poolKey.tickSpacing);
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
            sqrtP,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            _u0(100_000),
            _u1(100_000)
        );
        seeder.addLiquidity(poolKey, tickLower, tickUpper, liq);

        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
        liquid = IUniswapV4StandardExchangeLiquidReserve(address(vault));
        inMulti = IStandardExchangeInMulti(address(vault));
        outMulti = IStandardExchangeOutMulti(address(vault));
    }

    function test_MJ1_lengthNotTwo_reverts_singleZapInStillWorks() public {
        _join(_u0(4), _u1(4));
        address[] memory one = new address[](1);
        one[0] = _token0();
        uint256[] memory oneAmt = new uint256[](1);
        oneAmt[0] = _u0(1);
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        inMulti.exchangeInManyToOne(one, oneAmt, IERC20(address(vault)), 0, address(this), false, _deadline());

        uint256 amountIn = _u0(2);
        MintableERC20Decimals(_token0()).mint(address(this), amountIn);
        IERC20(_token0()).approve(address(vault), amountIn);
        uint256 shares = vault.exchangeIn(
            IERC20(_token0()), amountIn, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertGt(shares, 0, "MJ1: single zap-in");
    }

    function test_MJ2_idleProportionalJoin_fullRangeL_andSleeve() public {
        uint256 shares = _join(_u0(10), _u1(10));
        assertGt(shares, 0, "MJ2: shares");
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        (uint128 centerL,,) =
            StateLibrary.getPositionInfo(poolManager, poolKey.toId(), address(vault), minTick, maxTick, bytes32(0));
        assertGt(centerL, 0, "MJ2: center L");
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_MJ3_unbalancedJoin_paysBoth_surplusStaysSleeve() public {
        uint256 a0 = _u0(10);
        uint256 a1 = _u1(1);
        uint256 user0Before = IERC20(_token0()).balanceOf(address(this));
        uint256 user1Before = IERC20(_token1()).balanceOf(address(this));
        MintableERC20Decimals(_token0()).mint(address(this), a0);
        MintableERC20Decimals(_token1()).mint(address(this), a1);
        uint256 preview = inMulti.previewExchangeInManyToOne(_poolTokens(), _amts(a0, a1), IERC20(address(vault)));
        IERC20(_token0()).approve(address(vault), a0);
        IERC20(_token1()).approve(address(vault), a1);
        uint256 shares =
            inMulti.exchangeInManyToOne(_poolTokens(), _amts(a0, a1), IERC20(address(vault)), 0, address(this), false, _deadline());
        assertEq(shares, preview, "MJ3: preview==exec");
        assertEq(IERC20(_token0()).balanceOf(address(this)), user0Before, "MJ3: paid amount0");
        assertEq(IERC20(_token1()).balanceOf(address(this)), user1Before, "MJ3: paid amount1");
        assertGt(liquid.localReserve(_token0()), 0, "MJ3: surplus/sleeve token0");
    }

    function test_MJ4_blockedJoin_mints_noNestedUnlock_laterRebalance() public {
        uint256 a0 = _u0(5);
        uint256 a1 = _u1(5);
        MintableERC20Decimals(_token0()).mint(address(unlockCaller), a0);
        MintableERC20Decimals(_token1()).mint(address(unlockCaller), a1);
        vm.startPrank(address(unlockCaller));
        IERC20(_token0()).approve(address(vault), a0);
        IERC20(_token1()).approve(address(vault), a1);
        vm.stopPrank();
        uint256 shares = unlockCaller.runExchangeInManyToOne(
            address(vault), _poolTokens(), _amts(a0, a1), IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertGt(shares, 0, "MJ4: blocked mint");
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        (uint128 lBefore,,) =
            StateLibrary.getPositionInfo(poolManager, poolKey.toId(), address(vault), minTick, maxTick, bytes32(0));
        assertEq(lBefore, 0, "MJ4: no L while blocked");
        liquid.rebalanceLiquidReserve();
        (uint128 lAfter,,) =
            StateLibrary.getPositionInfo(poolManager, poolKey.toId(), address(vault), minTick, maxTick, bytes32(0));
        assertGt(lAfter, 0, "MJ4: idle rebalance deploys");
    }

    function test_MJ5_pretransferredTrue_noDelivery_noFreeMint() public {
        _join(_u0(4), _u1(4));
        uint256 claimed0 = _u0(2);
        uint256 claimed1 = _u1(2);
        uint256 supplyBefore = vault.totalSupply();
        uint256 attackerSharesBefore = vault.balanceOf(attacker);
        uint256 inv0 = IERC20(_token0()).balanceOf(address(vault));
        uint256 inv1 = IERC20(_token1()).balanceOf(address(vault));
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed0, uint256(0))
        );
        inMulti.exchangeInManyToOne(
            _poolTokens(), _amts(claimed0, claimed1), IERC20(address(vault)), 0, attacker, true, _deadline()
        );
        assertEq(vault.totalSupply(), supplyBefore, "MJ5: no free mint");
        assertEq(vault.balanceOf(attacker), attackerSharesBefore, "MJ5: attacker shares");
        assertEq(IERC20(_token0()).balanceOf(address(vault)), inv0, "MJ5: inv0");
        assertEq(IERC20(_token1()).balanceOf(address(vault)), inv1, "MJ5: inv1");
    }

    function test_MJ6_unsortedDuplicateNonPoolOrWrongOut_reverts() public {
        uint256[] memory amts = _amts(_u0(1), _u1(1));
        address[] memory desc = new address[](2);
        desc[0] = _token1();
        desc[1] = _token0();
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        inMulti.exchangeInManyToOne(desc, amts, IERC20(address(vault)), 0, address(this), false, _deadline());

        address[] memory dup = new address[](2);
        dup[0] = _token0();
        dup[1] = _token0();
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        inMulti.exchangeInManyToOne(dup, amts, IERC20(address(vault)), 0, address(this), false, _deadline());

        address[] memory other = new address[](2);
        other[0] = address(tokenA);
        other[1] = address(0xBEEF);
        if (other[0] > other[1]) {
            (other[0], other[1]) = (other[1], other[0]);
        }
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        inMulti.exchangeInManyToOne(other, amts, IERC20(address(vault)), 0, address(this), false, _deadline());

        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        inMulti.exchangeInManyToOne(_poolTokens(), amts, IERC20(_token0()), 0, address(this), false, _deadline());
    }

    function test_MJ7_previewJoinSharesMatchExec_idleAndBlocked() public {
        uint256 previewIdle =
            inMulti.previewExchangeInManyToOne(_poolTokens(), _amts(_u0(3), _u1(3)), IERC20(address(vault)));
        uint256 execIdle = _join(_u0(3), _u1(3));
        assertEq(execIdle, previewIdle, "MJ7: idle preview");

        uint256 previewBlocked =
            inMulti.previewExchangeInManyToOne(_poolTokens(), _amts(_u0(2), _u1(2)), IERC20(address(vault)));
        MintableERC20Decimals(_token0()).mint(address(unlockCaller), _u0(2));
        MintableERC20Decimals(_token1()).mint(address(unlockCaller), _u1(2));
        vm.startPrank(address(unlockCaller));
        IERC20(_token0()).approve(address(vault), _u0(2));
        IERC20(_token1()).approve(address(vault), _u1(2));
        vm.stopPrank();
        uint256 execBlocked = unlockCaller.runExchangeInManyToOne(
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
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        inMulti.exchangeInManyToOne(desc, _amts(1, 1), IERC20(address(vault)), 0, address(this), false, _deadline());
    }

    function test_ME1_lengthNotTwo_reverts_singleZapOutStillWorks() public {
        _join(_u0(10), _u1(10));
        address[] memory one = new address[](1);
        one[0] = _token0();
        uint256[] memory oneAmt = new uint256[](1);
        oneAmt[0] = _milliOf(_token0());
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        outMulti.exchangeOutOneToMany(
            IERC20(address(vault)), type(uint256).max, one, oneAmt, address(this), false, _deadline()
        );

        uint256 want = _milliOf(_token0());
        uint256 preview = vault.previewExchangeOut(IERC20(address(vault)), IERC20(_token0()), want);
        vault.approve(address(vault), preview);
        uint256 burned = vault.exchangeOut(
            IERC20(address(vault)), preview, IERC20(_token0()), want, address(this), false, _deadline()
        );
        assertGt(burned, 0, "ME1: single out");
    }

    function test_ME2_idleProportionalExit_paysBoth_ticksUnchanged() public {
        _join(_u0(10), _u1(10));
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        (uint128 lBefore,,) =
            StateLibrary.getPositionInfo(poolManager, poolKey.toId(), address(vault), minTick, maxTick, bytes32(0));
        (uint256 amount0, uint256 amount1) = _proportionalOut(1, 10);
        uint256 preview =
            outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(amount0, amount1));
        uint256 bal0Before = IERC20(_token0()).balanceOf(address(this));
        uint256 bal1Before = IERC20(_token1()).balanceOf(address(this));
        vault.approve(address(vault), preview);
        uint256 burned = outMulti.exchangeOutOneToMany(
            IERC20(address(vault)), preview, _poolTokens(), _amts(amount0, amount1), address(this), false, _deadline()
        );
        assertEq(burned, preview, "ME2: preview==exec");
        assertEq(IERC20(_token0()).balanceOf(address(this)), bal0Before + amount0, "ME2: amount0");
        assertEq(IERC20(_token1()).balanceOf(address(this)), bal1Before + amount1, "ME2: amount1");
        (uint128 lAfter,,) =
            StateLibrary.getPositionInfo(poolManager, poolKey.toId(), address(vault), minTick, maxTick, bytes32(0));
        assertGt(lAfter, 0, "ME2: still in range");
        assertTrue(lAfter <= lBefore, "ME2: L not increased");
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_ME3_unbalancedExit_reverts_noSendNoSwap() public {
        _join(_u0(10), _u1(10));
        uint256 bal0 = IERC20(_token0()).balanceOf(address(this));
        uint256 bal1 = IERC20(_token1()).balanceOf(address(this));
        uint256 supply = vault.totalSupply();
        vault.approve(address(vault), type(uint256).max);
        (uint256 p0, uint256 p1) = _proportionalOut(1, 10);
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        outMulti.exchangeOutOneToMany(
            IERC20(address(vault)),
            type(uint256).max,
            _poolTokens(),
            _amts(p0, p1 * 2 + 1),
            address(this),
            false,
            _deadline()
        );
        assertEq(IERC20(_token0()).balanceOf(address(this)), bal0, "ME3: no token0");
        assertEq(IERC20(_token1()).balanceOf(address(this)), bal1, "ME3: no token1");
        assertEq(vault.totalSupply(), supply, "ME3: no burn");
    }

    function test_ME4_blockedProportional_coverPays_shortRevertsWholeTx() public {
        _join(_u0(20), _u1(20));
        (uint256 amount0, uint256 amount1) = _proportionalOut(1, 20);
        uint256 preview =
            outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(amount0, amount1));
        vault.transfer(address(vault), preview);
        uint256 burned = unlockCaller.runExchangeOutOneToMany(
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

        (uint256 short0, uint256 short1) = _proportionalOut(1, 2);
        uint256 need = outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(short0, short1));
        vault.transfer(address(vault), need);
        vm.expectRevert();
        unlockCaller.runExchangeOutOneToMany(
            address(vault),
            IERC20(address(vault)),
            need,
            _poolTokens(),
            _amts(short0, short1),
            address(this),
            true,
            _deadline()
        );
    }

    function test_ME5_maxAmountInTooLow_noPartialSend() public {
        _join(_u0(10), _u1(10));
        (uint256 amount0, uint256 amount1) = _proportionalOut(1, 10);
        uint256 need =
            outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(amount0, amount1));
        uint256 bal0 = IERC20(_token0()).balanceOf(address(this));
        vault.approve(address(vault), need);
        vm.expectRevert(UniswapV4StandardExchangeOutBase.UniswapV4ExchangeOut_InsufficientInput.selector);
        outMulti.exchangeOutOneToMany(
            IERC20(address(vault)), need - 1, _poolTokens(), _amts(amount0, amount1), address(this), false, _deadline()
        );
        assertEq(IERC20(_token0()).balanceOf(address(this)), bal0, "ME5: no send");
    }

    function test_ME6_previewExitSharesMatchExec_idleAndBlocked() public {
        _join(_u0(10), _u1(10));
        (uint256 amount0, uint256 amount1) = _proportionalOut(1, 20);
        uint256 previewIdle =
            outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(amount0, amount1));
        vault.approve(address(vault), previewIdle);
        uint256 execIdle = outMulti.exchangeOutOneToMany(
            IERC20(address(vault)), previewIdle, _poolTokens(), _amts(amount0, amount1), address(this), false, _deadline()
        );
        assertEq(execIdle, previewIdle, "ME6: idle");

        (amount0, amount1) = _proportionalOut(1, 20);
        uint256 previewBlocked =
            outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(amount0, amount1));
        vault.transfer(address(vault), previewBlocked);
        uint256 execBlocked = unlockCaller.runExchangeOutOneToMany(
            address(vault),
            IERC20(address(vault)),
            previewBlocked,
            _poolTokens(),
            _amts(amount0, amount1),
            address(this),
            true,
            _deadline()
        );
        assertEq(execBlocked, previewBlocked, "ME6: blocked");
    }

    function test_ME7_maxAmountInAboveS_refundsUnusedShares() public {
        uint256 minted = _join(_u0(10), _u1(10));
        (uint256 amount0, uint256 amount1) = _proportionalOut(1, 10);
        uint256 s = outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(amount0, amount1));
        uint256 extra = minted / 10;
        if (extra == 0) extra = 1;
        uint256 maxIn = s + extra;
        vault.approve(address(vault), maxIn);
        uint256 sharesBefore = vault.balanceOf(address(this));
        uint256 burned = outMulti.exchangeOutOneToMany(
            IERC20(address(vault)), maxIn, _poolTokens(), _amts(amount0, amount1), address(this), false, _deadline()
        );
        assertEq(burned, s, "ME7: burned S");
        assertEq(vault.balanceOf(address(this)), sharesBefore - s, "ME7: unused refunded");
        assertGt(minted, 0, "ME7: had shares");
    }

    /// @dev Mixed books quantize 6-dec share burns. Drive search from the coarser tot, not from S.
    function _proportionalOut(uint256 n, uint256 d) internal view returns (uint256 amount0, uint256 amount1) {
        uint256 den = d == 0 ? 10 : d;
        (uint256 tot0, uint256 tot1) = _sotTotals();
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

    function _sotTotals() internal view returns (uint256 tot0, uint256 tot1) {
        (uint256 dep0, uint256 dep1) = liquid.deployedReserve();
        tot0 = IERC20(_token0()).balanceOf(address(vault)) + dep0;
        tot1 = IERC20(_token1()).balanceOf(address(vault)) + dep1;
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
        if (s == 0) return 0;
        a = FullMath.mulDiv(s - 1, tot, supply) + 1;
        if (a > 0 && a < tot && FullMath.mulDivRoundingUp(a, supply, tot) == s) return a;
        return 0;
    }

    function _join(uint256 amount0, uint256 amount1) internal returns (uint256 shares) {
        MintableERC20Decimals(_token0()).mint(address(this), amount0);
        MintableERC20Decimals(_token1()).mint(address(this), amount1);
        IERC20(_token0()).approve(address(vault), amount0);
        IERC20(_token1()).approve(address(vault), amount1);
        shares = inMulti.exchangeInManyToOne(
            _poolTokens(), _amts(amount0, amount1), IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertGt(shares, 0, "join shares");
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

    function _fullRangeTicks() internal view returns (int24 minTick, int24 maxTick) {
        minTick = TickMath.minUsableTick(poolKey.tickSpacing);
        maxTick = TickMath.maxUsableTick(poolKey.tickSpacing);
    }

    function _assertFreeWithinDeadband(uint256 liquidPct) internal view {
        (uint256 dep0, uint256 dep1) = liquid.deployedReserve();
        uint256 free0 = liquid.localReserve(_token0());
        uint256 free1 = liquid.localReserve(_token1());
        uint256 total0 = free0 + dep0;
        uint256 total1 = free1 + dep1;
        uint256 dust0 = _tinyOf(_token0());
        uint256 dust1 = _tinyOf(_token1());
        uint256 milli0 = _milliOf(_token0());
        uint256 milli1 = _milliOf(_token1());
        if (total0 > 0) {
            uint256 target0 = (total0 * liquidPct) / ONE_WAD;
            uint256 dev0 = free0 > target0 ? free0 - target0 : target0 - free0;
            uint256 tol0 = target0 == 0 ? dust0 : (target0 * 0.05e18) / ONE_WAD;
            if (tol0 < dust0) tol0 = dust0;
            assertLe(dev0, tol0 + total0 / 4 + milli0, "token0 deadband");
        }
        if (total1 > 0) {
            uint256 target1 = (total1 * liquidPct) / ONE_WAD;
            uint256 dev1 = free1 > target1 ? free1 - target1 : target1 - free1;
            uint256 tol1 = target1 == 0 ? dust1 : (target1 * 0.05e18) / ONE_WAD;
            if (tol1 < dust1) tol1 = dust1;
            if (target1 > 0) {
                assertLe(dev1, tol1 + total1 / 2 + milli1, "token1 deadband");
            }
        }
    }

    function _token0() internal view returns (address) {
        return Currency.unwrap(poolKey.currency0);
    }

    function _token1() internal view returns (address) {
        return Currency.unwrap(poolKey.currency1);
    }
}
