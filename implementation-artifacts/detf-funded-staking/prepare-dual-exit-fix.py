"""Prepare the existing Dual single-output route correction after its regression run exits."""
from pathlib import Path
import hashlib
import json
import difflib

root = Path(__file__).resolve().parents[2]
artifacts = Path(__file__).resolve().parent
record = artifacts / 'dual-single-output-correction.json'
assert not record.exists(), 'Already applied; preserve provenance.'
directory = Path('contracts/hooks/uniswap/v4/standardExchange/dual')
staged = {}

common_path = directory / 'UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol'
common = (root / common_path).read_text()
start = common.index('    function _withdraw(\n')
end = common.index('    function _depositFlexibleSe(', start)
withdraw = common[start:end]
anchor = '    ) internal returns (uint256 amount0, uint256 amount1) {'
assert withdraw.count(anchor) == 1
withdraw = withdraw.replace(anchor, anchor + '''
        return _withdrawAndSettle(lpAmount, to, minAmount0, minAmount1, deadline, true);
    }

    /// @dev A composed exit retains its own raw withdrawals until the final asset is paid.
    function _withdrawAndSettle(
        uint256 lpAmount,
        address to,
        uint256 minAmount0,
        uint256 minAmount1,
        uint256 deadline,
        bool refundDust
    ) internal returns (uint256 amount0, uint256 amount1) {''', 1)
withdraw = withdraw.replace('_refundBothPairDust(msg.sender);', 'if (refundDust) _refundBothPairDust(msg.sender);')
staged[common_path] = common[:start] + withdraw + common[end:]

claim_path = directory / 'UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib.sol'
staged[claim_path] = '''// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib as BufferClaim}
    from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol";

/// @notice Dual and Single CP use the same sequential buffer claim and fee-dilution model.
library UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib {
    function supportsTransitionQuote(address se, address pairToken, address holder) external view returns (bool) {
        return BufferClaim.supportsTransitionQuote(se, pairToken, holder);
    }

    function previewBufferClaimIn(address se, address pairToken, uint256 amountInRaw,
        IVaultFeeOracleQuery feeOracle, address hook) external view returns (uint256)
    {
        return BufferClaim.previewBufferClaimIn(se, pairToken, amountInRaw, feeOracle, hook);
    }

    function invertBufferClaimIn(address se, address pairToken, uint256 claimInNeeded,
        IVaultFeeOracleQuery feeOracle, address hook) external view returns (uint256)
    {
        return BufferClaim.invertBufferClaimIn(se, pairToken, claimInNeeded, feeOracle, hook);
    }
}
'''

