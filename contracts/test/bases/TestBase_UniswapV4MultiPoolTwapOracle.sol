// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    IUniswapV4MultiPoolTwapOracleDFPkg
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracleDFPkg.sol";
import {
    UniswapV4TwapOracleFactoryService
} from "contracts/oracles/uniswap/v4/twap/UniswapV4TwapOracleFactoryService.sol";
import {
    UniswapV4TwapAdapterFactory
} from "contracts/oracles/uniswap/v4/twap/UniswapV4TwapAdapterFactory.sol";

contract UniswapV4TwapPoolHarness is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;

    IPoolManager public immutable poolManager;

    enum Op {
        AddLiquidity,
        Swap
    }

    constructor(IPoolManager poolManager_) {
        poolManager = poolManager_;
    }

    function addLiquidity(PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidity) external {
        poolManager.unlock(abi.encode(Op.AddLiquidity, abi.encode(poolKey, tickLower, tickUpper, liquidity)));
    }

    function swap(PoolKey memory poolKey, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96)
        external
        returns (BalanceDelta delta)
    {
        bytes memory result = poolManager.unlock(
            abi.encode(Op.Swap, abi.encode(poolKey, zeroForOne, amountSpecified, sqrtPriceLimitX96))
        );
        return abi.decode(result, (BalanceDelta));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "not pm");
        (Op op, bytes memory inner) = abi.decode(data, (Op, bytes));
        if (op == Op.AddLiquidity) {
            (PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidity) =
                abi.decode(inner, (PoolKey, int24, int24, uint128));
            (BalanceDelta callerDelta,) = poolManager.modifyLiquidity(
                poolKey,
                ModifyLiquidityParams({
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: int256(uint256(liquidity)),
                    salt: bytes32(0)
                }),
                bytes("")
            );
            _settle(poolKey.currency0, callerDelta.amount0());
            _settle(poolKey.currency1, callerDelta.amount1());
            return abi.encode(callerDelta);
        }
        (PoolKey memory swapKey, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96) =
            abi.decode(inner, (PoolKey, bool, int256, uint160));
        BalanceDelta swapDelta = poolManager.swap(
            swapKey,
            SwapParams({zeroForOne: zeroForOne, amountSpecified: amountSpecified, sqrtPriceLimitX96: sqrtPriceLimitX96}),
            bytes("")
        );
        _settle(swapKey.currency0, swapDelta.amount0());
        _settle(swapKey.currency1, swapDelta.amount1());
        return abi.encode(swapDelta);
    }

    function _settle(Currency currency, int128 delta) internal {
        if (delta < 0) {
            uint256 amount = uint128(-delta);
            if (Currency.unwrap(currency) == address(0)) {
                poolManager.sync(currency);
                poolManager.settle{value: amount}();
            } else {
                poolManager.sync(currency);
                IERC20(Currency.unwrap(currency)).transfer(address(poolManager), amount);
                poolManager.settle();
            }
        } else if (delta > 0) {
            poolManager.take(currency, address(this), uint128(delta));
        }
    }

    receive() external payable {}
}

contract UniswapV4TwapUnlockPokeHarness is IUnlockCallback {
    IPoolManager public immutable poolManager;
    IUniswapV4MultiPoolTwapOracle public oracle;
    PoolKey public key;
    bool public wasUnlocked;
    bool public written;

    constructor(IPoolManager poolManager_) {
        poolManager = poolManager_;
    }

    function pokeWhileUnlocked(IUniswapV4MultiPoolTwapOracle oracle_, PoolKey memory key_)
        external
        returns (bool written_)
    {
        oracle = oracle_;
        key = key_;
        bytes memory result = poolManager.unlock("");
        return abi.decode(result, (bool));
    }

    function unlockCallback(bytes calldata) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "not pm");
        wasUnlocked = TransientStateLibrary.isUnlocked(poolManager);
        written = oracle.update(key);
        return abi.encode(written);
    }
}

