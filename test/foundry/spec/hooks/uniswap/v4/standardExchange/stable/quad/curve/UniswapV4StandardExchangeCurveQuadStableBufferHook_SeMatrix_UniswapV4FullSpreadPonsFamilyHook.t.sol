// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_FullSpreadPonsV2Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadPonsV2Fixture.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol";

/// @notice Real H row: forward EI payout supported; unsupported inverse domains reject atomically.
contract UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadPonsFamilyHook is UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior {
    /// @dev Package deployed once per test contract; later fixtures (one per SE leg) reuse it.
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_FullSpreadPonsV2Fixture f = new SeMatrix_FullSpreadPonsV2Fixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }
    function test_row_partialConsumption_bookedNotRefunded() public override {
        _seed(); SeMatrix_FullSpreadPonsV2Fixture(address(fx)).assertBlockedAccounting(hook);
    }
    function test_row_ammCallerFundSeparation() public override {
        _seed();
        for (uint256 i; i < 4; ++i) SeMatrix_FullSpreadPonsV2Fixture(address(fxs[i])).assertBlockedAccounting(hook);
    }
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _seed(); SeMatrix_FullSpreadPonsV2Fixture(address(fx)).assertExactOutRejected(hook, other, face, true);
        SeMatrix_FullSpreadPonsV2Fixture(address(fxs[otherIdx])).assertExactOutRejected(hook, face, other, true);
    }
    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _seed(); SeMatrix_FullSpreadPonsV2Fixture(address(fx)).assertExactOutRejected(hook, other, face, false);
        SeMatrix_FullSpreadPonsV2Fixture(address(fxs[otherIdx])).assertExactOutRejected(hook, face, other, false);
    }
    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seed();
        SeMatrix_FullSpreadPonsV2Fixture(address(fx)).assertRouterPairRoutes(address(swapRouter), hook, other, face, 1);
        SeMatrix_FullSpreadPonsV2Fixture(address(fxs[otherIdx])).assertRouterPairRoutes(address(swapRouter), hook, face, other, 1);
    }
}
