// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {TestBase_SlipstreamStandardExchange_Decimals} from
    "contracts/protocols/dexes/aerodrome/slipstream/test/bases/TestBase_SlipstreamStandardExchange_Decimals.sol";

/// @notice E6 + I1 on combo-decimal pair tokens. J1–J3 N/A (EX-IFACET).
abstract contract Adversarial_SlipstreamSE_E6IJ_Decimals is TestBase_SlipstreamStandardExchange_Decimals {
    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("slipAttacker");
    }

    function _booked0() internal view returns (uint256) {
        return _u0(100);
    }

    function _booked1() internal view returns (uint256) {
        return _u1(100);
    }

    function test_E6_in_refund_doesNotSweepBookedInventory() public {
        uint256 booked0 = _booked0();
        uint256 booked1 = _booked1();
        uint256 amountIn = _u0(10);
        pairToken0.mint(address(vault), booked0);
        pairToken1.mint(address(vault), booked1);
        uint256 vault0Before = pairToken0.balanceOf(address(vault));
        uint256 vault1Before = pairToken1.balanceOf(address(vault));
        assertGe(vault0Before, booked0, "seed token0");
        assertGe(vault1Before, booked1, "seed token1");

        pairToken0.mint(attacker, amountIn);

        vm.startPrank(attacker);
        pairToken0.approve(address(vault), amountIn);
        uint256 sharesOut = vault.exchangeIn(
            IERC20(address(pairToken0)),
            amountIn,
            IERC20(address(vault)),
            0,
            attacker,
            false,
            _deadline()
        );
        vm.stopPrank();

        assertGt(sharesOut, 0, "honest zap minted");
        uint256 attTokensAfter = pairToken0.balanceOf(attacker) + pairToken1.balanceOf(attacker);
        assertLe(attTokensAfter, amountIn, "E6: refund cannot exceed this-call inbound");
        assertLt(attTokensAfter, booked0, "E6: attacker must not be paid booked R");
        assertGe(pairToken0.balanceOf(address(vault)), booked0, "E6: booked token0 remains");
        assertGe(pairToken1.balanceOf(address(vault)), booked1, "E6: booked token1 remains");
    }

    function test_E6_out_pretransferred_fatMax_doesNotSkimBook() public {
        uint256 booked0 = _booked0();
        pairToken0.mint(address(vault), booked0);
        uint256 used = _u0(1);
        uint256 fatMax = used + _u0(50);
        uint256 amountOut = _u1(1) / 10;
        if (amountOut == 0) amountOut = 1;
        uint256 quotedUsed = vault.previewExchangeOut(
            IERC20(address(pairToken0)), IERC20(address(pairToken1)), amountOut
        );
        assertGt(quotedUsed, 0, "quoted used");
        assertLe(quotedUsed, fatMax, "quoted fits fat max");

        pairToken0.mint(attacker, used);
        vm.prank(attacker);
        pairToken0.transfer(address(vault), used);

        uint256 vaultBefore = pairToken0.balanceOf(address(vault));
        uint256 attBefore = pairToken0.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, quotedUsed, uint256(0))
        );
        vault.exchangeOut(
            IERC20(address(pairToken0)),
            fatMax,
            IERC20(address(pairToken1)),
            amountOut,
            attacker,
            true,
            _deadline()
        );

        assertEq(pairToken0.balanceOf(address(vault)), vaultBefore, "E6 out: booked R stays");
        assertEq(pairToken0.balanceOf(attacker), attBefore, "E6 out: attacker not paid R");
    }

    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        uint256 booked0 = _booked0();
        pairToken0.mint(address(vault), booked0);
        uint256 invBefore = pairToken0.balanceOf(address(vault));
        uint256 claimed = booked0;
        uint256 attSharesBefore = IERC20(address(vault)).balanceOf(attacker);
        assertEq(pairToken0.balanceOf(attacker), 0, "attacker drained");
        assertEq(pairToken0.allowance(attacker, address(vault)), 0, "no allowance");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed, uint256(0))
        );
        vault.exchangeIn(
            IERC20(address(pairToken0)),
            claimed,
            IERC20(address(vault)),
            0,
            attacker,
            true,
            _deadline()
        );

        assertEq(IERC20(address(vault)).balanceOf(attacker), attSharesBefore, "I1: no free vaultShare");
        assertEq(pairToken0.balanceOf(address(vault)), invBefore, "I1: inventory unchanged");
    }

    function test_I1_exchangeOut_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        uint256 booked0 = _booked0();
        pairToken0.mint(address(vault), booked0);
        uint256 invBefore = pairToken0.balanceOf(address(vault));
        uint256 amountOut = _u1(1) / 10;
        if (amountOut == 0) amountOut = 1;
        uint256 claimed = _u0(1);
        uint256 quotedUsed = vault.previewExchangeOut(
            IERC20(address(pairToken0)), IERC20(address(pairToken1)), amountOut
        );
        assertGt(quotedUsed, 0, "quoted used");
        assertLe(quotedUsed, claimed, "quoted fits claimed max");
        uint256 att0Before = pairToken0.balanceOf(attacker);
        uint256 att1Before = pairToken1.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, quotedUsed, uint256(0))
        );
        vault.exchangeOut(
            IERC20(address(pairToken0)),
            claimed,
            IERC20(address(pairToken1)),
            amountOut,
            attacker,
            true,
            _deadline()
        );

        assertEq(pairToken0.balanceOf(attacker), att0Before, "I1 out: no token0");
        assertEq(pairToken1.balanceOf(attacker), att1Before, "I1 out: no token1");
        assertEq(pairToken0.balanceOf(address(vault)), invBefore, "I1 out: inventory unchanged");
    }
}
