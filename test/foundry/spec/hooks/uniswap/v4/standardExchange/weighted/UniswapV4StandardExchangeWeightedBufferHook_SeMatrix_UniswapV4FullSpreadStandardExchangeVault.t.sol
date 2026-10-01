// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve as LiquidReserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/interfaces/IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.sol";
import {SeMatrix_FullSpreadV4Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol";
import {UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol";

/// @notice D20: weighted x UniswapV4FullSpreadStandardExchangeVault (COMPATIBLE). Face: 18-decimal pool currency0 (`SimpleMintableERC20`, ERC-20 variant) of a hermetic Uniswap V4 3000-fee pool on
///         the SE's own PoolManager, seeded by an independent LP; SE deployed through the production FullSpread V4
///         package (shared per test contract). Native-ETH variant out of scope.
contract UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault is UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior {
    /// @dev Package deployed once per test contract; later fixtures (one per SE leg) reuse it.
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_FullSpreadV4Fixture f = new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }

    function test_row_partialConsumption_bookedNotRefunded() public override {
        _seed();
        SeMatrix_FullSpreadV4Fixture(address(fx)).assertBlockedAccounting(hook);
    }
    function test_row_ammCallerFundSeparation() public override {
        _seed();
        SeMatrix_FullSpreadV4Fixture(address(fx)).assertBlockedAccounting(hook);
    }
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _seed();
        SeMatrix_FullSpreadV4Fixture(address(fx)).assertExactOutRejected(hook, other, face, true);
        SeMatrix_FullSpreadV4Fixture(address(fx)).assertExactOutRejected(hook, face, other, true);
    }
    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _seed();
        SeMatrix_FullSpreadV4Fixture(address(fx)).assertExactOutRejected(hook, other, face, false);
        SeMatrix_FullSpreadV4Fixture(address(fx)).assertExactOutRejected(hook, face, other, false);
    }
    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seed();
        SeMatrix_FullSpreadV4Fixture(address(fx)).assertRouterPairRoutes(address(swapRouter), hook, other, face, 1);
        SeMatrix_FullSpreadV4Fixture(address(fx)).assertRouterPairRoutes(address(swapRouter), hook, face, other, 1);
    }

    function test_consumer_halfBookSleeveIsActuallyFunded() public view {
        LiquidReserve reserve = LiquidReserve(seUT);
        (uint256 deployed0, uint256 deployed1) = reserve.deployedReserve();
        assertEq(reserve.targetLiquidReservePercentage(), 1e18);
        assertGt(deployed0, 0);
        assertGt(deployed1, 0);
        assertGt(reserve.localReserve(face), 0);
        assertGt(reserve.localReserve(fx.otherToken()), 0);
    }

    function test_consumer_exactInputUsesShareBudgetNotTwoLegInverse() public {
        _seed();
        uint256 amountIn = 1e12;
        uint256 quoted = IStandardExchangeIn(hook).previewExchangeIn(IERC20(other), amountIn, IERC20(face));
        assertGt(quoted, 0);
        uint256 snapshot = vm.snapshotState();
        uint256 sharesBefore = IERC20(seUT).balanceOf(hook);
        uint256 supplyBefore = IERC20(seUT).totalSupply();
        uint256 faceBefore = IERC20(face).balanceOf(user);
        vm.prank(user);
        uint256 paid = IStandardExchangeIn(hook).exchangeIn(IERC20(other), amountIn, IERC20(face), quoted, user, false, block.timestamp);
        uint256 sharesSpent = sharesBefore - IERC20(seUT).balanceOf(hook);
        assertGt(sharesSpent, 0);
        assertLt(sharesSpent, sharesBefore, "output reserve remains positive");
        assertEq(supplyBefore - IERC20(seUT).totalSupply(), sharesSpent, "actual share burn");
        assertEq(paid, quoted);
        assertEq(IERC20(face).balanceOf(user), faceBefore + paid);
        assertTrue(vm.revertToState(snapshot));
        assertEq(IStandardExchangeIn(seUT).previewExchangeIn(IERC20(seUT), sharesSpent, IERC20(face)), quoted,
            "same-state share redemption is the outer payout");
    }

    function test_consumer_unsupportedExactOutputRejectsBeforeFundingBothDirections() public {
        _seed();
        _assertUnsupportedEo(other, face, seUT, face);
        _assertUnsupportedEo(face, other, face, seUT);
    }

    function _assertUnsupportedEo(address input, address output, address seInput, address seOutput) private {
        bytes memory reason = abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, seInput, seOutput);
        uint256 sharesBefore = IERC20(seUT).balanceOf(hook);
        uint256 supplyBefore = IERC20(seUT).totalSupply();
        vm.expectRevert(reason);
        IStandardExchangeOut(hook).previewExchangeOut(IERC20(input), IERC20(output), 1e12);
        // Unfunded caller with no allowance: the domain error must precede the funding attempt.
        vm.prank(rowBob);
        vm.expectRevert(reason);
        IStandardExchangeOut(hook).exchangeOut(IERC20(input), type(uint256).max, IERC20(output), 1e12, rowBob, false, block.timestamp);
        assertEq(IERC20(seUT).balanceOf(hook), sharesBefore);
        assertEq(IERC20(seUT).totalSupply(), supplyBefore);
        assertEq(IERC20(input).allowance(rowBob, hook), 0);
    }
}
