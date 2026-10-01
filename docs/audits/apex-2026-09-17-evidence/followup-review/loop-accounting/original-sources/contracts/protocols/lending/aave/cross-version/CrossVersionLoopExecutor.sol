// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IPool} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPool.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";
import {IAToken} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAToken.sol";
import {DataTypes} from
    "@crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/types/DataTypes.sol";
import {ReserveConfiguration} from
    "@crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/configuration/ReserveConfiguration.sol";
import {TokenMath} from
    "@crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/helpers/TokenMath.sol";
import {ISpoke} from "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/ISpoke.sol";
import {IHub} from "@crane/contracts/protocols/lending/aave/v4/hub/interfaces/IHub.sol";

import {AaveV36Service} from "contracts/protocols/lending/aave/cross-version/AaveV36Service.sol";
import {AaveV4Service} from "contracts/protocols/lending/aave/cross-version/AaveV4Service.sol";

/**
 * @title CrossVersionLoopExecutor
 * @author cyotee doge <doge.cyotee>
 * @notice Core recursive cross-version leverage loop (PRD decisions 13, 20). Runs in the position
 *         holder's context (the vault) via the Service libs, which use `address(this)`.
 * @dev Geometric leverage: supply the deposit on V3, then per iteration borrow the paired token on
 *      one version (up to `ltvBps * safetyBps` of the freshly-added collateral) and supply it on the
 *      other version, alternating, until the layer shrinks below a dust threshold or `maxIterations`.
 *      Sizing uses the V3 oracle for both tokens (common USD scale). A precise target-LTV stop and
 *      live-HF gate per leg are refined when wired into the rebalance/exchange facets.
 */
