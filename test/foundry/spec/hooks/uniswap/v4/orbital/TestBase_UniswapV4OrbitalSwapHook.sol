// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {
    IUniswapV4OrbitalSwapHook
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHook.sol";
import {
    IUniswapV4OrbitalSwapHookFactory
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHookFactory.sol";
import {
    UniswapV4OrbitalSwapHook_FactoryService as OrbitalFactoryService
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHook_FactoryService.sol";

/**
 * @title TestBase_UniswapV4OrbitalSwapHook
 * @notice Hermetic TestBase: production factory only (P1); real PM + fee oracle; mintable legs.
 */
abstract contract TestBase_UniswapV4OrbitalSwapHook is IndexedexTest {
    SimpleMintableERC20 internal token0;
    SimpleMintableERC20 internal token1;
    SimpleMintableERC20 internal token2;
    IPoolManager internal pm;
    IUniswapV4OrbitalSwapHookFactory internal factory;
    address internal hook;
    IUniswapV4OrbitalSwapHook internal orbital;
    PoolKey internal poolKey01;
    PoolKey internal poolKey12;
    PoolKey internal poolKey02;
    WrapperExactOutRouter internal swapRouter;

    address internal user = address(0xBEEF);
    address internal feeRecipient;

    uint256 internal constant FUND = 1_000_000 ether;

    function setUp() public virtual override {
        IndexedexTest.setUp();
        feeRecipient = address(feeCollector);

        token0 = new SimpleMintableERC20("Token0", "T0");
        token1 = new SimpleMintableERC20("Token1", "T1");
        token2 = new SimpleMintableERC20("Token2", "T2");

        // Ensure binding order addresses are distinct (SimpleMintable deploys sequentially).
        require(
            address(token0) != address(token1) && address(token1) != address(token2)
                && address(token0) != address(token2),
            "token addr"
        );

        pm = IPoolManager(address(new PoolManager(address(this))));

        factory = IUniswapV4OrbitalSwapHookFactory(
            OrbitalFactoryService.deployFactory(pm)
        );

        (bytes32 salt,) = OrbitalFactoryService.mineSalt(address(factory), address(this));
        (hook, poolKey01, poolKey12, poolKey02) = factory.deploy(
            IVaultFeeOracleQuery(address(indexedexManager)),
            address(token0),
            address(token1),
            address(token2),
            salt,
            0,
            0
        );
        orbital = IUniswapV4OrbitalSwapHook(hook);

        swapRouter = new WrapperExactOutRouter(pm);

        token0.mint(user, FUND);
        token1.mint(user, FUND);
        token2.mint(user, FUND);
        vm.startPrank(user);
        token0.approve(hook, type(uint256).max);
        token1.approve(hook, type(uint256).max);
        token2.approve(hook, type(uint256).max);
        token0.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);
        token2.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _addLiquidity(uint256 a0, uint256 a1, uint256 a2)
        internal
        returns (uint256 shares, uint256 u0, uint256 u1, uint256 u2)
    {
        vm.prank(user);
        return orbital.addLiquidity(a0, a1, a2, user, 0, block.timestamp + 1 hours, "");
    }

    function _seedThreeLeg(uint256 amount)
        internal
        returns (uint256 shares)
    {
        (shares,,,) = _addLiquidity(amount, amount, amount);
    }

    function _setDexFee(uint256 feeWad) internal {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(hook, feeWad);
    }

    function _setUsageFee(uint256 feeWad) internal {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(hook, feeWad);
    }

    function _sqrtLimit(bool zeroForOne) internal pure returns (uint160) {
        return zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
    }

    function _poolKeyFor(address a, address b) internal view returns (PoolKey memory key) {
        (address c0, address c1) = a < b ? (a, b) : (b, a);
        key = PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
    }

    function _swapExactIn(address tokenIn, address tokenOut, uint256 amountIn) internal {
        PoolKey memory key = _poolKeyFor(tokenIn, tokenOut);
        bool zeroForOne = tokenIn == Currency.unwrap(key.currency0);
        vm.prank(user);
        swapRouter.swapExactIn(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: _sqrtLimit(zeroForOne)
            }),
            ""
        );
    }
}
