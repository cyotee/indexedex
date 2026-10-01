// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV4Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol";
import {UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol";

/// @notice D20: orbital x UniswapV4FullSpreadStandardExchangeVault (COMPATIBLE). Face: 18-decimal pool currency0 (`SimpleMintableERC20`, ERC-20 variant) of a hermetic Uniswap V4 3000-fee pool on
///         the SE's own PoolManager, seeded by an independent LP; SE deployed through the production FullSpread V4
///         package (shared per test contract). Native-ETH variant out of scope.
contract UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault is UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior {
    /// @dev Package deployed once per test contract; later fixtures (one per SE leg) reuse it.
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_FullSpreadV4Fixture f = new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }

    function test_row_partialConsumption_bookedNotRefunded() public override {
        _seed(); SeMatrix_FullSpreadV4Fixture(address(fx0)).assertBlockedAccounting(hook);
    }
    function test_row_ammCallerFundSeparation() public override {
        _seed();
        SeMatrix_FullSpreadV4Fixture(address(fx0)).assertBlockedAccounting(hook);
        SeMatrix_FullSpreadV4Fixture(address(fx1)).assertBlockedAccounting(hook);
        SeMatrix_FullSpreadV4Fixture(address(fx2)).assertBlockedAccounting(hook);
    }
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _seed(); SeMatrix_FullSpreadV4Fixture(address(fx0)).assertExactOutRejected(hook, face1, face0, true);
        SeMatrix_FullSpreadV4Fixture(address(fx1)).assertExactOutRejected(hook, face0, face1, true);
    }
    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _seed(); SeMatrix_FullSpreadV4Fixture(address(fx0)).assertExactOutRejected(hook, face1, face0, false);
        SeMatrix_FullSpreadV4Fixture(address(fx1)).assertExactOutRejected(hook, face0, face1, false);
    }
    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seed();
        SeMatrix_FullSpreadV4Fixture(address(fx0)).assertRouterPairRoutes(address(swapRouter), hook, face1, face0, 60);
        SeMatrix_FullSpreadV4Fixture(address(fx1)).assertRouterPairRoutes(address(swapRouter), hook, face0, face1, 60);
    }
}
