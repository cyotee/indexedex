// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;


import {
    ResearchFixture_UniswapV2SeRateMatrix
} from "scripts/foundry/research/uniswapV2Se/ResearchFixture_UniswapV2SeRateMatrix.sol";
import {
    ResearchModeCCloser
} from "scripts/foundry/research/uniswapV2Se/ResearchModeCCloser.sol";

/**
 * @title ResearchFixture_ModeC
 * @notice Mode C research environment: Mode A Uni demand + Balancer arb closing.
 * @dev Separate contract from Mode A so arb wiring never bloats Mode A compile surface.
 *      Arb body lives in standalone ResearchModeCCloser (structs + small helpers).
 *
 * Flow per step:
 *   1) Market demand on Uni (parent.swapUniExactIn)
 *   2) closeBalancerArbs — closer buys shares on each matrix pool if edge in profit asset
 *   3) sample telemetry (parent)
 */
contract ResearchFixture_ModeC is ResearchFixture_UniswapV2SeRateMatrix {
    ResearchModeCCloser public closer;
    address public arbAgent;

    /// @notice Bootstrap Mode A env, then deploy/configure standalone arb closer.
    function bootstrapModeC() external {
        bootstrapResearch();
        researchModeId = 1; // C_uni_plus_bal_arb
        arbAgent = makeAddr("modeCArbAgent");
        closer = new ResearchModeCCloser();

        // Profit asset = token market sells into Uni (traded asset).
        // Set after initTelemetry when tradedIsWeth is known — configureCloser() called then.
    }

    /**
     * @notice Call after initTelemetry so tradedIsWeth is set.
     * @dev Profit token: market buys USDC (tradedIsWeth) → arb for WETH; else USDC.
     */
    function configureCloser() external {
        require(telemetryReady, "modeC: telemetry first");
        require(address(closer) != address(0), "modeC: bootstrapModeC first");

        address profitTok = tradedIsWeth ? address(tokenWeth) : address(tokenUsdc);

        ResearchModeCCloser.Env memory e = ResearchModeCCloser.Env({
            agent: arbAgent,
            balRouter: address(router),
            uniRouter: address(uniV2Router),
            seVault: address(seVault),
            shares: address(shares),
            uniPair: address(uniV2Pair),
            weth: address(tokenWeth),
            usdc: address(tokenUsdc),
            bv3Vault: address(bv3Vault),
            permit2: address(permit2),
            profitToken: profitTok
        });
        closer.configure(e);
    }

    /// @notice Real Mode C arb — delegates to standalone closer (not Mode A stub).
    function closeBalancerArbs() public override returns (uint256 profit_, uint256 fills_) {
        require(telemetryReady, "modeC: telemetry");
        require(address(closer) != address(0), "modeC: no closer");

        address[] memory pools = new address[](MATRIX_N);
        address[] memory pairs = new address[](MATRIX_N);
        for (uint256 i = 0; i < MATRIX_N; ++i) {
            pools[i] = matrixPools[i];
            pairs[i] = address(matrixPairToken[i]);
        }

        ResearchModeCCloser.StepResult memory r = closer.closeAll(pools, pairs);
        stepArbProfit = r.profit;
        stepArbFills = r.fills;
        stepMaxBuyProbe = r.maxBuyProbe;
        stepMaxSellProbe = r.maxSellProbe;
        stepPositiveProbes = r.positiveProbes;
        cumulativeArbProfit += r.profit;
        profit_ = r.profit;
        fills_ = r.fills;
    }
}
