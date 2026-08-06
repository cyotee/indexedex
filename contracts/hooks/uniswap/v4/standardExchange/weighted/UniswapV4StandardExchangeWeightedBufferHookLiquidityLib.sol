// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4StandardExchangeWeightedBufferHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol";

/// @dev External pure/view offload for LiquidityFacet EIP-170 headroom.
library UniswapV4StandardExchangeWeightedBufferHookLiquidityLib {
    error ZeroAmount();
    error Slippage();

    /// @dev Packed partial-join inputs (avoids stack-too-deep under legacy codegen).
    struct PartialJoinArgs {
        uint256[] weights;
        uint256[] invScales;
        uint256[] natives;
        uint256[] invIn;
        uint256[] pairAmounts;
        address[] ses;
        uint256 supply;
    }

    struct PartialJoinResult {
        uint256 shares;
        uint256[] usedPair;
    }

    /// @notice Partial join shares + used pair (packed args for legacy codegen stack).
    function partialJoin(PartialJoinArgs memory a)
        external
        pure
        returns (PartialJoinResult memory r)
    {
        uint256 n = a.weights.length;
        r.usedPair = new uint256[](n);

        (uint256 minShares, bool anyProp, bool anySeed) = _scanProportional(a, r.usedPair);
        if (anyProp) {
            if (minShares == 0 || minShares == type(uint256).max) revert ZeroAmount();
            _fillProportionalUsed(a, r.usedPair, minShares);
        }
        if (!anySeed && !anyProp) revert ZeroAmount();
        if (!anySeed) {
            r.shares = minShares;
            if (r.shares == 0) revert ZeroAmount();
            return r;
        }
        r.shares = _seedPathShares(a, r.usedPair);
    }

    /// @dev Seed zeros + proportional min-share scan; writes seed usedPair slots.
    function _scanProportional(PartialJoinArgs memory a, uint256[] memory usedPair)
        private
        pure
        returns (uint256 minShares, bool anyProp, bool anySeed)
    {
        minShares = type(uint256).max;
        uint256 n = a.weights.length;
        for (uint256 i; i < n; ++i) {
            if (a.natives[i] == 0 && a.invIn[i] > 0) {
                usedPair[i] = a.pairAmounts[i];
                anySeed = true;
            } else if (a.natives[i] > 0 && a.invIn[i] > 0) {
                uint256 s = _legShares(a, i);
                if (s < minShares) minShares = s;
                anyProp = true;
            }
        }
    }

    function _legShares(PartialJoinArgs memory a, uint256 i) private pure returns (uint256) {
        return (Math.scaleTo(a.invIn[i], a.invScales[i]) * a.supply)
            / Math.scaleTo(a.natives[i], a.invScales[i]);
    }

    function _fillProportionalUsed(
        PartialJoinArgs memory a,
        uint256[] memory usedPair,
        uint256 minShares
    ) private pure {
        uint256 n = a.weights.length;
        for (uint256 i; i < n; ++i) {
            if (a.natives[i] > 0 && a.invIn[i] > 0) {
                uint256 usedInv = Math.descale(
                    Math.proportionalUsedScaled(
                        minShares, Math.scaleTo(a.natives[i], a.invScales[i]), a.supply
                    ),
                    a.invScales[i]
                );
                if (usedInv == 0) revert ZeroAmount();
                usedPair[i] = (a.pairAmounts[i] * usedInv) / a.invIn[i];
            }
        }
    }

    function _seedPathShares(PartialJoinArgs memory a, uint256[] memory usedPair)
        private
        pure
        returns (uint256 shares)
    {
        uint256 n = a.weights.length;
        uint256[] memory before = new uint256[](n);
        uint256[] memory after_ = new uint256[](n);
        _fillBeforeAfter(a, usedPair, before, after_);

        uint256 kBefore = Math.computeInterimK(a.weights, before);
        uint256 kAfter = Math.computeInterimK(a.weights, after_);
        if (kAfter > kBefore) {
            return Math.partialJoinSharesFromK(a.supply, kBefore, kAfter);
        }
        return _navShares(a, usedPair, before);
    }

    function _fillBeforeAfter(
        PartialJoinArgs memory a,
        uint256[] memory usedPair,
        uint256[] memory before,
        uint256[] memory after_
    ) private pure {
        uint256 n = a.weights.length;
        for (uint256 i; i < n; ++i) {
            before[i] = Math.scaleTo(a.natives[i], a.invScales[i]);
            if (a.natives[i] == 0 && a.invIn[i] > 0) {
                after_[i] = Math.scaleTo(a.invIn[i], a.invScales[i]);
            } else if (usedPair[i] > 0) {
                uint256 usedInv = _usedInvAt(a, usedPair, i);
                after_[i] = before[i] + Math.scaleTo(usedInv, a.invScales[i]);
            } else {
                after_[i] = before[i];
            }
        }
    }

    function _usedInvAt(PartialJoinArgs memory a, uint256[] memory usedPair, uint256 i)
        private
        pure
        returns (uint256)
    {
        if (usedPair[i] == 0) return 0;
        if (a.ses[i] == address(0)) return usedPair[i];
        uint256 denom = a.pairAmounts[i] == 0 ? 1 : a.pairAmounts[i];
        return (a.invIn[i] * usedPair[i]) / denom;
    }

    function _navShares(
        PartialJoinArgs memory a,
        uint256[] memory usedPair,
        uint256[] memory before
    ) private pure returns (uint256 shares) {
        uint256 vIn;
        uint256 vBook;
        uint256 n = a.weights.length;
        for (uint256 i; i < n; ++i) {
            uint256 usedInv = _usedInvAt(a, usedPair, i);
            vBook += (before[i] * a.weights[i]) / Math.WAD;
            vIn += (Math.scaleTo(usedInv, a.invScales[i]) * a.weights[i]) / Math.WAD;
        }
        if (vBook == 0 || vIn == 0) revert ZeroAmount();
        shares = (a.supply * vIn) / vBook;
        if (shares == 0) revert ZeroAmount();
    }
}
