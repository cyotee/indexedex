// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";
import {StandardExchangeConstantProduct as ConstantProduct} from "../../../StandardExchangeConstantProduct.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath as Protection} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath as Inventory} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService as Quotes} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";

// tag::UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner[]
/// @notice Read-only Hookless planning. The caller must execute and reconcile the selected action list.
library UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner {
    error AlignmentNotAchievable();
    error AccountingMismatch();

    uint16 internal constant REBALANCE_IMPACT_BPS = 25;
    uint16 internal constant COMPOSITION_IMPACT_BPS = 50;
    uint16 internal constant EXECUTION_SHORTFALL_BPS = 10;
    uint16 internal constant DEPOSIT_ALIGNMENT_BPS = 1;
    uint16 internal constant REPAIR_COMPOSITION_BPS = 1;
    uint32 internal constant MAX_REFINEMENTS = 32;

    struct RepairProgress {
        Types.Progress baseline;
        Types.Progress best;
    }

    struct RepairTrial {
        Types.Plan plan;
        Types.Progress progress;
        int256 sign;
    }

    function _directOut(Types.Snapshot memory state_, Quotes.Params memory params_, address tokenIn_, address tokenOut_)
        public view returns (Types.Plan memory plan_)
    {
        if (!state_.idle) revert IStandardExchangeErrors.InvalidRoute(tokenIn_, tokenOut_);
        Inventory._collect(state_.book);
        plan_.workflow = Types.Workflow.DirectExactOutput;
        plan_.swap = Quotes._exactOutput(params_);
        _afterSwap(state_, plan_.swap);
        plan_.placement = _closedPlacement(state_);
        if (!plan_.placement.certified) revert IStandardExchangeErrors.InvalidRoute(tokenIn_, tokenOut_);
        plan_.valid = true;
    }

    function _closedPlacement(Types.Snapshot memory state_) public pure returns (Types.Placement memory best_) {
        uint128 current = state_.position.liquidity;
        (bool representable, uint128 target) = Inventory._tryTargetLiquidity(state_);
        if (!representable) {
            if (Inventory._passes(state_)) return Inventory._placement(state_, current);
            return best_;
        }
        best_ = Inventory._placement(state_, target);
        if (!best_.certified) best_.funded = false;
        if (target > current) {
            Types.Placement memory lower = Inventory._placement(state_, target - 1);
            if (lower.certified && (!best_.certified || lower.afterState.position.liquidity > best_.afterState.position.liquidity)) {
                best_ = lower;
            }
        }
        if (Inventory._passes(state_) && (!best_.certified || current > best_.afterState.position.liquidity)) {
            best_ = Inventory._placement(state_, current);
        }
    }

    function _safePlacement(Types.Snapshot memory state_) public pure returns (Types.Placement memory best_) {
        return Inventory._safePlacement(state_);
    }

    function _composition(Types.Snapshot memory state_, Quotes.Params memory params_, uint256 credit_)
        public view returns (Types.Plan memory best_)
    {
        if (!state_.idle || state_.book.supply == 0 || credit_ == 0) revert AlignmentNotAchievable();
        // State free balances exclude caller credit. Collection is modeled exactly once.
        state_ = abi.decode(abi.encode(state_), (Types.Snapshot));
        Inventory._collect(state_.book);
        (Types.Plan memory candidate,) = _compositionCandidate(state_, params_, credit_, 0);
        best_ = candidate;
        (candidate,) = _compositionCandidate(state_, params_, credit_, credit_);
        best_ = _betterComposition(best_, candidate);
        uint256 low;
        uint256 high = credit_;
        uint32 evaluations = 2;
        uint32 refinements;
        for (uint32 i; i <= MAX_REFINEMENTS && high > low; ++i) {
            uint256 mid = low + (high - low) / 2;
            int256 sign;
            (candidate, sign) = _compositionCandidate(state_, params_, credit_, mid);
            ++evaluations;
            best_ = _betterComposition(best_, candidate);
            if (i != 0) ++refinements;
            if (sign > 0) low = mid + 1;
            else high = mid;
            // The relative protection is the convergence criterion. The work
            // limit is a ceiling, not a requirement to spend all 32 refinements.
            if (best_.valid) break;
        }
        (candidate,) = _compositionCandidate(state_, params_, credit_, low);
        best_ = _betterComposition(best_, candidate);
        (candidate,) = _compositionCandidate(state_, params_, credit_, high);
        best_ = _betterComposition(best_, candidate);
        if (!best_.valid) revert AlignmentNotAchievable();
        best_.refinements = refinements;
        best_.evaluations = evaluations + 2;
    }

    function _compositionCandidate(Types.Snapshot memory original_, Quotes.Params memory params_, uint256 credit_, uint256 swapIn_)
        private view returns (Types.Plan memory plan_, int256 sign_)
    {
        plan_.workflow = Types.Workflow.Composition;
        Types.Snapshot memory state = abi.decode(abi.encode(original_), (Types.Snapshot));
        params_.position = state.position;
        params_.amount = swapIn_;
        bool filled;
        (plan_.swap, filled) = Quotes._tryForward(params_);
        // An incomplete simulation is never booked or accepted as a fill.
        if (!filled) return (plan_, -1);
        _afterSwap(state, plan_.swap);
        uint256 input = params_.zeroForOne ? 0 : 1;
        uint256 output = 1 - input;
        plan_.contribution[input] = credit_ - plan_.swap.amountIn;
        plan_.contribution[output] = plan_.swap.amountOut;
        uint256[2] memory backing = Inventory._totals(state.book);
        sign_ = Protection._compare(
            Protection._product(plan_.contribution[input], backing[output], 1),
            Protection._product(plan_.contribution[output], backing[input], 1)
        );
        if (!Protection._priceWithin(original_.position.sqrtPriceX96, state.position.sqrtPriceX96, COMPOSITION_IMPACT_BPS)) return (plan_, sign_);
        if (!Protection._canAlignAfterPlacement(backing, plan_.contribution)) return (plan_, sign_);
        for (uint256 i; i < 2; ++i) state.book.free[i] += plan_.contribution[i];
        plan_.placement = _safePlacement(state);
        for (uint256 i; i < 2; ++i) {
            uint256 loss = plan_.placement.roundingLoss[i];
            if (plan_.placement.liquidityDelta > 0) {
                if (loss > plan_.contribution[i]) return (plan_, sign_);
                plan_.contribution[i] -= loss;
            } else {
                if (loss > backing[i]) return (plan_, sign_);
                backing[i] -= loss;
            }
        }
        // Zero contribution on a positive incumbent leg must not enter CP's blocked branch.
        if ((backing[0] != 0 && plan_.contribution[0] == 0) || (backing[1] != 0 && plan_.contribution[1] == 0)) return (plan_, sign_);
        if ((backing[0] == 0 && plan_.contribution[0] != 0) || (backing[1] == 0 && plan_.contribution[1] != 0)) return (plan_, sign_);
        plan_.shares = ConstantProduct._sharesForDeposit(
            plan_.contribution[0], plan_.contribution[1], original_.book.supply, backing[0], backing[1]
        );
        for (uint256 i; i < 2; ++i) {
            if (!Protection._aligned(plan_.shares, backing[i], original_.book.supply, plan_.contribution[i])) return (plan_, sign_);
        }
        plan_.valid = plan_.shares != 0;
        plan_.placement.afterState.book.supply += plan_.shares;
    }

    function _afterSwap(Types.Snapshot memory state_, Types.Swap memory swap_) internal pure {
        state_.position.sqrtPriceX96 = swap_.sqrtPriceAfterX96;
        state_.position.tick = swap_.tickAfter;
        state_.position.activeLiquidity = swap_.liquidityAfter;
        state_.book.deployed = Inventory._amounts(state_.position, state_.position.liquidity, false);
        uint256 input = swap_.zeroForOne ? 0 : 1;
        state_.book.earned[input] += Math.mulDiv(swap_.feeGrowthInsideX128, state_.position.liquidity, uint256(1) << 128);
        Inventory._collect(state_.book);
    }

    function _maintenance(Types.Snapshot memory original_, Quotes.Params memory params_)
        public view returns (Types.Plan memory best_)
    {
        Types.Snapshot memory state = abi.decode(abi.encode(original_), (Types.Snapshot));
        Inventory._collect(state.book);
        best_.workflow = Types.Workflow.Maintenance;
        best_.placement = _safePlacement(state);
        best_.valid = true;
        best_.maintenance = best_.placement.liquidityDelta == 0 ? Types.MaintenanceStatus.Unchanged : Types.MaintenanceStatus.Placed;
        if (best_.placement.certified) return best_;
        RepairProgress memory progress;
        progress.baseline = Inventory._progress(best_.placement.afterState);
        progress.best = progress.baseline;
        for (uint256 direction; direction < 2; ++direction) {
            params_.zeroForOne = direction == 0;
            // Compare local-funded and fully released funding domains. Each candidate
            // accounts for removal loss and quotes at its own post-removal liquidity.
            for (uint256 funding; funding < 2; ++funding) {
                if (funding == 1 && state.position.liquidity == 0) continue;
                Types.Placement memory removal = Inventory._placement(state, funding == 0 ? state.position.liquidity : 0);
                if (!removal.funded) continue;
                uint256 high = removal.afterState.book.free[direction];
                uint256 low;
                // Split the per-direction refinement budget between the two funding domains.
                for (uint32 probe; probe < MAX_REFINEMENTS / 2 && low < high; ++probe) {
                    uint256 amount = probe == 0 ? high : low + (high - low) / 2;
                    RepairTrial memory candidate = _repairCandidate(removal, original_.position.sqrtPriceX96, params_, amount);
                    ++best_.evaluations;
                    if (probe != 0) ++best_.refinements;
                    if (_improvesRepair(candidate, best_, progress)) {
                        best_ = _withWork(best_, candidate.plan);
                    }
                    if (candidate.sign > 0) low = amount + 1;
                    else high = amount == 0 ? 0 : amount - 1;
                    if (candidate.plan.valid && candidate.plan.placement.certified) break;
                }
                for (uint256 endpointIndex; endpointIndex < 2; ++endpointIndex) {
                    RepairTrial memory endpoint = _repairCandidate(removal, original_.position.sqrtPriceX96, params_, endpointIndex == 0 ? low : high);
                    ++best_.evaluations;
                    if (_improvesRepair(endpoint, best_, progress)) {
                        best_ = _withWork(best_, endpoint.plan);
                    }
                }
            }
        }
        if (best_.swap.amountIn == 0 && !best_.placement.certified) best_.maintenance = Types.MaintenanceStatus.Deferred;
    }

    function _repairCandidate(Types.Placement memory removal_, uint160 startPrice_, Quotes.Params memory params_, uint256 amount_)
        private view returns (RepairTrial memory trial_)
    {
        Types.Plan memory plan_ = trial_.plan;
        trial_.sign = -1;
        Types.Snapshot memory state = abi.decode(abi.encode(removal_.afterState), (Types.Snapshot));
        plan_.workflow = Types.Workflow.Maintenance;
        plan_.fundingRemoval = removal_;
        uint256 input = params_.zeroForOne ? 0 : 1;
        if (amount_ > state.book.free[input]) return trial_;
        params_.position = state.position;
        params_.amount = amount_;
        bool filled;
        (plan_.swap, filled) = Quotes._tryForward(params_);
        if (!filled || !Protection._priceWithin(startPrice_, plan_.swap.sqrtPriceAfterX96, REBALANCE_IMPACT_BPS)) return trial_;
        state.book.free[input] -= plan_.swap.amountIn;
        state.book.free[1 - input] += plan_.swap.amountOut;
        _afterSwap(state, plan_.swap);
        (plan_.placement, trial_.progress, trial_.sign) = Inventory._safePlacementWithProgress(state);
        if (!params_.zeroForOne) trial_.sign = -trial_.sign;
        plan_.valid = true;
        plan_.maintenance = Types.MaintenanceStatus.Improved;
    }

    function _improvesRepair(RepairTrial memory trial_, Types.Plan memory best_, RepairProgress memory progress_)
        private pure returns (bool)
    {
        Types.Plan memory candidate_ = trial_.plan;
        if (!candidate_.valid) return false;
        Types.Progress memory candidateProgress = trial_.progress;
        int256 comparison = Inventory._compareMetrics(candidateProgress, progress_.best);
        if (comparison > 0) return false;
        if (comparison == 0) {
            if (candidate_.swap.amountIn > best_.swap.amountIn) return false;
            if (candidate_.swap.amountIn == best_.swap.amountIn && _liquidityTurnover(candidate_) >= _liquidityTurnover(best_)) return false;
        }
        // Strict progress versus an already improving incumbent is transitively
        // better than the placement-only baseline, including equal-progress ties.
        if (best_.maintenance != Types.MaintenanceStatus.Improved
            && Inventory._compareMetrics(candidateProgress, progress_.baseline) >= 0) return false;
        progress_.best = candidateProgress;
        return true;
    }

    function _withWork(Types.Plan memory previous_, Types.Plan memory selected_) private pure returns (Types.Plan memory) {
        selected_.evaluations = previous_.evaluations;
        selected_.refinements = previous_.refinements;
        return selected_;
    }

    function _liquidityTurnover(Types.Plan memory plan_) private pure returns (uint256) {
        int256 removal = plan_.fundingRemoval.liquidityDelta;
        int256 placement = plan_.placement.liquidityDelta;
        return uint256(removal < 0 ? -removal : removal) + uint256(placement < 0 ? -placement : placement);
    }

    function _betterComposition(Types.Plan memory best_, Types.Plan memory candidate_)
        private pure returns (Types.Plan memory)
    {
        if (candidate_.valid && (!best_.valid || candidate_.shares > best_.shares
            || (candidate_.shares == best_.shares && candidate_.swap.amountIn < best_.swap.amountIn))) return candidate_;
        return best_;
    }
}
// end::UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner[]
