// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Router} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRouter} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IRouter.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";

/**
 * @title ResearchModeCCloser
 * @notice Standalone Mode C arb agent — no TestBase / diamond inheritance (stack headroom).
 * @dev After Uni demand moves rates, scan Balancer matrix pools:
 *      buy vault shares with pair → redeem SE → remove Uni LP → convert to profit asset.
 *      Fill only if that beats Uni-only conversion of the pair (profit in traded asset, not USD).
 *
 * Design for stack: structs pack args; each helper is a small scope; no giant functions.
 */
contract ResearchModeCCloser {
    Vm private constant vm = Vm(VM_ADDRESS);

    uint256 public constant MIN_PROFIT = 1e12;
    uint256 public constant PROBE_BPS_LO = 5; // 0.05%
    uint256 public constant PROBE_BPS_MID = 25; // 0.25%
    uint256 public constant PROBE_BPS_HI = 100; // 1%

    /// @dev Immutable env wired once after fixture bootstrap.
    struct Env {
        address agent;
        address balRouter;
        address uniRouter;
        address seVault;
        address shares;
        address uniPair;
        address weth;
        address usdc;
        address bv3Vault;
        address permit2;
        address profitToken; // traded asset: WETH if market buys USDC, else USDC
    }

    struct PoolRef {
        address pool;
        address pair;
    }

    struct Probe {
        uint256 pairIn;
        uint256 profit;
    }

    struct StepResult {
        uint256 profit;
        uint256 fills;
        uint256 pairSpent;
        /// @dev Best probe profits seen this step (wei of profitToken), even if below MIN_PROFIT.
        uint256 maxBuyProbe;
        uint256 maxSellProbe;
        /// @dev How many pool legs returned a successful on-path swap/redeem probe (>0 profit).
        uint256 positiveProbes;
    }

    Env private _env;
    bool private _configured;
    /// @dev Last closeAll diagnostics (for scripts / findings).
    StepResult public lastResult;

    function configure(Env memory e) external {
        require(e.agent != address(0), "closer: agent");
        require(e.profitToken != address(0), "closer: profit");
        _env = e;
        _configured = true;
        _approveAgent();
    }

    function env() external view returns (Env memory) {
        return _env;
    }

    /**
     * @notice Try arb on each pool; return aggregate profit in profitToken wei.
     * @dev `pools` / `pairs` same length (matrix). Uses snapshots for sizing probes.
     */
    function closeAll(address[] calldata pools, address[] calldata pairs)
        external
        returns (StepResult memory out)
    {
        require(_configured, "closer: not configured");
        require(pools.length == pairs.length, "closer: len");

        for (uint256 i = 0; i < pools.length; ++i) {
            PoolRef memory pref = PoolRef({pool: pools[i], pair: pairs[i]});

            // Direction A: buy shares with pair → redeem vault (user intent).
            Probe memory buy = _bestBuyProbe(pref);
            // Direction B: mint shares via vault → sell shares for pair on Balancer.
            Probe memory sell = _bestSellProbe(pref);

            if (buy.profit > out.maxBuyProbe) out.maxBuyProbe = buy.profit;
            if (sell.profit > out.maxSellProbe) out.maxSellProbe = sell.profit;
            if (buy.profit > 0 || sell.profit > 0) out.positiveProbes += 1;

            Probe memory best = buy.profit >= sell.profit ? buy : sell;
            bool isBuy = buy.profit >= sell.profit;

            if (best.profit < MIN_PROFIT || best.pairIn == 0) continue;

            uint256 realized =
                isBuy ? _executeBuyShares(pref, best.pairIn) : _executeSellShares(pref, best.pairIn);
            if (realized >= MIN_PROFIT) {
                out.profit += realized;
                out.fills += 1;
                out.pairSpent += best.pairIn;
            }
        }
        lastResult = out;
    }

    /* ---------------------------------------------------------------------- */
    /*                              Probe sizing                               */
    /* ---------------------------------------------------------------------- */

    function _bestBuyProbe(PoolRef memory pref) private returns (Probe memory best) {
        uint256 raw = _pairRaw(pref);
        if (raw < 1e6) return best;
        best = _maxBuy(best, pref, raw * PROBE_BPS_LO / 10_000);
        best = _maxBuy(best, pref, raw * PROBE_BPS_MID / 10_000);
        best = _maxBuy(best, pref, raw * PROBE_BPS_HI / 10_000);
    }

    function _bestSellProbe(PoolRef memory pref) private returns (Probe memory best) {
        // Sell path sizes by target LP notional in WETH terms (~same scale as buy probes).
        uint256 raw = _pairRaw(pref);
        if (raw < 1e6) return best;
        // Use small absolute WETH budget for LP mint (0.05 / 0.25 / 1 WETH).
        best = _maxSell(best, pref, 5e16);
        best = _maxSell(best, pref, 25e16);
        best = _maxSell(best, pref, 1e18);
    }

    function _maxBuy(Probe memory cur, PoolRef memory pref, uint256 pairIn)
        private
        returns (Probe memory)
    {
        if (pairIn == 0) return cur;
        uint256 snap = vm.snapshotState();
        uint256 p = _executeBuyShares(pref, pairIn);
        vm.revertToState(snap);
        if (p > cur.profit) {
            cur.profit = p;
            cur.pairIn = pairIn;
        }
        return cur;
    }

    function _maxSell(Probe memory cur, PoolRef memory pref, uint256 wethBudget)
        private
        returns (Probe memory)
    {
        if (wethBudget == 0) return cur;
        uint256 snap = vm.snapshotState();
        uint256 p = _executeSellShares(pref, wethBudget);
        vm.revertToState(snap);
        if (p > cur.profit) {
            cur.profit = p;
            cur.pairIn = wethBudget; // reuse field as size key
        }
        return cur;
    }

    /* ---------------------------------------------------------------------- */
    /*                    Execute: buy shares → redeem vault                   */
    /* ---------------------------------------------------------------------- */

    /// @dev pairIn of pair → Balancer buy shares → SE redeem → Uni LP out → profit token.
    function _executeBuyShares(PoolRef memory pref, uint256 pairIn) private returns (uint256 profit) {
        Env memory e = _env;
        if (pairIn == 0) return 0;

        uint256 cost = _uniQuote(pref.pair, e.profitToken, pairIn);
        if (cost == 0) return 0;

        _drainAgent();
        _fund(pref.pair, pairIn);

        if (!_buyShares(pref, pairIn)) {
            _drainAgent();
            return 0;
        }
        _redeemVaultToLp();
        _removeLp();
        _swapOtherToProfit();

        return _takeProfit(cost);
    }

    /* ---------------------------------------------------------------------- */
    /*              Execute: mint vault shares → sell on Balancer              */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev wethBudget: add Uni LP with WETH+USDC at live ratio, deposit SE, sell shares for pair,
     *      convert inventory to profit token. Cost = Uni-value of funded WETH+USDC in profit token.
     */
    function _executeSellShares(PoolRef memory pref, uint256 wethBudget)
        private
        returns (uint256 profit)
    {
        Env memory e = _env;
        if (wethBudget == 0) return 0;

        // Fund LP legs at live Uni ratio: usdcBudget ≈ weth * spot.
        uint256 usdcBudget = _uniQuote(e.weth, e.usdc, wethBudget);
        if (usdcBudget == 0) return 0;

        uint256 cost = _uniQuote(e.weth, e.profitToken, wethBudget)
            + _uniQuote(e.usdc, e.profitToken, usdcBudget);
        if (cost == 0) return 0;

        _drainAgent();
        _fund(e.weth, wethBudget);
        _fund(e.usdc, usdcBudget);

        if (!_mintSharesFromUniLp(wethBudget, usdcBudget)) {
            _drainAgent();
            return 0;
        }
        uint256 sh = IERC20(e.shares).balanceOf(e.agent);
        if (sh == 0) return 0;
        if (!_sellShares(pref, sh)) {
            _drainAgent();
            return 0;
        }
        _swapOtherToProfit();
        // Any leftover pair is converted above if other==pair; also convert pair if pair!=profit.
        _swapTokenToProfit(pref.pair);

        return _takeProfit(cost);
    }

    function _takeProfit(uint256 cost) private returns (uint256 profit) {
        Env memory e = _env;
        uint256 got = IERC20(e.profitToken).balanceOf(e.agent);
        if (got <= cost) return 0;
        profit = got - cost;
        address sink = address(uint160(uint256(keccak256("modeCArbSink"))));
        vm.prank(e.agent);
        IERC20(e.profitToken).transfer(sink, got);
    }

    function _mintSharesFromUniLp(uint256 wethIn, uint256 usdcIn) private returns (bool ok) {
        Env memory e = _env;
        vm.startPrank(e.agent);
        IERC20(e.weth).approve(e.uniRouter, wethIn);
        IERC20(e.usdc).approve(e.uniRouter, usdcIn);
        try IUniswapV2Router(e.uniRouter).addLiquidity(
            e.weth, e.usdc, wethIn, usdcIn, 0, 0, e.agent, block.timestamp + 1 hours
        ) {
            uint256 lpBal = IERC20(e.uniPair).balanceOf(e.agent);
            if (lpBal == 0) {
                ok = false;
            } else {
                IERC20(e.uniPair).approve(e.seVault, lpBal);
                try IStandardExchangeProxy(e.seVault).deposit(lpBal, e.agent) {
                    ok = true;
                } catch {
                    ok = false;
                }
            }
        } catch {
            ok = false;
        }
        vm.stopPrank();
    }

    function _sellShares(PoolRef memory pref, uint256 shareIn) private returns (bool ok) {
        Env memory e = _env;
        vm.startPrank(e.agent);
        IERC20(e.shares).approve(e.permit2 != address(0) ? e.permit2 : e.balRouter, shareIn);
        try IRouter(e.balRouter).swapSingleTokenExactIn(
            pref.pool,
            IERC20(e.shares),
            IERC20(pref.pair),
            shareIn,
            0,
            block.timestamp + 1 hours,
            false,
            bytes("")
        ) {
            ok = true;
        } catch {
            ok = false;
        }
        vm.stopPrank();
    }

    function _swapTokenToProfit(address token) private {
        Env memory e = _env;
        if (token == e.profitToken) return;
        uint256 bal = IERC20(token).balanceOf(e.agent);
        if (bal == 0) return;
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = e.profitToken;
        vm.startPrank(e.agent);
        IERC20(token).approve(e.uniRouter, bal);
        try IUniswapV2Router(e.uniRouter).swapExactTokensForTokens(
            bal, 0, path, e.agent, block.timestamp + 1 hours
        ) {} catch {}
        vm.stopPrank();
    }

    function _buyShares(PoolRef memory pref, uint256 pairIn) private returns (bool ok) {
        Env memory e = _env;
        vm.startPrank(e.agent);
        // Balancer V3 Router pulls via Permit2 (match production test harness pattern).
        if (e.permit2 != address(0)) {
            IERC20(pref.pair).approve(e.permit2, type(uint256).max);
            _permit2Max(e.permit2, pref.pair, e.balRouter);
        } else {
            IERC20(pref.pair).approve(e.balRouter, pairIn);
        }
        try IRouter(e.balRouter).swapSingleTokenExactIn(
            pref.pool,
            IERC20(pref.pair),
            IERC20(e.shares),
            pairIn,
            0,
            block.timestamp + 1 hours,
            false,
            bytes("")
        ) {
            ok = true;
        } catch {
            ok = false;
        }
        vm.stopPrank();
    }

    function _redeemVaultToLp() private {
        Env memory e = _env;
        uint256 sh = IERC20(e.shares).balanceOf(e.agent);
        if (sh == 0) return;
        vm.prank(e.agent);
        IStandardExchangeProxy(e.seVault).redeem(sh, e.agent, e.agent);
    }

    function _removeLp() private {
        Env memory e = _env;
        uint256 lpBal = IERC20(e.uniPair).balanceOf(e.agent);
        if (lpBal == 0) return;
        vm.startPrank(e.agent);
        IERC20(e.uniPair).approve(e.uniRouter, lpBal);
        IUniswapV2Router(e.uniRouter).removeLiquidity(
            e.weth, e.usdc, lpBal, 0, 0, e.agent, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _swapOtherToProfit() private {
        Env memory e = _env;
        address other = e.profitToken == e.weth ? e.usdc : e.weth;
        uint256 bal = IERC20(other).balanceOf(e.agent);
        if (bal == 0) return;

        address[] memory path = new address[](2);
        path[0] = other;
        path[1] = e.profitToken;

        vm.startPrank(e.agent);
        IERC20(other).approve(e.uniRouter, bal);
        try IUniswapV2Router(e.uniRouter).swapExactTokensForTokens(
            bal, 0, path, e.agent, block.timestamp + 1 hours
        ) {} catch {}
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                              Quotes / IO                                */
    /* ---------------------------------------------------------------------- */

    function _pairRaw(PoolRef memory pref) private view returns (uint256) {
        (IERC20[] memory tokens,, uint256[] memory balancesRaw,) =
            IVault(_env.bv3Vault).getPoolTokenInfo(pref.pool);
        if (address(tokens[0]) == pref.pair) return balancesRaw[0];
        return balancesRaw[1];
    }

    function _uniQuote(address tokenIn, address tokenOut, uint256 amountIn)
        private
        view
        returns (uint256)
    {
        if (amountIn == 0) return 0;
        if (tokenIn == tokenOut) return amountIn;
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        return IUniswapV2Router(_env.uniRouter).getAmountsOut(amountIn, path)[1];
    }

    function _fund(address token, uint256 amount) private {
        Env memory e = _env;
        if (amount == 0) return;
        if (token == e.weth) {
            vm.deal(e.agent, amount);
            vm.prank(e.agent);
            (bool ok,) = e.weth.call{value: amount}(abi.encodeWithSignature("deposit()"));
            require(ok, "closer: weth");
        } else {
            (bool ok,) = token.call(abi.encodeWithSignature("mint(address,uint256)", e.agent, amount));
            require(ok, "closer: mint");
        }
    }

    function _drainAgent() private {
        Env memory e = _env;
        _drainToken(e.weth);
        _drainToken(e.usdc);
        _drainToken(e.shares);
        _drainToken(e.uniPair);
    }

    function _drainToken(address token) private {
        uint256 bal = IERC20(token).balanceOf(_env.agent);
        if (bal == 0) return;
        vm.prank(_env.agent);
        IERC20(token).transfer(address(0xdead), bal);
    }

    function _approveAgent() private {
        Env memory e = _env;
        vm.startPrank(e.agent);
        // Uni V2 router: direct ERC20 allowance.
        IERC20(e.weth).approve(e.uniRouter, type(uint256).max);
        IERC20(e.usdc).approve(e.uniRouter, type(uint256).max);
        IERC20(e.uniPair).approve(e.uniRouter, type(uint256).max);
        IERC20(e.shares).approve(e.seVault, type(uint256).max);
        // Balancer V3 router typically pulls via Permit2.
        if (e.permit2 != address(0)) {
            IERC20(e.weth).approve(e.permit2, type(uint256).max);
            IERC20(e.usdc).approve(e.permit2, type(uint256).max);
            IERC20(e.shares).approve(e.permit2, type(uint256).max);
            _permit2Max(e.permit2, e.weth, e.balRouter);
            _permit2Max(e.permit2, e.usdc, e.balRouter);
            _permit2Max(e.permit2, e.shares, e.balRouter);
        } else {
            IERC20(e.weth).approve(e.balRouter, type(uint256).max);
            IERC20(e.usdc).approve(e.balRouter, type(uint256).max);
            IERC20(e.shares).approve(e.balRouter, type(uint256).max);
        }
        vm.stopPrank();
    }

    function _permit2Max(address permit2, address token, address spender) private {
        // IAllowanceTransfer.approve(token, spender, amount, expiration)
        (bool ok,) = permit2.call(
            abi.encodeWithSignature(
                "approve(address,address,uint160,uint48)",
                token,
                spender,
                type(uint160).max,
                type(uint48).max
            )
        );
        require(ok, "closer: permit2");
    }
}
