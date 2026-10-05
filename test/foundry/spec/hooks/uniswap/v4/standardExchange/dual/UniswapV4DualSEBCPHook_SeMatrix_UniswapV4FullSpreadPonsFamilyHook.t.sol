// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SeMatrix_FullSpreadPonsV2Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadPonsV2Fixture.sol";
import {UniswapV4DualSEBCPHook_SeMatrixBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol";

/// @notice D20: dual x UniswapV4FullSpreadPonsFamilyHook (COMPATIBLE). Face: 18-decimal pool currency0 (`SimpleMintableERC20`, ERC-20 variant) of a hermetic Uniswap V4 3000-fee pool on
///         the SE's own PoolManager, seeded by an independent LP; SE deployed through the production FullSpread V4
///         package (shared per test contract). Native-ETH variant out of scope.
contract UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadPonsFamilyHook is UniswapV4DualSEBCPHook_SeMatrixBehavior {
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
        _seed(); SeMatrix_FullSpreadPonsV2Fixture(address(fx)).assertBlockedAccounting(hook);
        SeMatrix_FullSpreadPonsV2Fixture(address(fx1)).assertBlockedAccounting(hook);
    }
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _seed(); SeMatrix_FullSpreadPonsV2Fixture(address(fx)).assertExactOutRejected(hook, other, face, true);
        SeMatrix_FullSpreadPonsV2Fixture(address(fx1)).assertExactOutRejected(hook, face, other, true);
    }
    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _seed(); SeMatrix_FullSpreadPonsV2Fixture(address(fx)).assertExactOutRejected(hook, other, face, false);
        SeMatrix_FullSpreadPonsV2Fixture(address(fx1)).assertExactOutRejected(hook, face, other, false);
    }
    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seed();
        uint256 restingFace = IERC20(face).balanceOf(hook);
        uint256 restingOther = IERC20(other).balanceOf(hook);
        uint256 beforeOut = IERC20(other).balanceOf(user);
        _swapExactIn(face, _f(1));
        assertGt(IERC20(other).balanceOf(user), beforeOut);
        beforeOut = IERC20(face).balanceOf(user);
        _swapExactIn(other, _o(1));
        assertGt(IERC20(face).balanceOf(user), beforeOut);
        SeMatrix_FullSpreadPonsV2Fixture(address(fx)).assertRouterExactOutRejected(address(swapRouter), poolKey, other, face);
        SeMatrix_FullSpreadPonsV2Fixture(address(fx1)).assertRouterExactOutRejected(address(swapRouter), poolKey, face, other);
        assertApproxEqAbs(IERC20(face).balanceOf(hook), restingFace, _residualTolerance());
        assertApproxEqAbs(IERC20(other).balanceOf(hook), restingOther, _residualTolerance());
    }
}
