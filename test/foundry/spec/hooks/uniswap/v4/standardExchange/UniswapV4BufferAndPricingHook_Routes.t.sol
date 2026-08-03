// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SwapParams, ModifyLiquidityParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {TestBase_ERC4626MorphoHermetic} from
    "contracts/test/bases/TestBase_ERC4626MorphoHermetic.sol";
import {IUniswapV4BufferAndPricingHook} from
    "contracts/hooks/uniswap/v4/standardExchange/interfaces/IUniswapV4BufferAndPricingHook.sol";
import {
    UniswapV4BufferAndPricingHook_FactoryService
} from "contracts/hooks/uniswap/v4/standardExchange/UniswapV4BufferAndPricingHook_FactoryService.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {
    PoolModifyLiquidityTest
} from "@crane/contracts/protocols/dexes/uniswap/v4/hooks/public/dependencies/v4-core/test/PoolModifyLiquidityTest.sol";

/**
 * @title UniswapV4BufferAndPricingHook_Routes_Test
 * @notice Hermetic Morpho MetaMorpho SE + real V4 PM: all four wrap/unwrap exact-in AND exact-out
 *         swap paths (positive amountSpecified for exact-out), fees, interest, add-liquidity guard.
 */
contract UniswapV4BufferAndPricingHook_Routes_Test is TestBase_ERC4626MorphoHermetic {
    IPoolManager internal pm;
    address internal hook;
    WrapperExactOutRouter internal swapRouter;
    PoolModifyLiquidityTest internal liqRouter;
    PoolKey internal poolKey;
    address internal user = address(0xBEEF);

    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    function setUp() public override {
        TestBase_ERC4626MorphoHermetic.setUp();

        // Seed Morpho vault liquidity so SE wrap deposits into Morpho market
        _seedMorphoVaultLiquidity(500_000 ether);

        pm = IPoolManager(
            vm.deployCode(
                "lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:PoolManager",
                abi.encode(address(this))
            )
        );
        swapRouter = new WrapperExactOutRouter(pm);
        liqRouter = new PoolModifyLiquidityTest(pm);

        hook = UniswapV4BufferAndPricingHook_FactoryService.deployHook(
            create3Factory, pm, se, address(loanToken)
        );

        (Currency c0, Currency c1) = address(loanToken) < se
            ? (Currency.wrap(address(loanToken)), Currency.wrap(se))
            : (Currency.wrap(se), Currency.wrap(address(loanToken)));

        poolKey = PoolKey({
            currency0: c0,
            currency1: c1,
            fee: 0,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
        pm.initialize(poolKey, SQRT_PRICE_1_1);

        // Fund user, seed SE shares via wrap
        _mintLoan(user, 1_000_000 ether);
        vm.startPrank(user);
        loanToken.approve(se, type(uint256).max);
        loanToken.approve(address(swapRouter), type(uint256).max);
        IStandardExchangeIn(se).exchangeIn(
            IERC20(address(loanToken)),
            200 ether,
            IERC20(se),
            0,
            user,
            false,
            block.timestamp
        );
        IERC20(se).approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _isWrapZFO() internal view returns (bool) {
        return address(loanToken) < se;
    }

    function _sqrtLimit(bool zeroForOne) internal pure returns (uint160) {
        return zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
    }

    /* ---------------------------------------------------------------------- */
    /*                         Four-route V4 swaps                            */
    /* ---------------------------------------------------------------------- */

    function test_HS1_wrapExactIn_previewEqualsExecution() public {
        uint256 amountIn = 10 ether;
        uint256 preview = IUniswapV4BufferAndPricingHook(hook).previewWrap(amountIn);
        bool zfo = _isWrapZFO();
        uint256 seBefore = IERC20(se).balanceOf(user);

        vm.prank(user);
        swapRouter.swapExactIn(
            poolKey,
            SwapParams({zeroForOne: zfo, amountSpecified: -int256(amountIn), sqrtPriceLimitX96: _sqrtLimit(zfo)}),
            ""
        );
        assertEq(IERC20(se).balanceOf(user) - seBefore, preview, "wrap exact-in");
    }

    function test_HS2_unwrapExactIn_previewEqualsExecution() public {
        uint256 seIn = 5 ether;
        uint256 preview = IUniswapV4BufferAndPricingHook(hook).previewUnwrap(seIn);
        bool zfo = !_isWrapZFO(); // unwrap opposite of wrap
        uint256 uBefore = loanToken.balanceOf(user);

        vm.prank(user);
        swapRouter.swapExactIn(
            poolKey,
            SwapParams({zeroForOne: zfo, amountSpecified: -int256(seIn), sqrtPriceLimitX96: _sqrtLimit(zfo)}),
            ""
        );
        assertEq(loanToken.balanceOf(user) - uBefore, preview, "unwrap exact-in");
    }

    function test_HS3_wrapExactOut_positiveAmountSpecified() public {
        uint256 seOut = 3 ether;
        uint256 amountIn = IUniswapV4BufferAndPricingHook(hook).previewWrapExactOut(seOut);
        assertGt(amountIn, 0);
        bool zfo = _isWrapZFO();
        uint256 seBefore = IERC20(se).balanceOf(user);
        uint256 uBefore = loanToken.balanceOf(user);

        // Positive amountSpecified → enters _wrapExactOut on Target
        vm.prank(user);
        swapRouter.swapExactOut(
            poolKey,
            SwapParams({
                zeroForOne: zfo,
                amountSpecified: int256(seOut),
                sqrtPriceLimitX96: _sqrtLimit(zfo)
            }),
            amountIn, // maxIn = exact preview (tight)
            ""
        );
        assertEq(IERC20(se).balanceOf(user) - seBefore, seOut, "exact SE out");
        assertEq(uBefore - loanToken.balanceOf(user), amountIn, "spend == preview");
    }

    function test_HS4_unwrapExactOut_positiveAmountSpecified() public {
        uint256 uOut = 2 ether;
        uint256 seIn = IUniswapV4BufferAndPricingHook(hook).previewUnwrapExactOut(uOut);
        assertGt(seIn, 0);
        bool zfo = !_isWrapZFO();
        uint256 seBefore = IERC20(se).balanceOf(user);
        uint256 uBefore = loanToken.balanceOf(user);

        // Positive amountSpecified → enters _unwrapExactOut on Target
        vm.prank(user);
        swapRouter.swapExactOut(
            poolKey,
            SwapParams({
                zeroForOne: zfo,
                amountSpecified: int256(uOut),
                sqrtPriceLimitX96: _sqrtLimit(zfo)
            }),
            seIn,
            ""
        );
        assertEq(seBefore - IERC20(se).balanceOf(user), seIn, "burn == preview seIn");
        assertEq(loanToken.balanceOf(user) - uBefore, uOut, "exact underlying out");
    }

    function test_HS5_wrongFeeInit_reverts() public {
        PoolKey memory bad = poolKey;
        bad.fee = 3000;
        vm.expectRevert();
        pm.initialize(bad, SQRT_PRICE_1_1);
    }

    function test_HS6_addLiquidity_revertsLiquidityNotAllowed() public {
        // beforeAddLiquidity always reverts LiquidityNotAllowed
        vm.expectRevert();
        liqRouter.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 1e18,
                salt: bytes32(0)
            }),
            ""
        );
    }

    function test_HS7_wrapWithUsageFee_userFullShares() public {
        address feeTo = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 0.01e18);

        uint256 amountIn = 10 ether;
        uint256 preview = IUniswapV4BufferAndPricingHook(hook).previewWrap(amountIn);
        bool zfo = _isWrapZFO();
        uint256 feeBefore = IERC20(se).balanceOf(feeTo);
        uint256 seBefore = IERC20(se).balanceOf(user);

        vm.prank(user);
        swapRouter.swapExactIn(
            poolKey,
            SwapParams({zeroForOne: zfo, amountSpecified: -int256(amountIn), sqrtPriceLimitX96: _sqrtLimit(zfo)}),
            ""
        );
        assertEq(IERC20(se).balanceOf(user) - seBefore, preview);
        assertEq(IERC20(se).balanceOf(feeTo) - feeBefore, preview / 100);
    }

    function test_H_DoD_morphoInterestStrictIncrease() public {
        uint256 seAmt = 10 ether;
        uint256 beforeOut = IUniswapV4BufferAndPricingHook(hook).previewUnwrap(seAmt);

        // Real Morpho borrow + time + accrueInterest (not claim-growth cheats)
        _accrueMorphoInterest();

        uint256 afterOut = IUniswapV4BufferAndPricingHook(hook).previewUnwrap(seAmt);
        assertGt(afterOut, beforeOut, "strict increase after Morpho interest");
    }

    /// @dev Hook must not retain free underlying after unwrap exact-out (settle actual got).
    function test_Hook_unwrapExactOut_noIdleUnderlyingOnHook() public {
        uint256 uOut = 2 ether;
        uint256 seIn = IUniswapV4BufferAndPricingHook(hook).previewUnwrapExactOut(uOut);
        bool zfo = !_isWrapZFO();

        vm.prank(user);
        swapRouter.swapExactOut(
            poolKey,
            SwapParams({
                zeroForOne: zfo,
                amountSpecified: int256(uOut),
                sqrtPriceLimitX96: _sqrtLimit(zfo)
            }),
            seIn,
            ""
        );
        assertEq(loanToken.balanceOf(hook), 0, "hook must not retain underlying inventory");
        assertEq(IERC20(se).balanceOf(hook), 0, "hook must not retain SE inventory");
    }
}
