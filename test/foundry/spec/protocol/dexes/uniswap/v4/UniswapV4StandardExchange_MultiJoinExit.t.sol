// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    TestBase_UniswapV4StandardExchange
} from "contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol";
import {
    IUniswapV4StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";
import {
    UniswapV4StandardExchangeCommon
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol";
import {
    UniswapV4StandardExchangeOutBase
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutBase.sol";
import {
    PoolManagerUnlockSeCaller
} from "test/foundry/spec/protocol/dexes/uniswap/v4/harness/PoolManagerUnlockSeCaller.sol";

contract MultiJoinExitSeeder is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;

    IPoolManager internal immutable poolManager;

    constructor(IPoolManager poolManager_) {
        poolManager = poolManager_;
    }

    function addLiquidity(PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidity) external {
        poolManager.unlock(abi.encode(poolKey, tickLower, tickUpper, liquidity));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "not pm");
        (PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidity) =
            abi.decode(data, (PoolKey, int24, int24, uint128));
        (BalanceDelta callerDelta,) = poolManager.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({
                tickLower: tickLower, tickUpper: tickUpper, liquidityDelta: int256(uint256(liquidity)), salt: bytes32(0)
            }),
            bytes("")
        );
        _settle(poolKey.currency0, callerDelta.amount0());
        _settle(poolKey.currency1, callerDelta.amount1());
        return abi.encode(callerDelta);
    }

    function _settle(Currency currency, int128 delta) internal {
        if (delta < 0) {
            uint256 amount = uint128(-delta);
            poolManager.sync(currency);
            IERC20(Currency.unwrap(currency)).transfer(address(poolManager), amount);
            poolManager.settle();
        } else if (delta > 0) {
            poolManager.take(currency, address(this), uint128(delta));
        }
    }
}

/**
 * @title UniswapV4StandardExchange_MultiJoinExit
 * @notice MJ1–MJ8 and ME1–ME7 on the gold DFPkg diamond (no SUT mock).
 */
