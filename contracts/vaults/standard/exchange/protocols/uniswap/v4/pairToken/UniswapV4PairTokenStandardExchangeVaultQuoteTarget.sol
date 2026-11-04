// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {NativeStandardYieldQuoteBase} from "contracts/vaults/standard/sy/NativeStandardYieldQuoteBase.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from "./interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";
import {UniswapV4PairTokenStandardExchangeVaultRepo as Repo} from "./UniswapV4PairTokenStandardExchangeVaultRepo.sol";
import {UniswapV4PairTokenStandardExchangeVaultTypes as Types} from "./UniswapV4PairTokenStandardExchangeVaultTypes.sol";
import {UniswapV4PairTokenStandardExchangeVaultProjection as Projection} from "./UniswapV4PairTokenStandardExchangeVaultProjection.sol";
import {UniswapV4PairTokenStandardExchangeVaultPlanner as Planner} from "./UniswapV4PairTokenStandardExchangeVaultPlanner.sol";

/// @notice Internal quote seams shared without inheriting another facet's external methods.
abstract contract UniswapV4PairTokenStandardExchangeVaultQuoteBase is NativeStandardYieldQuoteBase {
    function _plan(Types.Operation memory operation_) internal view returns (Types.Plan memory) {
        Repo.Storage storage state_ = Repo._layoutStruct();
        Repo._requireIdle(state_);
        return Planner.plan(
            Projection.loadSnapshot(state_.config, state_.inventory, ERC20Repo._totalSupply(), address(this)),
            operation_
        );
    }

    function _isCurrency(Types.Config memory config_, address token_) internal pure returns (bool) {
        address token0_ = Currency.unwrap(config_.poolKey.currency0);
        return token_ == token0_ || token_ == Currency.unwrap(config_.poolKey.currency1)
            || (token0_ == address(0) && token_ == config_.wrappedNative);
    }

    function _isToken0(Types.Config memory config_, address token_) internal pure returns (bool) {
        address token0_ = Currency.unwrap(config_.poolKey.currency0);
        return token_ == token0_ || (token0_ == address(0) && token_ == config_.wrappedNative);
    }

    function _zapOperation(address token_, uint256 amount_) internal view returns (Types.Operation memory operation_) {
        Types.Config memory config_ = Repo._layoutStruct().config;
        if (!_isCurrency(config_, token_)) {
            revert IStandardExchangeErrors.InvalidRoute(token_, address(this));
        }
        operation_.kind = Types.OperationKind.DepositZap;
        operation_.token = token_;
        if (_isToken0(config_, token_)) operation_.amounts.amount0 = amount_;
        else operation_.amounts.amount1 = amount_;
    }

    function _previewRoute(address in_, uint256 amount_, address out_, bool native_)
        internal view returns (uint256)
    {
        Repo._requireIdle();
        if (!native_ && (in_ == address(0) || out_ == address(0))) {
            revert IStandardExchangeErrors.InvalidRoute(in_, out_);
        }
        if (out_ == address(this) && in_ != address(this)) {
            return _plan(_zapOperation(in_, amount_)).shares;
        }
        Types.Config memory config_ = Repo._layoutStruct().config;
        if (in_ != address(this) || !_isCurrency(config_, out_)) {
            revert IStandardExchangeErrors.InvalidRoute(in_, out_);
        }
        Types.Operation memory operation_;
        operation_.kind = Types.OperationKind.RedeemSingle;
        operation_.shares = amount_;
        operation_.token = out_;
        Types.Plan memory plan_ = _plan(operation_);
        return _isToken0(config_, out_) ? plan_.payout.amount0 : plan_.payout.amount1;
    }

    function _previewExchangeIn(IERC20 in_, uint256 amount_, IERC20 out_)
        internal view override returns (uint256)
    {
        return _previewRoute(address(in_), amount_, address(out_), true);
    }
}

