// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4UpperLowerWingsStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/test/bases/TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultSurfacesTest[]
contract UniswapV4UpperLowerWingsStandardExchangeVaultSurfacesTest is TestBase_UniswapV4UpperLowerWingsStandardExchangeVault {
    function setUp() public override {
        super.setUp();
        token0.mint(address(this), 1e25); token0.approve(address(wings0), type(uint256).max);
    }
    function test_exactOutputBootstrapMintsOnlyRequestedShares() public {
        IStandardExchangeOut exchange = IStandardExchangeOut(address(wings0));
        assertEq(exchange.previewExchangeOut(token0, IERC20(address(wings0)), 1e12), 1e12);
        uint256 beforeBalance = token0.balanceOf(address(this));
        assertEq(exchange.exchangeOut(token0, 1e12 + 999, IERC20(address(wings0)), 1e12, address(this), false, block.timestamp), 1e12);
        assertEq(IERC20(address(wings0)).balanceOf(address(this)), 1e12);
        assertEq(beforeBalance - token0.balanceOf(address(this)), 1e12);
    }
    function test_exactOutputBootstrapRefundExcludesPendingRefundFromBacking() public {
        uint256 beforeBalance = token0.balanceOf(address(this));
        token0.transfer(address(wings0), 1e12 + 300);
        IStandardExchangeOut(address(wings0)).exchangeOut(token0, 1e12 + 200, IERC20(address(wings0)), 1e12, address(this), true, block.timestamp);
        assertEq(beforeBalance - token0.balanceOf(address(this)), 1e12 + 100, "refund capped at max input");
        (uint256 local0,) = wings0.localReserves();
        assertEq(token0.balanceOf(address(wings0)), local0, "refund was never holder backing");
        assertEq(IERC20(address(wings0)).totalSupply(), 1e12);
    }
    function test_exactOutputWithdrawAndShareRefund() public {
        IStandardExchangeOut exchange = IStandardExchangeOut(address(wings0));
        exchange.exchangeOut(token0, 1e12, IERC20(address(wings0)), 1e12, address(this), false, block.timestamp);
        uint256 required = exchange.previewExchangeOut(IERC20(address(wings0)), token0, 1e9);
        uint256 beforeShares = IERC20(address(wings0)).balanceOf(address(this));
        IERC20(address(wings0)).transfer(address(wings0), required + 300);
        uint256 beforeTarget = token0.balanceOf(address(this));
        assertEq(exchange.exchangeOut(IERC20(address(wings0)), required + 200, token0, 1e9, address(this), true, block.timestamp), required);
        assertEq(token0.balanceOf(address(this)) - beforeTarget, 1e9);
        assertEq(beforeShares - IERC20(address(wings0)).balanceOf(address(this)), required + 100);
        assertEq(IERC20(address(wings0)).balanceOf(address(wings0)), 100, "above cap left unclaimed");
    }
    function testFuzz_exactOutputQuantitiesAreSufficientAndMinimal(uint64 seed_) public {
        IStandardExchangeOut exchange = IStandardExchangeOut(address(wings0));
        exchange.exchangeOut(token0, 1e12, IERC20(address(wings0)), 1e12, address(this), false, block.timestamp);
        uint256 wanted = bound(seed_, 1, 1e10);
        uint256 required = exchange.previewExchangeOut(token0, IERC20(address(wings0)), wanted);
        uint256 sufficient = IStandardExchangeIn(address(wings0)).previewExchangeIn(token0, required, IERC20(address(wings0)));
        assertGe(sufficient, wanted);
        if (required > 1) assertLt(IStandardExchangeIn(address(wings0)).previewExchangeIn(token0, required - 1, IERC20(address(wings0))), wanted);
        uint256 beforeShares = IERC20(address(wings0)).balanceOf(address(this));
        exchange.exchangeOut(token0, required, IERC20(address(wings0)), wanted, address(this), false, block.timestamp);
        assertEq(IERC20(address(wings0)).balanceOf(address(this)) - beforeShares, wanted);
    }
    function test_nativeSYReusesShareAndStandardMoneyRoutes() public {
        IStandardizedYield sy = IStandardizedYield(address(wings0));
        assertEq(sy.yieldToken(), address(wings0));
        assertEq(sy.getTokensIn().length, 1); assertEq(sy.getTokensIn()[0], address(token0));
        assertTrue(sy.isValidTokenIn(address(token0))); assertFalse(sy.isValidTokenIn(address(token1)));
        assertFalse(sy.isValidTokenIn(address(0)));
        uint256 preview = sy.previewDeposit(address(token0), 1e12);
        assertEq(sy.deposit(address(this), address(token0), 1e12, preview), preview);
        assertEq(sy.totalSupply(), preview);
        assertEq(sy.exchangeRate(), wings0.liquidationValue().value * 1e18 / sy.totalSupply());
        uint256 shares = preview / 4;
        uint256 out = sy.previewRedeem(address(token0), shares);
        assertEq(sy.redeem(address(this), shares, address(token0), out, false), out);
        IERC20(address(sy)).transfer(address(sy), shares + 100);
        out = sy.previewRedeem(address(token0), shares);
        assertEq(sy.redeem(address(this), shares, address(token0), out, true), out);
        assertEq(sy.balanceOf(address(sy)), 100, "internal balance remainder retained");
    }
    function test_nativeSYRejectsETHAndOpposingToken() public {
        vm.deal(address(this), 1);
        vm.expectRevert(NativeStandardYieldTarget.UnsupportedNativePayment.selector);
        IStandardizedYield(address(wings0)).deposit{value: 1}(address(this), address(token0), 100, 0);
        vm.expectRevert(abi.encodeWithSelector(NativeStandardYieldTarget.InvalidSYToken.selector, address(token1)));
        IStandardizedYield(address(wings0)).deposit(address(this), address(token1), 100, 0);
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultSurfacesTest[]
