// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_AerodromeFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_AerodromeFixture.sol";
import {
    UniswapV4SingleSEBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol";

/// @notice D20: non-CP single × AerodromeStandardExchange. Face: 18-decimal pair token A of a seeded volatile Aerodrome V1 pool; SE shares 18 decimals.
contract UniswapV4SingleSEBufferHook_SeMatrix_AerodromeStandardExchange is UniswapV4SingleSEBufferHook_SeMatrixBehavior {
    /// @dev The first fixture deploys the protocol and the SE package; later SE legs reuse both through it.
    address internal sharedFixture;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_AerodromeFixture f = new SeMatrix_AerodromeFixture(_ctx(), sharedFixture);
        sharedFixture = address(f);
        return f;
    }


    /// @dev F5 fixed 2026-09-21: `_unwrapExactOut` settles exactly `pairOut`; an AMM zap-out that delivers
    ///      more keeps the surplus on the hook as retained residual (D6) instead of an unclaimed PoolManager
    ///      credit. Red record: run 5 asserted `CurrencyNotSettled()` on this sequence (`hook-se-matrix-run-5.log`).
    ///      The gold body's final `_assertHookFlatDelta` is replaced by a bounded-residual check because the
    ///      Aerodrome exact-out zap-out legitimately over-delivers by rounding.
    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        uint256 restingFace = _faceOf(hook);
        uint256 restingSe = _seOf(hook);
        uint256 userFace = _faceOf(user);
        uint256 userSe = _seOf(user);

        uint256 seOut = _wrapExactIn(_f(1));
        assertEq(_seOf(user) - userSe, seOut, "exact-in wrap paid");
        userSe = _seOf(user);
        userFace = _faceOf(user);

        uint256 faceOut = _unwrapExactIn(seOut / 2);
        assertEq(_faceOf(user) - userFace, faceOut, "exact-in unwrap paid");
        userFace = _faceOf(user);
        userSe = _seOf(user);

        uint256 wantSe = buffer.previewWrap(_f(1)) / 2;
        _wrapExactOut(wantSe);
        assertEq(_seOf(user) - userSe, wantSe, "exact-out wrap delivers the request");
        userSe = _seOf(user);
        userFace = _faceOf(user);

        _unwrapExactOut(_f(1) / 2);
        assertEq(_faceOf(user) - userFace, _f(1) / 2, "exact-out unwrap delivers the request");

        assertEq(_seOf(hook), restingSe, "hook SE delta residual");
        assertGe(_faceOf(hook), restingFace, "retained residual is never paid out");
        uint256 residual = _faceOf(hook) - restingFace;
        assertLe(residual, _f(1) / 200, "F5: retained face residual from AMM exact-out over-delivery stays below 1% of the unwrap");
        emit log_named_uint("F5 retained face residual (wei) after exact-out unwrap", residual);
    }
}
