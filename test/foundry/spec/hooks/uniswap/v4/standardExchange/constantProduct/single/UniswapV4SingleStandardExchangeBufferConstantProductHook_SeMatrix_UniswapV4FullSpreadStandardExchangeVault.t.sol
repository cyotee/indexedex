// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV4Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/// @notice D20: constantProduct/single x UniswapV4FullSpreadStandardExchangeVault (COMPATIBLE). Face: 18-decimal pool currency0 (`SimpleMintableERC20`, ERC-20 variant) of a hermetic Uniswap V4 3000-fee pool on
///         the SE's own PoolManager, seeded by an independent LP; SE deployed through the production FullSpread V4
///         package (shared per test contract). Native-ETH variant out of scope.
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault is UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior {
    /// @dev Package deployed once per test contract; later fixtures (one per SE leg) reuse it.
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_FullSpreadV4Fixture f = new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }

    // H-only domain assertions replace historical two-leg EO success; generic rows are unchanged.
    function test_row_partialConsumption_bookedNotRefunded() public override {
        _seed(); SeMatrix_FullSpreadV4Fixture(address(fx)).assertBlockedAccounting(hook);
    }
    function test_row_ammCallerFundSeparation() public override {
        _seed(); SeMatrix_FullSpreadV4Fixture(address(fx)).assertBlockedAccounting(hook);
    }
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _seed(); SeMatrix_FullSpreadV4Fixture(address(fx)).assertExactOutRejected(hook, raw, face, true);
        SeMatrix_FullSpreadV4Fixture(address(fx)).assertExactOutRejected(hook, face, raw, true);
    }
    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _seed(); SeMatrix_FullSpreadV4Fixture(address(fx)).assertExactOutRejected(hook, raw, face, false);
        SeMatrix_FullSpreadV4Fixture(address(fx)).assertExactOutRejected(hook, face, raw, false);
    }
    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seed();
        uint256 faceBefore = IERC20(face).balanceOf(user);
        uint256 rawBefore = IERC20(raw).balanceOf(user);
        _swapExactIn(face, raw, _f(1));
        assertGt(IERC20(raw).balanceOf(user), rawBefore);
        faceBefore = IERC20(face).balanceOf(user);
        _swapExactIn(raw, face, 1 ether);
        assertGt(IERC20(face).balanceOf(user), faceBefore);
        SeMatrix_FullSpreadV4Fixture(address(fx)).assertRouterExactOutRejected(address(swapRouter), poolKey, raw, face);
        SeMatrix_FullSpreadV4Fixture(address(fx)).assertRouterExactOutRejected(address(swapRouter), poolKey, face, raw);
        assertLe(IERC20(face).balanceOf(hook), DUST);
    }
}
