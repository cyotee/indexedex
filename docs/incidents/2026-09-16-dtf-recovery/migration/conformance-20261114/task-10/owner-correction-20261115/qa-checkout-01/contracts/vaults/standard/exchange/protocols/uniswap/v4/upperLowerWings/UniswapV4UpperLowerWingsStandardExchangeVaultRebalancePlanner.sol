// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4UpperLowerWingsStandardExchangeVaultRepo as Repo} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRepo.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultHarvest as Harvest} from "./UniswapV4UpperLowerWingsStandardExchangeVaultHarvest.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote as Quote} from "./UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultRebalancePlanner[]
/// @notice Bounded balancing search, evaluated only after wing closures have settled.
library UniswapV4UpperLowerWingsStandardExchangeVaultRebalancePlanner {
    struct Candidate { uint256 input; uint256 output; uint160 priceLimit; bool zeroForOne; uint128 coreLiquidity; uint256 steps; }
    function bestSwap() public view returns (Candidate memory best_) {
        Repo.Storage storage state = Repo._layout();
        Harvest.Portfolio memory book = Harvest.snapshot();
        Harvest.Plan memory baseline = Harvest.placement(book);
        best_.coreLiquidity = baseline.portfolio.positions[0].liquidity;
        bool zeroForOne = baseline.portfolio.positions[1].liquidity != 0;
        if (!zeroForOne && baseline.portfolio.positions[2].liquidity == 0) return best_;
        uint256 floor = Harvest.liquidFloor(book);
        uint256 high = zeroForOne ? book.local0 : book.local1;
        if (zeroForOne == book.target0) high = high > floor ? high - floor : 0;
        if (high > uint256(uint128(type(int128).max))) high = uint256(uint128(type(int128).max));
        uint256 low;
        Quote.Request memory request;
        request.manager = state.manager; request.key = state.key;
        request.target0 = !zeroForOne;
        // count=0 deliberately quotes a real prospective swap through all presently active liquidity,
        // including the retained core; this is not the whole-vault value quote.
        uint256 usedSteps;
        for (uint256 i; i < 12 && low < high && usedSteps < 512; ++i) {
            uint256 amount = low + (high - low) / 2;
            if (amount == 0) break;
            request.local0 = zeroForOne ? amount : 0;
            request.local1 = zeroForOne ? 0 : amount;
            request.stepLimit = 512 - usedSteps;
            Quote.Result memory sale = Quote.quote(request);
            usedSteps += sale.steps;
            Harvest.Plan memory trial = _placementAfter(book, sale, zeroForOne);
            uint128 core = trial.portfolio.positions[0].liquidity;
            if (core > best_.coreLiquidity && sale.proceeds != 0) {
                best_ = Candidate(amount, sale.proceeds, sale.sqrtPriceX96, zeroForOne, core, usedSteps);
            }
            bool stillExcess = zeroForOne ? trial.portfolio.positions[1].liquidity != 0 : trial.portfolio.positions[2].liquidity != 0;
            if (stillExcess) low = amount + 1;
            else high = amount;
        }
        best_.steps = usedSteps;
    }
    function _placementAfter(Harvest.Portfolio memory book_, Quote.Result memory sale_, bool zeroForOne_)
        private view returns (Harvest.Plan memory)
    {
        Harvest.Portfolio memory trial = abi.decode(abi.encode(book_), (Harvest.Portfolio));
        if (zeroForOne_) { trial.local0 -= sale_.sold; trial.local1 += sale_.proceeds; }
        else { trial.local1 -= sale_.sold; trial.local0 += sale_.proceeds; }
        trial.price = sale_.sqrtPriceX96; trial.tick = sale_.tick;
        Repo.Storage storage state = Repo._layout();
        Harvest.loadCapacities(trial, state.manager, state.key.toId());
        return Harvest.placement(trial);
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultRebalancePlanner[]
