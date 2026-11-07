// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {UniswapV4FullSpreadMathHarness, UniswapV4FullSpreadStandardExchangeVaultMath as Math} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMath.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultDFPkg as IPackage} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol";
import {UniswapV4FullSpreadSwapProjectionHarness} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultSwapProjection.sol";
import {TestBase_UniswapV4FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";
import {FullSpreadV4ExternalLp} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol";

interface IFullSpreadQuote {
    function reserves() external view returns (uint256[] memory);
    function reserveOfToken(address token) external view returns (uint256);
    function exchangeIn(
        address tokenIn, uint256 amountIn, address tokenOut, uint256 minAmountOut,
        address recipient, bool pretransferred, uint256 deadline
    ) external returns (uint256 amountOut, uint256 amountRefunded);
    function previewExchangeIn(address tokenIn, uint256 amountIn, address tokenOut)
        external
        view
        returns (uint256 amountOut, uint256 amountRefunded);

    function previewExchangeBundleInForSingleOut(uint256[] calldata amountsIn, address tokenOut)
        external
        view
        returns (uint256 amountOut, uint256[] memory amountsRefunded);

    function previewExchangeBundleOut(address tokenIn, uint256 amountIn, address[] calldata tokensOut)
        external
        view
        returns (uint256[] memory amountsOut, uint256 amountRefunded);

    function exchangeBundleInForSingleOut(
        uint256[] calldata amountsIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256[] memory amountsRefunded);

    function exchangeBundleOut(
        address tokenIn,
        uint256 amountIn,
        address[] calldata tokensOut,
        uint256[] calldata minAmountsOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256[] memory amountsOut, uint256 amountRefunded);

    function balanceOf(address account) external view returns (uint256);
}

contract UniswapV4FullSpreadStandardExchangeVault_QuotesAndRate_Test is TestBase_UniswapV4FullSpreadStandardExchangeVault {
    using PoolIdLibrary for PoolKey;
    uint256 internal constant PREVIEW_GAS = 5_000_000;
    IFullSpreadQuote internal quote;

    function setUp() public override {
        super.setUp();
        quote = IFullSpreadQuote(address(vault));
        _fund(address(this), 2_000_000 ether, 2_000_000 ether);
        _approve(address(vault));
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 100_000 ether;
        amounts_[1] = 100_000 ether;
        quote.exchangeBundleInForSingleOut(amounts_, address(vault), 0, address(this), false, block.timestamp);
    }

    function test_bundlePreviewMatchesExecution() public {
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 1_000 ether;
        amounts_[1] = 800 ether;
        (uint256 preview_, uint256[] memory previewRefund_) =
            quote.previewExchangeBundleInForSingleOut(amounts_, address(vault));
        (uint256 shares_, uint256[] memory refund_) = quote.exchangeBundleInForSingleOut(
            amounts_, address(vault), preview_, address(this), false, block.timestamp
        );
        assertEq(shares_, preview_);
        assertEq(refund_[0], previewRefund_[0]);
        assertEq(refund_[1], previewRefund_[1]);
        address[] memory tokens_ = new address[](2);
        tokens_[0] = address(token0);
        tokens_[1] = address(token1);
        (uint256[] memory outPreview_, uint256 outRefund_) =
            quote.previewExchangeBundleOut(address(vault), shares_, tokens_);
        assertEq(outRefund_, 0);
        (uint256[] memory out_, uint256 refunded_) = quote.exchangeBundleOut(
            address(vault), shares_, tokens_, outPreview_, address(this), false, block.timestamp
        );
        assertEq(refunded_, 0);
        assertEq(out_[0], outPreview_[0]);
        assertEq(out_[1], outPreview_[1]);
    }

    function test_unsupportedPreviewIsZero() public {(uint256 out_, uint256 refund_) = quote.previewExchangeIn(address(0xBEEF), 1 ether, address(vault));
        assertEq(out_, 0);
        assertEq(refund_, 0);
    }

    /// @notice P01: both input faces quote the net shares actually delivered.
    function test_oneSidedPreviewParityBothFaces() public {
        uint256 snapshot_ = vm.snapshotState();
        for (uint256 i_; i_ < 2; ++i_) {
            address input_ = i_ == 0 ? address(token0) : address(token1);
            address recipient_ = makeAddr("preview mint recipient");
            (uint256 expected_,) = quote.previewExchangeIn(input_, 10 ether, address(vault));
            assertGt(expected_, 0);
            (uint256 actual_,) = vault.exchangeIn(
                input_, 10 ether, address(vault), expected_, recipient_, false, block.timestamp
            );
            assertEq(actual_, expected_);
            assertEq(vault.balanceOf(recipient_), actual_);
            assertTrue(vm.revertToState(snapshot_));
        }
    }

    /// @notice P02: compare the output word with the recipient's swap receipt.
    function test_passThroughPreviewParityBothDirections() public {
        uint256 snapshot_ = vm.snapshotState();
        for (uint256 i_; i_ < 2; ++i_) {
            address input_ = i_ == 0 ? address(token0) : address(token1);
            address output_ = i_ == 0 ? address(token1) : address(token0);
            address recipient_ = makeAddr("preview swap recipient");
            (uint256 expected_, uint256 refund_) = quote.previewExchangeIn(input_, 10 ether, output_);
            assertGt(expected_, refund_, "output and refund words differ");
            (uint256 actual_,) = vault.exchangeIn(
                input_, 10 ether, output_, expected_, recipient_, false, block.timestamp
            );
            assertEq(actual_, expected_);
            assertEq(IERC20(output_).balanceOf(recipient_), actual_);
            assertTrue(vm.revertToState(snapshot_));
        }
    }

    /// @notice P03: exits include booked fees and fresh unpaid fees, in either face.
    function test_exitPreviewParityWithBookedAndUnpaidFees() public {
        vault.exchangeIn(address(token0), 100 ether, address(token1), 0, address(this), false, block.timestamp);
        vault.exchangeIn(address(token1), 100 ether, address(token0), 0, address(this), false, block.timestamp);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 1 ether;
        amounts_[1] = 1 ether;
        quote.exchangeBundleInForSingleOut(amounts_, address(vault), 0, address(this), false, block.timestamp);
        assertGt(token0.balanceOf(address(vault)), 0, "requested token zero booked fees");
        assertGt(token1.balanceOf(address(vault)), 0, "requested token one booked fees");
        vault.exchangeIn(address(token0), 100 ether, address(token1), 0, address(this), false, block.timestamp);
        vault.exchangeIn(address(token1), 100 ether, address(token0), 0, address(this), false, block.timestamp);
        uint256 snapshot_ = vm.snapshotState();
        for (uint256 i_; i_ < 2; ++i_) {
            address output_ = i_ == 0 ? address(token0) : address(token1);
            address recipient_ = makeAddr("preview exit recipient");
            uint256 shares_ = vault.balanceOf(address(this)) / 10;
            (uint256 expected_,) = quote.previewExchangeIn(address(vault), shares_, output_);
            assertGt(expected_, 0);
            (uint256 actual_,) = vault.exchangeIn(
                address(vault), shares_, output_, expected_, recipient_, false, block.timestamp
            );
            assertEq(actual_, expected_, "four-part receipt preview");
            assertEq(IERC20(output_).balanceOf(recipient_), actual_);
            assertTrue(vm.revertToState(snapshot_));
        }
    }

    /// @notice P05: output amounts follow the caller's order, not backing order.
    function test_bundleExitPreviewParityBothCallerOrders() public {
        uint256 snapshot_ = vm.snapshotState();
        for (uint256 i_; i_ < 2; ++i_) {
            address[] memory tokens_ = new address[](2);
            tokens_[i_] = address(token0);
            tokens_[1 - i_] = address(token1);
            uint256 shares_ = vault.balanceOf(address(this)) / 10;
            address recipient_ = makeAddr("preview bundle recipient");
            (uint256[] memory expected_, uint256 refund_) =
                quote.previewExchangeBundleOut(address(vault), shares_, tokens_);
            assertEq(refund_, 0);
            (uint256[] memory actual_, uint256 actualRefund_) = quote.exchangeBundleOut(
                address(vault), shares_, tokens_, expected_, recipient_, false, block.timestamp
            );
            assertEq(actualRefund_, 0);
            assertEq(actual_, expected_);
            assertEq(IERC20(tokens_[0]).balanceOf(recipient_), actual_[0]);
            assertEq(IERC20(tokens_[1]).balanceOf(recipient_), actual_[1]);
            assertTrue(vm.revertToState(snapshot_));
        }
    }

    /// @notice G02: a one-token exit preview has its own cold measurement.
    function test_previewOneTokenExitGasFitsCeiling() public {
        uint256 gas_ = gasleft();
        quote.previewExchangeIn(address(vault), 1 ether, address(token0));
        assertLe(gas_ - gasleft(), PREVIEW_GAS);
    }

    /// @notice G02: a pass-through preview has its own cold measurement.
    function test_previewPassThroughGasFitsCeiling() public {
        uint256 gas_ = gasleft();
        quote.previewExchangeIn(address(token0), 1 ether, address(token1));
        assertLe(gas_ - gasleft(), PREVIEW_GAS);
    }

    /// @notice P07: views remain live when disabled and during an outer unlock.
    function test_economicViewsDisabledAndUnlocked() public {
        vault.exchangeIn(address(token0), 100 ether, address(token1), 0, address(this), false, block.timestamp);
        vault.exchangeIn(address(token1), 100 ether, address(token0), 0, address(this), false, block.timestamp);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 1 ether;
        amounts_[1] = 1 ether;
        quote.exchangeBundleInForSingleOut(amounts_, address(vault), 0, address(this), false, block.timestamp);
        assertGt(token0.balanceOf(address(vault)), 0, "booked currency0 fees");
        assertGt(token1.balanceOf(address(vault)), 0, "booked currency1 fees");
        token0.transfer(address(vault), 7 ether);
        token1.transfer(address(vault), 11 ether);
        // Accrue fresh unpaid fees beside both booked fees and ambient local custody.
        vault.exchangeIn(address(token0), 100 ether, address(token1), 0, address(this), false, block.timestamp);
        vault.exchangeIn(address(token1), 100 ether, address(token0), 0, address(this), false, block.timestamp);
        _assertEconomicViews();
        pool.unlock("");
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(vault), true);
        _assertEconomicViews();
        pool.unlock("");
    }

    function unlockCallback(bytes calldata) external returns (bytes memory) {
        require(msg.sender == address(pool));
        // Keep a genuine foreign debt open while every view reads the live pool.
        pool.take(key.currency0, address(this), 1 ether);
        _assertEconomicViews();
        pool.sync(key.currency0);
        token0.transfer(address(pool), 1 ether);
        assertEq(pool.settle(), 1 ether);
        return "";
    }

    function _assertEconomicViews() internal view {
        int24 lower_ = TickMath.minUsableTick(key.tickSpacing);
        int24 upper_ = TickMath.maxUsableTick(key.tickSpacing);
        (uint160 price_,,,) = StateLibrary.getSlot0(pool, key.toId());
        (uint128 liquidity_, uint256 last0_, uint256 last1_) =
            StateLibrary.getPositionInfo(pool, key.toId(), address(vault), lower_, upper_, bytes32(0));
        (uint256 principal0_, uint256 principal1_) = Math.amountsForLiquidity(
            price_, TickMath.getSqrtPriceAtTick(lower_), TickMath.getSqrtPriceAtTick(upper_), liquidity_
        );
        (uint256 inside0_, uint256 inside1_) = StateLibrary.getFeeGrowthInside(pool, key.toId(), lower_, upper_);
        uint256[] memory reserves_ = quote.reserves();
        assertEq(reserves_[0], principal0_ + FullMath.mulDiv(liquidity_, inside0_ - last0_, 1 << 128));
        assertEq(reserves_[1], principal1_ + FullMath.mulDiv(liquidity_, inside1_ - last1_, 1 << 128));
        assertEq(quote.reserveOfToken(address(token0)), reserves_[0]);
        assertEq(quote.reserveOfToken(address(token1)), reserves_[1]);
        assertEq(quote.reserveOfToken(address(0xBEEF)), 0);
        (uint256 unsupported_,) = quote.previewExchangeIn(address(0xBEEF), 1 ether, address(vault));
        assertEq(unsupported_, 0);
        (uint256 mint_,) = quote.previewExchangeIn(address(token0), 1 ether, address(vault));
        assertGt(mint_, 0);
        (uint256 exit_,) = quote.previewExchangeIn(address(vault), 1 ether, address(token0));
        assertGt(exit_, 0);
        (uint256 pass_,) = quote.previewExchangeIn(address(token0), 1 ether, address(token1));
        assertGt(pass_, 0);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 1 ether;
        amounts_[1] = 1 ether;
        (uint256 bundleMint_, uint256[] memory refunds_) =
            quote.previewExchangeBundleInForSingleOut(amounts_, address(vault));
        assertGt(bundleMint_, 0);
        assertEq(refunds_.length, 2);
        assertLe(refunds_[0], amounts_[0]);
        assertLe(refunds_[1], amounts_[1]);
        for (uint256 i_; i_ < 2; ++i_) {
            address[] memory faces_ = new address[](2);
            faces_[i_] = address(token0);
            faces_[1 - i_] = address(token1);
            (uint256[] memory outputs_, uint256 refund_) =
                quote.previewExchangeBundleOut(address(vault), 1 ether, faces_);
            assertEq(outputs_.length, 2);
            assertGt(outputs_[0], 0);
            assertGt(outputs_[1], 0);
            assertEq(refund_, 0);
        }
    }

    /// @notice P08: normal entry and exit traverse adjacent one-liquidity dust ticks.
    function test_dustTicksPreviewMatchesDepositAndRedeem() public {
        PoolKey memory dustKey_ = key;
        dustKey_.tickSpacing = 1;
        pool.initialize(dustKey_, uint160(1) << 96);
        IFullSpreadQuote dust_ = IFullSpreadQuote(address(package.deployVault(IPackage.PkgArgs(dustKey_))));
        _approve(address(dust_));
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 100_000 ether;
        amounts_[1] = 100_000 ether;
        dust_.exchangeBundleInForSingleOut(amounts_, address(dust_), 0, address(this), false, block.timestamp);
        FullSpreadV4ExternalLp lp_ = new FullSpreadV4ExternalLp(pool);
        token0.mint(address(lp_), 1 ether);
        token1.mint(address(lp_), 1 ether);
        for (int24 i_ = 1; i_ <= 80; ++i_) {
            lp_.add(dustKey_, -i_, 1 - i_, 1);
        }
        (uint256 expected_,) = dust_.previewExchangeIn(address(token0), 1_000 ether, address(dust_));
        assertGt(expected_, 0);
        (uint256 shares_,) = dust_.exchangeIn(
            address(token0), 1_000 ether, address(dust_), expected_, address(this), false, block.timestamp
        );
        assertEq(shares_, expected_);
        (, int24 tick_,,) = StateLibrary.getSlot0(pool, dustKey_.toId());
        assertLt(tick_, -80, "deposit crossed every dust tick");
        (uint256 expectedExit_,) = dust_.previewExchangeIn(address(dust_), shares_, address(token0));
        uint256 before_ = token0.balanceOf(address(this));
        (uint256 actualExit_,) = dust_.exchangeIn(
            address(dust_), shares_, address(token0), expectedExit_, address(this), false, block.timestamp
        );
        assertEq(actualExit_, expectedExit_);
        assertEq(token0.balanceOf(address(this)) - before_, expectedExit_);
    }

    function test_previewExchangeInGasFitsCeiling() public {
        uint256 gas_ = gasleft();
        quote.previewExchangeIn(address(token0), 1 ether, address(vault));
        assertLe(gas_ - gasleft(), PREVIEW_GAS);
    }

    function test_previewExchangeBundleInGasFitsCeiling() public {
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 1 ether;
        amounts_[1] = 1 ether;
        uint256 gas_ = gasleft();
        quote.previewExchangeBundleInForSingleOut(amounts_, address(vault));
        assertLe(gas_ - gasleft(), PREVIEW_GAS);
    }

    function test_previewExchangeBundleOutGasFitsCeiling() public {
        address[] memory tokens_ = new address[](2);
        tokens_[0] = address(token0);
        tokens_[1] = address(token1);
        uint256 gas_ = gasleft();
        quote.previewExchangeBundleOut(address(vault), 1 ether, tokens_);
        assertLe(gas_ - gasleft(), PREVIEW_GAS);
    }

    function test_previewExchangeOutGasFitsCeiling() public {
        uint256 gas_ = gasleft();
        IStandardExchangeOut(address(vault)).previewExchangeOut(IERC20(address(token0)), IERC20(address(vault)), 1 ether);
        assertLe(gas_ - gasleft(), PREVIEW_GAS);
    }

    function test_getRateAndExchangeOutAreAbsent() public {
        assertEq(address(vault).code.length > 0, true);
        (bool ok_,) = address(vault).staticcall(abi.encodeWithSignature("getRate()"));
        assertFalse(ok_, "getRate is absent");
        uint256 caller0_ = token0.balanceOf(address(this));
        uint256 caller1_ = token1.balanceOf(address(this));
        uint256 vault0_ = token0.balanceOf(address(vault));
        uint256 vault1_ = token1.balanceOf(address(vault));
        uint256 shares_ = vault.balanceOf(address(this));
        assertEq(
            IStandardExchangeOut(address(vault)).previewExchangeOut(IERC20(address(token0)), IERC20(address(vault)), 1 ether),
            0
        );
        (bool inverseOk_, bytes memory inverse_) = address(vault).staticcall(abi.encodeWithSelector(
            IStandardExchangeOut.previewExchangeOut.selector, IERC20(address(token0)), IERC20(address(vault)), 1 ether
        ));
        assertTrue(inverseOk_);
        assertEq(inverse_.length, 32, "inverse preview retains its one-word ABI");
        assertEq(abi.decode(inverse_, (uint256)), 0);
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        IStandardExchangeOut(address(vault)).exchangeOut(
            IERC20(address(token0)), 1 ether, IERC20(address(vault)), 0, address(this), false, block.timestamp
        );
        assertEq(token0.balanceOf(address(this)), caller0_);
        assertEq(token1.balanceOf(address(this)), caller1_);
        assertEq(token0.balanceOf(address(vault)), vault0_);
        assertEq(token1.balanceOf(address(vault)), vault1_);
        assertEq(vault.balanceOf(address(this)), shares_);
    }
}

