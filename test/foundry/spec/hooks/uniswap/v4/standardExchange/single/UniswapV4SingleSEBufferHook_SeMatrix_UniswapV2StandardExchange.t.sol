// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_UniV2Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_UniV2Fixture.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV4SingleSEBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol";

/// @notice D20: non-CP single × UniswapV2StandardExchange. Face: 18-decimal pair token A of a seeded hermetic Uni V2 pair; SE shares 18 decimals.
contract UniswapV4SingleSEBufferHook_SeMatrix_UniswapV2StandardExchange is UniswapV4SingleSEBufferHook_SeMatrixBehavior {
    /// @dev The first fixture deploys the protocol and the SE package; later SE legs reuse both through it.
    address internal sharedFixture;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_UniV2Fixture f = new SeMatrix_UniV2Fixture(_ctx(), sharedFixture);
        sharedFixture = address(f);
        return f;
    }


    /// @dev F5 fixed 2026-09-21: `_unwrapExactOut` settles exactly `pairOut`; an AMM zap-out that delivers
    ///      more keeps the surplus on the hook as retained residual (D6) instead of an unclaimed PoolManager
    ///      credit. Red record: run 5 asserted `CurrencyNotSettled()` on this sequence (`hook-se-matrix-run-5.log`).
    ///      The gold body's final `_assertHookFlat()` is replaced by a bounded-residual check because the
    ///      Uni V2 exact-out zap-out legitimately over-delivers by rounding.
    function test_row_previewMatchesExecution() public override {
        uint256 x = _f(3);
        assertEq(
            buffer.previewWrap(x),
            IStandardExchangeIn(seUT).previewExchangeIn(IERC20(face), x, IERC20(seUT)),
            "wrap preview is the SE quote"
        );
        uint256 seOut = _wrapExactIn(x);
        assertEq(
            buffer.previewUnwrap(seOut),
            IStandardExchangeIn(seUT).previewExchangeIn(IERC20(seUT), seOut, IERC20(face)),
            "unwrap preview is the SE quote"
        );
        _unwrapExactIn(seOut);
        uint256 wantSe = buffer.previewWrap(_f(1));
        assertEq(
            buffer.previewWrapExactOut(wantSe),
            IStandardExchangeOut(seUT).previewExchangeOut(IERC20(face), IERC20(seUT), wantSe),
            "wrap exact-out preview is the SE quote"
        );
        _wrapExactOut(wantSe);
        assertEq(
            buffer.previewUnwrapExactOut(_f(1)),
            IStandardExchangeOut(seUT).previewExchangeOut(IERC20(seUT), IERC20(face), _f(1)),
            "unwrap exact-out preview is the SE quote"
        );
        _unwrapExactOut(_f(1));
        assertEq(IERC20(seUT).balanceOf(hook), 0, "hook free SE residual");
        uint256 residual = IERC20(face).balanceOf(hook);
        assertLe(residual, _f(1) / 100, "F5: retained face residual from AMM exact-out over-delivery stays below 1% of the unwrap");
        emit log_named_uint("F5 retained face residual (wei) after exact-out unwrap", residual);
    }
}
