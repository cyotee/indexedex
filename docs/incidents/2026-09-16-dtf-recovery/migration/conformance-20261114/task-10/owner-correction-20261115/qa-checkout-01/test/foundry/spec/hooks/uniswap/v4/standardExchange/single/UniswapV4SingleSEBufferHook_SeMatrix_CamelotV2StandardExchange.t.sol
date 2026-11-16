// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_CamelotFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_CamelotFixture.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV4SingleSEBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol";

/// @notice D20: non-CP single × CamelotV2StandardExchange. Face: 18-decimal pair token A of a seeded hermetic Camelot V2 pair; SE shares 27 decimals (reserve 18 + 9).
contract UniswapV4SingleSEBufferHook_SeMatrix_CamelotV2StandardExchange is UniswapV4SingleSEBufferHook_SeMatrixBehavior {
    /// @dev The first fixture deploys the protocol and the SE package; later SE legs reuse both through it.
    address internal sharedFixture;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_CamelotFixture f = new SeMatrix_CamelotFixture(_ctx(), sharedFixture);
        sharedFixture = address(f);
        return f;
    }

    /// @dev INCOMPATIBLE by owner ruling on finding F3 (2026-09-21): the Camelot SE has no exact-out mint
    ///      route. By design `previewExchangeOut(face, se, sharesOut)` returns 0 for an unsupported route
    ///      (previews are not reverted) and `exchangeOut` reverts `InvalidRoute(tokenIn, tokenOut)` at the
    ///      ZapIn Vault Deposit branch of `CamelotV2StandardExchangeOutTarget`. The non-CP hook mints
    ///      exact-out on wrap exact-out, so `previewWrapExactOut` quotes 0 and the router rejects `ZeroMaxIn()`.
    ///      Named production check (M2): `InvalidRoute` at the SE's `exchangeOut`, and the 0 preview.
    function test_INCOMPATIBLE_InvalidRoute() public {
        uint256 wantSe = buffer.previewWrap(_f(1));
        assertGt(wantSe, 0, "exact-in wrap quotes");
        assertEq(
            IStandardExchangeOut(seUT).previewExchangeOut(IERC20(face), IERC20(seUT), wantSe),
            0,
            "Camelot exact-out mint preview is 0 for the unsupported route"
        );
        assertEq(buffer.previewWrapExactOut(wantSe), 0, "hook wrap exact-out preview is 0");
        fx.fund(user, _f(10));
        vm.startPrank(user);
        IERC20(face).approve(seUT, _f(10));
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("InvalidRoute(address,address)")), face, seUT));
        IStandardExchangeOut(seUT).exchangeOut(IERC20(face), _f(10), IERC20(seUT), wantSe, user, false, block.timestamp + 1 hours);
        vm.stopPrank();
        emit log("INCOMPATIBLE F3 (owner ruling 2026-09-21): Camelot has no exact-out mint route; preview 0, execute InvalidRoute");
    }

    /// @dev The four gold rows that need an exact-out wrap cannot run on this pairing; each records the same named check.
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override { test_INCOMPATIBLE_InvalidRoute(); }
    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override { test_INCOMPATIBLE_InvalidRoute(); }
    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override { test_INCOMPATIBLE_InvalidRoute(); }
    function test_row_previewMatchesExecution() public override { test_INCOMPATIBLE_InvalidRoute(); }
}