contract UniswapV4FullSpreadQuadraticLock_Test is TestBase_UniswapV4FullSpreadStandardExchangeVault {
    using PoolIdLibrary for PoolKey;

    uint256 internal constant AMOUNT = 1_000 ether;
    uint128 internal constant ACTIVE = 1_000 ether;
    uint24 internal constant FEE = 3000;

    UniswapV4FullSpreadMathHarness internal math;
    UniswapV4FullSpreadSwapProjectionHarness internal scan;

    function setUp() public override {
        super.setUp();
        math = new UniswapV4FullSpreadMathHarness();
        scan = new UniswapV4FullSpreadSwapProjectionHarness();
    }

    function test_quadraticRootMatchesLockToken0() public view {
        (uint160 price_, uint160 lower_, uint160 upper_) = _inside();
        uint256 expected_ = FullSpreadLockRoot.floorRoot(true, AMOUNT, price_, lower_, upper_, ACTIVE, FEE);
        assertGt(expected_, 0);
        assertLt(expected_, AMOUNT);
        assertEq(math.quadraticInput(AMOUNT, true, price_, lower_, upper_, ACTIVE, FEE), expected_);
    }

    function test_quadraticRootMatchesLockToken1() public view {
        (uint160 price_, uint160 lower_, uint160 upper_) = _inside();
        uint256 expected_ = FullSpreadLockRoot.floorRoot(false, AMOUNT, price_, lower_, upper_, ACTIVE, FEE);
        assertGt(expected_, 0);
        assertLt(expected_, AMOUNT);
        assertEq(math.quadraticInput(AMOUNT, false, price_, lower_, upper_, ACTIVE, FEE), expected_);
    }

    function test_quadraticIsZeroOutsidePosition() public view {
        uint160 lower_ = TickMath.getSqrtPriceAtTick(-120);
        uint160 upper_ = TickMath.getSqrtPriceAtTick(120);
        uint160 below_ = TickMath.getSqrtPriceAtTick(-180);
        uint160 above_ = TickMath.getSqrtPriceAtTick(180);
        assertEq(math.quadraticInput(AMOUNT, true, below_, lower_, upper_, ACTIVE, FEE), 0);
        assertEq(math.quadraticInput(AMOUNT, true, lower_, lower_, upper_, ACTIVE, FEE), 0);
        assertEq(math.quadraticInput(AMOUNT, false, upper_, lower_, upper_, ACTIVE, FEE), 0);
        assertEq(math.quadraticInput(AMOUNT, false, above_, lower_, upper_, ACTIVE, FEE), 0);
    }

    function test_quadraticIsZeroWhenActiveLiquidityIsZero() public view {
        (uint160 price_, uint160 lower_, uint160 upper_) = _inside();
        assertEq(math.quadraticInput(AMOUNT, true, price_, lower_, upper_, 0, FEE), 0);
        assertEq(math.quadraticInput(AMOUNT, false, price_, lower_, upper_, 0, FEE), 0);
    }

    function test_quadraticCapIsSegmentBoundary() public {
        int24 edgeTick_ = -60;
        uint128 externalLiq_ = LiquidityAmounts.getLiquidityForAmounts(
            uint160(uint256(1) << 96),
            TickMath.getSqrtPriceAtTick(edgeTick_),
            TickMath.getSqrtPriceAtTick(60),
            1_000 ether,
            1_000 ether
        );
        FullSpreadV4ExternalLp lp_ = new FullSpreadV4ExternalLp(IPoolManager(address(pool)));
        token0.mint(address(lp_), 2_000 ether);
        token1.mint(address(lp_), 2_000 ether);
        lp_.add(key, edgeTick_, 60, externalLiq_);
        (uint160 price_, int24 current_, uint24 fee_) = _slot();
        uint128 active_ = StateLibrary.getLiquidity(pool, key.toId());
        int24 lower_ = TickMath.minUsableTick(key.tickSpacing);
        int24 upper_ = TickMath.maxUsableTick(key.tickSpacing);
        uint256 uncapped_ = math.quadraticInput(
            AMOUNT * 1000,
            true,
            price_,
            TickMath.getSqrtPriceAtTick(lower_),
            TickMath.getSqrtPriceAtTick(upper_),
            active_,
            fee_
        );
        uint160 edge_ = TickMath.getSqrtPriceAtTick(edgeTick_);
        uint256 capped_ = math.boundaryInput(true, price_, edge_, active_);
        assertGt(uncapped_, capped_, "uncapped root passes the next tick");
        (uint160 bound_, bool cap_) = scan.limitingSqrt(pool, key, current_, true, price_, active_, uncapped_);
        assertTrue(cap_);
        assertEq(bound_, edge_, "cap uses the next initialized tick, not a later segment");
        uint256 returned_ = cap_ ? math.boundaryInput(true, price_, bound_, active_) : uncapped_;
        assertEq(returned_, capped_);
        assertTrue(returned_ != uncapped_);
    }

    function _inside() internal pure returns (uint160 price_, uint160 lower_, uint160 upper_) {
        price_ = TickMath.getSqrtPriceAtTick(0);
        lower_ = TickMath.getSqrtPriceAtTick(-120);
        upper_ = TickMath.getSqrtPriceAtTick(120);
    }

    function _slot() internal view returns (uint160 price_, int24 tick_, uint24 fee_) {
        (price_, tick_, , fee_) = StateLibrary.getSlot0(pool, key.toId());
    }
}

