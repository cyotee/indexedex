// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IUniswapV4FullSpreadStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {IStandardExchangeBundleIn, IStandardExchangeBundleOut} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {TestBase_UniswapV4FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";

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
        assertGt(shares_, 0);
        assertEq(before0_ - token0.balanceOf(address(this)), 1_000 ether - refund_);
        assertEq(money.balanceOf(address(this)), sharesBefore_ + shares_);(uint256 exitPreview_,) = money.previewExchangeIn(address(vault), shares_, address(token0));
        uint256 faceBefore_ = token0.balanceOf(address(this));(uint256 out_, uint256 exitRefund_) = money.exchangeIn(address(vault), shares_, address(token0), exitPreview_, address(this), false, block.timestamp
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

}
