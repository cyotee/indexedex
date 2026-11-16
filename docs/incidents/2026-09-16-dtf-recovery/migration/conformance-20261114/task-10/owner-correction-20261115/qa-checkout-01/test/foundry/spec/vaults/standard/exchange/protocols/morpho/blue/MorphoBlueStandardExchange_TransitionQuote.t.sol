// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {TestBase_MorphoBlueStandardExchange} from "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange.sol";
import {TransitionQuoteAssertions} from "test/foundry/spec/vaults/standard/TransitionQuoteAssertions.sol";

contract MorphoBlueStandardExchange_TransitionQuote is TestBase_MorphoBlueStandardExchange, TransitionQuoteAssertions {
    function test_transitionSequence_vaultReceivesMorphoAccrualFees() public {
        vm.startPrank(OWNER);
        morpho.setFeeRecipient(se);
        morpho.setFee(marketParams, 1e17);
        vm.stopPrank();
        _wrapExactIn(user, 1000 ether + 13);
        _borrowFromMarket(2000 ether, 500 ether);
        vm.warp(block.timestamp + 30 days);
        uint256 navBefore_ = se4626.totalAssets();
        (bytes memory stateBefore_,) = IStandardExchangeTransitionQuote(se).quoteState(address(loanToken), user);
        uint256 snapshot_ = vm.snapshotState();
        morpho.accrueInterest(marketParams);
        assertEq(se4626.totalAssets(), navBefore_, "NAV includes pending Morpho fee shares");
        (bytes memory accruedState_,) = IStandardExchangeTransitionQuote(se).quoteState(address(loanToken), user);
        assertEq(accruedState_, stateBefore_, "snapshot includes exact fee-recipient accrual");
        assertTrue(vm.revertToState(snapshot_));
        _assertQuoteSequence(se, IERC20(address(loanToken)), user, 1 ether);
    }

    function test_transitionSequence_feeRecipientIsHolder() public {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 2e15);
        address holder_ = address(indexedexManager.feeTo());
        _mintLoan(holder_, 2000 ether);
        vm.prank(holder_);
        loanToken.approve(se, type(uint256).max);
        _wrapExactIn(holder_, 1000 ether + 13);
        _assertQuoteSequence(se, IERC20(address(loanToken)), holder_, 1 ether);
    }

    function testFuzz_transitionSequence(uint32 elapsed_, bool feeOn_) public {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, feeOn_ ? 2e15 : 0);
        _wrapExactIn(user, 1000 ether + 13);
        _wrapExactIn(attacker, 250 ether + 7);
        _borrowFromMarket(2000 ether, 500 ether);
        vm.warp(block.timestamp + bound(elapsed_, 1, 30 days));
        _assertQuoteSequence(se, IERC20(address(loanToken)), user, 1 ether);
    }
}
