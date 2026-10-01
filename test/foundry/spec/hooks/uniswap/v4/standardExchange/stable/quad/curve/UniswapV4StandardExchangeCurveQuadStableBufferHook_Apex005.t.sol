// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";

/// @notice APEX-2026-005 / D9 / D15 / D28 on the production hook proxy: contract-only pretransfer,
///         bounded exact-out credit with `credit - used` refund, exact-in credits the request only.
contract UniswapV4StandardExchangeCurveQuadStableBufferHook_Apex005Test is TestBase {

    address internal apexAttacker;
    AtomicPretransferCaller internal apexCaller;

    function setUp() public virtual override {
        super.setUp();
        apexAttacker = makeAddr("apexAttacker");
        apexCaller = new AtomicPretransferCaller();
        _firstMintEqual(200 ether);
    }

    function _apexMint(address token, address to, uint256 amount) internal {
        SimpleMintableERC20(token).mint(to, amount);
    }

    function _apexIn() internal view returns (IERC20) { return IERC20(address(token1)); }
    function _apexOut() internal view returns (IERC20) { return IERC20(address(token2)); }

    /// @dev D9/R13.1: an EOA with resting balance cannot use `pretransferred=true` on `exchangeIn`.
    function test_APEX005_eoaPretransfer_exchangeIn_rejected() public {
        IERC20 tin = _apexIn();
        IERC20 tout = _apexOut();
        uint256 amountIn = 1 ether;
        _apexMint(address(tin), apexAttacker, amountIn);
        vm.prank(apexAttacker);
        tin.transfer(hook, amountIn);
        uint256 hookInBefore = tin.balanceOf(hook);
        uint256 attackerOutBefore = tout.balanceOf(apexAttacker);
        vm.prank(apexAttacker);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IStandardExchangeIn(hook).exchangeIn(tin, amountIn, tout, 0, apexAttacker, true, block.timestamp + 1 hours);
        assertEq(tin.balanceOf(hook), hookInBefore, "no state change on reject");
        assertEq(tout.balanceOf(apexAttacker), attackerOutBefore, "no output on reject");
    }

    /// @dev D9/R13.1: an EOA with resting balance cannot use `pretransferred=true` on `exchangeOut`.
    function test_APEX005_eoaPretransfer_exchangeOut_rejected() public {
        IERC20 tin = _apexIn();
        IERC20 tout = _apexOut();
        uint256 wantOut = 1 ether;
        uint256 needIn = IStandardExchangeOut(hook).previewExchangeOut(tin, tout, wantOut);
        assertGt(needIn, 0);
        _apexMint(address(tin), apexAttacker, needIn);
        vm.prank(apexAttacker);
        tin.transfer(hook, needIn);
        uint256 attackerOutBefore = tout.balanceOf(apexAttacker);
        vm.prank(apexAttacker);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IStandardExchangeOut(hook).exchangeOut(tin, needIn * 2, tout, wantOut, apexAttacker, true, block.timestamp + 1 hours);
        assertEq(tout.balanceOf(apexAttacker), attackerOutBefore, "no output on reject");
    }

    /// @dev D15: a contract that pretransfers `fatMax` on exact-out receives back exactly
    ///      `credit - used` where `credit = min(unbooked, maxAmountIn)`.
    function test_APEX005_exactOut_trueFlag_refundsCreditMinusUsed() public {
        IERC20 tin = _apexIn();
        IERC20 tout = _apexOut();
        uint256 wantOut = 1 ether;
        uint256 needIn = IStandardExchangeOut(hook).previewExchangeOut(tin, tout, wantOut);
        assertGt(needIn, 0);
        uint256 fatMax = needIn * 3;
        _apexMint(address(tin), address(this), fatMax);
        tin.approve(address(apexCaller), fatMax);
        uint256 callerOutBefore = tout.balanceOf(address(apexCaller));
        bytes memory data = abi.encodeCall(
            IStandardExchangeOut.exchangeOut,
            (tin, fatMax, tout, wantOut, address(apexCaller), true, block.timestamp + 1 hours)
        );
        uint256 used = abi.decode(apexCaller.consumePretransfer(tin, address(this), hook, fatMax, data), (uint256));
        assertGt(used, 0);
        assertLe(used, fatMax, "used within the bounded credit");
        assertEq(tout.balanceOf(address(apexCaller)) - callerOutBefore, wantOut, "exact output delivered");
        assertEq(tin.balanceOf(address(apexCaller)), fatMax - used, "refund is credit - used");
        assertEq(tin.balanceOf(address(this)), 0, "payer spent fatMax");
    }

    /// @dev D15: `pretransferred=false` exact-out pulls exactly the quoted `used` and refunds nothing.
    function test_APEX005_exactOut_falseFlag_pullsUsedOnly() public {
        IERC20 tin = _apexIn();
        IERC20 tout = _apexOut();
        uint256 wantOut = 1 ether;
        uint256 needIn = IStandardExchangeOut(hook).previewExchangeOut(tin, tout, wantOut);
        uint256 fatMax = needIn * 3;
        _apexMint(address(tin), user, fatMax);
        vm.startPrank(user);
        tin.approve(hook, fatMax);
        uint256 outBefore = tout.balanceOf(user);
        uint256 inBefore = tin.balanceOf(user);
        uint256 used = IStandardExchangeOut(hook).exchangeOut(tin, fatMax, tout, wantOut, user, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(used, needIn, "pulls quoted used");
        assertEq(inBefore - tin.balanceOf(user), needIn, "only used pulled");
        assertEq(tout.balanceOf(user) - outBefore, wantOut, "exact output");
    }

    /// @dev D28/R13.5: 100 resting unbooked units with a request for 1 credit exactly 1, refund
    ///      nothing, and leave the other 99 for a later contract caller (D12 accepted residual).
    function test_APEX005_exactIn_excessResting_creditsRequestedOnly() public {
        IERC20 tin = _apexIn();
        IERC20 tout = _apexOut();
        uint256 resting = 100 ether;
        uint256 request = 1 ether;
        uint256 quote = IStandardExchangeIn(hook).previewExchangeIn(tin, request, tout);
        assertGt(quote, 0);
        _apexMint(address(tin), address(this), resting);
        tin.approve(address(apexCaller), resting);
        bytes memory data = abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (tin, request, tout, 0, address(apexCaller), true, block.timestamp + 1 hours)
        );
        uint256 hookInBefore = tin.balanceOf(hook);
        uint256 got = abi.decode(apexCaller.consumePretransfer(tin, address(this), hook, resting, data), (uint256));
        assertGt(got, 0, "credited the request");
        // The resting 100 shifts the hook's face reserve, so the output is bounded by the pre-transfer
        // quote for the request, never by the quote for the whole resting balance.
        assertLe(got, (quote * 105) / 100, "output for the requested amount only");
        assertEq(tin.balanceOf(address(apexCaller)), 0, "exact-in refunds nothing");
        assertEq(tout.balanceOf(address(apexCaller)), got, "output for the requested amount only");
        // The 99 uncredited units stayed with the hook (booked or resting credit), never refunded.
        assertGe(tin.balanceOf(hook), hookInBefore + resting - request, "excess stays with the hook");
    }
}
