// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultInExecutionBinding as ExitBinding} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/interfaces/IUniswapV4FullSpreadHooklessStandardExchangeVaultComponentBindings.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";

/// @notice RC-01 on the production hookless FullSpread proxy.
contract UniswapV4FullSpreadHooklessVaultHeldRedeem_Test is
    TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance
{
    address internal recipient;

    function setUp() public override {
        super.setUp();
        _bootstrap();
        recipient = makeAddr("hooklessSyRecipient");
    }

    /// @notice The held-share delegate cannot be called directly or through the proxy surface.
    function test_heldRedemptionDelegateHasNoPublicVaultEntry() public {
        address delegate_ = ExitBinding(address(vault)).UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE();
        bytes memory data_ = abi.encodeWithSignature(
            "executeZapOutExactIn(address,uint256,uint256,address)", address(token0), 1, 0, recipient
        );
        (bool ok_, bytes memory reason_) = delegate_.call(data_);
        assertFalse(ok_);
        assertEq(reason_, abi.encodeWithSignature("AccountingMismatch()"));
        (ok_, reason_) = address(vault).call(data_);
        assertFalse(ok_);
        assertEq(reason_, abi.encodeWithSignature("NoTargetFor(bytes4)", bytes4(data_)));
    }

    function test_RC01_codeLessCaller_rejectedBeforeBurn() public {
        uint256 callerBefore = vault.balanceOf(address(this));
        uint256 vaultBefore = vault.balanceOf(address(vault));
        vm.prank(makeAddr("hooklessSyEoa"));
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IStandardizedYield(address(vault)).redeem(recipient, 1, address(token0), 0, true);
        assertEq(vault.balanceOf(address(this)), callerBefore);
        assertEq(vault.balanceOf(address(vault)), vaultBefore);
        assertEq(token0.balanceOf(recipient), 0);
    }

    function test_RC01_contractCaller_redeemsOnlyRequestedVaultShares() public {
        uint256 requested = 1e15;
        vault.transfer(address(vault), requested * 2);
        uint256 callerBefore = vault.balanceOf(address(this));
        uint256 vaultBefore = vault.balanceOf(address(vault));
        uint256 outBefore = token0.balanceOf(recipient);
        vm.expectCall(address(vault), abi.encodeWithSelector(IStandardExchangeIn.exchangeIn.selector), 0);
        uint256 paid = IStandardizedYield(address(vault)).redeem(recipient, requested, address(token0), 0, true);
        assertGt(paid, 0);
        assertEq(vault.balanceOf(address(this)), callerBefore);
        assertEq(vault.balanceOf(address(vault)), vaultBefore - requested);
        assertEq(token0.balanceOf(recipient), outBefore + paid);
    }

    function test_RC01_ordinaryRedeem_burnsCallerShares() public {
        uint256 requested = 1e15;
        uint256 callerBefore = vault.balanceOf(address(this));
        uint256 vaultBefore = vault.balanceOf(address(vault));
        uint256 paid = IStandardizedYield(address(vault)).redeem(recipient, requested, address(token0), 0, false);
        assertGt(paid, 0);
        assertEq(vault.balanceOf(address(this)), callerBefore - requested);
        assertEq(vault.balanceOf(address(vault)), vaultBefore);
        assertEq(token0.balanceOf(recipient), paid);
    }
}
