// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile_Test as Fixture} from "./UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
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

    function test_review_underfundedEoaExactOutObservesCreditError() public {
        _dualJoin(1000 ether, 1000 ether);
        IERC20 input = IERC20(_token0());
        uint256 shares = vault.totalSupply() / 100;
        uint256 used = vault.previewExchangeOut(input, IERC20(address(vault)), shares);
        assertGt(used, 0);
        uint256 supply = vault.totalSupply();
        uint256 held = input.balanceOf(address(vault));
        address outsider = makeAddr("review outsider");
        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, used, 0));
        vault.exchangeOut(input, used, IERC20(address(vault)), shares, outsider, true, block.timestamp);
        assertEq(vault.totalSupply(), supply);
        assertEq(input.balanceOf(address(vault)), held);
        _assertLocalReserveMatchesCustody();
    }
}
