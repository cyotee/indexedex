// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
import {IOperable} from "@crane/contracts/access/operable/IOperable.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams, ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {FullSpreadV4ExternalLp} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IUniswapV4FullSpreadStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {IStandardExchangeBundleIn, IStandardExchangeBundleOut} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {TestBase_UniswapV4FullSpreadStandardExchangeVault, IFullSpreadVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultDFPkg as IPackage} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol";
import {UniswapV4FullSpreadStandardExchangeVaultSwapProjection as SwapProjection} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultSwapProjection.sol";
import {UniswapV4FullSpreadStandardExchangeVaultTypes as Types} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultTypes.sol";

interface IFullSpreadMoney {
    function exchangeIn(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256 amountRefunded);

    function previewExchangeIn(address tokenIn, uint256 amountIn, address tokenOut)
        external
        view
        returns (uint256 amountOut, uint256 amountRefunded);

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

    function donate(address token, uint256 amount, bool pretransferred) external;
    function compound() external;
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract UniswapV4FullSpreadStandardExchangeVault_Money_Test is TestBase_UniswapV4FullSpreadStandardExchangeVault {
    using PoolIdLibrary for PoolKey;

    IFullSpreadMoney internal money;

    function setUp() public override {
        super.setUp();
        money = IFullSpreadMoney(address(vault));
        _fund(address(this), 2_000_000 ether, 2_000_000 ether);
        _approve(address(vault));
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 100_000 ether;
        amounts_[1] = 100_000 ether;
        money.exchangeBundleInForSingleOut(amounts_, address(vault), 0, address(this), false, block.timestamp);
    }

    function test_passThroughSwapsWithoutMinting() public {
        uint256 supply_ = money.totalSupply();
        uint256 before_ = token1.balanceOf(address(this));(uint256 preview_, uint256 previewRefund_) =
            money.previewExchangeIn(address(token0), 1 ether, address(token1));(uint256 out_, uint256 refund_) = money.exchangeIn(address(token0), 1 ether, address(token1), 0, address(this), false, block.timestamp
        );
        assertEq(out_, preview_, "pass-through preview is execution");
        assertEq(refund_, previewRefund_);
        assertGt(out_, 0);
        assertEq(token1.balanceOf(address(this)) - before_, out_);
        assertEq(money.totalSupply(), supply_, "pass-through mints no shares");
        assertLt(refund_, 1 ether);
    }

    function test_oneSidedPreviewMatchesExecution() public {
        uint256 before0_ = token0.balanceOf(address(this));
        uint256 sharesBefore_ = money.balanceOf(address(this));(uint256 preview_, uint256 previewRefund_) =
            money.previewExchangeIn(address(token0), 1_000 ether, address(vault));(uint256 shares_, uint256 refund_) = money.exchangeIn(address(token0), 1_000 ether, address(vault), preview_, address(this), false, block.timestamp
        );
        assertEq(shares_, preview_);
        assertEq(refund_, previewRefund_);
        assertGt(shares_, 0, "49 percent one-sided mint succeeds");
        assertLt(refund_, 1_000 ether, "swap consumes part of the input");
        assertEq(token0.balanceOf(address(this)), before0_ - (1_000 ether - refund_));
        assertEq(money.balanceOf(address(this)), sharesBefore_ + shares_);
        uint256 exitShares_ = sharesBefore_ / 4;(uint256 exitPreview_,) = money.previewExchangeIn(address(vault), exitShares_, address(token0));
        uint256 faceBefore_ = token0.balanceOf(address(this));(uint256 out_, uint256 exitRefund_) = money.exchangeIn(address(vault), exitShares_, address(token0), exitPreview_, address(this), false, block.timestamp
        );
        assertEq(out_, exitPreview_, "exit preview is execution");
        assertEq(exitRefund_, 0);
        assertEq(token0.balanceOf(address(this)) - faceBefore_, out_);
    }

    function test_bundleOutPaysBothFaces() public {
        uint256 shares_ = 1_000 ether;
        if (money.balanceOf(address(this)) < shares_) shares_ = money.balanceOf(address(this)) / 2;
        address[] memory tokens_ = new address[](2);
        tokens_[0] = address(token1);
        tokens_[1] = address(token0);
        uint256[] memory mins_ = new uint256[](2);
        uint256 before0_ = token0.balanceOf(address(this));
        uint256 before1_ = token1.balanceOf(address(this));
        (uint256[] memory out_, uint256 refund_) =
            money.exchangeBundleOut(address(vault), shares_, tokens_, mins_, address(this), false, block.timestamp);
        assertEq(refund_, 0);
        assertGt(out_[0], 0);
        assertGt(out_[1], 0);
        assertEq(token1.balanceOf(address(this)) - before1_, out_[0]);
        assertEq(token0.balanceOf(address(this)) - before0_, out_[1]);
    }

    function test_donateEmitsMarkerAndEmptyCompoundEmitsNothing() public {
        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        vm.prank(feeTo_);
        money.compound();
        vm.recordLogs();
        vm.prank(feeTo_);
        money.compound();
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        for (uint256 i_; i_ < logs_.length; ++i_) {
            assertTrue(logs_[i_].emitter != address(vault) || logs_[i_].topics[0] != IVault.Compounded.selector);
        }
        _fund(feeTo_, 10 ether, 0);
        vm.startPrank(feeTo_);
        IERC20(address(token0)).approve(address(vault), type(uint256).max);
        vm.expectEmit(false, false, false, true, address(vault));
        emit IVault.Donation();
        money.donate(address(token0), 1 ether, false);
        vm.stopPrank();
    }

    function test_sameTokenRevertsInvalidRoute() public {
        vm.expectRevert(IVault.InvalidRoute.selector);money.exchangeIn(address(vault), 1, address(vault), 0, address(this), false, block.timestamp);
    }

    function test_deadlinePrecedesDisable() public {
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(vault), true);
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, 0, block.timestamp)
        );money.exchangeIn(address(token0), 1 ether, address(vault), 0, address(this), false, 0);
    }

    function test_disabledVaultBlocksDepositAndAllowsExit() public {
        uint256 shares_ = 100 ether;
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(vault), true);
        assertTrue(IVaultRegistryDisableQuery(address(indexedexManager)).isDisabled(address(vault)));
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, address(vault)));money.exchangeIn(address(token0), 1 ether, address(vault), 0, address(this), false, block.timestamp);(uint256 out_,) = money.exchangeIn(address(vault), shares_, address(token0), 0, address(this), false, block.timestamp
        );
        assertGt(out_, 0);
    }

    function test_enabledExchangeOutIsAbsent() public {
        assertEq(IStandardExchangeOut(address(vault)).previewExchangeOut(IERC20(address(token0)), IERC20(address(vault)), 1 ether), 0);
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        IStandardExchangeOut(address(vault)).exchangeOut(
            IERC20(address(token0)), 1 ether, IERC20(address(vault)), 0, address(this), false, block.timestamp
        );
    }

    function test_bundleOutMinimumUsesCallerIndex() public {
        address[] memory tokens_ = new address[](2);
        tokens_[0] = address(token1);
        tokens_[1] = address(token0);
        uint256[] memory mins_ = new uint256[](2);
        (uint256[] memory quoted_,) = money.previewExchangeBundleOut(address(vault), 1 ether, tokens_);
        mins_[0] = quoted_[0] + 1;
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeBundleIn.MinAmountNotMetAt.selector, 0, quoted_[0] + 1, quoted_[0])
        );
        money.exchangeBundleOut(address(vault), 1 ether, tokens_, mins_, address(this), false, block.timestamp);
    }


    /// forge-config: default.isolate = true
    function test_gasOneSidedMintFitsCeiling() public {
        assertTrue(vm.isIsolateMode());
        money.exchangeIn(address(token0), 1_000 ether, address(vault), 0, address(this), false, block.timestamp);
        assertLe(vm.lastFrameGas().gasTotalUsed, 11_900_000);
    }

    /// forge-config: default.isolate = true
    function test_gasOneTokenExitFitsCeiling() public {
        uint256 shares_ = 100 ether;
        assertTrue(vm.isIsolateMode());
        money.exchangeIn(address(vault), shares_, address(token0), 0, address(this), false, block.timestamp);
        assertLe(vm.lastFrameGas().gasTotalUsed, 11_900_000);
    }

    /// forge-config: default.isolate = true
    function test_gasPassThroughFitsCeiling() public {
        assertTrue(vm.isIsolateMode());
        money.exchangeIn(address(token0), 1 ether, address(token1), 0, address(this), false, block.timestamp);
        assertLe(vm.lastFrameGas().gasTotalUsed, 11_900_000);
    }

    /// forge-config: default.isolate = true
    function test_gasBundleInFitsCeiling() public {
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 1_000 ether;
        amounts_[1] = 1_000 ether;
        assertTrue(vm.isIsolateMode());
        money.exchangeBundleInForSingleOut(amounts_, address(vault), 0, address(this), false, block.timestamp);
        assertLe(vm.lastFrameGas().gasTotalUsed, 11_900_000);
    }

    /// forge-config: default.isolate = true
    function test_gasBundleOutFitsCeiling() public {
        address[] memory tokens_ = new address[](2);
        tokens_[0] = address(token0);
        tokens_[1] = address(token1);
        uint256[] memory mins_ = new uint256[](2);
        assertTrue(vm.isIsolateMode());
        money.exchangeBundleOut(address(vault), 1_000 ether, tokens_, mins_, address(this), false, block.timestamp);
        assertLe(vm.lastFrameGas().gasTotalUsed, 11_900_000);
    }

    /// forge-config: default.isolate = true
    function test_gasDonateFitsCeiling() public {
        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        _fund(feeTo_, 10 ether, 0);
        vm.startPrank(feeTo_);
        IERC20(address(token0)).approve(address(vault), type(uint256).max);
        assertTrue(vm.isIsolateMode());
        money.donate(address(token0), 1 ether, false);
        uint256 used_ = vm.lastFrameGas().gasTotalUsed;
        vm.stopPrank();
        assertLe(used_, 11_900_000);
    }

    function test_incompleteExitRevertsAmountOutNotMetAndDoesNotBurn() public {
        uint128 position_ = IFullSpreadPosition(address(vault)).positionLiquidity();
        assertGt(position_, 0);
        assertEq(StateLibrary.getLiquidity(pool, key.toId()), position_, "vault position is the only liquidity");
        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 feeShares_ = money.balanceOf(feeTo_);
        if (feeShares_ != 0) {
            vm.prank(feeTo_);
            IERC20(address(vault)).transfer(address(this), feeShares_);
        }
        uint256 shares_ = money.balanceOf(address(this));
        uint256 supply_ = money.totalSupply();
        assertGt(shares_, 0);
        address recipient_ = makeAddr("incompleteExit");
        uint256 caller0_ = token0.balanceOf(address(this));
        uint256 caller1_ = token1.balanceOf(address(this));
        uint256 recip0_ = token0.balanceOf(recipient_);
        uint256 recip1_ = token1.balanceOf(recipient_);
        uint256 vault0_ = token0.balanceOf(address(vault));
        uint256 vault1_ = token1.balanceOf(address(vault));
        try money.exchangeIn(address(vault), shares_, address(token1), 0, recipient_, false, block.timestamp) returns (
            uint256, uint256
        ) {
            assertTrue(false, "incomplete exit must revert");
        } catch (bytes memory err_) {
            assertGe(err_.length, 4);
            assertEq(bytes4(err_), IStandardExchangeErrors.AmountOutNotMet.selector);
        }
        assertEq(money.balanceOf(address(this)), shares_);
        assertEq(money.totalSupply(), supply_);
        assertEq(token0.balanceOf(address(this)), caller0_);
        assertEq(token1.balanceOf(address(this)), caller1_);
        assertEq(token0.balanceOf(recipient_), recip0_);
        assertEq(token1.balanceOf(recipient_), recip1_);
        assertEq(token0.balanceOf(address(vault)), vault0_);
        assertEq(token1.balanceOf(address(vault)), vault1_);
    }

}

interface IFullSpreadPosition {
    function positionLiquidity() external view returns (uint128);
    function tickLower() external view returns (int24);
    function tickUpper() external view returns (int24);
}