withdraw_path = directory / 'UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawTarget.sol'
source = (root / withdraw_path).read_text()
source = source.replace('import {IERC20} from', '''import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {IERC20} from''', 1)
start = source.index('    function _exitSingleAsset(')
replacement = '''    function _exitSingleAsset(address tokenOut, uint256 sharesIn, address to, uint256 deadline)
        internal returns (uint256 amountOut)
    {
        if (to == address(0)) revert ZeroAddress();
        UniswapV4SeBufferHookLegLib.LegKind kind = _classify(tokenOut);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) revert InvalidRoute();
        Repo.Layout storage l = Repo._layout();
        bool asShare = kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange;
        address pair = asShare ? l.legs.pairOfStandardExchange[tokenOut] : tokenOut;
        bool outIs0 = pair == l.currency0;
        if (!outIs0 && pair != l.currency1) revert InvalidRoute();

        uint256 beforeOut = IERC20(pair).balanceOf(address(this));
        (uint256 a0, uint256 a1) = _withdrawAndSettle(sharesIn, address(this), 0, 0, deadline, false);
        uint256 residual = outIs0 ? a1 : a0;
        if (residual > 0) {
            uint256 extra = _previewSwapExactIn(!outIs0, residual);
            if (extra > 0) _executeBookSwap(!outIs0, residual, extra, address(this));
            else IERC20(outIs0 ? l.currency1 : l.currency0).safeTransfer(msg.sender, residual);
        }
        // Exact-output SE unwrapping may deliver rounding surplus. All this-call output
        // belongs to this exit; preexisting raw inventory remains outside its payout.
        amountOut = IERC20(pair).balanceOf(address(this)) - beforeOut;
        if (asShare && amountOut > 0) amountOut = _buffer(tokenOut, pair, amountOut);
        IERC20(tokenOut).safeTransfer(to, amountOut);
        _syncReserves();
    }

    struct ExitQuoteLeg {
        address se;
        bytes state;
        uint256 assets;
        uint256 withdrawn;
    }

    function _previewExitSingleAsset(address tokenOut, uint256 sharesIn)
        internal view returns (uint256 amountOut)
    {
        UniswapV4SeBufferHookLegLib.LegKind kind = _classify(tokenOut);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) return 0;
        Repo.Layout storage l = Repo._layout();
        bool asShare = kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange;
        address pair = asShare ? l.legs.pairOfStandardExchange[tokenOut] : tokenOut;
        bool outIs0 = pair == l.currency0;
        if (!outIs0 && pair != l.currency1) return 0;
        address other = outIs0 ? l.currency1 : l.currency0;
        if (ClaimLib.supportsTransitionQuote(_seFor(pair), pair, address(this))
            && ClaimLib.supportsTransitionQuote(_seFor(other), other, address(this))) {
            return _previewSequentialExit(pair, other, sharesIn, asShare);
        }
        // Retain the existing non-transition peer model, using the remaining share book
        // rather than the pre-withdrawal reserve for the residual trade.
        (uint256 a0, uint256 a1) = _previewWithdraw(sharesIn);
        uint256 remainingIn = _remainingClaim(other, sharesIn);
        uint256 remainingOut = _remainingClaim(pair, sharesIn);
        uint256 residual = outIs0 ? a1 : a0;
        uint256 claimIn = residual == 0 ? 0 : _previewBufferClaimIn(_seFor(other), other, residual);
        amountOut = (outIs0 ? a0 : a1) + _exitSaleQuote(other, pair, claimIn, remainingIn, remainingOut);
        if (asShare && amountOut > 0) {
            amountOut = IStandardExchangeIn(tokenOut).previewExchangeIn(IERC20(pair), amountOut, IERC20(tokenOut));
        }
    }

    function _remainingClaim(address pair, uint256 lpAmount) private view returns (uint256) {
        address se = _seFor(pair);
        uint256 held = IERC20(se).balanceOf(address(this));
        uint256 removed = FullMath.mulDiv(held, lpAmount, _supplyAfterProtocolMint());
        return _claimOfSe(se, pair, held - removed);
    }

    function _previewSequentialExit(address pair, address other, uint256 sharesIn, bool asShare)
        private view returns (uint256 amountOut)
    {
        uint256 supply = _supplyAfterProtocolMint();
        ExitQuoteLeg memory output = _previewWithdrawLeg(pair, sharesIn, supply);
        ExitQuoteLeg memory input = _previewWithdrawLeg(other, sharesIn, supply);
        amountOut = output.withdrawn;
        if (input.withdrawn > 0) {
            uint256 assetsAfter;
            (,,, assetsAfter) = Transition(input.se).quoteTransition(
                input.state, Transition.Operation.DepositExactIn, input.withdrawn
            );
            uint256 addedClaim = assetsAfter > input.assets ? assetsAfter - input.assets : 0;
            uint256 extra = _exitSaleQuote(other, pair, addedClaim, input.assets, output.assets);
            if (extra > 0) {
                uint256 received;
                (output.state,, received, output.assets) = Transition(output.se).quoteTransition(
                    output.state, Transition.Operation.WithdrawExactOut, extra
                );
                amountOut += received;
            }
        }
        if (asShare && amountOut > 0) {
            (,, amountOut,) = Transition(output.se).quoteTransition(
                output.state, Transition.Operation.DepositExactIn, amountOut
            );
        }
    }

    function _previewWithdrawLeg(address pair, uint256 sharesIn, uint256 supply)
        private view returns (ExitQuoteLeg memory leg)
    {
        leg.se = _seFor(pair);
        (leg.state, leg.assets) = Transition(leg.se).quoteState(pair, address(this));
        uint256 seOut = FullMath.mulDiv(IERC20(leg.se).balanceOf(address(this)), sharesIn, supply);
        if (seOut > 0) {
            (leg.state,, leg.withdrawn, leg.assets) = Transition(leg.se).quoteTransition(
                leg.state, Transition.Operation.RedeemExactIn, seOut
            );
        }
    }

    function _exitSaleQuote(address tokenIn, address tokenOut, uint256 claimIn, uint256 reserveIn, uint256 reserveOut)
        private view returns (uint256)
    {
        if (claimIn == 0 || reserveIn == 0 || reserveOut == 0) return 0;
        uint8 decimalsIn = _decimalsOf(tokenIn);
        uint8 decimalsOut = _decimalsOf(tokenOut);
        return Math.fromWadFloor(Math.saleQuote(
            Math.toWad(claimIn, decimalsIn), Math.toWad(reserveIn, decimalsIn), Math.toWad(reserveOut, decimalsOut)
        ), decimalsOut);
    }

}
'''
staged[withdraw_path] = source[:start] + replacement

rows = []
for path, after in staged.items():
    before = (root / path).read_text()
    assert before != after
    rows.append({'path': str(path), 'before_sha256': hashlib.sha256(before.encode()).hexdigest(),
                 'after_sha256': hashlib.sha256(after.encode()).hexdigest(),
                 'diff': ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile=str(path), tofile=str(path)))})
for path, after in staged.items():
    (root / path).write_text(after)
record.write_text(json.dumps({'status': 'applied; existing-route regressions and peer coverage pending', 'rows': rows,
    'preserved': 'Host/underlying fee formulas, protocol LP fee ordering, H2 proportional previewBurnToToken, ordinary withdrawal dust policy and share custody.',
    'changed': 'Composed exits retain this-call output until payout, isolate unrelated inventory, deliver selected SE shares, and use sequential quotes where the actual peers provide them.',
    'limitations': 'No native SY integration yet. Non-transition peer quote approximation and direct incoming-SE-share quote transitions require additional validation.'}, indent=2) + '\n')
print('Corrected Dual composed exit accounting and supported sequential previews; validation pending.')
