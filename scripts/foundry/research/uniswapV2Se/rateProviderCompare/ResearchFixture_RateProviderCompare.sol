// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {
    TokenConfig,
    TokenType
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    ResearchFixture_UniswapV2SeRateMatrix
} from "scripts/foundry/research/uniswapV2Se/ResearchFixture_UniswapV2SeRateMatrix.sol";
import {
    ResearchTelemetry
} from "scripts/foundry/research/harness/ResearchTelemetry.sol";

/**
 * @title ResearchFixture_RateProviderCompare
 * @notice Pure-state Rate Provider comparative fixture (R+ or R− for entire matrix).
 * @dev Homogeneous policy: every SE-share leg uses WITH_RATE (ratesOn) or STANDARD (!ratesOn).
 *      Does not mix policies in one deployment. New research path only — Mode A scripts unchanged.
 *
 * R− fair init still uses SE rateProvider.getRate() for *sizing* only so t0 mid ≈ fair;
 * pools do not wire the rate, so after Uni moves mid lags redeem fair value.
 *
 * R− CREATE3 note: TokenConfig salt ignores rate-provider identity when share legs are STANDARD.
 * That collapses the 4 logical rate×pair cells to 2 physical pools (pair WETH vs pair USDC).
 * Deploy/init override maps all 4 matrix slots onto those 2 pools and inits each once.
 */
