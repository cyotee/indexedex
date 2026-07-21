// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    ResearchFixture_RateProviderCompare
} from "scripts/foundry/research/uniswapV2Se/rateProviderCompare/ResearchFixture_RateProviderCompare.sol";
import {
    ResearchModeCCloser
} from "scripts/foundry/research/uniswapV2Se/ResearchModeCCloser.sol";

/**
 * @title ResearchFixture_RateProviderCompare_ModeC
 * @notice Pure-state (R+ or R−) Mode C: Uni demand + Balancer arb closer.
 * @dev Homogeneous rate policy from parent constructor. Mirrors ResearchFixture_ModeC wiring.
 */
contract ResearchFixture_RateProviderCompare_ModeC is ResearchFixture_RateProviderCompare {
    ResearchModeCCloser public closer;
    address public arbAgent;

    constructor(bool ratesOn_, uint256 tradeSizeMul_, uint256 tradeSteps_)
        ResearchFixture_RateProviderCompare(ratesOn_, tradeSizeMul_, tradeSteps_)
    {}

    function bootstrapModeC() external {
        bootstrapResearch();
        researchModeId = 1; // C_uni_plus_bal_arb
        arbAgent = makeAddr("rpcModeCArbAgent");
        closer = new ResearchModeCCloser();
    }

    function configureCloser() external {
        require(telemetryReady, "rpcModeC: telemetry first");
        require(address(closer) != address(0), "rpcModeC: bootstrapModeC first");

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

    function closeBalancerArbs() public override returns (uint256 profit_, uint256 fills_) {
        require(telemetryReady, "rpcModeC: telemetry");
        require(address(closer) != address(0), "rpcModeC: no closer");

        // R− maps 4 logical lenses onto 2 physical pools — pass unique pools only so
        // the closer does not double-probe / double-fill the same address.
        uint256 n = ratesOn ? MATRIX_N : 2;
        address[] memory pools = new address[](n);
        address[] memory pairs = new address[](n);
        if (ratesOn) {
            for (uint256 i = 0; i < MATRIX_N; ++i) {
                pools[i] = matrixPools[i];
                pairs[i] = address(matrixPairToken[i]);
            }
        } else {
            pools[0] = matrixPools[1]; // pair WETH physical
            pairs[0] = address(tokenWeth);
            pools[1] = matrixPools[3]; // pair USDC physical
            pairs[1] = address(tokenUsdc);
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
