// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {TestBase_UniswapV4UpperLowerWingsStandardExchangeVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/test/bases/TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol";

/// @notice RC-01 on the production Wings proxy.
contract UniswapV4UpperLowerWingsVaultHeldRedeem_Test is TestBase_UniswapV4UpperLowerWingsStandardExchangeVault {
    address internal recipient;

    function setUp() public override {
        super.setUp();
        token0.mint(address(this), 1e24);
        token1.mint(address(this), 1e24);
        token0.approve(address(wings0), type(uint256).max);
        IStandardExchangeIn exchange = IStandardExchangeIn(address(wings0));
        uint256 issued = exchange.exchangeIn(token0, 1e18, IERC20(address(wings0)), 1e18, address(this), false, block.timestamp);
        assertEq(issued, 1e18);
        recipient = makeAddr("wingsSyRecipient");
    }

    function test_RC01_codeLessCaller_rejectedBeforeBurn() public {
        uint256 callerBefore = IERC20(address(wings0)).balanceOf(address(this));
        uint256 vaultBefore = IERC20(address(wings0)).balanceOf(address(wings0));
        vm.prank(makeAddr("wingsSyEoa"));
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IStandardizedYield(address(wings0)).redeem(recipient, 1, address(token0), 0, true);
        assertEq(IERC20(address(wings0)).balanceOf(address(this)), callerBefore);
        assertEq(IERC20(address(wings0)).balanceOf(address(wings0)), vaultBefore);
        assertEq(token0.balanceOf(recipient), 0);
    }

    function test_RC01_contractCaller_redeemsOnlyRequestedVaultShares() public {
        uint256 requested = 1e15;
        IERC20(address(wings0)).transfer(address(wings0), requested * 2);
        uint256 callerBefore = IERC20(address(wings0)).balanceOf(address(this));
        uint256 vaultBefore = IERC20(address(wings0)).balanceOf(address(wings0));
        uint256 outBefore = token0.balanceOf(recipient);
        vm.expectCall(address(wings0), abi.encodeWithSelector(IStandardExchangeIn.exchangeIn.selector), 0);
        uint256 paid = IStandardizedYield(address(wings0)).redeem(recipient, requested, address(token0), 0, true);
        assertGt(paid, 0);
        assertEq(IERC20(address(wings0)).balanceOf(address(this)), callerBefore);
        assertEq(IERC20(address(wings0)).balanceOf(address(wings0)), vaultBefore - requested);
        assertEq(token0.balanceOf(recipient), outBefore + paid);
    }

    function test_RC01_ordinaryRedeem_burnsCallerShares() public {
        uint256 requested = 1e15;
        uint256 callerBefore = IERC20(address(wings0)).balanceOf(address(this));
        uint256 vaultBefore = IERC20(address(wings0)).balanceOf(address(wings0));
        uint256 paid = IStandardizedYield(address(wings0)).redeem(recipient, requested, address(token0), 0, false);
        assertGt(paid, 0);
        assertEq(IERC20(address(wings0)).balanceOf(address(this)), callerBefore - requested);
        assertEq(IERC20(address(wings0)).balanceOf(address(wings0)), vaultBefore);
        assertEq(token0.balanceOf(recipient), paid);
    }
}
