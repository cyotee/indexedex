// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";

/// @notice Review probes of the documented D9/R13 error contract on real registry proxies.
contract HooklessApexRecurrenceErrorOrderTest is Acceptance {
    function test_review_eoaInternalSyRedeemConsumesSelfShares() public {
        _bootstrap();
        uint256 shares = vault.balanceOf(address(this)) / 100;
        IERC20 output = token0;
        vault.transfer(address(vault), shares);
        address outsider = makeAddr("review SY outsider");
        assertEq(outsider.code.length, 0);
        uint256 supply = vault.totalSupply();
        uint256 balance = output.balanceOf(outsider);
        vm.prank(outsider);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IStandardizedYield(address(vault)).redeem(outsider, shares, address(output), 0, true);
        assertEq(output.balanceOf(outsider), balance);
        assertEq(vault.balanceOf(address(vault)), shares);
        assertEq(vault.totalSupply(), supply);
    }

    /// @dev Former credit-first probe. A code-less short push now reaches the caller error first.
    function test_review_underfundedEoaExactOutObservesCreditError() public {
        _bootstrap();
        uint256 output = unit0;
        uint256 used = vault.previewExchangeOut(token1, token0, output);
        assertGt(used, 0, "supported positive quote");
        uint256 supply = vault.totalSupply();
        uint256 local0 = token0.balanceOf(address(vault));
        uint256 local1 = token1.balanceOf(address(vault));
        address outsider = makeAddr("review outsider");
        assertEq(outsider.code.length, 0);
        vm.prank(outsider);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeOut(token1, used, token0, output, outsider, true, block.timestamp);
        assertEq(vault.totalSupply(), supply);
        assertEq(token0.balanceOf(address(vault)), local0);
        assertEq(token1.balanceOf(address(vault)), local1);
        _assertBooked();
    }

    function test_review_underfundedContractExactOutObservesCreditError() public {
        _bootstrap();
        uint256 output = unit0;
        uint256 used = vault.previewExchangeOut(token1, token0, output);
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        uint256 supply = vault.totalSupply();
        uint256 local0 = token0.balanceOf(address(vault));
        uint256 local1 = token1.balanceOf(address(vault));
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, used, 0));
        caller.execute(address(vault), abi.encodeCall(
            IStandardExchangeOut.exchangeOut,
            (token1, used, token0, output, address(caller), true, block.timestamp)
        ));
        assertEq(vault.totalSupply(), supply);
        assertEq(token0.balanceOf(address(vault)), local0);
        assertEq(token1.balanceOf(address(vault)), local1);
        _assertBooked();
    }

    function test_review_fundedContractExactOutSpendsNoMoreThanMaximum() public {
        _bootstrap();
        uint256 output = 1e15;
        uint256 quote = vault.previewExchangeOut(token1, token0, output);
        uint256 maximum = quote + 1e18;
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        token1.approve(address(caller), maximum);
        uint256 beforeOut = token0.balanceOf(address(caller));
        uint256 spent = abi.decode(caller.consumePretransfer(
            token1, address(this), address(vault), maximum,
            abi.encodeCall(IStandardExchangeOut.exchangeOut, (token1, maximum, token0, output, address(caller), true, block.timestamp))
        ), (uint256));
        assertLe(spent, maximum);
        assertEq(spent, quote);
        assertEq(token0.balanceOf(address(caller)) - beforeOut, output);
        _assertBooked();
    }

    function test_review_falseFlagEoaExactOutDoesNotUseCallerGuard() public {
        _bootstrap();
        uint256 output = 1e15;
        uint256 quote = vault.previewExchangeOut(token1, token0, output);
        address outsider = makeAddr("review false-flag outsider");
        assertEq(outsider.code.length, 0);
        token1.transfer(outsider, quote);
        vm.startPrank(outsider);
        token1.approve(address(vault), quote);
        uint256 beforeOut = token0.balanceOf(outsider);
        uint256 spent = vault.exchangeOut(token1, quote, token0, output, outsider, false, block.timestamp);
        vm.stopPrank();
        assertLe(spent, quote);
        assertEq(spent, quote);
        assertEq(token0.balanceOf(outsider) - beforeOut, output);
        _assertBooked();
    }

    function test_review_fundedEoaExactOutReachesCallerGuard() public {
        _bootstrap();
        uint256 output = unit0;
        uint256 used = vault.previewExchangeOut(token1, token0, output);
        assertGt(used, 0, "supported positive quote");
        token1.transfer(address(vault), used);
        uint256 supply = vault.totalSupply();
        uint256 held = token1.balanceOf(address(vault));
        address outsider = makeAddr("review outsider");
        vm.prank(outsider);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeOut(token1, used, token0, output, outsider, true, block.timestamp);
        assertEq(vault.totalSupply(), supply);
        assertEq(token1.balanceOf(address(vault)), held, "prior separate prepayment remains");
    }
}
