// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {AtomicPretransferConstructorCaller} from "contracts/test/stubs/AtomicPretransferConstructorCaller.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";

// tag::UniswapV4FullSpreadHooklessStandardExchangeVaultPretransferCallerLifecycleTest[]
contract UniswapV4FullSpreadHooklessStandardExchangeVaultPretransferCallerLifecycleTest is Acceptance {
    function test_constructorCallerRejectedWithNoCustodyOrSupplyChange() public {
        _bootstrap();
        uint256 supply = vault.totalSupply();
        uint256 held = token0.balanceOf(address(vault));
        bytes memory callData = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (token0, 1e18, IERC20(address(vault)), 0, address(this), true, block.timestamp));
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        new AtomicPretransferConstructorCaller(token0, address(this), address(vault), 0, callData, true);
        assertEq(vault.totalSupply(), supply);
        assertEq(token0.balanceOf(address(vault)), held);
        _assertBooked();
    }

    function test_delegatedEoaRequiresNewCreditAndCannotReuseBookedInventory() public {
        _bootstrap();
        AtomicPretransferCaller implementation = new AtomicPretransferCaller();
        uint256 key = 0xabc123;
        address wallet = vm.addr(key);
        vm.signAndAttachDelegation(address(implementation), key);
        assertGt(wallet.code.length, 0);
        uint256 supply = vault.totalSupply();
        vm.prank(wallet);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1e18, 0));
        vault.exchangeIn(token0, 1e18, IERC20(address(vault)), 0, wallet, true, block.timestamp);
        assertEq(vault.totalSupply(), supply);
        uint256 expected = vault.previewExchangeIn(token0, 1e18, IERC20(address(vault)));
        token0.transfer(address(vault), 1e18);
        vm.prank(wallet);
        uint256 issued = vault.exchangeIn(token0, 1e18, IERC20(address(vault)), expected, wallet, true, block.timestamp);
        assertGt(issued, 0);
        assertEq(issued, expected);
        assertEq(vault.balanceOf(wallet), issued);
        assertEq(vault.totalSupply(), supply + issued);
        _assertBooked();
        vm.prank(wallet);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1e18, 0));
        vault.exchangeIn(token0, 1e18, IERC20(address(vault)), 0, wallet, true, block.timestamp);
        assertEq(vault.balanceOf(wallet), issued);
        _assertBooked();
    }
}
// end::UniswapV4FullSpreadHooklessStandardExchangeVaultPretransferCallerLifecycleTest[]
