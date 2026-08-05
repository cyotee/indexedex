// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {ReentrantMockERC20} from "contracts/test/stubs/ReentrantMockERC20.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {
    UniswapV4SingleStandardExchangeBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHook_FactoryService.sol";
import {
    IUniswapV4SingleStandardExchangeBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHookPackage.sol";
import {
    IUniswapV4SingleStandardExchangeBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHook.sol";
import {
    TestBase_UniswapV4SingleSEBufferHook_Adversarial as AdvBase
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/adversarial/TestBase_UniswapV4SingleSEBufferHook_Adversarial.sol";

/**
 * @notice C1/C2/C3: reentrancy via hostile pairToken on wrap/unwrap / SE paths.
 */
contract Adversarial_Reentrancy_Test is AdvBase {
    ReentrantMockERC20 internal hostilePair;
    address internal hostileSe;
    address internal hostileHook;
    IHook internal hostileBuffer;
    PoolKey internal hostileKey;
    WrapperExactOutRouter internal hostileRouter;

    function setUp() public override {
        super.setUp();

        hostilePair = new ReentrantMockERC20("Hostile", "HOST", 18);
        protocolVault = _deployCraneErc4626(address(hostilePair));
        hostileSe = _deployERC4626SE(address(protocolVault));

        IUniswapV4SingleStandardExchangeBufferHookPackage.PkgArgs memory args =
            IUniswapV4SingleStandardExchangeBufferHookPackage.PkgArgs({
                poolManager: address(pm),
                standardExchange: hostileSe,
                pairToken: address(hostilePair)
            });
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        hostileHook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        hostileBuffer = IHook(hostileHook);
        hostileRouter = new WrapperExactOutRouter(pm);

        hostileKey = PoolKey({
            currency0: Currency.wrap(hostileBuffer.currency0()),
            currency1: Currency.wrap(hostileBuffer.currency1()),
            fee: 0,
            tickSpacing: 60,
            hooks: IHooks(hostileHook)
        });
        pm.initialize(hostileKey, SQRT_PRICE_1_1);

        hostilePair.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        hostilePair.approve(hostileSe, type(uint256).max);
        hostilePair.approve(address(hostileRouter), type(uint256).max);
        IStandardExchangeIn(hostileSe).exchangeIn(
            IERC20(address(hostilePair)),
            200 ether,
            IERC20(hostileSe),
            0,
            user,
            false,
            block.timestamp
        );
        IERC20(hostileSe).approve(address(hostileRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _hostileSqrt(bool zfo) internal pure returns (uint160) {
        return zfo ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
    }

    /// @notice C1: hostile pairToken reenters mid-wrap via V4 router (hook path).
    function test_C1_hostilePair_reenterOnWrap() public {
        hostilePair.arm(
            address(hostileSe),
            abi.encodeWithSelector(
                IStandardExchangeIn.exchangeIn.selector,
                IERC20(address(hostilePair)),
                1 ether,
                IERC20(hostileSe),
                0,
                user,
                false,
                block.timestamp
            )
        );

        bool zfo = address(hostilePair) < hostileSe;
        uint256 seBefore = IERC20(hostileSe).balanceOf(user);
        uint256 pairHookBefore = hostilePair.balanceOf(hostileHook);
        uint256 seHookBefore = IERC20(hostileSe).balanceOf(hostileHook);
        uint256 preview = hostileBuffer.previewWrap(5 ether);

        vm.prank(user);
        try hostileRouter.swapExactIn(
            hostileKey,
            SwapParams({zeroForOne: zfo, amountSpecified: -int256(5 ether), sqrtPriceLimitX96: _hostileSqrt(zfo)}),
            ""
        ) {
            // Outer completed: hook flat; user SE credit == single preview (no double settle)
            assertEq(hostilePair.balanceOf(hostileHook), pairHookBefore, "flat pair");
            assertEq(IERC20(hostileSe).balanceOf(hostileHook), seHookBefore, "flat se");
            assertEq(IERC20(hostileSe).balanceOf(user) - seBefore, preview, "no double SE credit");
        } catch {
            // Nested lock forced full revert — clean residual, user unchanged
            assertEq(hostilePair.balanceOf(hostileHook), pairHookBefore, "revert clean pair");
            assertEq(IERC20(hostileSe).balanceOf(hostileHook), seHookBefore, "revert clean se");
            assertEq(IERC20(hostileSe).balanceOf(user), seBefore, "user SE unchanged");
        }
    }

    /// @notice C2: hostile reenter on unwrap path via V4 router (hook path).
    function test_C2_hostilePair_reenterOnUnwrap() public {
        // Nested reenter SE exchange during wrap-side token pull if any; on unwrap settle path arm SE reentry.
        hostilePair.arm(
            address(hostileSe),
            abi.encodeWithSelector(
                IStandardExchangeIn.exchangeIn.selector,
                IERC20(hostileSe),
                1 ether,
                IERC20(address(hostilePair)),
                0,
                user,
                false,
                block.timestamp
            )
        );

        bool zfo = !(address(hostilePair) < hostileSe);
        uint256 seIn = 3 ether;
        uint256 seBefore = IERC20(hostileSe).balanceOf(user);
        uint256 pairBefore = hostilePair.balanceOf(user);
        uint256 pairHookBefore = hostilePair.balanceOf(hostileHook);
        uint256 seHookBefore = IERC20(hostileSe).balanceOf(hostileHook);
        uint256 preview = hostileBuffer.previewUnwrap(seIn);

        vm.prank(user);
        try hostileRouter.swapExactIn(
            hostileKey,
            SwapParams({zeroForOne: zfo, amountSpecified: -int256(seIn), sqrtPriceLimitX96: _hostileSqrt(zfo)}),
            ""
        ) {
            assertEq(hostilePair.balanceOf(hostileHook), pairHookBefore, "flat pair");
            assertEq(IERC20(hostileSe).balanceOf(hostileHook), seHookBefore, "flat se");
            assertEq(seBefore - IERC20(hostileSe).balanceOf(user), seIn, "exact SE in");
            assertEq(hostilePair.balanceOf(user) - pairBefore, preview, "pair out == preview");
        } catch {
            assertEq(hostilePair.balanceOf(hostileHook), pairHookBefore, "revert clean pair");
            assertEq(IERC20(hostileSe).balanceOf(hostileHook), seHookBefore, "revert clean se");
            assertEq(IERC20(hostileSe).balanceOf(user), seBefore, "user SE unchanged");
        }
    }

    /// @notice C3: reenter SE exchangeIn from pair transferFrom mid hook wrap — no double settle.
    function test_C3_reenterSE_fromTokenCallback() public {
        // Drive real hook wrap: SE pulls pair via transferFrom → hostile reenters SE.exchangeIn.
        hostilePair.arm(
            address(hostileSe),
            abi.encodeWithSelector(
                IStandardExchangeIn.exchangeIn.selector,
                IERC20(address(hostilePair)),
                1 ether,
                IERC20(hostileSe),
                0,
                user,
                false,
                block.timestamp
            )
        );

        bool zfo = address(hostilePair) < hostileSe;
        uint256 amountIn = 5 ether;
        uint256 seBefore = IERC20(hostileSe).balanceOf(user);
        uint256 pairHookBefore = hostilePair.balanceOf(hostileHook);
        uint256 seHookBefore = IERC20(hostileSe).balanceOf(hostileHook);
        uint256 preview = hostileBuffer.previewWrap(amountIn);

        vm.prank(user);
        try hostileRouter.swapExactIn(
            hostileKey,
            SwapParams({
                zeroForOne: zfo,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: _hostileSqrt(zfo)
            }),
            ""
        ) {
            // Nested call did not strand inventory; user did not receive double SE credit
            assertEq(hostilePair.balanceOf(hostileHook), pairHookBefore, "flat pair residual");
            assertEq(IERC20(hostileSe).balanceOf(hostileHook), seHookBefore, "flat se residual");
            assertEq(
                IERC20(hostileSe).balanceOf(user) - seBefore,
                preview,
                "no double SE credit from nested reentry"
            );
        } catch {
            // SE/hook/PM lock aborted the whole swap — no stranded mid-swap inventory
            assertEq(hostilePair.balanceOf(hostileHook), pairHookBefore, "reverted clean pair");
            assertEq(IERC20(hostileSe).balanceOf(hostileHook), seHookBefore, "reverted clean se");
            assertEq(IERC20(hostileSe).balanceOf(user), seBefore, "user SE unchanged on full revert");
        }
    }
}