contract UniswapV4FullSpreadStandardExchangeVault_MoneyCompoundGas_Test is TestBase_UniswapV4FullSpreadStandardExchangeVault {
    IFullSpreadMoney internal money;

    function setUp() public override {
        super.setUp();
        money = IFullSpreadMoney(address(vault));
        _fund(address(this), 2_000_000 ether, 2_000_000 ether);
        _approve(address(vault));
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 100_000 ether;
        amounts_[1] = 100_000 ether;
        money.exchangeBundleInForSingleOut(amounts_, address(vault), 0, address(this), false, block.timestamp);
        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        _fund(feeTo_, 10 ether, 0);
        vm.startPrank(feeTo_);
        IERC20(address(token0)).approve(address(vault), type(uint256).max);
        money.donate(address(token0), 1 ether, false);
        vm.stopPrank();
    }

    /// forge-config: default.isolate = true
    function test_gasCompoundFitsCeiling() public {
        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        vm.prank(feeTo_);
        assertTrue(vm.isIsolateMode());
        money.compound();
        assertLe(vm.lastFrameGas().gasTotalUsed, 11_900_000);
    }
}

contract UniswapV4FullSpreadStandardExchangeVault_OneSidedAndExit_Test is TestBase_UniswapV4FullSpreadStandardExchangeVault {
    using PoolIdLibrary for PoolKey;

    IFullSpreadMoney internal money;

    function setUp() public override {
        super.setUp();
        money = IFullSpreadMoney(address(vault));
        _fund(address(this), 4_000_000 ether, 4_000_000 ether);
        _approve(address(vault));
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 100_000 ether;
        amounts_[1] = 100_000 ether;
        money.exchangeBundleInForSingleOut(amounts_, address(vault), 0, address(this), false, block.timestamp);
    }

    function test_oneSidedMintRefundsOnlyInputToken() public {
        uint256 snap_ = vm.snapshotState();
        _pushTo(true);
        _assertSuccessfulMint(address(token0), address(token1));
        vm.revertToState(snap_);
        _pushTo(false);
        _assertSuccessfulMint(address(token1), address(token0));
    }

    function test_spotOneSidedMintRefundsOnlyInputToken() public {
        _assertSuccessfulMint(address(token0), address(token1));
        _assertSuccessfulMint(address(token1), address(token0));
    }

    function test_oneTokenDonateSwapsAndBooksInputRemainder() public {
        uint256 snap_ = vm.snapshotState();
        _assertOneTokenDonate(address(token0));
        vm.revertToState(snap_);
        _assertOneTokenDonate(address(token1));
    }

    function test_oneTokenCompoundDoesNotRefund() public {
        _bookWithoutSwap(address(token0));
        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 feeToBefore_ = token0.balanceOf(feeTo_);
        uint256 otherBefore_ = token1.balanceOf(address(vault));
        vm.prank(feeTo_);
        money.compound();
        assertEq(token0.balanceOf(feeTo_), feeToBefore_, "compound does not refund");
        assertEq(token1.balanceOf(address(vault)), otherBefore_, "compound does not book the other token");
    }

    function test_outsidePositionAddsWantedToken() public {
        uint256 snap_ = vm.snapshotState();
        _pushTo(true);
        _assertOutside(address(token0), address(token1));
        vm.revertToState(snap_);
        _pushTo(false);
        _assertOutside(address(token1), address(token0));
    }

    function test_oneTokenExitReceiptIsProceedsPlusWithdrawn() public {
        _addCounterparty();
        _assertExitReceipt(address(token0));
        _assertExitReceipt(address(token1));
    }

    function test_oneTokenExitMinimumIsNotStalePreview() public {
        _addCounterparty();
        uint256 shares_ = 20 ether;
        (uint256 stale_,) = money.previewExchangeIn(address(vault), shares_, address(token0));
        stale_;
        _movePool();
        address recipient_ = makeAddr("staleExit");
        uint256 before_ = token0.balanceOf(recipient_);
        (uint256 out_,) = money.exchangeIn(address(vault), shares_, address(token0), 0, recipient_, false, block.timestamp);
        assertEq(out_, token0.balanceOf(recipient_) - before_);
    }

    struct MoneyTrace {
        uint256 swaps;
        uint256 spent;
        uint256 received;
        uint256 adds;
        uint256 removes;
        uint256 collects;
        uint128 added;
        uint160 priceAfterSwap;
        uint256 firstModify;
        uint256 firstSwap;
    }

    struct ExitClaim {
        uint256 supply;
        uint256 liquidity;
        uint256 principal0;
        uint256 principal1;
        uint256 fee0;
        uint256 fee1;
        uint256 booked0;
        uint256 booked1;
    }

    /// @notice M01/P01: both faces use one whole 49% swap and consume its output in the add.
    function test_M01_P01_eachFaceMintUsesWhole49PercentAndNetPreview() public {
        for (uint256 i_; i_ < 2; ++i_) {
            uint256 snap_ = vm.snapshotState();
            address input_ = i_ == 0 ? address(token0) : address(token1);
            address other_ = i_ == 0 ? address(token1) : address(token0);
            address recipient_ = makeAddr("netMintRecipient");
            uint256 before_ = IERC20(input_).balanceOf(address(this));
            uint256 otherBefore_ = IERC20(other_).balanceOf(address(vault));
            (uint256 preview_,) = money.previewExchangeIn(input_, 1_000 ether, address(vault));
            vm.recordLogs();
            (uint256 out_, uint256 refund_) =
                money.exchangeIn(input_, 1_000 ether, address(vault), preview_, recipient_, false, block.timestamp);
            Vm.Log[] memory logs_ = vm.getRecordedLogs();
            MoneyTrace memory trace_ = _moneyTrace(logs_, i_ == 0);
            assertEq(_transfers(logs_, input_, address(this), address(vault)), 1_000 ether);
            assertEq(_transfers(logs_, input_, address(vault), address(this)), refund_);
            assertEq(trace_.swaps, 1);
            assertEq(trace_.spent, FullMath.mulDiv(1_000 ether, 49, 100));
            assertGt(trace_.received, 0);
            assertEq(trace_.adds, 1);
            assertLt(trace_.firstSwap, trace_.firstModify);
            (uint256 pay0_, uint256 pay1_) = _addAmounts(trace_.priceAfterSwap, trace_.added);
            assertEq(i_ == 0 ? pay1_ : pay0_, trace_.received, "add consumes the entire swap output");
            assertEq(refund_, 1_000 ether - trace_.spent - (i_ == 0 ? pay0_ : pay1_));
            assertEq(IERC20(input_).balanceOf(address(this)), before_ - 1_000 ether + refund_);
            assertEq(IERC20(other_).balanceOf(address(vault)), otherBefore_);
            assertEq(out_, preview_);
            assertEq(money.balanceOf(recipient_), out_);
            assertGt(out_, 0);
            assertTrue(vm.revertToState(snap_));
        }
    }

    /// @notice M02/M06: exact lower/upper bounds and outside prices exercise both faces and both maintenance calls.
    function test_M02_M06_eachBoundaryAndOutsideRefundVersusBooking() public {
        for (uint256 side_; side_ < 4; ++side_) {
            uint256 snap_ = vm.snapshotState();
            bool below_ = side_ < 2;
            uint160 price_ = TickMath.getSqrtPriceAtTick(
                below_ ? TickMath.minUsableTick(60) : TickMath.maxUsableTick(60)
            );
            if (side_ == 1) --price_;
            if (side_ == 3) ++price_;
            _freshMarket(price_, 60);
            address wanted_ = below_ ? address(token0) : address(token1);
            address other_ = below_ ? address(token1) : address(token0);
            _fund(address(this), 10 ** 32, 10 ** 32);
            money.exchangeIn(wanted_, 10 ** 30, address(vault), 0, address(this), false, block.timestamp);
            assertEq(_price(), price_);
            _boundaryMoney(wanted_, true, price_);
            _boundaryMoney(other_, false, price_);
            assertTrue(vm.revertToState(snap_));
        }
    }

    /// @notice M03: tiny and partially spendable candidates keep neither a swap nor an add.
    function test_M03_collapsedAndPartialQuoteRefundWholeInput() public {
        for (uint256 i_; i_ < 2; ++i_) {
            address input_ = i_ == 0 ? address(token0) : address(token1);
            _collapsedMint(input_, 1);
            // This 49% input exceeds all full-range liquidity through the unbounded limit.
            // Its quote spends a positive strict subset; retaining that smaller swap is forbidden.
            uint256 huge_ = 10 ** 60;
            if (i_ == 0) token0.mint(address(this), huge_);
            else token1.mint(address(this), huge_);
            Types.SwapQuote memory partial_ =
                SwapProjection.exactInput(pool, key, i_ == 0, FullMath.mulDiv(huge_, 49, 100));
            assertGt(partial_.spent, 0);
            assertLt(partial_.spent, FullMath.mulDiv(huge_, 49, 100), "regression requires a partial quote");
            _collapsedMint(input_, huge_);
        }
    }

    /// @notice M04: first deposits at/below the floor, collapsed, and pretransfer over-max all roll back.
    function test_M04_firstMintFloorIncludesZeroAndPretransferOvermax() public {
        _freshMarket(uint160(1) << 96, 60);
        for (uint256 amount_ = 999; amount_ <= 1000; ++amount_) {
            uint256 before0_ = token0.balanceOf(address(this));
            uint256 before1_ = token1.balanceOf(address(this));
            vm.expectRevert(IVault.MinLiquidityNotMet.selector);
            _bundle(amount_, amount_, 0, address(this), false);
            assertEq(token0.balanceOf(address(this)), before0_);
            assertEq(token1.balanceOf(address(this)), before1_);
            _assertEmptyPosition();
        }
        vm.expectRevert(IVault.MinLiquidityNotMet.selector);
        money.exchangeIn(address(token0), 1 ether, address(vault), 0, address(this), false, block.timestamp);
        _assertEmptyPosition();
        token0.transfer(address(vault), 1);
        uint256 before_ = token0.balanceOf(address(this));
        vm.expectRevert(IVault.MinLiquidityNotMet.selector);
        money.exchangeIn(address(token0), 2, address(vault), 0, address(this), true, block.timestamp);
        assertEq(token0.balanceOf(address(vault)), 1, "no refund before first-deposit floor");
        assertEq(token0.balanceOf(address(this)), before_);
        _assertEmptyPosition();
    }

    /// @notice M04: a first zero add at either stored bound or outside cannot become a refund success.
    function test_M04_firstUnwantedBoundaryAndOutsideMintRevertsFloor() public {
        for (uint256 side_; side_ < 4; ++side_) {
            uint256 snap_ = vm.snapshotState();
            bool below_ = side_ < 2;
            uint160 price_ = TickMath.getSqrtPriceAtTick(
                below_ ? TickMath.minUsableTick(60) : TickMath.maxUsableTick(60)
            );
            if (side_ == 1) --price_;
            if (side_ == 3) ++price_;
            _freshMarket(price_, 60);
            address other_ = below_ ? address(token1) : address(token0);
            uint256 before_ = IERC20(other_).balanceOf(address(this));
            vm.expectRevert(IVault.MinLiquidityNotMet.selector);
            money.exchangeIn(other_, 1 ether, address(vault), 0, address(this), false, block.timestamp);
            assertEq(IERC20(other_).balanceOf(address(this)), before_);
            _assertEmptyPosition();
            assertTrue(vm.revertToState(snap_));
        }
    }

    /// @notice M05/M17: fees are collected before sizing the combined booked, fee, and donation input.
    function test_M05_M17_oneTokenMaintenanceUsesCombinedBalance() public {
        for (uint256 face_; face_ < 2; ++face_) {
            for (uint256 donate_; donate_ < 2; ++donate_) {
                uint256 snap_ = vm.snapshotState();
                _poolFees(face_ == 0 ? 10 ether : 0, face_ == 0 ? 0 : 10 ether);
                _bundle(1 ether, 1 ether, 0, address(this), false);
                address input_ = face_ == 0 ? address(token0) : address(token1);
                uint256 booked_ = IERC20(input_).balanceOf(address(vault));
                assertGt(booked_, 0);
                _poolFees(face_ == 0 ? 5 ether : 0, face_ == 0 ? 0 : 5 ether);
                (uint256 fee0_, uint256 fee1_) = _unpaid();
                uint256 fee_ = face_ == 0 ? fee0_ : fee1_;
                assertGt(fee_, 0);
                uint256 donation_ = donate_ == 0 ? 0 : 3 ether;
                address feeTo_ = _feeTo();
                _fund(feeTo_, donation_, donation_);
                vm.startPrank(feeTo_);
                IERC20(input_).approve(address(vault), type(uint256).max);
                uint256 before_ = IERC20(input_).balanceOf(feeTo_);
                vm.recordLogs();
                if (donate_ == 0) money.compound();
                else money.donate(input_, donation_, false);
                vm.stopPrank();
                Vm.Log[] memory logs_ = vm.getRecordedLogs();
                MoneyTrace memory trace_ = _moneyTrace(logs_, face_ == 0);
                assertEq(trace_.collects, 1);
                assertLt(trace_.firstModify, trace_.firstSwap, "collect before sizing swap executes");
                assertEq(trace_.swaps, 1);
                assertEq(trace_.spent, FullMath.mulDiv(booked_ + fee_ + donation_, 49, 100));
                assertGt(trace_.received, 0);
                assertEq(trace_.adds, 1);
                (uint256 pay0_, uint256 pay1_) = _addAmounts(trace_.priceAfterSwap, trace_.added);
                assertEq(face_ == 0 ? pay1_ : pay0_, trace_.received);
                assertEq(
                    IERC20(input_).balanceOf(address(vault)),
                    booked_ + fee_ + donation_
                        - _transfers(logs_, input_, address(vault), address(pool)),
                    "book actual settlement remainder, including fees accrued by the balancing swap"
                );
                assertEq(IERC20(input_).balanceOf(feeTo_), before_ - donation_, "no maintenance refund");
                assertTrue(vm.revertToState(snap_));
            }
        }
    }

    /// @notice M05/M12/M17: both-token maintenance deposits without swapping and emits Compounded.
    function test_M05_M12_M17_bothTokenMaintenanceNeverSwaps() public {
        for (uint256 donate_; donate_ < 2; ++donate_) {
            uint256 snap_ = vm.snapshotState();
            _poolFees(10 ether, 20 ether);
            vm.recordLogs();
            vm.prank(_feeTo());
            if (donate_ == 0) money.compound();
            else money.donate(address(token0), 0, false);
            Vm.Log[] memory logs_ = vm.getRecordedLogs();
            MoneyTrace memory trace_ = _moneyTrace(logs_, true);
            assertEq(trace_.collects, 1);
            assertEq(trace_.swaps, 0);
            assertEq(trace_.adds, 1);
            _markers(logs_, donate_ != 0, true);
            // A remaining booked token is not a failure and can be processed again.
            vm.prank(_feeTo());
            money.compound();
            assertTrue(vm.revertToState(snap_));
        }
    }

    /// @notice M03/M06/M12: collapsed maintenance input is booked and remains processable.
    function test_M06_collapsedMaintenanceBooksInsteadOfRefunding() public {
        for (uint256 i_; i_ < 2; ++i_) {
            uint256 snap_ = vm.snapshotState();
            address input_ = i_ == 0 ? address(token0) : address(token1);
            _collapsedMaintenance(input_, 1);
            _collapsedMaintenance(input_, 10 ** 60);
            assertTrue(vm.revertToState(snap_));
        }
    }

    function _collapsedMaintenance(address input_, uint256 amount_) internal {
        address feeTo_ = _feeTo();
        _fund(feeTo_, amount_, amount_);
        uint256 booked_ = IERC20(input_).balanceOf(address(vault));
        vm.startPrank(feeTo_);
        IERC20(input_).approve(address(vault), type(uint256).max);
        vm.recordLogs();
        money.donate(input_, amount_, false);
        Vm.Log[] memory donationLogs_ = vm.getRecordedLogs();
        assertEq(_moneyTrace(donationLogs_, true).swaps, 0);
        assertEq(_moneyTrace(donationLogs_, true).adds, 0);
        _markers(donationLogs_, true, false);
        assertEq(IERC20(input_).balanceOf(address(vault)), booked_ + amount_);
        uint256 before_ = IERC20(input_).balanceOf(feeTo_);
        vm.recordLogs();
        money.compound();
        Vm.Log[] memory compoundLogs_ = vm.getRecordedLogs();
        assertEq(_moneyTrace(compoundLogs_, true).swaps, 0);
        assertEq(_moneyTrace(compoundLogs_, true).adds, 0);
        _markers(compoundLogs_, false, false);
        assertEq(IERC20(input_).balanceOf(address(vault)), booked_ + amount_);
        assertEq(IERC20(input_).balanceOf(feeTo_), before_);
        vm.stopPrank();
    }

    /// @notice M07: pass-through has no mint, fee collection or liquidity modification in either direction.
    function test_M07_passThroughBothWaysAndMinimumRollback() public {
        vm.expectCall(address(vault), abi.encodeWithSelector(IFullSpreadMoney.compound.selector), uint64(0));
        for (uint256 i_; i_ < 2; ++i_) {
            uint256 snap_ = vm.snapshotState();
            address input_ = i_ == 0 ? address(token0) : address(token1);
            address output_ = i_ == 0 ? address(token1) : address(token0);
            uint256 supply_ = money.totalSupply();
            uint256 booked0_ = token0.balanceOf(address(vault));
            uint256 booked1_ = token1.balanceOf(address(vault));
            uint256 feeShares_ = money.balanceOf(_feeTo());
            address recipient_ = makeAddr("passThroughRecipient");
            uint256 before_ = IERC20(input_).balanceOf(address(this));
            vm.recordLogs();
            (uint256 out_, uint256 refund_) =
                money.exchangeIn(input_, 1 ether, output_, 0, recipient_, false, block.timestamp);
            Vm.Log[] memory logs_ = vm.getRecordedLogs();
            MoneyTrace memory trace_ = _moneyTrace(logs_, i_ == 0);
            _markers(logs_, false, false);
            assertEq(trace_.swaps, 1);
            assertEq(trace_.spent + refund_, 1 ether);
            assertEq(trace_.received, out_);
            assertEq(IERC20(output_).balanceOf(recipient_), out_);
            assertEq(IERC20(input_).balanceOf(address(this)), before_ - trace_.spent);
            assertEq(trace_.adds + trace_.removes + trace_.collects, 0);
            assertEq(money.totalSupply(), supply_);
            assertEq(money.balanceOf(_feeTo()), feeShares_);
            assertEq(token0.balanceOf(address(vault)), booked0_);
            assertEq(token1.balanceOf(address(vault)), booked1_);
            assertTrue(vm.revertToState(snap_));
            vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, out_ + 1, out_));
            money.exchangeIn(input_, 1 ether, output_, out_ + 1, recipient_, false, block.timestamp);
            assertEq(money.totalSupply(), supply_);
            assertEq(IERC20(output_).balanceOf(recipient_), 0);
        }
    }

    /// @notice M07: a real partial exact-input fill refunds the unused input in either direction.
    function test_M07_partialPassThroughRefundsUnusedInputBothWays() public {
        for (uint256 i_; i_ < 2; ++i_) {
            uint256 snap_ = vm.snapshotState();
            _freshMarket(uint160(1) << 96, 60);
            _bundle(10_000, 10_000, 0, address(this), false);
            _fund(address(this), 10 ** 30, 10 ** 30);
            address input_ = i_ == 0 ? address(token0) : address(token1);
            address output_ = i_ == 0 ? address(token1) : address(token0);
            uint256 before_ = IERC20(input_).balanceOf(address(this));
            uint256 supply_ = money.totalSupply();
            uint128 liquidity_ = IFullSpreadPosition(address(vault)).positionLiquidity();
            address recipient_ = makeAddr("partialPassThroughRecipient");
            vm.recordLogs();
            (uint256 out_, uint256 refund_) =
                money.exchangeIn(input_, 10 ** 30, output_, 0, recipient_, false, block.timestamp);
            MoneyTrace memory trace_ = _moneyTrace(vm.getRecordedLogs(), i_ == 0);
            assertEq(trace_.swaps, 1);
            assertGt(trace_.spent, 0);
            assertGt(refund_, 0);
            assertEq(trace_.spent + refund_, 10 ** 30);
            assertEq(IERC20(input_).balanceOf(address(this)), before_ - trace_.spent);
            assertEq(IERC20(output_).balanceOf(recipient_), out_);
            assertEq(trace_.received, out_);
            assertEq(trace_.adds + trace_.removes + trace_.collects, 0);
            assertEq(money.totalSupply(), supply_);
            assertEq(IFullSpreadPosition(address(vault)).positionLiquidity(), liquidity_);
            assertEq(token0.balanceOf(address(vault)), 0);
            assertEq(token1.balanceOf(address(vault)), 0);
            assertTrue(vm.revertToState(snap_));
        }
    }

    /// @notice M08: removing almost all liquidity cannot leave an opposing claim, even with minimum zero.
    function test_M08_incompleteExitBothFacesDoesNotBurnOrSwapStayingInventory() public {
        address feeTo_ = _feeTo();
        uint256 feeShares_ = money.balanceOf(feeTo_);
        vm.prank(feeTo_);
        IERC20(address(vault)).transfer(address(this), feeShares_);
        for (uint256 i_; i_ < 2; ++i_) {
            uint256 shares_ = money.balanceOf(address(this));
            bytes32 before_ = _custody();
            vm.expectPartialRevert(IStandardExchangeErrors.AmountOutNotMet.selector);
            money.exchangeIn(
                address(vault), shares_, i_ == 0 ? address(token0) : address(token1),
                0, address(this), false, block.timestamp
            );
            assertEq(_custody(), before_, "incomplete exit restores caller, vault, position and pool");
        }
    }

    /// @notice M09: a real four-part receipt includes nonzero fee and booked claims, without double counting.
    function test_M09_exitBothFacesPaysFourPartExecutedReceipt() public {
        _addCounterparty();
        _poolFees(20 ether, 30 ether);
        _bundle(1 ether, 1 ether, 0, address(this), false);
        assertGt(token0.balanceOf(address(vault)), 0);
        assertGt(token1.balanceOf(address(vault)), 0);
        _poolFees(10 ether, 15 ether);
        for (uint256 i_; i_ < 2; ++i_) {
            uint256 snap_ = vm.snapshotState();
            uint256 shares_ = money.balanceOf(address(this)) / 10;
            ExitClaim memory claim_ = _exitClaim(shares_);
            uint256 receipt_ = _fourPartExit(i_ == 0, shares_, claim_);
            assertTrue(vm.revertToState(snap_));
            bytes32 before_ = _custody();
            vm.expectPartialRevert(IStandardExchangeErrors.AmountOutNotMet.selector);
            money.exchangeIn(
                address(vault), shares_, i_ == 0 ? address(token0) : address(token1),
                receipt_ + 1, makeAddr("fourPartRecipient"), false, block.timestamp
            );
            assertEq(_custody(), before_);
        }
    }

    /// @notice M10: bundle exits honor caller order, both indexed minima, marker and no-swap rule.
    function test_M10_bundleOutBothOrdersAndEachMinimumIndex() public {
        for (uint256 order_; order_ < 2; ++order_) {
            uint256 snap_ = vm.snapshotState();
            address[] memory faces_ = _orderedFaces(order_ != 0);
            uint256 shares_ = money.balanceOf(address(this)) / 10;
            (uint256[] memory expected_,) = money.previewExchangeBundleOut(address(vault), shares_, faces_);
            for (uint256 index_; index_ < 2; ++index_) {
                uint256[] memory mins_ = new uint256[](2);
                mins_[index_] = expected_[index_] + 1;
                bytes32 before_ = _custody();
                vm.expectRevert(abi.encodeWithSelector(
                    IStandardExchangeBundleIn.MinAmountNotMetAt.selector, index_, mins_[index_], expected_[index_]
                ));
                money.exchangeBundleOut(address(vault), shares_, faces_, mins_, address(this), false, block.timestamp);
                assertEq(_custody(), before_);
            }
            address recipient_ = makeAddr("bundleExitRecipient");
            vm.recordLogs();
            (uint256[] memory out_, uint256 refund_) =
                money.exchangeBundleOut(address(vault), shares_, faces_, expected_, recipient_, false, block.timestamp);
            Vm.Log[] memory logs_ = vm.getRecordedLogs();
            assertEq(_moneyTrace(logs_, true).swaps, 0);
            _callerMarker(logs_, IVault.PairRedeemed.selector);
            assertEq(refund_, 0);
            for (uint256 i_; i_ < 2; ++i_) {
                assertEq(out_[i_], expected_[i_]);
                assertEq(IERC20(faces_[i_]).balanceOf(recipient_), out_[i_]);
                assertGt(out_[i_], 0);
            }
            assertTrue(vm.revertToState(snap_));
        }
    }

    /// @notice M11/P01: the add books pre-existing fees; neither fees nor refunds are depositor share credit.
    function test_M11_bundleBooksFeesAndRefundsInVaultTokenOrder() public {
        _poolFees(10 ether, 20 ether);
        (uint256 fee0_, uint256 fee1_) = _unpaid();
        uint256 supply_ = money.totalSupply();
        uint128 liquidity_ = IFullSpreadPosition(address(vault)).positionLiquidity();
        uint256 before0_ = token0.balanceOf(address(this));
        uint256 before1_ = token1.balanceOf(address(this));
        uint256 feeShares_ = money.balanceOf(_feeTo());
        address recipient_ = makeAddr("bundleMintRecipient");
        vm.recordLogs();
        (uint256 out_, uint256[] memory refund_) = _bundle(2_000 ether, 1_000 ether, 0, recipient_, false);
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        MoneyTrace memory trace_ = _moneyTrace(logs_, true);
        assertEq(trace_.swaps, 0);
        assertEq(trace_.adds, 1);
        _callerMarker(logs_, IVault.PairDeposited.selector);
        uint256 gross_ = FullMath.mulDiv(trace_.added, supply_, liquidity_);
        assertEq(money.totalSupply() - supply_, gross_);
        assertEq(out_ + money.balanceOf(_feeTo()) - feeShares_, gross_);
        assertEq(money.balanceOf(recipient_), out_);
        assertEq(token0.balanceOf(address(vault)), fee0_);
        assertEq(token1.balanceOf(address(vault)), fee1_);
        assertEq(token0.balanceOf(address(this)), before0_ - 2_000 ether + refund_[0]);
        assertEq(token1.balanceOf(address(this)), before1_ - 1_000 ether + refund_[1]);
        assertGt(refund_[0], refund_[1]);
        uint256 snap_ = vm.snapshotState();
        (uint256 learned_,) = _bundle(2_000 ether, 1_000 ether, 0, recipient_, false);
        assertTrue(vm.revertToState(snap_));
        vm.expectRevert(abi.encodeWithSelector(
            IStandardExchangeBundleIn.MinAmountNotMetAt.selector, 0, learned_ + 1, learned_
        ));
        _bundle(2_000 ether, 1_000 ether, learned_ + 1, recipient_, false);
    }

    /// @notice M12/M17: empty maintenance is inert; a fresh donation is not a Compounded event.
    function test_M12_M17_emptyFreshAndRevertingMaintenanceMarkers() public {
        bytes32 before_ = _custody();
        vm.recordLogs();
        vm.prank(_feeTo());
        money.compound();
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        _markers(logs_, false, false);
        assertEq(_moneyTrace(logs_, true).collects, 0);
        assertEq(_moneyTrace(logs_, true).adds, 0);
        assertEq(_custody(), before_);
        address feeTo_ = _feeTo();
        _fund(feeTo_, 1 ether, 0);
        vm.startPrank(feeTo_);
        token0.approve(address(vault), type(uint256).max);
        vm.recordLogs();
        money.donate(address(token0), 1 ether, false);
        logs_ = vm.getRecordedLogs();
        _markers(logs_, true, false);
        assertEq(_moneyTrace(logs_, true).collects, 0, "zero unpaid read does not poke");
        vm.stopPrank();
        before_ = _custody();
        vm.recordLogs();
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, address(this)));
        money.donate(address(token0), 1 ether, false);
        _markers(vm.getRecordedLogs(), false, false);
        assertEq(_custody(), before_);
        // An authorized funding failure is atomic too, rather than a caught maintenance step.
        vm.startPrank(feeTo_);
        token0.approve(address(vault), 0);
        vm.recordLogs();
        vm.expectRevert();
        money.donate(address(token0), 1 ether, false);
        vm.stopPrank();
        _markers(vm.getRecordedLogs(), false, false);
        assertEq(_custody(), before_);
    }

    /// @notice M13: disable exceptions preserve all other route and minimum checks.
    function test_M13_disabledRouteMatrixAndEnabledOutRollback() public {
        bytes32 before_ = _custody();
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        IStandardExchangeOut(address(vault)).exchangeOut(
            IERC20(address(token0)), 1 ether, IERC20(address(vault)), type(uint256).max,
            address(this), false, block.timestamp
        );
        assertEq(_custody(), before_);
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(vault), true);
        bytes memory disabled_ = abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, address(vault));
        vm.expectRevert(disabled_);
        money.exchangeIn(address(token0), 1 ether, address(token1), 0, address(this), false, block.timestamp);
        vm.expectRevert(disabled_);
        _bundle(1 ether, 1 ether, 0, address(this), false);
        vm.expectRevert(disabled_);
        IStandardExchangeOut(address(vault)).exchangeOut(
            IERC20(address(token0)), 1 ether, IERC20(address(vault)), type(uint256).max,
            address(this), false, block.timestamp
        );
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, 0, block.timestamp));
        money.exchangeBundleOut(address(vault), 1, _orderedFaces(false), new uint256[](2), address(this), false, 0);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, 0, block.timestamp));
        money.exchangeBundleInForSingleOut(new uint256[](2), address(vault), 0, address(this), false, 0);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, 0, block.timestamp));
        IStandardExchangeOut(address(vault)).exchangeOut(
            IERC20(address(token0)), 1 ether, IERC20(address(vault)), 1 ether, address(this), false, 0
        );
        vm.expectPartialRevert(IStandardExchangeErrors.AmountOutNotMet.selector);
        money.exchangeIn(address(vault), 100 ether, address(token0), type(uint256).max, address(this), false, block.timestamp);
        vm.expectRevert(IVault.InvalidRecipient.selector);
        money.exchangeIn(address(vault), 100 ether, address(token0), 0, address(0), false, block.timestamp);
        uint256[] memory out_;
        (out_,) = money.exchangeBundleOut(
            address(vault), 100 ether, _orderedFaces(false), new uint256[](2), address(this), false, block.timestamp
        );
        assertGt(out_[0], 0);
        assertGt(out_[1], 0);
        _fund(_feeTo(), 1 ether, 0);
        vm.startPrank(_feeTo());
        token0.approve(address(vault), type(uint256).max);
        money.donate(address(token0), 1 ether, false);
        money.compound();
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, address(this)));
        money.donate(address(token0), 0, false);
        vm.prank(_feeTo());
        vm.expectRevert(IVault.TokenNotExchangeable.selector);
        money.donate(address(0), 1, false);
        (uint256 preview_,) = money.previewExchangeIn(address(token0), 1 ether, address(vault));
        assertGt(preview_, 0);
        (bool ok_,) = address(vault).staticcall(abi.encodeWithSignature("reserves()"));
        assertTrue(ok_);
        assertEq(IStandardExchangeOut(address(vault)).previewExchangeOut(
            IERC20(address(token0)), IERC20(address(vault)), 1 ether
        ), 0);
    }

    /// @notice M14: genesis creates exactly the diamond's full-range salt-zero position and floor supply.
    function test_M14_genesisFloorPositionAndFeeAreNotExtraIssuance() public {
        _freshMarket(uint160(1) << 96, 60);
        _setFee(1 ether);
        address feeTo_ = _feeTo();
        vm.recordLogs();
        (uint256 out_,) = _bundle(10_000 ether, 10_000 ether, 0, address(this), false);
        MoneyTrace memory trace_ = _moneyTrace(vm.getRecordedLogs(), true);
        assertEq(trace_.adds, 1);
        assertEq(trace_.swaps, 0);
        assertEq(money.balanceOf(address(0)), 1000);
        assertEq(money.totalSupply(), trace_.added);
        uint256 gross_ = uint256(trace_.added) - 1000;
        assertEq(money.balanceOf(feeTo_), FullMath.mulDiv(gross_, 3e17, 1e18));
        assertEq(out_ + money.balanceOf(feeTo_), gross_);
        (uint128 liquidity_,,) = StateLibrary.getPositionInfo(
            pool, key.toId(), address(vault), TickMath.minUsableTick(60), TickMath.maxUsableTick(60), bytes32(0)
        );
        assertEq(liquidity_, trace_.added);
        assertEq(StateLibrary.getLiquidity(pool, key.toId()), trace_.added, "one position and one owner");
        assertEq(IFullSpreadPosition(address(vault)).tickLower(), TickMath.minUsableTick(60));
        assertEq(IFullSpreadPosition(address(vault)).tickUpper(), TickMath.maxUsableTick(60));
    }

    /// @notice FS-A05/11: one-sided genesis splits raw liquidity after the floor without maintenance.
    function test_M14_oneSidedGenesisFloorAndFeeBothFaces() public {
        uint256 snapshot_ = vm.snapshotState();
        address monitoredVault_;
        for (uint256 i_; i_ < 2; ++i_) {
            _freshMarket(uint160(1) << 96, 60);
            _addCounterparty();
            _setFee(1 ether);
            address input_ = i_ == 0 ? address(token0) : address(token1);
            address recipient_ = makeAddr("one sided genesis recipient");
            if (i_ == 0) {
                monitoredVault_ = address(vault);
                vm.expectCall(monitoredVault_, abi.encodeWithSelector(IFullSpreadMoney.compound.selector), uint64(0));
            } else {
                assertEq(address(vault), monitoredVault_, "both restored cases use the monitored vault");
            }
            vm.recordLogs();
            (uint256 net_,) = money.exchangeIn(
                input_, 1_000 ether, address(vault), 0, recipient_, false, block.timestamp
            );
            Vm.Log[] memory logs_ = vm.getRecordedLogs();
            MoneyTrace memory trace_ = _moneyTrace(logs_, i_ == 0);
            assertEq(trace_.adds, 1);
            assertEq(trace_.swaps, 1);
            uint256 gross_ = uint256(trace_.added) - 1000;
            uint256 fee_ = FullMath.mulDiv(gross_, 3e17, 1e18);
            assertEq(money.balanceOf(address(0)), 1000);
            assertEq(money.balanceOf(_feeTo()), fee_);
            assertEq(money.balanceOf(recipient_), net_);
            assertEq(net_ + fee_, gross_);
            assertEq(money.totalSupply(), trace_.added, "no extra fee issuance");
            assertEq(IFullSpreadPosition(address(vault)).positionLiquidity(), trace_.added);
            _markers(logs_, false, false);
            assertTrue(vm.revertToState(snapshot_));
        }
    }

    /// @notice FS-A06/08/11: bundle receipts independently include both fee/book claims in either caller order.
    function test_M10_bundleExitPaysExactBookedAndUnpaidClaimsBothOrders() public {
        _poolFees(20 ether, 30 ether);
        _bundle(1 ether, 1 ether, 0, address(this), false);
        _poolFees(10 ether, 15 ether);
        uint256 snapshot_ = vm.snapshotState();
        vm.expectCall(address(pool), abi.encodeWithSelector(IPoolManager.swap.selector), uint64(0));
        vm.expectCall(address(vault), abi.encodeWithSelector(IFullSpreadMoney.compound.selector), uint64(0));
        for (uint256 i_; i_ < 2; ++i_) {
            uint256 shares_ = money.balanceOf(address(this)) / 10;
            ExitClaim memory claim_ = _exitClaim(shares_);
            uint256 fee0_ = FullMath.mulDiv(claim_.fee0, shares_, claim_.supply);
            uint256 fee1_ = FullMath.mulDiv(claim_.fee1, shares_, claim_.supply);
            uint256 book0_ = FullMath.mulDiv(claim_.booked0, shares_, claim_.supply);
            uint256 book1_ = FullMath.mulDiv(claim_.booked1, shares_, claim_.supply);
            assertGt(fee0_, 0);
            assertGt(fee1_, 0);
            assertGt(book0_, 0);
            assertGt(book1_, 0);
            uint256[] memory expected_ = new uint256[](2);
            expected_[i_] = claim_.principal0 + fee0_ + book0_;
            expected_[1 - i_] = claim_.principal1 + fee1_ + book1_;
            address[] memory faces_ = _orderedFaces(i_ == 1);
            address recipient_ = makeAddr("bundle claim recipient");
            vm.recordLogs();
            (uint256[] memory actual_, uint256 refund_) = money.exchangeBundleOut(
                address(vault), shares_, faces_, expected_, recipient_, false, block.timestamp
            );
            Vm.Log[] memory logs_ = vm.getRecordedLogs();
            assertEq(actual_, expected_);
            assertEq(refund_, 0);
            assertEq(token0.balanceOf(recipient_), claim_.principal0 + fee0_ + book0_);
            assertEq(token1.balanceOf(recipient_), claim_.principal1 + fee1_ + book1_);
            assertEq(token0.balanceOf(address(vault)), claim_.booked0 - book0_ + claim_.fee0 - fee0_);
            assertEq(token1.balanceOf(address(vault)), claim_.booked1 - book1_ + claim_.fee1 - fee1_);
            assertEq(money.totalSupply(), claim_.supply - shares_);
            assertEq(IFullSpreadPosition(address(vault)).positionLiquidity(),
                claim_.liquidity - FullMath.mulDiv(claim_.liquidity, shares_, claim_.supply));
            assertEq(_moneyTrace(logs_, true).swaps, 0);
            _markers(logs_, false, false);
            assertTrue(vm.revertToState(snapshot_));
        }
    }

    /// @notice M14/P01: both face previews and minima use the same precise clamped fee as execution.
    function test_M14_P01_laterIssuanceExcludesBookedAndUnpaidFees() public {
        uint256[3] memory fees_ = [uint256(1e13), uint256(3e17), uint256(1e18)];
        for (uint256 f_; f_ < fees_.length; ++f_) {
            for (uint256 face_; face_ < 2; ++face_) {
                uint256 snap_ = vm.snapshotState();
                _setFee(fees_[f_]);
                _poolFees(20 ether, 30 ether);
                _bundle(1 ether, 1 ether, 0, address(this), false);
                _poolFees(10 ether, 15 ether);
                _assertNetIssuance(face_ == 0, fees_[f_] > 3e17 ? 3e17 : fees_[f_]);
                assertTrue(vm.revertToState(snap_));
            }
        }
    }

    /// @notice M14/APEX-044: mint and redeem all new shares without reducing any old holder's backing.
    function test_M14_roundTripDoesNotTransferExistingLiquidityToFeeTo() public {
        _setFee(1 ether);
        uint256 supply_ = money.totalSupply();
        uint128 liquidity_ = IFullSpreadPosition(address(vault)).positionLiquidity();
        address feeTo_ = _feeTo();
        uint256 oldFeeShares_ = money.balanceOf(feeTo_);
        address depositor_ = makeAddr("roundTripDepositor");
        (uint256 net_,) = _bundle(1_000 ether, 1_000 ether, 0, depositor_, false);
        uint256 fee_ = money.balanceOf(feeTo_) - oldFeeShares_;
        assertEq(money.totalSupply() - supply_, net_ + fee_);
        vm.prank(depositor_);
        money.exchangeBundleOut(
            address(vault), net_, _orderedFaces(false), new uint256[](2), depositor_, false, block.timestamp
        );
        vm.prank(feeTo_);
        (uint256[] memory feeOut_,) = money.exchangeBundleOut(
            address(vault), fee_, _orderedFaces(false), new uint256[](2), feeTo_, false, block.timestamp
        );
        assertLe(feeOut_[0], 300 ether);
        assertLe(feeOut_[1], 300 ether);
        assertEq(money.balanceOf(feeTo_), oldFeeShares_);
        assertEq(money.totalSupply(), supply_);
        assertGe(IFullSpreadPosition(address(vault)).positionLiquidity(), liquidity_);
    }

    /// @notice M15: pull transfers the full declaration, refunds the payer, and mints only to the recipient.
    function test_M15_pullFullDeclarationBeforeRefundToPayer() public {
        address recipient_ = makeAddr("pullRecipient");
        uint256 callerShares_ = money.balanceOf(address(this));
        vm.recordLogs();
        (uint256 out_, uint256[] memory refund_) = _bundle(2 ether, 1 ether, 0, recipient_, false);
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        assertEq(_transfers(logs_, address(token0), address(this), address(vault)), 2 ether);
        assertEq(_transfers(logs_, address(token1), address(this), address(vault)), 1 ether);
        assertEq(_transfers(logs_, address(token0), address(vault), address(this)), refund_[0]);
        assertEq(_transfers(logs_, address(token1), address(vault), address(this)), refund_[1]);
        assertEq(money.balanceOf(address(this)), callerShares_);
        assertEq(money.balanceOf(recipient_), out_);
        assertEq(token0.balanceOf(recipient_), 0);
        assertEq(token1.balanceOf(recipient_), 0);
    }

    /// @notice M15: pretransfer respects its maximum, refunds over-max unbooked inventory, and pulls no shortfall.
    function test_M15_pretransferMaximumAndOvermaxDoNotSpendBookedInventory() public {
        _poolFees(10 ether, 0);
        _bundle(1 ether, 1 ether, 0, address(this), false);
        uint256 booked_ = token0.balanceOf(address(vault));
        assertGt(booked_, 0);
        token0.transfer(address(vault), 3 ether);
        vm.recordLogs();
        (uint256 out_, uint256 refund_) =
            money.exchangeIn(address(token0), 1 ether, address(vault), 0, address(this), true, block.timestamp);
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        assertGt(out_, 0);
        assertEq(_transfers(logs_, address(token0), address(this), address(vault)), 0);
        assertEq(_transfers(logs_, address(token0), address(vault), address(this)), refund_);
        assertGe(token0.balanceOf(address(vault)), booked_ + 2 ether, "beyond-maximum balance is untouched");
        // The balancing swap's own accrued fee was collected by the add and is booked too.
        booked_ = token0.balanceOf(address(vault)) - 2 ether;
        uint256 supply_ = money.totalSupply();
        vm.recordLogs();
        (out_, refund_) =
            money.exchangeIn(address(token0), 4 ether, address(vault), 0, address(this), true, block.timestamp);
        logs_ = vm.getRecordedLogs();
        assertEq(out_, 0);
        assertEq(refund_, 2 ether, "refund available unbooked, not the maximum");
        assertEq(money.totalSupply(), supply_);
        assertEq(token0.balanceOf(address(vault)), booked_);
        assertEq(_moneyTrace(logs_, true).swaps + _moneyTrace(logs_, true).adds, 0);
        assertEq(_transfers(logs_, address(token0), address(this), address(vault)), 0);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, 1, 0));
        money.exchangeIn(address(token0), 4 ether, address(vault), 1, address(this), true, block.timestamp);
    }

    /// @notice M15: an over-max bundle fails before either leg; an EOA cannot claim pretransfer inventory.
    function test_M15_bundleOvermaxIsAtomicAndEOAPretransferRejected() public {
        token0.transfer(address(vault), 2 ether);
        token1.transfer(address(vault), 1 ether);
        bytes32 before_ = _custody();
        vm.expectRevert();
        _bundle(1 ether, 2 ether, 0, address(this), true);
        assertEq(_custody(), before_);
        address eoa_ = makeAddr("pretransferEOA");
        vm.prank(eoa_);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        money.exchangeIn(address(token0), 1 ether, address(vault), 0, eoa_, true, block.timestamp);
        assertEq(_custody(), before_);
    }

    /// @notice M15: a valid prepaid bundle reserves only its maxima and returns positional excess.
    function test_M15_bundlePretransferWithinMaximumLeavesUnclaimedBalance() public {
        token0.transfer(address(vault), 3 ether);
        token1.transfer(address(vault), 4 ether);
        address recipient_ = makeAddr("prepaidBundleRecipient");
        vm.recordLogs();
        (uint256 net_, uint256[] memory refund_) = _bundle(2 ether, 1 ether, 0, recipient_, true);
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        assertGt(net_, 0);
        assertEq(money.balanceOf(recipient_), net_);
        assertEq(token0.balanceOf(address(vault)), 1 ether);
        assertEq(token1.balanceOf(address(vault)), 3 ether);
        assertEq(_transfers(logs_, address(token0), address(this), address(vault)), 0);
        assertEq(_transfers(logs_, address(token1), address(this), address(vault)), 0);
        assertEq(_transfers(logs_, address(token0), address(vault), address(this)), refund_[0]);
        assertEq(_transfers(logs_, address(token1), address(vault), address(this)), refund_[1]);
        assertGt(refund_[0], refund_[1]);
    }

    /// @notice M15/APEX-010/036/039: stray transfers are not redeemable idle, pull credit, or parked-share credit.
    function test_M15_directAndStagedTransfersDoNotCreateLaterCallerCredit() public {
        uint256 shares_ = money.balanceOf(address(this)) / 10;
        (uint256[] memory quote_,) =
            money.previewExchangeBundleOut(address(vault), shares_, _orderedFaces(false));
        token0.transfer(address(vault), 100 ether);
        token1.transfer(address(vault), 200 ether);
        (uint256[] memory afterQuote_,) =
            money.previewExchangeBundleOut(address(vault), shares_, _orderedFaces(false));
        assertEq(afterQuote_[0], quote_[0]);
        assertEq(afterQuote_[1], quote_[1]);
        address later_ = makeAddr("laterCaller");
        vm.prank(later_);
        vm.expectRevert();
        money.exchangeIn(address(token0), 1 ether, address(vault), 0, later_, false, block.timestamp);
        assertEq(money.balanceOf(later_), 0);
        IERC20(address(vault)).transfer(address(vault), shares_);
        vm.prank(later_);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, later_, 0, shares_));
        money.exchangeIn(address(vault), shares_, address(token0), 0, later_, false, block.timestamp);
        assertEq(money.balanceOf(address(vault)), shares_);
        assertEq(token0.balanceOf(address(vault)), 100 ether);
        assertEq(token1.balanceOf(address(vault)), 200 ether);
    }

    /// @notice M16: global and selector grants are live-feeTo appointments, not a stored-owner role.
    function test_M16_liveFeeToAndGlobalAndFunctionOperators() public {
        address oldOwner_ = _feeTo();
        address global_ = makeAddr("globalOperator");
        address donateOnly_ = makeAddr("donateOperator");
        address compoundOnly_ = makeAddr("compoundOperator");
        vm.startPrank(oldOwner_);
        IOperable(address(vault)).setOperator(global_, true);
        IOperable(address(vault)).setOperatorFor(IFullSpreadMoney.donate.selector, donateOnly_, true);
        IOperable(address(vault)).setOperatorFor(IFullSpreadMoney.compound.selector, compoundOnly_, true);
        vm.stopPrank();
        vm.prank(global_);
        money.donate(address(token0), 0, false);
        vm.prank(global_);
        money.compound();
        vm.prank(donateOnly_);
        money.donate(address(token0), 0, false);
        vm.prank(donateOnly_);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, donateOnly_));
        money.compound();
        vm.prank(compoundOnly_);
        money.compound();
        vm.prank(compoundOnly_);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, compoundOnly_));
        money.donate(address(token0), 0, false);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, address(this)));
        money.compound();
        vm.prank(global_);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, global_));
        IOperable(address(vault)).setOperator(address(this), true);
        address nextOwner_ = makeAddr("liveFeeTo");
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(nextOwner_));
        vm.prank(oldOwner_);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, oldOwner_));
        IOperable(address(vault)).setOperator(address(this), true);
        vm.prank(oldOwner_);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, oldOwner_));
        IOperable(address(vault)).setOperatorFor(IFullSpreadMoney.compound.selector, address(this), true);
        vm.prank(oldOwner_);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, oldOwner_));
        money.donate(address(token0), 1 ether, false);
        vm.prank(oldOwner_);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, oldOwner_));
        money.compound();
        _fund(nextOwner_, 2 ether, 2 ether);
        uint256 nextBalance_ = token0.balanceOf(nextOwner_);
        uint256 nextBalance1_ = token1.balanceOf(nextOwner_);
        uint256 supply_ = money.totalSupply();
        vm.startPrank(nextOwner_);
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        vm.recordLogs();
        money.donate(address(token0), 1 ether, false);
        _markers(vm.getRecordedLogs(), true, false);
        vm.recordLogs();
        money.donate(address(token1), 1 ether, false);
        _markers(vm.getRecordedLogs(), true, true);
        vm.stopPrank();
        _poolFees(1 ether, 1 ether);
        vm.recordLogs();
        vm.prank(nextOwner_);
        money.compound();
        _markers(vm.getRecordedLogs(), false, true);
        assertEq(token0.balanceOf(nextOwner_), nextBalance_ - 1 ether, "live owner funds maintenance directly");
        assertEq(token1.balanceOf(nextOwner_), nextBalance1_ - 1 ether);
        assertEq(money.totalSupply(), supply_, "maintenance does not mint shares");
        vm.startPrank(nextOwner_);
        IOperable(address(vault)).setOperator(global_, false);
        IOperable(address(vault)).setOperatorFor(IFullSpreadMoney.compound.selector, address(this), true);
        vm.stopPrank();
        money.compound();
        vm.prank(global_);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, global_));
        money.compound();
    }

    /// @notice M17: donation before issuance reverts; donating shares only burns and never removes liquidity.
    function test_M17_zeroSupplyRejectAndShareDonationBurnOnly() public {
        uint256 shares_ = money.balanceOf(address(this)) / 10;
        address feeTo_ = _feeTo();
        IERC20(address(vault)).transfer(feeTo_, shares_);
        uint256 supply_ = money.totalSupply();
        uint128 liquidity_ = IFullSpreadPosition(address(vault)).positionLiquidity();
        vm.recordLogs();
        vm.prank(feeTo_);
        money.donate(address(vault), shares_, false);
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        MoneyTrace memory trace_ = _moneyTrace(logs_, true);
        assertEq(trace_.swaps + trace_.adds + trace_.removes + trace_.collects, 0);
        assertEq(money.totalSupply(), supply_ - shares_);
        assertEq(IFullSpreadPosition(address(vault)).positionLiquidity(), liquidity_);
        _markers(logs_, true, false);
        _freshMarket(uint160(1) << 96, 60);
        bytes32 before_ = _custody();
        vm.recordLogs();
        vm.prank(feeTo_);
        vm.expectRevert();
        money.donate(address(token0), 1 ether, false);
        logs_ = vm.getRecordedLogs();
        assertEq(_moneyTrace(logs_, true).swaps, 0);
        _markers(logs_, false, false);
        assertEq(_custody(), before_);
    }

    /// @notice P08/APEX-041/051: 600 initialized dust ticks do not cap a normal mint or redemption.
    function test_P08_dustTicksDepositAndRedeemComplete() public {
        _freshMarket(uint160(1) << 96, 1);
        _bundle(100_000 ether, 100_000 ether, 0, address(this), false);
        FullSpreadPoolMaintenance actor_ = new FullSpreadPoolMaintenance(pool);
        token0.mint(address(actor_), 1 ether);
        token1.mint(address(actor_), 1 ether);
        actor_.seedDust(key, 600);
        (uint256 preview_,) = money.previewExchangeIn(address(token1), 6_500 ether, address(vault));
        assertGt(preview_, 0);
        (uint256 shares_,) =
            money.exchangeIn(address(token1), 6_500 ether, address(vault), preview_, address(this), false, block.timestamp);
        assertEq(shares_, preview_);
        (, int24 tick_,,) = StateLibrary.getSlot0(pool, key.toId());
        assertGt(tick_, 600, "mint crosses all seeded dust ticks");
        (uint256 exitPreview_,) = money.previewExchangeIn(address(vault), shares_, address(token1));
        assertGt(exitPreview_, 0);
        uint256 before_ = token1.balanceOf(address(this));
        (uint256 out_,) =
            money.exchangeIn(address(vault), shares_, address(token1), exitPreview_, address(this), false, block.timestamp);
        assertEq(out_, exitPreview_);
        assertEq(token1.balanceOf(address(this)) - before_, out_);
    }

    /// @notice APEX-040: a pool donation and compound cannot round the next ordinary deposit to dust.
    function test_inventory040_poolDonationCompoundThenNormalDeposit() public {
        _poolFees(100_000 ether, 100_000 ether);
        vm.prank(_feeTo());
        money.compound();
        uint256 supply_ = money.totalSupply();
        uint128 liquidity_ = IFullSpreadPosition(address(vault)).positionLiquidity();
        vm.recordLogs();
        (uint256 net_,) = _bundle(1_000 ether, 1_000 ether, 0, address(this), false);
        MoneyTrace memory trace_ = _moneyTrace(vm.getRecordedLogs(), true);
        uint256 gross_ = FullMath.mulDiv(trace_.added, supply_, liquidity_);
        assertGt(net_, 100 ether, "normal deposit is not dust shares");
        assertEq(money.totalSupply() - supply_, gross_);
    }

    /// @notice APEX-034: direct transfers before genesis do not inflate the first or following issuance.
    function test_inventory034_preexistingBalancesDoNotInflateGenesis() public {
        _freshMarket(uint160(1) << 96, 60);
        token0.transfer(address(vault), 1_000_000 ether);
        token1.transfer(address(vault), 1_000_000 ether);
        assertEq(money.totalSupply(), 0, "a transfer alone mints nothing");
        vm.recordLogs();
        (uint256 net_,) = _bundle(1_000 ether, 1_000 ether, 0, address(this), false);
        MoneyTrace memory trace_ = _moneyTrace(vm.getRecordedLogs(), true);
        assertEq(money.totalSupply(), trace_.added);
        assertEq(money.balanceOf(address(0)), 1000);
        assertEq(net_ + money.balanceOf(_feeTo()) + 1000, trace_.added);
        assertEq(token0.balanceOf(address(vault)), 1_000_000 ether);
        assertEq(token1.balanceOf(address(vault)), 1_000_000 ether);
        uint256 supply_ = money.totalSupply();
        uint128 liquidity_ = IFullSpreadPosition(address(vault)).positionLiquidity();
        vm.recordLogs();
        _bundle(1_000 ether, 1_000 ether, 0, makeAddr("secondGenesisDepositor"), false);
        trace_ = _moneyTrace(vm.getRecordedLogs(), true);
        assertEq(money.totalSupply() - supply_, FullMath.mulDiv(trace_.added, supply_, liquidity_));
        assertEq(token0.balanceOf(address(vault)), 1_000_000 ether);
        assertEq(token1.balanceOf(address(vault)), 1_000_000 ether);
    }

    /// @notice M14: an absent fee recipient creates no fee shares and does not charge an unminted fee.
    function test_M14_zeroFeeRecipientMintsOnlyGrossSharesToDepositor() public {
        _setFee(1 ether);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(address(0)));
        uint256 supply_ = money.totalSupply();
        uint256 floor_ = money.balanceOf(address(0));
        uint128 liquidity_ = IFullSpreadPosition(address(vault)).positionLiquidity();
        address recipient_ = makeAddr("noFeeRecipient");
        (uint256 preview_,) = money.previewExchangeIn(address(token0), 1_000 ether, address(vault));
        vm.recordLogs();
        (uint256 net_,) =
            money.exchangeIn(address(token0), 1_000 ether, address(vault), preview_, recipient_, false, block.timestamp);
        MoneyTrace memory trace_ = _moneyTrace(vm.getRecordedLogs(), true);
        uint256 gross_ = FullMath.mulDiv(trace_.added, supply_, liquidity_);
        assertEq(net_, gross_);
        assertEq(preview_, gross_);
        assertEq(money.totalSupply() - supply_, gross_);
        assertEq(money.balanceOf(recipient_), gross_);
        assertEq(money.balanceOf(address(0)), floor_, "no fee is minted to the genesis floor");
    }

    /// @dev Creates a real initialized pool and a fresh registry-deployed vault; never injects SUT state.
    function _freshMarket(uint160 price_, int24 spacing_) internal {
        key.fee = 500;
        key.tickSpacing = spacing_;
        pool.initialize(key, price_);
        vault = IFullSpreadVault(package.deployVault(IPackage.PkgArgs(key)));
        money = IFullSpreadMoney(address(vault));
        _approve(address(vault));
    }

    function _bundle(uint256 amount0_, uint256 amount1_, uint256 min_, address recipient_, bool pretransferred_)
        internal
        returns (uint256 out_, uint256[] memory refunds_)
    {
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = amount0_;
        amounts_[1] = amount1_;
        return money.exchangeBundleInForSingleOut(amounts_, address(vault), min_, recipient_, pretransferred_, block.timestamp);
    }

    function _orderedFaces(bool reversed_) internal view returns (address[] memory faces_) {
        faces_ = new address[](2);
        faces_[0] = reversed_ ? address(token1) : address(token0);
        faces_[1] = reversed_ ? address(token0) : address(token1);
    }

    function _feeTo() internal view returns (address) {
        return address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
    }

    function _setFee(uint256 fee_) internal {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(address(vault), fee_);
    }

    function _assertEmptyPosition() internal view {
        assertEq(money.totalSupply(), 0);
        assertEq(money.balanceOf(address(this)), 0);
        assertEq(money.balanceOf(address(0)), 0);
        assertEq(IFullSpreadPosition(address(vault)).positionLiquidity(), 0);
    }

    function _collapsedMint(address input_, uint256 amount_) internal {
        bytes32 before_ = _custody();
        vm.recordLogs();
        (uint256 out_, uint256 refund_) =
            money.exchangeIn(input_, amount_, address(vault), 0, address(this), false, block.timestamp);
        MoneyTrace memory trace_ = _moneyTrace(vm.getRecordedLogs(), input_ == address(token0));
        assertEq(out_, 0);
        assertEq(refund_, amount_);
        assertEq(trace_.swaps + trace_.adds, 0);
        assertEq(_custody(), before_);
    }

    function _boundaryMoney(address input_, bool wanted_, uint160 price_) internal {
        uint256 amount_ = 10 ** 30 + 123;
        uint256 snap_ = vm.snapshotState();
        uint256 before_ = IERC20(input_).balanceOf(address(this));
        vm.recordLogs();
        (uint256 out_, uint256 refund_) =
            money.exchangeIn(input_, amount_, address(vault), 0, address(this), false, block.timestamp);
        MoneyTrace memory trace_ = _moneyTrace(vm.getRecordedLogs(), input_ == address(token0));
        assertEq(trace_.swaps, 0);
        assertEq(_price(), price_, "initialized exact-bound/outside price is unchanged");
        assertEq(IERC20(input_).balanceOf(address(this)), before_ - amount_ + refund_);
        if (wanted_) {
            assertGt(out_, 0);
            assertEq(trace_.adds, 1);
            assertGt(refund_, 0, "wanted-token add leaves rounding dust");
            assertLt(refund_, amount_);
        } else {
            assertEq(out_, 0);
            assertEq(refund_, amount_);
            assertEq(trace_.adds, 0);
        }
        assertTrue(vm.revertToState(snap_));
        address feeTo_ = _feeTo();
        _fund(feeTo_, amount_, amount_);
        vm.startPrank(feeTo_);
        IERC20(input_).approve(address(vault), type(uint256).max);
        before_ = IERC20(input_).balanceOf(feeTo_);
        vm.recordLogs();
        money.donate(input_, amount_, false);
        trace_ = _moneyTrace(vm.getRecordedLogs(), input_ == address(token0));
        assertEq(trace_.swaps, 0);
        assertEq(IERC20(input_).balanceOf(feeTo_), before_ - amount_, "donation is never refunded");
        uint256 booked_ = IERC20(input_).balanceOf(address(vault));
        if (wanted_) {
            assertEq(trace_.adds, 1);
            assertGt(booked_, 0, "wanted-token dust is booked");
            assertLt(booked_, amount_);
        } else {
            assertEq(trace_.adds, 0);
            assertEq(booked_, amount_);
        }
        vm.recordLogs();
        money.compound();
        trace_ = _moneyTrace(vm.getRecordedLogs(), input_ == address(token0));
        assertEq(trace_.swaps, 0);
        assertEq(IERC20(input_).balanceOf(feeTo_), before_ - amount_);
        assertEq(IERC20(input_).balanceOf(address(vault)), booked_, "boundary remainder stays booked");
        assertEq(_price(), price_);
        vm.stopPrank();
    }

    function _poolFees(uint256 amount0_, uint256 amount1_) internal {
        FullSpreadPoolMaintenance actor_ = new FullSpreadPoolMaintenance(pool);
        token0.mint(address(actor_), amount0_);
        token1.mint(address(actor_), amount1_);
        actor_.donate(key, amount0_, amount1_);
    }

    function _unpaid() internal view returns (uint256 fee0_, uint256 fee1_) {
        int24 lower_ = IFullSpreadPosition(address(vault)).tickLower();
        int24 upper_ = IFullSpreadPosition(address(vault)).tickUpper();
        (uint128 liquidity_, uint256 last0_, uint256 last1_) =
            StateLibrary.getPositionInfo(pool, key.toId(), address(vault), lower_, upper_, bytes32(0));
        (uint256 inside0_, uint256 inside1_) = StateLibrary.getFeeGrowthInside(pool, key.toId(), lower_, upper_);
        fee0_ = FullMath.mulDiv(liquidity_, inside0_ - last0_, uint256(1) << 128);
        fee1_ = FullMath.mulDiv(liquidity_, inside1_ - last1_, uint256(1) << 128);
    }

    function _exitClaim(uint256 shares_) internal view returns (ExitClaim memory claim_) {
        claim_.supply = money.totalSupply();
        claim_.liquidity = IFullSpreadPosition(address(vault)).positionLiquidity();
        uint128 removed_ = uint128(FullMath.mulDiv(claim_.liquidity, shares_, claim_.supply));
        (claim_.principal0, claim_.principal1) = _amountsForLiquidity(
            uint160(_price()), TickMath.getSqrtPriceAtTick(IFullSpreadPosition(address(vault)).tickLower()),
            TickMath.getSqrtPriceAtTick(IFullSpreadPosition(address(vault)).tickUpper()), removed_
        );
        (claim_.fee0, claim_.fee1) = _unpaid();
        claim_.booked0 = token0.balanceOf(address(vault));
        claim_.booked1 = token1.balanceOf(address(vault));
    }

    function _fourPartExit(bool want0_, uint256 shares_, ExitClaim memory claim_) internal returns (uint256 out_) {
        uint256 feeClaim0_ = FullMath.mulDiv(claim_.fee0, shares_, claim_.supply);
        uint256 feeClaim1_ = FullMath.mulDiv(claim_.fee1, shares_, claim_.supply);
        uint256 bookedClaim0_ = FullMath.mulDiv(claim_.booked0, shares_, claim_.supply);
        uint256 bookedClaim1_ = FullMath.mulDiv(claim_.booked1, shares_, claim_.supply);
        assertGt(want0_ ? feeClaim0_ : feeClaim1_, 0);
        assertGt(want0_ ? bookedClaim0_ : bookedClaim1_, 0);
        address output_ = want0_ ? address(token0) : address(token1);
        address recipient_ = makeAddr("fourPartRecipient");
        uint256 before_ = IERC20(output_).balanceOf(recipient_);
        vm.recordLogs();
        (out_,) = money.exchangeIn(address(vault), shares_, output_, 0, recipient_, false, block.timestamp);
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        MoneyTrace memory trace_ = _moneyTrace(logs_, !want0_);
        assertEq(trace_.swaps, 1);
        assertEq(trace_.spent, want0_
            ? claim_.principal1 + feeClaim1_ + bookedClaim1_
            : claim_.principal0 + feeClaim0_ + bookedClaim0_, "swap only the exiting holder's entire opposing claim");
        assertEq(out_, trace_.received + (want0_
            ? claim_.principal0 + feeClaim0_ + bookedClaim0_
            : claim_.principal1 + feeClaim1_ + bookedClaim1_));
        assertEq(IERC20(output_).balanceOf(recipient_) - before_, out_);
        assertEq(token0.balanceOf(address(vault)), claim_.booked0 - bookedClaim0_ + claim_.fee0 - feeClaim0_);
        assertEq(token1.balanceOf(address(vault)), claim_.booked1 - bookedClaim1_ + claim_.fee1 - feeClaim1_);
        assertEq(money.totalSupply(), claim_.supply - shares_);
        uint256 burnIndex_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter == address(vault) && logs_[i_].topics.length == 3
                && logs_[i_].topics[0] == keccak256("Transfer(address,address,uint256)")
                && logs_[i_].topics[2] == bytes32(0)) burnIndex_ = i_ + 1;
        }
        assertGt(burnIndex_, trace_.firstSwap, "measure executed receipt before burning");
    }

    function _assertNetIssuance(bool face0_, uint256 fee_) internal {
        address input_ = face0_ ? address(token0) : address(token1);
        uint256 supply_ = money.totalSupply();
        uint128 liquidity_ = IFullSpreadPosition(address(vault)).positionLiquidity();
        uint256 feeShares_ = money.balanceOf(_feeTo());
        address recipient_ = makeAddr("feePreviewRecipient");
        (uint256 preview_,) = money.previewExchangeIn(input_, 1_000 ether, address(vault));
        uint256 snap_ = vm.snapshotState();
        vm.recordLogs();
        (uint256 net_,) =
            money.exchangeIn(input_, 1_000 ether, address(vault), preview_, recipient_, false, block.timestamp);
        MoneyTrace memory trace_ = _moneyTrace(vm.getRecordedLogs(), face0_);
        uint256 gross_ = FullMath.mulDiv(trace_.added, supply_, liquidity_);
        assertGt(gross_, 0);
        assertEq(money.totalSupply() - supply_, gross_);
        assertEq(money.balanceOf(_feeTo()) - feeShares_, FullMath.mulDiv(gross_, fee_, 1e18));
        assertEq(net_, gross_ - FullMath.mulDiv(gross_, fee_, 1e18));
        assertEq(net_, preview_);
        assertEq(money.balanceOf(recipient_), net_);
        assertTrue(vm.revertToState(snap_));
        bytes32 before_ = _custody();
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, preview_ + 1, preview_));
        money.exchangeIn(input_, 1_000 ether, address(vault), preview_ + 1, recipient_, false, block.timestamp);
        assertEq(_custody(), before_);
    }

    function _addAmounts(uint160 price_, uint128 liquidity_) internal view returns (uint256 amount0_, uint256 amount1_) {
        uint160 lower_ = TickMath.getSqrtPriceAtTick(IFullSpreadPosition(address(vault)).tickLower());
        uint160 upper_ = TickMath.getSqrtPriceAtTick(IFullSpreadPosition(address(vault)).tickUpper());
        if (price_ <= lower_) amount0_ = SqrtPriceMath.getAmount0Delta(lower_, upper_, liquidity_, true);
        else if (price_ >= upper_) amount1_ = SqrtPriceMath.getAmount1Delta(lower_, upper_, liquidity_, true);
        else {
            amount0_ = SqrtPriceMath.getAmount0Delta(price_, upper_, liquidity_, true);
            amount1_ = SqrtPriceMath.getAmount1Delta(lower_, price_, liquidity_, true);
        }
    }

    /// @dev Reads actual manager execution events, not the planner or a pre-execution quote.
    function _moneyTrace(Vm.Log[] memory logs_, bool zeroForOne_) internal view returns (MoneyTrace memory trace_) {
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter != address(pool) || logs_[i_].topics.length != 3
                || logs_[i_].topics[1] != PoolId.unwrap(key.toId())
                || logs_[i_].topics[2] != bytes32(uint256(uint160(address(vault))))) continue;
            if (logs_[i_].topics[0] == keccak256("Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)")) {
                (int128 amount0_, int128 amount1_, uint160 price_,,,) =
                    abi.decode(logs_[i_].data, (int128, int128, uint160, uint128, int24, uint24));
                int128 spent_ = zeroForOne_ ? amount0_ : amount1_;
                int128 received_ = zeroForOne_ ? amount1_ : amount0_;
                assertLt(int256(spent_), 0);
                assertGt(int256(received_), 0);
                ++trace_.swaps;
                trace_.spent += uint256(-int256(spent_));
                trace_.received += uint256(int256(received_));
                trace_.priceAfterSwap = price_;
                if (trace_.firstSwap == 0) trace_.firstSwap = i_ + 1;
            } else if (logs_[i_].topics[0] == keccak256("ModifyLiquidity(bytes32,address,int24,int24,int256,bytes32)")) {
                (int24 lower_, int24 upper_, int256 delta_, bytes32 salt_) =
                    abi.decode(logs_[i_].data, (int24, int24, int256, bytes32));
                assertEq(lower_, TickMath.minUsableTick(key.tickSpacing));
                assertEq(upper_, TickMath.maxUsableTick(key.tickSpacing));
                assertEq(salt_, bytes32(0));
                if (trace_.firstModify == 0) trace_.firstModify = i_ + 1;
                if (delta_ > 0) {
                    ++trace_.adds;
                    trace_.added += uint128(uint256(delta_));
                } else if (delta_ < 0) ++trace_.removes;
                else ++trace_.collects;
            }
        }
    }

    function _markers(Vm.Log[] memory logs_, bool donation_, bool compounded_) internal view {
        uint256 donations_;
        uint256 compounds_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter != address(vault) || logs_[i_].topics.length == 0) continue;
            if (logs_[i_].topics[0] == IVault.Donation.selector) {
                ++donations_;
                assertEq(logs_[i_].topics.length, 1);
                assertEq(logs_[i_].data.length, 0);
            }
            if (logs_[i_].topics[0] == IVault.Compounded.selector) {
                ++compounds_;
                assertEq(logs_[i_].topics.length, 1);
                assertEq(logs_[i_].data.length, 0);
            }
        }
        assertEq(donations_, donation_ ? 1 : 0);
        assertEq(compounds_, compounded_ ? 1 : 0);
    }

    function _callerMarker(Vm.Log[] memory logs_, bytes32 topic_) internal view {
        uint256 count_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter == address(vault) && logs_[i_].topics.length == 2 && logs_[i_].topics[0] == topic_) {
                ++count_;
                assertEq(logs_[i_].topics[1], bytes32(uint256(uint160(address(this)))));
                assertEq(logs_[i_].data.length, 0);
            }
        }
        assertEq(count_, 1);
    }

    function _transfers(Vm.Log[] memory logs_, address token_, address from_, address to_)
        internal pure returns (uint256 amount_)
    {
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter == token_ && logs_[i_].topics.length == 3
                && logs_[i_].topics[0] == keccak256("Transfer(address,address,uint256)")
                && logs_[i_].topics[1] == bytes32(uint256(uint160(from_)))
                && logs_[i_].topics[2] == bytes32(uint256(uint160(to_)))) {
                amount_ += abi.decode(logs_[i_].data, (uint256));
            }
        }
    }

    function _custody() internal view returns (bytes32) {
        return keccak256(abi.encode(
            money.totalSupply(), money.balanceOf(address(this)), money.balanceOf(_feeTo()),
            token0.balanceOf(address(this)), token1.balanceOf(address(this)),
            token0.balanceOf(address(vault)), token1.balanceOf(address(vault)),
            token0.balanceOf(address(pool)), token1.balanceOf(address(pool)),
            IFullSpreadPosition(address(vault)).positionLiquidity(), _price()
        ));
    }

    function _assertSuccessfulMint(address tokenIn_, address other_) internal {
        uint256 amount_ = 1_000 ether;
        uint256 inBefore_ = IERC20(tokenIn_).balanceOf(address(this));
        uint256 otherBefore_ = IERC20(other_).balanceOf(address(this));
        uint256 vaultOtherBefore_ = IERC20(other_).balanceOf(address(vault));
        (uint256 shares_, uint256 refund_) =
            money.exchangeIn(tokenIn_, amount_, address(vault), 0, address(this), false, block.timestamp);
        assertGt(shares_, 0, "one-sided mint succeeds");
        assertEq(inBefore_ - IERC20(tokenIn_).balanceOf(address(this)), amount_ - refund_);
        assertEq(IERC20(other_).balanceOf(address(this)), otherBefore_, "refund is not the other token");
        assertEq(IERC20(other_).balanceOf(address(vault)), vaultOtherBefore_, "other token is not left unbooked");
    }

    function _assertOneTokenDonate(address token_) internal {
        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        address other_ = token_ == address(token0) ? address(token1) : address(token0);
        uint256 otherBefore_ = IERC20(other_).balanceOf(address(vault));
        _fund(feeTo_, 2 ether, 2 ether);
        uint256 price_ = _price();
        uint256 vaultBefore_ = IERC20(token_).balanceOf(address(vault));
        uint256 feeToBefore_ = IERC20(token_).balanceOf(feeTo_);
        vm.startPrank(feeTo_);
        IERC20(token_).approve(address(vault), type(uint256).max);
        vm.recordLogs();
        money.donate(token_, 1 ether, false);
        vm.stopPrank();
        (bool donation_,) = _donationAndCompound();
        assertTrue(donation_);
        assertTrue(_price() != price_, "one-token donate swaps");
        assertEq(IERC20(other_).balanceOf(address(vault)), otherBefore_, "other token is not booked residue");
        assertEq(IERC20(token_).balanceOf(feeTo_), feeToBefore_ - 1 ether, "declared input is not refunded");
        assertLt(IERC20(token_).balanceOf(address(vault)) - vaultBefore_, 1 ether, "deposited input is not all booked");
    }

    function _bookWithoutSwap(address token_) internal {
        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        _fund(feeTo_, 2 ether, 0);
        vm.startPrank(feeTo_);
        IERC20(token_).approve(address(vault), type(uint256).max);
        money.donate(token_, 1 ether, false);
        vm.stopPrank();
    }

    function _assertOutside(address wanted_, address other_) internal {
        uint256 price_ = _price();
        uint256 otherBefore_ = IERC20(other_).balanceOf(address(this));
        uint256 sharesBefore_ = money.balanceOf(address(this));
        (uint256 shares_, uint256 refund_) =
            money.exchangeIn(wanted_, 1_000 ether, address(vault), 0, address(this), false, block.timestamp);
        assertGt(shares_, 0, "wanted token is added");
        assertLt(refund_, 1_000 ether);
        assertEq(_price(), price_, "outside add does not swap");
        assertEq(money.balanceOf(address(this)), sharesBefore_ + shares_);
        (uint256 otherShares_, uint256 otherRefund_) =
            money.exchangeIn(other_, 1 ether, address(vault), 0, address(this), false, block.timestamp);
        assertEq(otherShares_, 0);
        assertEq(otherRefund_, 1 ether, "mint refunds the unwanted token");
        assertEq(IERC20(other_).balanceOf(address(this)), otherBefore_);
        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        _fund(feeTo_, 1 ether, 1 ether);
        vm.startPrank(feeTo_);
        IERC20(other_).approve(address(vault), type(uint256).max);
        uint256 vaultOther_ = IERC20(other_).balanceOf(address(vault));
        money.donate(other_, 1 ether, false);
        vm.stopPrank();
        assertEq(IERC20(other_).balanceOf(address(vault)), vaultOther_ + 1 ether, "donate books the unwanted token");
        assertEq(_price(), price_);
    }

    function _assertExitReceipt(address tokenOut_) internal {
        uint256 shares_ = 25 ether;
        uint256 snap_ = vm.snapshotState();
        (uint256 learned_, uint256 principal_, uint256 swapCredit_) = _exitAndMeasure(tokenOut_, shares_, 0);
        vm.revertToState(snap_);
        address recipient_ = makeAddr(tokenOut_ == address(token0) ? "exit0" : "exit1");
        address other_ = tokenOut_ == address(token0) ? address(token1) : address(token0);
        uint256 before_ = IERC20(tokenOut_).balanceOf(recipient_);
        uint256 otherBefore_ = IERC20(other_).balanceOf(recipient_);
        uint256 callerShares_ = money.balanceOf(address(this));
        uint256 supply_ = money.totalSupply();
        (uint256 out_,) = money.exchangeIn(address(vault), shares_, tokenOut_, learned_, recipient_, false, block.timestamp);
        uint256 increase_ = IERC20(tokenOut_).balanceOf(recipient_) - before_;
        assertEq(out_, increase_);
        assertEq(increase_, principal_ + swapCredit_);
        assertEq(IERC20(other_).balanceOf(recipient_), otherBefore_);
        vm.revertToState(snap_);
        try money.exchangeIn(address(vault), shares_, tokenOut_, learned_ + 1, recipient_, false, block.timestamp) returns (
            uint256, uint256
        ) {
            assertTrue(false, "minimum above the receipt must revert");
        } catch (bytes memory err_) {
            assertGe(err_.length, 4);
            assertEq(bytes4(err_), IStandardExchangeErrors.AmountOutNotMet.selector);
        }
        assertEq(money.balanceOf(address(this)), callerShares_);
        assertEq(money.totalSupply(), supply_);
    }

    function _exitAndMeasure(address tokenOut_, uint256 shares_, uint256 min_)
        internal
        returns (uint256 out_, uint256 principal_, uint256 swapCredit_)
    {
        uint256 supply_ = money.totalSupply();
        uint128 liquidity_ = IFullSpreadPosition(address(vault)).positionLiquidity();
        uint256 liqOut_ = uint256(liquidity_) * shares_ / supply_;
        (uint160 price_, int24 tick_, , ) = StateLibrary.getSlot0(pool, key.toId());
        tick_;
        int24 lower_ = IFullSpreadPosition(address(vault)).tickLower();
        int24 upper_ = IFullSpreadPosition(address(vault)).tickUpper();
        (uint256 amount0_, uint256 amount1_) = _amountsForLiquidity(
            price_, TickMath.getSqrtPriceAtTick(lower_), TickMath.getSqrtPriceAtTick(upper_), uint128(liqOut_)
        );
        principal_ = tokenOut_ == address(token0) ? amount0_ : amount1_;
        address recipient_ = makeAddr("measure");
        vm.recordLogs();
        (out_,) = money.exchangeIn(address(vault), shares_, tokenOut_, min_, recipient_, false, block.timestamp);
        swapCredit_ = _swapCredit(tokenOut_);
    }

    function _swapCredit(address tokenOut_) internal returns (uint256 credit_) {
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        bytes32 topic_ = keccak256("Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)");
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter != address(pool) || logs_[i_].topics.length == 0 || logs_[i_].topics[0] != topic_) continue;
            (int128 amount0_, int128 amount1_,,,,) = abi.decode(logs_[i_].data, (int128, int128, uint160, uint128, int24, uint24));
            int128 delta_ = tokenOut_ == address(token0) ? amount0_ : amount1_;
            if (delta_ > 0) credit_ += uint256(int256(delta_));
        }
    }

    function _addCounterparty() internal {
        int24 lower_ = TickMath.minUsableTick(key.tickSpacing);
        int24 upper_ = TickMath.maxUsableTick(key.tickSpacing);
        uint128 liquidity_ = LiquidityAmounts.getLiquidityForAmounts(
            uint160(uint256(1) << 96), TickMath.getSqrtPriceAtTick(lower_), TickMath.getSqrtPriceAtTick(upper_), 50_000 ether, 50_000 ether
        );
        FullSpreadV4ExternalLp lp_ = new FullSpreadV4ExternalLp(pool);
        token0.mint(address(lp_), 100_000 ether);
        token1.mint(address(lp_), 100_000 ether);
        lp_.add(key, lower_, upper_, liquidity_);
    }

    function _pushTo(bool below_) internal {
        FullSpreadDirectSwapper swapper_ = new FullSpreadDirectSwapper(pool);
        address feeTo_ = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 feeShares_ = money.balanceOf(feeTo_);
        if (feeShares_ != 0) {
            vm.prank(feeTo_);
            IERC20(address(vault)).transfer(address(this), feeShares_);
        }
        uint256 idle_ = money.balanceOf(address(this));
        if (idle_ > 1000) {
            address[] memory tokens_ = new address[](2);
            tokens_[0] = address(token0);
            tokens_[1] = address(token1);
            uint256[] memory mins_ = new uint256[](2);
            money.exchangeBundleOut(address(vault), idle_ - 1000, tokens_, mins_, address(this), false, block.timestamp);
        }
        uint256 amount_ = 100_000_000 ether;
        if (below_) token0.mint(address(swapper_), amount_);
        else token1.mint(address(swapper_), amount_);
        swapper_.swap(key, below_, amount_);
        int24 bound_ = below_ ? IFullSpreadPosition(address(vault)).tickLower() : IFullSpreadPosition(address(vault)).tickUpper();
        (uint160 price_, , , ) = StateLibrary.getSlot0(pool, key.toId());
        if (below_) assertLe(price_, TickMath.getSqrtPriceAtTick(bound_), "price is at or below the position");
        else assertGe(price_, TickMath.getSqrtPriceAtTick(bound_), "price is at or above the position");
    }

    function _movePool() internal {
        FullSpreadDirectSwapper swapper_ = new FullSpreadDirectSwapper(pool);
        token1.mint(address(swapper_), 1_000 ether);
        swapper_.swap(key, false, 1_000 ether);
    }

    function _amountsForLiquidity(uint160 price_, uint160 lower_, uint160 upper_, uint128 liquidity_)
        internal
        pure
        returns (uint256 amount0_, uint256 amount1_)
    {
        if (lower_ > upper_) (lower_, upper_) = (upper_, lower_);
        if (price_ <= lower_) {
            amount0_ = _amount0(lower_, upper_, liquidity_);
        } else if (price_ < upper_) {
            amount0_ = _amount0(price_, upper_, liquidity_);
            amount1_ = _amount1(lower_, price_, liquidity_);
        } else {
            amount1_ = _amount1(lower_, upper_, liquidity_);
        }
    }

    function _amount0(uint160 sqrtA_, uint160 sqrtB_, uint128 liquidity_) internal pure returns (uint256) {
        if (sqrtA_ > sqrtB_) (sqrtA_, sqrtB_) = (sqrtB_, sqrtA_);
        return FullMath.mulDiv(uint256(liquidity_) << 96, sqrtB_ - sqrtA_, sqrtB_) / sqrtA_;
    }

    function _amount1(uint160 sqrtA_, uint160 sqrtB_, uint128 liquidity_) internal pure returns (uint256) {
        if (sqrtA_ > sqrtB_) (sqrtA_, sqrtB_) = (sqrtB_, sqrtA_);
        return FullMath.mulDiv(liquidity_, sqrtB_ - sqrtA_, uint256(1) << 96);
    }

    function _price() internal view returns (uint256) {
        (uint160 price_, , , ) = StateLibrary.getSlot0(pool, key.toId());
        return price_;
    }

    function _donationAndCompound() internal returns (bool donation_, bool compounded_) {
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter != address(vault) || logs_[i_].topics.length == 0) continue;
            if (logs_[i_].topics[0] == IVault.Donation.selector) donation_ = true;
            if (logs_[i_].topics[0] == IVault.Compounded.selector) compounded_ = true;
        }
    }
}

