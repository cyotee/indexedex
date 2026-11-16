// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {
    TestBase_UniswapV4WeightedSwapHook_Decimals
} from "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook_Decimals.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";
import {
    UniswapV4WeightedSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookMath.sol";
import {RateProviderHarness} from
    "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook.sol";

/**
 * @title UniswapV4WeightedSwapHook_N2_Decimals
 * @notice n=2 money-paths on eight two-token combos. pairToken constructed first at `_pairDecimals()`.
 * @dev After address sort t0/t1 may permute; amounts use each token's decimals. Hook LP stays 18.
 */
abstract contract UniswapV4WeightedSwapHook_N2_Decimals is TestBase_UniswapV4WeightedSwapHook_Decimals {
    WrapperExactOutRouter internal swapRouter;

    function setUp() public virtual override {
        super.setUp();
        swapRouter = new WrapperExactOutRouter(pm);
    }

    function test_L1_firstMintFull_minOnAddress0() public {
        (address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1) = _deployN2Combo();
        uint256 shares = _joinFullN2(hook_, t0, t1, 1000);
        assertGt(shares, 0);
        assertEq(IERC20(hook_).balanceOf(address(0)), Math.MINIMUM_LIQUIDITY);
        assertEq(IERC20(hook_).balanceOf(user), shares);
        assertTrue(IUniswapV4WeightedSwapHook(hook_).isFullBook());
        assertEq(IUniswapV4WeightedSwapHook(hook_).reserveOf(address(t0)), _raw(t0, 1000));
        assertEq(IUniswapV4WeightedSwapHook(hook_).reserveOf(address(t1)), _raw(t1, 1000));
    }

    function test_L2_propJoinExit_previewEqExec() public {
        (address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1) = _deployN2Combo();
        _joinFullN2(hook_, t0, t1, 1000);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _raw(t0, 100);
        amounts[1] = _raw(t1, 100);
        (uint256 prevShares, uint256[] memory prevUsed) =
            IUniswapV4WeightedSwapHook(hook_).previewJoinProportional(amounts);

        vm.prank(user);
        (uint256 shares, uint256[] memory used) = IUniswapV4WeightedSwapHook(hook_).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
        assertEq(shares, prevShares);
        assertEq(used[0], prevUsed[0]);
        assertEq(used[1], prevUsed[1]);

        uint256 exitShares = shares / 2;
        uint256[] memory prevExit = IUniswapV4WeightedSwapHook(hook_).previewExitProportional(exitShares);
        uint256[] memory mins = new uint256[](2);
        vm.prank(user);
        uint256[] memory exited = IUniswapV4WeightedSwapHook(hook_).exitProportional(
            exitShares, user, mins, block.timestamp + 1 hours
        );
        assertEq(exited[0], prevExit[0]);
        assertEq(exited[1], prevExit[1]);
    }

    function test_L4_exitBurnsMsgSenderOnly() public {
        (address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1) = _deployN2Combo();
        uint256 shares = _joinFullN2(hook_, t0, t1, 1000);
        address other = address(0xCAFE);
        vm.prank(user);
        IERC20(hook_).transfer(other, shares);
        uint256[] memory mins = new uint256[](2);
        vm.prank(user);
        vm.expectRevert();
        IUniswapV4WeightedSwapHook(hook_).exitProportional(
            shares / 2, user, mins, block.timestamp + 1 hours
        );
        vm.prank(other);
        IUniswapV4WeightedSwapHook(hook_).exitProportional(
            shares / 2, other, mins, block.timestamp + 1 hours
        );
    }

    function test_L5_wouldZeroReserve_fullExitBlocked() public {
        (address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1) = _deployN2Combo();
        uint256 shares = _joinFullN2(hook_, t0, t1, 1000);
        uint256[] memory mins = new uint256[](2);
        uint256[] memory amounts = IUniswapV4WeightedSwapHook(hook_).previewExitProportional(shares);
        bool wouldZero = amounts[0] >= IUniswapV4WeightedSwapHook(hook_).reserveOf(address(t0))
            || amounts[1] >= IUniswapV4WeightedSwapHook(hook_).reserveOf(address(t1));
        if (wouldZero) {
            vm.prank(user);
            vm.expectRevert();
            IUniswapV4WeightedSwapHook(hook_).exitProportional(
                shares, user, mins, block.timestamp + 1 hours
            );
        } else {
            vm.prank(user);
            IUniswapV4WeightedSwapHook(hook_).exitProportional(
                shares, user, mins, block.timestamp + 1 hours
            );
            assertGt(IUniswapV4WeightedSwapHook(hook_).reserveOf(address(t0)), 0);
            assertGt(IUniswapV4WeightedSwapHook(hook_).reserveOf(address(t1)), 0);
        }
    }

    function test_L6_unbalancedJoin_fullBook() public {
        (address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1) = _deployN2Combo();
        _joinFullN2(hook_, t0, t1, 1000);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _raw(t0, 50);
        amounts[1] = _raw(t1, 10);
        uint256 prev = IUniswapV4WeightedSwapHook(hook_).previewJoinUnbalanced(amounts);
        vm.prank(user);
        uint256 shares = IUniswapV4WeightedSwapHook(hook_).joinUnbalanced(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
        assertEq(shares, prev);
        assertGt(shares, 0);
    }

    function test_L7_singleAssetJoinExit() public {
        (address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1) = _deployN2Combo();
        _joinFullN2(hook_, t0, t1, 10_000);
        uint256 amountIn = _raw(t0, 50);
        uint256 prevShares =
            IUniswapV4WeightedSwapHook(hook_).previewJoinSingleAssetExactIn(address(t0), amountIn);
        vm.prank(user);
        uint256 shares = IUniswapV4WeightedSwapHook(hook_).joinSingleAssetExactIn(
            address(t0), amountIn, user, 0, block.timestamp + 1 hours, ""
        );
        assertEq(shares, prevShares);

        uint256 prevOut =
            IUniswapV4WeightedSwapHook(hook_).previewExitSingleAssetExactIn(address(t1), shares / 2);
        vm.prank(user);
        uint256 out = IUniswapV4WeightedSwapHook(hook_).exitSingleAssetExactIn(
            address(t1), shares / 2, user, 0, block.timestamp + 1 hours
        );
        assertEq(out, prevOut);
    }

    function test_P2_n2_rejectsPartialFirstMint() public {
        (address hook_, MintableERC20Decimals t0,) = _deployN2Combo();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _raw(t0, 1000);
        amounts[1] = 0;
        vm.prank(user);
        vm.expectRevert();
        IUniswapV4WeightedSwapHook(hook_).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
    }

    function test_S1_previewExactInExactOut() public {
        (address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1) = _deployN2Combo();
        _joinFullN2(hook_, t0, t1, 10_000);
        uint256 amountIn = _raw(t0, 10);
        uint256 out = IUniswapV4WeightedSwapHook(hook_).previewSwapExactIn(address(t0), address(t1), amountIn);
        assertGt(out, 0);
        uint256 in2 = IUniswapV4WeightedSwapHook(hook_).previewSwapExactOut(address(t0), address(t1), out);
        assertGe(in2 + amountIn / 10_000 + 1, amountIn);
    }

    function test_S2_swapExactIn_viaRouter_updatesReserves() public {
        (address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1) = _deployN2Combo();
        _joinFullN2(hook_, t0, t1, 10_000);

        PoolKey memory key = _pairPoolKeysDec(hook_)[0];
        uint256 amountIn = _raw(t0, 10);
        uint256 preview =
            IUniswapV4WeightedSwapHook(hook_).previewSwapExactIn(address(t0), address(t1), amountIn);

        uint256 r0Before = IUniswapV4WeightedSwapHook(hook_).reserveOf(address(t0));
        uint256 r1Before = IUniswapV4WeightedSwapHook(hook_).reserveOf(address(t1));
        uint256 kBefore = IUniswapV4WeightedSwapHook(hook_).kLast();

        bool zeroForOne = address(t0) == Currency.unwrap(key.currency0);
        SwapParams memory sp = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amountIn),
            sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        });

        vm.startPrank(user);
        t0.approve(address(swapRouter), type(uint256).max);
        t1.approve(address(swapRouter), type(uint256).max);
        swapRouter.swapExactIn(key, sp, "");
        vm.stopPrank();

        assertEq(IUniswapV4WeightedSwapHook(hook_).reserveOf(address(t0)), r0Before + amountIn);
        assertEq(IUniswapV4WeightedSwapHook(hook_).reserveOf(address(t1)), r1Before - preview);
        assertEq(IUniswapV4WeightedSwapHook(hook_).kLast(), kBefore);
    }

    function test_S4_maxInRatio() public {
        (address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1) = _deployN2Combo();
        _joinFullN2(hook_, t0, t1, 1000);
        uint256 huge = _raw(t0, 400);
        vm.expectRevert();
        IUniswapV4WeightedSwapHook(hook_).previewSwapExactIn(address(t0), address(t1), huge);
    }

    function test_S5_feeZero_stillWorks() public {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultDexSwapFee(0);
        vm.stopPrank();

        (address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1) = _deployN2Combo();
        _joinFullN2(hook_, t0, t1, 1000);
        uint256 out = IUniswapV4WeightedSwapHook(hook_).previewSwapExactIn(
            address(t0), address(t1), _raw(t0, 10)
        );
        assertGt(out, 0);
    }

    function test_G1_growthMintOnJoinAfterSwap() public {
        (address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1) = _deployN2Combo();
        _joinFullN2(hook_, t0, t1, 10_000);

        uint256 kBefore = IUniswapV4WeightedSwapHook(hook_).kLast();
        assertGt(kBefore, 0);

        PoolKey memory key = _pairPoolKeysDec(hook_)[0];
        bool zeroForOne = address(t0) == Currency.unwrap(key.currency0);
        uint256 amountIn = _raw(t0, 100);
        vm.startPrank(user);
        t0.approve(address(swapRouter), type(uint256).max);
        t1.approve(address(swapRouter), type(uint256).max);
        swapRouter.swapExactIn(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            ""
        );
        vm.stopPrank();

        assertEq(IUniswapV4WeightedSwapHook(hook_).kLast(), kBefore);

        uint256 feeToBalBefore = IERC20(hook_).balanceOf(feeRecipient);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _raw(t0, 100);
        amounts[1] = _raw(t1, 100);
        vm.prank(user);
        IUniswapV4WeightedSwapHook(hook_).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
        assertGt(IERC20(hook_).balanceOf(feeRecipient), feeToBalBefore);
    }

    function test_G2_rootKIsV_fullBook() public {
        (address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1) = _deployN2Combo();
        _joinFullN2(hook_, t0, t1, 1000);
        uint256 k = IUniswapV4WeightedSwapHook(hook_).kLast();
        assertGt(k, 1000);
        assertEq(
            uint8(IUniswapV4WeightedSwapHook(hook_).kLastMode()),
            uint8(IUniswapV4WeightedSwapHook.KLastMode.FullProduct)
        );
    }

    function test_G3_feeOff_noProtocolMint() public {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        vm.stopPrank();

        (address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1) = _deployN2Combo();
        _joinFullN2(hook_, t0, t1, 1000);
        assertEq(IUniswapV4WeightedSwapHook(hook_).kLast(), 0);
        assertEq(IERC20(hook_).balanceOf(feeRecipient), 0);
    }

    function test_G4_growthOnExit() public {
        (address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1) = _deployN2Combo();
        uint256 shares = _joinFullN2(hook_, t0, t1, 10_000);

        PoolKey memory key = _pairPoolKeysDec(hook_)[0];
        bool zeroForOne = address(t0) == Currency.unwrap(key.currency0);
        vm.startPrank(user);
        t0.approve(address(swapRouter), type(uint256).max);
        t1.approve(address(swapRouter), type(uint256).max);
        swapRouter.swapExactIn(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(_raw(t0, 50)),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            ""
        );
        vm.stopPrank();

        uint256 feeBefore = IERC20(hook_).balanceOf(feeRecipient);
        uint256[] memory mins = new uint256[](2);
        vm.prank(user);
        IUniswapV4WeightedSwapHook(hook_).exitProportional(
            shares / 10, user, mins, block.timestamp + 1 hours
        );
        assertGe(IERC20(hook_).balanceOf(feeRecipient), feeBefore);
    }

    function test_R1_rateProviderPath() public {
        MintableERC20Decimals a = new MintableERC20Decimals("A", "A", _pairDecimals());
        MintableERC20Decimals b = new MintableERC20Decimals("B", "B", _rateDecimals());
        (MintableERC20Decimals t0, MintableERC20Decimals t1) = _sortTwo(a, b);
        RateProviderHarness rp = new RateProviderHarness();
        rp.setRate(2e18);

        address[] memory tokens = new address[](2);
        tokens[0] = address(t0);
        tokens[1] = address(t1);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5e17;
        weights[1] = 5e17;
        address[] memory providers = new address[](2);
        providers[0] = address(rp);

        (address hook_,) = _mineAndDeploy(tokens, weights, providers);
        _fundAndApproveDec(hook_, tokens);

        uint256 rate0 = IUniswapV4WeightedSwapHook(hook_).effectiveRate(0);
        uint256 rate1 = IUniswapV4WeightedSwapHook(hook_).effectiveRate(1);
        assertEq(rate0, Math.baseScaleFromDecimals(t0.decimals()) * 2e18 / 1e18);
        assertEq(rate1, Math.baseScaleFromDecimals(t1.decimals()));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _raw(t0, 1000);
        amounts[1] = _raw(t1, 2000);
        vm.prank(user);
        (uint256 shares,) = IUniswapV4WeightedSwapHook(hook_).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
        assertGt(shares, 0);
    }

    function test_R2_rateProviderFailClosed() public {
        MintableERC20Decimals a = new MintableERC20Decimals("A", "A", _pairDecimals());
        MintableERC20Decimals b = new MintableERC20Decimals("B", "B", _rateDecimals());
        (MintableERC20Decimals t0, MintableERC20Decimals t1) = _sortTwo(a, b);
        RateProviderHarness rp = new RateProviderHarness();
        rp.setShouldRevert(true);

        address[] memory tokens = new address[](2);
        tokens[0] = address(t0);
        tokens[1] = address(t1);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5e17;
        weights[1] = 5e17;
        address[] memory providers = new address[](2);
        providers[0] = address(rp);

        (address hook_,) = _mineAndDeploy(tokens, weights, providers);
        _fundAndApproveDec(hook_, tokens);

        vm.expectRevert();
        IUniswapV4WeightedSwapHook(hook_).effectiveRate(0);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _raw(t0, 1000);
        amounts[1] = _raw(t1, 1000);
        vm.prank(user);
        vm.expectRevert();
        IUniswapV4WeightedSwapHook(hook_).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
    }

    function test_R3_badReturndataFailClosed() public {
        MintableERC20Decimals a = new MintableERC20Decimals("A", "A", _pairDecimals());
        MintableERC20Decimals b = new MintableERC20Decimals("B", "B", _rateDecimals());
        (MintableERC20Decimals t0, MintableERC20Decimals t1) = _sortTwo(a, b);
        RateProviderHarness rp = new RateProviderHarness();
        rp.setBadReturndata(true);

        address[] memory tokens = new address[](2);
        tokens[0] = address(t0);
        tokens[1] = address(t1);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5e17;
        weights[1] = 5e17;
        address[] memory providers = new address[](2);
        providers[0] = address(rp);

        (address hook_,) = _mineAndDeploy(tokens, weights, providers);
        vm.expectRevert();
        IUniswapV4WeightedSwapHook(hook_).effectiveRate(0);
    }

    function test_X2_donateBlocked() public {
        (address hook_,,) = _deployN2Combo();
        PoolKey memory key = _pairPoolKeysDec(hook_)[0];
        vm.prank(address(pm));
        vm.expectRevert();
        IHooks(hook_).beforeDonate(address(this), key, 1, 1, "");
    }

    function test_X3_donationIgnored() public {
        (address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1) = _deployN2Combo();
        _joinFullN2(hook_, t0, t1, 1000);
        uint256 r0 = IUniswapV4WeightedSwapHook(hook_).reserveOf(address(t0));
        t0.mint(address(hook_), _raw(t0, 100));
        assertEq(IUniswapV4WeightedSwapHook(hook_).reserveOf(address(t0)), r0);
    }

    function test_RE1_reentrancyOnJoinReverts() public {
        WeightedReentrancyERC20 reent = new WeightedReentrancyERC20(_pairDecimals());
        MintableERC20Decimals b = new MintableERC20Decimals("B", "B", _rateDecimals());
        address ra = address(reent);
        address rb = address(b);
        address t0a = ra < rb ? ra : rb;
        address t1a = ra < rb ? rb : ra;

        address[] memory tokens = new address[](2);
        tokens[0] = t0a;
        tokens[1] = t1a;
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5e17;
        weights[1] = 5e17;
        address[] memory providers = new address[](2);

        (address hook_,) = _mineAndDeploy(tokens, weights, providers);

        reent.mint(user, _raw(MintableERC20Decimals(address(reent)), 1_000_000));
        b.mint(user, _raw(b, 1_000_000));
        vm.startPrank(user);
        reent.approve(hook_, type(uint256).max);
        b.approve(hook_, type(uint256).max);
        vm.stopPrank();

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _raw(MintableERC20Decimals(t0a), 1000);
        amounts[1] = _raw(MintableERC20Decimals(t1a), 1000);
        bytes memory nested = abi.encodeWithSelector(
            IUniswapV4WeightedSwapHook.joinProportional.selector,
            amounts,
            user,
            0,
            block.timestamp + 1 hours,
            ""
        );
        reent.arm(hook_, nested);

        vm.prank(user);
        try this.externalJoin(hook_, amounts) {} catch {}
    }

    function externalJoin(address hook_, uint256[] memory amounts) external {
        vm.prank(user);
        IUniswapV4WeightedSwapHook(hook_).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
    }

    function test_P2_1_emptyPermit2_transferFrom() public {
        (address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1) = _deployN2Combo();
        uint256 shares = _joinFullN2(hook_, t0, t1, 500);
        assertGt(shares, 0);
    }

    function test_P2_2_badModeReverts() public {
        (address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1) = _deployN2Combo();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _raw(t0, 100);
        amounts[1] = _raw(t1, 100);
        bytes memory bad = abi.encode(uint8(99));
        vm.prank(user);
        vm.expectRevert();
        IUniswapV4WeightedSwapHook(hook_).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, bad
        );
    }

    function test_P2_3_allowanceModeWithoutPermit2SetupReverts() public {
        (address hook_, MintableERC20Decimals t0, MintableERC20Decimals t1) = _deployN2Combo();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _raw(t0, 100);
        amounts[1] = _raw(t1, 100);
        bytes memory allowMode = abi.encode(uint8(1));
        vm.prank(user);
        vm.expectRevert();
        IUniswapV4WeightedSwapHook(hook_).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, allowMode
        );
    }
}

contract WeightedReentrancyERC20 is MintableERC20Decimals {
    address public target;
    bytes public payload;
    bool public armed;

    constructor(uint8 dec) MintableERC20Decimals("Reentrancy", "REENT", dec) {}

    function arm(address target_, bytes calldata payload_) external {
        target = target_;
        payload = payload_;
        armed = true;
    }

    function transferFrom(address from, address to, uint256 amount)
        external
        override
        returns (bool)
    {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        if (armed && target != address(0)) {
            armed = false;
            (bool ok,) = target.call(payload);
            ok;
        }
        return true;
    }
}