contract UniswapV4StandardExchange_MultiJoinExit is TestBase_UniswapV4StandardExchange {
    using PoolIdLibrary for PoolKey;

    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IStandardExchangeProxy internal vault;
    IUniswapV4StandardExchangeLiquidReserve internal liquid;
    IStandardExchangeInMulti internal inMulti;
    IStandardExchangeOutMulti internal outMulti;
    PoolKey internal poolKey;
    MultiJoinExitSeeder internal seeder;
    PoolManagerUnlockSeCaller internal unlockCaller;
    address internal attacker;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
        poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        poolManager.initialize(poolKey, TickMath.getSqrtPriceAtTick(0));

        seeder = new MultiJoinExitSeeder(poolManager);
        unlockCaller = new PoolManagerUnlockSeCaller(poolManager);
        tokenA.mint(address(seeder), 1_000_000 ether);
        tokenB.mint(address(seeder), 1_000_000 ether);
        int24 tickLower = -120;
        int24 tickUpper = 120;
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
            TickMath.getSqrtPriceAtTick(0),
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            100_000 ether,
            100_000 ether
        );
        seeder.addLiquidity(poolKey, tickLower, tickUpper, liq);

        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey, 60));
        liquid = IUniswapV4StandardExchangeLiquidReserve(address(vault));
        inMulti = IStandardExchangeInMulti(address(vault));
        outMulti = IStandardExchangeOutMulti(address(vault));
    }

    function test_MJ1_lengthNotTwo_reverts_singleZapInStillWorks() public {
        address[] memory one = new address[](1);
        one[0] = _token0();
        uint256[] memory oneAmt = new uint256[](1);
        oneAmt[0] = 1 ether;
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        inMulti.exchangeInManyToOne(one, oneAmt, IERC20(address(vault)), 0, address(this), false, _deadline());

        uint256 amountIn = 2 ether;
        ERC20PermitMintableStub(_token0()).mint(address(this), amountIn);
        IERC20(_token0()).approve(address(vault), amountIn);
        uint256 shares = vault.exchangeIn(
            IERC20(_token0()), amountIn, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertGt(shares, 0, "MJ1: single zap-in");
    }

    function test_MJ2_idleProportionalJoin_fullRangeL_andSleeve() public {
        uint256 shares = _join(10 ether, 10 ether);
        assertGt(shares, 0, "MJ2: shares");
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        (uint128 centerL,,) =
            StateLibrary.getPositionInfo(poolManager, poolKey.toId(), address(vault), minTick, maxTick, bytes32(0));
        assertGt(centerL, 0, "MJ2: center L");
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_MJ3_unbalancedJoin_paysBoth_surplusStaysSleeve() public {
        uint256 a0 = 10 ether;
        uint256 a1 = 1 ether;
        uint256 user0Before = IERC20(_token0()).balanceOf(address(this));
        uint256 user1Before = IERC20(_token1()).balanceOf(address(this));
        ERC20PermitMintableStub(_token0()).mint(address(this), a0);
        ERC20PermitMintableStub(_token1()).mint(address(this), a1);
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
        uint256 a0 = 5 ether;
        uint256 a1 = 5 ether;
        ERC20PermitMintableStub(_token0()).mint(address(unlockCaller), a0);
        ERC20PermitMintableStub(_token1()).mint(address(unlockCaller), a1);
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
        _join(4 ether, 4 ether);
        uint256 claimed0 = 2 ether;
        uint256 claimed1 = 2 ether;
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
        uint256[] memory amts = _amts(1 ether, 1 ether);
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
        uint256 previewIdle = inMulti.previewExchangeInManyToOne(_poolTokens(), _amts(3 ether, 3 ether), IERC20(address(vault)));
        uint256 execIdle = _join(3 ether, 3 ether);
        assertEq(execIdle, previewIdle, "MJ7: idle preview");

        uint256 previewBlocked =
            inMulti.previewExchangeInManyToOne(_poolTokens(), _amts(2 ether, 2 ether), IERC20(address(vault)));
        ERC20PermitMintableStub(_token0()).mint(address(unlockCaller), 2 ether);
        ERC20PermitMintableStub(_token1()).mint(address(unlockCaller), 2 ether);
        vm.startPrank(address(unlockCaller));
        IERC20(_token0()).approve(address(vault), 2 ether);
        IERC20(_token1()).approve(address(vault), 2 ether);
        vm.stopPrank();
        uint256 execBlocked = unlockCaller.runExchangeInManyToOne(
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

    function test_ME1_lengthNotTwo_reverts_singleZapOutStillWorks() public {
        _join(10 ether, 10 ether);
        address[] memory one = new address[](1);
        one[0] = _token0();
        uint256[] memory oneAmt = new uint256[](1);
        oneAmt[0] = 1e15;
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        outMulti.exchangeOutOneToMany(IERC20(address(vault)), type(uint256).max, one, oneAmt, address(this), false, _deadline());

        uint256 preview = vault.previewExchangeOut(IERC20(address(vault)), IERC20(_token0()), 1e15);
        vault.approve(address(vault), preview);
        uint256 burned = vault.exchangeOut(
            IERC20(address(vault)), preview, IERC20(_token0()), 1e15, address(this), false, _deadline()
        );
        assertGt(burned, 0, "ME1: single out");
    }

    function test_ME2_idleProportionalExit_paysBoth_ticksUnchanged() public {
        _join(10 ether, 10 ether);
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        (uint128 lBefore,,) =
            StateLibrary.getPositionInfo(poolManager, poolKey.toId(), address(vault), minTick, maxTick, bytes32(0));
        uint256 amount0 = 1 ether;
        uint256 amount1 = 1 ether;
        uint256 preview = outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(amount0, amount1));
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
        _join(10 ether, 10 ether);
        uint256 bal0 = IERC20(_token0()).balanceOf(address(this));
        uint256 bal1 = IERC20(_token1()).balanceOf(address(this));
        uint256 supply = vault.totalSupply();
        vault.approve(address(vault), type(uint256).max);
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        outMulti.exchangeOutOneToMany(
            IERC20(address(vault)), type(uint256).max, _poolTokens(), _amts(1 ether, 2 ether), address(this), false, _deadline()
        );
        assertEq(IERC20(_token0()).balanceOf(address(this)), bal0, "ME3: no token0");
        assertEq(IERC20(_token1()).balanceOf(address(this)), bal1, "ME3: no token1");
        assertEq(vault.totalSupply(), supply, "ME3: no burn");
    }

    function test_ME4_blockedProportional_coverPays_shortRevertsWholeTx() public {
        _join(20 ether, 20 ether);
        uint256 amount0 = 1 ether;
        uint256 amount1 = 1 ether;
        uint256 preview = outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(amount0, amount1));
        vault.transfer(address(vault), preview);
        uint256 burned = unlockCaller.runExchangeOutOneToMany(
            address(vault), IERC20(address(vault)), preview, _poolTokens(), _amts(amount0, amount1), address(this), true, _deadline()
        );
        assertEq(burned, preview, "ME4: blocked cover");

        (uint256 dep0, uint256 dep1) = liquid.deployedReserve();
        uint256 tot0 = liquid.localReserve(_token0()) + dep0;
        uint256 tot1 = liquid.localReserve(_token1()) + dep1;
        uint256 half0 = tot0 / 2;
        uint256 half1 = tot1 / 2;
        uint256 need = outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(half0, half1));
        vault.transfer(address(vault), need);
        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV4StandardExchangeCommon.UniswapV4Exchange_InsufficientLocalReserve.selector,
                _token0(),
                half0,
                liquid.localReserve(_token0())
            )
        );
        unlockCaller.runExchangeOutOneToMany(
            address(vault),
            IERC20(address(vault)),
            need,
            _poolTokens(),
            _amts(half0, half1),
            address(this),
            true,
            _deadline()
        );
    }

    function test_ME5_maxAmountInTooLow_noPartialSend() public {
        _join(10 ether, 10 ether);
        uint256 amount0 = 1 ether;
        uint256 amount1 = 1 ether;
        uint256 need = outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(amount0, amount1));
        uint256 bal0 = IERC20(_token0()).balanceOf(address(this));
        vault.approve(address(vault), need);
        vm.expectRevert(UniswapV4StandardExchangeOutBase.UniswapV4ExchangeOut_InsufficientInput.selector);
        outMulti.exchangeOutOneToMany(
            IERC20(address(vault)), need - 1, _poolTokens(), _amts(amount0, amount1), address(this), false, _deadline()
        );
        assertEq(IERC20(_token0()).balanceOf(address(this)), bal0, "ME5: no send");
    }

    function test_ME6_previewExitSharesMatchExec_idleAndBlocked() public {
        _join(10 ether, 10 ether);
        uint256 amount0 = 5e17;
        uint256 amount1 = 5e17;
        uint256 previewIdle =
            outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(amount0, amount1));
        vault.approve(address(vault), previewIdle);
        uint256 execIdle = outMulti.exchangeOutOneToMany(
            IERC20(address(vault)), previewIdle, _poolTokens(), _amts(amount0, amount1), address(this), false, _deadline()
        );
        assertEq(execIdle, previewIdle, "ME6: idle");

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
        uint256 minted = _join(10 ether, 10 ether);
        uint256 amount0 = 1 ether;
        uint256 amount1 = 1 ether;
        uint256 s = outMulti.previewExchangeOutOneToMany(IERC20(address(vault)), _poolTokens(), _amts(amount0, amount1));
        uint256 extra = 1 ether;
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

    function _join(uint256 amount0, uint256 amount1) internal returns (uint256 shares) {
        ERC20PermitMintableStub(_token0()).mint(address(this), amount0);
        ERC20PermitMintableStub(_token1()).mint(address(this), amount1);
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
        if (total0 > 0) {
            uint256 target0 = (total0 * liquidPct) / ONE_WAD;
            uint256 dev0 = free0 > target0 ? free0 - target0 : target0 - free0;
            uint256 tol0 = target0 == 0 ? 1e12 : (target0 * 0.05e18) / ONE_WAD;
            if (tol0 < 1e12) tol0 = 1e12;
            assertLe(dev0, tol0 + total0 / 4 + 1e15, "token0 deadband");
        }
        if (total1 > 0) {
            uint256 target1 = (total1 * liquidPct) / ONE_WAD;
            uint256 dev1 = free1 > target1 ? free1 - target1 : target1 - free1;
            uint256 tol1 = target1 == 0 ? 1e12 : (target1 * 0.05e18) / ONE_WAD;
            if (tol1 < 1e12) tol1 = 1e12;
            if (target1 > 0) {
                assertLe(dev1, tol1 + total1 / 2 + 1e15, "token1 deadband");
            }
        }
    }

    function _token0() internal view returns (address) {
        return Currency.unwrap(poolKey.currency0);
    }

    function _token1() internal view returns (address) {
        return Currency.unwrap(poolKey.currency1);
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _buildPoolKey(address token0Candidate, address token1Candidate) internal pure returns (PoolKey memory) {
        (address token0, address token1) =
            token0Candidate < token1Candidate ? (token0Candidate, token1Candidate) : (token1Candidate, token0Candidate);
        return PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
    }
}
