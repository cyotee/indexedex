// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title CrossVersionLoopService
 * @author cyotee doge <doge.cyotee>
 * @notice Pure, version-agnostic carry math for the cross-version loop vault: common-unit (USD)
 *         value normalization (PRD decision 29), V4 supply-APY derivation (PRD decision 33), and
 *         net-carry per loop orientation (PRD decision 28), plus per-leg gate helpers
 *         (PRD decisions 1, 24).
 * @dev Conventions: rates are RAY (1e27) APR; BPS is 1e4; USD values are normalized to 1e18 (WAD).
 *      These are pure helpers — the stateful orchestration (recursion, never-borrow unwind, atomic
 *      flip) lives in the exchange/rebalance Targets and is validated by fork tests against real
 *      Ethereum V3.6 + V4. The formulas here MUST be confirmed by those tests before being trusted.
 */
library CrossVersionLoopService {
    uint256 internal constant RAY = 1e27;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant BPS = 1e4;

    /// @dev `a * b / RAY` (ray multiply).
    function _rayMul(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * b) / RAY;
    }

    /// @dev `a * RAY / b` (ray divide).
    function _rayDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * RAY) / b;
    }

    /**
     * @notice Normalize a token amount to a common USD value scaled to 1e18 (WAD).
     * @param amount Raw token amount (in `tokenDecimals`).
     * @param tokenDecimals Decimals of the token.
     * @param price Oracle price of the token (in `priceUnit`).
     * @param priceUnit The oracle's price scale (e.g. 1e8 for V3 `BASE_CURRENCY_UNIT`, or the V4
     *        oracle's own unit). Both V3 and V4 oracles are USD-quoted on Ethereum (PRD decision 29).
     * @return value USD value scaled to 1e18.
     */
    function usdValue(uint256 amount, uint256 tokenDecimals, uint256 price, uint256 priceUnit)
        internal
        pure
        returns (uint256 value)
    {
        // value = amount * price / priceUnit, rescaled from tokenDecimals to 18.
        value = (amount * price * WAD) / (priceUnit * (10 ** tokenDecimals));
    }

    /**
     * @notice Derive the V4 supply APY (RAY) from Hub asset accessors (PRD decision 33).
     * @dev V4 exposes no supply-rate getter (finding F3). Suppliers earn the growth of total owed
     *      (drawn + premium) net of `liquidityFee`; the base drawn rate already drives that growth,
     *      so: supplyAPY = drawnRate * utilization * (1 - liquidityFee), with
     *      utilization = totalOwed / (liquidity + totalOwed). The premium contribution is captured
     *      because `totalOwed` includes premium debt. This is the rate-level approximation of
     *      decision 33's value-level identity; fork tests must confirm fidelity.
     * @param drawnRate Base drawn (borrow) rate (RAY).
     * @param liquidity Available asset liquidity.
     * @param totalOwed Total owed (drawn + premium).
     * @param liquidityFeeBps Protocol liquidity fee (BPS).
     * @return supplyRate Derived supply APY (RAY).
     */
    function deriveV4SupplyRate(uint256 drawnRate, uint256 liquidity, uint256 totalOwed, uint256 liquidityFeeBps)
        internal
        pure
        returns (uint256 supplyRate)
    {
        uint256 denom = liquidity + totalOwed;
        if (denom == 0) return 0;
        uint256 utilizationRay = _rayDiv(totalOwed, denom); // RAY
        uint256 grossRay = _rayMul(drawnRate, utilizationRay); // RAY
        supplyRate = (grossRay * (BPS - liquidityFeeBps)) / BPS;
    }

    /**
     * @notice Effective V4 borrow rate including the user's risk premium (PRD decision 28).
     * @param baseDrawnRate Base drawn rate (RAY).
     * @param riskPremiumBps Risk premium (BPS) over the base.
     * @return effective Effective borrow rate (RAY).
     */
    function effectiveV4BorrowRate(uint256 baseDrawnRate, uint256 riskPremiumBps)
        internal
        pure
        returns (uint256 effective)
    {
        effective = baseDrawnRate + (baseDrawnRate * riskPremiumBps) / BPS;
    }

    /**
     * @notice Net carry (signed, RAY-weighted USD) for one loop orientation (PRD decision 28).
     * @dev orientation: supply X on version A, borrow Y on A, supply Y on B, borrow X on B.
     *      netCarry = [supplyAPY_A(X) - borrowAPY_B(X)] * notionalX
     *               + [supplyAPY_B(Y) - borrowAPY_A(Y)] * notionalY
     *      Notionals are USD (1e18); rates are RAY. Result is signed; positive = profitable.
     * @return netCarry Signed net carry (1e18 USD * RAY / RAY = 1e18 USD per year, approx).
     */
    function netCarry(
        uint256 supplyApyAX,
        uint256 borrowApyBX,
        uint256 notionalX,
        uint256 supplyApyBY,
        uint256 borrowApyAY,
        uint256 notionalY
    ) internal pure returns (int256) {
        int256 legX = (int256(supplyApyAX) - int256(borrowApyBX)) * int256(notionalX) / int256(RAY);
        int256 legY = (int256(supplyApyBY) - int256(borrowApyAY)) * int256(notionalY) / int256(RAY);
        return legX + legY;
    }

    /**
     * @notice Projected LTV (BPS) after a hypothetical position, for the per-version gate
     *         (PRD decisions 1, 24). LTV = debtValue / collateralValue.
     * @param collateralValueUsd Collateral USD value (1e18).
     * @param debtValueUsd Debt USD value (1e18).
     * @return ltvBps Projected LTV in BPS (0 if no collateral).
     */
    function projectedLtvBps(uint256 collateralValueUsd, uint256 debtValueUsd)
        internal
        pure
        returns (uint256 ltvBps)
    {
        if (collateralValueUsd == 0) return 0;
        ltvBps = (debtValueUsd * BPS) / collateralValueUsd;
    }

    /**
     * @notice Whether a projected leg stays within the target-LTV stop (PRD decision 20):
     *         continue only while projected LTV <= target - threshold.
     */
    function withinTargetLtv(uint256 projectedLtvBps_, uint256 targetLtvBps, uint256 thresholdBps)
        internal
        pure
        returns (bool)
    {
        return projectedLtvBps_ + thresholdBps <= targetLtvBps;
    }

    /* ------------------------------- SHARES (decision 10) ------------------- */

    /**
     * @notice LP-style proportional shares to mint for a deposit (PRD decision 10). Shares are a
     *         claim on the net reserves valued in the common unit (NAV). First deposit mints shares
     *         1:1 with deposited value (the caller locks `MINIMUM_LIQUIDITY` per decision 21).
     * @param navBefore Net position value (common unit) before the deposit.
     * @param totalSupply Current total share supply.
     * @param depositValue Deposit value (common unit).
     */
    function sharesForDeposit(uint256 navBefore, uint256 totalSupply, uint256 depositValue)
        internal
        pure
        returns (uint256)
    {
        if (totalSupply == 0 || navBefore == 0) return depositValue;
        return (depositValue * totalSupply) / navBefore;
    }

    /**
     * @notice Common-unit value redeemable for `shares` (PRD decisions 10, 14): pro-rata of NAV.
     */
    function assetsForShares(uint256 nav, uint256 totalSupply, uint256 shares)
        internal
        pure
        returns (uint256)
    {
        if (totalSupply == 0) return 0;
        return (shares * nav) / totalSupply;
    }

    /**
     * @notice Usage/performance fee shares to mint to `feeTo` for NAV growth (PRD decision 19):
     *         dilution mint sized so `feeTo` captures `feeBps` of the value gained since baseline.
     * @dev feeShares / (totalSupply + feeShares) = feeBps/1e4 * growth/nav  →
     *      feeShares = totalSupply * feeValue / (nav - feeValue), where feeValue = growth*feeBps/1e4.
     * @param nav Current NAV (common unit).
     * @param navBaseline NAV baseline at last accrual (common unit).
     * @param totalSupply Current total share supply.
     * @param feeBps Performance fee (BPS) on the growth.
     */
    function performanceFeeShares(uint256 nav, uint256 navBaseline, uint256 totalSupply, uint256 feeBps)
        internal
        pure
        returns (uint256)
    {
        if (nav <= navBaseline || totalSupply == 0) return 0;
        uint256 feeValue = ((nav - navBaseline) * feeBps) / BPS;
        if (feeValue >= nav) return 0; // guard
        return (totalSupply * feeValue) / (nav - feeValue);
    }
}