/// @dev Independent transcription of the 2026-11-05 lock equations. Does not call the production coefficient helpers.
library FullSpreadLockRoot {
    uint256 internal constant Q96 = 1 << 96;
    uint256 internal constant G = 1_000_000;

    struct W {
        uint256 l0;
        uint256 l1;
        uint256 l2;
        uint256 l3;
    }

    function floorRoot(
        bool zeroForOne_,
        uint256 amount_,
        uint160 sqrtPrice_,
        uint160 sqrtLower_,
        uint160 sqrtUpper_,
        uint128 active_,
        uint24 feePips_
    ) internal pure returns (uint256) {
        if (_nonnegative(zeroForOne_, amount_, amount_, sqrtPrice_, sqrtLower_, sqrtUpper_, active_, feePips_)) return amount_;
        uint256 lo_;
        uint256 hi_ = amount_;
        while (lo_ < hi_) {
            uint256 mid_ = (lo_ + hi_) / 2;
            if (_nonnegative(zeroForOne_, mid_, amount_, sqrtPrice_, sqrtLower_, sqrtUpper_, active_, feePips_)) lo_ = mid_ + 1;
            else hi_ = mid_;
        }
        return lo_ == 0 ? 0 : lo_ - 1;
    }

    function _nonnegative(
        bool zeroForOne_,
        uint256 n_,
        uint256 amount_,
        uint160 sqrtPrice_,
        uint160 sqrtLower_,
        uint160 sqrtUpper_,
        uint128 active_,
        uint24 feePips_
    ) private pure returns (bool) {
        (bool negA_, W memory aAbs_, W memory b_, W memory c_) =
            _coeffs(zeroForOne_, amount_, sqrtPrice_, sqrtLower_, sqrtUpper_, active_, feePips_);
        W memory n2_ = _mulW(aAbs_, n_ * n_);
        W memory bn_ = _mulW(b_, n_);
        if (negA_ || _isZero(aAbs_)) return _cmp(c_, _add(n2_, bn_)) >= 0;
        return _cmp(_add(n2_, c_), bn_) >= 0;
    }

    function _coeffs(
        bool zeroForOne_,
        uint256 amount_,
        uint160 sqrtPrice_,
        uint160 sqrtLower_,
        uint160 sqrtUpper_,
        uint128 active_,
        uint24 feePips_
    ) private pure returns (bool negA_, W memory aAbs_, W memory b_, W memory c_) {
        uint256 gNum_ = G - feePips_;
        uint256 gapL_ = uint256(sqrtPrice_) - uint256(sqrtLower_);
        uint256 gapU_ = uint256(sqrtUpper_) - uint256(sqrtPrice_);
        if (zeroForOne_) {
            uint256 left_ = uint256(sqrtLower_) * G;
            uint256 right_ = uint256(sqrtPrice_) * gNum_;
            negA_ = left_ < right_;
            aAbs_ = _mulW(_pair(sqrtPrice_, sqrtUpper_), negA_ ? right_ - left_ : left_ - right_);
            b_ = _scale(_pair(sqrtUpper_, amount_), sqrtPrice_, sqrtLower_, gNum_);
            b_ = _add(b_, _scale(_pair(sqrtUpper_, active_), gapL_, Q96, G));
            b_ = _add(b_, _scale(_pair(sqrtPrice_, active_), gapU_, gNum_, Q96));
            c_ = _scale(_pair(sqrtUpper_, amount_), active_, gapL_, gNum_, Q96);
        } else {
            uint256 left_ = uint256(sqrtPrice_) * G;
            uint256 right_ = uint256(sqrtUpper_) * gNum_;
            negA_ = left_ < right_;
            aAbs_ = _mulW(_u(Q96), negA_ ? right_ - left_ : left_ - right_);
            b_ = _scale(_pair(sqrtPrice_, amount_), gNum_, Q96);
            b_ = _add(b_, _scale(_pair(sqrtPrice_, active_), gapU_, G));
            b_ = _add(b_, _scale(_pair(sqrtUpper_, active_), gapL_, gNum_));
            c_ = _scale(_pair(sqrtPrice_, amount_), active_, gapU_, gNum_);
        }
    }

    function _scale(W memory x_, uint256 a_, uint256 b_) private pure returns (W memory) {
        return _mulW(_mulW(x_, a_), b_);
    }

    function _scale(W memory x_, uint256 a_, uint256 b_, uint256 c_) private pure returns (W memory) {
        return _mulW(_scale(x_, a_, b_), c_);
    }

    function _scale(W memory x_, uint256 a_, uint256 b_, uint256 c_, uint256 d_) private pure returns (W memory) {
        return _mulW(_scale(x_, a_, b_, c_), d_);
    }

    function _pair(uint256 x_, uint256 y_) private pure returns (W memory w_) {
        (uint256 hi_, uint256 lo_) = _mul256(x_, y_);
        w_.l0 = lo_;
        w_.l1 = hi_;
    }

    function _u(uint256 x_) private pure returns (W memory w_) {
        w_.l0 = x_;
    }

    function _mulW(W memory x_, uint256 y_) private pure returns (W memory z_) {
        if (y_ == 0) return z_;
        (uint256 h0_, uint256 l0_) = _mul256(x_.l0, y_);
        (uint256 h1_, uint256 l1_) = _mul256(x_.l1, y_);
        (uint256 h2_, uint256 l2_) = _mul256(x_.l2, y_);
        (uint256 h3_, uint256 l3_) = _mul256(x_.l3, y_);
        uint256 c_;
        z_.l0 = l0_;
        (z_.l1, c_) = _sum(h0_, l1_, 0);
        (z_.l2, c_) = _sum(h1_, l2_, c_);
        (z_.l3, c_) = _sum(h2_, l3_, c_);
        require(h3_ == 0 && c_ == 0, "lock root overflow");
    }

    function _add(W memory x_, W memory y_) private pure returns (W memory z_) {
        uint256 c_;
        (z_.l0, c_) = _sum(x_.l0, y_.l0, 0);
        (z_.l1, c_) = _sum(x_.l1, y_.l1, c_);
        (z_.l2, c_) = _sum(x_.l2, y_.l2, c_);
        (z_.l3, c_) = _sum(x_.l3, y_.l3, c_);
        require(c_ == 0, "lock root overflow");
    }

    function _sum(uint256 a_, uint256 b_, uint256 c_) private pure returns (uint256 sum_, uint256 carry_) {
        unchecked {
            uint256 s_ = a_ + b_;
            uint256 c1_ = s_ < a_ ? 1 : 0;
            sum_ = s_ + c_;
            carry_ = c1_ + (sum_ < s_ ? 1 : 0);
        }
    }

    function _cmp(W memory x_, W memory y_) private pure returns (int256) {
        if (x_.l3 != y_.l3) return x_.l3 > y_.l3 ? int256(1) : int256(-1);
        if (x_.l2 != y_.l2) return x_.l2 > y_.l2 ? int256(1) : int256(-1);
        if (x_.l1 != y_.l1) return x_.l1 > y_.l1 ? int256(1) : int256(-1);
        if (x_.l0 != y_.l0) return x_.l0 > y_.l0 ? int256(1) : int256(-1);
        return 0;
    }

    function _isZero(W memory x_) private pure returns (bool) {
        return x_.l0 == 0 && x_.l1 == 0 && x_.l2 == 0 && x_.l3 == 0;
    }

    function _mul256(uint256 x_, uint256 y_) private pure returns (uint256 hi_, uint256 lo_) {
        assembly {
            let mm := mulmod(x_, y_, not(0))
            lo_ := mul(x_, y_)
            hi_ := sub(sub(mm, lo_), lt(mm, lo_))
        }
    }
}