// tag::UniswapV4PairTokenStandardExchangeVaultQuoteTarget[]
/// @notice Exact economic previews; allowances, receiver acceptance and deadlines remain execution checks.
contract UniswapV4PairTokenStandardExchangeVaultQuoteTarget is UniswapV4PairTokenStandardExchangeVaultQuoteBase {
    // tag::previewExchangeIn-89d61912[]
    /// @notice Canonical non-native SE face quote.
    /// @custom:signature previewExchangeIn(address,uint256,address)
    /// @custom:selector 0x89d61912
function previewExchangeIn(IERC20 in_, uint256 amount_, IERC20 out_) external view returns (uint256 amountOut, uint256 amountRefunded) {
        return (_previewRoute(address(in_), amount_, address(out_), false), 0);
    }
    // end::previewExchangeIn-89d61912[]

    // tag::previewDepositPair-fa5f0790[]
    /// @notice Final credited shares and accepted portions of both maxima.
    /// @custom:signature previewDepositPair(uint256,uint256)
    /// @custom:selector 0xfa5f0790
    function previewDepositPair(uint256 max0_, uint256 max1_)
        external view returns (uint256 shares, uint256 used0, uint256 used1)
    {
        Repo._requireIdle();
        Types.Operation memory operation_;
        operation_.kind = Types.OperationKind.DepositPair;
        operation_.amounts = Types.Amounts(max0_, max1_);
        Types.Plan memory plan_ = _plan(operation_);
        return (plan_.shares, plan_.accepted.amount0, plan_.accepted.amount1);
    }
    // end::previewDepositPair-fa5f0790[]

    // tag::previewRedeemPair-2d8c09d6[]
    /// @notice Exact paired withdrawal after selected maintenance.
    /// @custom:signature previewRedeemPair(uint256)
    /// @custom:selector 0x2d8c09d6
    function previewRedeemPair(uint256 shares_) external view returns (uint256 amount0, uint256 amount1) {
        Repo._requireIdle();
        Types.Operation memory operation_;
        operation_.kind = Types.OperationKind.RedeemPair;
        operation_.shares = shares_;
        Types.Plan memory plan_ = _plan(operation_);
        return (plan_.payout.amount0, plan_.payout.amount1);
    }
    // end::previewRedeemPair-2d8c09d6[]

    // tag::previewWithdrawalMode-e378544f[]
    /// @notice Return mode only for a valid complete paired or single-token plan.
    /// @custom:signature previewWithdrawalMode(uint256,bool,address)
    /// @custom:selector 0xe378544f
    function previewWithdrawalMode(uint256 shares_, bool paired_, address out_)
        external view returns (IVault.WithdrawalMode, IVault.MaintenanceReason)
    {
        Repo._requireIdle();
        if (paired_ ? out_ != address(0) : !_isCurrency(Repo._layoutStruct().config, out_)) {
            revert IStandardExchangeErrors.InvalidRoute(address(this), out_);
        }
        Types.Operation memory operation_;
        operation_.kind = paired_ ? Types.OperationKind.RedeemPair : Types.OperationKind.RedeemSingle;
        operation_.shares = shares_;
        operation_.token = out_;
        Types.Plan memory plan_ = _plan(operation_);
        return (plan_.mode, plan_.reason);
    }
    // end::previewWithdrawalMode-e378544f[]

    // tag::previewZapCredit-73cd027d[]
    /// @notice Post-swap caller growth credit and uncredited residual donation.
    /// @custom:signature previewZapCredit(address,uint256)
    /// @custom:selector 0x73cd027d
    function previewZapCredit(address token_, uint256 amount_)
        external view returns (uint256, uint256, uint256, uint256, uint256)
    {
        Repo._requireIdle();
        Types.Plan memory plan_ = _plan(_zapOperation(token_, amount_));
        return (
            plan_.shares, plan_.credit.amount0, plan_.credit.amount1,
            plan_.uncredited.amount0, plan_.uncredited.amount1
        );
    }
    // end::previewZapCredit-73cd027d[]
}
// end::UniswapV4PairTokenStandardExchangeVaultQuoteTarget[]
