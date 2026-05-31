// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import {Test} from "forge-std/Test.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolLiquidityTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolLiquidityTarget.sol";

contract LiquidityTargetExposed is StandardExchangeBufferPoolLiquidityTarget {
    function callOnAdd(address router, uint256[] memory amts)
        external returns (uint256[] memory, uint256, uint256[] memory, bytes memory)
    {
        return this.onAddLiquidityCustom(router, amts, 0, new uint256[](2), "");
    }
    function callOnRemove(address router, uint256[] memory amts)
        external returns (uint256, uint256[] memory, uint256[] memory, bytes memory)
    {
        return this.onRemoveLiquidityCustom(router, 0, amts, new uint256[](2), "");
    }
}

contract StandardExchangeBufferPoolLiquidityTargetTest is Test {
    LiquidityTargetExposed t;
    function setUp() public { t = new LiquidityTargetExposed(); }

    function test_addCustom_acceptsFromSelf() public {
        uint256[] memory amts = new uint256[](2); amts[0] = 5e18; amts[1] = 0;
        (uint256[] memory inScaled18, uint256 bptOut, uint256[] memory fees,) = t.callOnAdd(address(t), amts);
        assertEq(inScaled18[0], 5e18); assertEq(inScaled18[1], 0);
        assertEq(bptOut, 0);
        assertEq(fees.length, 2); assertEq(fees[0], 0); assertEq(fees[1], 0);
    }

    function test_addCustom_revertsForNonHookCaller() public {
        uint256[] memory amts = new uint256[](2); amts[0] = 5e18; amts[1] = 0;
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeBufferPool.NotHookCaller.selector, address(0xBEEF)));
        t.callOnAdd(address(0xBEEF), amts);
    }

    function test_removeCustom_acceptsFromSelf() public {
        uint256[] memory amts = new uint256[](2); amts[0] = 0; amts[1] = 7e18;
        (uint256 bptIn, uint256[] memory out, uint256[] memory fees,) = t.callOnRemove(address(t), amts);
        assertEq(bptIn, 0);
        assertEq(out[0], 0); assertEq(out[1], 7e18);
        assertEq(fees.length, 2);
    }

    function test_removeCustom_revertsForNonHookCaller() public {
        uint256[] memory amts = new uint256[](2); amts[0] = 0; amts[1] = 7e18;
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeBufferPool.NotHookCaller.selector, address(0xDEAD)));
        t.callOnRemove(address(0xDEAD), amts);
    }
}
