// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {UniswapV4SeBufferHookContextQuoteLib as ContextQuote} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib as CurveClaim} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib as BalancerClaim} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_CamelotV2StandardExchange as CamelotRow} from "./constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_CamelotV2StandardExchange.t.sol";

/// @notice Actual Camelot SE capability and forward-quote controls for legacy input inversion.
contract FullSpreadLegacyInverseCompatibilityTest is CamelotRow {
    function test_legacyInverse_absentContextKeepsQuadForwardVerifiedSearch() public {
        _seed();
        assertFalse(ContextQuote.supported(seUT));
        assertEq(ContextQuote.exactOutputState(seUT, face, address(pm)), bytes(""));
        uint256 wanted = IStandardExchangeIn(seUT).previewExchangeIn(IERC20(face), 1e12, IERC20(seUT));
        assertGt(wanted, 0);
        assertEq(IStandardExchangeOut(seUT).previewExchangeOut(IERC20(face), IERC20(seUT), wanted), 0,
            "legacy Camelot has no asset-to-exact-shares quote");
        uint256 curveInput = CurveClaim.invertBufferExactSharesOut(seUT, face, wanted);
        uint256 balancerInput = BalancerClaim.invertBufferExactSharesOut(seUT, face, wanted);
        assertGt(curveInput, 0);
        assertEq(curveInput, balancerInput, "same preserved baseline algorithm");
        assertGe(IStandardExchangeIn(seUT).previewExchangeIn(IERC20(face), curveInput, IERC20(seUT)), wanted);
        assertLt(IStandardExchangeIn(seUT).previewExchangeIn(IERC20(face), curveInput - 1, IERC20(seUT)), wanted,
            "forward-verified minimal sufficient input");
    }

    function test_legacyInverse_cpComposedExactOutputNeedsNoSeInversePrerequisite() public {
        _seed();
        assertFalse(ContextQuote.supported(seUT));
        uint256 wanted = 1e12;
        uint256 quote = IStandardExchangeOut(hook).previewExchangeOut(IERC20(face), IERC20(raw), wanted);
        assertGt(quote, 0);
        uint256 beforeInput = IERC20(face).balanceOf(user);
        uint256 beforeOutput = IERC20(raw).balanceOf(user);
        vm.prank(user);
        uint256 spent = IStandardExchangeOut(hook).exchangeOut(IERC20(face), quote, IERC20(raw), wanted, user, false, block.timestamp);
        assertEq(spent, quote);
        assertEq(IERC20(face).balanceOf(user), beforeInput - quote);
        assertEq(IERC20(raw).balanceOf(user), beforeOutput + wanted);
        assertEq(IERC20(face).allowance(hook, seUT), 0);
    }
}
