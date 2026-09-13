// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {PositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PositionManager.sol";
import {PositionDescriptor} from "@crane/contracts/protocols/dexes/uniswap/v4/PositionDescriptor.sol";
import {IWETH9} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/external/IWETH9.sol";
import {Actions} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Actions.sol";
import {LiquidityAmounts as ReferenceLiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/libraries/LiquidityAmounts.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IUniswapV4StandardExchangeLiquidReserve} from
    "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";
import {IUniswapV4StandardExchangePositionImport} from
    "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol";
import {IUniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/IUniswapV4StandardExchangeDFPkg.sol";

import {UniswapV4_Component_FactoryService} from
    "contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol";
import {PoolManagerUnlockSeCaller} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/harness/PoolManagerUnlockSeCaller.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {UniswapV4SeDecimalsHelpers} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4SeDecimalsHelpers.sol";
import {
    UniswapV4LiquiditySeeder_ProDexUniV4,
    UniswapV4ExternalSwapper_ProDexUniV4
} from "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/harness/UniswapV4SeDecimalsPoolOps.sol";

/**
 * @title UniswapV4StandardExchange_FullRangeBook_Decimals
 * @notice FR1–FR6 on combo decimals. pairToken = tokenA. vaultShare stays 18.
 */
abstract contract UniswapV4StandardExchange_FullRangeBook_Decimals is UniswapV4SeDecimalsHelpers {
    using PoolIdLibrary for PoolKey;
    using UniswapV4_Component_FactoryService for IFacet;
    using UniswapV4_Component_FactoryService for IIndexedexManagerProxy;

    bytes32 internal constant LOWER_WING_SALT = keccak256("indexedex.protocols.dexes.uniswap.v4.position.lowerWing");
    bytes32 internal constant UPPER_WING_SALT = keccak256("indexedex.protocols.dexes.uniswap.v4.position.upperWing");

    MintableERC20Decimals internal tokenA;
    MintableERC20Decimals internal tokenB;
    IStandardExchangeProxy internal vault;
    IUniswapV4StandardExchangeLiquidReserve internal liquid;
    IStandardExchangeInMulti internal inMulti;
    PoolKey internal poolKey;
    UniswapV4LiquiditySeeder_ProDexUniV4 internal seeder;
    UniswapV4ExternalSwapper_ProDexUniV4 internal swapper;
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
        swapper = new UniswapV4ExternalSwapper_ProDexUniV4(poolManager);
        unlockCaller = new PoolManagerUnlockSeCaller(poolManager);
        tokenA.mint(address(seeder), _uA(1_000_000));
        tokenB.mint(address(seeder), _uB(1_000_000));
        tokenA.mint(address(swapper), _uA(1_000_000));
        tokenB.mint(address(swapper), _uB(1_000_000));

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
    }

    function test_FR1_centerTicksFullRange_wingsUnused() public {
        _dualJoin(_u0(10), _u1(10));
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        uint128 centerL = _liquidityAt(minTick, maxTick, bytes32(0));
        assertGt(centerL, 0, "FR1: center L");
        assertEq(_liquidityAt(-60, 60, bytes32(0)), 0, "FR1: old tight center unused");
        assertEq(_liquidityAt(-1800, -60, LOWER_WING_SALT), 0, "FR1: lower wing L=0");
        assertEq(_liquidityAt(60, 1800, UPPER_WING_SALT), 0, "FR1: upper wing L=0");
        assertEq(_liquidityAt(minTick, maxTick, LOWER_WING_SALT), 0, "FR1: wing salt on full range");
    }

    function test_FR2_spotWalk_centerStaysInRange_feesOrTotalsGrow() public {
        _dualJoin(_u0(50), _u1(50));
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        (uint256 live0Before, uint256 live1Before) =
            StateLibrary.getFeeGrowthInside(poolManager, poolKey.toId(), minTick, maxTick);
        (uint256 tot0Before, uint256 tot1Before) = _totals();

        swapper.swapExactIn(poolKey, true, _u0(20_000));
        (, int24 tickAfter,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        assertLt(minTick, tickAfter, "FR2: above lower");
        assertLt(tickAfter, maxTick, "FR2: below upper");

        (uint256 live0After, uint256 live1After) =
            StateLibrary.getFeeGrowthInside(poolManager, poolKey.toId(), minTick, maxTick);
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
        _dualJoin(_u0(10), _u1(10));
        (int24 minTick, int24 maxTick) = _fullRangeTicks();
        uint256 blockedIn = _u0(5);
        MintableERC20Decimals(_token0()).mint(address(unlockCaller), blockedIn);
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

    function testFuzz_singleDeposit_roundTripPreservesIncumbentValue(bool token1_) public {
        _dualJoin(_u0(1000), _u1(1000));
        IERC20 asset = IERC20(token1_ ? _token1() : _token0());
        uint256 amount = token1_ ? _u1(1) : _u0(1);
        address depositor = makeAddr("mixed decimal depositor");
        MintableERC20Decimals(address(asset)).mint(depositor, amount);
        vm.startPrank(depositor);
        asset.approve(address(vault), amount);
        uint256 quoted = vault.previewExchangeIn(asset, amount, IERC20(address(vault)));
        uint256 minted = vault.exchangeIn(asset, amount, IERC20(address(vault)), quoted, depositor, false, _deadline());
        assertEq(minted, quoted);
        IERC20(address(vault)).approve(address(vault), minted);
        uint256 received = vault.exchangeIn(IERC20(address(vault)), minted, asset, 1, depositor, false, _deadline());
        vm.stopPrank();
        assertLe(received, amount, "mixed decimal round trip preserves incumbent value");
    }

    function test_FR5_bothTokensActivateThenSingleTokenDepositsRemainAvailable() public {
        uint256 amount = _u0(10);
        IERC20 input = IERC20(_token0());
        MintableERC20Decimals(address(input)).mint(address(this), amount);
        input.approve(address(vault), amount);
        assertEq(vault.previewExchangeIn(input, amount, IERC20(address(vault))), 0);
        uint256 balance = input.balanceOf(address(this));
        vm.expectRevert(bytes4(keccak256("UniswapV4Exchange_ZeroAmount()")));
        vault.exchangeIn(input, amount, IERC20(address(vault)), 0, address(this), false, _deadline());
        assertEq(input.balanceOf(address(this)), balance, "failed activation keeps payment");
        assertEq(IERC20(address(vault)).totalSupply(), 0);
        assertEq(input.balanceOf(address(vault)), 0);
        uint256 issued = _dualJoin(amount, _u1(10));
        assertGt(issued, 0);
        (int24 lower, int24 upper) = _fullRangeTicks();
        assertGt(_liquidityAt(lower, upper, bytes32(0)), 0, "dual activation creates full-range liquidity");
        input.approve(address(vault), amount);
        uint256 quote = vault.previewExchangeIn(input, amount, IERC20(address(vault)));
        assertGt(quote, 0);
        assertEq(vault.exchangeIn(input, amount, IERC20(address(vault)), quote, address(this), false, _deadline()), quote);
    }

    function test_FR6_importConvertsRealNftToFullRangeIncludingEarnedFees() public {
        (, int24 spotTick,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        int24 center = (spotTick / poolKey.tickSpacing) * poolKey.tickSpacing;
        int24 lowerImport = center - 120;
        int24 upperImport = center + 120;
        (IPositionManager manager, uint256 id) = _mintImportPosition(lowerImport, upperImport);
        swapper.swapExactIn(poolKey, true, _u0(100));
        swapper.swapExactIn(poolKey, false, _u1(100));
        uint256 expected = _importEntitlement(manager, id, lowerImport, upperImport);
        IStandardExchangeProxy bound = _deployVaultBoundToPm(manager);
        IERC721(address(manager)).approve(address(bound), id);
        uint256 shares = IUniswapV4StandardExchangePositionImport(address(bound)).importPosition(
            manager, id, expected, address(this), address(this), block.timestamp
        );
        assertEq(shares, expected, "exact principal plus accrued fees fund shares once");
        assertEq(manager.getPositionLiquidity(id), 0, "narrow NFT is emptied");
        assertEq(IERC721(address(manager)).ownerOf(id), address(bound));
        (int24 lower, int24 upper) = _fullRangeTicks();
        assertGt(_liquidityAtOn(address(bound), lower, upper, bytes32(0)), 0);
        assertEq(_liquidityAtOn(address(bound), lowerImport, upperImport, bytes32(0)), 0);
        IStandardizedYield sy = IStandardizedYield(address(bound));
        assertGt(sy.exchangeRate(), 0);
        uint256 out = sy.previewRedeem(_token0(), shares / 10);
        assertEq(sy.redeem(address(this), shares / 10, _token0(), out, false), out);
    }

    function _mintImportPosition(int24 lower, int24 upper) internal returns (IPositionManager manager, uint256 id) {
        PositionDescriptor descriptor = new PositionDescriptor(poolManager, address(weth), bytes32("ETH"));
        manager = IPositionManager(address(new PositionManager(
            poolManager, IAllowanceTransfer(address(permit2)), 100_000, descriptor, IWETH9(address(weth))
        )));
        for (uint256 i; i < 2; ++i) {
            address token = i == 0 ? _token0() : _token1();
            MintableERC20Decimals(token).mint(address(this), _uOf(token, 10_000));
            IERC20(token).approve(address(permit2), type(uint256).max);
            IAllowanceTransfer(address(permit2)).approve(token, address(manager), type(uint160).max, type(uint48).max);
        }
        (uint160 price,,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            price, TickMath.getSqrtPriceAtTick(lower), TickMath.getSqrtPriceAtTick(upper), _u0(1000), _u1(1000)
        );
        id = manager.nextTokenId();
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(poolKey, lower, upper, uint256(liquidity), uint128(_u0(1000)), uint128(_u1(1000)), address(this), bytes(""));
        params[1] = abi.encode(poolKey.currency0, poolKey.currency1);
        manager.modifyLiquidities(abi.encode(abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR)), params), block.timestamp);
    }

    function _importEntitlement(IPositionManager manager, uint256 id, int24 lower, int24 upper) internal view returns (uint256) {
        (uint160 price,,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        (uint128 liquidity, uint256 last0, uint256 last1) = StateLibrary.getPositionInfo(
            poolManager, poolKey.toId(), address(manager), lower, upper, bytes32(id)
        );
        (uint256 amount0, uint256 amount1) = ReferenceLiquidityAmounts.getAmountsForLiquidity(
            price, TickMath.getSqrtPriceAtTick(lower), TickMath.getSqrtPriceAtTick(upper), liquidity
        );
        (uint256 growth0, uint256 growth1) = StateLibrary.getFeeGrowthInside(poolManager, poolKey.toId(), lower, upper);
        unchecked {
            amount0 += FullMath.mulDiv(growth0 - last0, liquidity, uint256(1) << 128);
            amount1 += FullMath.mulDiv(growth1 - last1, liquidity, uint256(1) << 128);
        }
        return FixedPointMathLib.mulSqrt(amount0, amount1);
    }

    function _dualJoin(uint256 amount0, uint256 amount1) internal returns (uint256 shares) {
        address[] memory tokens = new address[](2);
        tokens[0] = _token0();
        tokens[1] = _token1();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;
        MintableERC20Decimals(_token0()).mint(address(this), amount0);
        MintableERC20Decimals(_token1()).mint(address(this), amount1);
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
                    ArtifactCreationCode.creationCode(create3Factory, "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol:UniswapV4StandardExchangeDFPkg"),
                    abi.encode(pkgInit_),
                    keccak256("UniswapV4StandardExchangeDFPkg.boundPM.fr6.decimals")
                )
            )
        );
        vm.stopPrank();
        return IStandardExchangeProxy(boundPkg_.deployVault(poolKey));
    }

    function _token0() internal view returns (address) {
        return Currency.unwrap(poolKey.currency0);
    }

    function _token1() internal view returns (address) {
        return Currency.unwrap(poolKey.currency1);
    }
}
