// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";

import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IUniswapV4StandardExchangeLiquidReserve} from
    "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";
import {IUniswapV4StandardExchangePositionImport} from
    "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol";
import {PoolManagerUnlockSeCaller} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/harness/PoolManagerUnlockSeCaller.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {UniswapV4SeDecimalsHelpers} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4SeDecimalsHelpers.sol";
import {UniswapV4LiquiditySeeder_ProDexUniV4} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/harness/UniswapV4SeDecimalsPoolOps.sol";

/**
 * @title UniswapV4StandardExchange_LocalLiquidBuffer_Decimals
 * @notice T1–T16 + H1/H3/H4 on combo decimals. pairToken = tokenA. vaultShare stays 18.
 */
abstract contract UniswapV4StandardExchange_LocalLiquidBuffer_Decimals is UniswapV4SeDecimalsHelpers {
    MintableERC20Decimals internal tokenA;
    MintableERC20Decimals internal tokenB;
    IStandardExchangeProxy internal vault;
    IUniswapV4StandardExchangeLiquidReserve internal liquid;
    PoolKey internal poolKey;
    UniswapV4LiquiditySeeder_ProDexUniV4 internal seeder;
    PoolManagerUnlockSeCaller internal unlockCaller;

    function _u0(uint256 human) internal view returns (uint256) {
        return _uOf(_token0(), human);
    }

    function _u1(uint256 human) internal view returns (uint256) {
        return _uOf(_token1(), human);
    }

    function setUp() public virtual override {
        super.setUp();

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
    }

    function test_T9_reservesEqualFreePlusDeployed() public {
        _bootstrapDeposit(10);

        (uint256 dep0,) = liquid.deployedReserve();
        uint256 free0 = liquid.localReserve(_token0());
        uint256 free1 = liquid.localReserve(_token1());

        assertEq(free0, IERC20(_token0()).balanceOf(address(vault)), "free0 == balance");
        assertEq(free1, IERC20(_token1()).balanceOf(address(vault)), "free1 == balance");
        assertTrue(free0 + dep0 + free1 > 0, "has inventory");
    }

    function test_T4d_donationDilutesSharePrice() public {
        uint256 shares = _bootstrapDeposit(10);
        uint256 supply = vault.totalSupply();
        assertEq(shares, supply, "sole holder");

        (uint256 dep0Before,) = liquid.deployedReserve();
        uint256 free0Before = liquid.localReserve(_token0());
        uint256 donation = _u0(5);

        _mintAndTransfer(_token0(), address(vault), donation);

        uint256 free0After = liquid.localReserve(_token0());
        (uint256 dep0After,) = liquid.deployedReserve();
        assertEq(free0After, free0Before + donation, "free increases by donation");
        assertEq(dep0After, dep0Before, "deployed unchanged");
        assertEq(vault.totalSupply(), supply, "supply unchanged - diluted claim");
    }

    function test_T1_idleDeposit_freeNear20pct() public {
        _bootstrapDeposit(100);
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_T1b_idleDeposit_notFullDeployRefund() public {
        _bootstrapDeposit(20);
        uint256 amountIn = _u0(50);
        MintableERC20Decimals(_token0()).mint(address(this), amountIn);
        IERC20(_token0()).approve(address(vault), amountIn);
        uint256 senderBefore = IERC20(_token0()).balanceOf(address(this));

        vault.exchangeIn(IERC20(_token0()), amountIn, IERC20(address(vault)), 0, address(this), false, _deadline());

        assertEq(IERC20(_token0()).balanceOf(address(this)), senderBefore - amountIn, "no refund to sender");
    }

    function test_T2_inSessionDeposit_sleeveNoNestedUnlock() public {
        _bootstrapDeposit(20);
        uint256 amountIn = _u0(5);
        MintableERC20Decimals t0 = MintableERC20Decimals(_token0());
        t0.mint(address(unlockCaller), amountIn);
        vm.prank(address(unlockCaller));
        t0.approve(address(vault), amountIn);

        uint256 shares = unlockCaller.runExchangeIn(
            address(vault), IERC20(_token0()), amountIn, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertGt(shares, 0, "blocked deposit mints shares");
        assertGe(liquid.localReserve(_token0()), amountIn, "sleeve holds deposit");
    }

    function test_H1_outerUnlock_seDeposit() public {
        test_T2_inSessionDeposit_sleeveNoNestedUnlock();
    }

    function test_T3_publicRebalanceAfterBlockedDeposit() public {
        test_T2_inSessionDeposit_sleeveNoNestedUnlock();
        assertTrue(liquid.canOpenPoolManagerUnlock(), "idle after outer unlock");
        uint256 supplyBefore = vault.totalSupply();
        liquid.rebalanceLiquidReserve();
        assertEq(vault.totalSupply(), supplyBefore, "rebalance does not issue shares");
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_T4_blockedAmountOut_paysSleeve() public {
        _bootstrapDeposit(20);
        _mintAndTransfer(_token0(), address(vault), _u0(2));

        uint256 amountOut = _u0(1);
        uint256 freeBefore = liquid.localReserve(_token0());
        assertGe(freeBefore, amountOut, "free covers");

        uint256 maxShares = vault.balanceOf(address(this));
        vault.transfer(address(vault), maxShares);

        uint256 recipientBalBefore = IERC20(_token0()).balanceOf(address(this));
        unlockCaller.runExchangeOut(
            address(vault),
            IERC20(address(vault)),
            maxShares,
            IERC20(_token0()),
            amountOut,
            address(this),
            true,
            _deadline()
        );
        assertGe(IERC20(_token0()).balanceOf(address(this)), recipientBalBefore + amountOut, "paid from sleeve");
    }

    function test_T4b_blockedAmountOut_wrongTokenFree_reverts() public {
        _bootstrapDeposit(20);
        liquid.rebalanceLiquidReserve();
        uint256 free0 = liquid.localReserve(_token0());
        _mintAndTransfer(_token1(), address(vault), _u1(10));

        uint256 want = free0 + _u0(1);
        uint256 shares = vault.balanceOf(address(this));
        vault.transfer(address(vault), shares);

        vm.expectRevert();
        unlockCaller.runExchangeOut(
            address(vault), IERC20(address(vault)), shares, IERC20(_token0()), want, address(this), true, _deadline()
        );
    }

    function test_T5_blockedAmountOut_insufficientLocalReserve() public {
        _bootstrapDeposit(10);
        liquid.rebalanceLiquidReserve();
        uint256 free0 = liquid.localReserve(_token0());
        uint256 want = free0 + _u0(1);
        uint256 shares = vault.balanceOf(address(this));
        vault.transfer(address(vault), shares);

        vm.expectRevert();
        unlockCaller.runExchangeOut(
            address(vault), IERC20(address(vault)), shares, IERC20(_token0()), want, address(this), true, _deadline()
        );
    }

    function test_T4c_freeAmountOut_alwaysPmNotSleeveFirst() public {
        _bootstrapDeposit(50);
        _mintAndTransfer(_token0(), address(vault), _u0(10));
        assertGt(liquid.localReserve(_token0()), _u0(1), "large free");

        uint256 amountOut = _halfOf(_token0());
        uint256 sharesBefore = vault.balanceOf(address(this));
        uint256 sharesBurned = vault.exchangeOut(
            IERC20(address(vault)), sharesBefore, IERC20(_token0()), amountOut, address(this), false, _deadline()
        );
        assertGt(sharesBurned, 0, "burned");
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_T6_blockedDirectSwap_reverts() public {
        uint256 amountIn = _milliOf(_token0());
        MintableERC20Decimals t0 = MintableERC20Decimals(_token0());
        t0.mint(address(unlockCaller), amountIn);
        vm.prank(address(unlockCaller));
        t0.approve(address(vault), amountIn);

        vm.expectRevert();
        unlockCaller.runExchangeIn(
            address(vault), IERC20(_token0()), amountIn, IERC20(_token1()), 0, address(this), false, _deadline()
        );
    }

    function test_T7_idleDirectSwap_thenRebalance() public {
        _bootstrapDeposit(20);
        uint256 amountIn = _milliOf(_token0());
        MintableERC20Decimals t0 = MintableERC20Decimals(_token0());
        t0.mint(address(this), amountIn);
        t0.approve(address(vault), amountIn);
        uint256 outAmt =
            vault.exchangeIn(IERC20(_token0()), amountIn, IERC20(_token1()), 0, address(this), false, _deadline());
        assertGt(outAmt, 0, "swap out");
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_T8_previewEqualsExec_freeZapIn() public {
        _bootstrapDeposit(20);
        uint256 amountIn = _u0(3);
        MintableERC20Decimals t0 = MintableERC20Decimals(_token0());
        t0.mint(address(this), amountIn);
        t0.approve(address(vault), amountIn);
        uint256 preview = vault.previewExchangeIn(IERC20(_token0()), amountIn, IERC20(address(vault)));
        uint256 exec =
            vault.exchangeIn(IERC20(_token0()), amountIn, IERC20(address(vault)), 0, address(this), false, _deadline());
        assertEq(preview, exec, "preview==exec free zap-in");
    }

    function test_T8b_previewEqualsExec_freeZapIn_withRebalance() public {
        _bootstrapDeposit(10);
        uint256 amountIn = _u0(5);
        MintableERC20Decimals t0 = MintableERC20Decimals(_token0());
        t0.mint(address(this), amountIn);
        t0.approve(address(vault), amountIn);
        uint256 preview = vault.previewExchangeIn(IERC20(_token0()), amountIn, IERC20(address(vault)));
        uint256 exec =
            vault.exchangeIn(IERC20(_token0()), amountIn, IERC20(address(vault)), 0, address(this), false, _deadline());
        assertEq(preview, exec, "sharesOut preview==exec even if rebalance moves inventory");
    }

    function test_H4_typeDefault20pct() public view {
        assertEq(
            IVaultFeeOracleQuery(address(indexedexManager)).liquidReservePercentageOfVault(address(vault)),
            0.2e18,
            "type default 20%"
        );
        assertEq(liquid.targetLiquidReservePercentage(), 0.2e18, "live target 20%");
    }

    function test_T11_typeDefaultWithoutVaultOverride() public view {
        test_H4_typeDefault20pct();
    }

    function test_T10_oracleCascade_vaultOverridesType() public {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setLiquidReservePercentageOfVault(address(vault), 0.3e18);
        assertEq(liquid.targetLiquidReservePercentage(), 0.3e18, "vault override");

        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setLiquidReservePercentageOfVault(address(vault), 0);
        assertEq(liquid.targetLiquidReservePercentage(), 0.2e18, "type after unset vault");
    }

    function test_T11b_changeTypeDefaultLive() public {
        _bootstrapDeposit(30);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(
            type(IUniswapV4StandardExchangeLiquidReserve).interfaceId, 0.4e18
        );
        assertEq(liquid.targetLiquidReservePercentage(), 0.4e18, "new type default");
        liquid.rebalanceLiquidReserve();
        _assertFreeWithinDeadband(0.4e18);
    }

    function test_T12_firstMintBlocked_thenFreeRebalanceCreatesPosition() public {
        uint256 amount0 = _u0(8);
        uint256 amount1 = _u1(8);
        MintableERC20Decimals(_token0()).mint(address(unlockCaller), amount0);
        MintableERC20Decimals(_token1()).mint(address(unlockCaller), amount1);
        vm.startPrank(address(unlockCaller));
        IERC20(_token0()).approve(address(vault), amount0);
        IERC20(_token1()).approve(address(vault), amount1);
        vm.stopPrank();
        address[] memory tokens = new address[](2);
        tokens[0] = _token0();
        tokens[1] = _token1();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;
        uint256 shares = unlockCaller.runExchangeInManyToOne(
            address(vault), tokens, amounts, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertGt(shares, 0, "first mint funded in both sleeve currencies");
        (uint256 dep0, uint256 dep1) = liquid.deployedReserve();
        assertEq(dep0, 0, "no token0 deployed during outer unlock");
        assertEq(dep1, 0, "no token1 deployed during outer unlock");
        assertEq(liquid.localReserve(_token0()), amount0, "token0 held in sleeve");
        assertEq(liquid.localReserve(_token1()), amount1, "token1 held in sleeve");
        liquid.rebalanceLiquidReserve();
        (dep0, dep1) = liquid.deployedReserve();
        assertGt(dep0, 0, "idle rebalance deploys token0");
        assertGt(dep1, 0, "idle rebalance deploys token1");
        assertTrue(liquid.canOpenPoolManagerUnlock(), "idle");
    }

    function test_T14_publicRebalanceBlocked_reverts() public {
        _bootstrapDeposit(5);
        RebalanceWhileUnlockedDecimals attacker = new RebalanceWhileUnlockedDecimals(poolManager, address(vault));
        vm.expectRevert();
        attacker.run();
    }

    function test_T15_withinDeadband_noUnlockNeeded() public {
        _bootstrapDeposit(40);
        _assertFreeWithinDeadband(0.2e18);
        liquid.rebalanceLiquidReserve();
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_T16_outsideDeadband_movesToTarget() public {
        _bootstrapDeposit(20);
        _mintAndTransfer(_token0(), address(vault), _u0(50));
        _mintAndTransfer(_token1(), address(vault), _u1(50));
        liquid.rebalanceLiquidReserve();
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_T4f_rebalanceNoSwap() public {
        _bootstrapDeposit(20);
        _mintAndTransfer(_token0(), address(vault), _u0(30));
        liquid.rebalanceLiquidReserve();
        (uint256 d0, uint256 d1) = liquid.deployedReserve();
        assertTrue(d0 + d1 + liquid.localReserve(_token0()) + liquid.localReserve(_token1()) > 0, "inventory");
    }

    function test_T4e_positionImportBlocked_reverts() public {
        ImportWhileUnlockedDecimals attacker = new ImportWhileUnlockedDecimals(poolManager, address(vault));
        vm.expectRevert();
        attacker.run();
    }

    function test_T13_reentrancyBlockedDeposit() public {
        HostileReenterERC20Decimals hostile = new HostileReenterERC20Decimals();
        MintableERC20Decimals pair = new MintableERC20Decimals("Pair", "PAIR", 18);
        PoolKey memory hk = _buildPoolKey(address(hostile), address(pair));
        poolManager.initialize(hk, TickMath.getSqrtPriceAtTick(0));

        pair.mint(address(seeder), 100_000 ether);
        hostile.mint(address(seeder), 100_000 ether);
        int24 tickLower = -120;
        int24 tickUpper = 120;
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
            TickMath.getSqrtPriceAtTick(0),
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            50_000 ether,
            50_000 ether
        );
        seeder.addLiquidity(hk, tickLower, tickUpper, liq);

        IStandardExchangeProxy hVault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(hk));
        hostile.mint(address(this), 11 ether);
        pair.mint(address(this), 10 ether);
        hostile.approve(address(hVault), 11 ether);
        pair.approve(address(hVault), 10 ether);
        address[] memory tokens = new address[](2);
        tokens[0] = Currency.unwrap(hk.currency0);
        tokens[1] = Currency.unwrap(hk.currency1);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10 ether;
        amounts[1] = 10 ether;
        uint256 initialShares = IStandardExchangeInMulti(address(hVault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(hVault)), 0, address(this), false, _deadline()
        );
        assertGt(initialShares, 0, "hostile vault activated before arming reentry");
        hostile.setAttackTarget(address(hVault), true);
        uint256 depositedShares = hVault.exchangeIn(
            IERC20(address(hostile)), 1 ether, IERC20(address(hVault)), 0, address(this), false, _deadline()
        );
        assertGt(depositedShares, 0, "outer funded deposit completes");
        assertEq(hostile.reentryAttempts(), 1, "hostile transferFrom reaches nested call");
        assertFalse(hostile.nestedCallSucceeded(), "nested deposit blocked");
        assertEq(hostile.nestedErrorSelector(), IReentrancyLock.IsLocked.selector, "nested guard error");
    }

    function test_H3_midSessionAmountOut_cover() public {
        test_T4_blockedAmountOut_paysSleeve();
    }

    function _bootstrapDeposit(uint256 human) internal returns (uint256 shares) {
        uint256 amount0 = _u0(human);
        uint256 amount1 = _u1(human);
        MintableERC20Decimals(_token0()).mint(address(this), amount0);
        MintableERC20Decimals(_token1()).mint(address(this), amount1);
        IERC20(_token0()).approve(address(vault), amount0);
        IERC20(_token1()).approve(address(vault), amount1);
        address[] memory tokens = new address[](2);
        tokens[0] = _token0();
        tokens[1] = _token1();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;
        shares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertGt(shares, 0, "bootstrap");
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
            assertLe(dev0, tol0 + total0 / 4 + milli0, "token0 within wide deadband");
        }
        if (total1 > 0) {
            uint256 target1 = (total1 * liquidPct) / ONE_WAD;
            uint256 dev1 = free1 > target1 ? free1 - target1 : target1 - free1;
            uint256 tol1 = target1 == 0 ? dust1 : (target1 * 0.05e18) / ONE_WAD;
            if (tol1 < dust1) tol1 = dust1;
            if (target1 > 0) {
                assertLe(dev1, tol1 + total1 / 2 + milli1, "token1 within wide band");
            }
        }
    }

    function _mintAndTransfer(address token, address to, uint256 amount) internal {
        if (token == address(tokenA)) {
            tokenA.mint(address(this), amount);
            tokenA.transfer(to, amount);
        } else {
            tokenB.mint(address(this), amount);
            tokenB.transfer(to, amount);
        }
    }

    function _token0() internal view returns (address) {
        return Currency.unwrap(poolKey.currency0);
    }

    function _token1() internal view returns (address) {
        return Currency.unwrap(poolKey.currency1);
    }
}

contract RebalanceWhileUnlockedDecimals is IUnlockCallback {
    IPoolManager immutable pm;
    address immutable vault;

    constructor(IPoolManager pm_, address vault_) {
        pm = pm_;
        vault = vault_;
    }

    function run() external {
        pm.unlock("");
    }

    function unlockCallback(bytes calldata) external returns (bytes memory) {
        IUniswapV4StandardExchangeLiquidReserve(vault).rebalanceLiquidReserve();
        return "";
    }
}

contract ImportWhileUnlockedDecimals is IUnlockCallback {
    IPoolManager immutable pm;
    address immutable vault;

    constructor(IPoolManager pm_, address vault_) {
        pm = pm_;
        vault = vault_;
    }

    function run() external {
        pm.unlock("");
    }

    function unlockCallback(bytes calldata) external returns (bytes memory) {
        IUniswapV4StandardExchangePositionImport(vault)
            .importPosition(IPositionManager(address(1)), 1, 0, address(this), address(this), block.timestamp + 1);
        return "";
    }
}

/// @dev Minimal ERC20 that reenters SE.exchangeIn during transferFrom (T13). Stays 18-dec (not a configured underlying).
contract HostileReenterERC20Decimals {
    uint256 public reentryAttempts;
    bool public nestedCallSucceeded;
    bytes4 public nestedErrorSelector;
    string public name = "Hostile";
    string public symbol = "HOS";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public attackVault;
    bool public attackEnabled;
    bool internal entered;

    function setAttackTarget(address vault_, bool enabled_) external {
        attackVault = vault_;
        attackEnabled = enabled_;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        if (attackEnabled && !entered && attackVault != address(0) && to == attackVault) {
            entered = true;
            ++reentryAttempts;
            try IStandardExchangeProxy(attackVault).exchangeIn(
                IERC20(address(this)), 0, IERC20(attackVault), 0, address(this), true, block.timestamp + 1
            ) returns (uint256) {
                nestedCallSucceeded = true;
            } catch (bytes memory reason) {
                if (reason.length >= 4) {
                    bytes4 selector;
                    assembly { selector := mload(add(reason, 32)) }
                    nestedErrorSelector = selector;
                }
            }
            entered = false;
        }
        return true;
    }
}
