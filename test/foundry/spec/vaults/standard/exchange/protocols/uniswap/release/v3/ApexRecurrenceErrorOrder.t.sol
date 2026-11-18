// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {FullSpreadReleaseFixture} from "./harness/FullSpreadReleaseFixture.sol";
import {UniswapV3FullSpreadStandardExchangeVaultBoundPoolLockSeCaller as LockedCaller} from "./harness/UniswapV3FullSpreadStandardExchangeVaultBoundPoolLockSeCaller.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";

/// @notice APEX/C06 intent under V3-ACC-10/12/16/17: funding guards and failures are atomic.
contract UniswapV3FullSpreadApexRecurrenceErrorOrderTest is FullSpreadReleaseFixture {
    function test_C06_mint_eoaShort() public {
        _join(1000 ether, 1000 ether);
        bytes32 beforeState = _state(alice);
        vm.prank(alice);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeIn(token0, 1 ether, IERC20(address(vault)), 1, bob, true, block.timestamp);
        assertEq(_state(alice), beforeState);
    }
    function test_C06_mint_contractShort() public {
        _join(1000 ether, 1000 ether);
        AtomicPretransferCaller wallet = new AtomicPretransferCaller();
        bytes32 beforeState = _state(address(wallet));
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, 1, 0));
        wallet.execute(address(vault), _mintData(address(wallet), true));
        assertEq(_state(address(wallet)), beforeState);
    }
    function test_C06_mint_eoaPull() public {
        _join(1000 ether, 1000 ether);
        _fund(token0, alice, 1 ether);
        (uint256 quote,) = vault.previewExchangeIn(token0, 1 ether, IERC20(address(vault)));
        vm.startPrank(alice);
        token0.approve(address(vault), 1 ether);
        (uint256 issued, uint256 refund) = vault.exchangeIn(token0, 1 ether, IERC20(address(vault)), quote, bob, false, block.timestamp);
        vm.stopPrank();
        assertGt(issued, 0);
        assertEq(issued, quote);
        assertEq(vault.balanceOf(bob), issued);
        assertEq(token0.balanceOf(alice), refund, "refund goes to payer, shares to recipient");
    }
    function test_C06_mint_contractFunded() public {
        _join(1000 ether, 1000 ether);
        AtomicPretransferCaller wallet = new AtomicPretransferCaller();
        uint256 beforeInput = token0.balanceOf(address(this));
        _fund(token0, address(this), 1 ether);
        token0.approve(address(wallet), 1 ether);
        (uint256 quote,) = vault.previewExchangeIn(token0, 1 ether, IERC20(address(vault)));
        (uint256 issued, uint256 refund) = abi.decode(wallet.consumePretransfer(token0, address(this), address(vault), 1 ether,
            _mintData(bob, true)), (uint256, uint256));
        assertEq(issued, quote);
        assertGt(issued, 0);
        assertEq(vault.balanceOf(bob), quote);
        assertEq(token0.balanceOf(address(wallet)), refund);
        assertEq(token0.balanceOf(address(this)), beforeInput);
    }
    function test_review_directExactOutSupportedControl_nowFailsClosed() public {
        _fund(token0, alice, 100 ether);
        vm.prank(alice);
        token0.approve(address(vault), 100 ether);
        _rejectExactOut(alice, false);
    }
    function test_review_directExactOutUnfilledPreview_returnsZero() public view {
        assertEq(vault.previewExchangeOut(token0, token1, token1.balanceOf(address(pool)) + 1), 0);
    }
    function test_review_eoaCannotRedeemParkedShares() public {
        uint256 parked = _join(1000 ether, 1000 ether) / 100;
        vault.transfer(address(vault), parked);
        bytes32 beforeState = _state(alice);
        vm.prank(alice);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeIn(IERC20(address(vault)), parked, token0, 0, alice, true, block.timestamp);
        assertEq(_state(alice), beforeState);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, parked));
        vault.exchangeIn(IERC20(address(vault)), parked, token0, 0, alice, false, block.timestamp);
        assertEq(_state(alice), beforeState);
    }
    function test_review_underfundedEoaExactOutObservesUnavailable() public {
        _join(1000 ether, 1000 ether);
        _rejectExactOut(alice, true);
    }
    function test_review_underfundedContractExactOutObservesUnavailable() public {
        _join(1000 ether, 1000 ether);
        AtomicPretransferCaller wallet = new AtomicPretransferCaller();
        bytes32 beforeState = _state(address(wallet));
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        wallet.execute(address(vault), abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (token0, uint256(1 ether), IERC20(address(vault)), uint256(1 ether), bob, true, block.timestamp)));
        assertEq(_state(address(wallet)), beforeState);
    }
    function test_review_underfundedEoaDirectExactOutObservesUnavailable() public { _rejectExactOut(alice, true); }
    function test_review_fundedContractDirectExactOutRollsBackPretransfer() public {
        _join(1000 ether, 1000 ether);
        AtomicPretransferCaller wallet = new AtomicPretransferCaller();
        _fund(token0, address(this), 10 ether);
        token0.approve(address(wallet), 10 ether);
        bytes32 beforeState = _state(address(this));
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        wallet.consumePretransfer(token0, address(this), address(vault), 10 ether,
            abi.encodeCall(IStandardExchangeOut.exchangeOut,
                (token0, uint256(10 ether), token1, uint256(1 ether), bob, true, block.timestamp)));
        assertEq(_state(address(this)), beforeState);
        assertEq(token0.balanceOf(address(wallet)), 0);
    }
    function test_review_falseFlagEoaDirectExactOutDoesNotPull() public { _rejectExactOut(alice, false); }
    function test_exactOut_deadlinePrecedesDisableAndFunding() public {
        _disable(true);
        vm.warp(1000);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, 1, 1000));
        vault.exchangeOut(token0, 1 ether, token1, 1 ether, bob, true, 1);
    }
    function test_exactOut_disabledUsesVaultDisabled() public {
        _disable(true);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, address(vault)));
        vault.exchangeOut(token0, 1 ether, token1, 1 ether, bob, false, block.timestamp);
    }
    function test_exactOut_lockedPreviewZero_andExecutionUnavailable() public {
        LockedCaller locked = new LockedCaller(pool);
        _fund(token0, address(locked), 1 ether);
        bytes memory result = locked.run(address(vault), abi.encodeCall(IStandardExchangeOut.previewExchangeOut,
            (token0, token1, uint256(1 ether))));
        assertEq(abi.decode(result, (uint256)), 0);
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        locked.run(address(vault), abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (token0, uint256(1 ether), token1, uint256(1 ether), bob, false, block.timestamp)));
    }
    function _rejectExactOut(address caller, bool prepaid) private {
        bytes32 beforeState = _state(caller);
        vm.prank(caller);
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        vault.exchangeOut(token0, 100 ether, token1, 1 ether, bob, prepaid, block.timestamp);
        assertEq(_state(caller), beforeState);
        assertEq(token1.balanceOf(bob), 0);
    }
    function _mintData(address recipient, bool prepaid) private view returns (bytes memory) {
        return abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (token0, uint256(1 ether), IERC20(address(vault)), uint256(1), recipient, prepaid, block.timestamp));
    }
}
