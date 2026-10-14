// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile_Test as Fixture} from "./UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {UniswapV3FullSpreadStandardExchangeVaultCommon} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

contract UniswapV3FullSpreadApexRecurrenceErrorOrderTest is Fixture {
    function test_review_directExactOutSupportedControl() public {
        IERC20 input = IERC20(_token0());
        IERC20 output = IERC20(pool.token1());
        uint256 requested = 1 ether;
        uint256 quoted = vault.previewExchangeOut(input, output, requested);
        assertGt(quoted, 0);
        ERC20PermitMintableStub(address(input)).mint(address(this), quoted);
        input.approve(address(vault), quoted);
        uint256 beforeOutput = output.balanceOf(address(this));
        uint256 used = vault.exchangeOut(input, quoted, output, requested, address(this), false, block.timestamp);
        assertEq(used, quoted);
        assertEq(output.balanceOf(address(this)) - beforeOutput, requested);
        _assertLocalReserveMatchesCustody();
    }

    function test_review_directExactOutRejectsUnfilledOutput() public {
        IERC20 input = IERC20(_token0());
        IERC20 output = IERC20(pool.token1());
        uint256 requested = output.balanceOf(address(pool)) + 1;
        uint256 beforeInput = input.balanceOf(address(this));
        uint256 beforeOutput = output.balanceOf(address(this));
        vm.expectPartialRevert(UniswapV3FullSpreadStandardExchangeVaultCommon.UniswapV3Exchange_ExactOutputNotFilled.selector);
        vault.previewExchangeOut(input, output, requested);
        assertEq(input.balanceOf(address(this)), beforeInput);
        assertEq(output.balanceOf(address(this)), beforeOutput);
        _assertLocalReserveMatchesCustody();
    }

    function test_review_eoaInternalSyRedeemConsumesSelfShares() public {
        _dualJoin(1000 ether, 1000 ether);
        uint256 shares = vault.balanceOf(address(this)) / 100;
        IERC20 output = IERC20(_token0());
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
        _dualJoin(1000 ether, 1000 ether);
        IERC20 input = IERC20(_token0());
        uint256 shares = vault.totalSupply() / 100;
        uint256 used = vault.previewExchangeOut(input, IERC20(address(vault)), shares);
        assertGt(used, 0);
        uint256 supply = vault.totalSupply();
        uint256 held = input.balanceOf(address(vault));
        address outsider = makeAddr("review outsider");
        assertEq(outsider.code.length, 0);
        vm.prank(outsider);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeOut(input, used, IERC20(address(vault)), shares, outsider, true, block.timestamp);
        assertEq(vault.totalSupply(), supply);
        assertEq(input.balanceOf(address(vault)), held);
        _assertLocalReserveMatchesCustody();
    }

    function test_review_underfundedContractExactOutObservesCreditError() public {
        _dualJoin(1000 ether, 1000 ether);
        IERC20 input = IERC20(_token0());
        uint256 shares = vault.totalSupply() / 100;
        uint256 used = vault.previewExchangeOut(input, IERC20(address(vault)), shares);
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        uint256 supply = vault.totalSupply();
        uint256 held = input.balanceOf(address(vault));
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, used, 0));
        caller.execute(address(vault), abi.encodeCall(
            IStandardExchangeOut.exchangeOut,
            (input, used, IERC20(address(vault)), shares, address(caller), true, block.timestamp)
        ));
        assertEq(vault.totalSupply(), supply);
        assertEq(input.balanceOf(address(vault)), held);
        _assertLocalReserveMatchesCustody();
    }

    function test_review_underfundedEoaDirectExactOutObservesCallerError() public {
        _dualJoin(1000 ether, 1000 ether);
        IERC20 input = IERC20(_token0());
        IERC20 output = IERC20(pool.token1());
        uint256 requested = 1 ether;
        uint256 quoted = vault.previewExchangeOut(input, output, requested);
        address outsider = makeAddr("review direct outsider");
        assertEq(outsider.code.length, 0);
        uint256 held = input.balanceOf(address(vault));
        uint256 received = output.balanceOf(outsider);
        vm.prank(outsider);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeOut(input, quoted, output, requested, outsider, true, block.timestamp);
        assertEq(input.balanceOf(address(vault)), held);
        assertEq(output.balanceOf(outsider), received);
        _assertLocalReserveMatchesCustody();
    }

    function test_review_fundedContractDirectExactOutSpendsNoMoreThanMaximum() public {
        _dualJoin(1000 ether, 1000 ether);
        IERC20 input = IERC20(_token0());
        IERC20 output = IERC20(pool.token1());
        uint256 requested = 1 ether;
        uint256 quoted = vault.previewExchangeOut(input, output, requested);
        uint256 maximum = quoted;
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        ERC20PermitMintableStub(address(input)).mint(address(this), maximum);
        input.approve(address(caller), maximum);
        uint256 beforeOut = output.balanceOf(address(caller));
        uint256 spent = abi.decode(caller.consumePretransfer(
            input, address(this), address(vault), maximum,
            abi.encodeCall(IStandardExchangeOut.exchangeOut, (input, maximum, output, requested, address(caller), true, block.timestamp))
        ), (uint256));
        assertLe(spent, maximum);
        assertEq(spent, quoted);
        assertEq(output.balanceOf(address(caller)) - beforeOut, requested);
        _assertLocalReserveMatchesCustody();
    }

    function test_review_falseFlagEoaDirectExactOutDoesNotUseCallerGuard() public {
        _dualJoin(1000 ether, 1000 ether);
        IERC20 input = IERC20(_token0());
        IERC20 output = IERC20(pool.token1());
        uint256 requested = 1 ether;
        uint256 quoted = vault.previewExchangeOut(input, output, requested);
        address outsider = makeAddr("review false-flag outsider");
        assertEq(outsider.code.length, 0);
        ERC20PermitMintableStub(address(input)).mint(outsider, quoted);
        vm.startPrank(outsider);
        input.approve(address(vault), quoted);
        uint256 beforeOut = output.balanceOf(outsider);
        uint256 spent = vault.exchangeOut(input, quoted, output, requested, outsider, false, block.timestamp);
        vm.stopPrank();
        assertLe(spent, quoted);
        assertEq(spent, quoted);
        assertEq(output.balanceOf(outsider) - beforeOut, requested);
        _assertLocalReserveMatchesCustody();
    }
}
