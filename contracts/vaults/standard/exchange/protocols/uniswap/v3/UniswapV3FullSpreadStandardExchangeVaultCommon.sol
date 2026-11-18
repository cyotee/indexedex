// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {SafeERC20} from "@crane/contracts/utils/SafeERC20.sol";
import {Address} from "@crane/contracts/utils/Address.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3MintCallback} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3MintCallback.sol";
import {IUniswapV3SwapCallback} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3SwapCallback.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {UniswapV3FullSpreadStandardExchangeVaultPoolAwareRepo as PoolRepo} from "./UniswapV3FullSpreadStandardExchangeVaultPoolAwareRepo.sol";
import {UniswapV3FullSpreadStandardExchangeVaultRepo as Repo} from "./UniswapV3FullSpreadStandardExchangeVaultRepo.sol";
import {UniswapV3FullSpreadStandardExchangeVaultPlanner as Planner} from "./UniswapV3FullSpreadStandardExchangeVaultPlanner.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as IVault} from "./interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";

/// @notice Bound-pool settlement with separately booked and operation-reserved custody.
abstract contract UniswapV3FullSpreadStandardExchangeVaultCommon is IUniswapV3MintCallback, IUniswapV3SwapCallback {
    using SafeERC20 for IERC20;

    error UniswapV3Exchange_CallbackNotAuthorized();
    error UniswapV3Exchange_BoundPoolInteractionBlocked();

    function _pool() internal view returns (IUniswapV3Pool) {
        return PoolRepo._uniswapV3Pool();
    }

    function _token0() internal view returns (address) {
        return _pool().token0();
    }

    function _token1() internal view returns (address) {
        return _pool().token1();
    }

    function canOpenBoundPoolOps() public view returns (bool) {
        (,,,,,, bool unlocked_) = _pool().slot0();
        return unlocked_;
    }

    function _requireCanOpenBoundPoolOps() internal view {
        if (!canOpenBoundPoolOps()) revert UniswapV3Exchange_BoundPoolInteractionBlocked();
    }

    function _requireNotDisabled() internal view {
        if (IVaultRegistryDisableQuery(address(StandardVaultRepo._feeOracle())).isDisabled(address(this))) {
            revert IVaultRegistryDisableQuery.VaultDisabled(address(this));
        }
    }

    function _deadline(uint256 deadline_) internal view {
        if (block.timestamp > deadline_) revert IStandardExchangeErrors.DeadlineExceeded(deadline_, block.timestamp);
    }

    function _recipient(address recipient_) internal view {
        if (recipient_ == address(0) || recipient_ == address(this)) revert IVault.InvalidRecipient();
    }

    function _requireShares(uint256 shares_) internal view {
        uint256 balance_ = ERC20Repo._balanceOf(msg.sender);
        if (shares_ > balance_) revert IERC20Errors.ERC20InsufficientBalance(msg.sender, balance_, shares_);
    }

    function _unbooked(address token_, uint256 index_) internal view returns (uint256) {
        Repo.Storage storage state_ = Repo._layout();
        return LocalCreditLib.available(
            IERC20(token_).balanceOf(address(this)), state_.booked[index_] + state_.reserved[index_]
        );
    }

    function _fund(address token_, uint256 amount_, uint256 index_, bool pretransferred_) internal {
        if (!pretransferred_ && amount_ != 0) {
            uint256 before_ = IERC20(token_).balanceOf(address(this));
            bytes memory result_ = Address.functionCall(
                token_, abi.encodeCall(IERC20.transferFrom, (msg.sender, address(this), amount_))
            );
            if (result_.length != 0 && !abi.decode(result_, (bool))) {
                revert SafeERC20.SafeERC20FailedOperation(token_);
            }
            uint256 received_ = IERC20(token_).balanceOf(address(this)) - before_;
            if (received_ != amount_) revert ISecurePullErrors.TransferDeltaInsufficient(amount_, received_);
        }
        Repo._layout().reserved[index_] += amount_;
    }

    function _pay(address token_, uint256 index_, address recipient_, uint256 amount_) internal {
        if (amount_ == 0) return;
        Repo._layout().reserved[index_] -= amount_;
        IERC20(token_).safeTransfer(recipient_, amount_);
    }

    function _close() internal view {
        Repo.Storage storage state_ = Repo._layout();
        if (state_.reserved[0] != 0 || state_.reserved[1] != 0
            || state_.callbackBudget[0] != 0 || state_.callbackBudget[1] != 0) {
            revert IVault.SettlementMismatch();
        }
    }

    function uniswapV3MintCallback(uint256 amount0Owed_, uint256 amount1Owed_, bytes calldata) external override {
        if (msg.sender != address(_pool())) revert UniswapV3Exchange_CallbackNotAuthorized();
        _callbackPay(_token0(), 0, amount0Owed_);
        _callbackPay(_token1(), 1, amount1Owed_);
    }

    function uniswapV3SwapCallback(int256 amount0Delta_, int256 amount1Delta_, bytes calldata) external override {
        if (msg.sender != address(_pool())) revert UniswapV3Exchange_CallbackNotAuthorized();
        if (amount0Delta_ > 0) _callbackPay(_token0(), 0, uint256(amount0Delta_));
        if (amount1Delta_ > 0) _callbackPay(_token1(), 1, uint256(amount1Delta_));
    }

    function _callbackPay(address token_, uint256 index_, uint256 amount_) private {
        if (amount_ == 0) return;
        Repo.Storage storage state_ = Repo._layout();
        if (amount_ > state_.callbackBudget[index_] || amount_ > state_.reserved[index_]) {
            revert IVault.SettlementMismatch();
        }
        state_.callbackBudget[index_] -= amount_;
        state_.reserved[index_] -= amount_;
        IERC20(token_).safeTransfer(msg.sender, amount_);
    }

    /// @dev Returns pool deltas, never a custody balance delta that could include unrelated transfers.
    function _swap(bool zeroForOne_, uint256 amount_) internal returns (uint256 spent_, uint256 received_) {
        if (amount_ == 0) return (0, 0);
        _requireCanOpenBoundPoolOps();
        Repo.Storage storage state_ = Repo._layout();
        uint256 inputIndex_ = zeroForOne_ ? 0 : 1;
        state_.callbackBudget[inputIndex_] = amount_;
        (int256 delta0_, int256 delta1_) = _pool().swap(
            address(this), zeroForOne_, int256(amount_),
            zeroForOne_ ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1, ""
        );
        spent_ = uint256(zeroForOne_ ? delta0_ : delta1_);
        received_ = uint256(-(zeroForOne_ ? delta1_ : delta0_));
        state_.callbackBudget[inputIndex_] = 0;
        state_.reserved[1 - inputIndex_] += received_;
    }

    function _collectFees() internal returns (uint256 fee0_, uint256 fee1_) {
        if (!Repo._isPositionCreated()) return (0, 0);
        _requireCanOpenBoundPoolOps();
        (int24 lower_, int24 upper_) = Repo._getPositionTicks();
        (uint128 liquidity_,,,,) = _pool().positions(Repo._getOwnPositionKey());
        if (liquidity_ != 0) _pool().burn(lower_, upper_, 0);
        (fee0_, fee1_) = _pool().collect(address(this), lower_, upper_, type(uint128).max, type(uint128).max);
        Repo._layout().booked[0] += fee0_;
        Repo._layout().booked[1] += fee1_;
    }

    function _add(Planner.Plan memory plan_) internal {
        if (plan_.swapIn != 0 || plan_.liquidityAdded != 0) _requireCanOpenBoundPoolOps();
        if (plan_.swapIn != 0) {
            (uint256 spent_, uint256 received_) = _swap(plan_.zeroForOne, plan_.swapIn);
            if (spent_ != plan_.swapSpent || received_ != plan_.swapOut) revert IVault.SettlementMismatch();
        }
        if (plan_.liquidityAdded == 0) return;
        // Entry-swap fees belong to incumbent liquidity and are collected before the add.
        _collectFees();
        int24 spacing_ = _pool().tickSpacing();
        Repo._createPositionIfNeeded(TickMath.minUsableTick(spacing_), TickMath.maxUsableTick(spacing_));
        (int24 lower_, int24 upper_) = Repo._getPositionTicks();
        Repo.Storage storage state_ = Repo._layout();
        state_.callbackBudget[0] = plan_.used0;
        state_.callbackBudget[1] = plan_.used1;
        (uint256 used0_, uint256 used1_) = _pool().mint(
            address(this), lower_, upper_, plan_.liquidityAdded, ""
        );
        if (used0_ != plan_.used0 || used1_ != plan_.used1) revert IVault.SettlementMismatch();
        state_.callbackBudget[0] = 0;
        state_.callbackBudget[1] = 0;
    }

    function _mintShares(Planner.Plan memory plan_, address recipient_) internal {
        if (plan_.mintFloor) Repo._writeGenesisFloor();
        if (plan_.feeShares != 0) ERC20Repo._mint(plan_.feeTo, plan_.feeShares);
        if (plan_.netShares != 0) ERC20Repo._mint(recipient_, plan_.netShares);
    }

    /// @dev Allocate only the exiting holder's pre-burn fee and booked claims.
    function _remove(Planner.Plan memory plan_) internal {
        _requireCanOpenBoundPoolOps();
        Repo.Storage storage state_ = Repo._layout();
        state_.booked[0] -= plan_.bookedClaim0;
        state_.booked[1] -= plan_.bookedClaim1;
        (int24 lower_, int24 upper_) = Repo._getPositionTicks();
        (uint256 principal0_, uint256 principal1_) = _pool().burn(lower_, upper_, plan_.liquidityRemoved);
        (uint256 collected0_, uint256 collected1_) =
            _pool().collect(address(this), lower_, upper_, type(uint128).max, type(uint128).max);
        if (collected0_ != principal0_ + plan_.feeClaim0 + plan_.feeRemainder0
            || collected1_ != principal1_ + plan_.feeClaim1 + plan_.feeRemainder1) {
            revert IVault.SettlementMismatch();
        }
        state_.booked[0] += plan_.feeRemainder0;
        state_.booked[1] += plan_.feeRemainder1;
        state_.reserved[0] = principal0_ + plan_.feeClaim0 + plan_.bookedClaim0;
        state_.reserved[1] = principal1_ + plan_.feeClaim1 + plan_.bookedClaim1;
        if (plan_.swapIn != 0) {
            (uint256 spent_, uint256 received_) = _swap(plan_.zeroForOne, plan_.swapIn);
            if (spent_ != plan_.swapIn || received_ != plan_.swapOut) {
                revert IStandardExchangeErrors.AmountOutNotMet(plan_.amountOut, 0);
            }
        }
        ERC20Repo._burn(msg.sender, plan_.sharesBurned);
    }
}
