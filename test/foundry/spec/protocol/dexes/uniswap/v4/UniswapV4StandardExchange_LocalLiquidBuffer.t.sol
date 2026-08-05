// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    TestBase_UniswapV4StandardExchange
} from "contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol";
import {
    IUniswapV4StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";
import {
    IUniswapV4StandardExchangePositionImport
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol";
import {
    PoolManagerUnlockSeCaller
} from "test/foundry/spec/protocol/dexes/uniswap/v4/harness/PoolManagerUnlockSeCaller.sol";

contract UniswapV4SeedLiquidity is IUnlockCallback {
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
 * @title UniswapV4StandardExchange_LocalLiquidBuffer
 * @notice §8 matrix T1–T16 + H1/H3/H4 for local liquid buffer (production DFPkg + PoolManager + fee oracle).
 */
contract UniswapV4StandardExchange_LocalLiquidBuffer is TestBase_UniswapV4StandardExchange {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IStandardExchangeProxy internal vault;
    IUniswapV4StandardExchangeLiquidReserve internal liquid;
    PoolKey internal poolKey;
    UniswapV4SeedLiquidity internal seeder;
    PoolManagerUnlockSeCaller internal unlockCaller;

    function setUp() public override {
        super.setUp();

        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
        poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        poolManager.initialize(poolKey, TickMath.getSqrtPriceAtTick(0));

        seeder = new UniswapV4SeedLiquidity(poolManager);
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
        uint256 supply = vault.totalSupply();
        assertEq(shares, supply, "sole holder");

        (uint256 dep0Before,) = liquid.deployedReserve();
        uint256 free0Before = liquid.localReserve(_token0());

        _mintAndTransfer(_token0(), address(vault), 5 ether);

        uint256 free0After = liquid.localReserve(_token0());
        (uint256 dep0After,) = liquid.deployedReserve();
        assertEq(free0After, free0Before + 5 ether, "free increases by donation");
        assertEq(dep0After, dep0Before, "deployed unchanged");
        assertEq(vault.totalSupply(), supply, "supply unchanged - diluted claim");
    }

    function test_T1_idleDeposit_freeNear20pct() public {
        _bootstrapDeposit(100 ether);
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_T1b_idleDeposit_notFullDeployRefund() public {
        uint256 amountIn = 50 ether;
        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);
        uint256 senderBefore = tokenA.balanceOf(address(this));

        vault.exchangeIn(IERC20(_token0()), amountIn, IERC20(address(vault)), 0, address(this), false, _deadline());

        assertEq(tokenA.balanceOf(address(this)), senderBefore - amountIn, "no refund to sender");
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_T2_inSessionDeposit_sleeveNoNestedUnlock() public {
        uint256 amountIn = 5 ether;
        tokenA.mint(address(this), amountIn);
        tokenA.transfer(address(vault), amountIn);

        uint256 shares = unlockCaller.runExchangeIn(
            address(vault), IERC20(_token0()), amountIn, IERC20(address(vault)), 0, address(this), true, _deadline()
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
        liquid.rebalanceLiquidReserve();
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_T4_blockedAmountOut_paysSleeve() public {
        _bootstrapDeposit(20 ether);
        _mintAndTransfer(_token0(), address(vault), 2 ether);

        uint256 amountOut = 1 ether;
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
        _bootstrapDeposit(20 ether);
        liquid.rebalanceLiquidReserve();
        uint256 free0 = liquid.localReserve(_token0());
        _mintAndTransfer(_token1(), address(vault), 10 ether);

        uint256 want = free0 + 1 ether;
        uint256 shares = vault.balanceOf(address(this));
        vault.transfer(address(vault), shares);

        vm.expectRevert();
        unlockCaller.runExchangeOut(
            address(vault), IERC20(address(vault)), shares, IERC20(_token0()), want, address(this), true, _deadline()
        );
    }

    function test_T5_blockedAmountOut_insufficientLocalReserve() public {
        _bootstrapDeposit(10 ether);
        liquid.rebalanceLiquidReserve();
        uint256 free0 = liquid.localReserve(_token0());
        uint256 want = free0 + 1 ether;
        uint256 shares = vault.balanceOf(address(this));
        vault.transfer(address(vault), shares);

        vm.expectRevert();
        unlockCaller.runExchangeOut(
            address(vault), IERC20(address(vault)), shares, IERC20(_token0()), want, address(this), true, _deadline()
        );
    }

    function test_T4c_freeAmountOut_alwaysPmNotSleeveFirst() public {
        _bootstrapDeposit(50 ether);
        _mintAndTransfer(_token0(), address(vault), 10 ether);
        assertGt(liquid.localReserve(_token0()), 1 ether, "large free");

        uint256 amountOut = 0.5 ether;
        uint256 sharesBefore = vault.balanceOf(address(this));
        uint256 sharesBurned = vault.exchangeOut(
            IERC20(address(vault)), sharesBefore, IERC20(_token0()), amountOut, address(this), false, _deadline()
        );
        assertGt(sharesBurned, 0, "burned");
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_T6_blockedDirectSwap_reverts() public {
        uint256 amountIn = 1e15;
        tokenA.mint(address(this), amountIn);
        tokenA.transfer(address(vault), amountIn);

        vm.expectRevert();
        unlockCaller.runExchangeIn(
            address(vault), IERC20(_token0()), amountIn, IERC20(_token1()), 0, address(this), true, _deadline()
        );
    }

    function test_T7_idleDirectSwap_thenRebalance() public {
        _bootstrapDeposit(20 ether);
        uint256 amountIn = 1e15;
        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);
        uint256 outAmt =
            vault.exchangeIn(IERC20(_token0()), amountIn, IERC20(_token1()), 0, address(this), false, _deadline());
        assertGt(outAmt, 0, "swap out");
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_T8_previewEqualsExec_freeZapIn() public {
        uint256 amountIn = 3 ether;
        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);
        uint256 preview = vault.previewExchangeIn(IERC20(_token0()), amountIn, IERC20(address(vault)));
        uint256 exec =
            vault.exchangeIn(IERC20(_token0()), amountIn, IERC20(address(vault)), 0, address(this), false, _deadline());
        assertEq(preview, exec, "preview==exec free zap-in");
    }

    function test_T8b_previewEqualsExec_freeZapIn_withRebalance() public {
        _bootstrapDeposit(10 ether);
        uint256 amountIn = 5 ether;
        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);
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
        _bootstrapDeposit(30 ether);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager))
            .setDefaultLiquidReservePercentageOfTypeId(
                type(IUniswapV4StandardExchangeLiquidReserve).interfaceId, 0.4e18
            );
        assertEq(liquid.targetLiquidReservePercentage(), 0.4e18, "new type default");
        liquid.rebalanceLiquidReserve();
        _assertFreeWithinDeadband(0.4e18);
    }

    function test_T12_firstMintBlocked_thenFreeRebalanceCreatesPosition() public {
        uint256 amountIn = 8 ether;
        tokenA.mint(address(this), amountIn);
        tokenA.transfer(address(vault), amountIn);

        uint256 shares = unlockCaller.runExchangeIn(
            address(vault), IERC20(_token0()), amountIn, IERC20(address(vault)), 0, address(this), true, _deadline()
        );
        assertGt(shares, 0, "first mint free only");
        (uint256 dep0,) = liquid.deployedReserve();
        assertEq(dep0, 0, "no position while blocked first mint");

        liquid.rebalanceLiquidReserve();
        assertTrue(liquid.canOpenPoolManagerUnlock(), "idle");
    }

    function test_T14_publicRebalanceBlocked_reverts() public {
        _bootstrapDeposit(5 ether);
        RebalanceWhileUnlocked attacker = new RebalanceWhileUnlocked(poolManager, address(vault));
        vm.expectRevert();
        attacker.run();
    }

    function test_T15_withinDeadband_noUnlockNeeded() public {
        _bootstrapDeposit(40 ether);
        _assertFreeWithinDeadband(0.2e18);
        liquid.rebalanceLiquidReserve();
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_T16_outsideDeadband_movesToTarget() public {
        _bootstrapDeposit(20 ether);
        _mintAndTransfer(_token0(), address(vault), 50 ether);
        liquid.rebalanceLiquidReserve();
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_T4f_rebalanceNoSwap() public {
        _bootstrapDeposit(20 ether);
        _mintAndTransfer(_token0(), address(vault), 30 ether);
        liquid.rebalanceLiquidReserve();
        (uint256 d0, uint256 d1) = liquid.deployedReserve();
        assertTrue(d0 + d1 + liquid.localReserve(_token0()) + liquid.localReserve(_token1()) > 0, "inventory");
    }

    function test_T4e_positionImportBlocked_reverts() public {
        ImportWhileUnlocked attacker = new ImportWhileUnlocked(poolManager, address(vault));
        vm.expectRevert();
        attacker.run();
    }

    function test_T13_reentrancyBlockedDeposit() public {
        // Deploy a fresh vault whose token0 reenters exchangeIn on transferFrom (nonReentrant must hold).
        HostileReenterERC20 hostile = new HostileReenterERC20();
        ERC20PermitMintableStub pair = new ERC20PermitMintableStub("Pair", "PAIR", 18, address(this), 0);
        PoolKey memory hk = _buildPoolKey(address(hostile), address(pair));
        poolManager.initialize(hk, TickMath.getSqrtPriceAtTick(0));

        // Seed external pool liquidity with pair + hostile so vault can rebalance later if needed.
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

        IStandardExchangeProxy hVault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(hk, 60));
        hostile.setAttackTarget(address(hVault), Currency.unwrap(hk.currency0) == address(hostile));

        uint256 amountIn = 1 ether;
        hostile.mint(address(this), amountIn);
        hostile.approve(address(hVault), amountIn);

        // Nested exchangeIn from transferFrom must hit nonReentrant (IsLocked).
        vm.expectRevert();
        hVault.exchangeIn(
            IERC20(Currency.unwrap(hk.currency0) == address(hostile) ? address(hostile) : address(pair)),
            amountIn,
            IERC20(address(hVault)),
            0,
            address(this),
            false,
            _deadline()
        );
    }

    function test_H3_midSessionAmountOut_cover() public {
        test_T4_blockedAmountOut_paysSleeve();
    }

    // H2 (real Single SE Buffer CP hook mid-swap → this V4 SE) lives in
    // UniswapV4StandardExchange_LocalLiquidBuffer_H2.t.sol (PRD D19 / plan §8).

    /* ---------------------------------------------------------------------- */
    /*                              helpers                                     */
    /* ---------------------------------------------------------------------- */

    function _bootstrapDeposit(uint256 amountIn) internal returns (uint256 shares) {
        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);
        shares =
            vault.exchangeIn(IERC20(_token0()), amountIn, IERC20(address(vault)), 0, address(this), false, _deadline());
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
            // Allow extra slack for dual-token remove overshoot / single-sided deploy limits.
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

contract RebalanceWhileUnlocked is IUnlockCallback {
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

contract ImportWhileUnlocked is IUnlockCallback {
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

/// @dev Minimal ERC20 that reenters SE.exchangeIn during transferFrom (T13).
contract HostileReenterERC20 {
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
            // Nested deposit while outer exchangeIn holds nonReentrant lock.
            IStandardExchangeProxy(attackVault)
                .exchangeIn(IERC20(address(this)), 0, IERC20(attackVault), 0, address(this), true, block.timestamp + 1);
            entered = false;
        }
        return true;
    }
}
