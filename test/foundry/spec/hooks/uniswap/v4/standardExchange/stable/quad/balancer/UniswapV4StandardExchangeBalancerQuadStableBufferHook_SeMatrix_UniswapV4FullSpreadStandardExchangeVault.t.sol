// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {SeMatrix_FullSpreadV4Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol";

/// @notice Real H row: forward EI payout supported; unsupported inverse domains reject atomically.
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault is UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior {
    /// @dev Package deployed once per test contract; later fixtures (one per SE leg) reuse it.
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_FullSpreadV4Fixture f = new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }
    function test_row_partialConsumption_bookedNotRefunded() public override {
        _seed(); SeMatrix_FullSpreadV4Fixture(address(fx)).assertBlockedAccounting(hook);
    }
    function test_row_ammCallerFundSeparation() public override {
        _seed();
        for (uint256 i; i < fxs.length; ++i) if (address(fxs[i]) != address(0))
            SeMatrix_FullSpreadV4Fixture(address(fxs[i])).assertBlockedAccounting(hook);
    }
    function test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed() public override {
        _seed(); SeMatrix_FullSpreadV4Fixture(address(fx)).assertExactOutRejected(hook, other, face, true);
        SeMatrix_FullSpreadV4Fixture(address(fxs[otherIdx])).assertExactOutRejected(hook, face, other, true);
    }
    function test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly() public override {
        _seed(); SeMatrix_FullSpreadV4Fixture(address(fx)).assertExactOutRejected(hook, other, face, false);
        SeMatrix_FullSpreadV4Fixture(address(fxs[otherIdx])).assertExactOutRejected(hook, face, other, false);
    }
    function test_row_poolManagerSwap_bothDirections_noFaceResidual() public override {
        _seed();
        SeMatrix_FullSpreadV4Fixture(address(fx)).assertRouterPairRoutes(address(swapRouter), hook, other, face, 1);
        SeMatrixFixture outFixture = address(fxs[otherIdx]) == address(0) ? fx : fxs[otherIdx];
        SeMatrix_FullSpreadV4Fixture(address(outFixture)).assertRouterPairRoutes(address(swapRouter), hook, face, other, 1);
    }

    function test_row_bufferFirst_restingFace_notPaidToJoiner() public override {
        _seed();
        address donor = makeAddr("donor");
        fx.fund(donor, _f(500));
        vm.prank(donor);
        IERC20(face).transfer(hook, _f(500));
        uint256 beforeFace = IERC20(face).balanceOf(user);
        uint256 beforeShares = _hookSeShares();
        uint256[] memory amounts = _amounts(_f(1), 1);
        vm.prank(user);
        uint256 minted = quad.joinUnbalanced(amounts, user, 0, block.timestamp + 1 hours);
        assertGt(minted, 0);
        assertEq(beforeFace - IERC20(face).balanceOf(user), amounts[faceIdx], "caller pays only its contribution");
        assertGt(_hookSeShares(), beforeShares, "resting face belongs to hook holders");
    }

    function test_row_seFailure_rollsBack() public override {
        _seed();
        fx.armOperativeRevert();
        uint256 beforeFace = IERC20(face).balanceOf(user);
        uint256 beforeOther = IERC20(other).balanceOf(user);
        uint256 beforeShares = _hookSeShares();
        uint256 beforeBook = fx.seBooked();
        uint256 beforeSupply = IERC20(hook).totalSupply();
        uint256[] memory amounts = _amounts(_f(10), 10);
        vm.prank(user);
        vm.expectRevert(rejectBytes);
        quad.joinUnbalanced(amounts, user, 0, block.timestamp + 1 hours);
        assertEq(IERC20(face).balanceOf(user), beforeFace);
        assertEq(IERC20(other).balanceOf(user), beforeOther);
        assertEq(_hookSeShares(), beforeShares);
        assertEq(fx.seBooked(), beforeBook);
        assertEq(IERC20(hook).totalSupply(), beforeSupply);
        fx.disarmOperativeRevert();
        vm.prank(user);
        assertGt(quad.joinUnbalanced(amounts, user, 0, block.timestamp + 1 hours), 0);
    }

    function test_row_previewMatchesExecution() public override {
        uint256 shares = _seed();
        uint256[] memory amounts = _amounts(_f(10), 10);
        uint256 quoted = quad.previewJoinUnbalanced(amounts);
        uint256 beforeFace = IERC20(face).balanceOf(user);
        uint256 beforeOther = IERC20(other).balanceOf(user);
        vm.prank(user);
        assertEq(quad.joinUnbalanced(amounts, user, quoted, block.timestamp + 1 hours), quoted);
        assertEq(beforeFace - IERC20(face).balanceOf(user), amounts[faceIdx]);
        assertEq(beforeOther - IERC20(other).balanceOf(user), amounts[otherIdx]);

        uint256 burn = shares / 10;
        uint256 quotedOut = quad.previewWithdrawSingle(face, burn);
        beforeFace = IERC20(face).balanceOf(user);
        vm.prank(user);
        assertEq(quad.withdrawSingle(face, burn, user, quotedOut, block.timestamp + 1 hours), quotedOut);
        assertEq(IERC20(face).balanceOf(user) - beforeFace, quotedOut);
        uint256 swapQuote = quad.previewSwapExactIn(face, other, _f(1));
        beforeOther = IERC20(other).balanceOf(user);
        _swapExactIn(face, other, _f(1));
        assertEq(IERC20(other).balanceOf(user) - beforeOther, swapQuote);
    }

    function test_proportionalJoinRequiresUnsupportedIdleExactShareInverse() public {
        _seed();
        uint256[] memory amounts = _amounts(_f(10), 10);
        bytes memory reason = abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, legTokens[0], legSes[0]);
        uint256 beforeFace = IERC20(face).balanceOf(user);
        uint256 beforeSupply = IERC20(hook).totalSupply();
        vm.expectRevert(reason);
        quad.previewJoinProportional(amounts);
        vm.prank(user);
        vm.expectRevert(reason);
        quad.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertEq(IERC20(face).balanceOf(user), beforeFace);
        assertEq(IERC20(hook).totalSupply(), beforeSupply);
    }
}
