// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PositionInfo} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/PositionInfoLibrary.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
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
    IUniswapV4StandardExchangeDFPkg,
    UniswapV4StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {
    UniswapV4_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol";
import {
    PoolManagerUnlockSeCaller
} from "test/foundry/spec/protocol/dexes/uniswap/v4/harness/PoolManagerUnlockSeCaller.sol";

contract FullRangeBookSeeder is IUnlockCallback {
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

contract FullRangeBookSwapper is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;

    IPoolManager internal immutable poolManager;

    constructor(IPoolManager poolManager_) {
        poolManager = poolManager_;
    }

    function swapExactIn(PoolKey memory poolKey, bool zeroForOne, uint256 amountIn) external returns (uint256 amountOut) {
        amountOut = abi.decode(poolManager.unlock(abi.encode(poolKey, zeroForOne, amountIn)), (uint256));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "not pm");
        (PoolKey memory poolKey, bool zeroForOne, uint256 amountIn) = abi.decode(data, (PoolKey, bool, uint256));
        BalanceDelta delta = poolManager.swap(
            poolKey,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            bytes("")
        );
        _settle(poolKey.currency0, delta.amount0());
        _settle(poolKey.currency1, delta.amount1());
        uint256 amountOut = zeroForOne ? uint128(delta.amount1()) : uint128(delta.amount0());
        return abi.encode(amountOut);
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

/// @dev Bind-path PositionManager for FR6. Reuses E6 import harness shape; packs non-min/max ticks.
contract Fr6PositionManager {
    PoolKey public key;
    uint128 public liq;
    address public nftOwner;
    PositionInfo public info;

    function configure(PoolKey memory key_, uint128 liq_, address nftOwner_, int24 tickLower_, int24 tickUpper_)
        external
    {
        key = key_;
        liq = liq_;
        nftOwner = nftOwner_;
        uint256 packed = (uint256(uint24(tickLower_)) << 8) | (uint256(uint24(tickUpper_)) << 32);
        info = PositionInfo.wrap(packed);
    }

    function getPoolAndPositionInfo(uint256) external view returns (PoolKey memory, PositionInfo) {
        return (key, info);
    }

    function getPositionLiquidity(uint256) external view returns (uint128) {
        return liq;
    }

    function ownerOf(uint256) external view returns (address) {
        return nftOwner;
    }

    function transferFrom(address, address, uint256) external {}

    function modifyLiquidities(bytes calldata, uint256) external {}
}

/**
 * @title UniswapV4StandardExchange_FullRangeBook
 * @notice FR1–FR6 on the gold DFPkg path. FR6 uses the E6 bind-PositionManager harness
 *         (hermetic TestBase cannot mint a live PositionManager NFT).
 */
contract UniswapV4StandardExchange_FullRangeBook is TestBase_UniswapV4StandardExchange {
    using PoolIdLibrary for PoolKey;
    using UniswapV4_Component_FactoryService for IFacet;
    using UniswapV4_Component_FactoryService for IIndexedexManagerProxy;

    bytes32 internal constant LOWER_WING_SALT = keccak256("indexedex.protocols.dexes.uniswap.v4.position.lowerWing");
    bytes32 internal constant UPPER_WING_SALT = keccak256("indexedex.protocols.dexes.uniswap.v4.position.upperWing");

    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IStandardExchangeProxy internal vault;
    IUniswapV4StandardExchangeLiquidReserve internal liquid;
    IStandardExchangeInMulti internal inMulti;
    PoolKey internal poolKey;
    FullRangeBookSeeder internal seeder;
    FullRangeBookSwapper internal swapper;
    PoolManagerUnlockSeCaller internal unlockCaller;

    function setUp() public override {
        super.setUp();
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
        poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        poolManager.initialize(poolKey, TickMath.getSqrtPriceAtTick(0));

        seeder = new FullRangeBookSeeder(poolManager);
        swapper = new FullRangeBookSwapper(poolManager);
        unlockCaller = new PoolManagerUnlockSeCaller(poolManager);
        tokenA.mint(address(seeder), 1_000_000 ether);
        tokenB.mint(address(seeder), 1_000_000 ether);
        tokenA.mint(address(swapper), 1_000_000 ether);
        tokenB.mint(address(swapper), 1_000_000 ether);

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
    }

    function test_FR1_centerTicksFullRange_wingsUnused() public {
        _dualJoin(10 ether, 10 ether);
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        uint128 centerL = _liquidityAt(minTick, maxTick, bytes32(0));
        assertGt(centerL, 0, "FR1: center L");
        assertEq(_liquidityAt(-60, 60, bytes32(0)), 0, "FR1: old tight center unused");
        assertEq(_liquidityAt(-1800, -60, LOWER_WING_SALT), 0, "FR1: lower wing L=0");
        assertEq(_liquidityAt(60, 1800, UPPER_WING_SALT), 0, "FR1: upper wing L=0");
        assertEq(_liquidityAt(minTick, maxTick, LOWER_WING_SALT), 0, "FR1: wing salt on full range");
    }

    function test_FR2_spotWalk_centerStaysInRange_feesOrTotalsGrow() public {
        _dualJoin(50 ether, 50 ether);
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        (uint256 live0Before, uint256 live1Before) = StateLibrary.getFeeGrowthInside(poolManager, poolKey.toId(), minTick, maxTick);
        (uint256 tot0Before, uint256 tot1Before) = _totals();

        swapper.swapExactIn(poolKey, true, 20_000 ether);
        (, int24 tickAfter,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        assertLt(minTick, tickAfter, "FR2: above lower");
        assertLt(tickAfter, maxTick, "FR2: below upper");

        (uint256 live0After, uint256 live1After) = StateLibrary.getFeeGrowthInside(poolManager, poolKey.toId(), minTick, maxTick);
        (uint256 tot0After, uint256 tot1After) = _totals();
        assertTrue(
            live0After > live0Before || live1After > live1Before || tot0After != tot0Before || tot1After != tot1Before,
            "FR2: fee growth or totals moved"
        );
    }

    function test_FR3_rebalanceAfterWalk_ticksUnchanged_sleeveDeadband() public {
        test_FR2_spotWalk_centerStaysInRange_feesOrTotalsGrow();
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        uint128 lBefore = _liquidityAt(minTick, maxTick, bytes32(0));
        assertGt(lBefore, 0, "FR3: had L");
        liquid.rebalanceLiquidReserve();
        assertGt(_liquidityAt(minTick, maxTick, bytes32(0)), 0, "FR3: still on full-range");
        _assertFreeWithinDeadband(0.2e18);
    }

    function test_FR4_blockedJoin_thenIdleRebalance_sameFullRangeTicks() public {
        _dualJoin(10 ether, 10 ether);
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        uint256 blockedIn = 5 ether;
        ERC20PermitMintableStub(_token0()).mint(address(unlockCaller), blockedIn);
        vm.prank(address(unlockCaller));
        IERC20(_token0()).approve(address(vault), blockedIn);
        unlockCaller.runExchangeIn(
            address(vault),
            IERC20(_token0()),
            blockedIn,
            IERC20(address(vault)),
            0,
            address(this),
            false,
            _deadline()
        );
        assertEq(_liquidityAt(minTick, maxTick, bytes32(0)) > 0 ? 1 : 0, 1, "FR4: center still there");
        liquid.rebalanceLiquidReserve();
        assertGt(_liquidityAt(minTick, maxTick, bytes32(0)), 0, "FR4: rebalance stays full-range");
    }

    function test_FR5_singleTokenFirstMint_thenOtherTokenMintsFullRangeL() public {
        uint256 amountIn = 10 ether;
        ERC20PermitMintableStub(_token0()).mint(address(this), amountIn);
        IERC20(_token0()).approve(address(vault), amountIn);
        uint256 shares = vault.exchangeIn(
            IERC20(_token0()), amountIn, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertGt(shares, 0, "FR5: shares");
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        uint128 lAfterFirst = _liquidityAt(minTick, maxTick, bytes32(0));

        ERC20PermitMintableStub(_token1()).mint(address(this), amountIn);
        IERC20(_token1()).approve(address(vault), amountIn);
        vault.exchangeIn(IERC20(_token1()), amountIn, IERC20(address(vault)), 0, address(this), false, _deadline());
        uint128 lAfterSecond = _liquidityAt(minTick, maxTick, bytes32(0));
        assertGt(lAfterSecond, lAfterFirst, "FR5: second token mints full-range L");
    }

    function test_FR6_importedNftTicksNotRewritten() public {
        int24 importedLower = -120;
        int24 importedUpper = 120;
        Fr6PositionManager pm_ = new Fr6PositionManager();
        pm_.configure(poolKey, 1_000_000, address(this), importedLower, importedUpper);
        IStandardExchangeProxy bound_ = _deployVaultBoundToPm(IPositionManager(address(pm_)));

        uint256 shares = IUniswapV4StandardExchangePositionImport(address(bound_)).importPosition(
            IPositionManager(address(pm_)), 1, 0, address(this), address(this), _deadline()
        );
        assertGt(shares, 0, "FR6: import minted");

        IUniswapV4StandardExchangeLiquidReserve boundLiq_ = IUniswapV4StandardExchangeLiquidReserve(address(bound_));
        ERC20PermitMintableStub(_token0()).mint(address(bound_), 20 ether);
        ERC20PermitMintableStub(_token1()).mint(address(bound_), 20 ether);
        boundLiq_.rebalanceLiquidReserve();

        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        assertTrue(importedLower != minTick || importedUpper != maxTick, "FR6: imported != full range");
        // Harness NFT ticks stay on the bound vault center; full-range salt-0 is not created.
        assertEq(_liquidityAtOn(address(bound_), minTick, maxTick, bytes32(0)), 0, "FR6: no rewrite to min/max");
    }

    function _dualJoin(uint256 amount0, uint256 amount1) internal returns (uint256 shares) {
        address[] memory tokens = new address[](2);
        tokens[0] = _token0();
        tokens[1] = _token1();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;
        ERC20PermitMintableStub(_token0()).mint(address(this), amount0);
        ERC20PermitMintableStub(_token1()).mint(address(this), amount1);
        IERC20(_token0()).approve(address(vault), amount0);
        IERC20(_token1()).approve(address(vault), amount1);
        shares = inMulti.exchangeInManyToOne(tokens, amounts, IERC20(address(vault)), 0, address(this), false, _deadline());
        assertGt(shares, 0, "dual join shares");
    }

    function _fullRangeTicks() internal view returns (int24 minTick, int24 maxTick) {
        minTick = TickMath.minUsableTick(poolKey.tickSpacing);
        maxTick = TickMath.maxUsableTick(poolKey.tickSpacing);
    }

    function _liquidityAt(int24 tickLower, int24 tickUpper, bytes32 salt) internal view returns (uint128 liq) {
        return _liquidityAtOn(address(vault), tickLower, tickUpper, salt);
    }

    function _liquidityAtOn(address owner_, int24 tickLower, int24 tickUpper, bytes32 salt)
        internal
        view
        returns (uint128 liq)
    {
        (liq,,) = StateLibrary.getPositionInfo(poolManager, poolKey.toId(), owner_, tickLower, tickUpper, salt);
    }

    function _totals() internal view returns (uint256 total0, uint256 total1) {
        (uint256 dep0, uint256 dep1) = liquid.deployedReserve();
        total0 = liquid.localReserve(_token0()) + dep0;
        total1 = liquid.localReserve(_token1()) + dep1;
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

    function _deployVaultBoundToPm(IPositionManager positionManager_) internal returns (IStandardExchangeProxy) {
        vm.startPrank(owner);
        IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit_ =
            UniswapV4_Component_FactoryService.buildArgsUniswapV4StandardExchangePkgInit(_univ4SePkgInitCore());
        pkgInit_ = UniswapV4_Component_FactoryService.attachTwapOracle(pkgInit_, twapOracle);
        pkgInit_ = UniswapV4_Component_FactoryService.attachUniswapV4StandardExchangeMultiFacets(
            pkgInit_,
            uniswapV4StandardExchangeInMultiFacet,
            uniswapV4StandardExchangeInMultiQueryFacet,
            uniswapV4StandardExchangeOutMultiFacet,
            uniswapV4StandardExchangeOutMultiQueryFacet
        );
        pkgInit_.positionManager = positionManager_;
        IUniswapV4StandardExchangeDFPkg boundPkg_ = IUniswapV4StandardExchangeDFPkg(
            address(
                IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
                    type(UniswapV4StandardExchangeDFPkg).creationCode,
                    abi.encode(pkgInit_),
                    keccak256("UniswapV4StandardExchangeDFPkg.boundPM.fr6")
                )
            )
        );
        vm.stopPrank();
        return IStandardExchangeProxy(boundPkg_.deployVault(poolKey, 60));
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