contract FullSpreadDirectSwapper is IUnlockCallback {
    IPoolManager public immutable manager;

    constructor(IPoolManager manager_) {
        manager = manager_;
    }

    function swap(PoolKey calldata key_, bool zeroForOne_, uint256 amountIn_) external {
        manager.unlock(abi.encode(key_, zeroForOne_, amountIn_));
    }

    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        if (msg.sender != address(manager)) revert();
        (PoolKey memory key_, bool zeroForOne_, uint256 amountIn_) = abi.decode(data_, (PoolKey, bool, uint256));
        manager.swap(
            key_,
            SwapParams({
                zeroForOne: zeroForOne_,
                amountSpecified: -int256(amountIn_),
                sqrtPriceLimitX96: zeroForOne_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            ""
        );
        _settle(key_.currency0);
        _settle(key_.currency1);
        return "";
    }

    function _settle(Currency currency_) internal {
        int256 delta_ = TransientStateLibrary.currencyDelta(manager, address(this), currency_);
        if (delta_ == 0) return;
        if (delta_ < 0) {
            uint256 debt_ = uint256(-delta_);
            manager.sync(currency_);
            IERC20(Currency.unwrap(currency_)).transfer(address(manager), debt_);
            if (manager.settle() != debt_) revert();
        } else {
            manager.take(currency_, address(this), uint256(delta_));
        }
    }
}

/// @notice Non-SUT actor that donates real pool fees or creates real adjacent dust positions.
contract FullSpreadPoolMaintenance is IUnlockCallback {
    IPoolManager public immutable manager;

    constructor(IPoolManager manager_) {
        manager = manager_;
    }

    function donate(PoolKey calldata key_, uint256 amount0_, uint256 amount1_) external {
        manager.unlock(abi.encode(key_, amount0_, amount1_, uint256(0)));
    }

    function seedDust(PoolKey calldata key_, uint256 count_) external {
        manager.unlock(abi.encode(key_, uint256(0), uint256(0), count_));
    }

    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        if (msg.sender != address(manager)) revert();
        (PoolKey memory key_, uint256 amount0_, uint256 amount1_, uint256 count_) =
            abi.decode(data_, (PoolKey, uint256, uint256, uint256));
        if (count_ == 0) manager.donate(key_, amount0_, amount1_, "");
        else {
            for (uint256 i_ = 1; i_ <= count_; ++i_) {
                int24 lower_ = int24(int256(i_));
                manager.modifyLiquidity(
                    key_, ModifyLiquidityParams(lower_, lower_ + 1, 1, bytes32(0)), ""
                );
            }
        }
        _settle(key_.currency0);
        _settle(key_.currency1);
        return "";
    }

    function _settle(Currency currency_) internal {
        int256 delta_ = TransientStateLibrary.currencyDelta(manager, address(this), currency_);
        if (delta_ < 0) {
            uint256 debt_ = uint256(-delta_);
            manager.sync(currency_);
            IERC20(Currency.unwrap(currency_)).transfer(address(manager), debt_);
            if (manager.settle() != debt_) revert();
        } else if (delta_ > 0) manager.take(currency_, address(this), uint256(delta_));
    }
}
