// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";

import {TestBase_RebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol";
import {
    IStandardExchangeTransitionQuote,
    IStandardExchangeExternalQuote,
    IStandardExchangeRateQuote
} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IRebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626.sol";
import {RebasingAwareOracle} from
    "test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareOracle.sol";

contract RebasingAwareERC4626_TransitionQuote is TestBase_RebasingAwareERC4626 {
    function _q() internal view returns (IStandardExchangeTransitionQuote) {
        return IStandardExchangeTransitionQuote(address(vault));
    }

    function test_quoteStateLength288() public view {
        (bytes memory state, uint256 holderAssets) = _q().quoteState(address(asset), alice);
        assertEq(state.length, 288);
        assertEq(holderAssets, 0);
        IRebasingAwareERC4626.QuoteState memory decoded =
            abi.decode(state, (IRebasingAwareERC4626.QuoteState));
        assertEq(decoded.version, 1);
        assertEq(decoded.chainId, block.chainid);
        assertEq(decoded.exchange, address(vault));
        assertEq(decoded.asset, address(asset));
        assertEq(decoded.decimalOffset, DEFAULT_OFFSET);
    }

    function test_malformedStateRevertsInvalidQuoteState() public {
        vm.expectRevert(IStandardExchangeTransitionQuote.InvalidQuoteState.selector);
        _q().quoteShareBalance(hex"00");
        bytes memory padded = new bytes(288);
        padded[64] = 0x01;
        vm.expectRevert(IStandardExchangeTransitionQuote.InvalidQuoteState.selector);
        _q().quoteShareBalance(padded);
    }

    function test_zeroTransitionNoOp() public {
        (bytes memory state,) = _q().quoteState(address(asset), alice);
        (bytes memory next, uint256 inAmt, uint256 outAmt,) =
            _q().quoteTransition(state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, 0);
        assertEq(inAmt, 0);
        assertEq(outAmt, 0);
        assertEq(keccak256(next), keccak256(state));
    }

    function test_depositTransitionMatchesExecution() public {
        uint256 assets = 12e18;
        (bytes memory state,) = _q().quoteState(address(asset), alice);
        (bytes memory next, uint256 inAmt, uint256 outAmt,) = _q().quoteTransition(
            state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, assets
        );
        uint256 snap = vm.snapshotState();
        vm.prank(alice);
        uint256 shares = vault.deposit(assets, alice);
        assertEq(shares, outAmt);
        assertEq(inAmt, assets);
        (bytes memory live,) = _q().quoteState(address(asset), alice);
        assertEq(keccak256(live), keccak256(next));
        vm.revertToState(snap);
        (bytes memory afterRevert,) = _q().quoteState(address(asset), alice);
        assertEq(keccak256(afterRevert), keccak256(state));
    }

    function test_receiveSharesAndExternal() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(40e18, alice);
        vm.prank(alice);
        IERC20(address(vault)).transfer(bob, shares / 2);
        (bytes memory state,) = _q().quoteState(address(asset), bob);
        (bytes memory received,,,) = _q().quoteTransition(
            state, IStandardExchangeTransitionQuote.Operation.ReceiveShares, shares / 4
        );
        assertEq(_q().quoteShareBalance(received), IERC20(address(vault)).balanceOf(bob) + shares / 4);
        (bytes memory ext,,) = IStandardExchangeExternalQuote(address(vault)).quoteExternalDeposit(
            state, address(asset), 5e18
        );
        assertGt(_q().quoteTotalSupply(ext), _q().quoteTotalSupply(state));
        assertEq(_q().quoteShareBalance(ext), _q().quoteShareBalance(state));
    }

    function test_unsupportedQuoteAsset() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeTransitionQuote.UnsupportedQuoteAsset.selector, address(vault)
            )
        );
        _q().quoteState(address(vault), alice);
    }

    function test_F17_redeemAndWithdrawTransitionsMatchExecution() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(30e18, alice);
        (bytes memory state,) = _q().quoteState(address(asset), alice);
        uint256 burn = shares / 4;
        (bytes memory next, uint256 inAmt, uint256 outAmt,) = _q().quoteTransition(
            state, IStandardExchangeTransitionQuote.Operation.RedeemExactIn, burn
        );
        uint256 snap = vm.snapshotState();
        vm.prank(alice);
        uint256 got = vault.redeem(burn, alice, alice);
        assertEq(got, outAmt);
        assertEq(inAmt, burn);
        (bytes memory live,) = _q().quoteState(address(asset), alice);
        assertEq(keccak256(live), keccak256(next));
        vm.revertToState(snap);

        (bytes memory wnext, uint256 win, uint256 wout,) = _q().quoteTransition(
            state, IStandardExchangeTransitionQuote.Operation.WithdrawExactOut, 2e18
        );
        vm.prank(alice);
        uint256 burned = vault.withdraw(2e18, alice, alice);
        assertEq(burned, win);
        assertEq(wout, 2e18);
        (bytes memory wlive,) = _q().quoteState(address(asset), alice);
        assertEq(keccak256(wlive), keccak256(wnext));
    }

    function test_quoteRateUsesProjectedState() public {
        vm.prank(alice);
        vault.deposit(20e18, alice);
        (bytes memory state,) = _q().quoteState(address(asset), alice);
        uint256 liveRate = IStandardizedYield(address(vault)).exchangeRate();
        uint256 quoted = IStandardExchangeRateQuote(address(vault)).quoteRate(
            address(vault), address(asset), state
        );
        assertEq(quoted, liveRate);
        (bytes memory next,,,) = _q().quoteTransition(
            state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, 10e18
        );
        uint256 projected = IStandardExchangeRateQuote(address(vault)).quoteRate(
            address(vault), address(asset), next
        );
        assertEq(IStandardizedYield(address(vault)).exchangeRate(), liveRate);
        assertGt(projected, 0);
    }

    function test_quotesDoNotMutateLiveBook() public {
        uint256 assetsBefore = vault.totalAssets();
        uint256 supplyBefore = IERC20(address(vault)).totalSupply();
        (bytes memory state,) = _q().quoteState(address(asset), alice);
        _q().quoteTransition(state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, 9e18);
        IStandardExchangeExternalQuote(address(vault)).quoteExternalDeposit(state, address(asset), 4e18);
        assertEq(vault.totalAssets(), assetsBefore);
        assertEq(IERC20(address(vault)).totalSupply(), supplyBefore);
    }
}
