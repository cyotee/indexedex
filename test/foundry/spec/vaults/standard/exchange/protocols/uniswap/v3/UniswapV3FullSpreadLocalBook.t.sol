// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {TestBase_UniswapV3FullSpreadAccounting} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadAccounting.sol";

// tag::UniswapV3FullSpreadLocalBookTest[]
/// @notice RC-03 under V3-ACC-09/10: pretransfer credit excludes booked custody and pool inventory.
contract UniswapV3FullSpreadLocalBookTest is TestBase_UniswapV3FullSpreadAccounting {
    function setUp() public override {
        super.setUp();
        _seedVault(SEED);
        _poolFees(1e24, 2e24);
        _bundleIn(bob, SEED, SEED); // Collect incumbent fees into booked custody without spending them.
    }

    /// @notice Changes to deployed principal and unpaid fees do not change held pretransfer credit.
    function test_pretransferCreditIgnoresChangingDeployedAmounts() public {
        (uint256 book0_, uint256 book1_) = _booked();
        (uint256 deployed0_, uint256 deployed1_) = _deployed();
        assertGt(book0_, deployed0_, "booked custody is separate from deployed reserves");
        assertGt(book1_, deployed1_);
        assertEq(token0.balanceOf(address(vault)), book0_);
        assertEq(token1.balanceOf(address(vault)), book1_);
        assertEq(vault.reserveOfToken(address(token0)), deployed0_);
        assertEq(vault.reserveOfToken(address(token1)), deployed1_);
        _assertCreditBoundary(IERC20(address(token0)), 0);
        _assertCreditBoundary(IERC20(address(token1)), 0);

        token0.transfer(address(vault), 7e8);
        token1.transfer(address(vault), 11e8);
        _assertCreditBoundary(IERC20(address(token0)), 7e8);
        _assertCreditBoundary(IERC20(address(token1)), 11e8);

        _externalSwapExactIn(pool, true, 1e17);
        (uint256 moved0_, uint256 moved1_) = _deployed();
        assertGt(moved0_, deployed0_);
        assertLt(moved1_, deployed1_);
        assertGt(vault.reserveOfToken(address(token0)), deployed0_);
        assertLt(vault.reserveOfToken(address(token1)), deployed1_);
        (uint256 afterBook0_, uint256 afterBook1_) = _booked();
        assertEq(afterBook0_, book0_);
        assertEq(afterBook1_, book1_);
        _assertCreditBoundary(IERC20(address(token0)), 7e8);
        _assertCreditBoundary(IERC20(address(token1)), 11e8);
    }

    /// @notice Pull and staged funding buy the same shares and refund only their unused declared input.
    function test_pretransferCreditsOnlyWalletExcessAboveBookedCustody() public {
        uint256 amount_ = 7e8;
        uint256 snapshot_ = vm.snapshotState();
        (uint256 pulledShares_, uint256 pulledRefund_) = vault.exchangeIn(
            IERC20(address(token0)), amount_, IERC20(address(vault)), 1, address(this), false, block.timestamp
        );
        assertTrue(vm.revertToState(snapshot_));

        uint256 sharesBefore_ = vault.balanceOf(address(this));
        uint256 walletBefore_ = token0.balanceOf(address(this));
        token0.transfer(address(vault), amount_);
        _assertCreditBoundary(IERC20(address(token0)), amount_);
        (uint256 pushedShares_, uint256 refund_) = vault.exchangeIn(
            IERC20(address(token0)), amount_, IERC20(address(vault)), pulledShares_, address(this), true, block.timestamp
        );
        assertEq(pushedShares_, pulledShares_);
        assertEq(refund_, pulledRefund_);
        assertGt(refund_, 0);
        assertEq(vault.balanceOf(address(this)) - sharesBefore_, pulledShares_);
        assertEq(walletBefore_ - token0.balanceOf(address(this)), amount_ - refund_);
        (uint256 book0_, uint256 book1_) = _booked();
        assertEq(token0.balanceOf(address(vault)), book0_);
        assertEq(token1.balanceOf(address(vault)), book1_);
        (uint256 deployed0_, uint256 deployed1_) = _deployed();
        assertEq(vault.reserveOfToken(address(token0)), deployed0_);
        assertEq(vault.reserveOfToken(address(token1)), deployed1_);
        _assertCreditBoundary(IERC20(address(token0)), 0);
        _assertSettled();
    }

    /// @notice A pull cannot substitute unrelated staged custody for the caller's payment.
    function test_pullStillTransfersRequestedInputWithExistingWalletExcess() public {
        token0.transfer(address(vault), 11e8);
        uint256 beforeBalance_ = token0.balanceOf(address(this));
        uint256 beforeOutput_ = token1.balanceOf(address(this));
        uint256 supply_ = vault.totalSupply();
        (uint256 book0_, uint256 book1_) = _booked();
        (uint256 quoted_,) = vault.previewExchangeIn(IERC20(address(token0)), 7e8, IERC20(address(token1)));
        (uint256 output_, uint256 refund_) = vault.exchangeIn(
            IERC20(address(token0)), 7e8, IERC20(address(token1)), quoted_, address(this), false, block.timestamp
        );
        assertGt(quoted_, 0);
        assertEq(beforeBalance_ - token0.balanceOf(address(this)), 7e8 - refund_);
        assertEq(token1.balanceOf(address(this)) - beforeOutput_, output_);
        assertEq(output_, quoted_);
        assertEq(token0.balanceOf(address(vault)), book0_ + 11e8);
        assertEq(token1.balanceOf(address(vault)), book1_);
        assertEq(vault.totalSupply(), supply_);
        _assertCreditBoundary(IERC20(address(token0)), 11e8);
        _assertSettled();
    }

    /// @dev Overstated credit with a positive minimum reverts without spending or refunding another balance.
    function _assertCreditBoundary(IERC20 token_, uint256 expectedCredit_) internal {
        (uint256 booked0_, uint256 booked1_) = _booked();
        uint256 book_ = address(token_) == address(token0) ? booked0_ : booked1_;
        uint256 balance_ = token_.balanceOf(address(vault));
        uint256 reserve_ = vault.reserveOfToken(address(token_));
        uint256 supply_ = vault.totalSupply();
        assertEq(balance_ - book_, expectedCredit_);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, 1, 0));
        vault.exchangeIn(token_, expectedCredit_ + 1, IERC20(address(vault)), 1, address(this), true, block.timestamp);
        assertEq(token_.balanceOf(address(vault)), balance_);
        assertEq(vault.reserveOfToken(address(token_)), reserve_);
        assertEq(vault.totalSupply(), supply_);
    }

    function _deployed() internal view returns (uint256, uint256) {
        (uint160 price_,,,,,,) = pool.slot0();
        return _amounts(price_, _positionLiquidity(), false);
    }
}
// end::UniswapV3FullSpreadLocalBookTest[]
