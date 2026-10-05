// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "../../UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService as Quotes} from "../../UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner as Planner} from "../../UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath as Protection} from "../../UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath as Inventory} from "../../UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol";
import {StandardExchangeConstantProduct as ConstantProduct} from "../../../../../StandardExchangeConstantProduct.sol";

/// @notice Independent exhaustive classifier. It does not call the analytic planner.
library UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticReference {
    enum Status { Feasible, Infeasible, Unknown }

    uint256 internal constant MAX_EXHAUSTIVE = 4096;

    struct Result {
        Status status;
        uint256 witness;
    }

    function _classify(Types.Snapshot memory state_, Quotes.Params memory params_, uint256 credit_)
        internal view returns (Result memory result_)
    {
        if (credit_ > MAX_EXHAUSTIVE) {
            result_.status = Status.Unknown;
            return result_;
        }
        for (uint256 swapIn; swapIn <= credit_; ++swapIn) {
            if (_feasible(state_, params_, credit_, swapIn)) {
                result_.status = Status.Feasible;
                result_.witness = swapIn;
                return result_;
            }
        }
        result_.status = Status.Infeasible;
    }

    function _certifies(Types.Snapshot memory state_, Quotes.Params memory params_, uint256 credit_, uint256 swapIn_)
        internal view returns (bool)
    {
        return _feasible(state_, params_, credit_, swapIn_);
    }

    function _feasible(Types.Snapshot memory state_, Quotes.Params memory params_, uint256 credit_, uint256 swapIn_)
        private view returns (bool)
    {
        if (swapIn_ > credit_) return false;
        Quotes.Params memory params = params_;
        params.amount = swapIn_;
        params.position = state_.position;
        (Types.Swap memory swap, bool filled) = Quotes._tryForward(params);
        if (!filled || !Protection._priceWithin(state_.position.sqrtPriceX96, swap.sqrtPriceAfterX96, 50)) return false;
        return _after(state_, swap, params.zeroForOne, credit_);
    }

    function _after(Types.Snapshot memory state_, Types.Swap memory swap_, bool zeroForOne_, uint256 credit_)
        private view returns (bool)
    {
        Types.Snapshot memory state = abi.decode(abi.encode(state_), (Types.Snapshot));
        Planner._afterSwap(state, swap_);
        uint256 input = zeroForOne_ ? 0 : 1;
        uint256[2] memory contribution;
        contribution[input] = credit_ - swap_.amountIn;
        contribution[1 - input] = swap_.amountOut;
        return _placed(state, state_.book.supply, contribution);
    }

    function _placed(Types.Snapshot memory state_, uint256 supply_, uint256[2] memory contribution_)
        private pure returns (bool)
    {
        uint256[2] memory backing = Inventory._totals(state_.book);
        for (uint256 i; i < 2; ++i) state_.book.free[i] += contribution_[i];
        Types.Placement memory placement = Planner._safePlacement(state_);
        for (uint256 i; i < 2; ++i) {
            uint256 loss = placement.roundingLoss[i];
            if (placement.liquidityDelta > 0) {
                if (loss > contribution_[i]) return false;
                contribution_[i] -= loss;
            } else if (loss > backing[i]) return false;
            else backing[i] -= loss;
        }
        if ((backing[0] != 0 && contribution_[0] == 0) || (backing[1] != 0 && contribution_[1] == 0)) return false;
        uint256 shares = _shares(contribution_, supply_, backing);
        if (shares == 0) return false;
        return _aligned(shares, supply_, contribution_, backing);
    }

    function _aligned(uint256 shares_, uint256 supply_, uint256[2] memory contribution_, uint256[2] memory backing_)
        private pure returns (bool)
    {
        for (uint256 i; i < 2; ++i) {
            if (!Protection._aligned(shares_, backing_[i], supply_, contribution_[i])) return false;
        }
        return true;
    }

    function _shares(uint256[2] memory contribution_, uint256 supply_, uint256[2] memory backing_)
        private pure returns (uint256)
    {
        return ConstantProduct._sharesForDeposit(contribution_[0], contribution_[1], supply_, backing_[0], backing_[1]);
    }
}
