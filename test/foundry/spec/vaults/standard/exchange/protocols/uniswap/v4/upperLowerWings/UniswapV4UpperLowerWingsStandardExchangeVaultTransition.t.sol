// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceFixture as Fixture} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRebalance.t.sol";
import {IStandardExchangeTransitionQuote as Transition, IStandardExchangeExternalQuote as External} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeUnlockContextQuote as Unlock} from "contracts/interfaces/IStandardExchangeUnlockContextQuote.sol";
import {IStandardExchangeExactOutputQuantityQuote as Quantity} from "contracts/interfaces/IStandardExchangeExactOutputQuantityQuote.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault as Vault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance as Rebalance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.sol";

import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultProjection as Projection} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultProjection.sol";

contract UniswapV4UpperLowerWingsStandardExchangeVaultTransitionTest is Fixture {
    using StateLibrary for IPoolManager;
    function testFuzz_projectedPartialCoreExitAfterMarketMove(int24 tickSeed_, uint16 fractionSeed_, bool target0_) public {
        Vault vault = target0_ ? wings0 : wings1;
        IERC20 target = IERC20(vault.targetToken());
        IStandardExchangeIn(address(vault)).exchangeIn(target, 1e12, IERC20(address(vault)), 0, address(this), false, block.timestamp);
        Rebalance(address(vault)).rebalance(0, block.timestamp);
        (uint160 current,,,) = pool.getSlot0(key.toId());
        uint160 destination = TickMath.getSqrtPriceAtTick(int24(bound(tickSeed_, -12000, 12000)));
        if (destination != current) externalLp.swapTo(key, destination < current, 1e25, destination);
        _projectAndExecuteExit(vault, 1e12 * bound(fractionSeed_, 1, 9999) / 10000);
    }
    function _projectAndExecuteExit(Vault vault_, uint256 shares_) private {
        Transition quote = Transition(address(vault_));
        IERC20 target = IERC20(vault_.targetToken());
        (bytes memory state,) = quote.quoteState(address(target), address(this));
        uint256 payout; uint256 projectedAssets;
        (state,,payout,projectedAssets) = quote.quoteTransition(state, Transition.Operation.RedeemExactIn, shares_);
        assertEq(IStandardExchangeIn(address(vault_)).exchangeIn(IERC20(address(vault_)), shares_, target,
            payout, address(this), false, block.timestamp), payout);
        (,uint256 actualAssets) = quote.quoteState(address(target), address(this));
        assertEq(actualAssets, projectedAssets);
        Projection.State memory projected = abi.decode(state, (Projection.State));
        (uint256 local0,uint256 local1) = vault_.localReserves();
        assertEq(projected.book.local0, local0); assertEq(projected.book.local1, local1);
        for (uint8 i; i < 3; ++i) {
            (int24 lower,int24 upper,uint128 liquidity,) = vault_.position(i);
            assertEq(projected.book.positions[i].liquidity, liquidity);
            if (liquidity != 0) { assertEq(projected.book.positions[i].lower, lower); assertEq(projected.book.positions[i].upper, upper); }
        }
    }
    function testFuzz_sequentialDepositsAndLocalRedemption(uint64 seed_, bool target0_) public {
        Vault vault = target0_ ? wings0 : wings1;
        IERC20 target = IERC20(vault.targetToken());
        Transition quote = Transition(address(vault));
        IStandardExchangeIn exchange = IStandardExchangeIn(address(vault));
        (bytes memory state,) = quote.quoteState(address(target), address(this));
        uint256 first = bound(seed_, 1e6, 1e12);
        uint256 issued;
        (state,,issued,) = quote.quoteTransition(state, Transition.Operation.DepositExactIn, first);
        uint256 more;
        (state,,more,) = quote.quoteTransition(state, Transition.Operation.DepositExactIn, first / 2);
        uint256 payout;
        uint256 projectedAssets;
        (state,,payout,projectedAssets) = quote.quoteTransition(state, Transition.Operation.RedeemExactIn, first / 100);
        assertEq(exchange.exchangeIn(target, first, IERC20(address(vault)), 0, address(this), false, block.timestamp), issued);
        assertEq(exchange.exchangeIn(target, first / 2, IERC20(address(vault)), 0, address(this), false, block.timestamp), more);
        assertEq(exchange.exchangeIn(IERC20(address(vault)), first / 100, target, 0, address(this), false, block.timestamp), payout);
        (bytes memory actual,uint256 actualAssets) = quote.quoteState(address(target), address(this));
        assertEq(actualAssets, projectedAssets);
        assertEq(quote.quoteTotalSupply(state), quote.quoteTotalSupply(actual));
        assertEq(quote.quoteShareBalance(state), IERC20(address(vault)).balanceOf(address(this)));
    }
    function test_projectedFullExitAfterCoreFundingBothTargets() public {
        for (uint256 i; i < 2; ++i) {
            uint256 snapshot = vm.snapshotState();
            Vault vault = i == 0 ? wings0 : wings1;
            IERC20 target = IERC20(vault.targetToken());
            IStandardExchangeIn exchange = IStandardExchangeIn(address(vault));
            exchange.exchangeIn(target, 1e12, IERC20(address(vault)), 0, address(this), false, block.timestamp);
            Rebalance(address(vault)).rebalance(0, block.timestamp);
            Transition quote = Transition(address(vault));
            (bytes memory state,) = quote.quoteState(address(target), address(this));
            uint256 payout;
            uint256 holderAssets;
            (state,,payout,holderAssets) = quote.quoteTransition(state, Transition.Operation.RedeemExactIn, 1e12);
            assertEq(holderAssets, 0); assertEq(quote.quoteTotalSupply(state), 0);
            assertEq(exchange.exchangeIn(IERC20(address(vault)), 1e12, target, payout, address(this), false, block.timestamp), payout);
            assertTrue(vm.revertToState(snapshot));
        }
    }
    function test_receiveSharesDoesNotChangeBackingOrSupply() public {
        IStandardExchangeIn(address(wings0)).exchangeIn(token0, 1e12, IERC20(address(wings0)), 0, address(this), false, block.timestamp);
        Transition quote = Transition(address(wings0));
        (bytes memory state,) = quote.quoteState(address(token0), makeAddr("buffer"));
        uint256 supply = quote.quoteTotalSupply(state);
        uint256 beforeAssets = quote.quoteAssets(state, supply);
        uint256 used;
        uint256 received;
        (state,used,received,) = quote.quoteTransition(state, Transition.Operation.ReceiveShares, 1000);
        assertEq(used, 1000); assertEq(received, 1000);
        assertEq(quote.quoteTotalSupply(state), supply); assertEq(quote.quoteAssets(state, supply), beforeAssets);
        vm.expectPartialRevert(Transition.InsufficientQuoteShares.selector);
        quote.quoteTransition(state, Transition.Operation.ReceiveShares, supply);
    }
    function test_unlockContextIsManagerSpecificAndSticky() public {
        Transition quote = Transition(address(wings0));
        (bytes memory state,) = quote.quoteState(address(token0), address(this));
        Unlock unlock = Unlock(address(wings0));
        assertEq(unlock.quoteStateWithUnavailableUnlock(state, address(123)), state);
        bytes memory blocked = unlock.quoteStateWithUnavailableUnlock(state, address(pool));
        assertEq(unlock.quoteStateWithUnavailableUnlock(blocked, address(123)), blocked);
        assertEq(unlock.quoteStateWithUnavailableUnlock(blocked, address(pool)), blocked);
        uint256 minted;
        (blocked,,minted,) = quote.quoteTransition(blocked, Transition.Operation.DepositExactIn, 1234);
        uint256 paid;
        (blocked,,paid,) = quote.quoteTransition(blocked, Transition.Operation.RedeemExactIn, minted);
        assertEq(paid, 1234); assertEq(quote.quoteTotalSupply(blocked), 0);
    }
    function test_externalDepositRetainsHolderBalanceAndRejectsOpposingRoute() public {
        Transition quote = Transition(address(wings0));
        (bytes memory state,) = quote.quoteState(address(token0), address(this));
        uint256 shares;
        uint256 holderAssets;
        (state,shares,holderAssets) = External(address(wings0)).quoteExternalDeposit(state, address(token0), 1e12);
        assertEq(shares, 1e12); assertEq(holderAssets, 0); assertEq(quote.quoteShareBalance(state), 0);
        assertEq(quote.quoteTotalSupply(state), shares);
        vm.expectRevert(abi.encodeWithSelector(Transition.UnsupportedQuoteAsset.selector, address(token1)));
        External(address(wings0)).quoteExternalExchange(state, address(token1), 100);
    }
    function test_snapshotVaultDomainAndTargetAreValidated() public {
        Transition quote = Transition(address(wings0));
        vm.expectRevert(abi.encodeWithSelector(Transition.UnsupportedQuoteAsset.selector, address(token1)));
        quote.quoteState(address(token1), address(this));
        (bytes memory state,) = quote.quoteState(address(token0), address(this));
        vm.expectRevert(Transition.InvalidQuoteState.selector);
        Transition(address(wings1)).quoteTotalSupply(state);
        assertEq(Quantity(address(wings0)).quoteInputForExactShares(state, 123), 123);
    }
}