contract ResearchFixture_RateProviderCompare is ResearchFixture_UniswapV2SeRateMatrix {
    /// @dev True = all share legs WITH_RATE + providers; false = all STANDARD.
    bool public immutable ratesOn;
    /// @dev Multiplier on baseline TRADE_WETH / TRADE_USDC (1 = baseline, 10/25 = high-vol).
    ///      Balancer swap fee is NOT changed here — volume lever only.
    uint256 public immutable tradeSizeMul;
    /// @dev Effective step count (0 in constructor → TRADE_STEPS default).
    uint256 public immutable tradeStepsN;

    /**
     * @param ratesOn_ Rate policy for entire matrix.
     * @param tradeSizeMul_ Size multiplier on TRADE_WETH/USDC (must be > 0).
     * @param tradeSteps_ Loop iterations; pass 0 to use parent TRADE_STEPS (24).
     */
    constructor(bool ratesOn_, uint256 tradeSizeMul_, uint256 tradeSteps_) {
        require(tradeSizeMul_ > 0, "rpc: tradeSizeMul=0");
        ratesOn = ratesOn_;
        tradeSizeMul = tradeSizeMul_;
        tradeStepsN = tradeSteps_ == 0 ? TRADE_STEPS : tradeSteps_;
    }

    /// @inheritdoc ResearchFixture_UniswapV2SeRateMatrix
    function tradeWethWei() public view override returns (uint256) {
        return TRADE_WETH * tradeSizeMul;
    }

    /// @inheritdoc ResearchFixture_UniswapV2SeRateMatrix
    function tradeUsdcWei() public view override returns (uint256) {
        return TRADE_USDC * tradeSizeMul;
    }

    /// @inheritdoc ResearchFixture_UniswapV2SeRateMatrix
    function tradeSteps() public view override returns (uint256) {
        return tradeStepsN;
    }

    /// @inheritdoc ResearchFixture_UniswapV2SeRateMatrix
    function _tokenConfigs(IERC20 pairToken_, IRateProvider rateProvider_)
        internal
        view
        override
        returns (TokenConfig[] memory tc)
    {
        tc = new TokenConfig[](2);
        (uint256 pairIdx, uint256 sharesIdx) =
            address(pairToken_) < address(shares) ? (uint256(0), uint256(1)) : (uint256(1), uint256(0));
        tc[pairIdx] = TokenConfig({
            token: pairToken_,
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });
        if (ratesOn) {
            tc[sharesIdx] = TokenConfig({
                token: shares,
                tokenType: TokenType.WITH_RATE,
                rateProvider: rateProvider_,
                paysYieldFees: false
            });
        } else {
            // Pure R− world: plain share ERC-20 on Balancer (no rate wiring).
            tc[sharesIdx] = TokenConfig({
                token: shares,
                tokenType: TokenType.STANDARD,
                rateProvider: IRateProvider(address(0)),
                paysYieldFees: false
            });
        }
    }

    /**
     * @dev R+: four distinct CREATE3 pools (rate provider in TokenConfig salt).
     *      R−: two physical pools by pair token only; logical rate-target metadata retained
     *      for residual lenses / telemetry labels. Map:
     *        pair USDC → indices 0 (rateWeth cross) and 3 (rateUsdc same)
     *        pair WETH → indices 1 (rateWeth same) and 2 (rateUsdc cross)
     */
    function _deployMatrixPools() internal override {
        // Labels + rate lenses (same topology as Mode A).
        matrixLabels[0] = "rateWeth_pairUsdc_cross";
        matrixPairToken[0] = tokenUsdc;
        matrixRateTarget[0] = tokenWeth;
        matrixRateProvider[0] = rateProviderWeth;

        matrixLabels[1] = "rateWeth_pairWeth_same";
        matrixPairToken[1] = tokenWeth;
        matrixRateTarget[1] = tokenWeth;
        matrixRateProvider[1] = rateProviderWeth;

        matrixLabels[2] = "rateUsdc_pairWeth_cross";
        matrixPairToken[2] = tokenWeth;
        matrixRateTarget[2] = tokenUsdc;
        matrixRateProvider[2] = rateProviderUsdc;

        matrixLabels[3] = "rateUsdc_pairUsdc_same";
        matrixPairToken[3] = tokenUsdc;
        matrixRateTarget[3] = tokenUsdc;
        matrixRateProvider[3] = rateProviderUsdc;

        if (ratesOn) {
            for (uint256 i = 0; i < MATRIX_N; ++i) {
                TokenConfig[] memory tc = _tokenConfigs(matrixPairToken[i], matrixRateProvider[i]);
                matrixPools[i] = constProdPkg.deployVault(tc, address(0));
                vm.label(matrixPools[i], matrixLabels[i]);
                approveForPool(IERC20(matrixPools[i]));
            }
            return;
        }

        // R−: one deploy per unique pair token (TokenConfig salt collision otherwise).
        TokenConfig[] memory tcUsdc = _tokenConfigs(tokenUsdc, IRateProvider(address(0)));
        TokenConfig[] memory tcWeth = _tokenConfigs(tokenWeth, IRateProvider(address(0)));
        address poolPairUsdc = constProdPkg.deployVault(tcUsdc, address(0));
        address poolPairWeth = constProdPkg.deployVault(tcWeth, address(0));
        vm.label(poolPairUsdc, "rpc_ratesOff_pairUsdc");
        vm.label(poolPairWeth, "rpc_ratesOff_pairWeth");
        approveForPool(IERC20(poolPairUsdc));
        approveForPool(IERC20(poolPairWeth));

        matrixPools[0] = poolPairUsdc; // rateWeth_pairUsdc_cross lens
        matrixPools[1] = poolPairWeth; // rateWeth_pairWeth_same lens
        matrixPools[2] = poolPairWeth; // rateUsdc_pairWeth_cross lens (same physical)
        matrixPools[3] = poolPairUsdc; // rateUsdc_pairUsdc_same lens (same physical)
    }

    /**
     * @dev R+: parent split (shares/4 per logical pool).
     *      R−: two physical pools; each gets shares/2, sized with same-asset rate for that pair
     *      so t0 mid ≈ fair. Logical indices that share a pool skip re-init.
     */
    function _bootstrapSharesAndInitPools() internal override {
        if (ratesOn) {
            super._bootstrapSharesAndInitPools();
            return;
        }

        uint256 totalLp = uniV2Pair.totalSupply();
        uint256 lpHeldByLp = uniV2Pair.balanceOf(lp);
        require(lpHeldByLp >= 2, "rpc: insufficient LP");
        vaultLpDeposited = lpHeldByLp / 2;
        freeLpOutsideVault = lpHeldByLp - vaultLpDeposited;

        vm.prank(lp);
        uniV2Pair.transfer(alice, vaultLpDeposited);

        vm.startPrank(alice);
        uniV2Pair.approve(address(seVault), vaultLpDeposited);
        uint256 sharesOut = seVault.deposit(vaultLpDeposited, alice);
        vm.stopPrank();

        require(sharesOut >= 2, "rpc: too few shares");
        // Per-physical-pool allocation (2 unique pools). Telemetry still uses this field.
        sharesPerPool = sharesOut / 2;
        require(sharesPerPool > 0, "rpc: sharesPerPool=0");
        require(uniV2Pair.balanceOf(lp) == freeLpOutsideVault, "rpc: free LP mismatch");
        require(totalLp == uniV2Pair.totalSupply(), "rpc: LP supply changed");

        // Init unique physical pools once: index 1 (pair WETH, same-asset rateWeth) and
        // index 3 (pair USDC, same-asset rateUsdc). Indices 0/2 share those pools.
        uint256 pairWethAmt = _pairAmountForInit(1, sharesPerPool);
        _initMatrixPool(1, sharesPerPool, pairWethAmt);
        uint256 pairUsdcAmt = _pairAmountForInit(3, sharesPerPool);
        _initMatrixPool(3, sharesPerPool, pairUsdcAmt);
    }

    /**
     * @dev Fair init for both worlds. Uses SE rate providers for sizing so t0 pair/raw ≈ fair
     *      share value, whether or not the pool applies rates live.
     *      R+: liveShares = raw * rate / 1e18 (Balancer WITH_RATE).
     *      R−: same numeric pair amount so mid = pair/raw equals that fair ratio at t0;
     *          after Uni, rate moves but raw mid does not track 1/rate.
     */
    function _pairAmountForInit(uint256 idx, uint256 rawShares_)
        internal
        view
        override
        returns (uint256 pairAmt)
    {
        // Always size from SE rate provider (exists even in R− pure world).
        uint256 rate = matrixRateProvider[idx].getRate();
        require(rate > 0, "rpc: rate=0 before init");
        uint256 liveShares = rawShares_ * rate / 1e18;
        require(liveShares > 0, "rpc: liveShares=0");

        IERC20 pair = matrixPairToken[idx];
        IERC20 rateTarget = matrixRateTarget[idx];

        if (address(pair) == address(rateTarget)) {
            return liveShares;
        }

        (uint256 reservePair, uint256 reserveRateTarget) = _uniReservesOf(pair, rateTarget);
        require(reserveRateTarget > 0, "rpc: zero uni reserve");
        pairAmt = liveShares * reservePair / reserveRateTarget;
        require(pairAmt > 0, "rpc: pairAmt=0");
    }

    /// @dev Meta includes scenarioFamily + rateProviderMode (homogeneous pure state).
    function _buildMetaJson(string memory runId_) internal view override returns (string memory) {
        string memory modeLabel = researchModeId == 1 ? "C_uni_plus_bal_arb" : "A_uni_only";
        string memory tradedLabel = tradedIsWeth ? "WETH" : "USDC";
        string memory marketBought = tradedIsWeth ? "USDC" : "WETH";
        string memory rpMode = ratesOn ? "on" : "off";
        string memory part1 = string.concat(
            "{\"product\":\"uniswapV2Se\",\"scenarioFamily\":\"rateProviderCompare\",\"rateProviderMode\":\"",
            rpMode,
            "\",\"mode\":\"",
            modeLabel,
            "\",\"runId\":\"",
            runId_,
            "\",\"framing\":\"lp_market_demand\",\"tradedAsset\":\"",
            tradedLabel,
            "\",\"marketBoughtAsset\":\"",
            marketBought,
            "\",\"pnlDenom\":\"USDC\","
        );
        string memory part2 = string.concat(
            "\"tradeSteps\":",
            ResearchTelemetry.u(tradeSteps()),
            ",\"tradeSizeMul\":",
            ResearchTelemetry.u(tradeSizeMul),
            ",\"tradeWethWei\":\"",
            ResearchTelemetry.u(tradeWethWei()),
            "\",\"tradeUsdcWei\":\"",
            ResearchTelemetry.u(tradeUsdcWei()),
            "\",\"vaultLpDeposited\":\"",
            ResearchTelemetry.u(vaultLpDeposited),
            "\",\"portfolio0Usdc\":\"",
            ResearchTelemetry.u(portfolio0Usdc),
            "\",\"initPrice_USDC_per_WETH\":\"",
            ResearchTelemetry.u(initUniSpotUsdcPerWeth),
            "\",\"scenariosDoc\":\"research/scenarios/uniswapV2Se/rateProviderCompare/\",",
            "\"note\":\"Pure-state rateProviderCompare. Balancer fee unchanged; volume via tradeSizeMul+tradeSteps. stamp_meta.py adds gitCommit.\"}"
        );
        return string.concat(part1, part2);
    }
}
