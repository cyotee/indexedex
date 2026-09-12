// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
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
import {TestBase_UniswapV4SingleStandardExchangeBufferHook_Decimals as TestBase} from
    "contracts/hooks/uniswap/v4/standardExchange/single/TestBase_UniswapV4SingleStandardExchangeBufferHook_Decimals.sol";

/**
 * @title UniswapV4SingleSEBufferHook_Decimals
 * @notice Wrap/unwrap money-paths on combo `_pairDecimals()`. vaultShare / hook LP stay 18.
 * @dev Pair amounts use `_uPair`. Unwrap `seIn` / wrapExactOut `seOut` stay 18-dec wads.
 *      C1/C2/C3 keep a gold-identical 18-dec hostile pair (ReentrantMockERC20).
 *      After PoolKey sort, pairToken is still the configured-decimal wrap face.
 */
abstract contract UniswapV4SingleSEBufferHook_Decimals is TestBase {
    ReentrantMockERC20 internal hostilePair;
    address internal hostileSe;
    address internal hostileHook;
    IHook internal hostileBuffer;
    PoolKey internal hostileKey;
    WrapperExactOutRouter internal hostileRouter;

    function setUp() public virtual override {
        super.setUp();
        _initPool();
    }

    function test_HS1_wrapExactIn_previewEqualsExecution() public {
        _wrapExactIn(_uPair(10));
        _assertHookFlat();
    }

    function test_HS2_unwrapExactIn_previewEqualsExecution() public {
        _unwrapExactIn(5 ether);
        _assertHookFlat();
    }

    function test_HS3_wrapExactOut_previewEqualsExecution() public {
        _wrapExactOut(3 ether);
        _assertHookFlat();
    }

    function test_HS4_unwrapExactOut_previewEqualsExecution() public {
        _unwrapExactOut(_uPair(2));
        _assertHookFlat();
    }

    function test_HS7_wrapWithUsageFee_previewEqualsExec_feeToMints_noHookFee() public {
        address feeTo = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        require(feeTo != address(0), "feeTo");
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 0.01e18);

        uint256 amountIn = _uPair(10);
        uint256 preview = buffer.previewWrap(amountIn);
        assertGt(preview, 0, "preview");

        bool zfo = _isWrapZFO();
        uint256 feeBefore = IERC20(se).balanceOf(feeTo);
        uint256 seBefore = IERC20(se).balanceOf(user);
        uint256 hookPairBefore = pairToken.balanceOf(hook);
        uint256 hookSeBefore = IERC20(se).balanceOf(hook);

        vm.prank(user);
        swapRouter.swapExactIn(
            poolKey,
            SwapParams({zeroForOne: zfo, amountSpecified: -int256(amountIn), sqrtPriceLimitX96: _sqrtLimit(zfo)}),
            ""
        );
        assertEq(IERC20(se).balanceOf(user) - seBefore, preview, "user gets preview");
        assertEq(IERC20(se).balanceOf(feeTo) - feeBefore, preview / 100, "SE fee to feeTo");
        assertEq(pairToken.balanceOf(hook), hookPairBefore, "no hook pair fee");
        assertEq(IERC20(se).balanceOf(hook), hookSeBefore, "no hook SE fee");
    }

    function test_flat_afterWrapUnwrap() public {
        _wrapExactIn(_uPair(10));
        _assertHookFlat();
        _unwrapExactIn(4 ether);
        _assertHookFlat();
        _wrapExactOut(2 ether);
        _assertHookFlat();
        _unwrapExactOut(_uPair(1));
        _assertHookFlat();
    }

    /// @notice A1: donate pairToken — wrap still SE-previewed; no free SE from donation.
    function test_A1_pairDonation_doesNotMintFreeSE() public {
        pairToken.mint(address(this), _uPair(100));
        pairToken.transfer(hook, _uPair(50));
        uint256 donated = pairToken.balanceOf(hook);
        assertEq(donated, _uPair(50));

        uint256 amountIn = _uPair(10);
        uint256 preview = buffer.previewWrap(amountIn);
        uint256 seBefore = IERC20(se).balanceOf(user);
        _wrapExactIn(amountIn);
        assertEq(IERC20(se).balanceOf(user) - seBefore, preview, "no free SE from donation");
        assertEq(pairToken.balanceOf(hook), donated, "donation idle OK");
    }

    /// @notice A2: donate SE shares — unwrap not credited free pair from idle SE.
    function test_A2_seDonation_doesNotCreditFreeUnwrap() public {
        pairToken.mint(address(this), _uPair(100));
        pairToken.approve(se, type(uint256).max);
        uint256 seGot = IERC20(se).balanceOf(address(this));
        IStandardExchangeIn(se).exchangeIn(
            IERC20(address(pairToken)), _uPair(50), IERC20(se), 0, address(this), false, block.timestamp
        );
        uint256 seAmt = IERC20(se).balanceOf(address(this)) - seGot;
        IERC20(se).transfer(hook, seAmt);
        uint256 donated = IERC20(se).balanceOf(hook);
        assertGt(donated, 0);

        uint256 seIn = 5 ether;
        uint256 preview = buffer.previewUnwrap(seIn);
        uint256 pairBefore = pairToken.balanceOf(user);
        _unwrapExactIn(seIn);
        assertEq(pairToken.balanceOf(user) - pairBefore, preview, "no free pair from SE donation");
        assertEq(IERC20(se).balanceOf(hook), donated, "SE donation idle OK");
    }

    /// @notice A3: donate then swap — idle stuck OK; not credited into swap accounting.
    function test_A3_donateThenSwap_idleNotCredited() public {
        pairToken.mint(address(this), _uPair(20));
        pairToken.transfer(hook, _uPair(20));
        uint256 pairDonated = pairToken.balanceOf(hook);

        _wrapExactIn(_uPair(5));
        _unwrapExactIn(2 ether);

        assertEq(pairToken.balanceOf(hook), pairDonated, "pair donation untouched by swaps");
    }

    function _setUpHostile() internal {
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
        _ensureProductDoorsAndFinalize(hostileHook, address(hostilePair), hostileSe);
        hostileBuffer = IHook(hostileHook);
        hostileRouter = new WrapperExactOutRouter(pm);

        hostileKey = PoolKey({
            currency0: Currency.wrap(hostileBuffer.currency0()),
            currency1: Currency.wrap(hostileBuffer.currency1()),
            fee: 0,
            tickSpacing: 60,
            hooks: IHooks(hostileHook)
        });

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
    /// @dev Gold-identical 18-dec ReentrantMockERC20; combo decimals stay on HS/A paths.
    function test_C1_hostilePair_reenterOnWrap() public {
        _setUpHostile();
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
            assertEq(hostilePair.balanceOf(hostileHook), pairHookBefore, "flat pair");
            assertEq(IERC20(hostileSe).balanceOf(hostileHook), seHookBefore, "flat se");
            assertEq(IERC20(hostileSe).balanceOf(user) - seBefore, preview, "no double SE credit");
        } catch {
            assertEq(hostilePair.balanceOf(hostileHook), pairHookBefore, "revert clean pair");
            assertEq(IERC20(hostileSe).balanceOf(hostileHook), seHookBefore, "revert clean se");
            assertEq(IERC20(hostileSe).balanceOf(user), seBefore, "user SE unchanged");
        }
    }

    /// @notice C2: hostile reenter on unwrap path via V4 router (hook path).
    function test_C2_hostilePair_reenterOnUnwrap() public {
        _setUpHostile();
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
        _setUpHostile();
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
            assertEq(hostilePair.balanceOf(hostileHook), pairHookBefore, "flat pair residual");
            assertEq(IERC20(hostileSe).balanceOf(hostileHook), seHookBefore, "flat se residual");
            assertEq(
                IERC20(hostileSe).balanceOf(user) - seBefore,
                preview,
                "no double SE credit from nested reentry"
            );
        } catch {
            assertEq(hostilePair.balanceOf(hostileHook), pairHookBefore, "reverted clean pair");
            assertEq(IERC20(hostileSe).balanceOf(hostileHook), seHookBefore, "reverted clean se");
            assertEq(IERC20(hostileSe).balanceOf(user), seBefore, "user SE unchanged on full revert");
        }
    }
}