library CrossVersionLoopExecutor {
    using AaveV36Service for IPool;
    using AaveV4Service for ISpoke;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using TokenMath for uint256;

    uint256 internal constant BPS = 1e4;
    uint256 internal constant MIN_LAYER_USD = 1e8; // $1 (oracle base 1e8) dust floor

    struct Market {
        IPool v36Pool;
        IAaveOracle v36Oracle;
        ISpoke v4Spoke;
        IHub v4Hub;
        IERC20 tokenA;
        IERC20 tokenB;
        uint256 v4ReserveIdA;
        uint256 v4ReserveIdB;
    }

    struct LoopConfig {
        uint256 ltvBps; // per-leg LTV cap to borrow against fresh collateral
        uint256 safetyBps; // fraction of the LTV actually used (margin)
        uint256 maxIterations;
    }

    /// @dev Cumulative progress + phi targets for a proportional unwind. Kept in memory so the
    ///      HF-safe stepping loop stays under the stack limit without `via_ir`.
    struct UnwindState {
        uint256 twB; // V4 tokenB collateral to withdraw (funds the V3 tokenB repay)
        uint256 trB; // V3 tokenB debt to repay (ceil of phi)
        uint256 twA; // V3 tokenA collateral to withdraw (floor of phi)
        uint256 trA; // V4 tokenA debt to repay (ceil of phi)
        uint256 doneWB;
        uint256 doneRB;
        uint256 doneWA;
        uint256 doneRA;
    }

    // Bound for the HF-safe proportional unwind. Small/partial exits finish in one pass; a
    // near-full exit deleverages fastest as debt clears (HF rises), so this ceiling is ample.
    uint256 internal constant UNWIND_MAX_ITERATIONS = 100;

    /// @dev USD value (oracle base 1e8) of `amount` of a token with `decimals` at `price` (1e8).
    function _toUsd(uint256 amount, uint8 decimals, uint256 price) internal pure returns (uint256) {
        return (amount * price) / (10 ** decimals);
    }

    /// @dev Token amount for a target USD value (oracle base 1e8).
    function _fromUsd(uint256 usd, uint8 decimals, uint256 price) internal pure returns (uint256) {
        return (usd * (10 ** decimals)) / price;
    }

    /// @dev Remaining V3 tokenA supply headroom. Cap 0 means unbounded. Paused/frozen is capacity 0.
    function tokenASupplyCapacity(Market memory m) internal view returns (uint256) {
        DataTypes.ReserveConfigurationMap memory cfg = m.v36Pool.getConfiguration(address(m.tokenA));
        if (cfg.getPaused() || cfg.getFrozen()) return 0;
        uint256 supplyCap = cfg.getSupplyCap();
        if (supplyCap == 0) return type(uint256).max;
        DataTypes.ReserveDataLegacy memory rd = m.v36Pool.getReserveData(address(m.tokenA));
        uint256 index = m.v36Pool.getReserveNormalizedIncome(address(m.tokenA));
        uint256 used = (IAToken(rd.aTokenAddress).scaledTotalSupply() + uint256(rd.accruedToTreasury))
            .getATokenBalance(index);
        uint256 capTokens = supplyCap * (10 ** cfg.getDecimals());
        return capTokens > used ? capTokens - used : 0;
    }

    /// @notice Deposit `amountA` of tokenA and build the leveraged cross-version loop (A-first):
    ///         supply A on V3, borrow B on V3, supply B on V4, borrow A on V4, supply A on V3, repeat.
    ///         Stops at the V3 tokenA supply cap and retains unsupplied principal locally (D43).
    function depositLoopAFirst(Market memory m, uint256 amountA, LoopConfig memory cfg) internal {
        // One-time max approvals to both venues for both tokens.
        m.tokenA.approve(address(m.v36Pool), type(uint256).max);
        m.tokenB.approve(address(m.v36Pool), type(uint256).max);
        m.tokenA.approve(address(m.v4Spoke), type(uint256).max);
        m.tokenB.approve(address(m.v4Spoke), type(uint256).max);

        uint256 priceA = m.v36Oracle.getAssetPrice(address(m.tokenA));
        uint256 priceB = m.v36Oracle.getAssetPrice(address(m.tokenB));
        uint8 decA = IERC20Metadata(address(m.tokenA)).decimals();
        uint8 decB = IERC20Metadata(address(m.tokenB)).decimals();

        uint256 factorBps = (cfg.ltvBps * cfg.safetyBps) / BPS; // effective per-leg borrow fraction

        uint256 cap = tokenASupplyCapacity(m);
        uint256 initial = amountA < cap ? amountA : cap;
        if (initial == 0) return;

        AaveV36Service.supply(m.v36Pool, address(m.tokenA), initial);

        uint256 layerUsd = (_toUsd(initial, decA, priceA) * factorBps) / BPS;

        for (uint256 i = 0; i < cfg.maxIterations; ++i) {
            if (layerUsd < MIN_LAYER_USD) break;
            if (tokenASupplyCapacity(m) == 0) break;

            uint256 borrowB = _fromUsd(layerUsd, decB, priceB);
            // D61: clamp to the account's live V3 borrow headroom so a position already at its LTV
            // (e.g. after a partial unwind, donation or oracle move) degrades gracefully instead of
            // reverting CollateralCannotCoverNewBorrow.
            {
                (,, uint256 availUsd,,,) = m.v36Pool.getUserAccountData(address(this));
                uint256 availB = _fromUsd(availUsd, decB, priceB);
                if (borrowB > availB) borrowB = availB;
                if (borrowB == 0) break;
            }
            AaveV36Service.borrow(m.v36Pool, address(m.tokenB), borrowB);
            AaveV4Service.supply(m.v4Spoke, m.v4ReserveIdB, borrowB);
            if (i == 0) m.v4Spoke.setUsingAsCollateral(m.v4ReserveIdB, true, address(this));

            layerUsd = (layerUsd * factorBps) / BPS;
            if (layerUsd < MIN_LAYER_USD) break;
            if (!_borrowAndResupplyA(m, _fromUsd(layerUsd, decA, priceA))) break;
            layerUsd = (layerUsd * factorBps) / BPS;
        }
    }

    /// @dev Borrow tokenA on V4 and resupply V3, clamped to remaining V3 capacity. False means stop.
    function _borrowAndResupplyA(Market memory m, uint256 want) private returns (bool continued) {
        uint256 cap = tokenASupplyCapacity(m);
        if (cap == 0 || want == 0) return false;
        uint256 borrowA = want < cap ? want : cap;
        AaveV4Service.borrow(m.v4Spoke, m.v4ReserveIdA, borrowA);
        AaveV36Service.supply(m.v36Pool, address(m.tokenA), borrowA);
        return borrowA == want;
    }

    /// @dev Fraction (WAD) of collateral safely removable to keep HF >= ~1.05, with a 5% extra
    ///      margin. Version-agnostic (works off the reported HF). Returns 0 if HF is already tight.
    function _safeFraction(uint256 hf) internal pure returns (uint256) {
        uint256 floorHf = 1.05e18;
        if (hf <= floorHf + 0.01e18) return 0;
        // Removing fraction f of collateral lowers HF roughly proportionally (collateral-dominated
        // position): newHF ~= hf*(1-f). Keep newHF >= floorHf => f <= 1 - floorHf/hf. Apply 95% margin.
        uint256 f = 1e18 - (floorHf * 1e18) / hf;
        return (f * 95) / 100;
    }

    /// @notice Fully unwind the loop using the never-borrow rule (PRD decision 14): alternately
    ///         withdraw an HF-safe fraction of collateral and repay debt across versions until debt
    ///         clears, then withdraw the remainder. Never borrows; HF stays >= ~1.05 each step, so it
    ///         never reverts on the HF edge. Leaves net tokenA + tokenB as raw balances.
    function fullUnwind(Market memory m, uint256 maxIterations) internal {
        m.tokenA.approve(address(m.v36Pool), type(uint256).max);
        m.tokenB.approve(address(m.v36Pool), type(uint256).max);
        m.tokenA.approve(address(m.v4Spoke), type(uint256).max);
        m.tokenB.approve(address(m.v4Spoke), type(uint256).max);

        for (uint256 i = 0; i < maxIterations; ++i) {
            bool progressed = false;

            // V4 side: withdraw an HF-safe fraction of tokenB collateral, repay V3 tokenB debt.
            if (AaveV36Service.debtOf(m.v36Pool, address(m.tokenB), address(this)) > 0) {
                uint256 suppliedB = AaveV4Service.suppliedOf(m.v4Spoke, m.v4ReserveIdB, address(this));
                uint256 wB = (suppliedB * _safeFraction(AaveV4Service.healthFactor(m.v4Spoke, address(this)))) / 1e18;
                if (wB > 0) {
                    AaveV4Service.withdraw(m.v4Spoke, m.v4ReserveIdB, wB);
                    progressed = true;
                }
                uint256 rawB = m.tokenB.balanceOf(address(this));
                if (rawB > 0) {
                    AaveV36Service.repay(m.v36Pool, address(m.tokenB), rawB);
                    progressed = true;
                }
            }

            // V3 side: withdraw an HF-safe fraction of tokenA collateral, repay V4 tokenA debt.
            if (AaveV4Service.debtOf(m.v4Spoke, m.v4ReserveIdA, address(this)) > 0) {
                uint256 suppliedA = AaveV36Service.suppliedOf(m.v36Pool, address(m.tokenA), address(this));
                uint256 wA = (suppliedA * _safeFraction(AaveV36Service.healthFactor(m.v36Pool, address(this)))) / 1e18;
                if (wA > 0) {
                    AaveV36Service.withdraw(m.v36Pool, address(m.tokenA), wA);
                    progressed = true;
                }
                uint256 rawA = m.tokenA.balanceOf(address(this));
                if (rawA > 0) {
                    AaveV4Service.repay(m.v4Spoke, m.v4ReserveIdA, rawA);
                    progressed = true;
                }
            }

            if (!progressed) break;
        }

        // Once a side's debt is fully cleared, its collateral is unconstrained: withdraw all of it.
        if (AaveV36Service.debtOf(m.v36Pool, address(m.tokenB), address(this)) == 0) {
            if (AaveV36Service.suppliedOf(m.v36Pool, address(m.tokenA), address(this)) > 0) {
                AaveV36Service.withdraw(m.v36Pool, address(m.tokenA), type(uint256).max);
            }
        }
        if (AaveV4Service.debtOf(m.v4Spoke, m.v4ReserveIdA, address(this)) == 0) {
            if (AaveV4Service.suppliedOf(m.v4Spoke, m.v4ReserveIdB, address(this)) > 0) {
                AaveV4Service.withdraw(m.v4Spoke, m.v4ReserveIdB, type(uint256).max);
            }
        }
    }

    /// @notice Net balance (post-unwind) of `token` across both versions: supplied - debt, floored at 0.
    function netBalanceOf(Market memory m, IERC20 token, uint256 v4ReserveId)
        internal
        view
        returns (uint256)
    {
        uint256 supplied = AaveV36Service.suppliedOf(m.v36Pool, address(token), address(this))
            + AaveV4Service.suppliedOf(m.v4Spoke, v4ReserveId, address(this));
        uint256 debt = AaveV36Service.debtOf(m.v36Pool, address(token), address(this))
            + AaveV4Service.debtOf(m.v4Spoke, v4ReserveId, address(this));
        return supplied >= debt ? supplied - debt : 0;
    }

    /// @notice Max tokenA directly withdrawable from V3 now, keeping HF safe (5% margin). This is the
    ///         amount a single-token withdrawal can free from the buffer without deleveraging
    ///         (PRD decisions 14, 15). Larger withdrawals (requiring deleverage) are a later refinement.
    function maxWithdrawableA(Market memory m) internal view returns (uint256) {
        uint256 suppliedA = AaveV36Service.suppliedOf(m.v36Pool, address(m.tokenA), address(this));
        (uint256 totalColl, uint256 totalDebt,, uint256 liqThresh,,) = m.v36Pool.getUserAccountData(address(this));
        if (totalDebt == 0) return suppliedA;
        uint256 needColl = (totalDebt * BPS) / liqThresh;
        if (totalColl <= needColl) return 0;
        uint256 priceA = m.v36Oracle.getAssetPrice(address(m.tokenA));
        uint256 removableA =
            ((totalColl - needColl) * (10 ** IERC20Metadata(address(m.tokenA)).decimals())) / priceA;
        removableA = (removableA * 95) / 100; // HF safety margin
        return removableA < suppliedA ? removableA : suppliedA;
    }

    /// @notice Withdraw `amount` of tokenA from V3 supply to the vault (never borrows).
    function withdrawA(Market memory m, uint256 amount) internal returns (uint256) {
        return AaveV36Service.withdraw(m.v36Pool, address(m.tokenA), amount);
    }

    /// @notice D61: burning `num` of `den` shares is a claim on phi = num/den of every position leg, so
    ///         scale all four legs by phi: free phi of each collateral and retire phi of each debt. Repay
    ///         rounds up and withdraw rounds down, so the remaining position's LTV never rises, which keeps
    ///         borrow headroom for the next deposit. Returns the net tokenA freed to the vault
    ///         (= floor(phi*suppliedA) - ceil(phi*debtA), matching `proportionalFreeableA`).
    /// @dev A single pass that withdrew a leg's collateral before repaying that leg's cross-token debt
    ///      transiently breached the version's HF near a full exit (phi -> 1). Instead this repays each
    ///      version's debt from freed collateral in HF-safe steps (like `fullUnwind`), so no intermediate
    ///      withdrawal ever drops a version below its liquidation buffer, while total collateral removed
    ///      (floor) and total debt repaid (ceil) still hit the proportional targets. Never borrows.
    function proportionalUnwind(Market memory m, uint256 num, uint256 den) internal returns (uint256 freedA) {
        if (num == 0 || den == 0) return 0;
        uint256 beforeA = m.tokenA.balanceOf(address(this));

        UnwindState memory st;
        // D61 rounding: repay ceil (debt never left under-retired), withdraw floor (collateral never
        // over-removed) so the remaining position's LTV never rises.
        st.trB = Math.mulDiv(AaveV36Service.debtOf(m.v36Pool, address(m.tokenB), address(this)), num, den, Math.Rounding.Ceil);
        st.trA = Math.mulDiv(AaveV4Service.debtOf(m.v4Spoke, m.v4ReserveIdA, address(this)), num, den, Math.Rounding.Ceil);
        st.twA = Math.mulDiv(AaveV36Service.suppliedOf(m.v36Pool, address(m.tokenA), address(this)), num, den);
        {
            // Withdraw only enough V4 tokenB collateral to fund the V3 tokenB repay (bounded by supply).
            uint256 suppliedB = AaveV4Service.suppliedOf(m.v4Spoke, m.v4ReserveIdB, address(this));
            st.twB = st.trB < suppliedB ? st.trB : suppliedB;
        }

        for (uint256 i = 0; i < UNWIND_MAX_ITERATIONS; ++i) {
            bool progressed = false;
            // V4 tokenB collateral -> raw tokenB (HF-safe fraction of what remains this step).
            if (st.doneWB < st.twB) {
                uint256 supB = AaveV4Service.suppliedOf(m.v4Spoke, m.v4ReserveIdB, address(this));
                uint256 safeB = (supB * _safeFraction(AaveV4Service.healthFactor(m.v4Spoke, address(this)))) / 1e18;
                uint256 want = st.twB - st.doneWB;
                uint256 wb = want < safeB ? want : safeB;
                if (wb > 0) { AaveV4Service.withdraw(m.v4Spoke, m.v4ReserveIdB, wb); st.doneWB += wb; progressed = true; }
            }
            // Repay V3 tokenB debt from raw tokenB (raises V3 HF; never repay 0).
            if (st.doneRB < st.trB) {
                uint256 haveB = m.tokenB.balanceOf(address(this));
                uint256 rb = st.trB - st.doneRB;
                if (rb > haveB) rb = haveB;
                if (rb > 0) { AaveV36Service.repay(m.v36Pool, address(m.tokenB), rb); st.doneRB += rb; progressed = true; }
            }
            // V3 tokenA collateral -> raw tokenA (HF-safe fraction; V3 HF is now higher from the repay).
            if (st.doneWA < st.twA) {
                uint256 supA = AaveV36Service.suppliedOf(m.v36Pool, address(m.tokenA), address(this));
                uint256 safeA = (supA * _safeFraction(AaveV36Service.healthFactor(m.v36Pool, address(this)))) / 1e18;
                uint256 want = st.twA - st.doneWA;
                uint256 wa = want < safeA ? want : safeA;
                if (wa > 0) { AaveV36Service.withdraw(m.v36Pool, address(m.tokenA), wa); st.doneWA += wa; progressed = true; }
            }
            // Repay V4 tokenA debt from raw tokenA (raises V4 HF for the next step; never repay 0).
            if (st.doneRA < st.trA) {
                uint256 haveA = m.tokenA.balanceOf(address(this));
                uint256 ra = st.trA - st.doneRA;
                if (ra > haveA) ra = haveA;
                if (ra > 0) { AaveV4Service.repay(m.v4Spoke, m.v4ReserveIdA, ra); st.doneRA += ra; progressed = true; }
            }
            if (st.doneWB >= st.twB && st.doneRB >= st.trB && st.doneWA >= st.twA && st.doneRA >= st.trA) break;
            if (!progressed) break;
        }

        // navUsd counts tokenB only as (supplied - debt), so any freed tokenB dust must not be stranded.
        uint256 dustB = m.tokenB.balanceOf(address(this));
        if (dustB > 0) AaveV4Service.supply(m.v4Spoke, m.v4ReserveIdB, dustB);
        freedA = m.tokenA.balanceOf(address(this)) - beforeA;
    }

    /// @notice D61: exact net tokenA a proportional unwind of `num`/`den` shares frees, computed with the
    ///         same rounding the unwind uses: floor(phi*suppliedA) - ceil(phi*debtA). This is the precise
    ///         freeable envelope for a pro-rata exit; the earlier floor(phi*(s-d)) over-predicted it by up
    ///         to a wei, which surfaced as a 1-wei `AmountOutNotMet` at execution.
    function proportionalFreeableA(Market memory m, uint256 num, uint256 den) internal view returns (uint256) {
        if (num == 0 || den == 0) return 0;
        uint256 s = AaveV36Service.suppliedOf(m.v36Pool, address(m.tokenA), address(this));
        uint256 d = AaveV4Service.debtOf(m.v4Spoke, m.v4ReserveIdA, address(this));
        uint256 wA = Math.mulDiv(s, num, den);
        uint256 rA = Math.mulDiv(d, num, den, Math.Rounding.Ceil);
        return wA > rA ? wA - rA : 0;
    }

    /// @notice Locally retained tokenA. The loop rejects every public pretransfer (D32), so the
    ///         whole raw balance is vault-owned backing that the supply cap kept out of V3 (D43).
    function localTokenA(Market memory m) internal view returns (uint256) {
        return m.tokenA.balanceOf(address(this));
    }

    /// @notice Common-unit USD value (oracle base 1e8) of `amount` of a pair token.
    function valueUsd(Market memory m, IERC20 token, uint256 amount) internal view returns (uint256) {
        uint256 price = m.v36Oracle.getAssetPrice(address(token));
        return _toUsd(amount, IERC20Metadata(address(token)).decimals(), price);
    }

    /// @notice Net position value (NAV) in the common USD unit (oracle base 1e8), reconciled live
    ///         from Aave (PRD decisions 2, 10): netA*priceA + netB*priceB. Used for share pricing.
    ///         Locally retained tokenA (principal not supplied because of the V3 supply cap, D43)
    ///         is booked backing and counts at the same oracle price (R14.12).
    function navUsd(Market memory m) internal view returns (uint256) {
        uint256 priceA = m.v36Oracle.getAssetPrice(address(m.tokenA));
        uint256 priceB = m.v36Oracle.getAssetPrice(address(m.tokenB));
        uint256 netA = netBalanceOf(m, m.tokenA, m.v4ReserveIdA) + localTokenA(m);
        uint256 netB = netBalanceOf(m, m.tokenB, m.v4ReserveIdB);
        return _toUsd(netA, IERC20Metadata(address(m.tokenA)).decimals(), priceA)
            + _toUsd(netB, IERC20Metadata(address(m.tokenB)).decimals(), priceB);
    }
}
