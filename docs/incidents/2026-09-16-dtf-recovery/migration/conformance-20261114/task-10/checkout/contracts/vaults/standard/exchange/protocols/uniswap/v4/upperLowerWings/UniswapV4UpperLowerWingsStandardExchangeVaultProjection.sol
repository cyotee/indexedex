// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault as Vault} from "./interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultRepo as Repo} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRepo.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultCommon as Common} from "./UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultHarvest as Harvest} from "./UniswapV4UpperLowerWingsStandardExchangeVaultHarvest.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultInventory as Inventory} from "./UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultTypes as Types} from "./UniswapV4UpperLowerWingsStandardExchangeVaultTypes.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultAccounting as Accounting} from "./UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote as Quote} from "./UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultMoney as Money} from "./UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol";

/// @notice Sequential portfolio projection against an unchanged live external-liquidity baseline.
/// @dev Snapshots are read-only calculations, never execution authorizations. Each operation resets its mutation budget.
library UniswapV4UpperLowerWingsStandardExchangeVaultProjection {
    using TransientStateLibrary for IPoolManager;
    struct State {
        address vault;
        uint256 version;
        bool blocked;
        uint256 shares;
        Harvest.Portfolio book;
        Quote.Request source;
        Harvest.Position[3] original;
        Quote.PoolState pool;
        bool cached;
        uint256 cachedOpposing;
        uint256 cachedProceeds;
        uint256 mutations;
        uint256 costBound;
    }
    function snapshot(address asset_, address holder_) public view returns (State memory q_) {
        Repo.Storage storage state = Repo._layout();
        if (!state.initialized) revert Vault.NotInitialized();
        if (state.busy) revert Vault.ReentrantOperation();
        if (asset_ != address(Money.target())) revert Transition.UnsupportedQuoteAsset(asset_);
        q_.vault = address(this); q_.version = 1;
        q_.blocked = state.manager.isUnlocked();
        q_.shares = ERC20Repo._balanceOf(holder_);
        q_.book = Harvest.snapshot();
        q_.source = Common.quoteRequest();
        q_.original = abi.decode(abi.encode(q_.book.positions), (Harvest.Position[3]));
        q_.pool = Quote.startingPool(q_.source);
        if (q_.book.supply == 0) {
            q_.book.local0 = IERC20(Currency.unwrap(state.key.currency0)).balanceOf(address(this));
            q_.book.local1 = IERC20(Currency.unwrap(state.key.currency1)).balanceOf(address(this));
        }
    }
    function decode(bytes memory encoded_) public view returns (State memory q_) {
        if (Repo._layout().busy) revert Vault.ReentrantOperation();
        q_ = abi.decode(encoded_, (State));
        Repo.Storage storage state = Repo._layout();
        if (q_.vault != address(this) || q_.version != 1 || q_.shares > q_.book.supply
            || address(q_.source.manager) != address(state.manager) || q_.source.owner != address(this)
            || keccak256(abi.encode(q_.source.key)) != keccak256(abi.encode(state.key))
            || q_.book.target0 != state.target0 || q_.source.target0 != state.target0
            || q_.book.spacing != state.key.tickSpacing || q_.book.price != q_.pool.price
            || q_.book.tick != q_.pool.tick || q_.source.count > 3
            || q_.pool.price < TickMath.MIN_SQRT_PRICE || q_.pool.price >= TickMath.MAX_SQRT_PRICE)
            revert Transition.InvalidQuoteState();
    }
    function value(State memory q_) public view returns (uint256 value_) {
        (uint256 amount0, uint256 amount1) = Harvest.totalInventory(q_.book);
        uint256 opposing = q_.book.target0 ? amount1 : amount0;
        uint256 target = q_.book.target0 ? amount0 : amount1;
        if (q_.cached && q_.cachedOpposing == opposing) return target + q_.cachedProceeds;
        Quote.Result memory result = Quote.quoteInventoryAt(q_.source, q_.pool, amount0, amount1);
        q_.cached = true; q_.cachedOpposing = opposing; q_.cachedProceeds = result.proceeds;
        return result.value;
    }
    function assets(State memory q_, uint256 shares_) public view returns (uint256) {
        return q_.book.supply == 0 ? shares_ : FullMath.mulDiv(shares_, value(q_), q_.book.supply);
    }
    function prepared(State memory q_) public pure returns (State memory) {
        q_.mutations = 0; q_.costBound = 0;
        if (!q_.blocked) _apply(q_, Harvest.harvest(q_.book));
        return q_;
    }
    function transition(State memory q_, Transition.Operation operation_, uint256 amount_)
        public view returns (State memory, uint256 amountIn_, uint256 amountOut_)
    {
        if (operation_ == Transition.Operation.ReceiveShares) {
            q_.shares += amount_;
            if (q_.shares > q_.book.supply) revert Transition.InsufficientQuoteShares(q_.shares, q_.book.supply);
            return (q_, amount_, amount_);
        }
        if (amount_ == 0) revert Money.ZeroAmount();
        q_ = prepared(q_);
        uint256 beforeValue = value(q_);
        if (operation_ == Transition.Operation.DepositExactIn) {
            if (IVaultRegistryDisableQuery(Repo._layout().registry).isDisabled(address(this))) revert Money.VaultDisabled();
            amountIn_ = amount_;
            amountOut_ = Accounting.issue(q_.book.supply, beforeValue, amount_);
            _target(q_, amount_, true);
            q_.book.supply += amountOut_; q_.shares += amountOut_;
            if (!q_.blocked) _apply(q_, Harvest.placement(q_.book));
            _cover(q_, 1);
        } else {
            amountIn_ = operation_ == Transition.Operation.WithdrawExactOut
                ? Accounting.sharesForAssets(q_.book.supply, beforeValue, amount_) : amount_;
            if (amountIn_ > q_.shares) revert Transition.InsufficientQuoteShares(amountIn_, q_.shares);
            amountOut_ = Accounting.entitlement(q_.book.supply, beforeValue, amountIn_);
            if (operation_ == Transition.Operation.WithdrawExactOut) amountOut_ = amount_;
            uint256 remaining = q_.book.supply - amountIn_;
            uint256 required = amountOut_ + (remaining == 0 ? 0 : 1);
            if (!q_.blocked) _fund(q_, required, remaining == 0);
            _cover(q_, required);
            q_.book.supply = remaining; q_.shares -= amountIn_;
            _target(q_, amountOut_, false);
            if (remaining != 0) {
                uint256 afterValue = value(q_);
                if (afterValue < beforeValue - amountOut_ && beforeValue - amountOut_ - afterValue > q_.costBound)
                    revert Money.HolderValueLoss(beforeValue - amountOut_, afterValue);
                if (!q_.blocked) _apply(q_, Harvest.placement(q_.book));
                _cover(q_, 1);
            }
        }
        return (q_, amountIn_, amountOut_);
    }
    function _apply(State memory q_, Harvest.Plan memory plan_) private pure {
        q_.book = plan_.portfolio;
        q_.mutations += plan_.count;
        if (q_.mutations > 16) revert Transition.InvalidQuoteState();
    }
    function _local(State memory q_) private pure returns (uint256) { return q_.book.target0 ? q_.book.local0 : q_.book.local1; }
    function _target(State memory q_, uint256 amount_, bool add_) private pure {
        if (q_.book.target0) q_.book.local0 = add_ ? q_.book.local0 + amount_ : q_.book.local0 - amount_;
        else q_.book.local1 = add_ ? q_.book.local1 + amount_ : q_.book.local1 - amount_;
    }
    function _cover(State memory q_, uint256 required_) private pure {
        uint256 available = _local(q_);
        if (available < required_) revert Vault.InsufficientLocalTarget(required_, available);
    }
    function _close(State memory q_, uint8 slot_) private pure {
        Harvest.Plan memory plan;
        plan.portfolio = q_.book;
        plan.operations = new Common.Operation[](1);
        Harvest.close(plan, slot_);
        _apply(q_, plan);
    }
    function _oneSided(State memory q_, uint8 slot_, bool target_) private pure returns (bool) {
        Harvest.Position memory position = q_.book.positions[slot_];
        if (position.liquidity == 0) return false;
        Types.Principal memory principal = Inventory.principal(q_.book.price, position.lower, position.upper, position.liquidity, false);
        return target_ == q_.book.target0 ? principal.amount0 != 0 && principal.amount1 == 0
            : principal.amount1 != 0 && principal.amount0 == 0;
    }
    function _fund(State memory q_, uint256 required_, bool terminal_) private view {
        if (terminal_) for (uint8 i; i < 3; ++i) _close(q_, i);
        if (_local(q_) >= required_) return;
        uint8 targetWing = q_.book.target0 ? 1 : 2;
        uint8 opposingWing = q_.book.target0 ? 2 : 1;
        if (_oneSided(q_, targetWing, true)) _close(q_, targetWing);
        if (_local(q_) >= required_) return;
        if (_oneSided(q_, opposingWing, false)) { _close(q_, opposingWing); _swap(q_, required_); }
        if (_local(q_) >= required_) return;
        _close(q_, targetWing);
        if (_local(q_) < required_) _close(q_, opposingWing);
        if (_local(q_) < required_) _close(q_, 0);
        if (_local(q_) < required_) _swap(q_, required_);
    }
    function _swap(State memory q_, uint256 required_) private view {
        uint256 opposing = q_.book.target0 ? q_.book.local1 : q_.book.local0;
        if (opposing == 0 || _local(q_) >= required_) return;
        if (q_.book.target0 ? q_.pool.price >= TickMath.MAX_SQRT_PRICE - 1 : q_.pool.price <= TickMath.MIN_SQRT_PRICE + 1) return;
        Quote.HeldPosition[3] memory held;
        for (uint256 i; i < 3; ++i) {
            Harvest.Position memory position = q_.book.positions[i];
            held[i] = Quote.HeldPosition(position.lower, position.upper, position.liquidity, position.growth0, position.growth1);
        }
        Quote.SwapProjection memory swap = Quote.projectSwap(q_.source, q_.pool, held, !q_.book.target0, opposing);
        if (q_.book.target0) q_.book.local1 -= swap.sale.sold;
        else q_.book.local0 -= swap.sale.sold;
        _target(q_, swap.sale.proceeds, true);
        q_.pool = swap.pool; q_.book.price = swap.pool.price; q_.book.tick = swap.pool.tick;
        q_.cached = false; q_.costBound += swap.sale.executionCostBound;
        for (uint256 i; i < 3; ++i) {
            Harvest.Position memory position = q_.book.positions[i];
            position.growth0 = swap.positions[i].growth0; position.growth1 = swap.positions[i].growth1;
            position.fee0 = Inventory.earnedFee(position.liquidity, position.growth0, 0);
            position.fee1 = Inventory.earnedFee(position.liquidity, position.growth1, 0);
        }
        if (++q_.mutations > 16) revert Transition.InvalidQuoteState();
        _capacities(q_);
    }
    function _capacities(State memory q_) private view {
        Harvest.loadCapacities(q_.book, q_.source.manager, q_.source.key.toId());
        for (uint256 i; i < q_.book.capacityCount; ++i) {
            Harvest.Capacity memory capacity = q_.book.capacities[i];
            for (uint256 j; j < 3; ++j) {
                Harvest.Position memory original = q_.original[j];
                Harvest.Position memory current = q_.book.positions[j];
                if (capacity.tick == original.lower || capacity.tick == original.upper) capacity.gross -= original.liquidity;
                if (capacity.tick == current.lower || capacity.tick == current.upper) capacity.gross += current.liquidity;
            }
        }
    }
}
