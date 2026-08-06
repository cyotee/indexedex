// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4StandardExchangeWeightedBufferHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol";

/// @dev External pure/view offload for LiquidityFacet EIP-170 headroom.
library UniswapV4StandardExchangeWeightedBufferHookLiquidityLib {
    error ZeroAmount();
    error Slippage();

    function partialJoin(
        uint256[] memory weights,
        uint256[] memory invScales,
        uint256[] memory natives,
        uint256[] memory invIn,
        uint256[] memory pairAmounts,
        address[] memory ses,
        uint256 supply
    ) external pure returns (uint256 shares, uint256[] memory usedPair) {
        uint256 n = weights.length;
        usedPair = new uint256[](n);
        uint256 minShares = type(uint256).max;
        bool anyProp;
        bool anySeed;
        for (uint256 i; i < n; ++i) {
            if (natives[i] == 0 && invIn[i] > 0) {
                usedPair[i] = pairAmounts[i];
                anySeed = true;
            } else if (natives[i] > 0 && invIn[i] > 0) {
                uint256 s = (Math.scaleTo(invIn[i], invScales[i]) * supply)
                    / Math.scaleTo(natives[i], invScales[i]);
                if (s < minShares) minShares = s;
                anyProp = true;
            }
        }
        if (anyProp) {
            if (minShares == 0 || minShares == type(uint256).max) revert ZeroAmount();
            for (uint256 i; i < n; ++i) {
                if (natives[i] > 0 && invIn[i] > 0) {
                    uint256 usedInv = Math.descale(
                        Math.proportionalUsedScaled(
                            minShares, Math.scaleTo(natives[i], invScales[i]), supply
                        ),
                        invScales[i]
                    );
                    if (usedInv == 0) revert ZeroAmount();
                    usedPair[i] = (pairAmounts[i] * usedInv) / invIn[i];
                }
            }
        }
        if (!anySeed && !anyProp) revert ZeroAmount();
        if (!anySeed) {
            shares = minShares;
            if (shares == 0) revert ZeroAmount();
            return (shares, usedPair);
        }
        // seed path: interim k growth or NAV
        uint256[] memory before = new uint256[](n);
        uint256[] memory after_ = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            before[i] = Math.scaleTo(natives[i], invScales[i]);
            if (natives[i] == 0 && invIn[i] > 0) {
                after_[i] = Math.scaleTo(invIn[i], invScales[i]);
            } else if (usedPair[i] > 0) {
                uint256 usedInv = ses[i] == address(0)
                    ? usedPair[i]
                    : (invIn[i] * usedPair[i]) / (pairAmounts[i] == 0 ? 1 : pairAmounts[i]);
                after_[i] = before[i] + Math.scaleTo(usedInv, invScales[i]);
            } else {
                after_[i] = before[i];
            }
        }
        uint256 kBefore = Math.computeInterimK(weights, before);
        uint256 kAfter = Math.computeInterimK(weights, after_);
        if (kAfter > kBefore) {
            shares = Math.partialJoinSharesFromK(supply, kBefore, kAfter);
            return (shares, usedPair);
        }
        uint256 vIn;
        uint256 vBook;
        for (uint256 i; i < n; ++i) {
            uint256 usedInv = usedPair[i] == 0
                ? 0
                : (
                    ses[i] == address(0)
                        ? usedPair[i]
                        : (invIn[i] * usedPair[i]) / (pairAmounts[i] == 0 ? 1 : pairAmounts[i])
                );
            vBook += (before[i] * weights[i]) / Math.WAD;
            vIn += (Math.scaleTo(usedInv, invScales[i]) * weights[i]) / Math.WAD;
        }
        if (vBook == 0 || vIn == 0) revert ZeroAmount();
        shares = (supply * vIn) / vBook;
        if (shares == 0) revert ZeroAmount();
    }
}
