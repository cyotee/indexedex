// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultCommon as Common} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInBase as InBase} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInBase.sol";

// tag::HooklessAdversarialTest[]
contract HooklessAdversarialTest is Acceptance {
    function test_callbackRequiresManagerAndActiveCommitment() public {
        vm.expectRevert(abi.encodeWithSelector(Common.UniswapV4Exchange_InvalidCallbackCaller.selector, address(this)));
        IUnlockCallback(address(vault)).unlockCallback("");
        vm.prank(address(poolManager));
        vm.expectRevert(Common.AccountingMismatch.selector);
        IUnlockCallback(address(vault)).unlockCallback("");
    }

    function test_EOAPretransferRejectedWithFundedVault() public {
        _bootstrap();
        vm.prank(makeAddr("code-less caller"));
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeIn(token0, 1, IERC20(address(vault)), 0, address(this), true, block.timestamp);
    }

    function test_lateDirectSwapGuardRollsBackEntireOperation() public {
        _bootstrap();
        uint256 input = token0.balanceOf(address(this));
        uint256 reserve0 = token0.balanceOf(address(vault));
        uint256 reserve1 = token1.balanceOf(address(vault));
        vm.expectRevert(InBase.UniswapV4ExchangeIn_SlippageExceeded.selector);
        vault.exchangeIn(token0, 1e18, token1, type(uint256).max, address(this), false, block.timestamp);
        assertEq(token0.balanceOf(address(this)), input);
        assertEq(token0.balanceOf(address(vault)), reserve0);
        assertEq(token1.balanceOf(address(vault)), reserve1);
        _assertBooked();
    }

    function test_disablingInboundPreservesShareExit() public {
        _bootstrap();
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(vault), true);
        uint256 quote = vault.previewExchangeIn(IERC20(address(vault)), 1e18, token0);
        assertEq(vault.exchangeIn(IERC20(address(vault)), 1e18, token0, quote, address(this), false, block.timestamp), quote);
        _assertBooked();
    }
}
// end::HooklessAdversarialTest[]
