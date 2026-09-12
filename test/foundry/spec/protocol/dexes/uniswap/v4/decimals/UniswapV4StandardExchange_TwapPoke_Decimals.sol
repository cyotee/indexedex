// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IUniswapV4StandardExchangeLiquidReserve} from
    "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";
import {
    IUniswapV4StandardExchangeDFPkg,
    UniswapV4StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {UniswapV4_Component_FactoryService} from
    "contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol";
import {UniswapV4StandardExchangeCommon} from
    "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol";
import {IUniswapV4MultiPoolTwapOracle} from
    "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {UniswapV4SeDecimalsHelpers} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4SeDecimalsHelpers.sol";
import {UniswapV4LiquiditySeeder_ProDexUniV4} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/harness/UniswapV4SeDecimalsPoolOps.sol";

contract FlipTwapOracleDecimals {
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

/**
 * @title UniswapV4StandardExchange_TwapPoke_Decimals
 * @notice H14–H17, H27–H29 on combo decimals. pairToken = tokenA. vaultShare stays 18.
 */
abstract contract UniswapV4StandardExchange_TwapPoke_Decimals is UniswapV4SeDecimalsHelpers {
    MintableERC20Decimals internal tokenA;
    MintableERC20Decimals internal tokenB;
    IStandardExchangeProxy internal vault;
    IUniswapV4StandardExchangeLiquidReserve internal liquid;
    PoolKey internal poolKey;
    UniswapV4LiquiditySeeder_ProDexUniV4 internal seeder;

    function _u0(uint256 human) internal view returns (uint256) {
        return _uOf(_token0(), human);
    }

    function setUp() public virtual override {
        super.setUp();
        tokenA = new MintableERC20Decimals("Token A", "TKNA", _tokenADecimals());
        tokenB = new MintableERC20Decimals("Token B", "TKNB", _tokenBDecimals());
        poolKey = _buildPoolKey(address(tokenA), address(tokenB));
        uint160 sqrtP = _oneToOneHumanSqrtPrice(_token0(), _token1());
        poolManager.initialize(poolKey, sqrtP);
        seeder = new UniswapV4LiquiditySeeder_ProDexUniV4(poolManager);
        tokenA.mint(address(seeder), _uA(1_000_000));
        tokenB.mint(address(seeder), _uB(1_000_000));
        int24 tickLower = TickMath.minUsableTick(60);
        int24 tickUpper = TickMath.maxUsableTick(60);
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
            sqrtP,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            _uOf(_token0(), 100_000),
            _uOf(_token1(), 100_000)
        );
        seeder.addLiquidity(poolKey, tickLower, tickUpper, liq);
        vault = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
        liquid = IUniswapV4StandardExchangeLiquidReserve(address(vault));
    }

    function test_H14_vaultTwapOracleAndZapPokesBoundPool() public {
        assertEq(address(liquid.twapOracle()), address(twapOracle));
        assertEq(twapOracle.poolManager(), address(poolManager));
        (, uint16 cardBefore,,,) = twapOracle.getState(poolKey.toId());
        assertEq(cardBefore, 0);
        _zapIn(_token0(), _u0(10));
        (, uint16 cardAfter,,,) = twapOracle.getState(poolKey.toId());
        assertEq(cardAfter, 1);
    }

    function test_H15_firstWriterMatchesPostTradeTick() public {
        _zapIn(_token0(), _u0(50));
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
        uint256 amountIn = _u0(5);
        (address[] memory tokens, uint256[] memory amounts) = _fundDualInput(_token0(), amountIn);
        vm.expectEmit(false, false, false, true, address(vault));
        emit UniswapV4StandardExchangeCommon.TwapOracleUpdateFailed(PoolId.unwrap(poolKey.toId()), bytes("hostile"));
        uint256 shares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 0, address(this), false, block.timestamp + 1 hours
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
        poolManager.initialize(foreign, _oneToOneHumanSqrtPrice(_token0(), _token1()));
        (, uint16 foreignBefore,,,) = twapOracle.getState(foreign.toId());
        assertEq(foreignBefore, 0);

        uint256 shares = _zapIn(_token0(), _u0(10));
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
        IStandardExchangeProxy vault2 = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
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

        FlipTwapOracleDecimals flip = new FlipTwapOracleDecimals();
        flip.setPm(address(uint160(address(poolManager)) + 1));
        pkgInit = _copyPkgInit();
        pkgInit.twapOracle = IUniswapV4MultiPoolTwapOracle(address(flip));
        vm.expectRevert(IUniswapV4StandardExchangeDFPkg.TwapOraclePoolManagerMismatch.selector);
        new UniswapV4StandardExchangeDFPkg(pkgInit);
    }

    function test_H28_deployVaultRevertsOnPmMismatch() public {
        FlipTwapOracleDecimals flip = new FlipTwapOracleDecimals();
        flip.setPm(address(poolManager));
        IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit = _copyPkgInit();
        pkgInit.twapOracle = IUniswapV4MultiPoolTwapOracle(address(flip));
        vm.startPrank(owner);
        IUniswapV4StandardExchangeDFPkg hostilePkg = IUniswapV4StandardExchangeDFPkg(
            address(
                IVaultRegistryDeployment(address(indexedexManager)).deployPkg(
                    type(UniswapV4StandardExchangeDFPkg).creationCode,
                    abi.encode(pkgInit),
                    keccak256("UniswapV4StandardExchangeDFPkg.hostileTwap.decimals")
                )
            )
        );
        vm.stopPrank();
        flip.setPm(address(uint160(address(poolManager)) + 1));
        vm.expectRevert(IUniswapV4StandardExchangeDFPkg.TwapOraclePoolManagerMismatch.selector);
        hostilePkg.deployVault(poolKey);
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

    function _fundDualInput(address token, uint256 amountIn)
        internal returns (address[] memory tokens, uint256[] memory amounts)
    {
        assertEq(token, _token0(), "TWAP fixture starts from token0");
        tokens = new address[](2);
        tokens[0] = _token0();
        tokens[1] = Currency.unwrap(poolKey.currency1);
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn * _uOf(Currency.unwrap(poolKey.currency1), 1) / _uOf(token, 1);
        for (uint256 i; i < 2; ++i) {
            MintableERC20Decimals(tokens[i]).mint(address(this), amounts[i]);
            IERC20(tokens[i]).approve(address(vault), amounts[i]);
        }
    }

    function _zapIn(address token, uint256 amountIn) internal returns (uint256 shares) {
        (address[] memory tokens, uint256[] memory amounts) = _fundDualInput(token, amountIn);
        shares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 0, address(this), false, block.timestamp + 1 hours
        );
        assertGt(shares, 0, "funded activation writes TWAP");
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

    function _token1() internal view returns (address) {
        return Currency.unwrap(poolKey.currency1);
    }
}
