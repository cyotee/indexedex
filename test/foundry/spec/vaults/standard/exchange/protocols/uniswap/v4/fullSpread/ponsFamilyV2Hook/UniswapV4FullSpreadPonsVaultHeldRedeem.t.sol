// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IUniswapV4FullSpreadPonsFamilyHookInExecutionBinding as ExitBinding} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/interfaces/IUniswapV4FullSpreadPonsFamilyHookComponentBindings.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch.sol";

/// @notice RC-01 on the production Pons-family FullSpread proxy.
contract UniswapV4FullSpreadPonsVaultHeldRedeem_Test is TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch {
    address internal recipient;
    address internal tokenOut;

    function setUp() public override {
        super.setUp();
        _activatePonsSe();
        recipient = makeAddr("ponsSyRecipient");
        tokenOut = address(weth);
    }

    /// @notice The held-share delegate cannot be called directly or through the proxy surface.
    function test_heldRedemptionDelegateHasNoPublicVaultEntry() public {
        address delegate_ = ExitBinding(address(ponsSe)).UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE();
        bytes memory data_ = abi.encodeWithSignature(
            "executeZapOutExactIn(address,uint256,uint256,address)", tokenOut, 1, 0, recipient
        );
        (bool ok_, bytes memory reason_) = delegate_.call(data_);
        assertFalse(ok_);
        assertEq(reason_, abi.encodeWithSignature("AccountingMismatch()"));
        (ok_, reason_) = address(ponsSe).call(data_);
        assertFalse(ok_);
        assertEq(reason_, abi.encodeWithSignature("NoTargetFor(bytes4)", bytes4(data_)));
    }

    function test_RC01_codeLessCaller_rejectedBeforeBurn() public {
        uint256 callerBefore = ponsSe.balanceOf(address(this));
        uint256 vaultBefore = ponsSe.balanceOf(address(ponsSe));
        vm.prank(makeAddr("ponsSyEoa"));
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IStandardizedYield(address(ponsSe)).redeem(recipient, 1, tokenOut, 0, true);
        assertEq(ponsSe.balanceOf(address(this)), callerBefore);
        assertEq(ponsSe.balanceOf(address(ponsSe)), vaultBefore);
        assertEq(IERC20(tokenOut).balanceOf(recipient), 0);
    }

    function test_RC01_contractCaller_redeemsOnlyRequestedVaultShares() public {
        uint256 requested = ponsSe.balanceOf(address(this)) / 20;
        require(requested > 1, "activation issued shares");
        ponsSe.transfer(address(ponsSe), requested * 2);
        uint256 callerBefore = ponsSe.balanceOf(address(this));
        uint256 vaultBefore = ponsSe.balanceOf(address(ponsSe));
        uint256 outBefore = IERC20(tokenOut).balanceOf(recipient);
        vm.expectCall(address(ponsSe), abi.encodeWithSelector(IStandardExchangeIn.exchangeIn.selector), 0);
        uint256 paid = IStandardizedYield(address(ponsSe)).redeem(recipient, requested, tokenOut, 0, true);
        assertGt(paid, 0);
        assertEq(ponsSe.balanceOf(address(this)), callerBefore);
        assertEq(ponsSe.balanceOf(address(ponsSe)), vaultBefore - requested);
        assertEq(IERC20(tokenOut).balanceOf(recipient), outBefore + paid);
    }

    function test_RC01_ordinaryRedeem_burnsCallerShares() public {
        uint256 requested = ponsSe.balanceOf(address(this)) / 20;
        require(requested > 0, "caller holds shares");
        uint256 callerBefore = ponsSe.balanceOf(address(this));
        uint256 vaultBefore = ponsSe.balanceOf(address(ponsSe));
        uint256 paid = IStandardizedYield(address(ponsSe)).redeem(recipient, requested, tokenOut, 0, false);
        assertGt(paid, 0);
        assertEq(ponsSe.balanceOf(address(this)), callerBefore - requested);
        assertEq(ponsSe.balanceOf(address(ponsSe)), vaultBefore);
        assertEq(IERC20(tokenOut).balanceOf(recipient), paid);
    }
}
