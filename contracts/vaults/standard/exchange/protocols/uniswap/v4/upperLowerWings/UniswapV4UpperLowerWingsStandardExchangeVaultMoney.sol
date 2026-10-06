// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@crane/contracts/utils/SafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault} from "./interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultRepo as Repo} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRepo.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultCommon as Common} from "./UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultInventory as Inventory} from "./UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultTypes as Types} from "./UniswapV4UpperLowerWingsStandardExchangeVaultTypes.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultHarvest as Harvest} from "./UniswapV4UpperLowerWingsStandardExchangeVaultHarvest.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultAccounting as Accounting} from "./UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote as Quote} from "./UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultMoney[]
/// @notice Target-only money orchestration. Pending caller credit is isolated before mandatory idle harvest.
library UniswapV4UpperLowerWingsStandardExchangeVaultMoney {
    using SafeERC20 for IERC20;
    using StateLibrary for IPoolManager;
    using TransientStateLibrary for IPoolManager;
    error VaultDisabled();
    error InvalidRecipient();
    error ZeroAmount();
    error HolderValueLoss(uint256 required, uint256 actual);
    error BackingDeficit(address token, uint256 booked, uint256 actual);

    function target() internal view returns (IERC20) {
        Repo.Storage storage state = Repo._layout();
        return IERC20(Currency.unwrap(state.target0 ? state.key.currency0 : state.key.currency1));
    }
    function begin(uint256 deadline_) internal {
        Repo.Storage storage state = Repo._layout();
        if (!state.initialized) revert IUniswapV4UpperLowerWingsStandardExchangeVault.NotInitialized();
        if (state.busy) revert IUniswapV4UpperLowerWingsStandardExchangeVault.ReentrantOperation();
        if (deadline_ < block.timestamp) revert IStandardExchangeErrors.DeadlineExceeded(deadline_, block.timestamp);
        state.busy = true; state.mutations = 0;
        _requireBacking();
    }
    function end() internal {
        _requireBacking();
        Repo.Storage storage state = Repo._layout();
        MultiAssetBasicVaultRepo._updateReserve(target(), state.target0 ? state.local0 : state.local1);
        state.busy = false;
    }
    function _requireBacking() private view {
        Repo.Storage storage state = Repo._layout();
        _requireBalance(IERC20(Currency.unwrap(state.key.currency0)), state.local0);
        _requireBalance(IERC20(Currency.unwrap(state.key.currency1)), state.local1);
    }
    function _requireBalance(IERC20 token_, uint256 booked_) private view {
        uint256 actual = token_.balanceOf(address(this));
        if (actual < booked_) revert BackingDeficit(address(token_), booked_, actual);
    }
    function _payTarget(address recipient_, uint256 amount_) private {
        IERC20 token = target();
        uint256 beforeBalance = token.balanceOf(recipient_);
        token.safeTransfer(recipient_, amount_);
        uint256 afterBalance = token.balanceOf(recipient_);
        uint256 received = afterBalance >= beforeBalance ? afterBalance - beforeBalance : 0;
        if (received != amount_) revert ISecurePullErrors.TransferDeltaInsufficient(amount_, received);
    }
    function _localTarget() private view returns (uint256) {
        Repo.Storage storage state = Repo._layout();
        return state.target0 ? state.local0 : state.local1;
    }
    function _changeTarget(uint256 amount_, bool add_) private {
        Repo.Storage storage state = Repo._layout();
        if (state.target0) state.local0 = add_ ? state.local0 + amount_ : state.local0 - amount_;
        else state.local1 = add_ ? state.local1 + amount_ : state.local1 - amount_;
    }
    function _pull(uint256 amount_, bool pushed_) private {
        IERC20 token = target();
        uint256 balance = token.balanceOf(address(this));
        if (pushed_) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
            uint256 available = LocalCreditLib.available(balance, _localTarget());
            if (available < amount_) revert ISecurePullErrors.TransferDeltaInsufficient(amount_, available);
        } else {
            token.safeTransferFrom(msg.sender, address(this), amount_);
            uint256 received = token.balanceOf(address(this)) - balance;
            if (received != amount_) revert ISecurePullErrors.TransferDeltaInsufficient(amount_, received);
        }
    }
    function _harvest() private {
        Repo.Storage storage state = Repo._layout();
        if (state.manager.isUnlocked()) return;
        Harvest.Plan memory plan = Harvest.harvest(Harvest.snapshot());
        if (plan.count != 0) Common.execute(plan.operations);
    }
    function _place() private {
        Repo.Storage storage state = Repo._layout();
        if (state.manager.isUnlocked()) return;
        Harvest.Plan memory plan = Harvest.placement(Harvest.snapshot());
        if (plan.count != 0) Common.execute(plan.operations);
    }
    function _bootstrapBacking(uint256 pending_) private {
        Repo.Storage storage state = Repo._layout();
        state.local0 = IERC20(Currency.unwrap(state.key.currency0)).balanceOf(address(this));
        state.local1 = IERC20(Currency.unwrap(state.key.currency1)).balanceOf(address(this));
        _changeTarget(pending_, false);
    }
    function deposit(uint256 assets_, uint256 minimum_, address recipient_, bool pushed_) public returns (uint256) {
        return _deposit(assets_, minimum_, recipient_, pushed_, 0, 0);
    }
    function depositExactShares(uint256 assets_, uint256 shares_, address recipient_, bool pushed_, uint256 refundReserve_)
        public returns (uint256)
    {
        return _deposit(assets_, shares_, recipient_, pushed_, shares_, refundReserve_);
    }
    function _deposit(uint256 assets_, uint256 minimum_, address recipient_, bool pushed_, uint256 exact_, uint256 refundReserve_)
        private returns (uint256 shares_)
    {
        Repo.Storage storage state = Repo._layout();
        if (!state.busy) revert IUniswapV4UpperLowerWingsStandardExchangeVault.ReentrantOperation();
        if (IVaultRegistryDisableQuery(state.registry).isDisabled(address(this))) revert VaultDisabled();
        if (recipient_ == address(0)) revert InvalidRecipient();
        if (assets_ == 0) revert ZeroAmount();
        _pull(assets_, pushed_);
        uint256 supply = ERC20Repo._totalSupply();
        if (supply == 0) _bootstrapBacking(assets_ + refundReserve_);
        _harvest();
        uint256 value = supply == 0 ? 0 : Quote.quote(Common.quoteRequest()).value;
        shares_ = Accounting.issue(supply, value, assets_);
        if (shares_ < minimum_) revert IStandardExchangeErrors.MinAmountNotMet(minimum_, shares_);
        if (exact_ != 0) shares_ = exact_;
        _changeTarget(assets_, true);
        ERC20Repo._mint(recipient_, shares_);
        _place();
        if (_localTarget() == 0) revert IUniswapV4UpperLowerWingsStandardExchangeVault.InsufficientLocalTarget(1, 0);
    }
    function redeem(uint256 shares_, uint256 minimum_, address recipient_, bool pushed_) public returns (uint256) {
        return _redeem(shares_, minimum_, recipient_, pushed_, 0);
    }
    function redeemExactAssets(uint256 shares_, uint256 assets_, address recipient_, bool pushed_) public returns (uint256) {
        return _redeem(shares_, assets_, recipient_, pushed_, assets_);
    }
    function _redeem(uint256 shares_, uint256 minimum_, address recipient_, bool pushed_, uint256 exact_)
        private returns (uint256 assets_)
    {
        Repo.Storage storage state = Repo._layout();
        if (!state.busy) revert IUniswapV4UpperLowerWingsStandardExchangeVault.ReentrantOperation();
        if (recipient_ == address(0) || recipient_ == address(this)) revert InvalidRecipient();
        if (shares_ == 0) revert ZeroAmount();
        if (pushed_) LocalCreditLib.requirePretransferCaller(msg.sender);
        address holder = pushed_ ? address(this) : msg.sender;
        uint256 balance = ERC20Repo._balanceOf(holder);
        if (balance < shares_) revert ISecurePullErrors.TransferDeltaInsufficient(shares_, balance);
        _harvest();
        uint256 supply = ERC20Repo._totalSupply();
        uint256 value = Quote.quote(Common.quoteRequest()).value;
        assets_ = Accounting.entitlement(supply, value, shares_);
        if (assets_ < minimum_) revert IStandardExchangeErrors.MinAmountNotMet(minimum_, assets_);
        if (exact_ != 0) assets_ = exact_;
        uint256 remaining = supply - shares_;
        uint256 required = assets_ + (remaining == 0 ? 0 : 1);
        uint256 costBound;
        if (state.manager.isUnlocked()) {
            if (_localTarget() < required) revert IUniswapV4UpperLowerWingsStandardExchangeVault.InsufficientLocalTarget(required, _localTarget());

        } else costBound = _fund(required, remaining == 0);
        ERC20Repo._burn(holder, shares_);
        _changeTarget(assets_, false);
        _payTarget(recipient_, assets_);
        if (remaining != 0) {
            uint256 afterValue = Quote.quote(Common.quoteRequest()).value;
            if (afterValue < value - assets_ && value - assets_ - afterValue > costBound)
                revert HolderValueLoss(value - assets_, afterValue);
            _place();
            if (_localTarget() == 0) revert IUniswapV4UpperLowerWingsStandardExchangeVault.InsufficientLocalTarget(1, 0);
        }
    }
    function _close(uint8 slot_) private {
        Repo.Position storage position = Repo._layout().positions[slot_];
        if (position.liquidity == 0) return;
        Common.Operation[] memory operations = new Common.Operation[](1);
        operations[0] = Common.Operation(Common.Kind.Modify, slot_, position.lower, position.upper,
            -int256(uint256(position.liquidity)), false, 0);
        Common.execute(operations);
    }
    function _fund(uint256 required_, bool terminal_) private returns (uint256 costBound_) {
        Repo.Storage storage state = Repo._layout();
        if (terminal_) { for (uint8 i; i < 3; ++i) _close(i); }
        if (_localTarget() >= required_) return costBound_;
        uint8 targetWing = state.target0 ? 1 : 2;
        uint8 opposingWing = state.target0 ? 2 : 1;
        if (_oneSided(targetWing, true)) _close(targetWing);
        if (_localTarget() >= required_) return costBound_;
        if (_oneSided(opposingWing, false)) {
            _close(opposingWing);
            costBound_ += _swapDeficit(required_);
        }
        if (_localTarget() >= required_) return costBound_;
        // Mixed wings precede core. Check cash after every removal before resorting to conversion.
        _close(targetWing);
        if (_localTarget() < required_) _close(opposingWing);
        if (_localTarget() < required_) _close(0);
        if (_localTarget() < required_) costBound_ += _swapDeficit(required_);
        if (_localTarget() < required_) revert IUniswapV4UpperLowerWingsStandardExchangeVault.InsufficientLocalTarget(required_, _localTarget());
    }
    function _oneSided(uint8 slot_, bool target_) private view returns (bool) {
        Repo.Storage storage state = Repo._layout();
        Repo.Position storage position = state.positions[slot_];
        if (position.liquidity == 0) return false;
        (uint160 price,,,) = state.manager.getSlot0(state.key.toId());
        Types.Principal memory principal = Inventory.principal(price, position.lower, position.upper, position.liquidity, false);
        bool token0 = target_ == state.target0;
        return token0 ? principal.amount0 != 0 && principal.amount1 == 0 : principal.amount1 != 0 && principal.amount0 == 0;
    }
    function _swapDeficit(uint256 required_) private returns (uint256 costBound_) {
        Repo.Storage storage state = Repo._layout();
        uint256 opposing = state.target0 ? state.local1 : state.local0;
        if (opposing == 0 || _localTarget() >= required_) return 0;
        // Exact input bounded by custody; partial output is checked by the funding caller.
        // Whole inventory overshoot is retained by the vault and must pass the remaining-value check.
        if (opposing > uint256(uint128(type(int128).max))) revert Quote.QuoteDeltaOverflow();
        (uint160 price,,,) = state.manager.getSlot0(state.key.toId());
        if (state.target0 ? price >= TickMath.MAX_SQRT_PRICE - 1 : price <= TickMath.MIN_SQRT_PRICE + 1) return 0;
        costBound_ = Quote.swapCost(Common.quoteRequest(), opposing);
        Common.Operation[] memory operations = new Common.Operation[](1);
        operations[0] = Common.Operation(Common.Kind.Swap, 0, 0, 0, -int256(opposing), !state.target0,
            state.target0 ? TickMath.MAX_SQRT_PRICE - 1 : TickMath.MIN_SQRT_PRICE + 1);
        Common.execute(operations);
    }
    function pretransferBudget(IERC20 token_, uint256 maximum_) internal view returns (uint256) {
        LocalCreditLib.requirePretransferCaller(msg.sender);
        uint256 booked = address(token_) == address(this) ? 0 : _localTarget();
        return LocalCreditLib.budget(LocalCreditLib.available(token_.balanceOf(address(this)), booked), maximum_);
    }
    function refund(IERC20 token_, uint256 amount_) internal {
        if (amount_ == 0) return;
        if (address(token_) == address(this)) ERC20Repo._transfer(address(this), msg.sender, amount_);
        else _payTarget(msg.sender, amount_);
    }
    function requiredInput(bool deposit_, uint256 amountOut_) public view returns (uint256) {
        Repo.Storage storage state = Repo._layout();
        if (!state.initialized) revert IUniswapV4UpperLowerWingsStandardExchangeVault.NotInitialized();
        if (state.busy) revert IUniswapV4UpperLowerWingsStandardExchangeVault.ReentrantOperation();
        if (amountOut_ == 0) revert ZeroAmount();
        uint256 supply = ERC20Repo._totalSupply();
        if (deposit_ && supply == 0) return amountOut_;
        uint256 value = _postHarvestValue();
        if (deposit_) return Accounting.inputForShares(supply, value, amountOut_);
        uint256 shares = Accounting.sharesForAssets(supply, value, amountOut_);
        if (state.manager.isUnlocked()) {
            uint256 required = amountOut_ + (shares < supply ? 1 : 0);
            if (_localTarget() < required) revert IUniswapV4UpperLowerWingsStandardExchangeVault.InsufficientLocalTarget(required, _localTarget());
        }
        return shares;
    }
    function _postHarvestValue() private view returns (uint256) {
        Harvest.Portfolio memory book = Harvest.snapshot();
        if (!Repo._layout().manager.isUnlocked()) book = Harvest.harvest(book).portfolio;
        (uint256 amount0, uint256 amount1) = Harvest.totalInventory(book);
        return Quote.quoteInventory(Common.quoteRequest(), amount0, amount1).value;
    }
    function preview(bool deposit_, uint256 amount_) public view returns (uint256) {
        Repo.Storage storage state = Repo._layout();
        if (!state.initialized) revert IUniswapV4UpperLowerWingsStandardExchangeVault.NotInitialized();
        if (state.busy) revert IUniswapV4UpperLowerWingsStandardExchangeVault.ReentrantOperation();
        uint256 supply = ERC20Repo._totalSupply();
        if (deposit_ && supply == 0) return Accounting.issue(0, 0, amount_);
        uint256 value = _postHarvestValue();
        if (deposit_) return Accounting.issue(supply, value, amount_);
        uint256 assets = Accounting.entitlement(supply, value, amount_);
        if (state.manager.isUnlocked()) {
            uint256 required = assets + (amount_ < supply ? 1 : 0);
            if (_localTarget() < required) revert IUniswapV4UpperLowerWingsStandardExchangeVault.InsufficientLocalTarget(required, _localTarget());
        }
        return assets;
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultMoney[]