abstract contract TestBase_UniswapV4MultiPoolTwapOracle is IndexedexTest {
    using UniswapV4TwapOracleFactoryService for ICreate3FactoryProxy;

    uint24 internal constant DEFAULT_FEE = 3000;
    int24 internal constant DEFAULT_TICK_SPACING = 60;

    PoolManager internal poolManager;
    IFacet internal twapOracleFacet;
    IUniswapV4MultiPoolTwapOracleDFPkg internal twapOraclePkg;
    UniswapV4TwapAdapterFactory internal twapAdapterFactory;
    IUniswapV4MultiPoolTwapOracle internal twapOracle;
    UniswapV4TwapPoolHarness internal poolHarness;
    UniswapV4TwapUnlockPokeHarness internal unlockPokeHarness;
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    PoolKey internal poolKey;

    function setUp() public virtual override {
        IndexedexTest.setUp();

        poolManager = new PoolManager(address(this));
        vm.label(address(poolManager), "PoolManager");

        twapOracleFacet = create3Factory.deployUniswapV4MultiPoolTwapOracleFacet();
        twapOraclePkg =
            create3Factory.deployUniswapV4MultiPoolTwapOracleDFPkg(twapOracleFacet, diamondPackageFactory);
        twapAdapterFactory = create3Factory.deployUniswapV4TwapAdapterFactory();
        twapOracle = _deployOracle(poolManager);

        poolHarness = new UniswapV4TwapPoolHarness(poolManager);
        unlockPokeHarness = new UniswapV4TwapUnlockPokeHarness(poolManager);
        vm.deal(address(poolHarness), 10_000_000 ether);

        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 0);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 0);
        poolKey = _buildPoolKey(address(tokenA), address(tokenB));
    }

    function _deployOracle(IPoolManager pm) internal returns (IUniswapV4MultiPoolTwapOracle) {
        IUniswapV4MultiPoolTwapOracle instance = twapOraclePkg.deployOracle(
            IUniswapV4MultiPoolTwapOracleDFPkg.PkgArgs({poolManager: address(pm)})
        );
        vm.label(address(instance), "twapOracle");
        return instance;
    }

    function _buildPoolKey(address token0, address token1) internal pure returns (PoolKey memory) {
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }
        return PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: DEFAULT_FEE,
            tickSpacing: DEFAULT_TICK_SPACING,
            hooks: IHooks(address(0))
        });
    }

    function _initPool(IPoolManager pm, PoolKey memory key, uint160 sqrtPrice) internal {
        pm.initialize(key, sqrtPrice);
    }

    function _seedFullRange(PoolKey memory key, uint256 amount0, uint256 amount1) internal {
        address t0 = Currency.unwrap(key.currency0);
        address t1 = Currency.unwrap(key.currency1);
        if (t0 != address(0)) {
            ERC20PermitMintableStub(t0).mint(address(poolHarness), amount0);
        }
        ERC20PermitMintableStub(t1).mint(address(poolHarness), amount1);
        (uint160 sqrtPrice,,,) = StateLibrary.getSlot0(IPoolManager(address(poolManager)), key.toId());
        int24 tickLower = TickMath.minUsableTick(key.tickSpacing);
        int24 tickUpper = TickMath.maxUsableTick(key.tickSpacing);
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPrice,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            amount0,
            amount1
        );
        poolHarness.addLiquidity(key, tickLower, tickUpper, liq);
    }

    function _swapToTick(PoolKey memory key, int24 targetTick) internal {
        (uint160 sqrtPrice, int24 currentTick,,) =
            StateLibrary.getSlot0(IPoolManager(address(poolManager)), key.toId());
        if (currentTick == targetTick) {
            return;
        }
        bool zeroForOne = currentTick > targetTick;
        uint160 limit = TickMath.getSqrtPriceAtTick(targetTick);
        if (zeroForOne) {
            if (limit == sqrtPrice) return;
        }
        int256 amountSpecified = -int256(uint256(500_000_000 ether));
        poolHarness.swap(key, zeroForOne, amountSpecified, limit);
    }

    function _warp(uint256 seconds_) internal {
        vm.warp(block.timestamp + seconds_);
    }

    function _poke(PoolKey memory key) internal returns (bool written) {
        return twapOracle.update(key);
    }

    function _currentTick(PoolKey memory key) internal view returns (int24 tick) {
        (, tick,,) = StateLibrary.getSlot0(IPoolManager(address(poolManager)), key.toId());
    }
}
