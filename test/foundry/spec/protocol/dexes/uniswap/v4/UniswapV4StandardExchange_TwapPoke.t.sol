// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    TestBase_UniswapV4StandardExchange
} from "contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol";
import {
    IUniswapV4StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";
import {
    IUniswapV4StandardExchangeDFPkg,
    UniswapV4StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {
    UniswapV4_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol";
import {
    UniswapV4StandardExchangeCommon
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";

contract FlipTwapOracle {
    address public pm;

    function setPm(address pm_) external {
        pm = pm_;
    }

    function poolManager() external view returns (address) {
        return pm;
    }

    function update(PoolKey calldata) external pure returns (bool) {
        revert("hostile");
    }
}

contract UniswapV4SeTwapSeeder is IUnlockCallback {
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
 * @title UniswapV4StandardExchange_TwapPoke
 * @notice H14–H17, H27–H29 for Uni V4 SE canonical TWAP wiring and fail-open poke.
 */
contract UniswapV4StandardExchange_TwapPoke is TestBase_UniswapV4StandardExchange {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IStandardExchangeProxy internal vault;
    IUniswapV4StandardExchangeLiquidReserve internal liquid;
    PoolKey internal poolKey;
    UniswapV4SeTwapSeeder internal seeder;

    function setUp() public override {
        super.setUp();
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
        poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        poolManager.initialize(poolKey, TickMath.getSqrtPriceAtTick(0));
        seeder = new UniswapV4SeTwapSeeder(poolManager);
        tokenA.mint(address(seeder), 1_000_000 ether);
        tokenB.mint(address(seeder), 1_000_000 ether);
        int24 tickLower = TickMath.minUsableTick(60);
        int24 tickUpper = TickMath.maxUsableTick(60);
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

    function test_H14_vaultTwapOracleAndZapPokesBoundPool() public {
        assertEq(address(liquid.twapOracle()), address(twapOracle));
        assertEq(twapOracle.poolManager(), address(poolManager));
        (, uint16 cardBefore,,,) = twapOracle.getState(poolKey.toId());
        assertEq(cardBefore, 0);
        _zapIn(_token0(), 10 ether);
        (, uint16 cardAfter,,,) = twapOracle.getState(poolKey.toId());
        assertEq(cardAfter, 1);
    }

    function test_H15_firstWriterMatchesPostTradeTick() public {
        _zapIn(_token0(), 50 ether);
        (, int24 spot,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        (,,, int24 recorded,) = twapOracle.getState(poolKey.toId());
        IUniswapV4MultiPoolTwapOracle.Observation memory obs = twapOracle.getObservation(poolKey.toId(), 0);
        assertEq(recorded, spot);
        assertEq(obs.prevTick, spot);
        assertEq(obs.tickCumulative, 0);
    }

    function test_H16_pokeRevertFailOpen() public {
        bytes4 sel = bytes4(keccak256("update((address,address,uint24,int24,address))"));
        vm.mockCallRevert(address(twapOracle), abi.encodeWithSelector(sel), "hostile");
        uint256 amountIn = 5 ether;
        ERC20PermitMintableStub(_token0()).mint(address(this), amountIn);
        IERC20(_token0()).approve(address(vault), amountIn);
        vm.expectEmit(false, false, false, true, address(vault));
        emit UniswapV4StandardExchangeCommon.TwapOracleUpdateFailed(PoolId.unwrap(poolKey.toId()), bytes("hostile"));
        uint256 shares = vault.exchangeIn(
            IERC20(_token0()), amountIn, IERC20(address(vault)), 0, address(this), false, block.timestamp + 1 hours
        );
        assertGt(shares, 0);
        vm.clearMockedCalls();
    }

    function test_H17_transferDoesNotPokeAndForeignUpdateWrites() public {
        PoolKey memory foreign = PoolKey({
            currency0: poolKey.currency0,
            currency1: poolKey.currency1,
            fee: 10_000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        poolManager.initialize(foreign, TickMath.getSqrtPriceAtTick(0));
        (, uint16 foreignBefore,,,) = twapOracle.getState(foreign.toId());
        assertEq(foreignBefore, 0);

        uint256 shares = _zapIn(_token0(), 10 ether);
        (, uint16 card,, uint32 ts) = _state();
        (, uint16 foreignAfterZap,,,) = twapOracle.getState(foreign.toId());
        assertEq(foreignAfterZap, 0, "zap must not poke a second PoolKey");

        vault.approve(address(1), shares / 2);
        vault.transfer(address(1), shares / 2);
        (, uint16 card2,, uint32 ts2) = _state();
        assertEq(card2, card);
        assertEq(ts2, ts);

        liquid.rebalanceLiquidReserve();
        (, uint16 foreignAfterRebalance,,,) = twapOracle.getState(foreign.toId());
        assertEq(foreignAfterRebalance, 0, "rebalance must not poke a second PoolKey");

        assertTrue(twapOracle.update(foreign));
        (, uint16 foreignCard,,,) = twapOracle.getState(foreign.toId());
        assertEq(foreignCard, 1);
        (, uint16 boundCard,,,) = twapOracle.getState(poolKey.toId());
        assertEq(boundCard, card);
    }

    function test_H27_everyVaultSharesPackageOracle() public {
        IStandardExchangeProxy vault2 =
            IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey, 60));
        IUniswapV4StandardExchangeLiquidReserve liquid2 =
            IUniswapV4StandardExchangeLiquidReserve(address(vault2));
        assertEq(address(liquid.twapOracle()), address(twapOracle));
        assertEq(address(liquid2.twapOracle()), address(twapOracle));
        assertEq(liquid.twapOracle().poolManager(), address(poolManager));
        assertEq(liquid2.twapOracle().poolManager(), address(poolManager));
    }

    function test_H29_constructZeroOrMismatchReverts() public {
        IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit = _copyPkgInit();
        pkgInit.twapOracle = IUniswapV4MultiPoolTwapOracle(address(0));
        vm.expectRevert(IUniswapV4StandardExchangeDFPkg.ZeroTwapOracle.selector);
        new UniswapV4StandardExchangeDFPkg(pkgInit);

        FlipTwapOracle flip = new FlipTwapOracle();
        flip.setPm(address(uint160(address(poolManager)) + 1));
        pkgInit = _copyPkgInit();
        pkgInit.twapOracle = IUniswapV4MultiPoolTwapOracle(address(flip));
        vm.expectRevert(IUniswapV4StandardExchangeDFPkg.TwapOraclePoolManagerMismatch.selector);
        new UniswapV4StandardExchangeDFPkg(pkgInit);
    }

    function test_H28_deployVaultRevertsOnPmMismatch() public {
        FlipTwapOracle flip = new FlipTwapOracle();
        flip.setPm(address(poolManager));
        IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit = _copyPkgInit();
        pkgInit.twapOracle = IUniswapV4MultiPoolTwapOracle(address(flip));
        vm.startPrank(owner);
        IUniswapV4StandardExchangeDFPkg hostilePkg = IUniswapV4StandardExchangeDFPkg(
            address(
                IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
                    type(UniswapV4StandardExchangeDFPkg).creationCode,
                    abi.encode(pkgInit),
                    keccak256("UniswapV4StandardExchangeDFPkg.hostileTwap")
                )
            )
        );
        vm.stopPrank();
        flip.setPm(address(uint160(address(poolManager)) + 1));
        vm.expectRevert(IUniswapV4StandardExchangeDFPkg.TwapOraclePoolManagerMismatch.selector);
        hostilePkg.deployVault(poolKey, 60);
    }

    function _copyPkgInit() internal view returns (IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit) {
        pkgInit = UniswapV4_Component_FactoryService.buildArgsUniswapV4StandardExchangePkgInit(_univ4SePkgInitCore());
        pkgInit = UniswapV4_Component_FactoryService.attachTwapOracle(pkgInit, twapOracle);
        pkgInit = UniswapV4_Component_FactoryService.attachUniswapV4StandardExchangeMultiFacets(
            pkgInit,
            uniswapV4StandardExchangeInMultiFacet,
            uniswapV4StandardExchangeInMultiQueryFacet,
            uniswapV4StandardExchangeOutMultiFacet,
            uniswapV4StandardExchangeOutMultiQueryFacet
        );
    }

    function _zapIn(address token, uint256 amountIn) internal returns (uint256 shares) {
        ERC20PermitMintableStub(token).mint(address(this), amountIn);
        IERC20(token).approve(address(vault), amountIn);
        shares = vault.exchangeIn(
            IERC20(token), amountIn, IERC20(address(vault)), 0, address(this), false, block.timestamp + 1 hours
        );
        assertGt(shares, 0);
    }

    function _state()
        internal
        view
        returns (uint16 index, uint16 cardinality, uint16 cardinalityNext, uint32 lastTimestamp)
    {
        (index, cardinality, cardinalityNext,, lastTimestamp) = twapOracle.getState(poolKey.toId());
    }

    function _token0() internal view returns (address) {
        return Currency.unwrap(poolKey.currency0);
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
