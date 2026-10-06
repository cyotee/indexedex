// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance} from "./interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultRepo as Repo} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRepo.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultMoney as Money} from "./UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultCommon as Common} from "./UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultHarvest as Harvest} from "./UniswapV4UpperLowerWingsStandardExchangeVaultHarvest.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote as Quote} from "./UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultRebalancePlanner as Planner} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRebalancePlanner.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceTarget[]
/// @notice Permissionless maintenance with bounded search, core-liquidity progress and a proportional loss cap.
contract UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceTarget is IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance {
    using TransientStateLibrary for IPoolManager;
    struct Checkpoint { uint256 value; uint128 core; uint256 deficit; }

    function rebalance(uint256 minimumValueAfter_, uint256 deadline_) external returns (uint256 valueAfter_) {
        Money.begin(deadline_);
        Repo.Storage storage state = Repo._layout();
        if (state.manager.isUnlocked() || ERC20Repo._totalSupply() == 0) revert RebalanceUnavailable();
        Checkpoint memory beforeState = Checkpoint(
            Quote.quote(Common.quoteRequest()).value, state.positions[0].liquidity, _sleeveDeficit(Harvest.snapshot())
        );
        _reshape();
        valueAfter_ = _validate(beforeState, minimumValueAfter_);
        Money.end();
    }
    function _reshape() private {
        Harvest.Plan memory harvested = Harvest.harvest(Harvest.snapshot());
        if (harvested.count != 0) Common.execute(harvested.operations);
        _closeWings();
        if (_sleeveDeficit(Harvest.snapshot()) != 0) _close(0);
        Planner.Candidate memory candidate = Planner.bestSwap();
        if (candidate.input != 0) {
            Common.Operation[] memory operations = new Common.Operation[](1);
            operations[0] = Common.Operation(Common.Kind.Swap, 0, 0, 0, -int256(candidate.input), candidate.zeroForOne, candidate.priceLimit);
            Common.execute(operations);
        }
        Harvest.Plan memory placement = Harvest.placement(Harvest.snapshot());
        if (placement.count != 0) Common.execute(placement.operations);
    }
    function _validate(Checkpoint memory before_, uint256 minimum_) private returns (uint256 valueAfter_) {
        Repo.Storage storage state = Repo._layout();
        uint128 coreAfter = state.positions[0].liquidity;
        uint256 deficitAfter = _sleeveDeficit(Harvest.snapshot());
        uint256 progress = before_.deficit > deficitAfter ? before_.deficit - deficitAfter : 0;
        if (coreAfter > before_.core) progress += FullMath.mulDiv(before_.value, coreAfter - before_.core, coreAfter);
        if (progress == 0) revert NoRebalanceProgress();
        if (progress > before_.value) progress = before_.value;
        uint256 maximumLoss = progress / 100;
        valueAfter_ = Quote.quote(Common.quoteRequest()).value;
        if (valueAfter_ < before_.value && before_.value - valueAfter_ > maximumLoss) {
            revert RebalanceLossExceeded(before_.value, valueAfter_, maximumLoss);
        }
        if (valueAfter_ < minimum_) revert IStandardExchangeErrors.MinAmountNotMet(minimum_, valueAfter_);
        if ((state.target0 ? state.local0 : state.local1) == 0) {
            revert RebalanceLossExceeded(before_.value, valueAfter_, maximumLoss);
        }
        emit Rebalanced(before_.value, valueAfter_, before_.core, coreAfter);
    }
    function _sleeveDeficit(Harvest.Portfolio memory book_) private pure returns (uint256) {
        uint256 desired = Harvest.liquidFloor(book_);
        uint256 local = book_.target0 ? book_.local0 : book_.local1;
        return desired > local ? desired - local : 0;
    }
    function _closeWings() private { _close(1); _close(2); }
    function _close(uint8 slot_) private {
        Repo.Position storage position = Repo._layout().positions[slot_];
        if (position.liquidity == 0) return;
        Common.Operation[] memory operations = new Common.Operation[](1);
        operations[0] = Common.Operation(Common.Kind.Modify, slot_, position.lower, position.upper,
            -int256(uint256(position.liquidity)), false, 0);
        Common.execute(operations);
    }

}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceTarget[]
